import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/machine_authn/machine_authn.dart';
import 'billing_api_client.dart';
import 'machine_authn_client.dart' show MachineAuthnException;

/// Better Auth `delegate-permissions` plugin CSR inbox
/// (`/api/auth/delegate-permissions/*`) — the entity-first enroll store that
/// Target Admin approval UIs read. Authenticated by the Better Auth session
/// cookie ([BillingAuthClient.getSessionCookie]) plus, when [accessToken] is
/// given, the billing API JWT: billing serves these routes behind
/// `requireBillingAuth`, and the token's org picks the paying party.
class DelegatePermissionsClient {
  DelegatePermissionsClient({
    required String billingBaseUrl,
    required Future<String> Function() sessionCookie,
    Future<String?> Function()? accessToken,
    http.Client? httpClient,
    this.flutterOrigin = 'scomm://',
  }) : _base = normalizeBillingApiBaseUrl(
         billingBaseUrl,
       ).replaceAll(RegExp(r'/$'), ''),
       _cookie = sessionCookie,
       _accessToken = accessToken,
       _http = httpClient ?? http.Client();

  final String _base;
  final Future<String> Function() _cookie;
  final Future<String?> Function()? _accessToken;
  final http.Client _http;

  /// Trusted deep-link origin the server copies to `Origin` for BA CSRF.
  final String flutterOrigin;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '$_base/api/auth/delegate-permissions$path',
  ).replace(queryParameters: query);

  /// [withCookie] false = unauthenticated call (enroll-pull): no cookie, no JWT.
  Future<Map<String, String>> _headers({bool withCookie = true}) async {
    final cookie = withCookie ? await _cookie() : '';
    final token = withCookie ? (await _accessToken?.call())?.trim() ?? '' : '';
    return {
      'accept': 'application/json',
      'content-type': 'application/json',
      'flutter-origin': flutterOrigin,
      if (cookie.isNotEmpty) 'cookie': cookie,
      if (token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MachineAuthnException(res.statusCode, res.body);
    }
    if (res.body.trim().isEmpty) return {};
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool withCookie = true,
  }) async => _decode(
    await _http.post(
      _uri(path),
      headers: await _headers(withCookie: withCookie),
      body: jsonEncode(body),
    ),
  );

  /// Whether the DP Entity CA exists (Admin kickstart done).
  Future<bool> entityExists({required String entityId}) async {
    final res = await _http.get(
      _uri('/entity', {'entityId': entityId.trim().toLowerCase()}),
      headers: await _headers(),
    );
    if (res.statusCode == 404) return false;
    final j = _decode(res);
    return j['exists'] is bool ? j['exists'] as bool : j['entityId'] != null;
  }

  /// Create a pending CSR enroll. [host] is the machine locator `label--entity`.
  Future<EnrollCreateResult> enrollCreate({
    required String entityId,
    required String host,
    required String csrPem,
    required Map<String, dynamic> publicJwk,
    String kind = 'machine_target',
    String? subjectSki,
    String? inviteToken,
    String? zone,
    String? target,
  }) async => EnrollCreateResult.fromJson(
    await _post('/enroll-create', {
      'entityId': entityId.trim().toLowerCase(),
      'host': host.trim().toLowerCase(),
      'kind': kind,
      'csrPem': csrPem,
      'publicJwk': publicJwk,
      if (subjectSki != null) 'subjectSki': subjectSki,
      if (inviteToken != null) 'inviteToken': inviteToken,
      // Enroll into this zone (its admin approves); the Target it is for.
      if (zone != null) 'zone': zone.trim().toLowerCase(),
      if (target != null) 'target': target.trim().toLowerCase(),
    }),
  );

  /// Pull by pull token (no session). Same shape as billing `enroll-pull`.
  Future<EnrollPullResult> enrollPull({required String pullToken}) async =>
      enrollPullResultFromJson(
        await _post('/enroll-pull', {
          'pullToken': pullToken,
        }, withCookie: false),
      );

  void close() => _http.close();
}
