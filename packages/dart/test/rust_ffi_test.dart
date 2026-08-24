import 'dart:io';

import 'package:test/test.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

void main() {
  test('rust backend flag not wired throws without library', () {
    TwoKeyRuntime.licenseBackend = LicenseBackend.rustCore;
    TwoKeyRuntime.nativeLibraryPath =
        'this_path_definitely_does_not_exist_two_key_core.dll';
    expect(
      () => TwoKeyRuntime.ensureBackendAvailable(),
      throwsA(anything),
    );
    TwoKeyRuntime.licenseBackend = LicenseBackend.pureDart;
    TwoKeyRuntime.nativeLibraryPath = null;
    TwoKeyRuntime.resetFfi();
  });

  test('rust ffi normalize when cdylib present', () {
    final candidates = [
      File('../../target/debug/two_key_core.dll'),
      File('../../target/debug/libtwo_key_core.dylib'),
      File('../../target/debug/libtwo_key_core.so'),
      File('../../target/release/two_key_core.dll'),
      File('../../target/release/libtwo_key_core.so'),
    ];
    File? lib;
    for (final f in candidates) {
      if (f.existsSync()) {
        lib = f;
        break;
      }
    }
    if (lib == null) {
      // ignore: avoid_print
      print('skip: build two-key-core cdylib to enable FFI test');
      return;
    }

    TwoKeyRuntime.resetFfi();
    TwoKeyRuntime.licenseBackend = LicenseBackend.rustCore;
    TwoKeyRuntime.nativeLibraryPath = lib.absolute.path;
    try {
      final normalized = TwoKeyRuntime.ffi.normalizeApiBaseUrl(
        'https://billing.example.com/api/v1/',
      );
      expect(normalized, 'https://billing.example.com');
    } finally {
      TwoKeyRuntime.licenseBackend = LicenseBackend.pureDart;
      TwoKeyRuntime.nativeLibraryPath = null;
      TwoKeyRuntime.resetFfi();
    }
  });
}
