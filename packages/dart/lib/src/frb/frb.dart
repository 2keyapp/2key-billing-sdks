/// Vendored flutter_rust_bridge wire for `two-key-core`.
///
/// Full FRB codegen (2.13.x) should replace [FrbWire] with generated stubs under
/// `generated/`. Until then this adapter calls the stable C ABI with the same
/// JSON shapes as `frb_api` in private `two-key-core`.
library;

export 'billing_mode.dart';
export 'frb_wire.dart';
export 'rust_billing_core.dart';
