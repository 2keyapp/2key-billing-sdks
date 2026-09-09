/// Resolves social OAuth callback URLs for native billing auth.
///
/// Host apps supply platform URIs; this helper only picks among them.
abstract final class BillingAuthRedirect {
  /// Query param Better Auth puts on `callbackURL` and echoes on `?cookie=`.
  ///
  /// Must stay aligned with `kCallbackNonceParam` in `package:better_auth`.
  static const callbackNonceQueryParam = 'ba_nonce';

  /// True when [actual] is the nonce registered for this sign-in attempt.
  static bool callbackNonceMatches({
    required String? expected,
    required String? actual,
  }) {
    final want = expected?.trim() ?? '';
    final got = actual?.trim() ?? '';
    return want.isNotEmpty && got.isNotEmpty && want == got;
  }

  /// Social sign-in callback (`signInSocial` callbackURL).
  ///
  /// Desktop typically uses a loopback HTTP URL so the browser can show a
  /// success page; mobile uses `{scheme}://auth/callback`.
  static String resolveSocialCallbackUrl({
    required String deepLinkScheme,
    required bool isMobile,
    required String desktopLoopbackUri,
    bool isWeb = false,
  }) {
    if (isWeb || isMobile) {
      return '$deepLinkScheme://auth/callback';
    }
    return desktopLoopbackUri;
  }

  /// OAuth redirect URI for authorize flows that need an absolute callback.
  static String resolveOAuthRedirectUri({
    required bool isMobile,
    required String desktopLoopbackUri,
    required String mobileRedirectUri,
    String? configuredOverride,
    bool isWeb = false,
  }) {
    final configured = configuredOverride?.trim() ?? '';
    if (isWeb || isMobile) {
      if (configured.isNotEmpty) return configured;
      return mobileRedirectUri;
    }
    return desktopLoopbackUri;
  }
}
