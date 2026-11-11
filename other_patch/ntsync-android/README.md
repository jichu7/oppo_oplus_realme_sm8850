# NTSync Android 权限示例

内核补丁 `other_patch/ntsync-6.14.patch` 只负责把 6.12.23 里的旧版 NTSync 半成品升级为 Linux 6.14 的完整驱动。设备节点 `/dev/ntsync` 是否能被使用，还取决于 ueventd 和 SELinux。

本目录是**示例**，不是可直接覆盖所有机型的成品策略。不同 ROM 的 `device/`、`vendor/` sepolicy 布局不同，请按自己的机型合并。

## 1. 设备节点

`ueventd.rc` 示例：

```text
/dev/ntsync 0666 root root
```

驱动本身使用 `miscdevice.mode = 0666`，但 Android 通常由 ueventd 创建 `/dev` 节点，所以仍建议显式写规则。

如果只打算给特定域使用，可改成更严格的权限，例如：

```text
/dev/ntsync 0660 root system
```

然后只给需要它的域放行。0666 的优点是 proot/chroot 里的 Wine 不需要额外改 uid；缺点是所有本机进程都能打开。

## 2. SELinux 标签

`file_contexts` 示例：

```text
/dev/ntsync u:object_r:ntsync_device:s0
```

`ntsync.te` 示例：

```text
type ntsync_device, dev_type;

# proot/chroot 里的 Wine 仍以普通应用 uid 运行，因此需要 appdomain 权限。
allow appdomain ntsync_device:chr_file { open read write ioctl map };

# KernelSU / root 场景。
allow su ntsync_device:chr_file { open read write ioctl map };
```

如果不想放开整个 `appdomain`，可以把 `appdomain` 换成具体的 `untrusted_app`、`priv_app` 等域。

## 3. 合并到机型策略

常见做法：

1. 把 `type ntsync_device, dev_type;` 放到机型的 `file.te` 或 `device.te`。
2. 把 `file_contexts` 的一行合并到机型的 `file_contexts`。
3. 把 `ntsync.te` 放到 `vendor/` 或 `system/` 的 policy 目录，按 ROM 的 `BOARD_SEPOLICY_DIRS` 引入。
4. 把 `ueventd.rc` 的一行合并到机型的 `ueventd.rc`。
5. 重新编译 `sepolicy` / `vendor_sepolicy`，刷入后检查：

```sh
adb shell ls -lZ /dev/ntsync
adb shell dmesg | grep -i ntsync
```

期望看到 `/dev/ntsync` 的标签是 `u:object_r:ntsync_device:s0`，权限符合预期。

## 4. 验证

```sh
adb shell ls -l /dev/ntsync
adb shell cat /proc/misc | grep ntsync
```

Wine/Proton 需要其构建版本启用 ntsync 支持。普通 Android 应用不会因为内核有 NTSync 而变快；它只对使用 NT 同步语义的 Wine/Proton/Box64 负载有意义。

## 5. 注意

- `CONFIG_NTSYNC=y` 只是提供内核接口，不会自动给任何应用授权。
- 如果 SELinux 报 `avc: denied { ioctl } for ... ntsync_device`，按 `audit2allow` 补齐对应域，不要直接 `setenforce 0`。
- 如果只用 proot 且不想改 sepolicy，可把 `/dev/ntsync` 的权限放宽到 0666，但这会扩大攻击面；更推荐按域授权。

## 6. 直接可合并的 vendor 策略

`vendor_policy/` 下是已经整理好的 vendor 侧文件：

- `ueventd.rc`
- `file_contexts`
- `ntsync_device.te`
- `apply_to_vendor.sh`

按 `vendor_policy/README.md` 合并到 `vendor/etc/ueventd.rc` 和 `BOARD_VENDOR_SEPOLICY_DIRS` 中的策略目录，重新编译 vendor/sepolicy 后即可让 `/dev/ntsync` 稳定为 `0666`。
