/// Local keypair for license device binding (`app_client`).
library;

import 'dart:convert';

import '../crypto/device_crypto.dart';

/// Stored license-device identity for one account/profile.
class LicenseDeviceIdentity {
  const LicenseDeviceIdentity({
    required this.publicJwk,
    required this.ski,
    this.privateJwk,
  });

  final Map<String, dynamic> publicJwk;
  final String ski;
  final Map<String, dynamic>? privateJwk;

  Map<String, dynamic> toJson() => {
        'publicJwk': publicJwk,
        'ski': ski,
        if (privateJwk != null) 'privateJwk': privateJwk,
      };

  factory LicenseDeviceIdentity.fromJson(Map<String, dynamic> json) {
    return LicenseDeviceIdentity(
      publicJwk: Map<String, dynamic>.from(json['publicJwk'] as Map),
      ski: json['ski'] as String,
      privateJwk: json['privateJwk'] is Map
          ? Map<String, dynamic>.from(json['privateJwk'] as Map)
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
    await _write(_storageKey(accountKey), jsonEncode(created.toJson()));
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

  Future<LicenseDeviceIdentity> _generate() async {
    final crypto = _crypto ??
        (DeviceCrypto.isAvailable ? DeviceCrypto.open() : null);
    if (crypto != null) {
      final generated = await crypto.generateKeyAndCsr(
        'license-device.local',
        commonName: 'license-device',
      );
      return LicenseDeviceIdentity(
        publicJwk: generated.publicJwk,
        ski: generated.ski,
        privateJwk: generated.privateJwk,
      );
    }
    throw StateError(
      'DeviceCrypto native library unavailable; cannot generate license device key',
    );
  }
}
