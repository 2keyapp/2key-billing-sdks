import 'package:two_key_dart_sdk/src/auth/billing_portal_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingPortalUrls', () {
    const urls = BillingPortalUrls(portalBaseUrl: 'https://portal.example.com');

    test('sessionHandoff builds handoff path without token', () {
      expect(
        urls.sessionHandoff().toString(),
        'https://portal.example.com/auth/handoff',
      );
    });

    test('sessionHandoff includes safe redirect path', () {
      expect(
        urls.sessionHandoff(redirectPath: '/subscriptions').toString(),
        'https://portal.example.com/auth/handoff?redirect=%2Fsubscriptions',
      );
    });

    test('sessionHandoff ignores unsafe redirect paths', () {
      expect(
        urls.sessionHandoff(redirectPath: '//evil.example.com').toString(),
        'https://portal.example.com/auth/handoff',
      );
    });

    test('marketplace and planPurchase build shop URLs', () {
      expect(
        urls.marketplace().toString(),
        'https://portal.example.com/shop',
      );
      expect(
        urls.planPurchase(12).toString(),
        'https://portal.example.com/shop/12',
      );
      expect(
        urls.planPurchasePath(12),
        '/shop/12',
      );
    });

    test('devices points at the SPA settings page', () {
      expect(
        urls.devices().toString(),
        'https://portal.example.com/settings/devices',
      );
    });

    test('devicesApiFallback keeps billing /portal/devices', () {
      expect(
        urls
            .devicesApiFallback(
              billingApiBaseUrl: 'https://billing.example.com',
            )
            .toString(),
        'https://billing.example.com/portal/devices',
      );
    });

    test('custom shopPath is respected', () {
      const custom = BillingPortalUrls(
        portalBaseUrl: 'https://portal.example.com',
        shopPath: 'store',
      );
      expect(custom.marketplace().toString(), 'https://portal.example.com/store');
      expect(custom.planPurchase(3).path, '/store/3');
    });
  });
}
