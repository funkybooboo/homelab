# guests/ -- one guest = one YAML manifest

The v2 skeleton (OPS-7) converges the guest fleet from these
manifests: `make converge` reads every `guests/*.yaml`, creates any
missing CT via the PVE API (the homelab-ops token), bootstraps the
operator account inside it, and applies the guest's role.

## Format

```yaml
name: test            # CT hostname + ansible host name (unique)
vmid: 299             # PVE VMID (see conventions below)
state: present        # present | absent (absent = destroyed)
node: pve-thermaltake # creation/placement (HA may move guests later)
template: debian-13-standard_13.6-1_amd64.tar.zst   # in pve-shared:vztmpl
storage: pve-shared   # CT rootfs storage (NFS = instant migration)
cores: 1
memory: 512           # MB
swap: 512             # MB
disk: 4               # GB rootfs
ip: 192.168.1.50      # static at pct level (never DHCP, issues 7)
role: test_service    # ansible role applied inside the guest
mounts: []            # pct mpX entries: {mp, src} -- node-level
                       # paths bind-mounted into the CT (USER-2)
gpu: false             # true = NVIDIA devnode passthrough into the
                       # CT (guests.yml writes the lxc lines; the
                       # node's driver is node_glue's job)
features: []           # e.g. [nesting] for docker-style services
```

## Conventions

- VMIDs: infra guests `1xx` (reserved: pbs=100), service CTs `2xx`
  sequential, test/disposable `299`. The old fleet's 100-134 VMIDs
  are retired with the old fleet (their dumps still carry them).
- IPs: infra guests in `.11-.19`, service guests in `.50-.99`
  (the `guest_range` in group_vars/all.yml; bash parsers there
  depend on that key format). First come: test=.50,
  vaultwarden=.51.
- `state: absent` destroys the CT -- destructive ops stay
  human-gated by review of the diff, same as cluster-level ops.
- Adding a service = one YAML here + one role in
  `ansible/playbooks/roles/` (the greenfield contract).
