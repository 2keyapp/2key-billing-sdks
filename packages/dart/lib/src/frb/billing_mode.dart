/// Billing connectivity mode for [BillingSession].
///
/// Hosts (e.g. SComm) set this instead of inventing parallel online/offline
/// flags. Auth session polling is controlled separately via
/// [BillingAuthClient.setOnline].
enum BillingMode {
  /// Restore / verify cached license JWT only (no license HTTP).
  offline,

  /// Allow bootstrap + license sync (+ optional poll when entitlements exist).
  online,
}
