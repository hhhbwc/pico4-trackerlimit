# PICO 4 Motion Tracker Unlock (2.0.5) v2.8 — 修复版

> 🌐 [简体中文](#简体中文) | [English](#english) | [Русский](#русский)

---

## 简体中文

### 🛑 v2.7 用户请立即升级（黑屏风险）

**v2.7 的 native 兼容库挂在全局路径 `/system/lib64/`**。系统中所有加载 trackingclient 的进程
（包括 `com.pico.xr.openxr_runtime`）都会被拉入 shim，触发 OpenXR SIGBUS 崩溃循环 →
tombstone 累积（实测 **447 个**）→ system_server 连带崩溃 → **黑屏，只能强制重启**。

### 🐛 v2.8 修复

| 变化 | 说明 |
|---|---|
| 🐛 **库隔离（关键修复）** | 兼容库从 `/system/lib64/` 迁到 `/system/priv-app/PvrSwift/lib/arm64/`（priv-app 私有目录）。只有体感追踪器应用可见，OpenXR 运行时使用原版系统库。**真机验证：0 tombstone、3 台追踪器正常枚举、应用正常** |
| 🔏 **APK 换回原版** | v2.7 ZIP 内是重签名改装 APK；v2.8 恢复为 **PICO 原签名、零修改** 的 2.0.5 原版 APK |
| 🚫 **移除自动解绑** | 全新安装不再自动 unbond（解绑需 root 且有固件掉电风险）。若卡旧配对界面，手动执行：<br>`su -c "/system/bin/tracker_test unbond tracker1"`（依次 1/2/3） |
| 🧹 继承 v2.7 | 单档原厂调度、PMS 缓存双向自愈、升级残留/属性清理、升级保留绑定 |

### 安装

1. Magisk → 模块 → 从本地安装 `PICO4_MotionTracker_v2.8.zip`（从 v2.0–v2.7 直接覆盖，无需卸载）
2. 重启
3. 打开「体感追踪器」应用，正常配对/校准

### 卸载

Magisk 中删除模块 → 重启，自动恢复原厂 2.0.4。

### 校验

| 文件 | MD5 | SHA-256 |
|---|---|---|
| `PICO4_MotionTracker_v2.8.zip` | `830604bd1e1ea59e8679b096500f6084` | `2bb1fcec33f58cbd402c10bbaf6b0c2a6ec2c1d2630adc74f3fbee6fce3b0c18` |

---

## English

### 🛑 v2.7 users: upgrade immediately (black screen risk)

v2.7 mounts the native compat libraries at the **global path `/system/lib64/`**. Every process that
loads trackingclient — including `com.pico.xr.openxr_runtime` — gets the shim pulled in, causing an
OpenXR SIGBUS crash loop → tombstones pile up (447 measured) → system_server crashes → **black screen**.

### 🐛 v2.8 fixes

- **Library isolation (critical)**: compat libs moved into `/system/priv-app/PvrSwift/lib/arm64/` (priv-app private dir). Only the tracker app sees them. Verified: **0 tombstones, 3 trackers enumerated, app opens normally**.
- **Stock APK restored**: unmodified, PICO-signed 2.0.5 APK (v2.7 shipped a re-signed patched one).
- **Auto-unbond removed**: fresh installs keep existing bonds (manual commands above if stuck on the legacy pairing screen).
- Inherits v2.7: single build / stock scheduling, PMS-cache self-healing, upgrade cleanup.

Overlay-install over any v2.0–v2.7, reboot, done.

---

## Русский

### 🛑 Пользователям v2.7: обновитесь немедленно (риск чёрного экрана)

v2.7 монтирует библиотеки совместимости по **глобальному пути `/system/lib64/`**. Каждый процесс,
загружающий trackingclient — включая `com.pico.xr.openxr_runtime` — получает shim, вызывая цикл
сбоев OpenXR SIGBUS → накопление tombstone (замерено 447) → **чёрный экран**.

### 🐛 Исправления v2.8

- **Изоляция библиотек (критично)**: библиотеки перенесены в `/system/priv-app/PvrSwift/lib/arm64/`. Видит их только приложение трекеров. Проверено: **0 tombstone, 3 трекера, приложение работает**.
- **Стоковый APK**: нетронутый оригинал с подписью PICO.
- **Авто-разрыв связи убран**: привязки трекеров сохраняются (команды вручную выше при необходимости).
- Унаследовано от v2.7: единая сборка, стоковое планирование, самоисцеление PMS-кэша, очистка при обновлении.

Установка поверх v2.0–v2.7 без удаления, затем перезагрузка.

---

## ⚠️ 5 点模式（如实说明）

- **连接层**：系统支持（MCU `tracker_num=5`、应用 `upper.limit=5`、`ro.pxr.support.swiftversion=3`），5 台追踪器理论上可配对连接。
- **解算层**：当前模块使用原厂 BODYPOSE 1.0.0.47 算法，模型目录**缺少 5 点专属 forearm / knee 模型**（`e2e_*_8_*`），5 点全身解算大概率不可用；需 Ultra 1.0.0.54 算法（不随本模块分发）。
- **实测**：作者仅有 3 台追踪器，未做满配验证。有 5 台设备的朋友欢迎提 issue 附 logcat。

---

仅供学习研究，请支持正版。
