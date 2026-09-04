// Host-rewriting shim for the herdr-world bridge.
//
// herdr-world v0.1.1's bridge rejects any request to /api/* or /ws/* whose
// Host header isn't loopback (its --allow-host flag is a no-op in that build),
// and Tailscale Serve forwards the client's Host verbatim. This shim terminates
// the proxied connection and re-issues each HTTP request / WebSocket to the
// bridge from loopback with Host + Origin stripped, so it looks like a local
// same-origin call and the bridge accepts it.
//
// Run with bun. Env:
//   HERDR_WORLD_BACKEND    bridge host:port         (default 127.0.0.1:8787)
//   HERDR_WORLD_SHIM_PORT  port this shim listens on (default 8788)

const BACKEND = process.env.HERDR_WORLD_BACKEND || "127.0.0.1:8787";
const PORT = Number(process.env.HERDR_WORLD_SHIM_PORT || 8788);

Bun.serve({
  port: PORT,
  hostname: "127.0.0.1",
  idleTimeout: 0,
  async fetch(req, server) {
    const url = new URL(req.url);
    if ((req.headers.get("upgrade") || "").toLowerCase() === "websocket") {
      if (server.upgrade(req, { data: { path: url.pathname + url.search } })) return;
      return new Response("upgrade failed", { status: 400 });
    }
    const headers = new Headers(req.headers);
    headers.delete("host");
    headers.delete("origin");
    headers.delete("referer");
    // Force an identity body. Bun's `fetch` otherwise injects its own
    // Accept-Encoding, transparently decompresses the reply, and hands back a
    // decoded body still carrying Content-Encoding/Content-Length headers that
    // describe the compressed bytes — the browser then reports a content
    // encoding error.
    headers.set("accept-encoding", "identity");
    let resp;
    try {
      resp = await fetch(`http://${BACKEND}${url.pathname}${url.search}`, {
        method: req.method,
        headers,
        body: req.body,
        redirect: "manual",
        duplex: "half",
      });
    } catch (e) {
      return new Response(`herdr-world shim: backend unreachable (${e})`, { status: 502 });
    }
    const respHeaders = new Headers(resp.headers);
    respHeaders.delete("content-encoding"); // paranoia: backend served identity
    return new Response(resp.body, {
      status: resp.status,
      statusText: resp.statusText,
      headers: respHeaders,
    });
  },
  websocket: {
    open(ws) {
      const backend = new WebSocket(`ws://${BACKEND}${ws.data.path}`);
      backend.binaryType = "arraybuffer";
      ws.data.backend = backend;
      ws.data.queue = [];
      backend.addEventListener("open", () => {
        for (const m of ws.data.queue) backend.send(m);
        ws.data.queue = [];
      });
      backend.addEventListener("message", (e) => ws.send(e.data));
      backend.addEventListener("close", (e) => { try { ws.close(e.code, e.reason); } catch {} });
      backend.addEventListener("error", () => { try { ws.close(); } catch {} });
    },
    message(ws, message) {
      const b = ws.data.backend;
      if (b && b.readyState === 1) b.send(message);
      else ws.data.queue.push(message);
    },
    close(ws) {
      try { if (ws.data.backend) ws.data.backend.close(); } catch {}
    },
  },
});

console.error(`herdr-world shim: http://127.0.0.1:${PORT} -> ${BACKEND}`);
