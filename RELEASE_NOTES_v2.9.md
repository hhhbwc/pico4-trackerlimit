# Release v2.9 / v2.9.1 — "边界确认按钮点不了" 冲突修复（全自动）

> 用户报告（俄语用户，2026-11）：装 **v2.0** 后，游戏中弹出的边界确认/重标定窗口，
> 其"确认"按钮无法点击——指针射线还在，但悬停时确认圆圈不出现；手柄与手势
> （hands）均失效；表现为系统级。首装后第一次开机正常，重启/断电/应用其他模块
> 后复现。同时报告了 Pico2Dock 的窗口跟随头部旋转问题（该问题归属 Pico2Dock）。

---

## ⓪ 真实冲突点（2026-11-19 用户提供 KarlVis 安装包后逆向确认）

用户后来发来了他机器上装的 **KarlVis O1.13.7S**（俄语社区的 PICO 4 增强 сборка）
与 Pico2Dock 源码包。逆向结论：

**KarlVis 的 DirectTouch 才是"指针圆圈消失"的另一半冲突方：**

- `directtouch.apk` = LSPosed 模块 `com.picodirecttouch.lsposed`，scope 含
  `com.picoxr.xrshell`（系统指针/窗口壳层）、`com.picovr.systemext`、
  `com.pvr.shortcut`、`com.picovr.settings`、IME 等 7 个包；
- 对 xrshell：Java 层 hook `com.picoxr.xrshell.event.EventWindowProvider.updateWindow`
  （把窗口几何记入自己的注册表）+ **注入 native 库 `libdirecttouch.so`**；
- 该 so 以 proxy/orig 内联代理方式接管引擎的：
  - `rayProxy/origRayUpdate` —— **射线更新**（指针命中判定）
  - `cursorProxy/origCursorUpdate` —— **光标更新**（悬停圆圈）
  - `syncProxy` —— 面板管理器同步（PanelVector）
  - `InputManager::InjectMotionEvent` —— 只给自己的面板注入触摸事件
    （日志原话：`no InjectMotionEvent, islands will not answer the controller ray`）

即：**只有 DirectTouch 注册表里的面板才有正常指针交互**。体感追踪器的边界
确认/重标定面板（PvrSwift `VSTPanel`，经 native shell 服务创建的应用层，
不走 `EventWindowProvider`）不在注册表里 → 悬停圆圈不出现、手柄手势都无法点击。

**为什么"装了追踪器模块才坏"**：没有追踪器模块时，2.0.4 被门禁拦住，VST 面板
根本不会出现 → 症状消失；没有 KarlVis 时，引擎原版命中逻辑覆盖所有层 → 面板正常
（作者真机从未见过此症状）。两者叠加才触发。**"第一次开机正常、重启后坏"则是
LSPosed 钩子重启后才生效**——与追踪模块无关。

**Pico2Dock**（`pico_re/sc.apk`，包名 `com.pvr.shortcut`——系统底座本身）与
KarlVis 的 DockHook 同时 hook `com.pvr.shortcut`；"dock 窗口跟随头部旋转"是
这两个的冲突，与本模块无关。KarlVis README 自己也警告"关闭其他改壳层的模块
（fwanchor、PicoWindowResize）：它们改同一批窗口"。

**v2.9.1 的对策（全自动，无需手动点击）**：`dt_compat.sh` 监视器随模块开机自启
（未装 KarlVis 时自动退出，零开销），监听 VSTPanel 生命周期：
面板弹出 → 临时 `setprop persist.dt.enable 0`（DirectTouch 总开关，游戏内 2D
直触本就无用），面板消失自动还原；面板悬空 120s 且前台是游戏（卡死）→ 自动
`force-stop com.pvr.swift` 解除（不影响游戏内追踪数据流），每次开机限 3 次；
前台是 PICO 自家界面（正在校准）绝不干预。调节开关：
`setprop persist.pvr.dt_compat_mode 0/1/2`（0=只记录，1=缺省，2=含自动解锁）。

---

## 一、v2.0 的模块侧副作用（次要背景——初版分析，当时的首要假设；真实冲突主因见上节 ⓪）

