#!/bin/bash
set -e

# ===== 获取脚本目录 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ===== 内核版本(取自脚本文件名, 例: builder_6.12.69_gki.sh -> 6.12.69_gki) =====
KERNEL_VER="$(basename "$0" .sh)"
KERNEL_VER="${KERNEL_VER#builder_}"

# ===== 设置自定义参数 =====
echo "===== 欧加真MT6993通用6.12.23 A16 OKI内核本地编译脚本 By Coolapk@cctv18 ====="
echo ">>> 读取用户配置..."
MANIFEST=${MANIFEST:-oppo+oplus+realme}
read -p "请输入自定义内核后缀（默认：android16-5-ge7f2a9832757-ab13799791-4k）: " CUSTOM_SUFFIX
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-android16-5-ge7f2a9832757-ab13799791-4k}
read -p "是否启用susfs？(y/n，默认：y): " APPLY_SUSFS
APPLY_SUSFS=${APPLY_SUSFS:-y}

if [[ "$APPLY_SUSFS" == [yY] ]]; then
  read -p "请选择 SUSFS 版本(latest=跟随上游最新, 2.4.0 / 2.3.0=固定版本, 默认：latest): " SUSFS_VERSION
fi
SUSFS_VERSION=${SUSFS_VERSION:-latest}
read -p "是否启用 KPM？(y-启用 KpatchNext独立kpm实现, n-关闭kpm，默认：n): " USE_PATCH_LINUX
USE_PATCH_LINUX=${USE_PATCH_LINUX:-n}
read -p "KSU分支版本(r=BakaSU, y=SukiSU Ultra, n=KernelSU Next, k=KSU, l=lkm模式(无内置KSU), 默认：r): " KSU_BRANCH
KSU_BRANCH=${KSU_BRANCH:-r}
read -p "KSU 自定义提交(留空=跟随所选分支最新; 可填 分支/标签/commit SHA, 或 仓库@版本 如 Baka-SU/BakaSU@main, 默认：留空): " KSU_REF_CUSTOM
KSU_REF_CUSTOM=${KSU_REF_CUSTOM:-}
read -p "是否应用 lz4 1.10.0 & zstd 1.5.7 补丁？(y/n，默认：y): " APPLY_LZ4
APPLY_LZ4=${APPLY_LZ4:-y}
read -p "是否应用 lz4kd 补丁？(y/n，默认：n): " APPLY_LZ4KD
APPLY_LZ4KD=${APPLY_LZ4KD:-n}
read -p "是否集成 NoMount 内核支持(可隐藏模块挂载痕迹, 需配合 NoMount 用户态模块; y/n, 默认y): " APPLY_NOMOUNT
APPLY_NOMOUNT=${APPLY_NOMOUNT:-y}
read -p "是否启用网络功能增强优化配置？(y/n，默认：y): " APPLY_BETTERNET
APPLY_BETTERNET=${APPLY_BETTERNET:-y}
read -p "是否添加 BBR 等一系列拥塞控制算法？(y添加/n禁用/d默认，默认：n): " APPLY_BBR
APPLY_BBR=${APPLY_BBR:-n}
read -p "是否添加 Droidspaces 容器支持？(n禁用/s标准/e扩展，默认：n): " APPLY_DROIDSPACES
APPLY_DROIDSPACES=${APPLY_DROIDSPACES:-n}
read -p "是否启用ADIOS调度器？(y/n，默认：y): " APPLY_ADIOS
APPLY_ADIOS=${APPLY_ADIOS:-y}
read -p "是否启用Re-Kernel？(y/n，默认：n): " APPLY_REKERNEL
APPLY_REKERNEL=${APPLY_REKERNEL:-n}
read -p "是否启用内核级基带保护？(y/n，默认：y): " APPLY_BBG
APPLY_BBG=${APPLY_BBG:-y}

if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
  KSU_TYPE="SukiSU Ultra"
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
  KSU_TYPE="BakaSU"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  KSU_TYPE="KernelSU Next"
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  KSU_TYPE="KernelSU"
else
  KSU_TYPE="no KSU"
fi

echo
echo "===== 配置信息 ====="
echo "适用机型: $MANIFEST"
echo "自定义内核后缀: -$CUSTOM_SUFFIX"
echo "KSU分支版本: $KSU_TYPE"
echo "KSU 自定义提交: ${KSU_REF_CUSTOM:-默认}"
echo "启用susfs: $APPLY_SUSFS"
echo "SUSFS 版本: $SUSFS_VERSION"
echo "启用 KPM: $USE_PATCH_LINUX"
echo "应用 lz4&zstd 补丁: $APPLY_LZ4"
echo "应用 lz4kd 补丁: $APPLY_LZ4KD"
echo "NoMount 支持: $APPLY_NOMOUNT"
echo "应用网络功能增强优化配置: $APPLY_BETTERNET"
echo "应用 BBR 等算法: $APPLY_BBR"
echo "应用 Droidspaces 容器支持: $APPLY_DROIDSPACES"
echo "启用ADIOS调度器: $APPLY_ADIOS"
echo "启用Re-Kernel: $APPLY_REKERNEL"
echo "启用内核级基带保护: $APPLY_BBG"
echo "===================="
echo

