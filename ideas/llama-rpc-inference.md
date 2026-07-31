# Distributed LLM inference with llama.cpp RPC on the homelab cluster

## Honest TL;DR

This cluster has exactly **one GPU node** (`pve-thermaltake`) and a **1GbE
LAN**. The generic "split a model across many GPU nodes over 10GbE" story does
**not** apply. With the constraints as they are, the realistic options are,
in priority order:

1. **Single-node on the GPU** (pve-thermaltake). This is almost certainly the
   best real choice. One GPU + its own RAM beats N CPU nodes dragged across
   1GbE for almost all model sizes that actually fit.
2. **GPU + local CPU offload on the same node** (still pve-thermaltake, no
   network involved). llama.cpp's `-ngl` already does this natively; no RPC
   needed.
3. **RPC across the cluster** -- only worth trying for models that *do not
   fit on pve-thermaltake alone* and where you accept that 1GbE will probably
   make it slower than the alternatives. Concrete, not aspirational, below.

Read the rest as "if you want to try option 3 anyway, here is how it maps onto
*these* boxes." It is an experiment, not a recommendation.

---

## Cluster reality (what there actually is to work with)

| node | arch | GPU? | RAM (rough) | usable for RPC? |
| --- | --- | --- | --- | --- |
| `pve-thermaltake` | x86_64 | **yes** | desktop | yes -- the only CUDA-capable box |
| `pve-framework` | x86_64 | no | desktop | yes -- CPU backend only |
| `pve-aspiree15` | x86_64 | no | laptop | yes -- CPU backend only |
| `pve-aspires` | x86_64 | no | laptop | yes -- CPU backend only |
| `raspberrypi` | arm64 | no | Pi | **no** -- arm64, no pve-lrm, skip |
| `truenas` | x86_64 | no | storage box | **no** -- it is the NFS box; don't load-balance inference onto storage |

LAN: 192.168.8.x /24, **1GbE**. Tailnet: tail54538d.ts.net (do *not* run RPC
tensor traffic over the tailnet; use the LAN IPs). Shared storage: truenas NFS
at 192.168.8.100 (already mounted on all nodes as `pve-shared`/`pve-backups`),
so the model file can live once on NFS if desired.

Net usable pool for an experiment: **1 GPU + up to 3 CPU x86 nodes**, all on
1GbE. The Pi is out (arm64, witness-only).

---

## Why 1GbE is the whole story

llama.cpp's RPC backend ships uncompressed tensor data over the network on
every layer evaluation. Rule of thumb: each remote layer, each token, moves
roughly `n_embd * n_batch * 2 bytes` over the wire. On 1GbE (~110 MB/s real),
that means per-layer overhead can be in the tens of milliseconds *per token*,
which dwarfs the cost of just computing the layer locally.

Practical consequences for this cluster:

- **Adds-latency** scenarios (small model that already fits on the GPU):
  RPC will be *slower* than single-node, probably by a lot. Don't do this.
- **Fits-ness** scenarios (model too big for the GPU + node RAM alone):
  RPC may be the only way to run it at all, and you trade latency for
  "it runs." That is the only legitimate use case here.
- Promising more than "it runs, slowly" on 1GbE is false optimism.

Before investing any time: `iperf3` between pve-thermaltake and one of the
CPU nodes. If you don't see close to wire-rate ~940 Mbps both ways, fix the
network first; RPC will amplify any network problem.

---

## If you still want to try it: minimal, honest setup

### Step 0: stay single-node first

Run `llama-server` on pve-thermaltake with `-ngl 999` (all layers on GPU) and
measure tokens/s. Then try `-ngl 0` (all CPU) and measure again. Those two
numbers are your baselines. RPC only matters if a model is bigger than what
either of those can hold.

### Step 1: build llama.cpp with RPC on every participating node

On pve-thermaltake (CUDA) and on whichever CPU nodes you want to rope in
(pve-framework / pve-aspiree15 / pve-aspires):

```bash
sudo apt update
sudo apt install -y build-essential cmake git libcurl4-openssl-dev

git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# GPU node (pve-thermaltake) -- needs the CUDA toolkit installed first
cmake -B build -DGGML_CUDA=ON -DGGML_RPC=ON
cmake --build build --config Release -j$(nproc)

# CPU-only nodes
cmake -B build -DGGML_RPC=ON
cmake --build build --config Release -j$(nproc)
```

> Flag names changed across llama.cpp versions (`LLAMA_*` -> `GGML_*`, RPC
> server command/flags moved). Re-derive the exact flags from the README in
> *the tag you checked out*, don't trust this doc verbatim.

### Step 2: start RPC backend servers on the CPU nodes

On each CPU worker, bind to its **LAN** IP (not tailnet), e.g. pve-framework
= 192.168.8.<whatever framework is>. Pick a port, 50052 is arbitrary:

```bash
./build/bin/llama-rpc-server --host 0.0.0.0 --port 50052
```

Make it a systemd unit so it survives reboot (mirror the existing
`ntfy-slack-bridge.service` pattern from CT 128 if you want a template):

