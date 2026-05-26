import assert from "node:assert/strict";
import test from "node:test";
import { balanceLogContext, checkBalanceRequest, validateBalanceCheckRequest } from "../src/balanceRegistry.js";

test("balance check rejects missing provider id", () => {
  const result = validateBalanceCheckRequest({
    merchant_id: "target",
    card_number: "123456789012345",
    access_code: "99999999"
  });

  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
  assert.match(result.message, /provider_id/);
});

test("balance check returns typed unsupported result for official web providers", async () => {
  const result = await checkBalanceRequest(
    {
      merchant_id: "target",
      provider_id: "target-official-web",
      card_number: "123456789012345",
      access_code: "99999999",
      consent_version: "2026-05-26"
    },
    new Date("2026-05-26T12:00:00.000Z")
  );

  assert.equal(result.ok, true);
  assert.equal(result.status, 200);
  assert.equal(result.body.status, "unsupported_auto_refresh");
  assert.equal(result.body.balance_minor_units, null);
  assert.equal(result.body.currency, "USD");
  assert.equal(result.body.checked_at, "2026-05-26T12:00:00.000Z");
  assert.match(result.body.provider_message, /Automatic balance refresh is not supported for Target/);
});

test("balance log context excludes credentials", () => {
  const context = balanceLogContext(
    {
      merchant_id: "target",
      provider_id: "target-official-web",
      card_number: "123456789012345",
      pin: "9999",
      access_code: "99999999",
      claim_code: "CLAIM-CODE"
    },
    new Error("boom")
  );

  const encoded = JSON.stringify(context);
  assert.equal(encoded.includes("123456789012345"), false);
  assert.equal(encoded.includes("9999"), false);
  assert.equal(encoded.includes("CLAIM-CODE"), false);
  assert.deepEqual(context, {
    merchant_id: "target",
    provider_id: "target-official-web",
    error: "boom"
  });
});
