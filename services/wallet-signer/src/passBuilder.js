import crypto from "node:crypto";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const DEFAULT_ICON_PNG_BASE64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADgQGFAe8N3wAAAABJRU5ErkJggg==";

const passkitBarcodeFormats = new Map([
  ["qr", "PKBarcodeFormatQR"],
  ["pdf417", "PKBarcodeFormatPDF417"],
  ["aztec", "PKBarcodeFormatAztec"],
  ["code128", "PKBarcodeFormatCode128"]
]);

export function validatePassRequest(body) {
  const required = [
    "serial_number",
    "merchant_display_name",
    "card_number_last4",
    "barcode_value",
    "barcode_format",
    "currency"
  ];
  const missing = required.filter((field) => typeof body?.[field] !== "string" || body[field].trim() === "");
  if (missing.length > 0) {
    return { ok: false, status: 400, message: `Missing required fields: ${missing.join(", ")}` };
  }
  if (!passkitBarcodeFormats.has(body.barcode_format)) {
    return { ok: false, status: 400, message: "Unsupported barcode format." };
  }
  if (
    body.current_balance_minor_units !== null &&
    body.current_balance_minor_units !== undefined &&
    !Number.isInteger(body.current_balance_minor_units)
  ) {
    return { ok: false, status: 400, message: "current_balance_minor_units must be an integer or null." };
  }
  if (body.pin !== null && body.pin !== undefined && typeof body.pin !== "string") {
    return { ok: false, status: 400, message: "pin must be a string or null." };
  }
  return { ok: true };
}

export function buildPassJson(request, config) {
  const balanceLabel = formatBalance(request.current_balance_minor_units, request.currency);
  const barcodeFormat = passkitBarcodeFormats.get(request.barcode_format);
  const pin = typeof request.pin === "string" ? request.pin.trim() : "";
  const auxiliaryFields = [
    {
      key: "ending",
      label: "Card",
      value: `Ending ${request.card_number_last4}`
    }
  ];

  if (pin) {
    auxiliaryFields.push({
      key: "pin",
      label: "PIN",
      value: pin
    });
  }

  return {
    formatVersion: 1,
    passTypeIdentifier: config.passTypeIdentifier,
    serialNumber: request.serial_number,
    teamIdentifier: config.teamIdentifier,
    organizationName: config.organizationName,
    description: `${request.merchant_display_name} Gift Card`,
    logoText: request.merchant_display_name,
    foregroundColor: "rgb(255, 255, 255)",
    backgroundColor: "rgb(31, 41, 55)",
    labelColor: "rgb(229, 231, 235)",
    storeCard: {
      primaryFields: [
        {
          key: "balance",
          label: "Balance",
          value: balanceLabel
        }
      ],
      secondaryFields: [
        {
          key: "merchant",
          label: "Merchant",
          value: request.merchant_display_name
        }
      ],
      auxiliaryFields,
      backFields: [
        {
          key: "redemption",
          label: "Redemption",
          value: request.redemption_notes || "Show this barcode in store or use the saved card number for checkout."
        }
      ]
    },
    barcode: {
      message: request.barcode_value,
      format: barcodeFormat,
      messageEncoding: "iso-8859-1",
      altText: `Ending ${request.card_number_last4}`
    },
    barcodes: [
      {
        message: request.barcode_value,
        format: barcodeFormat,
        messageEncoding: "iso-8859-1",
        altText: `Ending ${request.card_number_last4}`
      }
    ]
  };
}

export async function generatePkpass(request, config) {
  const tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), "digital-cards-pass-"));
  const passDir = path.join(tempRoot, "pass");
  const outputPath = path.join(tempRoot, `${request.serial_number}.pkpass`);

  try {
    await fs.mkdir(passDir, { recursive: true });
    await writePassFiles(passDir, request, config);
    await signManifest(passDir, config);
    await zipPass(passDir, outputPath);
    return await fs.readFile(outputPath);
  } finally {
    await fs.rm(tempRoot, { recursive: true, force: true });
  }
}

async function writePassFiles(passDir, request, config) {
  const passJson = buildPassJson(request, config);
  await fs.writeFile(path.join(passDir, "pass.json"), JSON.stringify(passJson, null, 2));

  const icon = Buffer.from(DEFAULT_ICON_PNG_BASE64, "base64");
  await fs.writeFile(path.join(passDir, "icon.png"), icon);
  await fs.writeFile(path.join(passDir, "icon@2x.png"), icon);
  await fs.writeFile(path.join(passDir, "logo.png"), icon);
  await fs.writeFile(path.join(passDir, "logo@2x.png"), icon);

  const manifest = await buildManifest(passDir);
  await fs.writeFile(path.join(passDir, "manifest.json"), JSON.stringify(manifest, null, 2));
}

async function buildManifest(passDir) {
  const entries = await fs.readdir(passDir);
  const manifest = {};

  for (const entry of entries) {
    if (entry === "manifest.json" || entry === "signature") continue;
    const filePath = path.join(passDir, entry);
    const stat = await fs.stat(filePath);
    if (!stat.isFile()) continue;
    const contents = await fs.readFile(filePath);
    manifest[entry] = crypto.createHash("sha1").update(contents).digest("hex");
  }

  return manifest;
}

async function signManifest(passDir, config) {
  const args = [
    "smime",
    "-binary",
    "-sign",
    "-certfile",
    config.wwdrCertPath,
    "-signer",
    config.signerCertPath,
    "-inkey",
    config.signerKeyPath,
    "-in",
    path.join(passDir, "manifest.json"),
    "-out",
    path.join(passDir, "signature"),
    "-outform",
    "DER"
  ];

  if (config.signerKeyPassword) {
    args.push("-passin", `pass:${config.signerKeyPassword}`);
  }

  await execFileAsync("openssl", args);
}

async function zipPass(passDir, outputPath) {
  await execFileAsync("zip", ["-qr", outputPath, "."], { cwd: passDir });
}

function formatBalance(minorUnits, currency) {
  if (minorUnits === null || minorUnits === undefined) {
    return "Balance not entered";
  }
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency
  }).format(minorUnits / 100);
}
