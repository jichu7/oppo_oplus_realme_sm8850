#!/system/bin/sh
# Runs early; the ntsync misc device may appear slightly later.
MODDIR=${0%/*}
LOG=/data/local/tmp/ntsync_rw.log
exec >>"$LOG" 2>&1

echo "=== post-fs-data $(date) ==="

i=0
while [ ! -e /dev/ntsync ] && [ "$i" -lt 30 ]; do
  sleep 0.5
  i=$((i + 1))
done

if [ ! -e /dev/ntsync ]; then
  echo "no /dev/ntsync"
  exit 0
fi

chmod 0666 /dev/ntsync
chown root:root /dev/ntsync

if ! command -v chcon >/dev/null 2>&1; then
  echo "chcon unavailable; mode only"
  exit 0
fi

# Prefer a dedicated type if the running policy defines it.
# Fall back to common app-accessible device types for ROMs without vendor source.
for t in ntsync_device ashmem_device gpu_device; do
  if chcon "u:object_r:${t}:s0" /dev/ntsync 2>/dev/null; then
    echo "label=${t}"
    exit 0
  fi
done

echo "chcon failed for all candidate types"
