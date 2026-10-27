import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/billing_dart_sdk.dart';

BillingTokenPayload _license(String payingParty, String plan, String addon) =>
    BillingTokenPayload.fromJson({
      'payload_version': 3,
      'exp': 4102444800,
      'paying_party': {
        'id': payingParty,
        'identity_provider': 'better-auth',
        'identity_subject': 'owner-$payingParty',
        'billing_email': 'a@b.com',
      },
      'subscriptions': [
        {
          'subscription_id': 's-$plan',
          'paying_party_id': payingParty,
          'plan_id': plan,
          'plan_name': plan,
          'product_id': 'prod',
          'product_name': 'Scomm',
          'addon_code': addon,
          'subscription_status': 'active',
          'valid_until': 4102444800,
        },
      ],
      // Per-license server gates; the merged view derives its own instead.
      'entitlements': {
        'addons': [addon],
      },
    });

void main() {
  group('device licenses, one per organization', () {
    test('merge combines seats and keeps the first payer on top', () {
      final merged = BillingTokenPayload.merge([
        _license('4', 'desktop', 'desktop'),
        _license('15', 'ai', 'ai_assistant'),
      ]);
      expect(merged.payingParty.id, '4');
      expect(merged.subscriptionIds, ['s-desktop', 's-ai']);
      expect(merged.hasAddon('desktop'), isTrue);
      expect(merged.hasAddon('ai_assistant'), isTrue);
      expect(
        merged.organizationPaidSubscriptions.map((s) => s.subscriptionId),
        ['s-ai'],
      );
    });

    test('merge of one license is that license', () {
      final only = _license('4', 'desktop', 'desktop');
      expect(BillingTokenPayload.merge([only]), same(only));
    });

    test('splitLicenses takes one license per line', () {
      expect(BillingSdk.splitLicenses(' a.b.c\r\n\nd.e.f \n'), [
        'a.b.c',
        'd.e.f',
      ]);
    });
  });
}
