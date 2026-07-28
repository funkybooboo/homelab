#!/usr/bin/env python3
"""Configure the TrueNAS alertservice that forwards to ntfy via the bridge.

Run on the TrueNAS host as root:
    python3 truenas-alertservice.py

Idempotent: if a Slack alertservice with our canonical name already exists,
it updates the URL in place; otherwise it creates it. Browser-trusted because
the bridge is behind tailscale serve (Let's Encrypt via Tailscale).

Prereq: the bridge from services/ntfy/ntfy-slack-bridge.py must already be
up at https://ntfy.tail54538d.ts.net<tridge-path>.

TrueNAS 25.10.5 API notes:
- Python client: `from truenas_api_client import Client` (NOT middlewared.client).
- alertservice.create {name, attributes:{type:"Slack", url}, level, enabled}.
- alertservice.update <id> {name, attributes, level, enabled} (full object only).
- alertservice.delete <id> is synchronous (returns True, not a job id).
- alertservice.test takes a full AlertServiceCreate SPEC dict (not an id) and
  returns True on success -- the test message lands on the ntfy topic.

The Slack type schema has NO auth-header field, so the secret in the bridge
URL IS the publisher secret. Use an unguessable random suffix.
"""
import json
import sys
from truenas_api_client import Client

SERVICE_NAME = "ntfy (homelab)"
# Replace with your real bridge URL.
BRIDGE_URL = "https://ntfy.tail54538d.ts.net/truenas-REPLACE_ME"
ALERT_LEVEL = "WARNING"  # INFO|NOTICE|WARNING|ERROR|CRITICAL|ALERT|EMERGENCY


def main():
    c = Client()
    existing = c.call("alertservice.query")
    match = next((s for s in existing if s.get("name") == SERVICE_NAME), None)

    spec = {
        "name": SERVICE_NAME,
        "attributes": {"type": "Slack", "url": BRIDGE_URL},
        "level": ALERT_LEVEL,
        "enabled": True,
    }

    if match:
        sid = match["id"]
        print(f"Updating existing alertservice id={sid} ({SERVICE_NAME})")
        c.call("alertservice.update", sid, spec)
        print("Updated.")
    else:
        created = c.call("alertservice.create", spec)
        print(f"Created alertservice id={created['id']}:", json.dumps(created, default=str))

    # Optional: fire a test alert. The test takes the SPEC, not an id.
    if "--test" in sys.argv:
        r = c.call("alertservice.test", spec)
        print("alertservice.test ->", json.dumps(r, default=str))
        print("A 'TrueNAS @ <host> -- This is a test alert' message should now be on the ntfy topic.")


if __name__ == "__main__":
    main()