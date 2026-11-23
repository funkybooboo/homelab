#!/bin/bash
# usb-nic-recover -- self-heal after the RTL8156 drops off the bus.
# Root cause of framework vanish events #1-3 (2026-07/09/11): the
# USB NIC does a bus-level disconnect + immediate re-enumeration;
# the kernel registers a NEW netdev, but vmbr0 keeps the stale port
# and the node sits network-dead until a human power-cycles it.
# This runs on nic0 re-appear (udev net add) and re-applies the
# network config so the fresh device gets enslaved + brought up.
sleep 2
/sbin/ifreload -a >/dev/null 2>&1 || /usr/sbin/ifreload -a >/dev/null 2>&1 || true
