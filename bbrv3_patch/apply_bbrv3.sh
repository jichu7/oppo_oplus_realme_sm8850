#!/usr/bin/env bash
# 为 6.12 内核应用 XanMod 的 BBRv3 补丁系列（含其前置补丁）。
#
# 用法:
#   sh apply_bbrv3.sh <内核源码根目录>      # 例如 sh apply_bbrv3.sh ./common
#   sh apply_bbrv3.sh                     # 默认当前目录
#
# 说明:
#   - 补丁系列来源: https://gitlab.com/xanmod/linux-patches (eol/linux-6.12.y-xanmod/net/tcp/bbr3)
#   - 19 个补丁按编号顺序应用，任何一个失败都会立即退出（不做静默忽略）。
#   - 已应用过（tcp_bbr.c 中检测到 BBR_VERSION 3）会直接跳过，可重复执行。
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"

if [ -d "$TARGET/common/net/ipv4" ]; then
  KDIR="$TARGET/common"
elif [ -d "$TARGET/net/ipv4" ]; then
  KDIR="$TARGET"
else
  echo "[-] 找不到内核源码目录: $TARGET（需要包含 net/ipv4 或 common/net/ipv4）" >&2
  exit 1
fi

BBRFILE="$KDIR/net/ipv4/tcp_bbr.c"
if [ -f "$BBRFILE" ] && grep -Eq '#define BBR_VERSION[[:space:]]+3' "$BBRFILE"; then
  echo "[+] 检测到 BBRv3 已应用，跳过"
  exit 0
fi

if [ ! -f "$BBRFILE" ]; then
  echo "[-] 未找到 $BBRFILE" >&2
  exit 1
fi

cd "$KDIR"

count=0
for p in "$SCRIPT_DIR"/patches/*.patch; do
  name="$(basename "$p")"
  echo ">>> 应用 $name"
  # -F3: 允许 3 行上下文模糊，兼容一加厂商内核相对 6.12.58 的少量改动
  if ! patch -p1 -F3 --forward --no-backup-if-mismatch -i "$p"; then
    echo "[-] 补丁应用失败: $name" >&2
    echo "[-] 请检查内核源码版本是否为 6.12.x，或该文件是否已被其他补丁修改" >&2
    exit 1
  fi
  count=$((count + 1))
done

if ! grep -Eq '#define BBR_VERSION[[:space:]]+3' "$BBRFILE"; then
  echo "[-] 补丁执行完毕但未检测到 BBRv3（BBR_VERSION 3），请检查补丁是否被正确应用" >&2
  exit 1
fi

echo "[+] BBRv3 补丁系列应用完成（$count 个补丁）"
