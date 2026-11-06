# USER-4: The Monero node

As a household member, I want a self-hosted, pruned, tailnet-only
Monero node, so that our own transactions broadcast and query the
chain without leaking tx data or view-key scans to a third-party node.

**Status**: someday
**Arc**: unqueued

## Acceptance criteria

- [ ] Pruned node CT on an x86 node, tailnet-only, disk sized for the
      pruned chain
- [ ] Wallet points at it; a broadcast + a chain query proven through
      our own node
- [ ] Mining ships only as an opt-in accepted-loss phase, if at all

## Notes

The design record separates the three bundled goals honestly: the node
(real win, cheap, clean fit), the exchange path (privacy lives there,
not in the node; Haveno/Bisq vs KYC CEX honesty table), and mining
(near-certain negative ROI on this cluster). See
[../design/monero-node.md](../design/monero-node.md) -- it is written
against the OLD cluster, so re-anchor its placement facts before
building.
