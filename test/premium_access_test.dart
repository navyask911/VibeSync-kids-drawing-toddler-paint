import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_models.dart';
import 'package:kids_drawing_toddler_paint/subscriptions/ad_free_subscription_service.dart';

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

  group('Offline subscription cache policy', () {
    final now = DateTime.utc(2026, 11, 1, 12);

    test('a recent store confirmation is available for short offline use', () {
      expect(
        AdFreeSubscriptionService.isCacheValid(
          active: true,
          confirmedAt: now.subtract(const Duration(hours: 12)),
          now: now,
        ),
        isTrue,
      );
    });

    test('inactive, expired, missing, and future timestamps are rejected', () {
      expect(
        AdFreeSubscriptionService.isCacheValid(
          active: true,
          confirmedAt: now.subtract(const Duration(hours: 25)),
          now: now,
        ),
        isFalse,
      );
      expect(
        AdFreeSubscriptionService.isCacheValid(
          active: false,
          confirmedAt: now,
          now: now,
        ),
        isFalse,
      );
      expect(
        AdFreeSubscriptionService.isCacheValid(
          active: true,
          confirmedAt: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        AdFreeSubscriptionService.isCacheValid(
          active: true,
          confirmedAt: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('the Play Console product id is stable', () {
      expect(AdFreeSubscriptionService.productId, 'adfree_yearly');
    });
  });
}
