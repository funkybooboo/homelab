#!/usr/bin/env python3
"""ntfy Slack-format bridge + reverse proxy.

Listens on 127.0.0.1:2587. tailscale serve --https 443 proxies the tailnet
https://ntfy.tail54538d.ts.net -> this listener.

  POST <BRIDGE_PATH>          <- TrueNAS "Slack" alertservice webhook target.
                                 Body is Slack incoming-webhook JSON:
                                   {"text": "...", "attachments": [{"text": "...", ...}]}
                                 Converted to an ntfy publish (Title + Message + priority)
                                 and forwarded to the local ntfy server.

  Everything else             <- reverse-proxied to ntfy on 127.0.0.1:2586
                                 (web UI, JSON subscribe API, raw publish endpoint),
                                 so the phone app and direct publishers work unchanged.

Auth: ntfy itself enforces auth (auth-default-access=deny-all). Subscribers
authenticate with username+password via the proxied ntfy. The bridge's own
publish step uses a long-lived ntfy token (NTFY_TOKEN env) so it does not
need to know any user password.

Keeping the bridge combined as a reverse proxy means there is exactly ONE
tailscale-serve backend (this listener); ntfy is bound to 127.0.0.1 only and
never directly internet/tailnet-exposed.

All secrets come from environment variables -- no credentials are baked in.
The companion systemd unit (ntfy-slack-bridge.service) sets:
  NTFY_TOPIC, NTFY_TOKEN, BRIDGE_PATH
"""
import json
import os
import sys
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# ---- config (all from env; no hardcoded secrets) -------------------------
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "2587"))
NTFY_UPSTREAM = os.environ.get("NTFY_UPSTREAM", "http://127.0.0.1:2586")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "")
NTFY_TOKEN = os.environ.get("NTFY_TOKEN", "")
BRIDGE_PATH = os.environ.get("BRIDGE_PATH", "")

DEFAULT_PRIORITY = "default"


def build_publish(slack_json: dict) -> dict:
    # Compose a readable title + message body from the Slack payload.
    text = (slack_json.get("text") or "").strip()
    attachments = slack_json.get("attachments") or []
    att_texts = []
    for a in attachments:
        t = (a.get("text") or a.get("fallback") or "").strip()
        if t:
            att_texts.append(t)
    body = "\n".join(att_texts) if att_texts else text
    title = text if att_texts else "TrueNAS Alert"
    priority = slack_json.get("priority") or DEFAULT_PRIORITY
    return {
        "topic": NTFY_TOPIC,
        "title": title,
        "message": body,
        "priority": priority,
        "tags": ["rotating_light"] if priority in ("high", "urgent") else ["bell"],
    }


def forward_publish(payload: dict) -> tuple:
    # ntfy's plain-text publish with headers is the robust path (Title, Priority,
    # Tags as headers, message as body). JSON-body publish to /<topic> works in
    # newer ntfy but 2.11 stores the JSON as the literal message text unless
    # Content-Type is exactly right; headers avoid that ambiguity.
    body = payload["message"].encode("utf-8")
    headers = {
        "Authorization": "Bearer " + NTFY_TOKEN,
        "Title": payload["title"],
        "Priority": str(payload["priority"]),
        "Tags": ",".join(payload["tags"]),
    }
    req = urllib.request.Request(
        NTFY_UPSTREAM.rstrip("/") + "/" + NTFY_TOPIC,
        data=body,
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:
        return 502, str(e)


def proxy_to_ntfy(method, path, headers, body):
    """Minimal reverse proxy to the upstream ntfy server."""
    url = NTFY_UPSTREAM.rstrip("/") + path
    # Strip hop-by-hop headers; keep auth so subscribers' credentials pass through.
    skip = {"host", "connection", "keep-alive", "proxy-authenticate",
            "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade"}
    out_headers = {k: v for k, v in headers.items() if k.lower() not in skip}
    req = urllib.request.Request(url, data=body if body else None,
                                 headers=out_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, dict(resp.headers), resp.read()
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read()
    except Exception as e:
        return 502, {"Content-Type": "text/plain"}, str(e).encode()


class Handler(BaseHTTPRequestHandler):
    server_version = "ntfy-slack-bridge/1.0"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _handle(self, method):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None

        if method == "POST" and BRIDGE_PATH and self.path.split("?", 1)[0] == BRIDGE_PATH:
            try:
                slack = json.loads(body.decode("utf-8")) if body else {}
            except Exception:
                slack = {"text": body.decode("utf-8", "replace") if body else "(no body)"}
            if not slack.get("text") and not slack.get("attachments"):
                # Plain text body -> treat as message directly.
                slack = {"text": (body or b"").decode("utf-8", "replace")}
            code, resp = forward_publish(build_publish(slack))
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(resp.encode("utf-8", "replace"))
            return

        # Otherwise: reverse-proxy to ntfy.
        code, hdrs, data = proxy_to_ntfy(method, self.path, dict(self.headers), body)
        self.send_response(code)
        for k, v in hdrs.items():
            if k.lower() in ("transfer-encoding", "connection", "content-length"):
                continue
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if method != "HEAD":
            self.wfile.write(data)

    def do_GET(self): self._handle("GET")
    def do_POST(self): self._handle("POST")
    def do_PUT(self): self._handle("PUT")
    def do_DELETE(self): self._handle("DELETE")
    def do_HEAD(self): self._handle("HEAD")
    def do_OPTIONS(self): self._handle("OPTIONS")


if __name__ == "__main__":
    missing = [k for k, v in (("NTFY_TOPIC", NTFY_TOPIC),
                             ("NTFY_TOKEN", NTFY_TOKEN),
                             ("BRIDGE_PATH", BRIDGE_PATH)) if not v]
    if missing:
        print("Missing required env: " + ", ".join(missing), file=sys.stderr)
        sys.exit(2)
    srv = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    print(f"ntfy-slack-bridge on {LISTEN_HOST}:{LISTEN_PORT} -> {NTFY_UPSTREAM}, "
          f"bridge path {BRIDGE_PATH}, topic {NTFY_TOPIC}", file=sys.stderr)
    srv.serve_forever()