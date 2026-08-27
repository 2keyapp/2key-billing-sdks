import 'dart:convert';

import '../api/agent_token_client.dart';
import '../crypto/device_crypto.dart';
import 'device_identity_store.dart';

/// Mint Target Agent entitlement JWT using stored device identity + PoP.
class AgentEntitlementFlow {
  AgentEntitlementFlow({
    required AgentTokenClient tokenClient,
    required DeviceCrypto crypto,
    required DeviceIdentityStore store,
  })  : _tokenClient = tokenClient,
        _crypto = crypto,
        _store = store;

  final AgentTokenClient _tokenClient;
  final DeviceCrypto _crypto;
  final DeviceIdentityStore _store;

  /// Load identity by SKI, sign PoP, mint agent token.
  Future<AgentTokenMintResult> mintFromStore({
    required String ski,
    required String targetIdentity,
    String? privatePem,
  }) async {
    final identity = await _store.load(ski);
    if (identity == null) {
      throw StateError('No stored identity for SKI $ski');
    }
    return mintFromIdentity(
      identity: identity,
      targetIdentity: targetIdentity,
      privatePem: privatePem,
    );
  }

  /// Mint agent token from an in-memory identity.
  Future<AgentTokenMintResult> mintFromIdentity({
    required StoredDeviceIdentity identity,
    required String targetIdentity,
    String? privatePem,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = jsonEncode({'ski': identity.ski, 'ts': ts});
    final pem = privatePem ?? identity.privatePem;
    if (pem == null || pem.isEmpty) {
      throw StateError('privatePem required for agent PoP (not in store)');
    }
    final signature = await _crypto.signJsonB64Url(
      privatePem: pem,
      payloadJson: payload,
    );

    return _tokenClient.mintAgentToken(
      credential: identity.credential,
      proof: {'ts': ts, 'signature': signature},
      targetIdentity: targetIdentity,
    );
  }
}
