# PICO 4 Motion Tracker Unlock (2.0.5) v2.7 — Magisk Module

Enable the PICO Motion Tracker **2.0.5** app on the **PICO 4 (standard)** / PUI 5.13.x.
Tracker detection works; install / upgrade / uninstall are reliable.
No system partition changes — uninstall restores stock.

> **v2.7 = single build.** Only the stock-scheduling build remains.
> CPU/GPU performance tuning was moved to the **pico4-power-mode** project
> (its Magisk companion applies the tuning when Performance Mode is active).
> Upgrading from old Performance/EXTREME flavors auto-restores stock properties.

> 🇬🇧 English (below) · 🇷🇺 Русский (ниже) · 🇨🇳 中文（在最下方）

---

## English

- **What it is**: enables the *stock* 2.0.5 app via a Magisk module (priv-app overlay).
  Includes a native compat layer that fixes tracker detection, and a self-healing
  version-switch lifecycle (PackageManager cache handled automatically on
  install / upgrade / uninstall).
- **Single build**: stock scheduling only. No CPU/GPU tuning in this module
  (by design — that lives in pico4-power-mode now).
- **Install**: Magisk → Modules → Install from storage → pick the ZIP → reboot →
  open the "Motion Tracker" app.
- **Upgrade**: flash over any old version (v2.0–v2.6, incl. Performance/EXTREME
  flavors). No uninstall needed; tracker bonds kept; leftover tuning properties
  are restored to stock automatically.
- **Uninstall**: remove the module in Magisk → reboot → stock 2.0.4 restored.
- **Notes**: the app itself is stock and multi-language (follows your headset
  system language). Full technical notes: see `FIX_NOTES_v2.6.md` on GitHub.
- For learning & research only.

## Русский

- **Что это**: включает *штатное* приложение 2.0.5 через Magisk-модуль
  (priv-app overlay). Исправлено обнаружение трекеров и цикл
  обновления/удаления (кэш PackageManager обрабатывается автоматически).
- **Единая сборка**: только стоковый режим планирования. Настройки CPU/GPU
  перенесены в проект **pico4-power-mode**.
- **Установка**: Magisk → Модули → Установить из файла → ZIP → перезагрузка →
  открыть приложение «Motion Tracker».
- **Обновление**: прошить поверх любой старой версии (v2.0–v2.6, включая
  Performance/EXTREME) — привязки сохраняются, остатки настроек сбрасываются.
- **Удаление**: удалить модуль в Magisk → перезагрузка — возвращается стоковая 2.0.4.
- Только для обучения и исследований.

## 中文

本模块用于在 PICO 4 标准版（PUI 5.13.x）上完整启用「体感追踪器 2.0.5」应用：

- **原版 APK**（零修改、原签名）+ **native 兼容层**修复追踪器检测；
- 版本切换/升级/卸载全链路自动修复（PMS 解析缓存双向处理）；
- **v2.7 起单档版**：仅保留原厂调度（不做性能调优）；
  性能调优已迁移至 **pico4-power-mode** 项目（由其 Magisk 伴生组件在性能模式下应用）；
- 从旧性能档（Performance/EXTREME）升级时，自动还原被改写过的系统属性；
- 安装：Magisk → 模块 → 从本地安装 → 重启 → 打开「体感追踪器」；
- 卸载：Magisk 移除模块 → 重启，自动恢复原版 2.0.4。
- 应用自带多语言（跟随头显系统语言）。
- 详细技术记录见 GitHub 仓库 `FIX_NOTES_v2.6.md`。仅供学习研究。

---

*Module version v2.7 · versionCode 12 · Magisk required.*