# ===== 创建工作目录 =====
WORKDIR="$SCRIPT_DIR"
cd "$WORKDIR"

# ===== 安装构建依赖 =====
echo ">>> 安装构建依赖..."
# Function to run a command with sudo if not already root
SU() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

SU apt-mark hold firefox && apt-mark hold libc-bin && apt-mark hold man-db
SU rm -rf /var/lib/man-db/auto-update
SU apt-get update
SU apt-get install --no-install-recommends -y curl bison flex clang binutils dwarves git lld pahole zip perl make gcc python3 python-is-python3 bc libssl-dev libelf-dev libdw-dev cpio xz-utils tar unzip aria2

# ===== 初始化仓库 =====
echo ">>> 初始化仓库..."
rm -rf kernel_workspace
mkdir kernel_workspace
cd kernel_workspace

echo "正在克隆源码仓库..."
aria2c -s16 -x16 -k1M https://github.com/cctv18/android_kernel_oppo_mt6993/archive/refs/heads/oppo/mt6993_b_16.0.0_find_x9.zip -o common.zip && 
unzip -q common.zip && 
mv "android_kernel_oppo_mt6993-oppo-mt6993_b_16.0.0_find_x9" common &&
rm -rf common.zip &

echo "正在克隆llvm-clang19工具链..." &&
mkdir -p clang19 &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang19-r536225/clang-r536225.zip -o clang.zip &&
unzip -q clang.zip -d clang19 &&
rm -rf clang.zip &

echo "正在克隆Rust 1.82.0工具链..." &&
mkdir -p rust &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang19-r536225/rust.zip -o rust.zip &&
unzip -q rust.zip -d rust &&
rm -rf rust.zip &

echo "正在克隆构建工具..." &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang19-r536225/build-tools.zip -o build-tools.zip &&
unzip -q build-tools.zip &&
rm -rf build-tools.zip &

wait
echo "所有源码及llvm-clang19工具链初始化完成！"
echo ">>> 初始化仓库完成!"

for f in common/scripts/setlocalversion; do
  sed -i 's/ -dirty//g' "$f"
  sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f"
done

# ===== 替换版本后缀 =====
echo ">>> 替换内核版本后缀..."
for f in ./common/scripts/setlocalversion; do
  sed -i "\$s|echo \"\\\$res\"|echo \"-${CUSTOM_SUFFIX}\"|" "$f"
done
sudo sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-'${CUSTOM_SUFFIX}'"/' ./common/arch/arm64/configs/gki_defconfig
sed -i 's/${scm_version}//' ./common/scripts/setlocalversion
echo "CONFIG_LOCALVERSION_AUTO=n" >> ./common/arch/arm64/configs/gki_defconfig

# ===== 拉取 KSU 并设置版本号 =====
# 自定义 KSU 版本: 留空=跟随所选分支最新; 或 <分支|标签|commit SHA>; 或 <owner/repo>@<版本>
KSU_REF_RAW="$KSU_REF_CUSTOM"
KSU_REF_RAW="$(printf '%s' "$KSU_REF_RAW" | tr -d '[:space:]')"
KSU_REPO_IN=""
KSU_REF=""
if [[ "$KSU_REF_RAW" == *@* ]]; then
  KSU_REPO_IN="${KSU_REF_RAW%@*}"
  KSU_REF="${KSU_REF_RAW##*@}"
  KSU_REPO_IN="${KSU_REPO_IN#https://github.com/}"
  KSU_REPO_IN="${KSU_REPO_IN#http://github.com/}"
  KSU_REPO_IN="${KSU_REPO_IN#github.com/}"
  KSU_REPO_IN="${KSU_REPO_IN%.git}"
  KSU_REPO_IN="${KSU_REPO_IN%/}"
else
  KSU_REF="$KSU_REF_RAW"
fi
case "$KSU_BRANCH" in
  y|Y)     KSU_REPO_DEFAULT="SukiSU-Ultra/SukiSU-Ultra" ; KSU_REF_DEFAULT="main" ; KSU_SETUP_BRANCH="main" ;;
  r|R)     KSU_REPO_DEFAULT="Baka-SU/BakaSU" ; KSU_REF_DEFAULT="main" ; KSU_SETUP_BRANCH="main" ;;
  n|N)     KSU_REPO_DEFAULT="pershoot/KernelSU-Next" ; KSU_REF_DEFAULT="dev-susfs" ; KSU_SETUP_BRANCH="dev-susfs" ;;
  k|K)     KSU_REPO_DEFAULT="tiann/KernelSU" ; KSU_REF_DEFAULT="main" ; KSU_SETUP_BRANCH="main" ;;
  *)       KSU_REPO_DEFAULT="" ; KSU_REF_DEFAULT="" ; KSU_SETUP_BRANCH="" ;;
