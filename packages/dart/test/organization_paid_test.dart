import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/billing_dart_sdk.dart';

BillingTokenPayload _payload(List<Object?> subscriptionPayingParties) =>
    BillingTokenPayload.fromJson({
      'payload_version': 3,
      'exp': 4102444800,
      'paying_party': {
        'id': '7',
        'identity_provider': 'google',
        'identity_subject': 'sub',
        'billing_email': 'a@b.com',
      },
      'subscriptions': [
        for (final (i, pp) in subscriptionPayingParties.indexed)
          {
            'subscription_id': 's$i',
            'plan_id': 'p$i',
            'plan_name': 'Plan $i',
            'product_id': 'prod',
            'product_name': 'Scomm',
            'subscription_status': 'active',
            'valid_until': 4102444800,
            if (pp != null) 'paying_party_id': pp,
          },
      ],
    });

void main() {
  group('organization-paid subscriptions', () {
    test('parses paying_party_id as string or number', () {
      final payload = _payload(['7', 9]);
      expect(payload.subscriptions[0].payingPartyId, '7');
      expect(payload.subscriptions[1].payingPartyId, '9');
    });

    test('seats paid by another paying party are organization-paid', () {
      final payload = _payload(['7', '9']);
      expect(
        payload.organizationPaidSubscriptions.map((s) => s.subscriptionId),
        ['s1'],
      );
      expect(payload.isOrganizationManaged, isFalse);
    });

    test('all seats paid by an organization means organization-managed', () {
      expect(_payload(['9', '12']).isOrganizationManaged, isTrue);
    });

    test('own seats and older payloads are not organization-managed', () {
      expect(_payload(['7']).isOrganizationManaged, isFalse);
      expect(_payload([null]).isOrganizationManaged, isFalse);
      expect(_payload([]).isOrganizationManaged, isFalse);
    });
  });
}
