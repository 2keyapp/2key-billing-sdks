import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logging/sdk_logger.dart';
import 'billing_auth_exception.dart';
import 'billing_auth_tokens.dart';

/// Mints billing API JWTs via Better Auth `GET /api/auth/token` (JWT plugin).
class BillingApiTokenMint {
  BillingApiTokenMint({
    required this.authBaseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String authBaseUrl;
  final http.Client _http;

  /// Exchanges an active Better Auth session cookie for a billing API JWT.
  Future<BillingAuthTokens> mintFromSessionCookie(String sessionCookie) async {
    final cookie = sessionCookie.trim();
    if (cookie.isEmpty) {
      throw const BillingAuthException('No session cookie — sign in first');
    }

    final uri = Uri.parse('$authBaseUrl/token');
    final response = await _http.get(
      uri,
      headers: {
        'accept': 'application/json',
        'cookie': cookie,
      },
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw BillingAuthException(
        'Invalid token response (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = body['code'] as String?;
      if (code == 'ORG_SLUG_REQUIRED' || response.statusCode == 403) {
        if (code == 'ORG_SLUG_REQUIRED' ||
            (body['message'] as String? ?? '').contains('ORG_SLUG_REQUIRED') ||
            (body['message'] as String? ?? '').toLowerCase().contains('slug')) {
          throw BillingOrgSlugRequiredException(
            body['message'] as String? ??
                'Bind an organization slug before minting a billing token',
          );
        }
      }
      throw BillingAuthException(
        body['message'] as String? ??
            body['error'] as String? ??
            'Token mint failed (${response.statusCode})',
        statusCode: response.statusCode,
        code: code,
      );
    }

    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw const BillingAuthException('Token response missing token field');
    }

    BillingSdkLogger.info('BillingApiTokenMint: billing JWT minted');
    return BillingAuthTokens.fromJwtPluginToken(token);
  }

  /// Binds the session to an organization slug (`POST /organization/bind`).
  Future<({String organizationId, String slug, String name, String role})>
      bindFromSessionCookie(String sessionCookie, {String slug = 'me'}) async {
    final cookie = sessionCookie.trim();
    if (cookie.isEmpty) {
      throw const BillingAuthException('No session cookie — sign in first');
    }

    final trimmed = slug.trim().isEmpty ? 'me' : slug.trim();
    final uri = Uri.parse('$authBaseUrl/organization/bind');
    final response = await _http.post(
      uri,
      headers: {
        'accept': 'application/json',
        'content-type': 'application/json',
        'cookie': cookie,
      },
      body: jsonEncode({'slug': trimmed}),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw BillingAuthException(
        'Invalid bind response (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BillingAuthException(
        body['message'] as String? ??
            body['error'] as String? ??
            'Organization bind failed (${response.statusCode})',
        statusCode: response.statusCode,
        code: body['code'] as String?,
      );
    }

    final organizationId = body['organizationId'] as String?;
    final boundSlug = body['slug'] as String?;
    final name = body['name'] as String?;
    final role = body['role'] as String?;
    if (organizationId == null || boundSlug == null || role == null) {
      throw const BillingAuthException(
        'Bind response was missing organization fields',
      );
    }

    return (
      organizationId: organizationId,
      slug: boundSlug,
      name: name ?? boundSlug,
      role: role,
    );
  }

  void close() => _http.close();
}
