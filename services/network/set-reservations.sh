#!/bin/sh
# set-reservations.sh -- GL-MT2500 (OpenWrt 21.02) dnsmasq DHCP host reservations
# Pins TrueNAS + the 5 PVE nodes to their CURRENT IPs (sticky across reboots).
# Idempotent. Re-runnable. Run via:
#   cat set-reservations.sh | ssh root@gl-mt2500.tail54538d.ts.net \
#     'cat > /tmp/set-reservations.sh && sh /tmp/set-reservations.sh'
# (router has no sftp-server; can't scp.)

set -e
add() {
  name="$1"; mac="$2"; ip="$3"
  existing=$(uci -q show dhcp \
              | grep -E "=mac\.'$mac'$" \
              | head -1 \
              | cut -d. -f2 \
              | cut -d= -f1)
  if [ -n "$existing" ]; then
    echo "  $mac already reserved ($existing) -- skipping"
    return
  fi
  sid=$(uci add dhcp host)
  uci set dhcp.$sid.name="$name"
  uci set dhcp.$sid.mac="$mac"
  uci set dhcp.$sid.ip="$ip"
  echo "  + $name  $mac -> $ip"
}

add truenas          6c:bf:b5:04:d9:97 192.168.8.100
add pve-framework    9c:bf:0d:01:4c:d6 192.168.8.129
add pve-thermaltake  4c:ed:fb:bf:ab:7d 192.168.8.117
add pve-aspiree15    54:ab:3a:9b:e9:4c 192.168.8.102
add pve-aspires      00:e0:4c:68:a4:fa 192.168.8.103
add raspberrypi      d8:3a:dd:45:d3:7e 192.168.8.243

uci commit dhcp
/etc/init.d/dnsmasq reload
echo "--- reservations now in place: ---"
uci show dhcp | grep -E "@host\["