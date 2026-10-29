// Better Auth for OSMS: Google sign-in, sessions in SQLite (data/auth.db), and the
// short-lived tokens the Python API checks against /api/auth/jwks.

import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { betterAuth, type BetterAuthOptions } from "better-auth";
import { getMigrations } from "better-auth/db/migration";
import { bearer, jwt, magicLink, oneTimeToken } from "better-auth/plugins";
import type { Config } from "./config.ts";

export function openDatabase(path: string): DatabaseSync {
  if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  // Same settings as the API's SQLite: readers never block, waits instead of failing.
  db.exec("PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000; PRAGMA foreign_keys = ON;");
  return db;
}

function authOptions(config: Config, log: (line: string) => void) {
  return {
    appName: "OSMS",
    baseURL: config.baseURL,
    secret: config.secret,
    database: openDatabase(config.databasePath),
    trustedOrigins: config.appOrigins,
    telemetry: { enabled: false },
    socialProviders: config.google
      ? {
          google: {
            clientId: config.google.clientId,
            clientSecret: config.google.clientSecret,
            prompt: "select_account",
          },
        }
      : {},
    // The app deletes the reader's OSMS data through the API first, then this.
    user: { deleteUser: { enabled: true } },
    plugins: [
      // The desktop app has no cookie jar: it sends its session as a bearer token.
      bearer({ requireSignature: true }),
      jwt({
        jwt: {
          issuer: config.baseURL,
          audience: config.apiAudience,
          expirationTime: "15m",
          // Only what the API needs to create the reader's row; `sub` is the user id.
          definePayload: ({ user }) => ({ email: user.email, name: user.name }),
        },
      }),
      // Hands a browser session to the desktop app. Minted only by /native/done.
      oneTimeToken({ expiresIn: 3, storeToken: "hashed", disableClientRequest: true }),
      ...(config.devSignIn
        ? [
            magicLink({
              expiresIn: 300,
              // Development only: nothing is emailed. The link goes to this log, and the
              // address never does (logs use ids, not emails).
              sendMagicLink: async ({ url }) => log(`[dev sign-in] Open this link to sign in: ${url}`),
            }),
          ]
        : []),
    ],
  } satisfies BetterAuthOptions;
}

/** Creates the tables Better Auth needs (first start, upgrades), then the auth instance. */
export async function createAuth(config: Config, log: (line: string) => void = console.log) {
  const options = authOptions(config, log);
  const { runMigrations } = await getMigrations(options);
  await runMigrations();
  return betterAuth(options);
}

export type Auth = Awaited<ReturnType<typeof createAuth>>;
