import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/machine_authn/machine_authn.dart';
import 'billing_api_client.dart';

Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
  if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
    return json['data'] as Map<String, dynamic>;
  }
  return json;
}

/// Thrown when a Machine AuthN HTTP request fails.
class MachineAuthnException implements Exception {
  MachineAuthnException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'MachineAuthnException($statusCode): $body';
}

/// HTTP client for billing `/api/v1/machine-authn/*`.
class MachineAuthnClient {
  MachineAuthnClient({
    required String baseUrl,
    http.Client? httpClient,
    String? authorization,
    Map<String, String>? extraHeaders,
  })  : _baseUrl = _originWithTrailingSlash(normalizeBillingApiBaseUrl(baseUrl)),
        _http = httpClient ?? http.Client(),
        _authorization = authorization?.trim(),
        _extraHeaders = extraHeaders ?? const {};

  final String _baseUrl;
  final http.Client _http;
  final String? _authorization;
  final Map<String, String> _extraHeaders;

  static String _originWithTrailingSlash(String origin) {
    if (origin.isEmpty) return origin;
    return origin.endsWith('/') ? origin : '$origin/';
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${_baseUrl}api/v1$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool jsonBody = false, bool withAuth = true}) {
    final headers = <String, String>{..._extraHeaders};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (withAuth) {
      final auth = _authorization;
      if (auth != null && auth.isNotEmpty) {
        headers['Authorization'] =
            auth.toLowerCase().startsWith('bearer ') ? auth : 'Bearer $auth';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return _unwrapData(decoded);
      }
      throw MachineAuthnException(
        response.statusCode,
        'Expected JSON object, got ${decoded.runtimeType}',
      );
    }
    throw MachineAuthnException(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(jsonBody: true, withAuth: withAuth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    bool withAuth = true,
  }) async {
    final response = await _http.get(
      _uri(path, query),
      headers: _headers(withAuth: withAuth),
    );
    return _decode(response);
  }

  /// POST `/machine-authn/register`
  Future<RegisterMachineAuthnResult> register({
    required String payingPartyId,
    required String memberId,
    required String entityId,
    required String package,
    required String rootSki,
    required String caCertPem,
    Map<String, dynamic>? rootCredential,
  }) async {
    final data = await _post('/machine-authn/register', {
      'payingPartyId': payingPartyId,
      'memberId': memberId,
      'entityId': entityId,
      'package': package,
      'rootSki': rootSki,
      'caCertPem': caCertPem,
      if (rootCredential != null) 'rootCredential': rootCredential,
    });
    return RegisterMachineAuthnResult.fromJson(data);
  }

  /// POST `/machine-authn/enroll-create`
  Future<EnrollCreateResult> enrollCreate({
    required String payingPartyId,
    required String memberId,
    required String csrPem,
    String? kind,
    String? host,
    String? zone,
    Map<String, dynamic>? publicJwk,
    String? subjectSki,
    String? inviteToken,
    String? platform,
  }) async {
    final data = await _post('/machine-authn/enroll-create', {
      'payingPartyId': payingPartyId,
      'memberId': memberId,
      'csrPem': csrPem,
      if (kind != null) 'kind': kind,
      if (host != null) 'host': host,
      if (zone != null) 'zone': zone,
      if (publicJwk != null) 'publicJwk': publicJwk,
      if (subjectSki != null) 'subjectSki': subjectSki,
      if (inviteToken != null) 'inviteToken': inviteToken,
      if (platform != null) 'platform': platform,
    });
    return EnrollCreateResult.fromJson(data);
  }

  /// POST `/machine-authn/enroll-approve`
  Future<EnrollApproveResult> enrollApprove({
    required String enrollId,
    required String memberId,
    required String leafPem,
    required String chainPem,
    required Map<String, dynamic> credential,
    required String issuerSki,
  }) async {
    final data = await _post('/machine-authn/enroll-approve', {
      'enrollId': enrollId,
      'memberId': memberId,
      'leafPem': leafPem,
      'chainPem': chainPem,
      'credential': credential,
      'issuerSki': issuerSki,
    });
    return EnrollApproveResult.fromJson(data);
  }

  /// POST `/machine-authn/enroll-pull` (no session auth)
  Future<EnrollPullResult> enrollPull({required String pullToken}) async {
    final data = await _post(
      '/machine-authn/enroll-pull',
      {'pullToken': pullToken},
      withAuth: false,
    );
    return enrollPullResultFromJson(data);
  }

  /// POST `/machine-authn/enroll-invite`
  Future<EnrollInviteResult> enrollInvite({
    required String payingPartyId,
    required String memberId,
    String? kind,
    int? expiresInSeconds,
    int? maxUses,
  }) async {
    final data = await _post('/machine-authn/enroll-invite', {
      'payingPartyId': payingPartyId,
      'memberId': memberId,
      if (kind != null) 'kind': kind,
      if (expiresInSeconds != null) 'expiresInSeconds': expiresInSeconds,
      if (maxUses != null) 'maxUses': maxUses,
    });
    return EnrollInviteResult.fromJson(data);
  }

  /// GET `/machine-authn/enroll-invite` (no session auth)
  Future<EnrollInviteResult> getEnrollInvite({
    required String payingPartyId,
    required String inviteToken,
  }) async {
    final data = await _get(
      '/machine-authn/enroll-invite',
      query: {
        'payingPartyId': payingPartyId,
        'inviteToken': inviteToken,
      },
      withAuth: false,
    );
    return EnrollInviteResult.fromJson(data);
  }

  /// POST `/machine-authn/issue-delegate`
  Future<IssueDelegateResult> issueDelegate({
    required String payingPartyId,
    required String memberId,
    required String issuerSki,
    required String kind,
    required Map<String, dynamic> credential,
    String? zone,
    String? platform,
  }) async {
    final data = await _post('/machine-authn/issue-delegate', {
      'payingPartyId': payingPartyId,
      'memberId': memberId,
      'issuerSki': issuerSki,
      'kind': kind,
      'credential': credential,
      if (zone != null) 'zone': zone,
      if (platform != null) 'platform': platform,
    });
    return IssueDelegateResult.fromJson(data);
  }

  /// POST `/machine-authn/assert-subset`
  Future<AssertSubsetResult> assertSubset({
    required List<Map<String, dynamic>> child,
    required List<Map<String, dynamic>> parent,
    Map<String, dynamic>? catalog,
  }) async {
    final data = await _post('/machine-authn/assert-subset', {
      'child': child,
      'parent': parent,
      if (catalog != null) 'catalog': catalog,
    });
    return AssertSubsetResult.fromJson(data);
  }

  /// GET `/machine-authn/platform-root` (no session auth)
  Future<PlatformRootResult> platformRoot() async {
    final data = await _get('/machine-authn/platform-root', withAuth: false);
    return PlatformRootResult.fromJson(data);
  }

  /// GET `/machine-authn/credential-status?ski=`
  Future<CredentialStatusResult> credentialStatus({required String ski}) async {
    final data = await _get(
      '/machine-authn/credential-status',
      query: {'ski': ski},
    );
    return CredentialStatusResult.fromJson(data);
  }

  void close() => _http.close();
}