esac
KSU_MANAGER="none"
KSU_NAME="no KSU"
if [[ -z "$KSU_REPO_DEFAULT" ]]; then
  echo ">>> 已选择无内置KernelSU模式，跳过配置..."
else
  KSU_REPO="${KSU_REPO_IN:-$KSU_REPO_DEFAULT}"
  KSU_CHECKOUT="${KSU_REF:-$KSU_REF_DEFAULT}"
  if [[ -n "$KSU_REF_RAW" ]]; then
    KSU_REF_DESC="自定义 $KSU_REF_RAW"
  else
    KSU_REF_DESC="跟随上游(默认 $KSU_CHECKOUT)"
  fi
  echo ">>> KSU 仓库: $KSU_REPO"
  echo ">>> KSU 目标版本: $KSU_CHECKOUT ($KSU_REF_DESC)"
  if [[ "$KSU_REPO" == *SukiSU* || "$KSU_REPO" == *sukisu* ]]; then
    # SukiSU Ultra: 上游 setup.sh 会从第三方 gitea 镜像拉取, 这里直接克隆真实源码再手动接入
    git clone -q --depth=1 "https://github.com/$KSU_REPO.git" KernelSU
    KSU_DIR="KernelSU"
    ln -sfn ../../KernelSU/kernel ./common/drivers/kernelsu
    grep -q 'CONFIG_KSU) += kernelsu/' ./common/drivers/Makefile || printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> ./common/drivers/Makefile
    grep -q 'drivers/kernelsu/Kconfig' ./common/drivers/Kconfig || sed -i '/endmenu/i source "drivers/kernelsu/Kconfig"' ./common/drivers/Kconfig
    echo ">>> 已克隆 $KSU_REPO 并接入 common/drivers/kernelsu"
  else
    KSU_SETUP_OK=0
    for b in "$KSU_SETUP_BRANCH" main master; do
      if curl -fsSL "https://raw.githubusercontent.com/$KSU_REPO/refs/heads/$b/kernel/setup.sh" -o /tmp/ksu_setup.sh 2>/dev/null; then
        KSU_SETUP_OK=1
        break
      fi
    done
    if [[ $KSU_SETUP_OK -ne 1 ]]; then
      echo "!!! 无法从仓库 $KSU_REPO 获取 kernel/setup.sh(仓库名或分支无效)"
      exit 1
    fi
    bash /tmp/ksu_setup.sh "$KSU_CHECKOUT"
    KSU_DIR="$(find . -maxdepth 1 -type d \( -name 'KernelSU' -o -name 'KernelSU-Next' -o -name 'BakaSU' -o -name 'SukiSU' \) -print | head -n1)"
    if [[ -z "$KSU_DIR" ]]; then
      echo "!!! 未找到 KSU 源码目录，setup.sh 可能执行失败"
      exit 1
    fi
    KSU_DIR="${KSU_DIR#./}"
  fi
  echo ">>> KSU 源码目录: $KSU_DIR"
  # 强制定位到指定版本(setup.sh 定位失败会静默回退默认分支)
  if [[ -n "$KSU_REF" ]]; then
    if ! git -C "$KSU_DIR" checkout -q "$KSU_REF" 2>/dev/null; then
      if git -C "$KSU_DIR" fetch -q origin "$KSU_REF" 2>/dev/null; then
        git -C "$KSU_DIR" checkout -q FETCH_HEAD
      else
        # 短 SHA 不是合法 ref，先用 GitHub API 解析成完整 commit SHA
        KSU_SHA=$(curl -fsSL "https://api.github.com/repos/$KSU_REPO/commits/$KSU_REF" 2>/dev/null | grep -o '"sha": *"[0-9a-f]\{40\}"' | head -n1 | cut -d'"' -f4)
        if [[ -z "$KSU_SHA" ]]; then
          echo "!!! 无法解析 KSU 版本 $KSU_REF (仓库 $KSU_REPO 的分支/标签/SHA 无效)"
          exit 1
        fi
        git -C "$KSU_DIR" fetch -q origin "$KSU_SHA" || { echo "!!! 无法获取 KSU 提交 $KSU_SHA"; exit 1; }
        git -C "$KSU_DIR" checkout -q "$KSU_SHA"
      fi
    fi
  fi
  KSU_SHORT="$(git -C "$KSU_DIR" rev-parse --short HEAD)"
  echo ">>> KSU 实际提交: $KSU_SHORT ($(git -C "$KSU_DIR" rev-parse --abbrev-ref HEAD))"
  # 自动识别管理器(以源码实际内容为准)
  KSU_KBUILD="$KSU_DIR/kernel/Kbuild"
  KSU_MANAGER=""
  if [[ "$KSU_REPO" == *SukiSU* || "$KSU_REPO" == *sukisu* ]] \
    || { [[ -f "$KSU_KBUILD" ]] && grep -q 'REPO_NAME[[:space:]]*:=[[:space:]]*SukiSU' "$KSU_KBUILD"; }; then
    KSU_MANAGER="sukisu"
  elif [[ -f "$KSU_KBUILD" ]] && grep -q 'REPO_NAME[[:space:]]*:=[[:space:]]*BakaSU' "$KSU_KBUILD"; then
    KSU_MANAGER="bakasu"
  elif [[ -f "$KSU_KBUILD" ]] && grep -q 'KSU_VERSION_FALLBACK' "$KSU_KBUILD"; then
    KSU_MANAGER="ksunext"
  elif [[ -f "$KSU_KBUILD" ]] && grep -q 'DKSU_VERSION' "$KSU_KBUILD"; then
    KSU_MANAGER="ksu"
  elif [[ -f "$KSU_DIR/kernel/supercall/dispatch.c" ]]; then
    KSU_MANAGER="bakasu"
  fi
  if [[ -z "$KSU_MANAGER" ]]; then
    case "$KSU_BRANCH" in
      y|Y)     KSU_MANAGER="sukisu" ;;
      r|R)     KSU_MANAGER="bakasu" ;;
      n|N)     KSU_MANAGER="ksunext" ;;
      k|K)     KSU_MANAGER="ksu" ;;
      *)       KSU_MANAGER="none" ;;
    esac
    echo "!!! 无法从源码识别 KSU 管理器，回退使用选择: $KSU_MANAGER"
  fi
  case "$KSU_MANAGER" in
    bakasu)  KSU_NAME="BakaSU" ;;
    sukisu)  KSU_NAME="SukiSU Ultra" ;;
    ksunext) KSU_NAME="KernelSU Next" ;;
    ksu)     KSU_NAME="KernelSU" ;;
    *)       KSU_NAME="no KSU" ;;
  esac
  echo ">>> KSU 管理器识别: $KSU_NAME ($KSU_MANAGER)"
  # 按识别结果注入版本号
  case "$KSU_MANAGER" in
    sukisu)
      # SukiSU Ultra 的版本号由 kernel/Kbuild 自己按 30000 + 提交数 + 996 计算, 这里同步一份
      git -C "$KSU_DIR" fetch -q --unshallow 2>/dev/null || true
      KSU_VERSION=$(expr $(git -C "$KSU_DIR" rev-list --count HEAD 2>/dev/null || echo 0) + 30996)
      ;;
    bakasu)
      echo 'CONFIG_KSU_FULL_NAME_FORMAT="%TAG_NAME%-%COMMIT_SHA%@cctv18"' >> ./common/arch/arm64/configs/gki_defconfig
      KSU_VERSION=$(expr $(git -C "$KSU_DIR" rev-list --count HEAD 2>/dev/null || echo 0) + 30700)
      ;;
    ksunext)
      if [[ -z "$KSU_REF" ]]; then
        KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=dev&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
      else
        KSU_VERSION=$(expr $(git -C "$KSU_DIR" rev-list --count HEAD 2>/dev/null || echo 0) + 30000)
      fi
      KSU_GIT_TAG="$(git -C "$KSU_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
      if [[ -z "$KSU_GIT_TAG" && -z "$KSU_REF" ]]; then
        KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s/"//')
      fi
      KSU_GIT_TAG="${KSU_GIT_TAG:-v0.0.1}"
      rm -rf "$KSU_DIR/.git"
      sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := $KSU_VERSION/g" "$KSU_DIR/kernel/Kbuild"
      sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := $KSU_GIT_TAG/g" "$KSU_DIR/kernel/Kbuild"
      # 为 KernelSU Next 添加 WildKSU 管理器支持
      cd ./common/drivers/kernelsu
      wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/apk_sign.patch
      patch -p2 -N -F 3 < apk_sign.patch || true
      cd "$WORKDIR/kernel_workspace"
      ;;
    ksu)
      if [[ -z "$KSU_REF" ]]; then
        KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/tiann/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
      else
        KSU_VERSION=$(expr $(git -C "$KSU_DIR" rev-list --count HEAD 2>/dev/null || echo 0) + 30000)
      fi
      sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" "$KSU_DIR/kernel/Kbuild"
      ;;
    *)
      echo "!!! 未识别的 KSU 管理器，跳过版本号注入"
      KSU_VERSION="unknown"
      ;;
  esac
  echo ">>> KSU 版本号: $KSU_VERSION"
