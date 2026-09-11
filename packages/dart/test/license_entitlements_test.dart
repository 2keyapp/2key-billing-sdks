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
  group('LicenseEntitlements Product→Feature→count', () {
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
      final hostsJson = jsonDecode(
        _fixture('scomm_host_catalogs.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final claims = Map<String, dynamic>.from(root['claims'] as Map);
      final payload = BillingTokenPayload.fromJson(claims);
      final hosts = HostsCatalog.fromJson(hostsJson);

      final open = payload.entitlements;
      expect(open.hasAddon('linux'), isTrue);
      expect(open.hasAddon('pgp'), isTrue);
      expect(open.hasAddon('pqc'), isTrue);
      expect(open.hasProduct('prod_mail'), isTrue);

      final email = payload.entitlementsAgainst(hosts.forHost('scommDesktop'));
      expect(email.hasProduct('Scomm'), isTrue);
      expect(email.hasProduct('prod_mail'), isFalse);
      expect(email.resourceForProduct('Scomm', 'max_devices'), 5);
      expect(email.resourceInt('max_devices'), 5);
      expect(email.hasAddon('pqc'), isTrue);
      expect(email.hasAddon('ai_assistant'), isTrue);
      expect(email.hasAddon('pgp'), isFalse);
      expect(email.hasAddon('linux'), isFalse);
      expect(
        email.subscriptions.any((sub) => sub.addonCode == 'pgp'),
        isFalse,
      );
      expect(
        email.subscriptions.any((sub) => sub.addonCode == 'linux'),
        isFalse,
      );

      final emailLinux = payload.entitlementsAgainst(hosts.forHost('scommLinux'));
      expect(emailLinux.hasAddon('linux'), isTrue);
      expect(emailLinux.hasAddon('pqc'), isTrue);
      expect(emailLinux.hasAddon('pgp'), isFalse);

      final office = payload.entitlementsAgainst(hosts.forHost('office'));
      expect(office.hasProduct('Scomm'), isTrue);
      expect(office.hasAddon('pgp'), isTrue);
      expect(office.hasAddon('pqc'), isTrue);
      expect(office.hasAddon('ai_assistant'), isTrue);
      expect(office.hasAddon('linux'), isFalse);
      expect(office.hasAddon('accent_color'), isFalse);
      expect(
        office.subscriptions.any((sub) => sub.addonCode == 'linux'),
        isFalse,
      );
      expect(
        office.subscriptions.any((sub) => sub.addonCode == 'ai_assistant'),
        isTrue,
      );
      expect(
        billingHasActiveAddonRef(
          payload,
          'linux',
          catalog: hosts.forHost('office'),
        ),
        isFalse,
      );
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

    test('bundle plan GROUP BY product SUM resources; normalized JSON has no prices', () {
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
            'plan_id': 'plan_bundle',
            'plan_name': 'All Add-ons Bundle',
            'product_id': '1',
            'product_name': 'Scomm',
            'subscription_status': 'active',
            'valid_until': 4102444800,
            'quantity': 1,
            'offerings': [
              {
                'offering_id': 'o1',
                'offering_code': 'pgp',
                'product_id': '1',
                'product_name': 'Scomm',
                'units': 1,
                'resources': {'addon_code': 'pgp', 'mailboxes': 10},
              },
              {
                'offering_id': 'o2',
                'offering_code': 'linux',
                'product_id': '1',
                'product_name': 'Scomm',
                'units': 1,
                'resources': {'addon_code': 'linux', 'mailboxes': 5},
              },
            ],
          },
        ],
      });
      final e = derived.entitlements;
      expect(e.resourceForProduct('Scomm', 'mailboxes'), 15);
      expect(e.hasAddon('pgp'), isTrue);
      expect(e.hasAddon('linux'), isTrue);
      expect(e.hasProduct('Scomm'), isTrue);
      final snap = e.toNormalizedJson();
      expect(snap['products'], {
        'Scomm': {
          'pgp': {'count': 1, 'mailboxes': 10},
          'linux': {'count': 1, 'mailboxes': 5},
        },
      });
      expect(jsonEncode(snap), isNot(contains('price')));
      expect(jsonEncode(snap), isNot(contains('plan_name')));
    });

    test('COUNT(*) per feature; extra resources stay on that feature', () {
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
            'plan_id': 'plan_x',
            'plan_name': 'X',
            'product_id': '1',
            'product_name': 'Scomm',
            'subscription_status': 'active',
            'valid_until': 4102444800,
            'quantity': 2,
            'offerings': [
              {
                'offering_id': 'o-pgp',
                'offering_code': 'pgp',
                'product_id': '1',
                'product_name': 'Scomm',
                'units': 1,
                'resources': {'addon_code': 'pgp'},
              },
              {
                'offering_id': 'o-spam',
                'offering_code': 'spam_filter',
                'product_id': '1',
                'product_name': 'Scomm',
                'units': 1,
                'resources': {'addon_code': 'spam_filter', 'mailbox': 5},
              },
            ],
          },
        ],
      });
      final snap = derived.entitlements.toNormalizedJson();
      expect(snap['products'], {
        'Scomm': {
          'pgp': {'count': 2},
          'spam_filter': {'count': 2, 'mailbox': 10},
        },
      });
    });
  });
}
