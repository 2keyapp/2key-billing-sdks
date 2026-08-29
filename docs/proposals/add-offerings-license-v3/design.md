# Proposal: Offerings catalog + license payload v3 (SDK)

Parent change: `2key-billing` OpenSpec change-id `add-product-offerings-license-v3` (capabilities: `catalog-offerings`, `catalog-plans`, `license-using-party-token`, `identity/subscription-seat`).

## Why

Using-party hosts must gate features from a cached, verified license without seeing paying-party amounts. Catalog composition moves to product **offerings** and multi-offering **plans**; the SDK must parse payload v3 entitlements and expose a stable gate contract.

## SDK contract

### Startup

1. `BillingSdk.configureFrom(config)`
2. `BillingSession` load persisted account + license JWT
3. Verify offline (ES256, `exp`, optional device SKI)
4. Expose `LicenseEntitlements` from verified claims
5. If online: `syncIfLicenseChanged` (ETag); start poll / foreground sync

Missing or invalid license → empty entitlements (host takes alternate paths).

### `LicenseEntitlements` (proposed API)

| Method | Behavior |
|--------|----------|
| `hasAnyActiveSubscription` | Any sub active/trialing and not past `valid_until` |
| `hasOffering(code)` / `hasAddon(code)` / `hasProduct(code)` | From entitlements / offerings |
| `resourceInt(key)` / `maxDevices()` | Prefer top-level `entitlements` |
| `expiryForOffering` / `earliestExpiry` | From `subscriptions[].valid_until` |
| `allowsDevice(localSki)` | Existing device bind rules |

**Must not** expose or require price/currency for access decisions.

### Payload dual-read

- Prefer `payload_version` 3 (`entitlements`, nested `offerings`).
- Accept v2 during cutover: derive coarse entitlements from `product_id` / `addon_code` / `max_devices` on each subscription (no stacking beyond sum of seat fields).

### Host gate pattern

```
if (entitlements.allows(...)) → paid path
else → alternate / locked / free path (+ catalog/portal for purchase CTA)
```

## Tasks (SDK repo)

- [x] Conformance fixture `license_payload_v3.json`
- [ ] Dart / Rust core / browser parsers + entitlements helpers
- [ ] Session docs: cache-at-start + gate guidance
- [ ] Tests: stacking aggregation trust server entitlements; v2 fallback; no amount fields required

## Status

Server OpenSpec `add-product-offerings-license-v3` is partially applied (schema, issuer v3, catalog attachments, quantity absorb). SDK parse/API and host gates remain.