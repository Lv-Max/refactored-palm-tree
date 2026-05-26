#!/usr/bin/env node
/**
 * Boots the pmxt-core engine as a loopback-only HTTP server with NO access
 * token, so the official @pmxt/mcp (which only sends `Authorization: Bearer`,
 * not the `x-pmxt-access-token` header the default `pmxt-server` requires) can
 * talk to it in local mode.
 *
 * All Kalshi logic lives in pmxt-core; this file only starts it. Venue
 * credentials are read by pmxt-core from KALSHI_API_KEY / KALSHI_PRIVATE_KEY in
 * this process's environment, so the key never travels in MCP tool calls.
 *
 * The server binds to 127.0.0.1 only. There is no token because anything that
 * can reach localhost is already on this machine. On a shared/multi-user host,
 * front it with an authenticating proxy instead.
 */
const pmxt = require("pmxt-core");

const PORT = Number(process.env.PMXT_LOCAL_PORT || 38470);

async function main() {
  // No second argument => createApp registers no auth middleware.
  const server = await pmxt.startServer(PORT);
  server.on("error", (err) => {
    console.error(`[pmxt-local-server] ${err.code === "EADDRINUSE" ? `port ${PORT} already in use` : err.message}`);
    process.exit(1);
  });
  console.error(`[pmxt-local-server] listening on http://127.0.0.1:${PORT}`);
}

main().catch((err) => {
  console.error("[pmxt-local-server] failed to start:", err.message);
  process.exit(1);
});
