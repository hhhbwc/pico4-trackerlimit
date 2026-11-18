> ⚠️ **维护状态**：本项目已无法继续测试与维护 —— 我把自己那套 PICO 腿环卖掉了，换成了 Rebocap。
> 现有版本仍可照文档安装使用，但背后不再有任何真机实测，新出现的兼容问题我无法验证也就无法修。

🌐 [简体中文](README.md) | [English](README_EN.md) | [Русский](README_RU.md)

# PICO 4 Motion Tracker Unlock (2.0.5)

针对 **PICO 4 标准版**（A8110 / Phoenix，ROM 5.13.x）的 PICO 体感追踪器应用完整解锁。
通过 **Magisk 模块** 在标准版上完整启用「体感追踪器 2.0.5」应用：
**追踪器检测正常、版本切换/升级/卸载全链路可靠**。系统分区零修改，卸载即恢复原版。

> 📦 下载：[Releases](../../releases) → **v2.9.1**（与 KarlVis/DirectTouch 全自动兼容 + v2.0–v2.2 残留清理；v2.8 库隔离修复不变）
> 🔧 要求：Magisk 27+，PICO 4 标准版（或受相同门禁限制的 4 系列设备）

---

## ❌ 关于 5 点全身追踪（实测结论，先说清楚）

**实测不支持，让等它的各位失望了，抱歉。**

连接层确实是放开的：5 台追踪器可以配对、应用里也能切到 5 点档位。
但**全身解算不工作**——标准版原厂 BODYPOSE 算法缺少 5 点专属的
forearm / knee 神经网络模型（`e2e_*_8_*`），Ultra 的 1.0.0.54 算法
作为替代未经证实。5 点全身动捕在标准版上目前无解，**请按 2 点 / 3 点使用**。

尽管如此，这个模块仍然有实际价值：

- 标准版完整解锁「体感追踪器 2.0.5」（原版 APK、原签名、门禁绕过）
- 2 / 3 点模式正常切换，追踪器正常配对 / 校准 / 枚举
- 实测解决追踪器在游戏（如 VRChat）中**掉线**、校准/重标定弹窗**中断使用**等问题
- 与 KarlVis/DirectTouch 自动兼容，边界确认按钮不再失灵

---

## 🆕 v2.9.1：修复"边界确认按钮点不了"（与 KarlVis/DirectTouch 的冲突，全自动）

**用户报告**：装 v2.0 后，游戏内弹出的边界确认/重标定窗口无法点击确认——指针
悬停时确认圆圈不出现，手柄与手势均失效；首装首次开机正常，重启后复现。

**真实冲突点（逆向 KarlVis O1.13.7S 确认）**：KarlVis 的 DirectTouch（LSPosed
模块 `com.picodirecttouch.lsposed`）向 `com.picoxr.xrshell` 注入 native 库，
以 proxy/orig 代理接管了引擎的**射线更新（rayProxy）与光标/悬停圆圈更新
（cursorProxy）**——只有它注册表里的面板才有正常指针交互；体感追踪器的边界
面板（PvrSwift VSTPanel 的应用层）不在其中 → 圆圈消失、手柄手势都点不了。
没有追踪器模块时该面板根本不会出现、没有 KarlVis 时引擎原版命中逻辑覆盖所有
层——两者叠加才触发；"首次开机正常、重启后坏"= LSPosed 钩子重启后生效。
完整分析见 [RELEASE_NOTES_v2.9.md](RELEASE_NOTES_v2.9.md)。

