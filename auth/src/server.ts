// The auth service's HTTP server: Better Auth under /api/auth/, plus the few routes
// OSMS adds around it (which providers are on, and the desktop app's hand-off).

import { createHash } from "node:crypto";
import { createServer as createHttpServer, type IncomingMessage, type ServerResponse } from "node:http";
import { fromNodeHeaders, toNodeHandler } from "better-auth/node";
import { createAuth } from "./auth.ts";
import type { Config } from "./config.ts";

/**
 * The desktop app signs in in the reader's own browser and waits on the loopback
 * interface for the result (RFC 8252). Only that exact shape of address is accepted.
 */
const LOOPBACK = /^http:\/\/127\.0\.0\.1:(\d{4,5})\/callback\?state=[A-Za-z0-9_-]{16,128}$/;

/** Ties a hand-off to the browser that started it, so another site can't trigger one. */
const FLOW_COOKIE = "osms_native_flow";

export function loopbackAddress(value: string | null): string | null {
  const port = value ? LOOPBACK.exec(value)?.[1] : undefined;
  return port && Number(port) >= 1024 && Number(port) <= 65535 ? value : null;
}

function flowId(returnTo: string): string {
  return createHash("sha256").update(returnTo).digest("base64url");
}

function cookie(req: IncomingMessage, name: string): string | undefined {
  for (const part of (req.headers.cookie ?? "").split(";")) {
    const [key, ...value] = part.trim().split("=");
    if (key === name) return value.join("=");
  }
  return undefined;
}

function withParams(address: string, params: Record<string, string>): string {
  const url = new URL(address);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return url.toString();
}

export async function createServer(config: Config, log: (line: string) => void = console.log) {
  const auth = await createAuth(config, log);
  const handleAuth = toNodeHandler(auth);

  function json(res: ServerResponse, status: number, body: unknown) {
    res.writeHead(status, { "Content-Type": "application/json" }).end(JSON.stringify(body));
  }

  function redirect(res: ServerResponse, location: string, cookies: string[] = []) {
    res.writeHead(302, { Location: location, "Set-Cookie": cookies, "Cache-Control": "no-store" }).end();
  }

  /** CORS for the app's own origins only. Returns false for a browser request from anywhere else. */
  function cors(req: IncomingMessage, res: ServerResponse): boolean {
    const origin = req.headers.origin;
    if (!origin) return true;
    if (!config.appOrigins.includes(origin)) return false;
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Access-Control-Allow-Credentials", "true");
    res.setHeader("Access-Control-Allow-Headers", "content-type, authorization");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Expose-Headers", "set-auth-token");
    res.setHeader("Vary", "Origin");
    return true;
  }

  const secure = config.baseURL.startsWith("https://") ? "; Secure" : "";
  const flowCookie = (value: string, maxAge: number) =>
    `${FLOW_COOKIE}=${value}; Path=/native; HttpOnly; SameSite=Lax; Max-Age=${maxAge}${secure}`;

  /** Desktop app, step 1: the reader's browser lands here and goes on to Google. */
  async function nativeSignIn(url: URL, req: IncomingMessage, res: ServerResponse) {
    const returnTo = loopbackAddress(url.searchParams.get("return_to"));
    if (!returnTo) return json(res, 400, { error: "The desktop app's return address is missing or not allowed." });
    if (url.searchParams.get("provider") !== "google" || !config.google) {
      return redirect(res, withParams(returnTo, { error: "google_off" }));
    }
    const back = encodeURIComponent(returnTo);
    const response = await auth.api.signInSocial({
      body: {
        provider: "google",
        callbackURL: `${config.baseURL}/native/done?return_to=${back}`,
        errorCallbackURL: `${config.baseURL}/native/error?return_to=${back}`,
      },
      headers: fromNodeHeaders(req.headers),
      asResponse: true,
    });
    const { url: providerURL } = (await response.json()) as { url?: string };
    if (!providerURL) return json(res, 502, { error: "Could not start Google sign-in." });
    redirect(res, providerURL, [...response.headers.getSetCookie(), flowCookie(flowId(returnTo), 600)]);
  }

  /** Desktop app, step 2: signed in. Send the app a one-time token it trades for a session. */
  async function nativeDone(url: URL, req: IncomingMessage, res: ServerResponse) {
    const returnTo = loopbackAddress(url.searchParams.get("return_to"));
    if (!returnTo) return json(res, 400, { error: "The desktop app's return address is missing or not allowed." });
    const done = [flowCookie("", 0)];
    // Only a sign-in this browser started from the desktop app may hand a session over.
    if (cookie(req, FLOW_COOKIE) !== flowId(returnTo)) {
      return redirect(res, withParams(returnTo, { error: "expired" }), done);
    }
    const headers = fromNodeHeaders(req.headers);
    const session = await auth.api.getSession({ headers });
    if (!session) return redirect(res, withParams(returnTo, { error: "not_signed_in" }), done);
    const { token } = await auth.api.generateOneTimeToken({ headers });
    redirect(res, withParams(returnTo, { token }), done);
  }

  function nativeError(url: URL, res: ServerResponse) {
    const returnTo = loopbackAddress(url.searchParams.get("return_to"));
    if (!returnTo) return json(res, 400, { error: "Sign-in didn't finish." });
    redirect(res, withParams(returnTo, { error: url.searchParams.get("error") ?? "failed" }), [flowCookie("", 0)]);
  }

  const server = createHttpServer(async (req, res) => {
    try {
      const url = new URL(req.url ?? "/", config.baseURL);
      if (!cors(req, res)) return json(res, 403, { error: "Origin not allowed." });
      if (req.method === "OPTIONS") return void res.writeHead(204).end();

      if (url.pathname.startsWith("/api/auth/")) return await handleAuth(req, res);
      if (req.method !== "GET") return json(res, 405, { error: "Method not allowed." });

      switch (url.pathname) {
        case "/health":
          return json(res, 200, { ok: true });
        case "/providers":
          return json(res, 200, { google: Boolean(config.google), emailLink: config.devSignIn });
        case "/native/sign-in":
          return await nativeSignIn(url, req, res);
        case "/native/done":
          return await nativeDone(url, req, res);
        case "/native/error":
          return nativeError(url, res);
        default:
          return json(res, 404, { error: "Not found." });
      }
    } catch (error) {
      console.error(error);
      if (!res.headersSent) json(res, 500, { error: "Something went wrong." });
    }
  });
  return { server, auth };
}
