/// Shared error codes (snake_case) — keep in sync with docs/error-codes.md.
enum TwoKeyErrorCode {
  config,
  network,
  unauthorized,
  offline,
  licenseInvalid,
  licenseExpired,
  licenseMalformed,
  notModified,
  invalidResponse,
  unknown,
}

extension TwoKeyErrorCodeX on TwoKeyErrorCode {
  String get wire {
    return switch (this) {
      TwoKeyErrorCode.config => 'config',
      TwoKeyErrorCode.network => 'network',
      TwoKeyErrorCode.unauthorized => 'unauthorized',
      TwoKeyErrorCode.offline => 'offline',
      TwoKeyErrorCode.licenseInvalid => 'license_invalid',
      TwoKeyErrorCode.licenseExpired => 'license_expired',
      TwoKeyErrorCode.licenseMalformed => 'license_malformed',
      TwoKeyErrorCode.notModified => 'not_modified',
      TwoKeyErrorCode.invalidResponse => 'invalid_response',
      TwoKeyErrorCode.unknown => 'unknown',
    };
  }
}

class TwoKeyException implements Exception {
  TwoKeyException(this.code, this.message, {this.detail});

  final TwoKeyErrorCode code;
  final String message;
  final String? detail;

  @override
  String toString() => '${code.wire}: $message';
}
