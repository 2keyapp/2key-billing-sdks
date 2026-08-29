/// Local keypair for license device binding (`app_client`).
library;

import 'dart:convert';

import '../crypto/device_crypto.dart';
import 'dart_license_device_crypto.dart';
import 'jwk_thumbprint.dart';

/// Stored license-device identity for one account/profile.
class LicenseDeviceIdentity {
  const LicenseDeviceIdentity({
    required this.publicJwk,
    required this.ski,
    this.privateJwk,
    this.friendlyName,
  });

  final Map<String, dynamic> publicJwk;
  final String ski;
  final Map<String, dynamic>? privateJwk;

  /// User-chosen label (unique within using party once bound).
  final String? friendlyName;

  LicenseDeviceIdentity copyWith({
    Map<String, dynamic>? publicJwk,
    String? ski,
    Map<String, dynamic>? privateJwk,
    String? friendlyName,
  }) =>
      LicenseDeviceIdentity(
        publicJwk: publicJwk ?? this.publicJwk,
        ski: ski ?? this.ski,
        privateJwk: privateJwk ?? this.privateJwk,
        friendlyName: friendlyName ?? this.friendlyName,
      );

  Map<String, dynamic> toJson() => {
        'publicJwk': publicJwk,
        'ski': ski,
        if (privateJwk != null) 'privateJwk': privateJwk,
        if (friendlyName != null) 'friendlyName': friendlyName,
      };

  factory LicenseDeviceIdentity.fromJson(Map<String, dynamic> json) {
    final friendly = json['friendlyName'] ?? json['friendly_name'];
    return LicenseDeviceIdentity(
      publicJwk: Map<String, dynamic>.from(json['publicJwk'] as Map),
      ski: json['ski'] as String,
      privateJwk: json['privateJwk'] is Map
          ? Map<String, dynamic>.from(json['privateJwk'] as Map)
          : null,
      friendlyName: friendly is String && friendly.trim().isNotEmpty
          ? friendly.trim()
          : null,
    );
  }
}

/// Generates and persists a device key via a host-provided secure store.
class LicenseDeviceKeystore {
  LicenseDeviceKeystore({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
    DeviceCrypto? crypto,
  })  : _read = read,
        _write = write,
        _crypto = crypto;

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;
  final DeviceCrypto? _crypto;

  String _storageKey(String accountKey) => 'license_device_v1:$accountKey';

  Future<LicenseDeviceIdentity> ensureForAccount(String accountKey) async {
    final existing = await loadForAccount(accountKey);
    if (existing != null) return existing;
    final created = await _generate();
    await persistForAccount(accountKey, created);
    return created;
  }

  Future<LicenseDeviceIdentity?> loadForAccount(String accountKey) async {
    final raw = await _read(_storageKey(accountKey));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return LicenseDeviceIdentity.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Writes [identity] for [accountKey] (e.g. promote local device to a profile).
  Future<void> persistForAccount(
    String accountKey,
    LicenseDeviceIdentity identity,
  ) =>
      _write(_storageKey(accountKey), jsonEncode(identity.toJson()));

  Future<LicenseDeviceIdentity> _generate() async {
    try {
      final crypto = _crypto ??
          (DeviceCrypto.isAvailable ? DeviceCrypto.open() : null);
      if (crypto != null) {
        final generated = await crypto.generateKeyAndCsr(
          'license-device.local',
          commonName: 'license-device',
        );
        final publicJwk = Map<String, dynamic>.from(generated.publicJwk);
        final ski = publicJwk.isNotEmpty
            ? jwkThumbprintSha256(publicJwk)
            : generated.ski;
        return LicenseDeviceIdentity(
          publicJwk: publicJwk,
          ski: ski.isNotEmpty ? ski : generated.ski,
          privateJwk: generated.privateJwk,
        );
      }
    } catch (_) {
      // Fall through to pure-Dart Ed25519 when native core is missing/broken.
    }
    return generateDartLicenseDeviceIdentity();
  }
}
