# roles/

Lands with the v2 IaC skeleton (OPS-7): one role per concern
(debian-ct template, guest buildout, node glue), data-driven from the
inventory + `guests/` manifests. Until then the per-node glue lives in
`scripts/deploy-node-glue.sh` (parked) and `scripts/revive-node.sh`
(live).
