🌐 [简体中文](README.md) | English | [Русский](README_RU.md)

# PICO 4 Motion Tracker Unlock (2.0.5)

Full unlock of the PICO Motion Tracker app **2.0.5** for the **PICO 4 standard edition** (A8110 / Phoenix, ROM 5.13.x).
The app is enabled via a **Magisk module**: **tracker detection works, and install / upgrade / uninstall are fully reliable**. Zero system partition modifications — uninstall restores stock.

> 📦 Download: [Releases](../../releases) → **v2.8** (fixed build: library isolation, 0 crashes)
> 🔧 Requirements: Magisk 27+, PICO 4 standard edition (or other 4-series devices behind the same gates)

---

## 🛑 v2.7 users: upgrade to v2.8 ASAP (black screen risk)

**v2.7 has a critical flaw**: the native compat libraries are mounted at the global path `/system/lib64/`.
**Every** process that loads trackingclient — including `com.pico.xr.openxr_runtime` — gets the shim pulled in,
causing an OpenXR SIGBUS crash loop → tombstones pile up (447 measured) → system_server crashes → **black screen** (forced reboot only).

**v2.8 fix**: the libraries now live in `/system/priv-app/PvrSwift/lib/arm64/` (priv-app private nativeLibraryDir).
Only the tracker app sees them; the OpenXR runtime keeps using the stock system library.
Verified on device: **0 tombstones, 3 trackers enumerated, app opens normally**.
Overlay-install v2.8 over v2.7 — no uninstall needed. The APK is back to the unmodified, PICO-signed original, and auto-unbond has been removed (manual commands in the FAQ).

---

## 🆕 v2.7: single build + tuning migration

| Change | Details |
|---|---|
| 🔀 **3 flavors → 1 build** | Only one build remains (stock scheduling). Flashing over the old Performance / EXTREME flavors **automatically restores** the stock-scheduling properties |
| 🎛️ **Performance tuning moved out** | The CPU/GPU scheduling tuning now lives in **[pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode)**: its Magisk companion applies it while Performance Mode is active, and restores stock otherwise |
| 🧹 **Clean upgrades** | Legacy tuning properties are cleaned up on upgrade (immediately + boot-time fallback) |

> Why single build? Maintaining three builds had no purpose — the unlock is independent of scheduling, and tuning is now consolidated in one place (power-mode).

---

## 🆕 What v2.6 fixes (reliability foundation)

| # | Old issue | v2.6 fix |
|---|---|---|
| 1 | Tracker list always empty (no devices found) | ✅ **Native compat layer** supplies the symbol missing from P4 firmware; device list works (verified with 3 trackers) |
| 2 | Version number not updated after upgrade / stuck after uninstall / app won't open after switching | ✅ **Automatic PackageManager parse-cache handling** in both directions (self-healing on boot) |
| 3 | Leftovers when upgrading from old versions | ✅ Auto-cleanup of v2.0–v2.4 residue; tracker bonds preserved |
| 4 | Persistent properties left by performance flavors | ✅ Non-persistent writes + auto-restore on uninstall |
| 5 | Switching flavors required uninstall | 🔁 Flavors were cross-flashable; **merged into one build since v2.7** |

> ⚠️ Upgrading from v2.0–v2.6 (incl. Performance/EXTREME): just install v2.7 over it — no uninstall needed.

---

## ✨ What gets unlocked

| Capability | Stock (standard edition) | After unlock |
|---|---|---|
| Motion Tracker 2.0.5 app | "Device not supported, please upgrade" | Fully working (**stock APK, original signature, zero modifications**) |
| Tracker detection | — | ✅ List / connect / calibrate |
| Privileged permissions | Unobtainable (signature mismatch) | Full priv-app grant |
| Tracker count | 2 or 3 (fixed by wear mode) | 2 / 3 / 5, following official app flows |
| 5-point (forearm / knee) | Ultra-only tier | Unlocked at system level (5 trackers required) |

---

## 📥 Install / Upgrade / Uninstall

