import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

void main() {
  test('TwoKeyCoreFfi.open fails when library missing', () {
    expect(
      () => TwoKeyCoreFfi.open(
        'this_path_definitely_does_not_exist_two_key_core.dll',
      ),
      throwsA(anything),
    );
  });

  test('normalize via FFI when cdylib present', () {
    final candidates = <File>[
      File('../../bin/two_key_core.dll'),
      File('../../bin/libtwo_key_core.dylib'),
      File('../../bin/libtwo_key_core.so'),
    ];
    final dev = Platform.environment['TWOKEY_CORE_DEV_DIR'];
    if (dev != null && dev.isNotEmpty) {
      candidates.addAll([
        File('$dev/target/debug/two_key_core.dll'),
        File('$dev/target/debug/libtwo_key_core.so'),
        File('$dev/target/release/libtwo_key_core.so'),
        File('$dev/target/debug/libtwo_key_core.dylib'),
      ]);
    }
    File? lib;
    for (final f in candidates) {
      if (f.existsSync()) {
        lib = f;
        break;
      }
    }
    if (lib == null) {
      // ignore: avoid_print
      print('skip: fetch/build two-key-core cdylib to enable FFI test');
      return;
    }

    final ffi = TwoKeyCoreFfi.open(lib.absolute.path);
    final normalized = ffi.normalizeApiBaseUrl(
      'https://billing.example.com/api/v1/',
    );
    expect(normalized, 'https://billing.example.com');
  });
}
