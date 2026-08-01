# nvidia-uvm device nodes for Jellyfin transcoding (pve-thermaltake)

The NVIDIA GPU passed through to Jellyfin CT 102 on `pve-thermaltake` is used
for NVENC hardware transcoding (`/etc/jellyfin/encoding.xml` has
`<HardwareAccelerationType>nvenc</HardwareAccelerationType>`). Without the
fix below, **anything that needs re-encoding fails with "Playback failed due
to a fatal player error"** while remux/copy (`-codec copy`) plays fine.

## Root cause

The dkms `nvidia` driver on this host ships **no udev rule**. The `nvidia-uvm`
module registers its char device (`major "nvidia-uvm"` in `/proc/devices`,
currently 234) but **devtmpfs never creates the `/dev/nvidia-uvm` node**, so:

* On the host `/dev/nvidia-uvm` and `/dev/nvidia-uvm-tools` do not exist.
* CT 102's `lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file`
  therefore creates a **0-byte regular placeholder** with mode `0000` inside
  the CT.
* Jellyfin runs as user `jellyfin`, so `cuInit(0)` fails with
  `CUDA_ERROR_UNKNOWN: unknown error` and ffmpeg aborts:
  ```
  Failed to set value 'cuda=cu:0' for option 'init_hw_device'
  Error parsing global options: Generic error in an external library
  ```

The other nvidia nodes (`/dev/nvidia0`, `nvidiactl`, `nvidia-modeset`) **are**
mode 0666 (created by the driver), which is why `nvidia-smi` as root and
remux-only playback keep working.

## Fix: boot-time mknod service

`nvidia-uvm-devnodes.sh` loads `nvidia-uvm` and idempotently creates the two
device nodes (mode 0666). `nvidia-uvm-devnodes.service` runs it at boot.

### Install (on pve-thermaltake only -- the host with the GPU)

```sh
install -m 0755 nvidia-uvm-devnodes.sh /usr/local/sbin/nvidia-uvm-devnodes.sh
install -m 0644 nvidia-uvm-devnodes.service /etc/systemd/system/nvidia-uvm-devnodes.service
systemctl daemon-reload
systemctl enable --now nvidia-uvm-devnodes.service
```

### Verify (on pve-thermaltake)

```sh
ls -la /dev/nvidia-uvm /dev/nvidia-uvm-tools     # char devices, crw-rw-rw-
# inside CT 102 after a reboot (bind-mount must re-resolve the real node):
pct reboot 102
pct exec 102 -- ls -la /dev/nvidia-uvm            # must show 'c', not 0 bytes
pct exec 102 -- sudo -u jellyfin /usr/lib/jellyfin-ffmpeg/ffmpeg \
  -hide_banner -init_hw_device cuda=cu:0 \
  -f lavfi -i testsrc=duration=1:size=320x240:rate=10 -c:v h264_nvenc -f null -
# expect: "frame= ... encoder ... h264_nvenc"
```

## Notes

* The module's major number is dynamic (currently 234); the script reads it
  from `/proc/devices` rather than hard-coding it.
* `nvidia-uvm` depends on `nvidia` symbols; `modprobe nvidia-uvm` pulls
  `nvidia` in too, so this service is sufficient at boot (no extra
  `modules-load.d` entry needed).
* CT 102 must be (re)started *after* the host nodes exist for the bind mount
  to attach to the real char device instead of a freshly-created 0-byte
  placeholder. The `lxc.mount.entry ...create=file` fallback silently masks a
  missing host node -- a missing `/dev/nvidia-uvm` shows up as a 0-byte
  regular file inside the CT, not as a mount failure.
* CT 102 currently has `onboot: 0`; after a pve-thermaltake reboot Jellyfin
  must be started by hand (or set `onboot: 1` to autostart the CT with the
  GPU).

## Revert

```sh
systemctl disable --now nvidia-uvm-devnodes.service
rm -f /etc/systemd/system/nvidia-uvm-devnodes.service /usr/local/sbin/nvidia-uvm-devnodes.sh
systemctl daemon-reload
rm -f /dev/nvidia-uvm /dev/nvidia-uvm-tools   # optional
```