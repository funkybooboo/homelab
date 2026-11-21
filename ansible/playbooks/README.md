# playbooks/

Lands with the v2 IaC skeleton (OPS-7): `converge.yml` (idempotent
fleet converge driven by the inventory + guest manifests) and
`verify.yml` (check-mode diff for drift detection, OPS-15). Until then
the bring-up tooling lives in `scripts/`.