fi

# ===== 克隆补丁仓库&应用 SUSFS 补丁 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 应用 SUSFS&hook 补丁..."
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo ">>> 克隆补丁仓库..."
  # 版本号 -> 上游固定提交(SUSFS 上游没给 2.x 打 tag；版本号取自 kernel_patches/include/linux/susfs.h 的 SUSFS_VERSION)
  # 2.4.0 = 上游 2ea91d1c37(适配 6.12 多基线，2026-11-17)；2.3.0 = 上游 456ea36dd4(2026-08-29)
  case "$SUSFS_VERSION" in
    latest) SUSFS_REF="" ; SUSFS_LABEL="latest(跟随上游分支 oki-android16-6.12)" ;;
    2.4.0)  SUSFS_REF=2ea91d1c37cc974b683d6ffbc2e913c3b728d1f5 ; SUSFS_LABEL="SUSFS 2.4.0" ;;
    2.3.0)  SUSFS_REF=456ea36dd442fdbf05e15d3c962753d3130cec21 ; SUSFS_LABEL="SUSFS 2.3.0" ;;
    *)      SUSFS_REF="$SUSFS_VERSION" ; SUSFS_LABEL="自定义版本 $SUSFS_VERSION" ;;
  esac
  echo ">>> SUSFS 版本: $SUSFS_LABEL"
  if [[ -z "$SUSFS_REF" ]]; then
    git clone --depth=1 https://github.com/cctv18/susfs4oki.git susfs4ksu -b oki-android16-6.12
  else
    git init -q susfs4ksu
    git -C susfs4ksu remote add origin https://github.com/cctv18/susfs4oki.git
    if ! git -C susfs4ksu fetch -q --depth=1 origin "$SUSFS_REF"; then
      # 短 SHA 不是有效 ref，先用 GitHub API 解析成完整 commit SHA 再拉取
      SUSFS_SHA=$(curl -fsSL "https://api.github.com/repos/cctv18/susfs4oki/commits/$SUSFS_REF" 2>/dev/null | grep -o '"sha": *"[0-9a-f]\{40\}"' | head -n1 | cut -d'"' -f4)
      if [[ -z "$SUSFS_SHA" ]]; then
        echo "!!! 无法解析 SUSFS 版本 $SUSFS_REF (分支/标签/SHA 无效)"
        exit 1
      fi
      git -C susfs4ksu fetch -q --depth=1 origin "$SUSFS_SHA" || { echo "!!! 无法获取 SUSFS 提交 $SUSFS_SHA"; exit 1; }
    fi
    git -C susfs4ksu checkout -q FETCH_HEAD
  fi
  SUSFS_FOUND=$(grep -m1 -o 'SUSFS_VERSION "v[0-9.]*"' susfs4ksu/kernel_patches/include/linux/susfs.h | cut -d'"' -f2)
  echo ">>> SUSFS 实际版本/提交: ${SUSFS_FOUND:-未知} @ $(git -C susfs4ksu rev-parse --short HEAD)"
  if [[ ! -f "susfs4ksu/kernel_patches/50_add_susfs_in_gki-android16-6.12.patch" ]]; then
    echo "!!! 该 SUSFS 版本不含 android16-6.12 补丁，请换一个版本"
    exit 1
  fi
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android16-6.12.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd ./common
  PATCH_FILE=50_add_susfs_in_gki-android16-6.12.patch
  # 新版 ACK 16K 内核把 vma_pages() 改成了 vma_data_pages()，补丁上下文对不上时
  # patch 会带 fuzz 把代码块盲插到错误函数里（编译期才报错），所以先对齐到源码实际写法
  if grep -q 'vma_data_pages(' fs/proc/task_mmu.c && grep -q 'if (!vma_pages(vma))' "$PATCH_FILE"; then
    sed -i 's/if (!vma_pages(vma))/if (!vma_data_pages(vma))/' "$PATCH_FILE"
    echo ">>> SUSFS 补丁上下文已对齐源码: vma_pages -> vma_data_pages"
  fi
  # 收紧 fuzz：不再允许整段上下文失配的盲插
  # 老版本 SUSFS 补丁(如 2.3.0)里只做 include 插入的 hunk，会因新基线在同一位置新增
  # 了 #include <linux/dma-buf.h> 而上下文中间不匹配(patch 无法自己定位)，这类
  # 失配用自愈脚本按源码实际位置补插；其它类型的失配仍然直接报错
  if ! patch -p1 -F 1 < "$PATCH_FILE"; then
    if command -v python3 >/dev/null 2>&1 && python3 "$SCRIPT_DIR/../other_patch/susfs_rej_repair.py" .; then
      echo ">>> SUSFS 补丁的 include 段落已按源码实际位置补插，继续构建"
    else
      echo "!!! SUSFS 补丁应用失败，请检查以下 rejects"
      find . -name '*.rej' -print -exec cat {} \;
      exit 1
    fi
  fi
