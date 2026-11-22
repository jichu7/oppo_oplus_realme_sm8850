# 欧加真 SM8850/MT6993 系列通用6.12内核自动化编译脚本
[![STAR](https://img.shields.io/github/stars/cctv18/oppo_oplus_realme_sm8850?style=flat&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyByb2xlPSJpbWciIHZpZXdCb3g9IjAgMCAyNCAyNCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48dGl0bGU%2BR2l0SHViPC90aXRsZT48cGF0aCBkPSJNMTIgLjI5N2MtNi42MyAwLTEyIDUuMzczLTEyIDEyIDAgNS4zMDMgMy40MzggOS44IDguMjA1IDExLjM4NS42LjExMy44Mi0uMjU4LjgyLS41NzcgMC0uMjg1LS4wMS0xLjA0LS4wMTUtMi4wNC0zLjMzOC43MjQtNC4wNDItMS42MS00LjA0Mi0xLjYxQzQuNDIyIDE4LjA3IDMuNjMzIDE3LjcgMy42MzMgMTcuN2MtMS4wODctLjc0NC4wODQtLjcyOS4wODQtLjcyOSAxLjIwNS4wODQgMS44MzggMS4yMzYgMS44MzggMS4yMzYgMS4wNyAxLjgzNSAyLjgwOSAxLjMwNSAzLjQ5NS45OTguMTA4LS43NzYuNDE3LTEuMzA1Ljc2LTEuNjA1LTIuNjY1LS4zLTUuNDY2LTEuMzMyLTUuNDY2LTUuOTMgMC0xLjMxLjQ2NS0yLjM4IDEuMjM1LTMuMjItLjEzNS0uMzAzLS41NC0xLjUyMy4xMDUtMy4xNzYgMCAwIDEuMDA1LS4zMjIgMy4zIDEuMjMuOTYtLjI2NyAxLjk4LS4zOTkgMy0uNDA1IDEuMDIuMDA2IDIuMDQuMTM4IDMgLjQwNSAyLjI4LTEuNTUyIDMuMjg1LTEuMjMgMy4yODUtMS4yMy42NDUgMS42NTMuMjQgMi44NzMuMTIgMy4xNzYuNzY1Ljg0IDEuMjMgMS45MSAxLjIzIDMuMjIgMCA0LjYxLTIuODA1IDUuNjI1LTUuNDc1IDUuOTIuNDIuMzYuODEgMS4wOTYuODEgMi4yMiAwIDEuNjA2LS4wMTUgMi44OTYtLjAxNSAzLjI4NiAwIC4zMTUuMjEuNjkuODI1LjU3QzIwLjU2NSAyMi4wOTIgMjQgMTcuNTkyIDI0IDEyLjI5N2MwLTYuNjI3LTUuMzczLTEyLTEyLTEyIiBmaWxsPSIjZmZmZmZmIj48L3BhdGg%2BPC9zdmc%2B)](https://github.com/cctv18/oppo_oplus_realme_sm8850/stargazers)
[![FORK](https://img.shields.io/github/forks/cctv18/oppo_oplus_realme_sm8850?style=flat&logo=greasyfork&color=%2394E61A)](https://github.com/cctv18/oppo_oplus_realme_sm8850/forks)
[![COOLAPK](https://img.shields.io/badge/cctv18_2-cctv18_2?style=flat&logo=android&logoColor=FF4500&label=%E9%85%B7%E5%AE%89&color=FF4500)](http://www.coolapk.com/u/22650293)
[![DISCUSSION](https://img.shields.io/badge/%E8%AE%A8%E8%AE%BA%E5%8C%BA-discussions?logo=livechat&logoColor=FFBBFF&color=3399ff)](https://github.com/cctv18/oppo_oplus_realme_sm8850/discussions)

<img alt="Endpoint Badge" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fcctv18%2Fkernel-workshop%2Frefs%2Fheads%2Fhotfix%2Fnotice.json">

##### 
一个更方便、快捷的自动化OPPO/一加/真我系列骁龙8Elite Gen5(SM8850)/天玑9500(MT6993)机型的通用6.12内核编译脚本。
##### 
这个项目的初衷是解决以下问题：
- 绿厂官方摆烂，代码开源开一半，导致部分内核代码无法通过已有的配置xml正常编译，甚至没有编译配置xml；
- 由于6.12内核引入了包括rust代码在内的大量新机制，导致市面上已有的使用make指令编译内核的方法无法正常完成编译，只能使用低效的bazel进行编译，而官方使用的 Bazel 编译器过于不稳定且臃肿不堪，容易出现各种各样莫名其妙的错误，且全网几乎找不到任何有效解决方法，对于新手极不友好；
- 现有的6.12内核常用编译流程（使用bazel编译/拉取第三方工具链编译等）编译速度极慢，即使在有缓存的情况下二次编译时间也动辄需要20-30分钟，且bazel与ccache缓存不兼容，无法正常保存编译缓存。
## 本项目的主要内容(及计划)
- 使用 AOSP 官方 LLVM/Clang 19 + Rust v1.82.0 进行编译，并排除了官方源码中不必要的 vendor 源码参与，大幅优化编译流程并引入ccache缓存机制，对比原 bazel 编译器缩短了近2/3的编译时间（原版官方编译器每次约需要超过1h才能完成编译），提高了编译过程的稳定性，输出日志更便于维护调试；
- 修复官方代码部分bug/未及时更新的补丁，并引入诸多第三方更新/功能支持；
- 提供 Github Action 在线编译/shell本地编译双版本脚本。
## 已实现：
- [x] 欧加真骁龙 SM8850 通用OKI内核（基于一加15源码的 6.12.23 / 一加Ace 6T源码的 6.12.38 ，其他同内核版本非SM8850机型可自行测试，部分机型可完全兼容）
- [x] 欧加真天玑 MT6993 通用OKI内核（基于OPPO Find X9 源码的 6.12.23 ，其他同内核版本非MT6993机型可自行测试，部分机型可完全兼容）
- [x] ReSukiSU/SukiSU Ultra/KernelSU Next/原版KernelSU多版本KSU可选（SukiSU Ultra 直接取用官方源码仓库 [SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)，不复用 BakaSU 的代码）
- [x] 引入独家设计的 [ccache-ECS](https://github.com/cctv18/ccache-ECS) 缓存及大量编译流程优化，编译时间可稳定在约6min *(首次编译时会拉取公共预置ccache，从第二次开始没有大量配置改动的情况下，单次编译时间约6min；距离上一次调用两周未调用后缓存会被自动清除，此时编译会自动重建缓存)*
- [x] 引入O2编译优化，改善内核运行性能
- [x] 关闭 UBSAN（含 `UBSAN_TRAP`）与 `init_on_alloc` 的默认清零开销（两者在运行期都没有开关，只能编译期处理），并将 `PANIC_TIMEOUT` 由 `-1` 改为 `5`，避免崩溃后卡死等看门狗复位
- [x] lz4 1.10.0 & zstd 1.5.7 算法更新&优化补丁(来自[@ferstar](https://github.com/ferstar), 移植by [@Xiaomichael](https://github.com/Xiaomichael), 6.12版本补丁重制by [@cctv18](https://github.com/cctv18))
- [x] 移植lz4kd支持到6.12内核(可选补丁)
- [x] 可选加入 BBR/Brutal 及一系列 tcp 拥塞控制算法
- [x] [ADIOS IO调度器](https://github.com/firelzrd/adios)移植
- [x] 加入一些网络连接性能优化配置选项（用于为ipset及需要iptables等高级网络功能内核支持的程序提供支持）
- [x] Droidspaces 容器化支持（比传统 Docker/LXC 更轻量化，便于移植的完整 Linux 环境容器实现）
- [x] 添加了对[Mountify](https://github.com/backslashxx/mountify)模块的支持
- [x] 默认集成 [NoMount](https://github.com/maxsteeel/nomount) 内核支持（无挂载路径重定向，可隐藏模块挂载痕迹；需配合 NoMount 用户态模块使用，本地构建时可通过 `APPLY_NOMOUNT=n`、CI 构建时可通过输入 `nomount_enable=false` 关闭）
- [x] 内置 [SUSFS](https://github.com/cctv18/susfs4oki) 支持，并可选择 SUSFS 版本（本地构建时输入 `latest`/`2.4.0`/`2.3.0`，CI 构建时选择 `susfs_version`；版本号按上游 `SUSFS_VERSION` 映射到固定提交，`latest` 跟随上游最新）。老版本补丁里只做 include 插入的 hunk 在新内核基线上会失配，构建时由 `other_patch/susfs_rej_repair.py` 按源码实际位置补插，其它类型的补丁失配仍然直接报错
- [x] 可选自定义 KSU 管理器的提交版本并自动识别管理器（本地构建时输入 `KSU_REF_CUSTOM`，CI 构建时填写 `ksu_ref`；留空跟随所选分支最新，可填 `分支`/`标签`/`commit SHA`，也可填 `仓库@版本` 如 `Baka-SU/BakaSU@main` 直接切换仓库；构建时会按源码实际内容识别管理器类型——`REPO_NAME := BakaSU`/`KSU_VERSION_FALLBACK`/`DKSU_VERSION`/`kernel/supercall/dispatch.c`——并按识别结果注入版本号、命名产物与生成发布说明，识别失败才回退到 `ksu_type` 选择框）
- [x] 加入Re:Kernel支持，与Freezer，NoActive等软件配合降低功耗
- [x] 加入[内核防格基带保护(By @showdo)](https://github.com/vc-teahouse/Baseband-guard)，有效防止恶意格机脚本/程序对系统分区数据的破坏
- [x] 支持运行期 mTHP 多尺寸大页调优（内核已编入 8K~2048K 全部尺寸，实测 64K+128K 最优、256K 应关闭；零补丁、纯运行期配置，详细数据见下文「运行期调优」）
## 待实现：
- [ ] zram内置化，无需外置zram.ko挂载 ~~（有了新版 lz4&zstd 补丁真的还有必要吗）~~
- [ ] Nethunter 网卡监听模式支持
- [ ] kexec 内核热切换支持
- 更多优化与特性移植……
- 更多优化与特性移植……
##### 
##### 
##### 
## 运行期调优（非内核改动，设备侧生效）
以下都是**不需要重新编译**的调优，改完立即生效，重启后需由模块/开机脚本重新写入。

### mTHP 多尺寸透明大页
本内核已编入 mTHP 的全部尺寸（`/sys/kernel/mm/transparent_hugepage/hugepages-{8,16,32,64,128,256,512,1024,2048}kB` 均存在），但启动参数 `transparent_hugepage=never` 会在开机时把**每个尺寸**都置为 `never`，并且修改全局 `enabled` **不会**回填 per-size 设置，必须显式逐尺寸打开。

实测数据（一加15 / 6.12.69_gki；负载 = 5 次冷启设置 + 3 次 monkey + 60s 静置；同负载 61~62s 窗口；成功率 = `anon_fault_alloc / (anon_fault_alloc + anon_fault_fallback)`）：

| 配置 | 64K | 128K | 256K | 合计成功率 | 每分钟成功次数 |
|---|---|---|---|---|---|
| **64K + 128K** | 20.9% | **32.3%** | — | **25.6%** | **7945** |
| 128K + 256K | — | 22.7% | 11.0% | 18.5% | 2909 |
| 三层全开 | 22.0% | 23.8% | 6.9% | 19.8% | 3894 |
| 仅 128K | — | 12.5% | — | 12.5% | 3402 |
| 仅 256K | — | — | 10.4% | 10.4% | 594 |

结论：
- **64K + 128K 为最优组合**，折算覆盖字节数约为次优组合的 2 倍。
- **64K 不可省**：只开 128K 时，128K 成功率从 32.3% 掉到 12.5%，`split_failed` 从 116/min 涨到 3651/min（31 倍）。64K 是抢不到 128K 时的第二道缓冲，去掉它内存碎片会更碎。
- **256K 应永久关闭**：order-6 需要 64 个连续页，实际碎片下命中率只有 6.9%~11.0%，且每次缺页都要先多付一次必然失败的 order-6 查找；三层全开时还会把 128K 的成功率从 32.3% 压到 23.8%。
- **不会引发压缩卡顿**：三轮实测 `compact_stall` 全程为 0，与全关基线（0.1 次/分钟）无差异——`__GFP_NORETRY` 对 order > 3 直接失败，不进入内存压缩。

固化脚本（模块 `post-fs-data.sh` 或开机脚本）：

```sh
T=/sys/kernel/mm/transparent_hugepage
echo madvise > "$T/enabled"
echo always  > "$T/hugepages-64kB/enabled"
echo always  > "$T/hugepages-128kB/enabled"
echo never   > "$T/hugepages-256kB/enabled"
```

其中 `256K` 那行必须显式写 `never`：启动参数只保证开机初值，一旦被其它模块打开就不会自动关回去。

判读方法：`/proc/vmstat` 的 `thp_*` 与 `/proc/meminfo` 的 `AnonHugePages` **只统计 2MB（PMD）大页**，对 mTHP 完全不可见，必须读 per-size 的 `stats`：

```sh
for s in 64 128 256; do
  d=/sys/kernel/mm/transparent_hugepage/hugepages-${s}kB/stats
  echo "== ${s}K  alloc=$(cat $d/anon_fault_alloc) fallback=$(cat $d/anon_fault_fallback)"
done
```

> 6.10 之前的内核（如一加12 的 6.1）没有 per-size 入口，只能调传统 2MB THP，其表现不能用来推断本节的 mTHP 行为。

## 鸣谢
- WildKernel的一加系列内核构建脚本：[WildKernels/OnePlus_KernelSU_SUSFS](https://github.com/WildKernels/OnePlus_KernelSU_SUSFS)
- ReSukiSU：[ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)
- SukiSU Ultra：[SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- susfs4ksu：[ShirkNeko/susfs4ksu](https://github.com/ShirkNeko/susfs4ksu)
- ReSukiSU：[ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)
- pershoot维护的KernelSU Next仓库：[pershoot/KernelSU-Next](https://github.com/pershoot/KernelSU-Next)
- 原版KernelSU: [tiann/KernelSU](https://github.com/tiann/KernelSU)
- 内核防格基带保护模块：[vc-teahouse/Baseband-guard](https://github.com/vc-teahouse/Baseband-guard)
- KSUN的多管理器补丁：[WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches)
- ~~本地化内核构建脚本（已失效）：[Suxiaoqinx/kernel_manifest_OnePlus_Sukisu_Ultra](https://github.com/Suxiaoqinx/kernel_manifest_OnePlus_Sukisu_Ultra)~~

<!-- 这是一个访客统计，用来看看我的项目主页有多少人访问过 -->
<div align="center">
  <img width="0" height="0" src="https://count.getloli.com/get/@:cctv18" />
</div>

