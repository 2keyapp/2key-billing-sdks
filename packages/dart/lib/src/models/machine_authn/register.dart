import 'capability_credential.dart';

/// Response from `POST /machine-authn/register`.
class RegisterMachineAuthnResult {
  const RegisterMachineAuthnResult({required this.raw});

  factory RegisterMachineAuthnResult.fromJson(Map<String, dynamic> json) {
    return RegisterMachineAuthnResult(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  String? get entityId => raw['entityId'] as String?;
  bool? get machineAuthnEnabled => raw['machineAuthnEnabled'] as bool?;
}

/// Response from `POST /machine-authn/issue-delegate`.
class IssueDelegateResult {
  const IssueDelegateResult({required this.raw});

  factory IssueDelegateResult.fromJson(Map<String, dynamic> json) {
    return IssueDelegateResult(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  CapabilityCredential? get credential {
    final c = raw['credential'];
    if (c is Map<String, dynamic>) {
      return CapabilityCredential.fromJson(c);
    }
    return null;
  }
}
