# Next.js behind a TLS-terminating reverse proxy

A reusable gotcha that bit cronmaster (CT 127) when its HTTPS fronting went
live via `tailscale serve --https 443`. Also potentially affects linkwarden
(CT 112) and excalidraw (CT 120) -- the same Next.js + tailscale-serve
pattern. **Audit those two if login-then-bounce symptoms appear.**

## Symptom (the cronmaster incident)

After enabling `tailscale serve --https 443` on a Next.js standalone app:

* `POST /login` succeeds (200 + `set-cookie`).
* Every subsequent request (`GET /`, `GET /anything`) is redirected back to
  `/login` forever. The user is locked out.

App logs show:
```
Session check error: TypeError: fetch failed ... ERR_SSL_WRONG_VERSION_NUMBER
```

## Root cause (latent app bug exposed by the HTTPS prefix swap, NOT TLS itself)

A lot of Next.js apps authenticate requests by **server-side self-fetching
their own check-session endpoint** in middleware:

```js
let t = process.env.INTERNAL_API_URL || process.env.APP_URL || e.nextUrl.origin
fetch(new URL(`${t}/api/auth/check-session`), { headers: { Cookie: ... } })
```

Without `INTERNAL_API_URL` set, this falls back to `nextUrl.origin` -- which
becomes `https://<host>.tail54538d.ts.net` once the app is fronted by HTTPS.
Inside the CT that tailnet name **resolves to `127.0.1.1`** (an `/etc/hosts`
entry), and **nothing listens on 443 there** (`tailscale serve` runs in
tailscaled on the 100.x tailnet IP, not on the loopback).

So the self-fetch hits `https://127.0.1.1:443` -> `ERR_SSL_WRONG_VERSION_NUMBER`
-> middleware catches the throw -> redirects to `/login`.

Before HTTPS was added, `nextUrl.origin` was `http://<host>:3000`, which DID
resolve + serve locally -- so the missing env var never mattered. The HTTPS
prefix swap from tailscale serve was what exposed it.

## Fix (env-only, no code change)

Set the internal loopback URL in the app's `.env`:

```sh
# /opt/<app>/.env
INTERNAL_API_URL=http://localhost:<app-port>
# (some frameworks read APP_URL / NEXTAUTH_URL / AUTH_URL instead -- check yours)
systemctl restart <app>.service
```

For cronmaster specifically: added `INTERNAL_API_URL=http://localhost:3000`
to `/opt/cronmaster/.env`, restarted `cronmaster.service`. Verified:
`POST /api/auth/login -> 200 set-cookie`, `GET / -> 200` (was 307 to
`/login`).

## General lesson

Any Next.js (or similar SSR) app behind a TLS-terminating reverse proxy
(tailscale serve, Caddy, nginx, etc.) that does server-side self-fetch MUST
be told its **internal loopback URL** -- never rely on `nextUrl.origin` in
production behind TLS. The external/public origin is correct for the
browser but wrong for the server calling itself.

## Symptom tell

> Login returns 200 but every page redirects back to `/login`; app logs show
> `Session check error: TypeError: fetch failed ... ERR_SSL_WRONG_VERSION_NUMBER`.

Apply the env fix + restart.

## Audit todo

* linkwarden (112) -- check `.env` for `INTERNAL_API_URL` / `APP_URL` /
  `NEXTAUTH_URL` / `AUTH_URL` + whether middleware self-checks session.
* excalidraw (120) -- same.
* speedtest-tracker (103) is Laravel (`APP_URL` -- different framework; its
  `APP_URL` was already set to the HTTPS origin, fine).