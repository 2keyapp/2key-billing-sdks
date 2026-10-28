/// Org membership row from Better Auth `list-members` / `get-full-organization`.
class OrgMember {
  const OrgMember({
    required this.id,
    required this.role,
    this.userId,
    this.email,
    this.name,
  });

  final String id;
  final String role;
  final String? userId;
  final String? email;
  final String? name;
}

/// Pending (or other) Better Auth organization invitation.
class OrgInvitation {
  const OrgInvitation({
    required this.id,
    required this.email,
    required this.role,
    this.status = 'pending',
  });

  final String id;
  final String email;
  final String role;
  final String status;
}

List<OrgMember> parseOrgMembers(Object? json) {
  final rows = _rows(json, 'members');
  final out = <OrgMember>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final id = '${row['id'] ?? ''}';
    if (id.isEmpty) continue;
    final user = row['user'] is Map ? row['user'] as Map : const {};
    out.add(OrgMember(
      id: id,
      role: '${row['role'] ?? 'member'}',
      userId: row['userId']?.toString(),
      email: user['email']?.toString(),
      name: user['name']?.toString(),
    ));
  }
  return out;
}

List<OrgInvitation> parseOrgInvitations(Object? json) {
  final rows = json is List ? json : _rows(json, 'invitations');
  final out = <OrgInvitation>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final id = '${row['id'] ?? ''}';
    final email = '${row['email'] ?? ''}';
    if (id.isEmpty) continue;
    out.add(OrgInvitation(
      id: id,
      email: email,
      role: '${row['role'] ?? 'member'}',
      status: '${row['status'] ?? 'pending'}',
    ));
  }
  return out;
}

List<dynamic> _rows(Object? json, String key) {
  if (json is! Map) return const [];
  final data = json['data'] is Map ? json['data'] as Map : json;
  final rows = data[key];
  return rows is List ? rows : const [];
}
