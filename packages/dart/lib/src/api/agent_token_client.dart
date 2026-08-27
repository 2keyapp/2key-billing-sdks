import 'dart:convert';

import 'package:http/http.dart' as http;

import 'billing_api_client.dart';

/// Thrown when agent token mint fails.
class AgentTokenException implements Exception {
  AgentTokenException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'AgentTokenException($statusCode): $body';
}

/// Minted Target Agent entitlement token.
class AgentTokenMintResult {
  const AgentTokenMintResult({
    required this.token,
    required this.expiresIn,
    this.tokenType,
  });

  factory AgentTokenMintResult.fromJson(Map<String, dynamic> json) {
    return AgentTokenMintResult(
      token: json['token'] as String? ?? '',
      expiresIn: json['expiresIn'] as int? ?? 0,
      tokenType: json['token_type'] as String? ?? json['tokenType'] as String?,
    );
  }

  final String token;
  final int expiresIn;
  final String? tokenType;
}

/// HTTP client for `POST /api/auth/agent/token` on the Better Auth host.
class AgentTokenClient {
  AgentTokenClient({
    required String authOrigin,
    http.Client? httpClient,
  })  : _baseUrl = _normalizeAuthOrigin(authOrigin),
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  static String _normalizeAuthOrigin(String input) {
    var s = normalizeBillingApiBaseUrl(input.trim());
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// POST `/api/auth/agent/token`
  Future<AgentTokenMintResult> mintAgentToken({
    required Map<String, dynamic> credential,
    required Map<String, dynamic> proof,
    required String targetIdentity,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/agent/token');
    final response = await _http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'credential': credential,
        'proof': proof,
        'targetIdentity': targetIdentity,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentTokenException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AgentTokenException(
        response.statusCode,
        'Expected JSON object response',
      );
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return AgentTokenMintResult.fromJson(data);
    }
    return AgentTokenMintResult.fromJson(decoded);
  }

  void close() => _http.close();
}