| 变化 | 说明 |
|---|---|
| 🤖 **全自动 DirectTouch 兼容监视器（v2.9.1）** | `dt_compat.sh` 开机自启（未装 KarlVis 自动退出、零开销）：边界面板弹出时临时 `persist.dt.enable 0` 让 DirectTouch 让位，面板消失自动还原；面板卡死 120s 且前台是游戏时自动解除（不影响游戏内追踪数据流）。**无需任何手动点击** |
| 🧹 **升级清理** | 覆盖安装自动移除改装 APK 时代写入的 `key_mod_wear_mode` / `key_mod_upper_limit` 偏好键；同时消除 v2.0 补丁 APK 的 discovery 后台强驻留副作用（原版 APK 守卫齐全） |
| 🛟 **救援 + 诊断（备用）** | Magisk"执行"按钮 = 立即救援 + 导出 `/sdcard/pico4_diag_*.log`（含 DirectTouch/lspd 诊断段） |
| 🔒 架构不变 | 原版 PICO 签名 APK + priv-app 私有库目录（v2.8 路线） |

> **v2.0/v2.1/v2.2 用户**：直接覆盖安装 v2.9.1（同模块 id，无需卸载，绑定保留）。
> ✅ watcher 状态机已在作者真机（A8110 / 5.13.7）端到端验证；`persist.dt.enable`
> 的实时语义待 KarlVis 真机确认，若热切换不生效由卡死自动解锁兜底——两条路都
> 无需手动干预。
> "dock 窗口跟随头部旋转" = Pico2Dock（替换系统底座 `com.pvr.shortcut`）×
> KarlVis(DockHook) 的冲突，与本模块无关。

---

## 🛑 v2.7 用户请尽快升级到 v2.8（黑屏风险）

**v2.7 存在一个严重缺陷**：native 兼容库挂载在全局路径 `/system/lib64/`。
系统中**所有**加载 trackingclient 的进程（包括 `com.pico.xr.openxr_runtime`）都会被拉入兼容 shim，
导致 OpenXR 运行时 SIGBUS 崩溃循环 → tombstone 持续累积（实测 **447 个**）→ system_server 连带崩溃 → **黑屏**（只能强制重启）。

**v2.8 修复**：兼容库迁移到 `/system/priv-app/PvrSwift/lib/arm64/`（priv-app 私有 nativeLibraryDir），
只有体感追踪器应用可见，OpenXR 运行时继续使用系统原版库。真机验证：**0 tombstone、3 台追踪器正常枚举、应用正常**。
从 v2.7 覆盖安装 v2.8 即可，无需卸载。

---

## 🆕 v2.8：修复版（库隔离 + 移除自动解绑）

| 变化 | 说明 |
|---|---|
| 🐛 **修复黑屏（关键）** | 兼容库从 `/system/lib64/`（全局）迁到 `priv-app/PvrSwift/lib/arm64/`（私有），`openxr_runtime` 不再被污染；崩溃循环与黑屏根除 |
| 🔏 **APK 换回原版** | v2.7 ZIP 内的 APK 是重签名改装版；v2.8 换回 **PICO 原签名、零修改** 的 2.0.5 原版 APK（门禁靠 priv-app 身份 + 原签名通过，实测有效） |
| 🚫 **移除自动解绑** | 不再在全新安装时自动 unbond（解绑需要 root 且有固件掉电风险）。如卡旧配对界面，见 [RELEASE_NOTES_v2.8.md](RELEASE_NOTES_v2.8.md) 手动命令 |
| 🧹 继承 v2.7 | 单档原厂调度、PMS 缓存双向自愈、升级残留/属性清理全部保留 |

---

## 🆕 v2.7：单档化（原厂调度）+ 性能调优迁移

| 变化 | 说明 |
|---|---|
| 🔀 **三档 → 单档** | 只保留一个构建（原厂调度）。从旧 Performance / EXTREME 档覆盖安装时，**自动还原**被改写过的系统属性，回到原厂调度 |
| 🎛️ **性能调优迁移** | 原性能/极限档的 CPU/GPU 调度调优迁移至 **[pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode)** 项目：由其 Magisk 伴生组件在「性能模式」生效时自动应用（CPU/GPU governor → `performance` 等），其他档位恢复原厂 |
| 🧹 **升级即清理** | 覆盖安装自动清理旧档位残留属性（best-effort 即时 + 下次开机兜底） |

