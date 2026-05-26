# Digital Cards Wallet Signer

Minimal Node service that signs static Apple Wallet `storeCard` passes for Phase 1.

## Local Setup

```sh
npm install
cp .env.example .env
npm start
```

Required certificate files:

- Pass Type ID certificate as PEM
- Pass Type ID private key as PEM
- Apple WWDR certificate as PEM

The Wallet API accepts an optional gift card PIN and renders it on the pass when present.

Balance checks are only routed to registered providers. The first merchant catalog uses official web lookup flows, so `/api/balance/check` returns `unsupported_auto_refresh` until an allowed backend provider is added. Do not log card numbers, PINs, access codes, claim codes, or raw provider responses.

## API

```text
POST /api/wallet/passes
Content-Type: application/json
Accept: application/vnd.apple.pkpass
```

Response:

```text
200 application/vnd.apple.pkpass
```

```text
POST /api/balance/check
Content-Type: application/json
Accept: application/json
```

Response for the current official-web providers:

```json
{
  "balance_minor_units": null,
  "currency": "USD",
  "status": "unsupported_auto_refresh",
  "checked_at": "2026-05-26T12:00:00.000Z",
  "provider_message": "Automatic balance refresh is not supported for Target. Open the official lookup page or enter the balance manually."
}
```
