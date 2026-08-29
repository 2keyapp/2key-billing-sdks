# Proposal: Offerings catalog + license payload v3 (SDK)

Parent change: `2key-billing` OpenSpec change-id `add-product-offerings-license-v3` (capabilities: `catalog-offerings`, `catalog-plans`, `license-using-party-token`, `identity/subscription-seat`).

## Why

Using-party hosts must gate features from a cached, verified license without seeing paying-party amounts. Catalog composition moves to product **offerings** and multi-offering **plans**; the SDK must parse payload v3 entitlements and expose a stable gate contract.

## SDK contract

### Startup

See [host-startup.md](./host-startup.md).

### `LicenseEntitlements` (API)

Primary contract: **Product → Resources → Quantity** (same product summed across offerings/plans).

| Method | Behavior |
|--------|----------|
| `byProduct` | Map productId → resourceKey → quantity |
| `resourceForProduct(productId, key)` | Quantity for one product |
| `resourceInt(key)` / `maxDevices()` | Sum across all products |
| `hasAnyActiveSubscription` | Any sub active/trialing and not past `valid_until` |
| `hasOffering(code)` / `hasAddon(code)` / `hasProduct(id)` | From entitlements / offerings |
| `expiryForOffering` / `expiryForAddon` / `earliestExpiry` | From `subscriptions[].valid_until` |
| `allowsDevice(localSki)` | Existing device bind rules |

Prefer server `entitlements.by_product` when `payload_version >= 3`. **Must not** expose or require price/currency for access decisions.

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
- [x] Dart / Rust core / browser parsers + entitlements helpers
- [x] Session docs: cache-at-start + gate guidance
- [x] Tests: stacking aggregation trust server entitlements; v2 fallback; no amount fields required

## Status

Server + SDK Product→Resources→Quantity contract done. Host gates (secMail 5.x) wired to `payload.entitlements`.

## Non-goals

- Checkout or invoice clients in using-party SDK
- Implementing quantity bump fulfillment (server-only)
