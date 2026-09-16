# PICO 4 Motion Tracker Unlock (2.0.5) — v2.7 Single Build

🇬🇧 English below · 🇷🇺 Русский ниже · 🇨🇳 中文在最下方

---

## 🇬🇧 English

**v2.7 = single build (stock scheduling) + tuning migration.**

### Changes

- 🔀 **3 flavors → 1 build.** Only the stock-scheduling build remains.
  Flashing over the old Performance / EXTREME flavors **automatically restores**
  the stock-scheduling properties (immediate best-effort + boot-time fallback).
- 🎛️ **CPU/GPU tuning moved to [pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode).**
  Its Magisk companion (`pico4-power-mode_tuner_magisk`) applies the performance
  scheduling while Performance Mode is active and restores stock otherwise.
  (IO-scheduler tuning was dropped — this kernel only offers noop/cfq.)
- 🧹 Upgrade path hardened: legacy cleanup + property restore on upgrade;
  tracker bonds kept.

### Install / Upgrade / Uninstall

- **Install**: Magisk → Modules → Install from storage → `PICO4_MotionTracker_v2.7.zip` → reboot.
- **Upgrade**: flash over any old version (v2.0–v2.6 incl. Performance/EXTREME).
- **Uninstall**: remove the module in Magisk → reboot → stock 2.0.4 restored.

### Verified (real device, 2026-09-16)

- v2.6 → v2.7 upgrade: single build active, legacy properties cleared, bonds kept
- Tracker detection / app open / reboot cycle all pass
- Test setup: PICO 4 A8110 / PUI 5.13.7 / Magisk, 3 Motion Trackers

### Checksums

| File | MD5 | SHA-256 |
|---|---|---|
| PICO4_MotionTracker_v2.7.zip | `583521b17abf147adf05293b2a04e607` | `472a00c4de88a361a64d44fc4e429727cff742ee69a6c8e2cd2f2721625ba0a9` |

---

## 🇷🇺 Русский

**v2.7 — единая сборка (стоковое планирование) + перенос тюнинга.**

### Изменения

- 🔀 **3 версии → 1 сборка.** Осталась только сборка со стоковым планированием.
  При прошивке поверх старых Performance / EXTREME свойства **автоматически
  восстанавливаются** к заводским.
- 🎛️ **Тюнинг CPU/GPU перенесён в [pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode).**
  Его Magisk-компаньон применяет производительное планирование при активном
  режиме производительности и возвращает сток иначе.
- 🧹 Обновление очищает остатки старых версий; привязки трекеров сохраняются.

### Установка / Обновление / Удаление

- **Установка**: Magisk → Модули → Установить из файла → `PICO4_MotionTracker_v2.7.zip` → перезагрузка.
- **Обновление**: прошить поверх любой старой версии (v2.0–v2.6, включая Performance/EXTREME).
- **Удаление**: удалить модуль → перезагрузка → возвращается стоковая 2.0.4.

### Проверено (реальное устройство, 16.09.2026)

- Обновление v2.6 → v2.7: единая сборка активна, старые свойства очищены, привязки сохранены
- Обнаружение трекеров / запуск приложения / цикл перезагрузки — всё в порядке

### Контрольные суммы

| Файл | MD5 | SHA-256 |
|---|---|---|
| PICO4_MotionTracker_v2.7.zip | `583521b17abf147adf05293b2a04e607` | `472a00c4de88a361a64d44fc4e429727cff742ee69a6c8e2cd2f2721625ba0a9` |

---

## 🇨🇳 中文

**v2.7 = 单档化（原厂调度）+ 性能调优迁移。**

### 变更

- 🔀 **三档 → 单档**：只保留原厂调度构建；从旧 Performance / EXTREME 档覆盖安装时，
  **自动还原**被改写的系统属性（即时 best-effort + 下次开机兜底）。
- 🎛️ **CPU/GPU 调优迁移至 [pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode)**：
  由其 Magisk 伴生组件在「性能模式」生效时应用，其他档位恢复原厂。
  （IO 调度器调优已放弃——本内核仅支持 noop/cfq。）
- 🧹 升级链路加固：升级时清理旧档残留 + 还原属性；追踪器绑定保留。

### 安装 / 升级 / 卸载

- **安装**：Magisk → 模块 → 从本地安装 → `PICO4_MotionTracker_v2.7.zip` → 重启
- **升级**：直接覆盖任意旧版（v2.0–v2.6，含性能/极限档）
- **卸载**：Magisk 移除模块 → 重启 → 自动恢复原版 2.0.4

### 已验证（真机，2026-09-16）

- v2.6 → v2.7 覆盖升级：单档生效、旧属性清零、绑定保留
- 追踪器检测 / 应用启动 / 重启循环全部通过
- 测试环境：PICO 4 A8110 / PUI 5.13.7 / Magisk，3 台追踪器

### 校验值

| 文件 | MD5 | SHA-256 |
|---|---|---|
| PICO4_MotionTracker_v2.7.zip | `583521b17abf147adf05293b2a04e607` | `472a00c4de88a361a64d44fc4e429727cff742ee69a6c8e2cd2f2721625ba0a9` |

---

For learning & research only. / Только для обучения и исследований. / 仅供学习研究，请支持正版。