> 为什么单档化？维护三个构建没有意义；解锁本身与调度无关，调优统一收敛到 power-mode 一个入口。

---

## 🆕 v2.6 修复了什么（从"能用"到"可靠"）

| # | 旧版问题 | v2.6 修复 |
|---|---|---|
| 1 | 追踪器检测为空（应用里永远没有设备） | ✅ **native 兼容层**补齐 P4 固件缺失符号，设备列表正常（3 台真机验证） |
| 2 | 升级后版本号不变 / 卸载后回不去 / 切换版本后打不开应用 | ✅ **PMS 解析缓存双向自动处理**（开机自愈，无需手动干预） |
| 3 | 旧版升级链路残留、升级后行为不一致 | ✅ 覆盖安装自动清理 v2.0–v2.4 残留；升级保留追踪器绑定 |
| 4 | 性能档属性持久化残留 | ✅ 非持久写入 + 卸载自动还原 |
| 5 | 切换档位需卸载重装 | 🔁 旧版本三档曾可互刷；**v2.7 起合并为单档** |

> ⚠️ 从 v2.0 / v2.1 / v2.2 / v2.3 / v2.4 / v2.6 **直接覆盖安装 v2.7 即可**，无需先卸载。

---

## 🆕 v2.8.1：可选实验性调参模块 + .cpt 格式规范

| 变化 | 说明 |
|---|---|
| 🎛️ **附加资产 `pico4_algo_tuning_v0.1.1.zip`** | 可选实验模块：把 BODYPOSE/追踪器运行时配置（.cpt）改为激进档——全身解算与追踪预测线程绑大核 cpu4-7、RT 优先级 8/5、200Hz 解算、n_iter 20。**手柄配置不动**。与主模块共存，独立回滚 |
| 📄 **[CPT_FORMAT.md](CPT_FORMAT.md)** | .cpt 二进制格式规范（AES-128-ECB / PKCS7 / LF-only base64 / 尾部 NUL）+ 一次真实崩循环事故的完整记录与自检清单。服务失败模式是**崩循环**而非降级——写 .cpt 工具前必读 |

> ⚠️ 调参模块为 EXPERIMENTAL：崩溃风险已通过安装时格式守卫拦截，但**调参收益未经系统性验证**（仅验证不崩）。回滚：`touch /data/adb/modules/pico4_algo_tuning/disable && reboot`。

## ✨ 解锁内容

| 能力 | 原厂（标准版） | 解锁后 |
|---|---|---|
| 体感追踪器 2.0.5 应用 | 提示"设备不支持，请升级系统" | 完整可用（**原版 APK、原签名、零修改**） |
| 追踪器设备检测 | — | ✅ 正常列出 / 连接 / 校准 |
| 特权权限 | 拿不到（签名不符） | priv-app 身份完整授予 |
| 追踪器数量 | 2 或 3（随穿戴模式固定） | 2 / 3 正常可用；❌ 5 点实测不支持（见上方说明） |
| 5 点（forearm / knee） | Ultra 专属档位 | ❌ **实测不支持**：连接层可配对，全身解算不工作（见上方"关于 5 点"） |

---

## 📥 安装 / 升级 / 卸载

### 安装
1. 确认已 root（Magisk 27+）
2. Magisk → 模块 → 从本地安装 ZIP
3. 重启
4. 打开「体感追踪器」应用，正常配对/校准

> **不能同时装两个 Tracker 模块。** 如果检测到旧模块 `pico4_swift205_libpreload`（v2.0.0），当前源码里的安装器会中止（这条拦截已随 **v2.8.2** ZIP 发布）；先 `touch /data/adb/modules/pico4_swift205_libpreload/remove` 并重启，再刷本 ZIP。两个模块会同时覆盖 `PvrSwift` 的 APK/so，卸载其中一个会误删另一个的 nativeLibraryDir。

