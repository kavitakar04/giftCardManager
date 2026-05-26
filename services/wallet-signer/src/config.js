export function loadConfig(env = process.env) {
  return {
    port: Number(env.PORT || 3000),
    passTypeIdentifier: env.PASS_TYPE_IDENTIFIER || "pass.com.example.digitalcards",
    teamIdentifier: env.TEAM_IDENTIFIER || "ABCDE12345",
    organizationName: env.ORGANIZATION_NAME || "Digital Cards",
    serviceBaseURL: env.SERVICE_BASE_URL || "http://localhost:3000",
    signerCertPath: env.SIGNER_CERT_PATH,
    signerKeyPath: env.SIGNER_KEY_PATH,
    signerKeyPassword: env.SIGNER_KEY_PASSWORD || "",
    wwdrCertPath: env.WWDR_CERT_PATH
  };
}

export function validateSigningConfig(config) {
  const missing = [];
  if (!config.signerCertPath) missing.push("SIGNER_CERT_PATH");
  if (!config.signerKeyPath) missing.push("SIGNER_KEY_PATH");
  if (!config.wwdrCertPath) missing.push("WWDR_CERT_PATH");
  return missing;
}
