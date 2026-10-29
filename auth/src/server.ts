// The auth service's HTTP server: Better Auth under /api/auth/, plus the few routes
// OSMS adds around it (which providers are on, and the desktop app's hand-off).

import { createServer as createHttpServer, type IncomingMessage, type ServerResponse } from "node:http";
import { fromNodeHeaders, toNodeHandler } from "better-auth/node";
import { createAuth } from "./auth.ts";
import type { Config } from "./config.ts";

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

  /** Desktop app, step 1: the system browser lands here and goes on to Google. */
  async function nativeSignIn(url: URL, req: IncomingMessage, res: ServerResponse) {
    if (url.searchParams.get("provider") !== "google" || !config.google) {
      return json(res, 400, { error: "Google sign-in isn't set up on this server." });
    }
    const response = await auth.api.signInSocial({
      body: {
        provider: "google",
        callbackURL: `${config.baseURL}/native/done`,
        errorCallbackURL: `${config.baseURL}/native/error`,
      },
      headers: fromNodeHeaders(req.headers),
      asResponse: true,
    });
    const { url: providerURL } = (await response.json()) as { url?: string };
    if (!providerURL) return json(res, 502, { error: "Could not start Google sign-in." });
    redirect(res, providerURL, response.headers.getSetCookie());
  }

  /** Desktop app, step 2: signed in; hand the app a one-time token it trades for a session. */
  async function nativeDone(req: IncomingMessage, res: ServerResponse) {
    const headers = fromNodeHeaders(req.headers);
    const session = await auth.api.getSession({ headers });
    if (!session) return redirect(res, `${config.nativeCallback}?error=not_signed_in`);
    const { token } = await auth.api.generateOneTimeToken({ headers });
    redirect(res, `${config.nativeCallback}?token=${encodeURIComponent(token)}`);
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
          return await nativeDone(req, res);
        case "/native/error":
          return redirect(res, `${config.nativeCallback}?error=${encodeURIComponent(url.searchParams.get("error") ?? "failed")}`);
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
