# PICO 4 Motion Tracker Unlock (2.0.5) — v2.6 Compatibility Fix Release

🇬🇧 English below · 🇷🇺 Русский ниже · 🇨🇳 中文在最下方

---

## 🇬🇧 English

**v2.6 = compatibility fix release** (v2.5 skipped). Fixes two core issues:
① tracker detection was always empty; ② version switching / uninstall lifecycle
(version number stuck; app failing to open after switching).

### Fixes

- 🐛 **Tracker detection restored** — a native compat layer supplies the
  `getSwiftTrackerInfoVector` symbol missing from P4 firmware.
  Before: empty device list (`devices: null`); after: **3 trackers detected**
  (verified on a real device).
- 🐛 **Version-switch lifecycle fixed** — automatic PackageManager parse-cache
  handling on install / upgrade / uninstall (PUI 5.13.x). Fixes: version not
  updating after upgrade / stuck after uninstall / app crash
  “Failed to resolve attribute” after switching.
- 🐛 **Upgrade path hardened** — auto-cleanup of v2.0–v2.4 leftovers;
  `modules_update` untouched.
- 🐛 **Cleaner uninstall** — restores properties written by old performance
  builds; zero residue.
- 🔁 **Flavors are cross-flashable** — Standard / Performance / EXTREME:
  flash any flavor over another anytime (no uninstall, tracker bonds kept).
- 🔖 version=v2.6 / versionCode=11

### Downloads

| Flavor | Notes | File |
|---|---|---|
| ⭐ Standard | recommended for daily use | `PICO4_MotionTracker_v2.6_standard.zip` |
| 🚀 Performance | CPU performance tuning | `PICO4_MotionTracker_v2.6_performance.zip` |
| 🔥 EXTREME | max performance (high power/heat) | `PICO4_MotionTracker_v2.6_extreme.zip` |

### Install / Upgrade / Uninstall

- **Install**: Magisk → Modules → Install from storage → pick a ZIP → reboot →
  open the Motion Tracker app.
- **Upgrade**: flash over any old version (v2.0–v2.4). No uninstall needed;
  tracker bonds are kept.
- **Uninstall**: remove the module in Magisk → reboot → stock 2.0.4 is restored.
- The module keeps the app **stock (original signature)** and it is
  multi-language (follows the headset system language).

### Verified (real device, 2026-09-15)

- v2.4 → v2.6 upgrade: version auto-updates, app opens, all 3 trackers detected
- v2.6 uninstall: version falls back to 2.0.4, stock app works, zero residue
- Cross-flash Standard ⇄ Performance ⇄ EXTREME: verified both ways
- Test setup: PICO 4 A8110 / PUI 5.13.7 / Magisk, 3 Motion Trackers

---

## 🇷🇺 Русский

**v2.6 — релиз с исправлениями совместимости** (v2.5 пропущена). Решает две
основные проблемы: ① список трекеров всегда был пуст; ② цикл переключения
версий / удаления (номер версии «застревал», приложение не открывалось после
переключения).

### Исправления

- 🐛 **Обнаружение трекеров восстановлено** — нативный слой совместимости
  добавляет отсутствующий в прошивке P4 символ `getSwiftTrackerInfoVector`.
  Было: пустой список устройств; стало: **3 трекера определяются** (проверено
  на реальном устройстве).
- 🐛 **Цикл переключения версий исправлен** — автоматическая обработка кэша
  PackageManager при установке / обновлении / удалении (PUI 5.13.x).
  Исправлено: номер версии не обновлялся после апгрейда / «застревал» после
  удаления / падение приложения с «Failed to resolve attribute».
- 🐛 **Обновление со старых версий** — автоматическая очистка остатков v2.0–v2.4.
- 🐛 **Чистое удаление** — восстановление свойств, записанных старыми
  performance-сборками; без остатков.
- 🔁 **Версии (Standard / Performance / EXTREME) можно перепрошивать друг
  поверх друга** в любой момент — без удаления, привязки трекеров сохраняются.
- 🔖 version=v2.6 / versionCode=11

### Скачать

