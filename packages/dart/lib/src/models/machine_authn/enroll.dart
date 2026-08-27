import 'capability_credential.dart';

/// Response from `POST /machine-authn/enroll-create`.
class EnrollCreateResult {
  const EnrollCreateResult({
    required this.enrollId,
    required this.pullToken,
    required this.subjectSki,
    required this.status,
    this.kind,
  });

  factory EnrollCreateResult.fromJson(Map<String, dynamic> json) {
    return EnrollCreateResult(
      enrollId: json['enrollId'] as String? ?? '',
      pullToken: json['pullToken'] as String? ?? '',
      subjectSki: json['subjectSki'] as String? ?? '',
      kind: json['kind'] as String?,
      status: json['status'] as String? ?? 'pending',
    );
  }

  final String enrollId;
  final String pullToken;
  final String subjectSki;
  final String? kind;
  final String status;
}

/// Response from `POST /machine-authn/enroll-pull`.
sealed class EnrollPullResult {
  const EnrollPullResult({required this.enrollId, required this.status});

  final String enrollId;
  final String status;
}

class EnrollPullPending extends EnrollPullResult {
  const EnrollPullPending({required super.enrollId})
      : super(status: 'pending');
}

class EnrollPullRejected extends EnrollPullResult {
  const EnrollPullRejected({required super.enrollId})
      : super(status: 'rejected');
}

class EnrollPullApproved extends EnrollPullResult {
  const EnrollPullApproved({
    required super.enrollId,
    this.host,
    this.zone,
    this.kind,
    this.ski,
    this.publicJwk,
    this.certPem,
    this.chainPem,
    this.credential,
    this.hostCertCosign,
    this.seatId,
  }) : super(status: 'approved');

  factory EnrollPullApproved.fromJson(Map<String, dynamic> json) {
    return EnrollPullApproved(
      enrollId: json['enrollId'] as String? ?? '',
      host: json['host'] as String?,
      zone: json['zone'] as String?,
      kind: json['kind'] as String?,
      ski: json['ski'] as String?,
      publicJwk: json['publicJwk'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['publicJwk'] as Map)
          : null,
      certPem: json['certPem'] as String?,
      chainPem: json['chainPem'] as String?,
      credential: json['credential'] is Map<String, dynamic>
          ? CapabilityCredential.fromJson(
              Map<String, dynamic>.from(json['credential'] as Map),
            )
          : null,
      hostCertCosign: json['hostCertCosign'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['hostCertCosign'] as Map)
          : null,
      seatId: json['seatId'] as String?,
    );
  }

  final String? host;
  final String? zone;
  final String? kind;
  final String? ski;
  final Map<String, dynamic>? publicJwk;
  final String? certPem;
  final String? chainPem;
  final CapabilityCredential? credential;
  final Map<String, dynamic>? hostCertCosign;
  final String? seatId;
}

EnrollPullResult enrollPullResultFromJson(Map<String, dynamic> json) {
  final status = json['status'] as String? ?? 'pending';
  final enrollId = json['enrollId'] as String? ?? '';
  return switch (status) {
    'approved' => EnrollPullApproved.fromJson(json),
    'rejected' => EnrollPullRejected(enrollId: enrollId),
    _ => EnrollPullPending(enrollId: enrollId),
  };
}

/// Response from `POST /machine-authn/enroll-approve`.
class EnrollApproveResult {
  const EnrollApproveResult({
    required this.enrollId,
    required this.status,
    this.pullToken,
    this.kind,
    this.seatId,
    this.hostCertCosign,
  });

  factory EnrollApproveResult.fromJson(Map<String, dynamic> json) {
    return EnrollApproveResult(
      enrollId: json['enrollId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      pullToken: json['pullToken'] as String?,
      kind: json['kind'] as String?,
      seatId: json['seatId'] as String?,
      hostCertCosign: json['hostCertCosign'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['hostCertCosign'] as Map)
          : null,
    );
  }

  final String enrollId;
  final String status;
  final String? pullToken;
  final String? kind;
  final String? seatId;
  final Map<String, dynamic>? hostCertCosign;
}

/// Response from enroll-invite create / peek.
class EnrollInviteResult {
  const EnrollInviteResult({required this.raw});

  factory EnrollInviteResult.fromJson(Map<String, dynamic> json) {
    return EnrollInviteResult(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  String? get inviteToken => raw['inviteToken'] as String?;
  String? get kind => raw['kind'] as String?;
}

/// Response from `GET /machine-authn/credential-status`.
class CredentialStatusResult {
  const CredentialStatusResult({required this.raw});

  factory CredentialStatusResult.fromJson(Map<String, dynamic> json) {
    return CredentialStatusResult(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  String? get status => raw['status'] as String?;
  String? get ski => raw['ski'] as String?;
}

/// Response from `GET /machine-authn/platform-root`.
class PlatformRootResult {
  const PlatformRootResult({required this.raw});

  factory PlatformRootResult.fromJson(Map<String, dynamic> json) {
    return PlatformRootResult(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;
}

/// Response from `POST /machine-authn/assert-subset`.
class AssertSubsetResult {
  const AssertSubsetResult({required this.ok, this.message, this.code});

  factory AssertSubsetResult.fromJson(Map<String, dynamic> json) {
    return AssertSubsetResult(
      ok: json['ok'] as bool? ?? false,
      message: json['message'] as String?,
      code: json['code'] as String?,
    );
  }

  final bool ok;
  final String? message;
  final String? code;
}