else
  echo ">>> 未开启susfs，跳过susfs补丁配置..."
fi
cd "$WORKDIR/kernel_workspace"
if [[ "${KSU_MANAGER:-}" == "ksu" && "$APPLY_SUSFS" == [yY] ]]; then
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch "./${KSU_DIR:-KernelSU}/"
  cd "./${KSU_DIR:-KernelSU}"
  patch -p1 -F 3 < 10_enable_susfs_for_ksu.patch || true
fi
cd "$WORKDIR/kernel_workspace"

# ===== 应用 LZ4 & ZSTD 补丁 =====
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  echo ">>> 正在添加lz4 1.10.0 & zstd 1.5.7补丁..."
  git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8850.git
  cp ./oppo_oplus_realme_sm8850/zram_patch/001-lz4.patch ./common/
  cp ./oppo_oplus_realme_sm8850/zram_patch/002-zstd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  patch -p1 -F 3 < 001-lz4.patch || true
  patch -p1 -F 3 < 002-zstd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4&ZSTD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 应用 LZ4KD 补丁 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  echo ">>> 应用 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace/common"
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/lz4kd.patch
  patch -p1 -F 3 < lz4kd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== NoMount 内核支持 =====
if [[ "$APPLY_NOMOUNT" == [yY] ]]; then
  echo ">>> 集成 NoMount 内核支持..."
  cd "$WORKDIR/kernel_workspace"
  NOMOUNT_APPLY="$SCRIPT_DIR/../nomount_patch/apply_nomount.sh"
  if [ ! -f "$NOMOUNT_APPLY" ]; then
    echo ">>> 未找到 $NOMOUNT_APPLY ，请确认仓库根目录包含 nomount_patch/" >&2
    exit 1
  fi
  sh "$NOMOUNT_APPLY" ./common
  echo "CONFIG_NOMOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
  echo ">>> NoMount 集成完成"
