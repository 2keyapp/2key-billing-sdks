import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/src/auth/org_roster.dart';

void main() {
  test('parseOrgMembers reads nested user email', () {
    final members = parseOrgMembers({
      'members': [
        {
          'id': 'm1',
          'userId': 'u1',
          'role': 'admin',
          'user': {'email': 'a@acme.com', 'name': 'A'},
        },
      ],
    });
    expect(members.single.email, 'a@acme.com');
    expect(members.single.role, 'admin');
  });

  test('parseOrgInvitations accepts a list or wrapped map', () {
    expect(
      parseOrgInvitations([
        {
          'id': 'i1',
          'email': 'b@acme.com',
          'role': 'member',
          'status': 'pending',
        },
      ]).single.email,
      'b@acme.com',
    );
    expect(
      parseOrgInvitations({
        'invitations': [
          {'id': 'i1', 'email': 'b@acme.com', 'role': 'member'},
        ],
      }).single.status,
      'pending',
    );
  });
}
