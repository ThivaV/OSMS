// Settings from the environment. Names (never values) are listed in ../.env.example;
// `make env` creates a local .env with a fresh secret.

import { fileURLToPath } from "node:url";

export type Config = {
  production: boolean;
  /** Where this service is reached; also the issuer of the API tokens. */
  baseURL: string;
  host: string;
  port: number;
  secret: string;
  databasePath: string;
  /** The app's origins (Flutter web), trusted for redirects and CORS. */
  appOrigins: string[];
  /** The `aud` of the tokens the Python API accepts. */
  apiAudience: string;
  /** Where the browser hands a signed-in session back to the desktop app. */
  nativeCallback: string;
  google: { clientId: string; clientSecret: string } | null;
  /** Development only: sign in with an emailed link that is printed to the log. */
  devSignIn: boolean;
};

const defaultDatabase = fileURLToPath(new URL("../../data/auth.db", import.meta.url));

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const production = env.NODE_ENV === "production";
  const devSignIn = env.OSMS_DEV_SIGN_IN === "1";
  if (production && devSignIn) {
    throw new Error("OSMS_DEV_SIGN_IN is for local development and must be off in production.");
  }

  const secret = env.BETTER_AUTH_SECRET ?? "";
  if (secret.length < 32) {
    throw new Error("BETTER_AUTH_SECRET is missing or shorter than 32 characters. Run `make env`.");
  }

  const { GOOGLE_CLIENT_ID: clientId, GOOGLE_CLIENT_SECRET: clientSecret } = env;
  return {
    production,
    baseURL: env.BETTER_AUTH_URL || "http://localhost:3000",
    host: env.AUTH_HOST || "127.0.0.1",
    port: Number(env.AUTH_PORT || 3000),
    secret,
    databasePath: env.AUTH_DATABASE_PATH || defaultDatabase,
    appOrigins: (env.OSMS_APP_ORIGINS || "http://localhost:8080")
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
    apiAudience: env.OSMS_API_AUDIENCE || "osms-api",
    nativeCallback: "osms://auth",
    google: clientId && clientSecret ? { clientId, clientSecret } : null,
    devSignIn,
  };
}
