import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'url.dart';

sealed class SyncResult {}

class SyncSuccess implements SyncResult {
  SyncSuccess({required this.signedToken, this.etag});
  final String signedToken;
  final String? etag;
}

class SyncNotModified implements SyncResult {
  SyncNotModified({this.etag});
  final String? etag;
}

/// Minimal `/api/v1` client.
class TwoKeyApiClient {
  TwoKeyApiClient({required String baseUrl, http.Client? httpClient})
      : _baseUrl = _slash(normalizeApiBaseUrl(baseUrl)),
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  static String _slash(String origin) =>
      origin.isEmpty ? origin : (origin.endsWith('/') ? origin : '$origin/');

  Future<SyncResult> fetchLicense({
    required String authorizationToken,
    String? payingPartyId,
    String? ifNoneMatch,
  }) async {
    final raw = authorizationToken.trim();
    if (raw.isEmpty) {
      throw TwoKeyException(TwoKeyErrorCode.unauthorized, 'Authorization token is required.');
    }
    final token = raw.toLowerCase().startsWith('bearer ') ? raw : 'Bearer $raw';
    final headers = <String, String>{'Authorization': token};
    final party = payingPartyId?.trim();
    if (party != null && party.isNotEmpty) {
      headers['X-Paying-Party-Id'] = party;
    }
    final etag = ifNoneMatch?.trim();
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag.startsWith('"') ? etag : '"$etag"';
    }

    final uri = Uri.parse('${_baseUrl}api/v1/license');
    late http.Response response;
    try {
      response = await _http.get(uri, headers: headers);
    } catch (e) {
      throw TwoKeyException(
        TwoKeyErrorCode.network,
        'Network error talking to billing server',
        detail: '$e',
      );
    }

    final responseEtag = response.headers['etag'] ?? response.headers['ETag'];
    if (response.statusCode == 304) {
      return SyncNotModified(etag: responseEtag ?? etag);
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body is Map<String, dynamic>
          ? (body['data'] is Map<String, dynamic>
              ? body['data'] as Map<String, dynamic>
              : body)
          : <String, dynamic>{};
      final signed = data['signedToken'] ?? data['signed_token'] ?? data['token'];
      if (signed is String && signed.isNotEmpty) {
        return SyncSuccess(signedToken: signed, etag: responseEtag);
      }
      throw TwoKeyException(
        TwoKeyErrorCode.invalidResponse,
        'Invalid response from billing server. Try again or report this issue.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw TwoKeyException(
        TwoKeyErrorCode.unauthorized,
        'Billing request failed (HTTP ${response.statusCode}).',
      );
    }
    throw TwoKeyException(
      TwoKeyErrorCode.unknown,
      'Billing request failed (HTTP ${response.statusCode}).',
    );
  }
}
