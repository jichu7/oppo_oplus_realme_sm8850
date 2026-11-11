# NTSync vendor 策略：/dev/ntsync 全局可读写

目标：让 NTSync 节点在 Android 上最终呈现为：

```text
crw-rw-rw- 1 root root u:object_r:ntsync_device:s0 /dev/ntsync
```

并允许 `untrusted_app`（proot/chroot 里的 Wine）和 `su` 访问。

> 内核里的 `miscdevice.mode = 0666` 只是 devtmpfs 的初始 mode；Android 的 ueventd 仍会按规则改写。  
> 所以只有 vendor 侧同时补 `ueventd.rc` 和 SELinux 策略，才能稳定得到 0666。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `ueventd.rc` | `/dev/ntsync 0666 root root` |
| `ntsync_device.te` | 定义 `ntsync_device`，放行 `untrusted_app_all` / `su` |
| `file_contexts` | 给节点打 `u:object_r:ntsync_device:s0` 标签 |
| `apply_to_vendor.sh` | 把以上内容合并进 vendor 源码（幂等） |

## 合并到 vendor

假设：

- vendor 根目录：`vendor/oplus/sm8850`
- 已加入 `BOARD_VENDOR_SEPOLICY_DIRS` 的策略目录：`device/oplus/sepolicy/vendor`

在仓库根目录执行：

```bash
bash other_patch/ntsync-android/vendor_policy/apply_to_vendor.sh \
  vendor/oplus/sm8850 \
  device/oplus/sepolicy/vendor
```

脚本会：

1. 在 `vendor/oplus/sm8850/etc/ueventd.rc` 中写入或替换 `/dev/ntsync 0666 root root`；
2. 复制 `ntsync_device.te` 到策略目录；
3. 在策略目录的 `file_contexts` 中写入或替换 `/dev/ntsync` 标签。

如果不想用脚本，手动做同样三件事即可。

## 必须确认的构建配置

1. 该策略目录确实在 `BOARD_VENDOR_SEPOLICY_DIRS` 中，例如：

   ```make
   BOARD_VENDOR_SEPOLICY_DIRS += device/oplus/sepolicy/vendor
   ```

2. 内核已启用 NTSync：

   ```text
   CONFIG_NTSYNC=y
   ```

3. 重新编译 vendor / sepolicy，而不是只重编 kernel：

   ```bash
   source build/envsetup.sh
   lunch <你的产品>
   m vendorimage
   # 或至少 m sepolicy
   ```

## 验证

刷入后：

```bash
adb shell ls -lZ /dev/ntsync
adb shell getenforce
adb shell dmesg | grep -i -E 'ntsync|avc'
```

期望：

```text
crw-rw-rw- 1 root root u:object_r:ntsync_device:s0 /dev/ntsync
```

权限不对时按下面排查。

### 仍然是 0600

- 检查规则是否真的进了 vendor 分区：

  ```bash
  adb shell grep ntsync /vendor/etc/ueventd.rc
  ```

- 看 ueventd 是否处理了该设备：

  ```bash
  adb shell dmesg | grep -i ueventd
  ```

- 某些 ROM 的 `ueventd.rc` 在 `system/etc` 或 `vendor/etc` 都有，确认你改的是实际生效的那份。
- 如果 ROM 在开机后还有 init 脚本改权限，需要把该脚本里的 `chmod 0600` 一并改掉。

### 权限是 0666，但应用仍打不开

看 `avc: denied`：

```bash
adb shell dmesg | grep avc
```

按实际域补 `allow`。本策略默认放行：

```text
allow untrusted_app ntsync_device:chr_file { open read write ioctl map getattr };
allow su ntsync_device:chr_file { open read write ioctl map getattr };
```

如果 ROM 使用版本化的 `untrusted_app_*` 域，并且你要覆盖所有版本，可改成：

```text
allow untrusted_app_all ntsync_device:chr_file { open read write ioctl map getattr };
```

前提是该 ROM 定义了 `untrusted_app_all`；否则按实际域补 `untrusted_app_25`、`untrusted_app_27` 等。不要直接 `setenforce 0`。

## 安全说明

`0666` 意味着本机任何进程都能打开 `/dev/ntsync`。这是你要的“全局可读写”，但会扩大 ioctl 攻击面；如果以后只想给 Wine/proot 用，建议改成 `0660 root system` 并只给 `untrusted_app_all` 放行。
