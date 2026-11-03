import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class DeviceBinding {
  DeviceBinding._();

  static const String appPackageSalt = 'com.navya.kids_drawing_studio';
  static const String channelName = 'com.navya.kids_drawing_studio/device_binding';
  static const MethodChannel _channel = MethodChannel(channelName);

  static String hashAndroidId(String androidId) {
    final normalized = androidId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(androidId, 'androidId', 'must not be empty');
    }
    return sha256.convert(utf8.encode('$appPackageSalt:$normalized')).toString();
  }

  static Future<String> currentDeviceBindingHash() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'The per-device Google Play subscription is supported on Android only.',
      );
    }
    final androidId = await _channel.invokeMethod<String>('getAndroidId');
    if (androidId == null || androidId.trim().isEmpty) {
      throw StateError('Android did not return ANDROID_ID.');
    }
    return hashAndroidId(androidId);
  }

  static PurchaseDeviceBindingDecision evaluatePurchase({
    required String currentDeviceBindingHash,
    required String? obfuscatedAccountId,
    required String? previouslyBoundDeviceHash,
  }) {
    final storeBinding = obfuscatedAccountId?.trim() ?? '';
    if (storeBinding.isNotEmpty) {
      return storeBinding == currentDeviceBindingHash
          ? PurchaseDeviceBindingDecision.sameDevice
          : PurchaseDeviceBindingDecision.differentDevice;
    }
    final localBinding = previouslyBoundDeviceHash?.trim() ?? '';
    if (localBinding.isEmpty) {
      return PurchaseDeviceBindingDecision.legacyFirstActivation;
    }
    return localBinding == currentDeviceBindingHash
        ? PurchaseDeviceBindingDecision.sameDevice
        : PurchaseDeviceBindingDecision.differentDevice;
  }
}

enum PurchaseDeviceBindingDecision {
  sameDevice,
  legacyFirstActivation,
  differentDevice,
}
