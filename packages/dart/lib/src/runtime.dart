/// Dual-path backend selection for license/session logic.
///
/// `pureDart` — current interim implementation in this package.
/// `rustCore` — flutter_rust_bridge → `two-key-core` (not wired yet).
enum LicenseBackend {
  pureDart,
  rustCore,
}

/// Global toggle for dual-path experiments (default pure Dart).
class TwoKeyRuntime {
  TwoKeyRuntime._();

  static LicenseBackend licenseBackend = LicenseBackend.pureDart;

  /// Whether FRB/Rust path is requested (throws until bindings ship).
  static void ensureBackendAvailable() {
    if (licenseBackend == LicenseBackend.rustCore) {
      throw UnsupportedError(
        'LicenseBackend.rustCore is not wired yet. '
        'See bindings/README.md and docs/proposals/add-rust-core-sdk/tasks.md §3–4.',
      );
    }
  }
}
