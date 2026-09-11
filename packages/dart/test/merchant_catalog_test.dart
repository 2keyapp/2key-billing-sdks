import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

void main() {
  group('MerchantCatalog', () {
    late MerchantCatalog catalog;

    setUp(() {
      catalog = MerchantCatalog.fromJson({
        'products': {
          'Scomm': {
            'offerings': {
              'pqc': {'displayName': 'PQC'},
              'linux': {'displayName': 'Linux'},
              'ai_assistant': {'displayName': 'Local-AI'},
            },
            'plans': {
              'PQC': {
                'description': 'Post-quantum',
                'trialDays': 30,
                'offeringCodes': ['pqc'],
                'pricings': {
                  'annual': {'currency': 'USD', 'basePrice': 15},
                },
              },
              'All Add-ons Bundle': {
                'description': 'Everything',
                'trialDays': 14,
                'offeringCodes': ['pqc', 'linux', 'ai_assistant'],
                'pricings': {
                  'annual': {'currency': 'USD', 'basePrice': 25},
                  'monthly': {'currency': 'USD', 'basePrice': 3},
                },
              },
            },
          },
        },
      });
    });

    test('parses single-SKU and bundle plans', () {
      expect(catalog.plans, hasLength(2));
      final pqc = catalog.plans.firstWhere((p) => p.name == 'PQC');
      expect(pqc.isBundle, isFalse);
      expect(pqc.singleAddonCode, 'pqc');
      expect(pqc.shopSlug, 'pqc');
      expect(pqc.trialDays, 30);
      expect(pqc.pricings.single.basePrice, 15);

      final bundle =
          catalog.plans.firstWhere((p) => p.name == 'All Add-ons Bundle');
      expect(bundle.isBundle, isTrue);
      expect(bundle.singleAddonCode, isNull);
      expect(bundle.shopSlug, 'All Add-ons Bundle');
      expect(bundle.offeringCodes, ['pqc', 'linux', 'ai_assistant']);
      expect(bundle.pricings, hasLength(2));
      expect(bundle.offeringDisplayNames['linux'], 'Linux');
    });
  });

  group('BillingPortalUrls.shopItem', () {
    test('encodes plan name slugs for bundles', () {
      const urls = BillingPortalUrls(portalBaseUrl: 'https://portal.example.com');
      expect(
        urls.shopItemPath('All Add-ons Bundle'),
        '/shop/All%20Add-ons%20Bundle',
      );
      expect(
        urls.shopItem('pqc').toString(),
        'https://portal.example.com/shop/pqc',
      );
    });
  });
}
