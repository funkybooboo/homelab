#!/bin/bash
# usb-nic-recover -- self-heal after the RTL8156 drops off the bus.
# Framework's USB NIC does a spontaneous bus-level reset: the
# kernel registers a FRESH netdev, but vmbr0 keeps the stale port
# and the node sits network-dead with the machine running (see
# docs/quirks.md, the 2026-11-27 postmortem).
# Fired by the udev rule (72-usb-nic-recover.rules), which is
# MAC-matched on add|move for a reason: the fresh device's ADD
# event carries the kernel's initial name (eth0) -- the rename
# to nic0 arrives later as a MOVE event, so a rule matching
# KERNEL=="nic0" + ACTION=="add" fires on NOTHING. That exact
# mistake is why the 2026-11-27 00:04 outage sat dead for 11
# hours with the rule on disk. The rules file also arms nothing
# by itself: node_glue runs `udevadm control --reload` after
# deploying it.
sleep 2
logger -t usb-nic-recover "USB-NIC event: re-applying network config (ifreload -a)"
/sbin/ifreload -a >/dev/null 2>&1 || /usr/sbin/ifreload -a >/dev/null 2>&1 || true
