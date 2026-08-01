#!/bin/bash
# vzdump-ntfy-hook.sh -- PVE vzdump hook script that publishes an ntfy phone
# push on backup job errors + completions. Deployed to
# /usr/local/sbin/vzdump-ntfy-hook.sh on every PVE node, wired into the
# Saturday 21:00 vzdump job via `--script /usr/local/sbin/vzdump-ntfy-hook.sh`
# (or pvesh set on the job config).
#
# PVE invokes hook scripts at several phases with environment variables:
#   VMID, VMTYPE, PHASE (job-start | job-end | job-error | backup-start |
#                        backup-end | backup-abort | log-end | pre-stop |
#                        pre-restart), LOGFILE, VZDUMP_TMPDIR, etc.
# We only act on the high-level phases:
#   job-start  -> nothing (too noisy, every guest)
#   job-end    -> low-priority "OK" ping with the per-job summary
#   job-error  -> urgent "[FAIL] vzdump" with the failing guestid + log path
#
# The script is a no-op (exit 0) if /etc/ntfy-publish.env is missing, so a
# missing notifier never breaks a backup.
set -u

NTFY_HELPER=/usr/local/sbin/ntfy-publish.sh
[ -r "$NTFY_HELPER" ] && . "$NTFY_HELPER"
ntfy_publish() { :; }  # override-safe no-op if helper absent

HOST=$(hostname)
case "${PHASE:-}" in
  job-error)
    ntfy_publish "[FAIL] vzdump $HOST vm${VMID:-?}" \
      "vzdump backup of VM/CT ${VMID:-?} (${VMTYPE:-}) on $HOST FAILED. Log: ${LOGFILE:-/var/log/vzdump.log}" \
      urgent rotating_light
    ;;
  job-end)
    # Only push the OK on the *job* end (once per full backup run), not per-guest.
    ntfy_publish "[OK] vzdump $HOST" \
      "vzdump job ended on $HOST. Log: ${LOGFILE:-/var/log/vzdump.log}" \
      low white_check_mark
    ;;
esac

exit 0
