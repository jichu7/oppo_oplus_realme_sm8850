# NTSync 运行时权限模块（无 vendor 源码方案）

适用于厂商没有提供 6.12.23 vendor 源码、无法重新编译 `vendorimage` 的情况。

模块在开机后做两件事：

1. `chmod 0666 /dev/ntsync`、`chown root:root`；
2. 尝试把节点重新标记为可被应用访问的 SELinux 类型。

## 安装

把本目录打包成 zip（文件必须在 zip 根目录，不要多一层文件夹），在 KernelSU / Magisk 中安装，重启。

```sh
cd other_patch/ntsync-android/runtime_module
zip -r ../ntsync_rw.zip .
```

或者直接使用已经打好的 `../ntsync_rw.zip`。

## 验证

```sh
adb shell ls -lZ /dev/ntsync
adb shell cat /data/local/tmp/ntsync_rw.log
```

期望看到类似：

```text
crw-rw-rw- 1 root root u:object_r:ntsync_device:s0 /dev/ntsync
```

如果日志显示 `label=ashmem_device` 或 `label=gpu_device`，说明策略里没有 `ntsync_device`，脚本用了一个应用本来就能访问的设备类型作为兼容回退。功能可能可用，但类型语义不准确。

## 重要限制

- 这是**运行时修补**，不是 vendor 策略；每次重启由模块重新执行。
- 如果内核根本没有注册 `/dev/ntsync`，先确认 `CONFIG_NTSYNC=y` 且节点存在。
- `0666` 会扩大攻击面；不需要时请卸载模块。
- `sepolicy.rule` 里的 `type` / `typeattribute` 需要 root 管理器支持。Magisk 支持；部分 KernelSU 版本只支持 `allow`，此时会走 `ashmem_device` / `gpu_device` 回退。
- Android 11+ 的应用域带 SDK 后缀，例如 `untrusted_app_27`。如果日志里出现 `scontext=u:r:untrusted_app_27` 被拒绝，需要把该域也加入 `sepolicy.rule`；当前已加入 `untrusted_app_27`。
- 如果回退标签仍被 SELinux 拒绝，最终可靠方案仍是把 `vendor_policy/` 合并进 vendor/sepolicy 并重编 vendor 分区，或给 ROM 打离线策略补丁。

## 与 AnyKernel3 捆绑

当工作流输入 `ntsync_enable=true` 时，打包阶段会把 `ntsync_rw.zip` 放进 AnyKernel3 包，并在 `anykernel.sh` 末尾追加安装逻辑：

- 优先执行 `/data/adb/ksud module install ntsync_rw.zip`（KernelSU/SukiSU）；
- 否则执行 `/data/adb/magisk/magisk --install-module ntsync_rw.zip`（Magisk）；
- 两者都不存在时只打印提示，需要开机后手动安装。

所以 AK3 包本身就能在刷内核时顺带安装模块；如果刷写环境无法访问 `/data`，仍需要开机后手动安装。

## 卸载

在 root 管理器中删除模块并重启，节点会恢复为 vendor/ueventd 的默认权限。
