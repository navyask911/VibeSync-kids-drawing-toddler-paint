import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_models.dart';
import 'package:kids_drawing_toddler_paint/subscriptions/ad_free_subscription_service.dart';
import 'package:kids_drawing_toddler_paint/subscriptions/device_binding.dart';

void main() {
  group('Premium feature policy', () {
    test('only neon and rainbow brushes require the subscription', () {
      expect(StrokeStyle.solid.requiresSubscription, isFalse);
      expect(StrokeStyle.neon.requiresSubscription, isTrue);
      expect(StrokeStyle.rainbow.requiresSubscription, isTrue);
    });

    test('three extra templates require the subscription', () {
      for (final page in <ColoringPage>[
        ColoringPage.dinosaur,
        ColoringPage.butterfly,
        ColoringPage.castle,
      ]) {
        expect(page.requiresSubscription, isTrue);
      }
      for (final page in <ColoringPage>[
        ColoringPage.freeDraw,
        ColoringPage.puppy,
        ColoringPage.sunshine,
        ColoringPage.rocket,
        ColoringPage.unicorn,
      ]) {
        expect(page.requiresSubscription, isFalse);
      }
    });
  });

  group('Seven-day device-bound offline cache policy', () {
    final deviceA = List<String>.filled(64, 'a').join();
    final deviceB = List<String>.filled(64, 'b').join();
    final now = DateTime.utc(2026, 11, 3, 12);

    test('a recent confirmation is valid only for its bound device', () {
      expect(
        AdFreeSubscriptionService.isCacheValid(
          active: true,
          confirmedAt: now.subtract(const Duration(days: 6, hours: 23)),
          cachedDeviceBindingHash: deviceA,
          currentDeviceBindingHash: deviceA,
          now: now,
        ),
        isTrue,
      );
      expect(
        AdFreeSubscriptionService.isCacheValid(
          active: true,
          confirmedAt: now.subtract(const Duration(days: 2)),
          cachedDeviceBindingHash: deviceA,
          currentDeviceBindingHash: deviceB,
          now: now,
        ),
        isFalse,
      );
    });

    test('inactive, expired, unbound and future cache entries are rejected', () {
      final cases = <Map<String, Object?>>[
        {'active': true, 'confirmedAt': now.subtract(const Duration(days: 7, minutes: 1)), 'cached': deviceA, 'current': deviceA},
        {'active': false, 'confirmedAt': now, 'cached': deviceA, 'current': deviceA},
        {'active': true, 'confirmedAt': now, 'cached': null, 'current': deviceA},
        {'active': true, 'confirmedAt': now, 'cached': deviceA, 'current': null},
        {'active': true, 'confirmedAt': now.add(const Duration(minutes: 1)), 'cached': deviceA, 'current': deviceA},
      ];
      for (final entry in cases) {
        expect(
          AdFreeSubscriptionService.isCacheValid(
            active: entry['active']! as bool,
            confirmedAt: entry['confirmedAt'] as DateTime?,
            cachedDeviceBindingHash: entry['cached'] as String?,
            currentDeviceBindingHash: entry['current'] as String?,
            now: now,
          ),
          isFalse,
        );
      }
    });

    test('product ID is the yearly subscription product', () {
      expect(AdFreeSubscriptionService.productId, 'adfree_yearly');
    });

    test('cross-device block message is explicit', () {
      expect(
        AdFreeSubscriptionService.differentDeviceMessage,
        'This ₹299/year subscription is already active on another device. '
        'Our subscription is strictly valid for 1 device only.',
      );
    });
  });

  group('Android device binding', () {
    test('SHA-256 binding is deterministic and 64 lowercase hex characters', () {
      final first = DeviceBinding.hashAndroidId('android-id-sample');
      final second = DeviceBinding.hashAndroidId('android-id-sample');
      final different = DeviceBinding.hashAndroidId('another-android-id');
      expect(first, second);
      expect(first, hasLength(64));
      expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(different, isNot(first));
    });

    test('empty Android identifiers are rejected', () {
      expect(() => DeviceBinding.hashAndroidId(' '), throwsArgumentError);
    });

    test('a Play record for this device is accepted', () {
      expect(
        DeviceBinding.evaluatePurchase(
          currentDeviceBindingHash: 'device-A',
          obfuscatedAccountId: 'device-A',
          previouslyBoundDeviceHash: null,
        ),
        PurchaseDeviceBindingDecision.sameDevice,
      );
    });

    test('a Play record for another device is blocked', () {
      expect(
        DeviceBinding.evaluatePurchase(
          currentDeviceBindingHash: 'device-B',
          obfuscatedAccountId: 'device-A',
          previouslyBoundDeviceHash: 'device-B',
        ),
        PurchaseDeviceBindingDecision.differentDevice,
      );
    });

    test('legacy/test purchases bind on first local activation', () {
      expect(
        DeviceBinding.evaluatePurchase(
          currentDeviceBindingHash: 'device-A',
          obfuscatedAccountId: null,
          previouslyBoundDeviceHash: null,
        ),
        PurchaseDeviceBindingDecision.legacyFirstActivation,
      );
      expect(
        DeviceBinding.evaluatePurchase(
          currentDeviceBindingHash: 'device-A',
          obfuscatedAccountId: '',
          previouslyBoundDeviceHash: 'device-A',
        ),
        PurchaseDeviceBindingDecision.sameDevice,
      );
      expect(
        DeviceBinding.evaluatePurchase(
          currentDeviceBindingHash: 'device-B',
          obfuscatedAccountId: '',
          previouslyBoundDeviceHash: 'device-A',
        ),
        PurchaseDeviceBindingDecision.differentDevice,
      );
    });
  });
}
