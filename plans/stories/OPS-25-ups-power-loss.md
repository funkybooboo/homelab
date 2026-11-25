# OPS-25: UPS power-loss protection

As the operator, I want the fleet to know when mains power dies and
shut itself down cleanly before the UPS battery empties -- so an
outage costs minutes of downtime instead of a corrupted pool or a
fleet of dirty filesystems.

**Status**: planned (design recorded 2026-11-25)
**Arc**: v4 (resilience automation; pairs with the off-site alerting
design -- power events are exactly what should page you)

## Hardware

APC BE600M1 (600VA / 330W) with its USB data cable. Small battery
-- expect single-digit minutes under any real load, so the
choreography must start early, not at 10% battery.

## Design sketch

- **Monitor host: the Pi.** It is a full cluster member, draws
  nothing, has USB, and already runs node-level services under the
  node_glue pattern (no new guest needed -- a daemon, not a CT).
  The Pi AND the router must sit ON the UPS battery: the monitor
  that dies first is worthless.
- **Software: NUT (Network UPS Tools)**, driver `usbhid-ups` (the
  BE600M1 is USB-HID; apcupsd is the fallback if the device turns
  out to want APC's smart protocol instead -- proven at build time).
- **Choreography:**
  1. `onbattery` grace timer (~60-120s -- ride out blips without
     drama; most outages are seconds long)
  2. notify via ntfy immediately: "power out; fleet on battery;
     shutdown begins in N minutes if it persists"
  3. if still on battery: guests halt first (PVE API, pct shutdown
     order), then truenas, then the nodes, then the Pi last
  4. `onbattery` clears during grace -> cancel, notify "power back"
- **Alerting:** the on-battery event is a first-class watcher/ntfy
  notification; under the off-site alerting design it also reaches
  the VPS delivery path, so a dead lab still tells the phone why.
- **Wake-up:** after power returns, nodes stay off until the
  operator presses power (the standing human-gated model) UNLESS
  BIOS AC-power-on is deliberately enabled per node -- operator
  choice recorded at build time.

## Standing-rule amendment (explicit)

The OPS-23 doctrine says nodes never self-reboot and reboots are
human-gated. THIS story adds the sanctioned exception class:
**power-loss shutdown is automated on purpose** -- the alternative
is data loss, and the operator is choosing automation here with
eyes open. It is not a precedent for update reboots; it is its own
class, recorded here.

## Acceptance criteria

- [ ] UPS monitored from the Pi (NUT driver proven against the
      BE600M1; upsc reports on-battery + battery.charge)
- [ ] Grace timer + cancellation proven (pull the UPS plug for 30s
      -> notify, no shutdown; pull it for the grace period ->
      choreography begins)
- [ ] Choreography proven in a drill: guests, truenas, nodes, Pi
      -- in order, clean halts, no corruption
- [ ] ntfy (and later the VPS path) carries the outage story end
      to end
- [ ] The shutdown sequence is a repo script (declarative, not
      hand-wiring on the Pi)

## Notes

Physical wiring prerequisite: UPS battery outlets -> router, Pi
(the monitor must outlive everything it shuts down). Which other
gear rides the battery is the operator's call -- the detection
does not require nodes on the UPS; the fleet is shut down over
the network, not through the wall.

Honest limitation: if the UPS's own USB reporting dies, or the
outage kills the UPS + Pi together, the fleet goes down hard --
identical to today's no-UPS behavior. This story is strictly
additive; it has no new silent-failure mode beyond the monitor
itself (which the heartbeat family already watches).
