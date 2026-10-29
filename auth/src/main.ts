// Starts the auth service: `npm start` (or `make auth`).

import { loadConfig } from "./config.ts";
import { createServer } from "./server.ts";

const config = loadConfig();
const { server } = await createServer(config);

server.listen(config.port, config.host, () => {
  console.log(`OSMS auth on ${config.baseURL} (listening on ${config.host}:${config.port})`);
  console.log(`Google sign-in: ${config.google ? "on" : "off (set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET)"}`);
  if (config.devSignIn) console.log("Development sign-in by link: on. Links appear in this log.");
});

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
