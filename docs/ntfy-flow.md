# ntfy request flow

## Container internals

```
                        TAILNET (100.x)
                              |
                              |  https://ntfy.tail54538d.ts.net
                              |  (LE cert, auto-renewed)
                              v
              +-----------------------------------+
              |  tailscaled on CT 128 `ntfy`      |
              |  tailscale serve --https 443      |
              |    -> http://localhost:2587       |
              +-----------------------------------+
                              |
                              v
              +-----------------------------------+
              |  ntfy-slack-bridge.py  :2587     |
              |  (reverse proxy + Slack->ntfy)    |
              +-----------------------------------+
                 |                    |
       POST /truenas-<secret>        everything else
       (Slack webhook JSON)          (web UI, subscribe, raw pub)
                 |                    |
   parse {text,att[]}->              pass-through
   {Title,Msg,Priority,Tags}            |
                 |                       |
                 v                       v
        +-----------------------------------+
        | ntfy server  :2586  (127.0.0.1)  |
        | auth: deny-all, user nate        |
        | topic: homelab-<secret-suffix>   |
        +-----------------------------------+
                              |
                              | long-lived subscribe (auth user+pass)
                              v
                   +------------------------+
                   | phone: ntfy app        |  <- push notification
                   | (on tailnet via TS app) |
                   +------------------------+
```

## TrueNAS alert path (the reason all this exists)

```
TrueNAS alert (>= WARNING)
   -> alertservice "ntfy (homelab)" type=Slack
      -> POST {text, attachments[]}
         https://ntfy.tail54538d.ts.net/truenas-<secret>
         -> bridge parses -> ntfy publish to topic -> phone push
```

## Direct publish path (any tailnet box)

```
any CT / node / phone (on tailnet)
   -> curl -u nate:<pass> -H Title:.. -d msg \
        https://ntfy.tail54538d.ts.net/homelab-<secret>
      -> bridge passes through (it's not <secret-path>)
      -> ntfy topic -> phone
```

## Why this shape

* Only the **bridge** (`:2587`) is exposed; ntfy itself (`:2586`) is
  localhost-only and never directly reachable.
* One `tailscale serve` backend = the bridge. The bridge reverse-proxies
  *everything except* the secret Slack path, so the phone app's web UI / JSON
  subscribe and direct `curl` publishers all keep working unchanged.
* The secret URL path `/truenas-<secret>` **is** the publisher secret
  (TrueNAS's Slack type has no auth-header field). ntfy auth (`user/pass` +
  `deny-all`) gates both subscribers and the bridge's own publish token.