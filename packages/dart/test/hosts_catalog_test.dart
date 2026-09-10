import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

File _fixture(String name) {
  final candidates = [
    File('../../conformance/fixtures/$name'),
    File('../conformance/fixtures/$name'),
    File('conformance/fixtures/$name'),
  ];
  for (final f in candidates) {
    if (f.existsSync()) return f;
  }
  throw StateError('Missing fixture $name');
}

void main() {
  group('HostsCatalog', () {
    late HostsCatalog hosts;

    setUp(() {
      hosts = HostsCatalog.fromJson(
        jsonDecode(_fixture('scomm_host_catalogs.json').readAsStringSync())
            as Map<String, dynamic>,
      );
    });

    test('slices office vs email hosts from baked hosts.json', () {
      final office = hosts.forHost('office');
      expect(office.productNames, {'Scomm'});
      expect(office.offeringCodes.contains('pgp'), isTrue);
      expect(office.offeringCodes.contains('linux'), isFalse);
      expect(office.knowsProduct('Scomm'), isTrue);
      expect(office.knowsProduct('42'), isFalse);
      expect(office.knowsAddon('linux'), isFalse);

      final desktop = hosts.forHost('scommDesktop');
      expect(desktop.offeringCodes.contains('pgp'), isFalse);
      expect(desktop.offeringCodes.contains('linux'), isFalse);
      expect(desktop.offeringCodes.contains('accent_color'), isTrue);

      final linux = hosts.forHost('scommLinux');
      expect(linux.offeringCodes.contains('linux'), isTrue);
      expect(linux.offeringCodes.contains('pgp'), isFalse);
    });

    test('rejects unknown host keys', () {
      expect(() => hosts.forHost('missing'), throwsArgumentError);
    });
  });

  test('productNames remap serial JWT product_id without double-counting', () {
    final payload = BillingTokenPayload.fromJson({
      'payload_version': 3,
      'paying_party': {
        'id': 'pp1',
        'identity_provider': 'google',
        'identity_subject': 'sub',
        'billing_email': 'a@b.com',
      },
      'subscriptions': [
        {
          'subscription_id': 's1',
          'plan_id': '1',
          'plan_name': 'A',
          'product_id': '42',
          'product_name': 'Scomm',
          'subscription_status': 'active',
          'valid_until': 4102444800,
          'quantity': 1,
          'offerings': [
            {
              'offering_id': 'o1',
              'offering_code': 'pqc',
              'product_id': '42',
              'product_name': 'Scomm',
              'units': 1,
              'resources': {'max_devices': 5, 'addon_code': 'pqc'},
            },
          ],
        },
      ],
      'entitlements': {
        'by_product': {
          '42': {'max_devices': 5},
        },
        'addons': ['pqc'],
        'by_offering_code': {
          'pqc': {'addon_code': 'pqc'},
        },
      },
    });
    const catalog = OfferingCatalog(
      productNames: {'Scomm'},
      offeringCodes: {'pqc'},
      addonCodes: {'pqc'},
    );
    final gated = payload.entitlementsAgainst(catalog);
    expect(gated.hasProduct('Scomm'), isTrue);
    expect(gated.hasProduct('42'), isFalse);
    expect(gated.resourceForProduct('Scomm', 'max_devices'), 5);
    expect(gated.resourceInt('max_devices'), 5);
  });
}