else
  echo ">>> 跳过 NoMount 集成"
fi

# ===== 添加 defconfig 配置项 =====
echo ">>> 添加 defconfig 配置项..."
DEFCONFIG_FILE=./common/arch/arm64/configs/gki_defconfig

# 写入通用 SUSFS/KSU 配置
echo "CONFIG_KSU=y" >> "$DEFCONFIG_FILE"
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo "CONFIG_KSU_SUSFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> "$DEFCONFIG_FILE"
else
  echo "CONFIG_KSU_SUSFS=n" >> "$DEFCONFIG_FILE"
fi
#添加对 Mountify (backslashxx/mountify) 模块的支持
echo "CONFIG_TMPFS_XATTR=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TMPFS_POSIX_ACL=y" >> "$DEFCONFIG_FILE"

# 开启O2编译优化配置
echo "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y" >> "$DEFCONFIG_FILE"
#跳过将uapi标准头安装到 usr/include 目录的不必要操作，节省编译时间
echo "CONFIG_HEADERS_INSTALL=n" >> "$DEFCONFIG_FILE"

# 应用 CVE_2026_43499 修复补丁
cd common
wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/cve-2026-43499-rtmutex-6.12.patch
patch -p1 -F 3 < cve-2026-43499-rtmutex-6.12.patch
cd ..

# 6.12内核Rust配置
echo "CONFIG_RUST=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_ANDROID_BINDER_IPC_RUST=m" >> ./common/arch/arm64/configs/gki_defconfig

# 仅在启用了 LZ4KD 补丁时添加相关算法支持
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_ZSMALLOC=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
CONFIG_ZRAM_BACKEND_LZ4HC=y
CONFIG_ZRAM_BACKEND_LZ4K=y
CONFIG_ZRAM_BACKEND_LZ4KD=y
CONFIG_ZRAM_BACKEND_842=y
EOF

fi

# ===== 启用网络功能增强优化配置 =====
if [[ "$APPLY_BETTERNET" == "y" || "$APPLY_BETTERNET" == "Y" ]]; then
  echo ">>> 正在启用网络功能增强优化配置..."
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_MAX=65534" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_PORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMARK=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTIP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_MAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETIFACE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_LIST_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_NAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_TARGET_MASQUERADE=y" >> "$DEFCONFIG_FILE"
  #由于部分机型的vintf兼容性检测规则，在开启CONFIG_IP6_NF_NAT后开机会出现"您的设备内部出现了问题。请联系您的设备制造商了解详情。"的提示，故添加一个配置修复补丁，在编译内核时隐藏CONFIG_IP6_NF_NAT=y但不影响对应功能编译
  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/config.patch
  patch -p1 -F 3 < config.patch || true
  cd ..
