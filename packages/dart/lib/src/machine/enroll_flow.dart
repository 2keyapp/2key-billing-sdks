import 'dart:async';

import '../api/machine_authn_client.dart';
import '../crypto/device_crypto.dart';
import '../models/machine_authn/machine_authn.dart';
import 'device_identity_store.dart';

/// Target device enrollment: CSR → enroll-create → poll pull → persist.
class MachineEnrollFlow {
  MachineEnrollFlow({
    required MachineAuthnClient http,
    required DeviceCrypto crypto,
    required DeviceIdentityStore store,
    this.pullInterval = const Duration(seconds: 3),
    this.pullTimeout = const Duration(minutes: 15),
  })  : _http = http,
        _crypto = crypto,
        _store = store;

  final MachineAuthnClient _http;
  final DeviceCrypto _crypto;
  final DeviceIdentityStore _store;
  final Duration pullInterval;
  final Duration pullTimeout;

  /// Enroll a machine target: generate CSR locally, create enroll, poll until approved.
  Future<StoredDeviceIdentity> enrollTarget({
    required String payingPartyId,
    required String memberId,
    required String host,
    String kind = 'machine_target',
    String? inviteToken,
    String? platform,
    String? issuerPem,
  }) async {
    final generated = await _crypto.generateKeyAndCsr(host);
    final created = await _http.enrollCreate(
      payingPartyId: payingPartyId,
      memberId: memberId,
      csrPem: generated.csrPem,
      subjectSki: generated.ski,
      publicJwk: generated.publicJwk,
      host: host,
      kind: kind,
      inviteToken: inviteToken,
      platform: platform,
    );

    final approved = await pullUntilApproved(created.pullToken);

    if (issuerPem != null &&
        approved.certPem != null &&
        approved.certPem!.isNotEmpty) {
      final valid = await _crypto.verifyCert(
        leafPem: approved.certPem!,
        issuerPem: issuerPem,
      );
      if (!valid) {
        throw StateError('Issued leaf cert failed issuer verification');
      }
    }

    final identity = StoredDeviceIdentity(
      ski: approved.ski ?? generated.ski,
      privateJwk: generated.privateJwk,
      credential: approved.credential?.toJson() ?? {},
      certPem: approved.certPem,
      chainPem: approved.chainPem,
      host: approved.host ?? host,
    );
    await _store.save(identity);
    return identity;
  }

  /// Poll `enroll-pull` until approved or timeout.
  Future<EnrollPullApproved> pullUntilApproved(String pullToken) async {
    final deadline = DateTime.now().add(pullTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final result = await _http.enrollPull(pullToken: pullToken);
      switch (result) {
        case EnrollPullApproved approved:
          return approved;
        case EnrollPullRejected():
          throw StateError('Enrollment was rejected');
        case EnrollPullPending():
          await Future<void>.delayed(pullInterval);
      }
    }
    throw TimeoutException('Enrollment pull timed out', pullTimeout);
  }

  /// Register org root CA on paying party (admin session on [MachineAuthnClient]).
  Future<RegisterMachineAuthnResult> registerOrg({
    required String payingPartyId,
    required String memberId,
    required String entityId,
    required String package,
    required String rootSki,
    required String caCertPem,
    Map<String, dynamic>? rootCredential,
  }) {
    return _http.register(
      payingPartyId: payingPartyId,
      memberId: memberId,
      entityId: entityId,
      package: package,
      rootSki: rootSki,
      caCertPem: caCertPem,
      rootCredential: rootCredential,
    );
  }
}
