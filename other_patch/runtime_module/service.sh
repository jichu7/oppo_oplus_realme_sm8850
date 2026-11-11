#!/system/bin/sh
# Re-apply after ueventd/init has finished creating device nodes.
MODDIR=${0%/*}
LOG=/data/local/tmp/ntsync_rw.log
exec >>"$LOG" 2>&1

sleep 8
echo "=== service $(date) ==="

[ -e /dev/ntsync ] || exit 0

chmod 0666 /dev/ntsync
chown root:root /dev/ntsync

if ! command -v chcon >/dev/null 2>&1; then
  exit 0
fi

for t in ntsync_device ashmem_device gpu_device; do
  if chcon "u:object_r:${t}:s0" /dev/ntsync 2>/dev/null; then
    echo "label=${t}"
    exit 0
  fi
done

echo "chcon failed for all candidate types"
