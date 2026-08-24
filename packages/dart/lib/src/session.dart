import 'dart:convert';

import 'config.dart';
import 'errors.dart';

/// Persisted account session (matches Rust/TS shape).
class AccountSession {
  AccountSession({
    required this.accountKey,
    this.accessToken,
    this.licenseJwt,
    this.licenseEtag,
    this.payingPartyIdHeader,
  });

  final String accountKey;
  String? accessToken;
  String? licenseJwt;
  String? licenseEtag;
  String? payingPartyIdHeader;

  Map<String, dynamic> toJson() => {
        'account_key': accountKey,
        'access_token': accessToken,
        'license_jwt': licenseJwt,
        'license_etag': licenseEtag,
        'paying_party_id_header': payingPartyIdHeader,
      };

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    return AccountSession(
      accountKey: (json['account_key'] ?? json['accountKey']) as String,
      accessToken: (json['access_token'] ?? json['accessToken']) as String?,
      licenseJwt: (json['license_jwt'] ?? json['licenseJwt']) as String?,
      licenseEtag: (json['license_etag'] ?? json['licenseEtag']) as String?,
      payingPartyIdHeader:
          (json['paying_party_id_header'] ?? json['payingPartyIdHeader'])
              as String?,
    );
  }
}

/// Opaque key-value store (host supplies secure storage).
abstract class SessionStore {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
  Future<void> delete(String key);
}

/// In-memory store for tests / CLI prototypes.
class MemorySessionStore implements SessionStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> get(String key) async => _map[key];

  @override
  Future<void> set(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

String _sanitize(String accountKey) =>
    accountKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

class SessionManager {
  SessionManager({
    required TwoKeySdkConfig config,
    SessionStore? store,
  })  : _config = config.validated(),
        _store = store ?? MemorySessionStore();

  final TwoKeySdkConfig _config;
  final SessionStore _store;

  String _key(String accountKey) =>
      '${_config.storagePrefix}:session:${_sanitize(accountKey)}';

  Future<AccountSession?> load(String accountKey) async {
    final raw = await _store.get(_key(accountKey));
    if (raw == null) return null;
    try {
      return AccountSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      throw TwoKeyException(
        TwoKeyErrorCode.unknown,
        'Corrupt session data',
        detail: '$e',
      );
    }
  }

  Future<void> save(AccountSession session) async {
    await _store.set(_key(session.accountKey), jsonEncode(session.toJson()));
  }

  Future<void> clear(String accountKey) async {
    await _store.delete(_key(accountKey));
  }
}
