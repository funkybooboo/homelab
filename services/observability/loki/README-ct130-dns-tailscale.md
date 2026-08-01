# CT 130 (loki) -- DNS + tailscale auth notes
#
# Tailnet join: `tailscale up --hostname=loki --accept-dns=false --auth-key=<key>`
# (interactive URL flow is flaky; authkey joins deterministically). The tailnet
# has node-approval enabled -- after the key joins, the admin must approve
# `loki` at https://login.tailscale.com/admin/machines before traffic flows.
#
# DNS GOTCHA (the cert-issuance killer): /etc/resolv.conf defaults to
# 192.168.8.1 (the LAN router). UDP DNS from CT 130 to 192.168.8.1 is
# FLAKY (i/o timeouts). Tailscale cert issuance (DNS-01 challenge via LE)
# fails with "acme.GetReg: ... lookup acme-v02.api.letsencrypt.org on
# 192.168.8.1:53: i/o timeout". Fix: override /etc/resolv.conf to use
# Cloudflare's 1.1.1.1 (reliable anycast over UDP from this CT):
#
#     printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\n" > /etc/resolv.conf
#
# Once that's set, `tailscale cert loki.tail54538d.ts.net` issues a real
# Let's Encrypt cert within ~30s. tailscale cert auto-renews in tailscaled.
#
# tailscale serve (HTTPS front over the tailnet):
#     tailscale serve --bg --https 443 --yes http://localhost:3100
# Proxies https://loki.tail54538d.ts.net -> http://localhost:3100
# internally, with the LE cert issued above. Same pattern as the other
# CTs (grafana, forgejo, prometheus, etc.).
#
# After a tailscaled restart, netcheck may briefly report UDP=false until
# the mesh re-establishes. If TLS stops working post-restart, a second
# `systemctl restart tailscaled` clears it.
#
# This file documents the live setup; the actual config lives at
# /etc/resolv.conf and in tailscaled's state on CT 130.