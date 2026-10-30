// End-to-end tests of the auth service on a throwaway in-memory database.
// Run with `npm test` (or `make check-auth`).

import assert from "node:assert/strict";
import { createPublicKey, verify } from "node:crypto";
import type { AddressInfo } from "node:net";
import { after, before, describe, it } from "node:test";
import { loadConfig, type Config } from "../src/config.ts";
import { createServer } from "../src/server.ts";

const APP = "http://localhost:8080";
const SECRET = "test-secret-that-is-long-enough-for-better-auth-0123456789";

let base = "";
let close: () => void;
const logged: string[] = [];

before(async () => {
  const config: Config = {
    ...loadConfig({ BETTER_AUTH_SECRET: SECRET, OSMS_DEV_SIGN_IN: "1", AUTH_DATABASE_PATH: ":memory:" }),
    google: { clientId: "test-client", clientSecret: "test-secret" },
  };
  const { server } = await createServer(config, (line) => logged.push(line));
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  close = () => server.close();
});

after(() => close());

/** Signs in with the development link and returns the session cookie and bearer token. */
async function signIn(email = "ada@users.example") {
  const request = await fetch(`${base}/api/auth/sign-in/magic-link`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: APP },
    body: JSON.stringify({ email, callbackURL: `${APP}/` }),
  });
  assert.equal(request.status, 200, await request.clone().text());
  const line = logged.at(-1) ?? "";
  assert.ok(!line.includes(email), "the log must not contain the address");
  const link = new URL(line.slice(line.indexOf("http")));
  const verified = await fetch(`${base}${link.pathname}${link.search}`, { redirect: "manual" });
  assert.equal(verified.status, 302);
  assert.equal(verified.headers.get("location"), `${APP}/`);
  const cookie = verified.headers.getSetCookie().map((c) => c.split(";")[0]).join("; ");
  const bearer = verified.headers.get("set-auth-token");
  assert.ok(cookie.includes("session_token"), "a session cookie is set");
  assert.ok(bearer, "the session is also exposed as a bearer token");
  return { cookie, bearer };
}

function decode(part: string) {
  return JSON.parse(Buffer.from(part, "base64url").toString("utf8"));
}

