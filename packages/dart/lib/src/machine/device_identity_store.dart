import 'dart:convert';
import 'dart:io';

/// Persisted device identity (PEM + credential JSON).
class StoredDeviceIdentity {
  const StoredDeviceIdentity({
    required this.ski,
    required this.privateJwk,
    required this.credential,
    this.certPem,
    this.chainPem,
    this.privatePem,
    this.host,
  });

  factory StoredDeviceIdentity.fromJson(Map<String, dynamic> json) {
    return StoredDeviceIdentity(
      ski: json['ski'] as String? ?? '',
      privateJwk: Map<String, dynamic>.from(json['privateJwk'] as Map? ?? {}),
      credential: Map<String, dynamic>.from(json['credential'] as Map? ?? {}),
      certPem: json['certPem'] as String?,
      chainPem: json['chainPem'] as String?,
      privatePem: json['privatePem'] as String?,
      host: json['host'] as String?,
    );
  }

  final String ski;
  final Map<String, dynamic> privateJwk;
  final Map<String, dynamic> credential;
  final String? certPem;
  final String? chainPem;
  final String? privatePem;
  final String? host;

  Map<String, dynamic> toJson() => {
        'ski': ski,
        'privateJwk': privateJwk,
        'credential': credential,
        if (certPem != null) 'certPem': certPem,
        if (chainPem != null) 'chainPem': chainPem,
        if (privatePem != null) 'privatePem': privatePem,
        if (host != null) 'host': host,
      };

  Map<String, dynamic> toCryptoIdentityJson() => {
        'ski': ski,
        'privateJwk': privateJwk,
        'credential': credential,
        if (certPem != null) 'certPem': certPem,
        if (chainPem != null) 'chainPem': chainPem,
      };
}

/// Port for persisting enrolled device material.
abstract class DeviceIdentityStore {
  Future<StoredDeviceIdentity?> load(String ski);
  Future<void> save(StoredDeviceIdentity identity);
  Future<void> delete(String ski);
}

/// In-memory store for tests and ephemeral agents.
class InMemoryDeviceIdentityStore implements DeviceIdentityStore {
  final _bySki = <String, StoredDeviceIdentity>{};

  @override
  Future<void> delete(String ski) async {
    _bySki.remove(ski);
  }

  @override
  Future<StoredDeviceIdentity?> load(String ski) async => _bySki[ski];

  @override
  Future<void> save(StoredDeviceIdentity identity) async {
    _bySki[identity.ski] = identity;
  }
}

/// File-backed store (PEM paths + credential JSON).
class FileDeviceIdentityStore implements DeviceIdentityStore {
  FileDeviceIdentityStore(this.rootDir);

  final String rootDir;

  String _path(String ski) => '$rootDir${Platform.pathSeparator}$ski.json';

  @override
  Future<void> delete(String ski) async {
    final file = File(_path(ski));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  Future<StoredDeviceIdentity?> load(String ski) async {
    final file = File(_path(ski));
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) return null;
    return StoredDeviceIdentity.fromJson(json);
  }

  @override
  Future<void> save(StoredDeviceIdentity identity) async {
    final dir = Directory(rootDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    await File(_path(identity.ski)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(identity.toJson()),
    );
  }
}
