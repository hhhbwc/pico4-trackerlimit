# PICO 4 体感追踪器 — v2.4–v2.6 技术记录（兼容修复与生命周期）

> 本文档对应 v2.6（Release）。v2.0–v2.3 的历史逆向记录见 [FIX_NOTES.md](FIX_NOTES.md)。

## 背景

- **v2.0–v2.3**：修改版 APK 路线（测试签名 + smali/二进制补丁），存在签名提示、升级链路与回滚问题。
- **v2.4**：改为**原版 APK** 路线（原签名、零修改 v` system/priv-app` overlay），但遗留两个核心问题：
  1. 追踪器检测为空（应用内永远没有设备）；
  2. 版本切换/卸载的"解析缓存"闭环问题（版本号回不去、切换后打不开应用）。

v2.6 解决以上两项，并加固升级/卸载全链路。

---

## 一、追踪器检测为空 — 根因与修复

### 根因（二进制层）

- 2.0.5 的 `libswift.so` 通过 `dlsym` 从系统库 `libtrackingclient.pxr.so` 解析新接口
  `getSwiftTrackerInfoVector` 来枚举追踪器；
- P4 标准版固件（PUI 5.13.x）**不含该符号**（PICO 4 Ultra 固件含）→ 枚举失败，`devices: null`，
  应用界面永远没有设备。

### 修复：native 兼容层（两件套）

| 文件 | 处理 | 说明 |
|---|---|---|
| `libtrackingclient.pxr.so` | 补丁版 | **仅新增一条 `DT_NEEDED` 依赖**（指向下面的转发库），其余逐字节与原厂相同 |
| `libswift205shim.so` | 转发库（新增） | 导出缺失符号：内部 `dlsym` 旧接口 `getSwiftTrackerInfo` 取数（3×0x48 结构体），自实现 `std::vector` 构造并按新接口格式返回 |

- 应用与 APK 零修改、保持原签名；仅通过 Magisk 覆盖这两条库路径。
- 构建方式：
  ```bash
  # shim（aarch64，nostdlib）
  aarch64-linux-gnu-gcc -shared -nostdlib -fPIC -O2 -ffreestanding -fno-builtin \
      -fno-stack-protector -fno-asynchronous-unwind-tables \
      -Wl,-soname,libswift205shim.so -o libswift205shim.so libswift205shim.c
  # 系统库打补丁
  patchelf --add-needed libswift205shim.so libtrackingclient.pxr.so
  ```
- 运行日志标识：`Swift205Shim: init / legacy call ret=0 / pushed N items`
  → 应用侧 `devices: [N 台]`。

---

## 二、版本切换/卸载闭环 — PMS 解析缓存

### 现象（P4 真机复现）

- 安装模块（overlay 2.0.5）后：**版本号卡在 2.0.4**；
- 卸载模块 + 重启后：**版本号卡在 2.0.5**（回不去）；
- 更严重时：**应用启动崩溃**（`InflateException: Failed to resolve attribute`，
  TypedValue 资源错配 —— 解析缓存与真实 APK 不一致所致）。

### 根因

PUI 5.13.x 的 PackageManager 解析缓存（`/data/system/package_cache/*/PvrSwift-*`）
**不会随 overlay 切换自动失效**：向上/向下切换版本时，系统仍使用旧解析结果。

### 修复（双向自动）

| 脚本 | 动作 |
|---|---|
| `post-fs-data.sh` | 每次开机（早于 PMS 启动）清理 `PvrSwift-*` / `com.pvr.swift-*` 解析缓存 → 开机自愈 |
| `uninstall.sh` | 卸载模块时同样清理 → 保证回落 2.0.4 生效 |
| `customize.sh` | 安装时清理一次 |

> 急救命令（手动）：`rm -rf /data/system/package_cache/*/PvrSwift-*` 后重启。

---

## 三、其他修复与开发向踩坑

- **dm-4 单文件挂载坑**：本 ROM 对若干算法库存在 `/dev/block/dm-4` 的文件级挂载；
  检测"模块覆盖是否已挂载"时必须 `grep -v dm-4` 过滤，否则会误判导致切换失效。
- **属性卫生**：性能档属性改用 `resetprop -n`（不落盘）；卸载时通过一次性脚本还原旧版
  可能写入的值（仅在值确实被改过时写回，避免新增存储条目）。
- **升级残留清理**：覆盖安装时清理旧模块目录中的挂载文件与遗留标记；不触碰 `modules_update`
  （避免 Magisk 覆盖升级静默失败）。
- **跨档位互刷**：从性能档刷回标准档时，旧 `system.prop` 会被自动移除、属性回默认
  （已验证双向）。
- **全新安装的解绑逻辑**：首次安装（从未装过本模块）重启后会自动解绑一次已配对的旧设备
  （2.0.4 时代绑定），之后重新配对即可；升级安装保留绑定。

---

## 四、真机验证（摘要）

| 场景 | 结果 |
|---|---|
| v2.4 → v2.6 覆盖升级 | ✅ 版本号自动刷新、应用正常、3 台追踪器全部检测到 |
| v2.6 卸载 | ✅ 版本回落 2.0.4、原版应用正常、零残留 |
| 三档互刷（std⇄perf⇄extreme） | ✅ 双向通过、属性正确切换 |
| 原厂 → v2.6 全新安装 | ✅ 通过 |

设备环境：PICO 4 A8110 / PUI 5.13.7 / Magisk；追踪器 3 台（固件 sv1.89 / sv1.91 均验证）。

---

## 五、文件哈希

| 文件 | SHA-256 |
|---|---|
| `libswift205shim.so` | `8511ae8b3da304f9c08fffcbfc2ac210d9087c28f446f5a818601e2b55a3fadc` |
| `libtrackingclient.pxr.so`（补丁版） | `dc03b45f1f1bcb12441e01c340f37832334fbd6a979f2a94a07e929f5c9aeee4` |
| `libtrackingclient.pxr.so`（原厂） | `4cb4b368242d540888e314076ff17cc1e9145c436777b9d92a9301ef8bcbf429` |

模块 ZIP 校验见 [RELEASE_NOTES_v2.6.md](RELEASE_NOTES_v2.6.md)。

---

仅供学习研究，请支持正版。
