# PICO 4 Motion Tracker Unlock v2.8.2

🇬🇧 English below · 🇷🇺 Русский ниже · 🇨🇳 中文在最下方

---

## 🇬🇧 English

**What changed**

- **Refuse to stack two tracker modules.** v2.0.0 shipped as
  `pico4_swift205_libpreload`; this build is `pico4_swift_force_enable`.
  Installing both makes two modules overlay the same `PvrSwift` APK/libs, and
  uninstalling either deletes the other's `nativeLibraryDir`. The installer now
  aborts if the other module is present.
- **No PvrSwift payload change.** The v2.8 library isolation (compat libs in
  `priv-app/PvrSwift/lib/arm64`, stock PICO-signed APK) is unchanged.

**Migration from v2.0.0 (old module id)**

```bash
su -c 'touch /data/adb/modules/pico4_swift205_libpreload/remove'
# reboot, then flash v2.8.2
```

**Upgrade from v2.8**

Flash v2.8.2 over it (same module id), then reboot. No uninstall needed.

**Tested**: old-module guard, v2.8 → v2.8.2 upgrade, fresh install, uninstall/stock restore.

**Versions**: v2.8.2 (versionCode 14).

---

## 🇷🇺 Русский

**Что изменилось**

- **Запрет двух tracker-модулей.** v2.0.0 поставлялась как
  `pico4_swift205_libpreload`; эта сборка — `pico4_swift_force_enable`.
  Два модуля перекрывают одни и те же APK/so `PvrSwift`, и удаление одного
  стирает `nativeLibraryDir` другого. Установщик теперь прерывается, если
  найден другой модуль.
- **Payload PvrSwift не изменён.** Изоляция библиотек из v2.8 (compat-библиотеки
  в `priv-app/PvrSwift/lib/arm64`, оригинальный APK с подписью PICO) сохранена.

**Переход с v2.0.0 (старый id)**

```bash
su -c 'touch /data/adb/modules/pico4_swift205_libpreload/remove'
# перезагрузка, затем прошить v2.8.2
```

**Обновление с v2.8**

Прошейте v2.8.2 поверх (тот же id), затем перезагрузка. Удалять не нужно.

**Проверено**: защита от старого модуля, обновление v2.8 → v2.8.2, чистая установка,
удаление и возврат стока.

**Версии**: v2.8.2 (versionCode 14).

---

## 🇨🇳 中文

**本次变化**

- **拒绝两个 Tracker 模块叠加。** v2.0.0 的模块 id 是
  `pico4_swift205_libpreload`；本版本是 `pico4_swift_force_enable`。
  两个模块会同时覆盖同一套 `PvrSwift` APK/so，卸载其中一个会误删另一个的
  `nativeLibraryDir`。安装器检测到另一个模块时会直接中止。
- **PvrSwift 载荷不变。** v2.8 的库隔离方案（compat 库放
  `priv-app/PvrSwift/lib/arm64`，保留 PICO 原签名 APK）完全保留。

**从 v2.0.0（旧模块 id）迁移**

```bash
su -c 'touch /data/adb/modules/pico4_swift205_libpreload/remove'
# 重启，然后刷 v2.8.2
```

**从 v2.8 升级**

直接用 v2.8.2 覆盖（同模块 id），重启即可，无需卸载。

**已验证**：旧模块拦截、v2.8 → v2.8.2 升级、全新安装、卸载并恢复原厂。

**版本**：v2.8.2（versionCode 14）。
