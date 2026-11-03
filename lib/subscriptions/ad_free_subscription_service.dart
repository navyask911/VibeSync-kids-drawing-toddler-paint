import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_binding.dart';

typedef DeviceBindingHashLoader = Future<String> Function();

class AdFreeSubscriptionService extends ChangeNotifier {
  AdFreeSubscriptionService({
    InAppPurchase? store,
    SharedPreferencesAsync? preferences,
    DeviceBindingHashLoader? deviceBindingHashLoader,
  })  : _store = store ?? InAppPurchase.instance,
        _preferences = preferences ?? SharedPreferencesAsync(),
        _deviceBindingHashLoader =
            deviceBindingHashLoader ?? DeviceBinding.currentDeviceBindingHash;

  static const String productId = 'adfree_yearly';
  static const Duration cacheValidity = Duration(days: 7);
  static const String differentDeviceMessage =
      'This ₹299/year subscription is already active on another device. '
      'Our subscription is strictly valid for 1 device only.';

  static const String _cachePrefix = 'adfree_yearly.';
  static const String _activeKey = '${_cachePrefix}active';
  static const String _confirmedAtKey = '${_cachePrefix}confirmed_at';
  static const String _deviceHashKey = '${_cachePrefix}device_binding_hash';
  static const String _bindingSourceKey = '${_cachePrefix}binding_source';

  final InAppPurchase _store;
  final SharedPreferencesAsync _preferences;
  final DeviceBindingHashLoader _deviceBindingHashLoader;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Future<void> _purchaseUpdateQueue = Future<void>.value();

  ProductDetails? product;
  String? deviceBindingHash;
  bool storeAvailable = false;
  bool isReady = false;
  bool isAdFree = false;
  bool isPurchasing = false;
  bool isRestoring = false;
  bool isBoundElsewhere = false;
  bool isUsingOfflineGrace = false;
  String? message;

  bool get deviceBindingReady => deviceBindingHash != null;

  static bool isCacheValid({
    required bool active,
    required DateTime? confirmedAt,
    required String? cachedDeviceBindingHash,
    required String? currentDeviceBindingHash,
    DateTime? now,
  }) {
    if (!active ||
        confirmedAt == null ||
        cachedDeviceBindingHash == null ||
        currentDeviceBindingHash == null ||
        cachedDeviceBindingHash.isEmpty ||
        currentDeviceBindingHash.isEmpty ||
        cachedDeviceBindingHash != currentDeviceBindingHash) {
      return false;
    }
    final age = (now ?? DateTime.now()).toUtc().difference(confirmedAt.toUtc());
    return !age.isNegative && age <= cacheValidity;
  }

  Future<bool> _refreshDeviceBinding() async {
    try {
      final currentHash = await _deviceBindingHashLoader();
      if (currentHash.length != 64) {
        throw StateError('The device binding hash is invalid.');
      }
      deviceBindingHash = currentHash;
      await _loadCachedEntitlement();
      return true;
    } catch (error) {
      deviceBindingHash = null;
      isAdFree = false;
      isUsingOfflineGrace = false;
      message = Platform.isAndroid
          ? 'Could not identify this device for subscription protection. '
              'Purchases and restores are disabled.'
          : 'Per-device Google Play subscriptions are supported on Android only.';
      debugPrint('Device binding refresh failed: $error');
      notifyListeners();
      return false;
    }
  }