### 升级（从任意旧版，含 v2.7 / 旧性能档）
直接安装 v2.8.2 ZIP 覆盖即可（**无需卸载**）；重启后生效，追踪器绑定保留，旧档调优属性自动还原。

### 卸载
Magisk 中删除本模块 → 重启。系统分区从未被修改，自动恢复原厂 2.0.4。

| 构建 | 说明 | 下载 |
|---|---|---|
| ✅ **v2.9.1（推荐）** | KarlVis/DirectTouch 全自动兼容（watcher 已实机验证）+ v2.0–v2.2 残留清理 | [`PICO4_MotionTracker_v2.9.1.zip`](../../releases/download/v2.9.1/PICO4_MotionTracker_v2.9.1.zip) |
| v2.8.2 | 库隔离修复 + 重复模块拦截；0 崩溃真机验证 | [`PICO4_MotionTracker_v2.8.2.zip`](../../releases/download/v2.8.2/PICO4_MotionTracker_v2.8.2.zip) |
| v2.8 | 库隔离修复版（无重复模块拦截） | [`PICO4_MotionTracker_v2.8.zip`](../../releases/download/v2.8/PICO4_MotionTracker_v2.8.zip) |
| ⚠️ v2.7（历史） | 库在全局路径，**有黑屏风险**，勿再安装 | [Releases](../../releases/tag/v2.7) |
| ⚠️ v2.0–v2.2（历史） | **改装 APK 路线**，存在 discovery 后台强制驻留等系统级副作用，请升级 v2.9 | [Releases](../../releases/tag/v2.0) |

---

## 🔧 原理

标准版跑不了 2.0.5 是"多层限制叠加"，逐层解决：

| # | 层 | 说明 |
|---|---|---|
| 1 | 门禁绕过 | priv-app overlay：把**原版 2.0.5 APK** 放入 `/system/priv-app`（原签名、零修改），绕过 `ro.pxr.externalfunc` 门禁 |
| 2 | 特权权限 | 以系统应用身份运行，`SWIFT_ACCESS` 等特权权限完整授予 |
| 3 | **native 兼容层（库隔离）** | 2.0.5 需要 P4 固件缺失的 `getSwiftTrackerInfoVector` 符号——补丁版 trackingclient（仅加一条 `DT_NEEDED`）+ 转发 shim 放进 **`priv-app/PvrSwift/lib/arm64/`**（`libswift.so` 加 `DT_RUNPATH=$ORIGIN`）。只有体感追踪器应用能加载到，`openxr_runtime` 等其他进程用原版系统库，互不干扰 |
| 4 | **版本切换生命周期** | 自动失效 PMS 解析缓存（安装方向 + 卸载方向双向），保证版本号、资源加载、应用启动全部正确 |
| 5 | 属性卫生 | 性能属性非持久化写入；卸载自动还原；v2.7 起升级时同样自动还原旧档属性 |

> 完整技术细节（二进制补丁、缓存机制、构建方式、踩坑记录）见 [FIX_NOTES_v2.6.md](FIX_NOTES_v2.6.md)；
> v2.0–v2.3 的历史逆向记录见 [FIX_NOTES.md](FIX_NOTES.md)。

---

## ✅ 已验证（真机）

- PICO 4 A8110 / PUI 5.13.7 / Magisk，3 台体感追踪器
- **v2.8 / libpreload 结构**（2026-10-06）：0 tombstone、openxr_runtime 正常、应用正常打开、3 台追踪器全部枚举（`bindState=1`）
- **v2.4 → v2.6 覆盖升级**：版本号自动刷新、应用正常打开、3 台追踪器全部检测到
- **v2.6 → v2.7 覆盖升级**（2026-09-16）：单档生效、旧属性清零、绑定保留
- **卸载**：版本自动回落 2.0.4、原版应用正常、缓存/属性/模块零残留
- 追踪器固件 sv1.89 / sv1.91 均已验证可用（固件工具见下方"相关项目"）

