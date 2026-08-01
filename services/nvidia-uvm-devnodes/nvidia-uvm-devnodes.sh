#!/bin/bash
# nvidia-uvm-devnodes.sh -- ensure /dev/nvidia-uvm + /dev/nvidia-uvm-tools exist.
# The dkms nvidia driver on this PVE host ships NO udev rule, so the nvidia-uvm
# char device registers (see /proc/devices, major "nvidia-uvm") but devtmpfs
# never creates the node. Jellyfin (CT 102) bind-mounts these two paths; without
# them the node is a 0-byte placeholder and CUDA cuInit() fails -> Jellyfin
# transcoding throws "fatal player error". This idempotent script loads the
# module and mknods the nodes at boot.
set -e
modprobe nvidia-uvm 2>/dev/null || true
major=$(awk '$2=="nvidia-uvm"{print $1; found=1} END{exit !found}' /proc/devices)
if [ -z "$major" ]; then
    echo "ERROR: nvidia-uvm not registered in /proc/devices" >&2
    exit 1
fi
declare -A minors=( [0]=nvidia-uvm [1]=nvidia-uvm-tools )
for m in 0 1; do
    name="${minors[$m]}"
    dev="/dev/$name"
    if [ -e "$dev" ]; then
        # ensure it is a char device, not a stale regular file
        [ -c "$dev" ] || { rm -f "$dev"; mknod "$dev" c "$major" "$m"; }
    else
        mknod "$dev" c "$major" "$m"
    fi
    chmod 0666 "$dev"
done