v2.0 模块的全部内容只有两样：`customize.sh`（仅备份原 APK）+
**测试签名、smali 补丁过的 PvrSwift 2.0.5 APK**（`swift205_patched_v23.apk`，
md5 `fff13444db4f79603a7e613177be23ea`，已下载 Release 资产并与文档核对一致）。

把该 APK 与 **原版 2.0.5 APK**（v2.8+ 路线所用）做全量 baksmali diff，差异恰好
7 个类，无未记录改动：

| 类 | 补丁内容 |
|---|---|
| `Features` / `SwiftVM$init$1` / `MainActivity` | 门禁绕过（swiftSupport / isVersionSupported 恒真） |
| `SwiftRepo` | **`setSwiftDiscoverySwitch` 的 5 处守卫全部 nop**；设备列表改回调缓存 |
| `SwiftImpl` / `Utils` / `WearModeFragment` | wear-mode / upper-limit 内存 override |

关键在 `SwiftRepo.setSwiftDiscoverySwitch`。原版逻辑在 `enable=1` 时要求：
`swiftVersion==2` 且 `powerMode==1` 且 `!batteryLow` 且 `size<limit` 且
**`isAppVisible`**，不满足即 ignore。v2.0 把这 5 处条件跳转全部替换成 `nop`
（FIX_NOTES v20 记录的行为：`setDevDiscoverySwitch enable 1 tracker_num 5`
不再 ignore）。

而调用方是谁？`SwiftService`——跑在独立后台进程 `com.pvr.swift.service`、
监听 `SCREEN_ON / SCREEN_OFF / BATTERY_LOW / BATTERY_OKAY`、随
`BOOT_COMPLETED` 启动的系统侧服务，在上述每个事件上都会调用
`setSwiftDiscoverySwitch(1, ...)`。

**结论**：v2.0 部署后，追踪站点（station）的 discovery/配对开关在后台被无条件
反复打开，且不受"应用是否可见"约束——整个追踪子系统长期处于"等待配对/发现"
状态。正常流程里，这个状态只应在校准/配对界面短暂存在。

## 二、为什么症状是"边界确认按钮点不了"

游戏内的边界重确认/重标定窗口走的是 PvrSwift 的 VST 流程：

```
系统广播 pvr.intent.action.swift.vst(.tob)
  → SwiftReceiver（exported，manifest 声明）
  → VSTPanel.showVST(failMode, avatarMode)
  → WindowManagerProxy.addView(..., TYPE_ERROR_IN_WORLD)
  → PvrApiUtils.createSurfaceTexture → native shell（xrshell）创建 XR 系统层
```

（`VSTPanel` / `WindowManagerProxy` / `PvrApiUtils` 三个类在补丁 APK 与原版间
**零差异**——窗口逻辑本身是原厂代码。）

当追踪子系统被 v2.0 卡在后台 discovery 状态时，面板的显示/隐藏状态机
（`showing` / `enterMode` / `failMode` / `stopCalibrate timeout`）可能停在
"已武装"状态：面板层残留或被反复重建，**指针射线命中了这层系统层而不是
PUI 的确认按钮** —— 表现正是：按钮可见、悬停确认圆圈不出现、手柄与手势
都无法点击（XR 层未注册为可交互目标时，运行时不产生 hover 圆圈）。
"首装后第一次开机正常、之后复现" 与 SwiftService 随 BOOT/屏幕/电池事件
逐步把状态推入卡死一致。

> 注：这是模块侧唯一能解释该症状的机制（v2.0 相对 v2.8.2 的全部差异就是
> 上述 7 个类，其余系统级变化为零）。若 v2.9（原版 APK + 清理）之后症状仍
> 复现，则说明是 2.0.5 面板层与 PUI 5.13.x 的输入路由问题（原厂 Ultra 固件
> 5.14+ 才有官方适配），届时用 v2.9 附带的诊断文件定位——诊断包会记录
> 面板层归属与窗口标志。

## 三、v2.9 / v2.9.1 改动