---

## ❓ 常见问题

**Q：追踪器列表为空 / 搜不到设备？**
v2.6 已修复此问题。若仍出现，请附 `adb logcat | grep -E "Swift205Shim|devices:"` 输出提 issue。

**Q：升级后应用里版本号不对 / 打不开？**
v2.6 起自动处理（每次开机自愈）。

**Q：性能调优（CPU/GPU 调度）去哪了？**
迁移到了 [pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode)。开启「性能模式」时由其伴生模块自动应用，关闭时恢复原厂。

**Q：还能刷旧版性能/极限档吗？**
历史 Release 仍在（v2.6），但不再维护；v2.7 起单档化，旧的调优请用 pico4-power-mode。

**Q：系统 OTA 后失效？**
正常现象，重刷本模块 zip 并重启即可。

**Q：游戏里弹出的边界确认/重标定窗口，确认按钮点不了（指针上没有确认圆圈，手柄和手势都不行）？**
这是 **KarlVis/DirectTouch 与本模块的叠加冲突**：DirectTouch 接管了 xrshell 的射线/光标
（悬停圆圈）更新，只认它注册表里的面板，追踪器的边界面板不在其中。**升级 v2.9.1**（覆盖安装
即可）——兼容监视器开机自动运行，DirectTouch 在面板存续期间自动让位、卡死自动解除，
全程无需手动操作。想帮忙定位可附 `/sdcard/pico4_diag_*.log` 提 issue。"dock 窗口跟随头部
旋转"是 Pico2Dock（替换系统底座 com.pvr.shortcut）× KarlVis(DockHook) 的冲突，与本模块无关。

**Q：v2.7 为什么会黑屏？**
兼容库当时挂在全局路径 `/system/lib64/`，`openxr_runtime` 等进程加载 trackingclient 时被连带拉入 shim，触发 SIGBUS 崩溃循环（实测 447 个 tombstone）。v2.8 已把库迁到 priv-app 私有目录，彻底修复。

**Q：5 点全身动捕到底能不能用？**
**不能。实测结论（2026-11，多位用户实测）：不支持。** 连接层是通的（5 台可配对、应用里能切 5 点档），但全身解算不工作——标准版原厂 BODYPOSE 算法缺 5 点专属的 forearm / knee 模型（`e2e_*_8_*`），Ultra 1.0.0.54 算法替代未经证实。请按 **2 点 / 3 点**使用。给期待 5 点的朋友道个歉——但模块在标准版上解锁 2.0.5、稳定追踪不掉线这些价值是真实的。

---

## 📄 文档与版本历史

- [RELEASE_NOTES_v2.9.md](RELEASE_NOTES_v2.9.md) — v2.9/v2.9.1 版本说明（边界确认指针冲突的完整根因分析：KarlVis DirectTouch + 实机验证记录）
- [RELEASE_NOTES_v2.7.md](RELEASE_NOTES_v2.7.md) — v2.7 版本说明
- [RELEASE_NOTES_v2.6.md](RELEASE_NOTES_v2.6.md) — v2.6 版本说明（历史）
- [FIX_NOTES_v2.6.md](FIX_NOTES_v2.6.md) — v2.4–v2.6 完整技术记录
- [FIX_NOTES.md](FIX_NOTES.md) — v2.0–v2.3 逆向与踩坑记录（历史）
- [RELEASE_NOTES.md](RELEASE_NOTES.md) — v2.3 版本说明（历史）

## 🔗 相关项目

- **[pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode)** — 性能模式解锁 + CPU/GPU 调度调优（v2.7 起性能调优的新家）
- **[pico4-tracker-firmware](https://github.com/hhhbwc/pico4-tracker-firmware)** — PICO 体感追踪器固件升级/降级工具

---

仅供学习研究，请支持正版。本项目为社区项目，与 PICO 官方无关。
