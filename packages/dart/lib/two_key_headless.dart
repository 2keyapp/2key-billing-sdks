/// Headless (Dart VM, no Flutter) entry: auth, machine AuthN, agent tokens.
///
/// Safe to import from CLIs and daemons — nothing here touches `dart:ui`.
/// Pass your own [BillingAuthStorage]; `SecureBillingAuthStorage` is a stub
/// on the VM.
library;

export 'src/api/agent_token_client.dart';
export 'src/api/billing_api_client.dart';
export 'src/api/delegate_permissions_client.dart';
export 'src/api/machine_authn_client.dart';
export 'src/auth/auth.dart';
export 'src/config/billing_sdk_config.dart';
export 'src/crypto/device_crypto.dart';
export 'src/exceptions/billing_sync_error.dart';
export 'src/logging/sdk_logger.dart';
export 'src/machine/agent_entitlement_flow.dart';
export 'src/machine/device_identity_store.dart';
export 'src/machine/enroll_flow.dart';
export 'src/models/machine_authn/machine_authn.dart';
export 'src/models/models.dart';
