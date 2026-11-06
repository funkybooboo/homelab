# LEARN-1: Distributed llama.cpp inference

As the craft, I want llama.cpp RPC inference running on the cluster's
one GPU node, so that local LLM experiments run without new hardware
-- and teach the operator the RPC/layer-split tooling along the way.

**Status**: someday
**Arc**: unqueued

## Acceptance criteria

- [ ] Single-node llama.cpp server on pve-thermaltake (the design's
      realistic option 1) with model storage sized on the GPU node
- [ ] Optional: GPU + local CPU offload on the same node, measured
      honestly (tokens/s + what the 1GbE LAN makes impossible)
- [ ] A written verdict on the multi-node RPC fantasy under 1GbE (the
      design already predicts it loses; verify once, record it)

## Notes

This is a LEARN story: it earns its place by what it teaches, never by
pretending to beat one GPU. See
[../design/llama-rpc-inference.md](../design/llama-rpc-inference.md)
(written against the old cluster; placement facts need re-anchoring).
