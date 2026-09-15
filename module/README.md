# module/ — v2.6 模块源码

本目录为 **v2.6 模块的源码镜像**（与 Releases 中 `PICO4_MotionTracker_v2.6_*.zip` 内文件一致；
不含 `system/priv-app/PvrSwift/PvrSwift.apk` 载荷——APK 为 Pico 原版文件，请从 Release ZIP 获取）。

## 结构

```
module.prop            模块元数据（version=v2.6 / versionCode=11）
customize.sh           安装脚本（备份、旧版残留清理、解析缓存清理、状态）
post-fs-data.sh        开机早段：清理 PMS 解析缓存（版本切换自愈的关键）
service.sh             开机后段：兼容层自检
toggle.sh              安装期辅助脚本（消费首次安装的解绑标记）
action.sh              Magisk「执行」按钮文案
uninstall.sh           卸载清理（缓存失效 + 属性还原）
system/lib64/
  libswift205shim.so         native 兼容层（转发库，本仓库源码见 native/）
  libtrackingclient.pxr.so   补丁版系统库（仅 +1 条 DT_NEEDED 依赖）
native/
  libswift205shim.c          转发库源码
```

## 工作原理

见仓库根目录 [FIX_NOTES_v2.6.md](../FIX_NOTES_v2.6.md)：

1. priv-app overlay 原版 2.0.5 APK（原签名、零修改）绕过 `ro.pxr.externalfunc` 门禁；
2. native 兼容层补齐 P4 缺失的 `getSwiftTrackerInfoVector` 符号（转发到旧接口）；
3. PMS 解析缓存双向自动处理，保证升级/卸载闭环（版本号、资源、启动全部正确）。

## 构建

```bash
# 转发库（aarch64）
aarch64-linux-gnu-gcc -shared -nostdlib -fPIC -O2 -ffreestanding -fno-builtin \
    -fno-stack-protector -fno-asynchronous-unwind-tables \
    -Wl,-soname,libswift205shim.so -o system/lib64/libswift205shim.so native/libswift205shim.c

# 系统库补丁
patchelf --add-needed libswift205shim.so libtrackingclient.pxr.so
```

打包：将本目录内容放入 Magisk 模块 zip 根（并把 `PvrSwift.apk` 放入
`system/priv-app/PvrSwift/PvrSwift.apk`），安装脚本会自动处理其余事项。

仅供学习研究，请支持正版。
