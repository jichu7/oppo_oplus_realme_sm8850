# NoMount 内核补丁（内核侧）

本目录是 [maxsteeel/nomount](https://github.com/maxsteeel/nomount) 内核部分的移植版本，用于在编译本项目内核时把 **NoMount 路径重定向子系统** 直接编进内核（`Image` / `vmlinux`），从而在设备安装 NoMount 用户态模块（metamodule）后获得无挂载的模块路径重定向能力。

| 项目 | 说明 |
| --- | --- |
| 上游版本 | v2.3.1（`NOMOUNT_BASE_VERSION = "23"`） |
| 上游仓库 | https://github.com/maxsteeel/nomount |
| 兼容内核 | 5.2 ~ 6.19（本仓库涉及 6.1.x / 6.12.x） |
| 许可 | GPL-2.0（见 `LICENSE`，拷贝自上游 `kernel/LICENSE`） |

## v2.3.1 更新要点

- 规则路径哈希只计算一次并复用；合成 virtual-parent 规则改为共享，减少启动时大量规则分配的拷贝开销。
- 重新校验时复用已绑定到 inode 的目录 leaf，`nm_child_matches` 对空名称短路。
- 添加规则时校验空名称、`NAME_MAX` 溢出、未知标志、whiteout/opaque/virtual-dir 冲突和畸形 UID 范围，并规范化尾部斜杠。
- 拒绝 `.`/`..` 路径分量，readdir 跳过 dot entry，避免创建永远无法匹配的规则。
- 拒绝 backing path 指向 virtual inode 的规则（#120），防止循环；virtual inode 的 rename 目标与硬链接返回 `-EPERM`。
- 重新校验时丢弃失效的 backing child dentry，避免 replaced/removed 文件继续使用 stale dentry。
- virtual inode 在 open/write 时同步 backing inode 大小，`stat`/`fstat` 能报告写入后的真实大小。
- virtual 文件异步 direct I/O 返回 `-EOPNOTSUPP`；重复 mmap 不再弄脏 `S_PRIVATE` 标志。
- virtual 目录项返回真实 `d_type`（char/block/fifo/socket/symlink/...），readdir 消费者能看到正确类型。
- 文件句柄保留真实 inode 的 native `encode_fh`，virtual inode 返回 `-ESTALE`，避免交给 NFS/FUSE/overlay export 路径。
- `put_super` 在 superblock 释放前移除 hooks；hook/unhook 统一；fake xattr 表在 RCU grace period 后释放，修复一类 unmount UAF。
- hijacked callbacks 在原始指针恢复期间回退到 live `i_op`/`f_op`，关闭规则拆除时的竞争。
- leaf hash 表从 64 扩到 1024 桶，UID exclusion bloom filter 从 256 扩到 1024 bit，规则多时冲突显著减少。
- `setup.sh` 无参数时先 fetch tags，再跟随最新 `v*` tag（不再盲目拉 `dev`）。
- `Kconfig` 现在 `select KEYS`；`CONFIG_KEYS=n` 的内核不再编译失败。
- wire protocol 仍为 v23，2.3.1 用户态与 2.3.0 驱动可互操作，但建议内核与用户态一起更新。

## v2.3.0 更新要点

- 修复单元素规则数组 OOB 读取、跨 superblock backing child 的空 dentry 解引用、positive whiteout/OOB readdir、rebind 类型不匹配。
- blocked UID 在 opaque directory 下保留 native view；完善 kernfs superblock 的 xattr proxy。
- xattr 权限/LSM 检查改到 backing inode；优化 leaf 复用、bucket 索引、RCU 与规则锁路径。

## 目录结构

```
nomount_patch/
├── apply_nomount.sh      # 一键挂进内核源码树（幂等）
├── LICENSE               # GPL-2.0
├── README.md
└── src/                  # 上游 kernel/src 原样拷贝
    ├── Kconfig           # config NOMOUNT (tristate, default y)
    ├── Makefile          # obj-$(CONFIG_NOMOUNT) += nomount.o
    ├── nomount.c
    └── nomount.h
```

## 集成原理（与上游 setup.sh 等价）

`apply_nomount.sh` 对目标内核源码树做三步操作，全部幂等：

1. 把 `src/` 下的 4 个文件拷贝到 `<内核树>/fs/nomount/`；
2. 若 `fs/Makefile` 没有 `CONFIG_NOMOUNT`，追加 `obj-$(CONFIG_NOMOUNT) += nomount/`；
3. 若 `fs/Kconfig` 没有 `fs/nomount/Kconfig`，在最后一个 `endmenu` 之前插入 `source "fs/nomount/Kconfig"`（文件没有 `endmenu` 时退化为追加到末尾）。

脚本自动识别两种源码树布局：`<树>/fs`（AOSP common 内核）与 `<树>/common/fs`（GKI 源码包）。与上游不同，这里用**拷贝**而非符号链接，避免在 Windows 工作副本或 CI 缓存中丢失链接。

## 用法

### 1) GitHub Actions（本仓库工作流）

所有 `fastbuild_*.yml` 都新增了布尔输入 `nomount_enable`（默认 `true`）。开启后构建流程会：

- 从本仓库拉取 `nomount_patch/` 并执行 `apply_nomount.sh`；
- 向 `arch/arm64/configs/gki_defconfig` 追加 `CONFIG_NOMOUNT=y`；
- 在 `ak3.log`、Release 说明中标注 NoMount 是否启用。

### 2) 本地脚本

`local/builder_*.sh` 增加了 `NoMount 内核支持` 交互项（默认 `y`），开启后会调用本目录的 `apply_nomount.sh` 写入配置，产物文件名带 `-nomount` 后缀。

### 3) 手动（任意内核树）

```bash
cd /path/to/kernel-tree          # 含 fs/ 或 common/fs/ 的目录
sh /path/to/nomount_patch/apply_nomount.sh .
echo "CONFIG_NOMOUNT=y" >> arch/arm64/configs/gki_defconfig
```

## 注意事项

- 本补丁只提供**内核侧**能力；设备上还需要安装 NoMount 的用户态模块（metamodule）才能真正使用。
- 与 KernelSU / SukiSU / KernelSU Next / SUSFS 等共存；NoMount 不使用 mount，因此可与 `CONFIG_KSU_SUSFS_SUS_MOUNT` 同时开启。
- `nomount.c` 在 6.13+ 使用字符串形式的 `MODULE_IMPORT_NS("...")`，6.12 及更早使用内核原生形式，6.1/6.12 均已覆盖。
- 本仓库编译参数已带 `-Wno-error`；若你自行编译且内核启用了 `CONFIG_WERROR`，建议补上 `KCFLAGS=-Wno-error`，避免上游代码告警中断编译。

## 更新上游版本

```bash
git clone --depth=1 https://github.com/maxsteeel/nomount
cp -f nomount/kernel/src/Kconfig nomount/kernel/src/Makefile \
      nomount/kernel/src/nomount.c nomount/kernel/src/nomount.h nomount_patch/src/
cp -f nomount/kernel/LICENSE nomount_patch/LICENSE
```

然后更新本文件顶部的版本号。
