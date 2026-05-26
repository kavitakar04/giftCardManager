import assert from "node:assert/strict";
import test from "node:test";
import { buildPassJson, validatePassRequest } from "../src/passBuilder.js";

const config = {
  passTypeIdentifier: "pass.com.example.digitalcards",
  teamIdentifier: "ABCDE12345",
  organizationName: "Digital Cards"
};

test("validates required request fields", () => {
  const result = validatePassRequest({});
  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
});

test("rejects unsupported barcode formats", () => {
  const result = validatePassRequest({
    serial_number: "serial-1",
    merchant_display_name: "Subway",
    card_number_last4: "1234",
    barcode_value: "1234567890",
    barcode_format: "ean13",
    currency: "USD"
  });

  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
});

test("rejects non-string pin", () => {
  const result = validatePassRequest({
    serial_number: "serial-1",
    merchant_display_name: "Subway",
    card_number_last4: "1234",
    barcode_value: "1234567890",
    barcode_format: "code128",
    currency: "USD",
    pin: 9999
  });

  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
});

test("builds store card pass json with pin", () => {
  const passJson = buildPassJson({
    serial_number: "serial-1",
    merchant_display_name: "Subway",
    card_number_last4: "1234",
    barcode_value: "1234567890",
    barcode_format: "code128",
    current_balance_minor_units: 1842,
    currency: "USD",
    redemption_notes: "Show this barcode in store.",
    pin: "9999"
  }, config);

  const encoded = JSON.stringify(passJson);
  assert.equal(passJson.storeCard.primaryFields[0].value, "$18.42");
  assert.deepEqual(passJson.storeCard.auxiliaryFields[1], {
    key: "pin",
    label: "PIN",
    value: "9999"
  });
  assert.equal(passJson.barcode.format, "PKBarcodeFormatCode128");
  assert.equal(encoded.includes("9999"), true);
});