describe("auth service", () => {
  it("says which sign-in methods are on", async () => {
    const res = await fetch(`${base}/providers`);
    assert.deepEqual(await res.json(), { google: true, emailLink: true });
  });

  it("answers the app's origin and refuses others", async () => {
    const ok = await fetch(`${base}/providers`, { headers: { Origin: APP } });
    assert.equal(ok.headers.get("access-control-allow-origin"), APP);
    assert.equal(ok.headers.get("access-control-allow-credentials"), "true");
    const refused = await fetch(`${base}/providers`, { headers: { Origin: "https://evil.example" } });
    assert.equal(refused.status, 403);
    assert.equal(refused.headers.get("access-control-allow-origin"), null);
  });

  it("issues API tokens the API can verify against the published keys", async () => {
    const { cookie } = await signIn();
    const res = await fetch(`${base}/api/auth/token`, { headers: { Cookie: cookie } });
    assert.equal(res.status, 200);
    const { token } = (await res.json()) as { token: string };
    const [header, payload, signature] = token.split(".");
    const claims = decode(payload);
    assert.equal(claims.iss, "http://localhost:3000", "the issuer is the configured base URL");
    assert.equal(claims.aud, "osms-api");
    assert.equal(claims.email, "ada@users.example");
    assert.ok(claims.sub && claims.exp - claims.iat <= 15 * 60);
    assert.deepEqual(Object.keys(claims).sort(), ["aud", "email", "exp", "iat", "iss", "name", "sub"]);

    const { keys } = (await (await fetch(`${base}/api/auth/jwks`)).json()) as { keys: Array<{ kid: string }> };
    const jwk = keys.find((k) => k.kid === decode(header).kid);
    assert.ok(jwk, "the signing key is published");
    const key = createPublicKey({ key: jwk as never, format: "jwk" });
    assert.ok(verify(null, Buffer.from(`${header}.${payload}`), key, Buffer.from(signature, "base64url")));
  });

  it("accepts the signed bearer token, as the desktop app sends it", async () => {
    const { bearer } = await signIn("grace@users.example");
    const res = await fetch(`${base}/api/auth/get-session`, { headers: { Authorization: `Bearer ${bearer}` } });
    const body = (await res.json()) as { user: { email: string } };
    assert.equal(body.user.email, "grace@users.example");
    const unsigned = await fetch(`${base}/api/auth/get-session`, {
      headers: { Authorization: `Bearer ${bearer!.split(".")[0]}` },
    });
    assert.equal(await unsigned.json(), null);
  });

  // The desktop app waits on the loopback interface (RFC 8252); this is the address it sends.
  const APP_RETURN = "http://127.0.0.1:53682/callback?state=Zm9vYmFyYmF6cXV4cXV1eA";
  const q = (returnTo: string) => `return_to=${encodeURIComponent(returnTo)}`;
  const cookiesFrom = (res: Response) => res.headers.getSetCookie().map((c) => c.split(";")[0]);

  it("sends the desktop app's sign-in only back to its loopback address", async () => {
    for (const address of [
      "https://evil.example/callback?state=Zm9vYmFyYmF6cXV4cXV1eA",
      "http://127.0.0.1.evil.example:53682/callback?state=Zm9vYmFyYmF6cXV4cXV1eA",
      "http://localhost:53682/callback?state=Zm9vYmFyYmF6cXV4cXV1eA",
      "http://127.0.0.1:53682/elsewhere?state=Zm9vYmFyYmF6cXV4cXV1eA",
      "http://127.0.0.1:53682/callback?state=short",
      "http://127.0.0.1:80/callback?state=Zm9vYmFyYmF6cXV4cXV1eA",
      `${APP_RETURN}&next=https://evil.example`,
    ]) {
      for (const route of ["/native/sign-in?provider=google&", "/native/done?", "/native/error?error=x&"]) {
        const res = await fetch(`${base}${route}${q(address)}`, { redirect: "manual" });
        assert.equal(res.status, 400, `${route} ${address}`);
      }
    }
  });

  it("starts Google sign-in for the desktop app in the reader's browser", async () => {
    const res = await fetch(`${base}/native/sign-in?provider=google&${q(APP_RETURN)}`, { redirect: "manual" });
    assert.equal(res.status, 302);
    const google = new URL(res.headers.get("location") ?? "");
    assert.equal(google.host, "accounts.google.com");
    assert.equal(google.searchParams.get("redirect_uri"), "http://localhost:3000/api/auth/callback/google");
    assert.ok(cookiesFrom(res).some((c) => c.startsWith("osms_native_flow=")), "the flow is tied to this browser");
  });

  it("never hands a session to a sign-in this browser didn't start", async () => {
    const { cookie } = await signIn("mallory@users.example");
    // Signed in, but no flow cookie: as if another site sent the browser here.
    const res = await fetch(`${base}/native/done?${q(APP_RETURN)}`, { headers: { Cookie: cookie }, redirect: "manual" });
    const back = new URL(res.headers.get("location") ?? "");
    assert.equal(back.searchParams.get("error"), "expired");
    assert.equal(back.searchParams.get("token"), null);
  });

  it("hands a signed-in browser session to the desktop app once", async () => {
    const started = await fetch(`${base}/native/sign-in?provider=google&${q(APP_RETURN)}`, { redirect: "manual" });
    const flow = cookiesFrom(started).find((c) => c.startsWith("osms_native_flow="))!;

    const notYet = await fetch(`${base}/native/done?${q(APP_RETURN)}`, { headers: { Cookie: flow }, redirect: "manual" });
    assert.equal(new URL(notYet.headers.get("location") ?? "").searchParams.get("error"), "not_signed_in");

    // Google would sign the browser in here; the development link does the same.
    const { cookie } = await signIn("linus@users.example");
    const done = await fetch(`${base}/native/done?${q(APP_RETURN)}`, {
      headers: { Cookie: `${cookie}; ${flow}` },
      redirect: "manual",
    });
    const back = new URL(done.headers.get("location") ?? "");
    assert.equal(`${back.origin}${back.pathname}`, "http://127.0.0.1:53682/callback");
    assert.equal(back.searchParams.get("state"), "Zm9vYmFyYmF6cXV4cXV1eA", "the app's state comes back untouched");
    const token = back.searchParams.get("token");
    assert.ok(token);
    assert.ok(cookiesFrom(done).includes("osms_native_flow="), "the flow cookie is cleared");

    const trade = () =>
      fetch(`${base}/api/auth/one-time-token/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });
    const first = await trade();
    assert.equal(first.status, 200);
    assert.ok(first.headers.get("set-auth-token"));
    assert.notEqual((await trade()).status, 200, "a one-time token works once");
  });

  it("passes a failed Google sign-in back to the desktop app", async () => {
    const res = await fetch(`${base}/native/error?error=access_denied&${q(APP_RETURN)}`, { redirect: "manual" });
    assert.equal(new URL(res.headers.get("location") ?? "").searchParams.get("error"), "access_denied");
  });

  it("never mints a hand-off token for a client request", async () => {
    const { cookie } = await signIn("barbara@users.example");
    const res = await fetch(`${base}/api/auth/one-time-token/generate`, { headers: { Cookie: cookie } });
    assert.notEqual(res.status, 200);
  });

  it("refuses unsafe settings", () => {
    assert.throws(() => loadConfig({ BETTER_AUTH_SECRET: "short" }), /BETTER_AUTH_SECRET/);
    assert.throws(
      () => loadConfig({ BETTER_AUTH_SECRET: SECRET, OSMS_DEV_SIGN_IN: "1", NODE_ENV: "production" }),
      /development/,
    );
  });
});