fi

# ===== 添加 BBR 等一系列拥塞控制算法 =====
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" || "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
  echo ">>> 正在添加 BBR 等一系列拥塞控制算法..."
  echo "CONFIG_TCP_CONG_ADVANCED=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_CUBIC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_VEGAS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_NV=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_WESTWOOD=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_HTCP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BRUTAL=y" >> "$DEFCONFIG_FILE"
  if [[ "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
    echo "CONFIG_DEFAULT_TCP_CONG=bbr" >> "$DEFCONFIG_FILE"
  else
    echo "CONFIG_DEFAULT_TCP_CONG=cubic" >> "$DEFCONFIG_FILE"
  fi
fi

# ===== 启用 Droidspaces 容器支持 =====
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  echo ">>> 正在添加 Droidspaces 容器支持..."
  # 开启 Droidspaces 容器所需内核支持
  echo "CONFIG_PID_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IPC_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_USER_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_SYSVIPC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_DEVTMPFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NAMESPACES=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_POSIX_MQUEUE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_TARGET_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_RECENT=y" >> "$DEFCONFIG_FILE"
  # 开启 NTSync
  echo "CONFIG_NTSYNC=y" >> "$DEFCONFIG_FILE"
  cd common
  # 应用 Droidspaces 容器必须补丁
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/fix_sysvipc_kabi_a16-6.12.patch
  patch -p1 -F 3 < fix_sysvipc_kabi_a16-6.12.patch || true
  # 修补 oplus_bsp_midas 行为，避免开机崩溃
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/fix_oplus_bsp_midas.patch
  patch -p1 -F 3 < fix_oplus_bsp_midas.patch || true
  # 应用 NTSync 补丁
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/ntsync_compat_android16-6.12.patch
  patch -p1 -F 3 < ntsync_compat_android16-6.12.patch || true
  cd ..
  if [[ "$APPLY_DROIDSPACES" == [eE] ]]; then
    echo "正在启用容器环境扩展支持..."
    # 开启虚拟 HCI 设备支持
    echo "CONFIG_BT_HCIVHCI=y" >> "$DEFCONFIG_FILE"
    # 开启 systemd-coredump 支持
    echo "CONFIG_STATIC_USERMODEHELPER=n" >> "$DEFCONFIG_FILE"
    # 添加 Lindroid EVDI DRM 驱动
    # echo "CONFIG_DRM_LINDROID_EVDI=y" >> "$DEFCONFIG_FILE"
    # cd common
    # wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/evdi_drm.patch
    # patch -p1 -F 3 < evdi_drm.patch || true
    # cd ..
  fi
fi

# ===== 启用ADIOS调度器 =====
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  echo ">>> 正在启用ADIOS调度器..."
  echo "CONFIG_MQ_IOSCHED_ADIOS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用Re-Kernel =====
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  echo ">>> 正在启用Re-Kernel..."
  echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_REKERNEL_NETWORK=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用内核级基带保护 =====
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  echo ">>> 正在启用内核级基带保护..."
  echo "CONFIG_BBG=y" >> "$DEFCONFIG_FILE"
  cd ./common
  curl -sSL https://github.com/cctv18/Baseband-guard/raw/master/setup.sh | bash
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
  cd ..
fi

# ===== 降低调试开销配置 =====
echo ">>> 正在关闭 UBSAN 与 init_on_alloc(两者均无运行期开关, 只能编译期处理)..."
cat >> "$DEFCONFIG_FILE" <<'EOF'
# CONFIG_UBSAN is not set
# CONFIG_UBSAN_TRAP is not set
# CONFIG_INIT_ON_ALLOC_DEFAULT_ON is not set
CONFIG_PANIC_TIMEOUT=5
EOF

# ===== 禁用 defconfig 检查 =====
echo ">>> 禁用 defconfig 检查..."
sed -i 's/check_defconfig//' ./common/build.config.gki

# ===== 编译内核 =====
echo ">>> 开始编译内核..."
WORKDIR="$(pwd)"
export PATH="$WORKDIR/clang19/bin:$PATH"
export PATH="$WORKDIR/build-tools/bin:$PATH"
export PATH="$WORKDIR/rust/bin:$PATH"
CLANG_DIR="$WORKDIR/clang19/bin"
CLANG_VERSION="$($CLANG_DIR/clang --version | head -n 1)"
LLD_VERSION="$($CLANG_DIR/ld.lld --version | head -n 1)"
RUSTC_VERSION="$(rustc -V 2>/dev/null | head -n1)"
BINDGEN_VERSION="$(bindgen --version 2>/dev/null | head -n1)"
export CC="$CLANG_DIR/clang"
export HOSTCC="$CLANG_DIR/clang"
export RUSTC="rustc"
export BINDGEN="bindgen"
export LIBCLANG_PATH="$WORKDIR/clang19/lib"
export LLVM=1 LLVM_IAS=1
export ARCH=arm64 SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export LD=ld.lld HOSTLD=ld.lld AR=llvm-ar NM=llvm-nm AS=clang READELF=llvm-readelf
export OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump OBJSIZE=llvm-size STRIP=llvm-strip
KCFLAGS+=" -no-canonical-prefixes"
KCFLAGS+=" -O2"
KCFLAGS+=" -pipe"
KCFLAGS+=" -Wno-error"
KCFLAGS+=" -fno-stack-protector"
KCFLAGS+=" -D__ANDROID_COMMON_KERNEL__"
export KCFLAGS
echo "编译器信息:"
echo "Clang版本: $CLANG_VERSION"
echo "LLD版本: $LLD_VERSION"
echo "Rustc版本: $RUSTC_VERSION"
echo "Bindgen版本: $BINDGEN_VERSION"
pahole_version=$(pahole --version 2>/dev/null | head -n1); [ -z "$pahole_version" ] && echo "pahole版本：未安装" || echo "pahole版本：$pahole_version"

cd common

COMMON_REAL_PATH=$(pwd -P)
ROOT_REAL_PATH=$(dirname "$COMMON_REAL_PATH")
KCFLAGS+=" -fdebug-prefix-map=$ROOT_REAL_PATH=."
KCFLAGS+=" -fmacro-prefix-map=$ROOT_REAL_PATH=."
KCFLAGS+=" -ffile-prefix-map=$ROOT_REAL_PATH=."
export KCFLAGS
source "./_setup_env.sh" 2>/dev/null || true
echo "KCFLAGS=$KCFLAGS"

make -j$(nproc --all) \
    LLVM=1 \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CC="$CLANG_DIR/clang" \
    HOSTCC="$CLANG_DIR/clang" \
    LD=ld.lld \
    HOSTLD=ld.lld \
    RUSTC="rustc" \
    OBJCOPY="llvm-objcopy" \
    O=out \
    gki_defconfig Image 2>&1 | tee $WORKDIR/build.log
echo ">>> 内核编译成功！"

# ===== 选择使用 patch_linux (KPM补丁)=====
WORKDIR="$SCRIPT_DIR"
OUT_DIR="$WORKDIR/kernel_workspace/common/out/arch/arm64/boot"
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  echo ">>> 使用 kptools-linux 工具处理输出..."
  cd "$OUT_DIR"
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kptools-linux
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kpimg-linux
  chmod +x ./kptools-linux
  ./kptools-linux -p -i ./Image -k ./kpimg-linux -o ./oImage
  rm -f Image
  mv oImage Image
  echo ">>> 已成功打上KP-N补丁!"
fi

# ===== 克隆并打包 AnyKernel3 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 克隆 AnyKernel3 项目..."
git clone https://github.com/cctv18/AnyKernel3 --depth=1

echo ">>> 清理 AnyKernel3 Git 信息..."
rm -rf ./AnyKernel3/.git

echo ">>> 拷贝内核镜像到 AnyKernel3 目录..."
cp "$OUT_DIR/Image" ./AnyKernel3/

echo ">>> 进入 AnyKernel3 目录并打包 zip..."
cd "$WORKDIR/kernel_workspace/AnyKernel3"

# ===== 如果启用 lz4kd，则下载 zram.zip 并放入当前目录 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  wget https://raw.githubusercontent.com/cctv18/oppo_oplus_realme_sm8850/refs/heads/main/zram.zip
fi

if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  wget https://github.com/cctv18/KPatch-Next/releases/latest/download/kpn.zip
fi

# ===== 生成 ZIP 文件名 =====
ZIP_NAME="Anykernel3-${KERNEL_VER}-${MANIFEST}"

if [[ "$APPLY_SUSFS" == "y" || "$APPLY_SUSFS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-susfs"
fi
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4kd"
fi
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4-zstd"
fi
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  ZIP_NAME="${ZIP_NAME}-kpm"
fi
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbr"
fi
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  ZIP_NAME="${ZIP_NAME}-dss"
fi
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-adios"
fi
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-rek"
fi
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbg"
fi

if [[ "$APPLY_NOMOUNT" == [yY] ]]; then
  ZIP_NAME="${ZIP_NAME}-nomount"
fi

ZIP_NAME="${ZIP_NAME}-v$(date +%Y%m%d).zip"

# ===== 打包 ZIP 文件，包括 zram.zip（如果存在） =====
echo ">>> 打包文件: $ZIP_NAME"
zip -r "../$ZIP_NAME" ./*

ZIP_PATH="$(realpath "../$ZIP_NAME")"
echo ">>> 打包完成 文件所在目录: $ZIP_PATH"
