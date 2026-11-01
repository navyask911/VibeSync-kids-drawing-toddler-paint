import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';

class AdFreeSubscriptionService extends ChangeNotifier {
  AdFreeSubscriptionService({InAppPurchase? store})
      : _store = store ?? InAppPurchase.instance;

  static const String productId = 'adfree_yearly';
  static const Duration cacheValidity = Duration(hours: 24);
  static const int _maxCacheBytes = 4096;

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? product;
  bool storeAvailable = false;
  bool isReady = false;
  bool isAdFree = false;
  bool isPurchasing = false;
  bool isRestoring = false;
  String? message;
  bool _foundSubscriptionDuringRestore = false;

  static bool isCacheValid({
    required bool active,
    required DateTime? confirmedAt,
    DateTime? now,
  }) {
    if (!active || confirmedAt == null) return false;
    final age = (now ?? DateTime.now()).toUtc().difference(confirmedAt.toUtc());
    return !age.isNegative && age <= cacheValidity;
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}ad_free_subscription_v1.json');
  }

  Future<void> initialize() async {
    await _loadCachedEntitlement();
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        message = 'Google Play purchase updates are temporarily unavailable.';
        debugPrint('Purchase stream error: $error');
        notifyListeners();
      },
    );
    try {
      storeAvailable = await _store.isAvailable().timeout(const Duration(seconds: 8));
      if (storeAvailable) {
        await refreshProductDetails();
        await restorePurchases();
      } else {
        message = 'Google Play is not available on this device right now.';
      }
    } catch (error) {
      message = 'Could not refresh the subscription with Google Play.';
      debugPrint('Subscription initialization deferred: $error');
    } finally {
      isReady = true;
      notifyListeners();
    }
  }

  Future<void> _loadCachedEntitlement() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final length = await file.length();
      if (length <= 0 || length > _maxCacheBytes) {
        await file.delete();
        return;
      }
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return;
      final timestamp = json['confirmedAt'];
      isAdFree = isCacheValid(
        active: json['active'] == true,
        confirmedAt: timestamp is String ? DateTime.tryParse(timestamp) : null,
      );
    } catch (error) {
      debugPrint('Ad-free cache read failed: $error');
      isAdFree = false;
    }
  }

  Future<void> _persistEntitlement() async {
    final file = await _cacheFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'active': true,
        'confirmedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }

  Future<void> _clearCachedEntitlement() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Ad-free cache clear failed: $error');
    }
  }

  Future<void> _grantEntitlement() async {
    isAdFree = true;
    try {
      await _persistEntitlement();
    } catch (error) {
      debugPrint('Ad-free cache write failed: $error');
    }
    notifyListeners();
  }

  Future<void> _revokeEntitlement() async {
    isAdFree = false;
    await _clearCachedEntitlement();
    notifyListeners();
  }

  Future<void> refreshProductDetails() async {
    if (!storeAvailable) return;
    try {
      final response = await _store
          .queryProductDetails(<String>{productId})
          .timeout(const Duration(seconds: 8));
      if (response.error != null) message = response.error!.message;
      product = null;
      for (final details in response.productDetails) {
        if (details.id == productId) {
          product = details;
          break;
        }
      }
      if (product == null && response.notFoundIDs.contains(productId)) {
        message = 'The ad-free subscription is not configured in Google Play yet.';
      }
    } catch (error) {
      message = 'Could not load the subscription from Google Play.';
      debugPrint('Product query failed: $error');
    }
    notifyListeners();
  }

  Future<void> purchase() async {
    final details = product;
    if (!storeAvailable || details == null || isPurchasing) {
      message = details == null
          ? 'The subscription is not currently available in Google Play.'
          : 'Please wait for the current purchase to finish.';
      notifyListeners();
      return;
    }
    isPurchasing = true;
    message = null;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) {
        isPurchasing = false;
        message = 'Google Play could not start the purchase.';
        notifyListeners();
      }
    } catch (error) {
      isPurchasing = false;
      message = 'The purchase could not be started. Please try again.';
      debugPrint('Purchase start failed: $error');
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (!storeAvailable || isRestoring) return;
    isRestoring = true;
    _foundSubscriptionDuringRestore = false;
    message = null;
    notifyListeners();
    try {
      await _store.restorePurchases().timeout(const Duration(seconds: 8));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!_foundSubscriptionDuringRestore) {
        await _revokeEntitlement();
        message = 'No active ad-free subscription was found for this Play account.';
      } else {
        message = 'Your ad-free subscription has been restored.';
      }
    } catch (error) {
      // A store outage must not erase a still-fresh cached state.
      message = 'Could not restore purchases. Please try again when online.';
      debugPrint('Restore failed: $error');
    } finally {
      isRestoring = false;
      notifyListeners();
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> updates) {
    for (final purchase in updates) {
      unawaited(_handlePurchase(purchase));
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.productID == productId) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          isPurchasing = true;
          message = 'Google Play is processing your purchase.';
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // The store plugin reports a completed transaction. The cache is
          // only an offline convenience; receipt/token verification on a
          // trusted server is needed for strong expiry/refund protection.
          if (purchase.verificationData.serverVerificationData.isNotEmpty) {
            _foundSubscriptionDuringRestore = true;
            await _grantEntitlement();
            isPurchasing = false;
            message = 'Ad-free access is active on this device.';
          } else {
            isPurchasing = false;
            message = 'Google Play did not provide purchase details to confirm access.';
          }
          notifyListeners();
          break;
        case PurchaseStatus.error:
          isPurchasing = false;
          message = purchase.error?.message ?? 'The purchase could not be completed.';
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          isPurchasing = false;
          message = 'The purchase was canceled.';
          notifyListeners();
          break;
      }
    }
    if (purchase.pendingCompletePurchase) {
      try {
        await _store.completePurchase(purchase);
      } catch (error) {
        debugPrint('Purchase completion failed: $error');
      }
    }
  }

  @override
  void dispose() {
    final stream = _purchaseSubscription;
    if (stream != null) unawaited(stream.cancel());
    super.dispose();
  }
}