| # | 改动 | 说明 |
|---|---|---|
| 1 | **升级清理（customize.sh §4b）** | 覆盖安装时从 `/data/data/com.pvr.swift/shared_prefs/swift_state.xml` 移除改装 APK 写入的 `key_mod_wear_mode` / `key_mod_upper_limit` 键（原版 APK 从不读它们）。其余键（隐私授权/绑定数/校准计数）不动。卸载脚本同样清理 |
| 2 | **DirectTouch 兼容监视器（dt_compat.sh，v2.9.1 新增）** | 开机自启、全自动、无需任何手动点击；未装 KarlVis 自动退出。三条路径（见上节）；事件以 logcat 时间戳为幂等键，杜绝震荡（实机踩坑后修复） |
| 3 | **救援脚本（rescue.sh）** | 手动立即救援 + 采集诊断（Magisk"执行"按钮或 adb）；v2.9.1 增加 DirectTouch/lspd 诊断段 |
| 4 | **诊断包** | `/sdcard/pico4_diag_<ts>.log`：props（swift/pxr/dt）、PvrSwift 解析、进程、窗口层、SurfaceFlinger、服务、VST+DirectTouch 相关 logcat、兼容监视器自身日志 |
| 5 | **service.sh** | 自检扩充 + 自动拉起监视器 |
| 6 | 架构不变 | 原版 PICO 签名 APK + priv-app 私有库目录（v2.8 路线），零系统分区修改 |

## 三b、实机验证（A8110 / PUI 5.13.7-202510300008，作者自己的头显，无追踪器）

| 测试 | 结果 |
|---|---|
| 设备端 `sh -n`（mksh） | ✅ |
| 面板弹出 → `persist.dt.enable 0`（注入 showVST 日志） | ✅ 实机 setprop 生效 |
| 面板消失 → 属性自动还原（unset 走 resetprop -d） | ✅ |
| 卡死自动解锁（mode=2，前台=游戏） | ✅ 15s 后自动 force-stop，属性还原 |
| 防震荡幂等键 | ✅ 45s 观察窗内仅 1 次 force-stop，无重复武装 |
| 前台判定 | ✅ 适配 PUI 5.13.x 真实行格式（` ResumedActivity:ActivityRecord{… u0 pkg/…`，主屏取第一行）；文件中转规避 dumpsys SIGPIPE 丢输出（实机踩坑） |
| 未装 KarlVis 时 | ✅ watcher 立即退出，零开销 |

> 说明：验证机上 KarlVis 无法安装（XRShell 哈希 `2a4d157a…` ≠ KarlVis 适配的
> `06e6c265…`，ROM 构建 202510300008 vs 202510301735）——native 内联钩子对
> 错位二进制有崩溃风险，故仅在无 scope 的休眠状态下验证 watcher 状态机。
> `persist.dt.enable` 是否被 DirectTouch 实时读取（而非仅在 xrshell 启动时）
> 仍待真机确认：实时生效 → 面板立即恢复可点；否则由卡死自动解锁兜底。
> 两条路都不需要用户手动干预。

## 四、对 v2.0 用户（本次报告者）的处置

1. **直接覆盖安装 v2.9.1 ZIP，重启**（同模块 id `pico4_swift_force_enable`，无需卸载；绑定保留）。
   完成：换回原版 APK（消除改装 APK 的全部副作用）+ 清理改装残留 + **自动启用
   DirectTouch 兼容监视器**——之后边界确认按钮无需任何手动操作。
2. 如果还想帮忙定位（可选）：卡住时抓一份 `/sdcard/pico4_diag_*.log` 发给开发者。
3. Pico2Dock 的"dock 窗口跟随头部旋转"= Pico2Dock(替换 com.pvr.shortcut) ×
   KarlVis(DockHook) 的冲突，请向 KarlVis/Pico2Dock 作者反馈。

## 五、已知限制（诚实声明）

- watcher 状态机已在作者真机（A8110/5.13.7）端到端验证（见三b节）；
  但 `persist.dt.enable` 的实时语义（DirectTouch 是否热读该属性）未能在验证机
  确认（XRShell 哈希不匹配，装 KarlVis 有崩溃风险）——该属性若只在 xrshell
  启动时读取，则让位路径退化为"下次壳层重启生效"，卡死兜底路径（mode 2）
  不受影响，两条路都不需要用户手动干预。
- v2.0 改装 APK 时代的 discovery 强驻留分析仍成立（v2.9.1 换回原版 APK 后消失）。