```ini
# /etc/systemd/system/llama-rpc.service
[Unit]
Description=llama.cpp RPC backend (CPU)
After=network.target

[Service]
Type=simple
ExecStart=/opt/llama.cpp/build/bin/llama-rpc-server --host 0.0.0.0 --port 50052
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Step 3: run the main server on pve-thermaltake

Put the model on the NFS share (`pve-shared`) so you don't copy it onto every
node, or keep a local copy on thermaltake for speed -- your call.

```bash
# rpc-servers.txt -- LAN IPs of the CPU workers only
192.168.8.<framework>:50052
192.168.8.<aspiree15>:50052
192.168.8.<aspires>:50052
```

```bash
./build/bin/llama-server \
  -m /path/to/model.gguf \
  --rpc rpc-servers.txt \
  -c 8192 \
  -ngl 999 \
  --host 0.0.0.0 \
  --port 8080
```

`-ngl 999` keeps as many layers as fit on pve-thermaltake's GPU; the overflow
gets distributed across the RPC workers. Watch the startup log: it prints how
many layers went to each backend.

---

## LXC vs VM, on this cluster

The cluster has no existing GPU-passthrough story; I have not seen any node
configured with IOMMU / vfio / nvidia container passthrough. Two options:

- **Run llama.cpp on the pve-thermaltake *host*** (simplest for a first
  experiment; the GPU is already there, no passthrough gymnastics).
- **LXC with NVIDIA device passthrough** to a new CT on pve-thermaltake: the
  `lxc.cgroup2.devices.allow: c 195:* rwm` + `/dev/nvidia*` mount entries
  pattern. Adds a CT to manage but keeps the host clean. Only worth it if the
  experiment graduates to a permanent service.

For the CPU worker nodes you do **not** need passthrough at all; a plain
unprivileged LXC CT (or just the host) is fine. They're CPU-only.

Recommendation: first attempt, run on the hosts (thermaltake for GPU+main, and
the laptop/desktop hosts for CPU workers). Move into LXC only if it's worth
keeping.

---

## What success would actually look like

Be explicit so this doesn't drift into optimism:

- **Success = "a model that doesn't fit on pve-thermaltake alone now runs,
  end-to-end, even if slow."** That is genuinely useful for the "I want to
  poke at a model bigger than my one GPU" case.
- **Not success = "tokens/s went up."** On 1GbE it very likely won't, vs
  single-node-on-GPU, for anything that already fits on the GPU. If you
  measure that and it's true, say so and shelve RPC.

Log baselines first (step 0). Without those numbers the result is unfalsifiable.

---

## Realistic limitations for this cluster

1. **1GbE is the bottleneck**, almost certainly. `iperf3` before anything else.
2. **Not fault-tolerant.** If pve-aspiree15 (a laptop) sleeps or a CPU worker
   drops, the inference for layers on it dies. The lid-ignored laptops stay up,
   but a reboot still kills the RPC backend. Low resilience.
3. **No automatic layer balancing.** You specify the worker list; llama.cpp
   splits, you don't get fine control without manual tuning.
4. **Same llama.cpp build version on every node**, or it won't talk.
5. **The Pi is out.** arm64 + no pve-lrm + no GPU. Don't add it to
   `rpc-servers.txt`.
6. **Don't run RPC over the tailnet.** Use 192.168.8.x LAN IPs. Tailnet is
   fine for the human-facing `llama-server` endpoint if you want to reach it
   from your workstation, but the inter-node tensor traffic should stay on
   the LAN.

---

## Alternative that probably fits this cluster better

Skip RPC. Put one Ollama (or llama-server) instance on pve-thermaltake using
the GPU + local CPU offload, expose it over the tailnet via `tailscale serve`
like every other CT, and point your clients at `https://llm.tail54538d.ts.net`.
That is a 30-minute job, not a multi-day build, and it gets you a working LLM
endpoint. RPC becomes interesting only when you outgrow the one GPU.

If you want redundancy or more throughput than the one GPU gives, the honest
answer is "add a second GPU node", not "federate across CPU laptops over 1GbE."

---

## Next steps (if proceeding)

1. `iperf3` pve-thermaltake <-> pve-framework. Write down the number.
2. Single-node baseline on pve-thermaltake: tokens/s with `-ngl 999` and `-ngl 0`
   for a test model.
3. Only if those baselines show a real gap a bigger model would fill: build
   RPC on one CPU worker, add it, re-measure.
4. If tokens/s improves or a previously-unrunnable model now runs: keep going.
   If it gets worse: stop, this isn't the cluster for distributed inference,
   and that's a fine answer.

---

## References

- [llama.cpp RPC README](https://github.com/ggerganov/llama.cpp/blob/master/tools/rpc/README.md)
- [llama.cpp build docs](https://github.com/ggerganov/llama.cpp/blob/master/docs/build.md)
- Proxmox LXC device passthrough: `lxc.cgroup2.devices.allow` + `lxc.mount.entry`
- Cluster facts: see `docs/overview.md` in this repo

---

*Document Version: 2.0 -- rewritten for the actual cluster: one GPU node
(pve-thermaltake), three CPU-only x86 nodes, arm64 Pi unusable for CUDA RPC,
1GbE LAN. Replaces the generic multi-GPU/10GbE template v1.0.*