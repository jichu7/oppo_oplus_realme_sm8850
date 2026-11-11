#!/usr/bin/env bash
set -euo pipefail

# 用法：
#   ./apply_to_vendor.sh <VENDOR_ROOT> <SEPOLICY_DIR>
# 示例：
#   ./apply_to_vendor.sh ../../vendor/oplus/sm8850 ../../device/oplus/sepolicy/vendor
#
# VENDOR_ROOT   包含 etc/ueventd.rc 的 vendor 根目录
# SEPOLICY_DIR  已加入 BOARD_VENDOR_SEPOLICY_DIRS 的策略目录
#
# 本脚本只负责合并文件，不修改 Android.bp / BoardConfig.mk。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_ROOT="${1:-}"
SEPOLICY_DIR="${2:-}"

if [[ -z "$VENDOR_ROOT" || -z "$SEPOLICY_DIR" ]]; then
  echo "用法: $0 <VENDOR_ROOT> <SEPOLICY_DIR>" >&2
  exit 1
fi

UEVENTD="$VENDOR_ROOT/etc/ueventd.rc"
if [[ ! -f "$UEVENTD" ]]; then
  echo "找不到 $UEVENTD，请确认 VENDOR_ROOT 是 vendor 分区根目录。" >&2
  exit 1
fi
if [[ ! -d "$SEPOLICY_DIR" ]]; then
  echo "找不到策略目录 $SEPOLICY_DIR，请确认它已加入 BOARD_VENDOR_SEPOLICY_DIRS。" >&2
  exit 1
fi

# 1) ueventd 规则（已有旧规则时改成 0666，避免保留 0600）
if grep -qE '^[[:space:]]*/dev/ntsync[[:space:]]' "$UEVENTD"; then
  sed -i -E 's#^[[:space:]]*/dev/ntsync[[:space:]].*#/dev/ntsync 0666 root root#' "$UEVENTD"
  echo "已更新 ueventd 规则: $UEVENTD"
else
  printf '\n# NTSync: 全局可读写\n/dev/ntsync 0666 root root\n' >> "$UEVENTD"
  echo "已追加 ueventd 规则: $UEVENTD"
fi

# 2) SELinux 类型与放行规则
install -m 0644 "$SCRIPT_DIR/ntsync_device.te" "$SEPOLICY_DIR/ntsync_device.te"
echo "已复制 ntsync_device.te: $SEPOLICY_DIR"

# 3) file_contexts（已有旧标签时改成 ntsync_device）
if [[ -f "$SEPOLICY_DIR/file_contexts" ]] && grep -qE '^[[:space:]]*/dev/ntsync[[:space:]]' "$SEPOLICY_DIR/file_contexts"; then
  sed -i -E 's#^[[:space:]]*/dev/ntsync[[:space:]].*#/dev/ntsync u:object_r:ntsync_device:s0#' "$SEPOLICY_DIR/file_contexts"
  echo "已更新 file_contexts: $SEPOLICY_DIR/file_contexts"
else
  printf '/dev/ntsync u:object_r:ntsync_device:s0\n' >> "$SEPOLICY_DIR/file_contexts"
  echo "已追加 file_contexts: $SEPOLICY_DIR/file_contexts"
fi

echo
echo "完成。请确认该目录已加入 BOARD_VENDOR_SEPOLICY_DIRS，然后重新编译 vendor/sepolicy。"
