# Self-hosted Monero node + (optional) miner + private buy/sell

## Honest TL;DR

This is really **two and a half separate goals** the request bundled into one,
and they have very different honesty profiles:

1. **Run a Monero full/pruned node** so you broadcast your own transactions
   without leaking tx data + view-key scans to a third-party node. **Real
   win, cheap, clean fit for this cluster.** Recommending we do it.
2. **Buy/sell XMR "privately."** A node does *not* buy you this. Privacy of
   fiat<->XMR is a property of the *exchange path* (DEX vs KYC'd CEX vs P2P),
   not the node. The node only protects broadcast/chain-query privacy. Worth
   building the second half honestly and separately, because it is where the
   real privacy (and the real risk) lives.
3. **Mine Monero.** On this cluster: **negative ROI for years, network
   support only.** Real money (electricity) for lottery tickets. Included
   as an *optional, opt-in, accepted-loss* phase, not as income.

Read the rest as "here is how each of the three maps onto *these* boxes, with
the tradeoffs that actually matter for a 1GbE tailnet-only Proxmox homelab."

> Status: PROPOSAL. Nothing here is deployed.
> Grounded in [`../docs/services.md`](../docs/services.md) (CT catalog),
> [`../docs/https.md`](../docs/https.md) (tailnet-only HTTPS + LE via
> `tailscale serve`), [`../docs/cluster.md`](../docs/cluster.md) (HA + the
> "Pi rule"), and [`../docs/storage.md`](../docs/storage.md) (the
> `pve-shared` NFS + random-IO-abhors-NFS lesson already learned on the
> Loki CT, see `ideas/observability.md`).

---

## What the request actually asks for, separated

The request said: "a monero node so I can buy and sell monero privently and
maybe even mine monero." That collapses three independent privacy/economic
properties. They must be designed separately, because the node is easy and
honest, and the exchange path is hard and has a long dishonest marketing
tail (swap aggregators, "no-KYC" CEXs, Telegram OTC). The table below is the
whole thesis of this doc:

| goal | what gives you the property | does a self-hosted node help? |
| --- | --- | --- |
| broadcast my own txs, scan the chain myself, no remote node sees my tx graph | your own `monerod` + your own view-key scans | **yes -- this is the only thing the node does** |
| keep my keys under my own control (not an exchange's custody) | a local wallet file on a machine you own; seed backed up offline | yes, indirectly -- a node makes self-custody usable daily |
| buy XMR from fiat without leaking identity | the *exchange path* (DEX/P2P/cash-by-mail), NOT the node | **no. Node is irrelevant to this.** |
| sell XMR to fiat without leaking identity | same -- the offramp path, not the node | **no.** |
| earn XMR from hardware | mining (RandomX CPU) | n/a -- separate subsystem |

> **One-line correction to the request's framing:** a self-hosted node gives
> you *broadcast + query + custody* privacy. It does **not** give you
> *acquisition* privacy. Buying/selling "privately" is solved by *which
> exchange you use*, and the honest options for that are fewer and flakier
> than the Monero marketing suggests (see "Exchange path" below).

---

## What already exists on this stack (don't rebuild)

- 5-node PVE cluster, 23 running CTs, all web surfaces tailnet-only HTTPS over
  `tailscale serve --https 443` with auto-renewed LE certs
  ([`../docs/https.md`](../docs/https.md)). A Monero node fits this pattern
  exactly: no public port needed for *your* privacy, RPC stays inside the
  tailnet, certs are free.
- `local-lvm` vs `pve-shared` NFS storage tradeoff -- already learned the
  hard way on the Loki CT (130): **random-IO workloads abhor NFS blips**,
  so Loki's TSDB went on `local-lvm`, not `pve-shared`. A Monero blockchain
  is the same class of workload (lots of random reads/writes during sync +
  constant block I/O while peered). Same answer: **local-lvm, not NFS.** Don't
  relearn this.
- ntfy push pipeline + alertmanager->ntfy bridge already live
  ([`../docs/notifications.md`](../docs/notifications.md)) -- node-stuck /
  sync-stalled / disk-full alerts ride the existing rail for free.
- vzdump Saturday 21:00 snapshot of every HA-managed CT -- gives us the
  "rollback a bad upgrade" path for the node CT for free, same as every
  other CT.
- The `accept-dns=false` + MagicDNS renewal gotcha
  ([`../docs/https.md`](../docs/https.md)) -- already solved cluster-wide, the
  new CT just joins the tailnet the same way CT 122/123/130 did.

---

## Cluster reality (what there actually is to work with)

| node | arch | role | good for the node? | good for mining? |
| --- | --- | --- | --- | --- |
| `pve-thermaltake` | x86_64 | desktop, the GPU node | yes | CPU only; shares RAM/cores with jellyfin GPU transcode |
| `pve-aspiree15` | x86_64 | laptop, HA master | yes | weak (laptop CPU, thermals) |
| `pve-aspires` | x86_64 | laptop | yes | weak (laptop CPU) |
| `pve-framework` | x86_64 | desktop | yes | OK-ish CPU, but was offline Jul 18-26 once -- don't put a 24/7 miner here |
| `raspberrypi` | arm64 | quorum-witness | **no** -- arm64 + no `pve-lrm` (Pi rule, [`../docs/cluster.md`](../docs/cluster.md)) | **no** |
| `truenas` | x86_64 | storage/NFS | **no** -- never load the node onto the storage box | n/a |

LAN: 192.168.8.x /24, **1GbE**. Tailnet: tail54538d.ts.net. Shared storage is
NFS from truenas -- and as above, we deliberately avoid it for this CT.

Storage sizing: the full Monero blockchain is ~**200GB and growing** (~10GB/yr);
a **pruned** node is ~**50GB**. Pruned is enough for your own
broadcast/query privacy and is what we default to. Full node only if you want
to serve the public network (then you also need inbound P2P, see open
question 1).

---

## Phase 1 -- The node (the honest, recommended part)

### 1a -- CT creation

New **LXC CT 131** `monero-node` on `pve-thermaltake` (the desktop; has the
headroom and is reliably-on; the laptop nodes are lid-ignored but
thermally weaker). **Unprivileged, `nesting=1` not needed** (no Docker
required -- we run `monerod` natively as a systemd unit, matching the
homelab's "no Docker, native packages" convention).

- rootfs: **`local-lvm` 80GB** (pruned chain ~50GB + headroom; bump to 250GB
  on a full-node variant, but see open question 1).
- cores 4, RAM **8GB** (Monero verification is RAM-heavy; 4GB is the floor,
  8GB is comfortable, more lets it batch-verify faster during initial sync).
- HA: **yes** (rootfs on local-lvm of the chosen node -- but see caveat:
  an HA-migrated node resumes from a stale chain and re-syncs cleanly, so HA
  is fine here, the chain is self-healing). onboot=1.
- tailscale: join as `monero.tail54538d.ts.net`, `tailscale serve` not
  required (the RPC is consumed over the tailnet IP directly, port 18089 --
  no browser UI to serve, no cert needed). This is the same pattern as the
  postgres CT 108 (no web port, no tailscale serve, consumed over tailnet).

### 1b -- monerod

Install the official CLI from https://www.getmonero.org/downloads/ (the
homelab convention is upstream-static-binary, not a distro package, because
Debian's `monero` packaging lags). Create a `monero` user, drop the binary
in `/opt/monero`, data in `/var/lib/monero` (on the local-lvm rootfs). Systemd
unit, restricted-RPC bound to the tailnet interface only:

```
ExecStart=/opt/monero/monerod \
  --data-dir /var/lib/monero \
  --rpc-restricted-bind-ip 0.0.0.0 \
  --rpc-restricted-bind-port 18089 \
  --rpc-bind-ip 127.0.0.1 --rpc-bind-port 18081 \
  --confirm-external-bind \
  --no-igd --no-zmq \
  --enable-dns-blocklist \
  --prune-blockchain
```

- `--rpc-restricted-bind-port 18089` -- the *safe* RPC for wallets (view-key
  scans + tx broadcast only; cannot spend). This is what your wallets
  connect to over the tailnet.
- `--rpc-bind-ip 127.0.0.1 --rpc-bind-port 18081` -- the *unrestricted* RPC
  (can spend) bound to loopback only. Used only by `monero-wallet-cli`
  running *on the CT itself* if you ever run a hot wallet there (Phase 3
  caveat -- by default we do NOT).
- `--prune-blockchain` -- ~50GB instead of ~200GB. Sufficient for your own
  broadcast/query privacy. Drop only if you decide to be a public peer
  (open question 1).
- `--enable-dns-blocklist` -- drops known-phishing seed nodes. Standard.

Initial sync: **2-5 days** on this hardware, pegged to ~1 core + lots of disk
I/O. This is normal; Monero verification is genuinely CPU-heavy (RandomX
PoW must be verified for every historical block). Do not panic at the long
sync; do not "help" it with a pruned bootstrap snapshot from an untrusted
source (chain-verification defeat). Let it sync from real peers.

### 1c -- Observation into the existing stack (free wins)

- **Prometheus**: scrape `monero` via a small exporter. The homelab already
  scrapes app-native `/metrics` (forgejo, grafana). `monerod` has no native
  metrics endpoint; the honest options are (a) a lightweight
  `monero-prometheus-exporter` sidecar (community ones exist, e.g.
  `monero-exporter`), or (b) a `node_exporter` on the CT for at least
  CPU/mem/disk (matches the pattern already on every PVE host). Default to
  **(b)** for Phase 1 (consistent with how the ~15 metric-less CTs are
  treated -- CT-level CPU/mem/disk on the existing "Proxmox -- CTs" board,
  no per-service board). Add (a) later only if you want chain-height /
  peer-count / sync-progress alerts.
- **Loki**: promtail on the CT pushes `monerod`'s journald unit to the
  existing Loki on CT 130, same as the 13 hosts already wired in Phase 2 of
  the observability plan. The "Logs -- Incident Timeline" board picks it up
  automatically.
- **ntfy**: an alert on "sync stalled > 6h" or "node not fully synced > 14d"
  rides the existing alertmanager->ntfy rail. Low priority -- the node being
  a few hours behind hurts nobody but you.

### 1d -- Wallet connection (the actual point)

- **Default and recommended**: run the wallet on your *personal* device
  (Monero GUI Wallet on desktop, Feather/Cake on mobile), pointed at
  `http://monero.tail54538d.ts.net:18089` over the tailnet. **Keys never
  touch shared homelab infrastructure.** This is the same sovereignty
  argument as vaultwarden: the cluster stores nothing sensitive about your
  funds, it just relays your txs and answers your view-key scans.
- **Do not** put a hot wallet on the node CT by default. A hot wallet on
  shared infrastructure means spend keys live on a box that 5 people
  (future-you) might `pct exec` into, that gets vzdump-snapshotted to the
  NFS box, etc. Revisit in Phase 3 only if you have a concrete reason
  (e.g. payment automation) **and** understand the risk.

---

## Phase 2 -- The exchange path (the "buy and sell privately" part)

This phase has nothing to do with the node. It is included because the
request asked for it, and because the honest answer is more useful than the
marketing. **All of these are out-of-cluster decisions** -- none of them run
on the homelab; they're just where you point your (now-self-hosted) wallet.

### Honest options, ranked by how private they actually are

| path | KYC? | custody | real privacy | real risk | honest verdict |
| --- | --- | --- | --- | --- | --- |
| KYC'd CEX (Kraken, etc. -- the ones that still list XMR) | full | exchange holds until withdraw | **none** -- CEX sees your identity, your bank, your tx graph | exchange delist/regulatory rugpull (Kraken delisted XMR in EU/EEA already) | easy, not private at all. Use only to acquire, withdraw immediately to self-custody, never keep balance there. |
| **Haveno** (decentralized, Monero-native, Tor) | none | non-custodial multisig escrow | **high** -- peer-to-peer, Tor, no central KYC | counterparty + escrow dispute risk; thin liquidity; project is young | the honest "private buy/sell" option today. Expect low liquidity + patience. |
| Bisq (BTC/XMR swap market) | none | non-custodial | high | same as Haveno + an extra hop (fiat->BTC->XMR or reverse) | reasonable, more steps |
| "no-KYC" CEX / swap aggregators (Trocador, ChangeNOW, etc.) | "none" advertised | **custodial during swap** | **low in practice** -- many are front-ends for KYC'd CEXs; some flag "AML" and hold funds; some are outright honeypots | **high** -- funds lost to "AML review" holds is a known pattern | **be skeptical.** "No KYC" marketing is often false. Treat as custodial and risky, not as private. |
| cash-by-mail / local cash (the old LocalMonero model) | none | n/a | highest | personal safety + scam risk; LocalMonero was seized in 2024 | works but the on-the-ground risk is real and the platforms are mostly gone |
| centralized swap (e.g. FixedFloat, before its 2024 hack) | none advertised | custodial | low | demonstrated loss (FixedFloat lost ~$26M and paused) | the failure cases are public; avoid |

**Punchline for the "buy and sell privately" goal:** Haveno (or Bisq) is the
honest answer. The "swap aggregator" ecosystem markets itself as private and
mostly isn't. KYC'd CEXs are the path of least resistance if you tolerate
identity leakage *for the acquisition step only* and withdraw immediately to
your self-hosted-wallet-over-your-own-node. The node protects everything
*after* acquisition; it cannot protect the acquisition itself.

### Legal/ToS flag (not legal advice, just a flag)

- Monero is delisted or restricted by many exchanges and some jurisdictions.
  Kraken delisted XMR for EU/EEA users; Binance delisted globally; OKX
  delisted. Check **what jurisdiction you're actually in** and what the
  *current* (not 2023) listing status is before planning around a specific
  CEX. This changes year to year.
- Privacy is legal in most places; *structuring trades to evade reporting*
  is not. The boundary is jurisdiction-specific and the answer is "talk to
  someone qualified," not "ask the idea file."

---

## Phase 3 -- Mining (optional, accepted-loss, NOT income)

### Why this section is short and blunt

Monero uses **RandomX**, a CPU + memory-hard PoW. Profitable RandomX mining
means: modern many-core CPU, lots of fast RAM, huge pages, cheap electricity,
and ideally cooler-than-ambient air. This homelab has none of those as
primary design goals -- it's a quiet 5-node cluster on a 1GbE LAN, mostly
laptops, sharing RAM with 23 service CTs. The honest math:

- A modern desktop CPU (e.g. an 8-core Ryzen-class on `pve-thermaltake`)
  mines on the order of **a few thousand H/s**. At network difficulty and
  current XMR price, that's roughly **fractions of a cent per day**, against
  tens of cents/day of electricity. The ratio has been negative for years
  and is not expected to invert for commodity hardware.
- Laptops (`pve-aspiree15`, `pve-aspires`) are worse and you cook the
  batteries/thermals for a guaranteed loss.
- `pve-framework` has OK CPU but was offline for 8 days once; not a
  reliability story for a 24/7 load.
- The Pi is out (arm64, witness-only).

**Treat mining as a network-support donation, accept the electricity cost as
the donation, do not budget for income.** If that framing is unattractive,
skip this phase. It is genuinely fine to skip it.

### If you still want to (the honest minimal setup)

- Run `xmrig` on **one** node only, **not** in the shared cluster's CTs
  competing for cores with services. The cleanest is on `pve-thermaltake`
  directly (host, not CT) so it can use huge pages + full L3 + all idle
  cores, with `nice`/`cgroups` so it yields to the cluster the instant
  anything else wants CPU.
- Point it at **your own node** for solo mining (`127.0.0.1:18081`), or at a
  public pool for predictable dust. Solo = lottery, pool = tiny steady dust
  minus pool fee. Neither is profit; both are participation.
- **Do not** run xmrig inside an LXC with a hot wallet. The CT model adds
  nothing to mining and a `pct exec`-able miner with keys is strictly worse.
- Add an ntfy alert on "xmrig not running > 1h" *only if* you actually care
  about uptime -- if it's a donation you don't care, leave it off.

### What we will NOT do

- No GPU mining. Monero is CPU-only (RandomX); the NVIDIA GPU on
  `pve-thermaltake` that jellyfin uses for transcode is irrelevant to
  Monero. Don't confuse this with the ETC/legacy GPU-minable coins.
- No mining over the tailnet / RPC tensor traffic. (Not applicable here, but
  noting for consistency with `ideas/llama-rpc-inference.md`'s "don't run
  RPC tensor traffic over the tailnet" rule.)
- No mining on the Pi, no mining on truenas, no mining on the laptop nodes
  long-term. See cluster-reality table.

---

## Comparison with alternatives (for the broadcast-solvency goal)

| option | broadcast privacy | self-custody | effort | fits homelab policy |
| --- | --- | --- | --- | --- |
| remote node (Feather/Cake's default, or a public one) | **none** -- third party sees your tx graph + view-key scans | depends on wallet | none | yes, but no win over just using a wallet |
| **self-hosted node (this)** | **full** | full | medium (one CT, 2-5d sync) | **yes -- matches tailnet-only + local-lvm-for-random-IO patterns** |
| `monero-wallet-rpc` on a VPS | full | full | medium + ongoing cost | no -- reintroduces a third-party box, defeats the point |

Self-hosted is the only one that gives full broadcast/query/sovereignty
privacy. Remote-node wallets are the honest "good enough, zero effort"
alternative and we note them so the tradeoff is explicit, not implicit.

---

## Cost

- Hardware: **$0** (amortized into existing PVE cluster).
- Power (node only): ~5-10W continuous for one 4-core / 8GB CT pegged during
  sync, dropping to ~3-5W at steady state. Negligible alongside the cluster.
- Power (mining, optional Phase 3): **negative ROI** -- treat the delta on
  the electricity bill as a donation. Estimate tens of dollars/month,
  against sub-dollar expected return. Flag, don't budget.
- Domain: $0 (uses `monero.tail54538d.ts.net` over the tailnet, no public
  cert needed since the RPC is JSON-over-HTTP consumed by your own wallets,
  not a browser).
- Total (node only): **$0/yr** beyond electricity already being paid.

---

## Success metrics

- [ ] CT 131 `monero-node` up on `pve-thermaltake`, tailnet-joined as
      `monero.tail54538d.ts.net`, HA-managed + onboot.
- [ ] `monerod` fully synced (height within 1 block of network) within 5
      days of first boot.
- [ ] Monero GUI Wallet on a personal device connects to
      `http://monero.tail54538d.ts.net:18089` and reports "connected to
      daemon" + correct chain height.
- [ ] A test spend broadcasts through the local node and confirms (does not
      rely on a third-party node anywhere in the path).
- [ ] CT-level CPU/mem/disk visible on the existing "Proxmox -- CTs" board;
      `monerod` journald lines visible in Loki "Incident Timeline" board.
- [ ] (optional, Phase 3) xmrig on `pve-thermaltake` submits shares to the
      local node, with user-visible `nice`-priority yield to the cluster.
- [ ] Recovery from full CT loss within 1h: recreate CT 131, restore
      `/var/lib/monero` from the most recent vzdump (Saturday snapshot),
      resume sync (does not need a full re-sync if the snapshot is recent
      enough; if stale, re-sync is self-healing).

---

## Risk assessment

| risk | likelihood | impact | mitigation |
| --- | --- | --- | --- |
| monerod binary supply-chain (compromised release) | low | severe | verify GPG signature + hashes from getmonero.org against a second source; pin a specific version, don't auto-update blindly |
| chain sync stalls / bad peers | medium | low | `--enable-dns-blocklist`, drop bad peers via `monerod` console; sync is self-healing, just slow |
| wallet keys leak via homelab infra (snapshot, pct exec, NFS) | medium if hot wallet on CT; near-zero if wallet on personal device | severe | **default policy: wallet on personal device, keys never on the cluster**; do not run a hot wallet on CT 131 in Phase 1 |
| disk full from chain growth (~10GB/yr) | low near-term, certain long-term | medium | 80GB rootfs gives years of pruned headroom; add a prometheus fs alert (consistent with observability plan) |
| regulatory/local legality of running a Monero node | low in most jurisdictions | potentially high in a few | check your jurisdiction; node is non-commercial + non-custodial in most readings, but verify |
| "no-KYC" swap aggregator loss (Phase 2) | medium | high (loss of funds) | prefer Haveno/Bisq; treat aggregator "no-KYC" claims as marketing, not truth |
| mining electricity cost exceeds value (Phase 3) | **near-certain** | low (just money) | accept as donation; skip if unattractive |
| cluster resource contention from the node during sync | medium (2-5d pegged core) | low | 4-core/8GB CT on `pve-thermaltake` which has headroom; one-time pain during initial sync |
| monerod CVE requires urgent upgrade | low | medium | vzdump snapshot gives instant rollback; track getmonero.org security advisories |

---

## Open questions (before any build)

1. **Pruned vs full node + inbound P2P.** Pruned (default) gives you your own
   broadcast/query privacy and that's it -- you don't *serve* the public
   network because no inbound P2P port is forwarded (matches homelab
   "nothing public" policy). A full node *with* inbound 18080/tcp forwarded
   through the GL-MT2500 would make you a useful network peer -- but exposes
   your home IP to the Monero P2P network, breaking the "tailnet-only,
   nothing public" posture every other service in this homelab holds. **My
   recommendation: pruned, no inbound, tailnet-only.** Confirm before build.
2. **Node membership in the CT catalog / IaC.** This CT is created manually
   like Loki CT 130 (which also isn't in `proxmox-iac.md`'s scope yet). When
   `ideas/proxmox-iac.md` lands, this CT should be captured there alongside
   130. Note it as a known gap, don't block Phase 1 on it.
3. **Do you actually want Phase 2 (Haveno/Bisq) documented further, or is
   the table here enough?** It's an out-of-cluster decision either way; the
   idea file can stop at the comparison table unless you want a walk-through.
4. **Mining: build it, or just leave this phase as "available if you ever
   want a heater"?** Given the near-certain negative ROI, the honest default
   is "don't, unless you want to participate." Confirm we're skipping it
   for now.

---

## References

- Official CLI downloads + GPG verification:
  https://www.getmonero.org/downloads/ + https://www.getmonero.org/resources/user-guides/verification-binary-windows-command-line.html
- `monerod` flags reference:
  https://monero-docs.lza.dev/interacting/monerod-reference/
- Pruned vs full node:
  https://monero-docs.lza.dev/interacting/monerod-reference/#prune-blockchain
- Haveno (DEX, Monero-native, Tor): https://haveno.exchange /
  https://github.com/haveno-dex/haveno
- Bisq (decentralized swap market): https://bisq.network
- RandomX (PoW, CPU/memory-hard): https://www.getmonero.org/resources/monero-papers/RandomX-aug2019.pdf
- xmrig (miner): https://xmrig.com / https://github.com/xmrig/xmrig
- Monero node privacy model (why your own node matters for broadcast):
  https://monero-docs.lza.dev/running-node/
- Existing homelab related docs:
  [`../docs/https.md`](../docs/https.md), [`../docs/cluster.md`](../docs/cluster.md),
  [`../docs/storage.md`](../docs/storage.md), [`./observability.md`](./observability.md)
  (Loki CT 130 local-lvm precedent), [`./proxmox-iac.md`](./proxmox-iac.md).

---

## Status

**Phase:** idea -- ready for Phase 1 (node) when a free weekend + tolerance
for a 2-5 day initial sync lands. Phase 2 is an out-of-cluster decision
documented here for honesty, not a build. Phase 3 (mining) is "available if
you ever want a network-participation donation / a space heater," not a plan.
**Estimated effort:** Phase 1 ~1 weekend (mostly waiting on sync); Phase 2
zero homelab effort (it's where you point your wallet); Phase 3 ~1 evening
if ever.
**Maintenance:** ~15 min/month (track `monerod` version, rare upgrade, fs
fill check). vzdump gives free rollback.
**Prerequisite:** none blocking -- PVE, tailnet, tailscale join, vzdump, Loki
intake + CT-level prometheus are all already live.