🌐 [简体中文](README.md) | [English](README_EN.md) | [Русский](README_RU.md)

# PICO 4 Motion Tracker Unlock (2.0.5)

针对 **PICO 4 标准版**（A8110 / Phoenix，国行 ROM 5.13.7）的 PICO 体感追踪器应用完整解锁。
通过 **Magisk 模块** 将 Ultra 的「体感追踪器 2.0.5」应用完整移植到标准版，
**2 / 3 / 5 点追踪模式切换可用**。系统分区零修改，卸载即恢复原版。

> 📦 下载：[Releases](../../releases) → `PICO4_MotionTracker_2.0.5_v2.2.zip`
> 🔧 要求：Magisk 27+，PICO 4（标准版 / 其他被相同门禁限制的 4 系列）

---

## ✨ 解锁了什么

| 能力 | 原厂（标准版） | 解锁后 |
|---|---|---|
| 体感追踪器 2.0.5 应用 | 提示"设备不支持，请升级系统" | 完整可用 |
| 追踪器配对数量 | 2 或 3（随穿戴模式固定） | **2 / 3 / 5 个，应用内切换** |
| 特权权限 | 拿不到（签名不符） | priv-app 身份完整授予 |
| 5 点（5tk_thigh） | Ultra 专属档位 | 系统层已放开（见下方说明） |

---

## 📥 安装

1. 确认已 root（Magisk 27+）
2. Magisk → 模块 → 从本地安装 `PICO4_MotionTracker_2.0.5_v2.2.zip`
3. 重启
4. 打开「体感追踪器」应用，正常扫描配对 → 佩戴校准 → 开追

## 🗑️ 卸载

Magisk 中删除本模块 → 重启。系统分区从未被修改，自动恢复原厂状态。

---

## 🔄 模式切换（2 / 3 / 5 点）

- 应用 **设置页 → 数量上限**：选 3 或 5（选 3/5 时若已绑定数超目标会弹"先解绑"确认框，属原厂保护逻辑）
- 应用 **穿戴模式页**：切换 2 点（2tk）/ 3 点（3tk_waist）/ 5 点（5tk_thigh），
  确认时**自动联动配对上限**（2 点→2、3 点→3、5 点→5）
- 所有切换即时生效，不依赖 PICO 配置服务的写权限

> ⚠️ **注意：手上只有 3 个追踪器，无法实测配对5个。**
> 系统层证据（MCU `tracker_num=5`、Stationservice 按 5 槽位工作）表明 5 点理论上可行，
> 但满配 5 台的场景未经真机验证。配第 3 个以上遇到问题时欢迎提 issue 附 logcat。

---

## 🧩 原理：为什么需要这么多层

标准版跑不了这个应用，不是一道门，是**五层叠加**：

| # | 层 | 原厂行为 | 本方案处理 |
|---|---|---|---|
| 1 | 产品档位门禁 | `ro.pxr.externalfunc=0` → 应用判定"设备不支持" | priv-app overlay + 强制放行检查 |
| 2 | 特权权限 | 测试签名装 /data 拿不到 `SWIFT_ACCESS` 等 signature\|privileged 权限 | Magisk overlay 到 `/system/priv-app`，按"或"逻辑授予权限 |
| 3 | Native 兼容 | 2.0.5 的 `libswift.so` 需要 P4 缺失的 `getSwiftTrackerInfoVector` 导出，垃圾数据直通 JNI → `negative array length` 崩溃循环 | 禁用对应 vtable 调用路径 |
| 4 | 设备枚举 | 枚举接口不可用，设备列表恒为空，无法进入校准 | 改用系统 `statusChangedCallback` 回调缓存设备 |
| 5 | 模式切换 | PICO 配置服务拒绝应用写入系统键（wear mode 卡在 5 点，limit 卡在 5） | 应用内 override，选择即时生效 |

另有：配对用的 discovery 开关被应用的电源/前台可见性检查 ignore，已强制开启
（这正是"点了扫描没反应"的直接原因）。

完整的逆向过程、smali 改动清单、ARM64 二进制补丁细节和崩溃链分析见
[FIX_NOTES.md](FIX_NOTES.md)（包括那条 `negative array length: -954437177` 的完整解剖）。

---

## 🆚 与旧方案（LSPosed / Zygisk hook）的对比

本仓库最初是 LSPosed hook 方案（已在 v2.0 移除），差异：

| | LSPosed hook（旧） | Magisk priv-app overlay（新） |
|---|---|---|
| 思路 | 运行时 hook 拦截检查 | 直接替换应用 + 二进制补丁 |
| 崩溃风险 | 高（handleLoadPackage 阶段触发 ClassLoader 重入 → 崩溃循环；扫描阶段还有 hook 不到的方法体内硬编码） | 无 hook，改动随 APK 固化 |
| 权限 | 仍拿不到 priv-app 特权 | ✅ 完整授予 |
| native 层 | 无法覆盖（Xposed hook 不了 native） | ✅ 直接补丁 |
| 依赖 | 需要 Zygisk Vector 框架 | 仅 Magisk |
| 维护 | 每次 hook 点偏移变化都要改代码 | OTA 后重刷模块即可 |

---

## ❓ 常见问题

**Q：点了扫描设备没反应？**
确认应用版本是 2.0.5 且模块已安装重启。v2.0 已强制开启 discovery，
如仍有问题抓 logcat 过滤 `SwiftRepo|TrackingClient` 提 issue。

**Q：配对成功后追踪器几秒就断链？**
日志显示 `reason: tracker_power_off` 且 HMD 侧设置全部正确时，
是追踪器自身固件问题（多见于对在线状态的追踪器执行过解绑）。
**放回充电座充电几分钟或恢复出厂设置**后重新配对即可。

**Q：5 点能用吗？**
软件门已全开。但 5 点需要 5 台追踪器——手上只有 3 台，无法实测配对5个。

**Q：系统 OTA 后失效了？**
正常，Magisk overlay 在 OTA 后需要重刷模块 zip 再重启。

---

## 📦 校验（v2.0）

```
MD5:    e431d01ba43d62aa799127f842dfdc83
SHA256: f89449301fecae7627c022022c0741e198291927179709b4a98f5d2fec9093fa
```

## 📄 文档

- [RELEASE_NOTES.md](RELEASE_NOTES.md) — v2.0 版本说明
- [FIX_NOTES.md](FIX_NOTES.md) — 完整逆向与踩坑记录

仅供学习研究，请支持正版。

---

## ❓ 更多常见问题
**Q：应用一直显示"连接 DK 追踪器"/等待 DK？**
DK（Developer Kit）是 2.0 追踪器的产品名，2.0.5 应用默认运行在 2.0 模式。
如果你用的是**一代 PICO Motion Tracker**（蓝牙配对那种），请到
设置 → 追踪器版本 → 切到 **1.0**（切换前先解绑所有已配对追踪器）。

**Q：切换 2.0 失败（提示"切换失败"）？**
先在应用里解绑所有已配对追踪器再切。仍失败的话，root 下执行
`adb shell setprop persist.pxr.tracking.swiftVersion 2` 后重启应用再试，
并把 `getprop persist.pxr.tracking.swiftVersion` 和 `ro.pxr.support.swiftversion`
的结果连同 logcat 提 issue。

**Q：PICO 商店弹窗"Verification failed: illegal signature"并要求购买？**
正常现象——修改版 APK 使用测试签名，不是商店签名。点取消忽略即可。
**不要**购买/恢复商店版本，那会覆盖掉解锁。
