const unsupportedAutoMessage = (provider) =>
  `Automatic balance refresh is not supported for ${provider.display_name}. Open the official lookup page or enter the balance manually.`;

export const balanceProviderRegistry = new Map([
  [
    "subway-official-web",
    {
      provider_id: "subway-official-web",
      merchant_id: "subway",
      display_name: "Subway",
      capability: "official_web",
      currency: "USD"
    }
  ],
  [
    "starbucks-official-web",
    {
      provider_id: "starbucks-official-web",
      merchant_id: "starbucks",
      display_name: "Starbucks",
      capability: "official_web",
      currency: "USD"
    }
  ],
  [
    "target-official-web",
    {
      provider_id: "target-official-web",
      merchant_id: "target",
      display_name: "Target",
      capability: "official_web",
      currency: "USD"
    }
  ],
  [
    "amazon-official-web",
    {
      provider_id: "amazon-official-web",
      merchant_id: "amazon",
      display_name: "Amazon",
      capability: "official_web",
      currency: "USD"
    }
  ]
]);

export function validateBalanceCheckRequest(body) {
  const missing = [];
  if (typeof body?.merchant_id !== "string" || body.merchant_id.trim() === "") {
    missing.push("merchant_id");
  }
  if (typeof body?.provider_id !== "string" || body.provider_id.trim() === "") {
    missing.push("provider_id");
  }

  if (missing.length > 0) {
    return { ok: false, status: 400, message: `Missing required fields: ${missing.join(", ")}` };
  }

  return { ok: true };
}

export async function checkBalanceRequest(body, now = new Date()) {
  const validation = validateBalanceCheckRequest(body);
  if (!validation.ok) {
    return validation;
  }

  const provider = balanceProviderRegistry.get(body.provider_id);
  if (!provider || provider.merchant_id !== body.merchant_id) {
    return {
      ok: false,
      status: 404,
      message: "Balance provider is not configured for this merchant."
    };
  }

  if (provider.capability !== "backend_auto" || typeof provider.check_balance !== "function") {
    return {
      ok: true,
      status: 200,
      body: {
        balance_minor_units: null,
        currency: provider.currency,
        status: "unsupported_auto_refresh",
        checked_at: now.toISOString(),
        provider_message: unsupportedAutoMessage(provider)
      }
    };
  }

  return provider.check_balance(body, now);
}

export function balanceLogContext(body, error) {
  return {
    merchant_id: typeof body?.merchant_id === "string" ? body.merchant_id : undefined,
    provider_id: typeof body?.provider_id === "string" ? body.provider_id : undefined,
    error: error?.message
  };
}