| Версия | Описание | Файл |
|---|---|---|
| ⭐ Standard | рекомендуется для ежедневного использования | `PICO4_MotionTracker_v2.6_standard.zip` |
| 🚀 Performance | настройка производительности CPU | `PICO4_MotionTracker_v2.6_performance.zip` |
| 🔥 EXTREME | максимальная производительность (высокий нагрев) | `PICO4_MotionTracker_v2.6_extreme.zip` |

### Установка / обновление / удаление

- **Установка**: Magisk → Модули → Установить из файла → ZIP → перезагрузка →
  открыть приложение «Motion Tracker».
- **Обновление**: прошить поверх любой старой версии (v2.0–v2.4) —
  удалять не нужно.
- **Удаление**: удалить модуль в Magisk → перезагрузка → возвращается
  стоковая 2.0.4.
- Приложение остаётся **штатным (оригинальная подпись)** и поддерживает
  много языков (язык — по системе шлема).

### Проверено (реальное устройство, 15.09.2026)

- Обновление v2.4 → v2.6: версия обновляется автоматически, приложение
  открывается, все 3 трекера найдены
- Удаление v2.6: возврат к 2.0.4, стоковое приложение работает, без остатков
- Перепрошивка версий: проверена в обе стороны
- Тест: PICO 4 A8110 / PUI 5.13.7 / Magisk, 3 трекера

---

## 🇨🇳 中文

**v2.6 是 v2.4 的兼容修复版**（跳过 v2.5）：解决两类核心问题——
① 追踪器检测为空；② 版本切换/卸载闭环（版本号回不去、切换后打不开应用）。

### 修复内容

- 🐛 **追踪器检测恢复**：native 兼容层补齐 P4 固件缺失的
  `getSwiftTrackerInfoVector` 符号。修复前设备列表恒为空；修复后
  **3 台追踪器正常列出**（真机验证）。
- 🐛 **版本切换全链路修复**：安装/升级/卸载三个方向自动失效 PMS 解析缓存
  （修复"版本号不变 / 回不去 / 资源错配崩溃"）。
- 🐛 **升级链路加固**：覆盖安装自动清理 v2.0–v2.4 残留；不触碰 modules_update。
- 🐛 **卸载更干净**：还原旧版性能包写入的属性；零残留。
- 🔁 **三档互刷**：Standard / Performance / EXTREME 可互相覆盖安装
  （无需卸载、绑定保留）。
- 🔖 version=v2.6 / versionCode=11

### 安装 / 升级 / 卸载

- **安装**：Magisk → 模块 → 从本地安装 → 重启 → 打开「体感追踪器」。
- **升级**：直接覆盖安装（无需卸载）；绑定保留。
- **卸载**：Magisk 移除模块 → 重启 → 自动恢复原版 2.0.4。
- 应用保持原版（原签名），自带多语言（跟随头显系统语言）。

### 已验证（真机，2026-09-15）

- v2.4 → v2.6 覆盖升级：版本自动刷新、应用正常、3 台追踪器全部检测到
- v2.6 卸载：版本回落 2.0.4、原版应用正常、零残留
- 三档互刷：双向通过
- 测试环境：PICO 4 A8110 / PUI 5.13.7 / Magisk，3 台追踪器

---

## Checksums / Контрольные суммы / 校验值

| File | MD5 | SHA-256 |
|---|---|---|
| PICO4_MotionTracker_v2.6_standard.zip | `0daf2e328d670798f553eda48921c79c` | `0cdea9fbadd61e3e245a899ebba56f25066311d4509bc225085772d6201c4c6e` |
| PICO4_MotionTracker_v2.6_performance.zip | `a98d4a8cce2bdddcaa146b6bc32b57c4` | `e183d89cd172553a5ef64f6fbd08de39bbb83596c4fde3f42ad1c1c918b64d00` |
| PICO4_MotionTracker_v2.6_extreme.zip | `fffb8c1e10c47c60dcf2e915953b7972` | `28f3778232b4d40da338b8ed87f9f702f146a5e2c83824e3300f1945abfc14cf` |

---

For learning & research only. / Только для обучения и исследований. / 仅供学习研究，请支持正版。