  Future<void> initialize() async {
    // Resolve the binding before accepting purchase callbacks, but subscribe
    // before querying Play so unfinished transactions are not missed.
    await _refreshDeviceBinding();
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _enqueuePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        message = 'Google Play purchase updates are temporarily unavailable.';
        debugPrint('Purchase stream error: $error');
        notifyListeners();
      },
    );

    try {
      storeAvailable =
          await _store.isAvailable().timeout(const Duration(seconds: 8));
      if (storeAvailable) {
        await refreshProductDetails();
        if (deviceBindingReady) {
          await restorePurchases();
        }
      } else if (isAdFree) {
        message = 'Your device-bound subscription is available in offline grace mode.';
      } else {
        message = 'Google Play is not available on this device right now.';
      }
    } catch (error) {
      message = isAdFree
          ? 'Your device-bound subscription is available in offline grace mode.'
          : 'Could not refresh the subscription with Google Play.';
      debugPrint('Subscription initialization deferred: $error');
    } finally {
      isReady = true;
      notifyListeners();
    }
  }

  Future<void> _loadCachedEntitlement() async {
    final active = await _preferences.getBool(_activeKey) ?? false;
    final storedHash = await _preferences.getString(_deviceHashKey);
    final confirmedAtValue = await _preferences.getString(_confirmedAtKey);
    final confirmedAt = confirmedAtValue == null
        ? null
        : DateTime.tryParse(confirmedAtValue);

    isBoundElsewhere = false;
    isAdFree = isCacheValid(
      active: active,
      confirmedAt: confirmedAt,
      cachedDeviceBindingHash: storedHash,
      currentDeviceBindingHash: deviceBindingHash,
    );
    isUsingOfflineGrace = isAdFree;

    if (active &&
        storedHash != null &&
        deviceBindingHash != null &&
        storedHash != deviceBindingHash) {
      isBoundElsewhere = true;
      message = differentDeviceMessage;
    } else if (active && !isAdFree) {
      await _clearCachedEntitlement();
    }
  }

  Future<void> _persistEntitlement({required String bindingSource}) async {
    final hash = deviceBindingHash;
    if (hash == null) {
      throw StateError('Cannot cache entitlement without a device binding.');
    }
    await _preferences.setBool(_activeKey, true);
    await _preferences.setString(
      _confirmedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await _preferences.setString(_deviceHashKey, hash);
    await _preferences.setString(_bindingSourceKey, bindingSource);
  }

  Future<void> _clearCachedEntitlement({bool preserveDeviceBinding = false}) async {
    try {
      await _preferences.remove(_activeKey);
      await _preferences.remove(_confirmedAtKey);
      if (!preserveDeviceBinding) {
        await _preferences.remove(_deviceHashKey);
        await _preferences.remove(_bindingSourceKey);
      }
    } catch (error) {
      debugPrint('Ad-free cache clear failed: $error');
    }
  }

  Future<void> _grantEntitlement({required String bindingSource}) async {
    isAdFree = true;
    isBoundElsewhere = false;
    isUsingOfflineGrace = false;
    try {
      await _persistEntitlement(bindingSource: bindingSource);
    } catch (error) {
      debugPrint('Ad-free cache write failed: $error');
    }
    notifyListeners();
  }

  Future<void> _blockDifferentDevice() async {
    isAdFree = false;
    isUsingOfflineGrace = false;
    isBoundElsewhere = true;
    await _clearCachedEntitlement(preserveDeviceBinding: true);
    message = differentDeviceMessage;
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
      ProductDetails? firstMatch;
      for (final details in response.productDetails) {
        if (details.id != productId) continue;
        firstMatch ??= details;
        if (details is GooglePlayProductDetails &&
            details.offerToken != null &&
            details.offerToken!.isNotEmpty) {
          product = details;
          break;
        }
      }
      product ??= firstMatch;
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
    if (!await _refreshDeviceBinding()) return;
    final details = product;
    final bindingHash = deviceBindingHash;
    if (bindingHash == null) {
      message = 'This Android device could not be securely identified. '
          'Subscription purchase is disabled.';
      notifyListeners();
      return;
    }
    if (isBoundElsewhere) {
      message = differentDeviceMessage;
      notifyListeners();
      return;
    }
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
      if (!Platform.isAndroid ||
          details is! GooglePlayProductDetails ||
          details.offerToken == null ||
          details.offerToken!.isEmpty) {
        throw StateError('Google Play did not return an eligible Android subscription offer.');
      }
      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: details,
        applicationUserName: bindingHash,
        offerToken: details.offerToken,
      );
      final started = await _store.buyNonConsumable(purchaseParam: purchaseParam);
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
    if (!await _refreshDeviceBinding()) return;
    if (!deviceBindingReady) {
      message = 'This Android device could not be securely identified. '
          'Subscription restoration is disabled.';
      notifyListeners();
      return;
    }

    isRestoring = true;
    _restoreSawSubscription = false;
    _restoreFoundEntitlement = false;
    _restoreFoundMismatch = false;
    message = null;
    notifyListeners();
    try {
      await _store.restorePurchases().timeout(const Duration(seconds: 8));
      await _purchaseUpdateQueue.timeout(const Duration(seconds: 8));

      if (_restoreFoundMismatch) {
        await _blockDifferentDevice();
      } else if (_restoreFoundEntitlement) {
        message = 'Your subscription has been restored on this device.';
      } else if (_restoreSawSubscription) {
        message = 'Google Play returned a subscription record that could not '
            'be verified for this device.';
      } else {
        await _clearCachedEntitlement();
        isAdFree = false;
        isUsingOfflineGrace = false;
        isBoundElsewhere = false;
        message = 'No active adfree_yearly subscription was found for this Play account.';
      }
    } catch (error) {
      message = isAdFree
          ? 'Google Play could not refresh your subscription. '
              'Your device-bound offline grace remains active.'
          : 'Could not restore purchases. Please try again when online.';
      debugPrint('Restore failed: $error');
    } finally {
      isRestoring = false;
      notifyListeners();
    }
  }

  bool _restoreSawSubscription = false;
  bool _restoreFoundEntitlement = false;
  bool _restoreFoundMismatch = false;

  void _enqueuePurchaseUpdates(List<PurchaseDetails> updates) {
    _purchaseUpdateQueue = _purchaseUpdateQueue
        .then<void>((_) async {
          for (final purchase in updates) {
            await _handlePurchase(purchase);
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Purchase update processing failed: $error');
        });
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    try {
      if (purchase.productID != productId) return;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          isPurchasing = true;
          message = 'Google Play is processing your subscription purchase.';
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _restoreSawSubscription = true;
          if (purchase.verificationData.serverVerificationData.isEmpty) {
            isPurchasing = false;
            message = 'Google Play did not provide purchase details to confirm access.';
            notifyListeners();
            break;
          }
          if (!Platform.isAndroid || deviceBindingHash == null) {
            isPurchasing = false;
            message = 'Per-device Google Play subscriptions are supported on Android only.';
            notifyListeners();
            break;
          }
          if (purchase is! GooglePlayPurchaseDetails) {
            isPurchasing = false;
            message = 'Google Play returned an unsupported purchase record. Access was not activated.';
            notifyListeners();
            break;
          }

          final previousBinding = await _preferences.getString(_deviceHashKey);
          final decision = DeviceBinding.evaluatePurchase(
            currentDeviceBindingHash: deviceBindingHash!,
            obfuscatedAccountId: purchase.billingClientPurchase.obfuscatedAccountId,
            previouslyBoundDeviceHash: previousBinding,
          );
          if (decision == PurchaseDeviceBindingDecision.differentDevice) {
            _restoreFoundMismatch = true;
            isPurchasing = false;
            await _blockDifferentDevice();
            break;
          }

          final source = decision == PurchaseDeviceBindingDecision.legacyFirstActivation
              ? 'legacy-first-activation'
              : 'google-play-obfuscated-account-id';
          await _grantEntitlement(bindingSource: source);
          _restoreFoundEntitlement = true;
          isPurchasing = false;
          message = 'Ad-free and Pro Creative Studio are active on this device.';
          notifyListeners();
          break;
        case PurchaseStatus.error:
          isPurchasing = false;
          message = purchase.error?.message ?? 'The subscription purchase could not be completed.';
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          isPurchasing = false;
          message = 'The subscription purchase was canceled.';
          notifyListeners();
          break;
      }
    } catch (error, stackTrace) {
      debugPrint('Purchase update handling failed: $error\n$stackTrace');
      if (purchase.productID == productId) {
        isPurchasing = false;
        message = 'The subscription update could not be processed. Please restore again from the parent area.';
        notifyListeners();
      }
    } finally {
      // Acknowledge even a rejected cross-device record; acknowledge within
      // Google's three-day Android deadline so the purchase is not refunded.
      if (purchase.pendingCompletePurchase) {
        try {
          await _store.completePurchase(purchase);
        } catch (error) {
          debugPrint('Purchase completion/acknowledgement failed: $error');
        }
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
