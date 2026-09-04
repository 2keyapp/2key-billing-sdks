# Host: license cache at start + feature gates

Using-party apps (e.g. Scomm) should treat the signed license as offline entitlement truth. Amounts stay in the plan catalog / portal only.

## Startup sequence

```dart
await BillingSdk.configureFrom(config);

final session = BillingSession(store: secureStore, mode: BillingMode.online);
await session.loadAccount(accountKey); // restore + verify cached JWT

final entitlements = session.accountSession?.licensePayload?.entitlements;
// Paint UI immediately from entitlements (or empty → free/alternate paths)

if (online) {
  unawaited(session.syncIfLicenseChanged(accountKey: accountKey));
  session.startLicensePolling(accountKey: accountKey); // 6 hours
}
```

On foreground: `session.onAppForeground(accountKey: accountKey)`.

## Gate pattern

```dart
final e = payload?.entitlements;
// Product → Resources → Quantity (sums same product across offerings/plans)
final devices = e?.resourceForProduct('prod_mail', 'max_devices') ?? 0;
if (e != null && e.hasAddon('ai_assistant') && e.hasAnyActiveSubscription) {
  return PaidFeature(maxDevices: devices);
}
return LockedOrFreeAlternate(
  expiresAt: e?.expiryForAddon('ai_assistant') ?? e?.earliestExpiry(),
  onPurchase: openPortalCatalog, // prices from GET /plans, not license
);
```

Useful queries: `byProduct`, `resourceForProduct`, `hasOffering`, `hasProduct`, `maxDevices()`, `earliestExpiry()`, `allowsDevice(localSki)`.

## Payload versions

- Prefer server `entitlements` when `payload_version >= 3`.
- v2 dual-read derives coarse limits from seat `max_devices` / `addon_code` × `quantity`.