### Install
1. Make sure you're rooted (Magisk 27+)
2. Magisk → Modules → Install from storage → pick the ZIP
3. Reboot
4. Open the "Motion Tracker" app

### Upgrade (from any old version, incl. old Performance/EXTREME)
Just flash v2.7 over it (**no uninstall needed**); takes effect after reboot, tracker bonds are kept, legacy tuning properties are restored.

### Uninstall
Remove the module in Magisk → reboot. The system partition was never touched; stock 2.0.4 is restored automatically.

| Build | Notes | Download |
|---|---|---|
| ✅ **v2.7 (only build)** | Stock scheduling; pair with pico4-power-mode for tuning | [`PICO4_MotionTracker_v2.7.zip`](../../releases/download/v2.7/PICO4_MotionTracker_v2.7.zip) |

---

## 🔧 How it works

| # | Layer | Details |
|---|---|---|
| 1 | Gate bypass | priv-app overlay: the **stock 2.0.5 APK** is placed into `/system/priv-app` (original signature), bypassing the `ro.pxr.externalfunc` check |
| 2 | Privileges | Runs as a system app — privileged permissions fully granted |
| 3 | **Native compat layer** | 2.0.5 needs `getSwiftTrackerInfoVector`, missing from P4 firmware — fixed by patching the system tracking lib (one extra dependency) + a tiny forwarding shim |
| 4 | **Version-switch lifecycle** | Automatically invalidates the PackageManager parse cache (both install and uninstall directions) |
| 5 | Property hygiene | Non-persistent writes; restored on uninstall; since v2.7 also restored on flavor upgrades |

> Full technical notes: [FIX_NOTES_v2.6.md](FIX_NOTES_v2.6.md). History (v2.0–v2.3): [FIX_NOTES.md](FIX_NOTES.md).

---

## ✅ Verified (real device)

- PICO 4 A8110 / PUI 5.13.7 / Magisk, 3 Motion Trackers
- **v2.4 → v2.6 upgrade**: version auto-updated, app opens, all 3 trackers detected
- **v2.6 → v2.7 upgrade** (2026-09-16): single build active, legacy properties cleared, bonds kept
- **Uninstall**: version falls back to 2.0.4, stock app works, zero residue
- Tracker firmware sv1.89 / sv1.91 both verified working

---

## ❓ FAQ

**Q: Tracker list is empty?**
Fixed in v2.6. If it still happens, open an issue with `adb logcat | grep -E "Swift205Shim|devices:"`.

**Q: Where did the CPU/GPU performance tuning go?**
Moved to [pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode). It auto-applies while Performance Mode is on and restores stock when off.

**Q: Can I still flash the old Performance/EXTREME zips?**
Old releases remain (v2.6) but are no longer maintained; v2.7+ is single-build — use pico4-power-mode for tuning.

**Q: Version number wrong / app won't open after switching?**
Handled automatically since v2.6 (self-healing on every boot).

**Q: Breaks after system OTA?**
Expected — re-flash the module ZIP and reboot.

**Q: 5-point mode?**
Needs 5 trackers; not fully tested with 5 units (system-level evidence shows 5 slots supported).

---

## 📄 Docs & version history

- [RELEASE_NOTES_v2.7.md](RELEASE_NOTES_v2.7.md) — v2.7 release notes
- [RELEASE_NOTES_v2.6.md](RELEASE_NOTES_v2.6.md) — v2.6 release notes (historical)
- [FIX_NOTES_v2.6.md](FIX_NOTES_v2.6.md) — full v2.4–v2.6 technical notes
- [FIX_NOTES.md](FIX_NOTES.md) — v2.0–v2.3 reverse-engineering log (historical)

## 🔗 Related projects

- **[pico4-power-mode](https://github.com/hhhbwc/pico4-power-mode)** — Performance Mode unlock + CPU/GPU scheduling tuning (the new home of the tuning)
- **[pico4-tracker-firmware](https://github.com/hhhbwc/pico4-tracker-firmware)** — PICO Motion Tracker firmware update/downgrade toolkit

---

For learning & research only. Community project, not affiliated with PICO.
