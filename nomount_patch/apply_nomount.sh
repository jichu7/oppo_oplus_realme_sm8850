#!/bin/sh
# ============================================================
# NoMount 内核补丁应用脚本（内核侧，上游 maxsteeel/nomount v22）
#
# 用法: sh apply_nomount.sh [内核源码根目录]
#       不传参数时默认为当前目录 "."
#
# 脚本把 src/ 中的 NoMount 源文件放入 <内核树>/fs/nomount/，
# 并在 fs/Makefile、fs/Kconfig 中挂好编译与配置入口。
# 所有操作幂等，可安全重复执行。
# ============================================================
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC_DIR="$SCRIPT_DIR/src"
TARGET=${1:-.}

log() { printf '%s\n' "$*"; }
die() { printf '[-] %s\n' "$*" >&2; exit 1; }

[ -d "$TARGET" ] || die "目标目录不存在: $TARGET"

for f in Kconfig Makefile nomount.c nomount.h; do
	[ -f "$SRC_DIR/$f" ] || die "缺少 NoMount 源文件: $SRC_DIR/$f"
done

if [ -d "$TARGET/fs" ]; then
	FS_DIR="$TARGET/fs"
elif [ -d "$TARGET/common/fs" ]; then
	FS_DIR="$TARGET/common/fs"
else
	die "在 $TARGET 下找不到 fs/ 或 common/fs/，请把参数指向内核源码根目录"
fi

FS_MAKEFILE="$FS_DIR/Makefile"
FS_KCONFIG="$FS_DIR/Kconfig"
[ -f "$FS_MAKEFILE" ] || die "缺少 $FS_MAKEFILE"
[ -f "$FS_KCONFIG" ] || die "缺少 $FS_KCONFIG"

# 1. 放置 NoMount 源文件
mkdir -p "$FS_DIR/nomount"
for f in Kconfig Makefile nomount.c nomount.h; do
	cp -f "$SRC_DIR/$f" "$FS_DIR/nomount/$f"
done
log "[+] NoMount 源文件已放入: $FS_DIR/nomount"

# 2. fs/Makefile: 挂上编译规则
if grep -q 'CONFIG_NOMOUNT' "$FS_MAKEFILE"; then
	log "[=] fs/Makefile 已包含 NoMount 编译规则，跳过"
else
	printf '\nobj-$(CONFIG_NOMOUNT) += nomount/\n' >> "$FS_MAKEFILE"
	log "[+] 已在 fs/Makefile 追加: obj-\$(CONFIG_NOMOUNT) += nomount/"
fi

# 3. fs/Kconfig: 在最后一个 endmenu 之前插入配置入口
if grep -q 'fs/nomount/Kconfig' "$FS_KCONFIG"; then
	log "[=] fs/Kconfig 已包含 NoMount 配置入口，跳过"
else
	TMP="$FS_KCONFIG.nomount.tmp"
	awk '
		{ line[NR] = $0 }
		END {
			n = NR
			pos = 0
			for (i = n; i >= 1; i--) {
				if (line[i] ~ /^endmenu[[:space:]]*$/) { pos = i; break }
			}
			for (i = 1; i <= n; i++) {
				if (pos == i) {
					print ""
					print "source \"fs/nomount/Kconfig\""
				}
				print line[i]
			}
			if (pos == 0) {
				print ""
				print "source \"fs/nomount/Kconfig\""
			}
		}
	' "$FS_KCONFIG" > "$TMP"
	mv -f "$TMP" "$FS_KCONFIG"
	log "[+] 已在 fs/Kconfig 插入: source \"fs/nomount/Kconfig\""
fi

cat <<'EOF'

[+] NoMount 内核侧集成完成。
    下一步: 在内核 defconfig 中加入
        CONFIG_NOMOUNT=y
    （本仓库 GitHub Actions 工作流与 local/builder_*.sh 已自动处理）
EOF
