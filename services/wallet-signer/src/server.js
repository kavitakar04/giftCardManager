import express from "express";
import { balanceLogContext, checkBalanceRequest } from "./balanceRegistry.js";
import { loadConfig, validateSigningConfig } from "./config.js";
import { generatePkpass, validatePassRequest } from "./passBuilder.js";

const config = loadConfig();
const app = express();

app.use(express.json({ limit: "32kb" }));

app.get("/health", (_request, response) => {
  response.json({ ok: true });
});

app.post("/api/wallet/passes", async (request, response) => {
  const validation = validatePassRequest(request.body);
  if (!validation.ok) {
    response.status(validation.status).json({ error: validation.message });
    return;
  }

  const missingConfig = validateSigningConfig(config);
  if (missingConfig.length > 0) {
    response.status(500).json({ error: `Missing signing configuration: ${missingConfig.join(", ")}` });
    return;
  }

  try {
    const passData = await generatePkpass(request.body, config);
    response
      .status(200)
      .type("application/vnd.apple.pkpass")
      .send(passData);
  } catch (error) {
    console.error("Pass signing failed", {
      serial_number: request.body?.serial_number,
      merchant_display_name: request.body?.merchant_display_name,
      error: error.message
    });
    response.status(500).json({ error: "Pass signing failed." });
  }
});

app.post("/api/balance/check", async (request, response) => {
  try {
    const result = await checkBalanceRequest(request.body);
    if (!result.ok) {
      response.status(result.status).json({ error: result.message });
      return;
    }

    response.status(result.status).json(result.body);
  } catch (error) {
    console.error("Balance check failed", balanceLogContext(request.body, error));
    response.status(500).json({ error: "Balance check failed." });
  }
});

app.listen(config.port, () => {
  console.log(`Wallet signer listening on port ${config.port}`);
});
