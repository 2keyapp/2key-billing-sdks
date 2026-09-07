import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

File _fixture(String name) {
  // flutter test cwd is packages/dart
  final candidates = [
    File('../../conformance/fixtures/$name'),
    File('../conformance/fixtures/$name'),
    File('conformance/fixtures/$name'),
  ];
  for (final f in candidates) {
    if (f.existsSync()) return f;
  }
  throw StateError('Missing fixture $name (tried ${candidates.map((f) => f.path).join(', ')})');
}

void main() {
  group('LicenseEntitlements Product→Resources→Quantity', () {
    test('exposes by_product summed quantities', () {
      final root =
          jsonDecode(_fixture('license_payload_v3.json').readAsStringSync())
              as Map<String, dynamic>;
      final claims = Map<String, dynamic>.from(root['claims'] as Map);
      final payload = BillingTokenPayload.fromJson(claims);
      expect(payload.payloadVersion, 3);
      final e = payload.entitlements;
      expect(e.byProduct['prod_mail']?['max_devices'], 10);
      expect(e.resourceForProduct('prod_mail', 'max_devices'), 10);
      expect(e.maxDevices(), 10);
      expect(e.maxDevicesForProduct('prod_mail'), 10);
      expect(e.hasProduct('prod_mail'), isTrue);
      expect(e.hasAddon('scomm_connector'), isTrue);
    });

    test('catalog intersection fails closed for unknown JWT codes', () {
      final root =
          jsonDecode(_fixture('license_payload_v3.json').readAsStringSync())
              as Map<String, dynamic>;
      final claims = Map<String, dynamic>.from(root['claims'] as Map);
      final payload = BillingTokenPayload.fromJson(claims);
      const catalog = OfferingCatalog(
        productIds: {'prod_mail'},
        offeringCodes: {'scomm_connector_5'},
        addonCodes: {'scomm_connector'},
      );
      final e = payload.entitlementsAgainst(catalog);
      expect(e.hasProduct('prod_mail'), isTrue);
      expect(e.hasOffering('scomm_connector_5'), isTrue);
      expect(e.hasAddon('scomm_connector'), isTrue);
      expect(e.hasProduct('unknown_product'), isFalse);
      expect(e.hasOffering('unknown_offering'), isFalse);
      expect(e.hasAddon('unknown_addon'), isFalse);
    });

    test('catalog drops JWT offerings the host does not know', () {
      final payload = BillingTokenPayload.fromJson({
        'payload_version': 3,
        'exp': 4102444800,
        'paying_party': {
          'id': 'pp1',
          'identity_provider': 'google',
          'identity_subject': 'sub',
          'billing_email': 'a@b.com',
        },
        'subscriptions': [
          {
            'subscription_id': 's1',
            'plan_id': 'plan_a',
            'plan_name': 'A',
            'product_id': 'prod_mail',
            'product_name': 'Mail',
            'subscription_status': 'active',
            'valid_until': 4102444800,
            'quantity': 1,
            'addon_code': 'scomm_connector',
            'offerings': [
              {
                'offering_id': 'o1',
                'offering_code': 'scomm_connector_5',
                'product_id': 'prod_mail',
                'units': 1,
                'resources': {'max_devices': 5},
              },
            ],
          },
        ],
      });
      const catalog = OfferingCatalog(
        productIds: {'other_product'},
        offeringCodes: {'other_offering'},
        addonCodes: {'other_addon'},
      );
      final e = payload.entitlementsAgainst(catalog);
      expect(e.hasProduct('prod_mail'), isFalse);
      expect(e.hasOffering('scomm_connector_5'), isFalse);
      expect(e.hasAddon('scomm_connector'), isFalse);
    });

    test('Scomm host catalogs split pgp / pqc / linux on one JWT', () {
      final root = jsonDecode(
        _fixture('license_payload_scomm_split.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final catalogs = jsonDecode(
        _fixture('scomm_host_catalogs.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final claims = Map<String, dynamic>.from(root['claims'] as Map);
      final payload = BillingTokenPayload.fromJson(claims);
      final productIds = Set<String>.from(
        (catalogs['productIds'] as List).map((e) => e.toString()),
      );

      OfferingCatalog host(String name) {
        final hosts = catalogs['hosts'] as Map<String, dynamic>;
        final row = hosts[name] as Map<String, dynamic>;
        return OfferingCatalog(
          productIds: productIds,
          offeringCodes: Set<String>.from(
            (row['offeringCodes'] as List).map((e) => e.toString()),
          ),
          addonCodes: Set<String>.from(
            (row['addonCodes'] as List).map((e) => e.toString()),
          ),
        );
      }

      final open = payload.entitlements;
      expect(open.hasAddon('linux'), isTrue);
      expect(open.hasAddon('pgp'), isTrue);
      expect(open.hasAddon('pqc'), isTrue);

      final email = payload.entitlementsAgainst(host('secmailDesktop'));
      expect(email.hasAddon('pqc'), isTrue);
      expect(email.hasAddon('ai_assistant'), isTrue);
      expect(email.hasAddon('pgp'), isFalse);
      expect(email.hasAddon('linux'), isFalse);

      final emailLinux = payload.entitlementsAgainst(host('secmailLinux'));
      expect(emailLinux.hasAddon('linux'), isTrue);
      expect(emailLinux.hasAddon('pqc'), isTrue);
      expect(emailLinux.hasAddon('pgp'), isFalse);

      final office = payload.entitlementsAgainst(host('office'));
      expect(office.hasAddon('pgp'), isTrue);
      expect(office.hasAddon('pqc'), isTrue);
      expect(office.hasAddon('ai_assistant'), isTrue);
      expect(office.hasAddon('linux'), isFalse);
      expect(office.hasAddon('accent_color'), isFalse);
    });

    test('sums same product across offerings when deriving client-side', () {
      final derived = BillingTokenPayload.fromJson({
        'payload_version': 3,
        'exp': 4102444800,
        'paying_party': {
          'id': 'pp1',
          'identity_provider': 'google',
          'identity_subject': 'sub',
          'billing_email': 'a@b.com',
        },
        'subscriptions': [
          {
            'subscription_id': 's1',
            'plan_id': 'plan_a',
            'plan_name': 'A',
            'product_id': 'prod_mail',
            'product_name': 'Mail',
            'subscription_status': 'active',
            'valid_until': 4102444800,
            'quantity': 1,
            'offerings': [
              {
                'offering_id': 'o1',
                'offering_code': 'tier5',
                'product_id': 'prod_mail',
                'units': 1,
                'resources': {'max_devices': 5},
              },
            ],
          },
          {
            'subscription_id': 's2',
            'plan_id': 'plan_b',
            'plan_name': 'B',
            'product_id': 'prod_mail',
            'product_name': 'Mail',
            'subscription_status': 'active',
            'valid_until': 4102444800,
            'quantity': 1,
            'offerings': [
              {
                'offering_id': 'o2',
                'offering_code': 'tier25',
                'product_id': 'prod_mail',
                'units': 1,
                'resources': {'max_devices': 25},
              },
            ],
          },
        ],
      });
      final e = derived.entitlements;
      expect(e.resourceForProduct('prod_mail', 'max_devices'), 30);
      expect(e.resourceInt('max_devices'), 30);
    });
  });
}
