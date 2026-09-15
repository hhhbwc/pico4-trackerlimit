🌐 [简体中文](README.md) | English | [Русский](README_RU.md)

# PICO 4 Motion Tracker Unlock (2.0.5)

Full unlock of the PICO Motion Tracker app **2.0.5** for the **PICO 4 standard edition** (A8110 / Phoenix, ROM 5.13.x).
The app is enabled via a **Magisk module**: **tracker detection works, and install / upgrade / uninstall are fully reliable**. Zero system partition modifications — uninstall restores stock.

> 📦 Download: [Releases](../../releases) → **v2.6** (Standard / Performance / EXTREME)
> 🔧 Requirements: Magisk 27+, PICO 4 standard edition (or other 4-series devices behind the same gates)

---

## 🆕 What v2.6 fixes

| # | Old issue | v2.6 fix |
|---|---|---|
| 1 | Tracker list always empty (no devices found) | ✅ **Native compat layer** supplies the symbol missing from P4 firmware; device list works (verified with 3 trackers) |
| 2 | Version number not updated after upgrade / stuck after uninstall / app won't open after switching | ✅ **Automatic PackageManager parse-cache handling** in both directions (self-healing on boot) |
| 3 | Leftovers when upgrading from old versions | ✅ Auto-cleanup of v2.0–v2.4 residue; tracker bonds preserved |
| 4 | Persistent properties left by performance flavors | ✅ Non-persistent writes + auto-restore on uninstall |
| 5 | Switching flavors required uninstall | 🔁 **Cross-flashable flavors** (same module ID, no uninstall, bonds kept) |

> ⚠️ Upgrading from v2.0–v2.4: just install v2.6 over it — no uninstall needed.

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
2. Magisk → Modules → Install from storage → pick a flavor ZIP
3. Reboot
4. Open the "Motion Tracker" app

### Upgrade (from any old version)
Just flash the new ZIP over it (**no uninstall needed**); takes effect after reboot, tracker bonds are kept.

### Cross-flashing flavors
Standard / Performance / EXTREME are the same module (different tuning) — flash any other ZIP at any time.

### Uninstall
Remove the module in Magisk → reboot. The system partition was never touched; stock 2.0.4 is restored automatically.

| Flavor | Notes | Download |
|---|---|---|
| ⭐ Standard | Recommended daily | [`PICO4_MotionTracker_v2.6_standard.zip`](../../releases/download/v2.6/PICO4_MotionTracker_v2.6_standard.zip) |
| 🚀 Performance | CPU performance tuning | [`PICO4_MotionTracker_v2.6_performance.zip`](../../releases/download/v2.6/PICO4_MotionTracker_v2.6_performance.zip) |
| 🔥 EXTREME | Max performance (high power) | [`PICO4_MotionTracker_v2.6_extreme.zip`](../../releases/download/v2.6/PICO4_MotionTracker_v2.6_extreme.zip) |

---

## 🔧 How it works (v2.6)

| # | Layer | Details |
|---|---|---|
| 1 | Gate bypass | priv-app overlay: the **stock 2.0.5 APK** is placed into `/system/priv-app` (original signature), bypassing the `ro.pxr.externalfunc` check |
| 2 | Privileges | Runs as a system app — privileged permissions fully granted |
| 3 | **Native compat layer** | 2.0.5 needs `getSwiftTrackerInfoVector`, missing from P4 firmware — fixed by patching the system tracking lib (one extra dependency) + a tiny forwarding shim |
| 4 | **Version-switch lifecycle** | Automatically invalidates the PackageManager parse cache (both install and uninstall directions) |
| 5 | Property hygiene | Performance properties written non-persistently; restored on uninstall |

> Full technical notes: [FIX_NOTES_v2.6.md](FIX_NOTES_v2.6.md). History (v2.0–v2.3): [FIX_NOTES.md](FIX_NOTES.md).

---

## ✅ Verified (real device)

- PICO 4 A8110 / PUI 5.13.7 / Magisk, 3 Motion Trackers
- **v2.4 → v2.6 upgrade**: version auto-updated, app opens, all 3 trackers detected
- **v2.6 uninstall**: version falls back to 2.0.4, stock app works, zero residue
- **Cross-flash**: Standard ⇄ Performance ⇄ EXTREME verified both ways
- Tracker firmware sv1.89 / sv1.91 both verified working

---

## ❓ FAQ

**Q: Tracker list is empty?**
Fixed in v2.6. If it still happens, open an issue with `adb logcat | grep -E "Swift205Shim|devices:"`.

**Q: Version number wrong / app won't open after switching?**
Handled automatically since v2.6 (self-healing on every boot).

**Q: "illegal signature" popup from the store?**
Since v2.4 the module uses the stock APK — no test-signature issues. Just install v2.6.

**Q: 1st-gen trackers (DK / 1.0)?**
This project targets 2nd-gen trackers. For gen-1: Settings → Tracker version → 1.0.

**Q: Breaks after system OTA?**
Expected — re-flash the module ZIP and reboot.

**Q: 5-point mode?**
Needs 5 trackers; not fully tested with 5 units (system-level evidence shows 5 slots supported).

**Q: Can I downgrade to an older module version?**
Yes — flash any older ZIP (v2.6 handles the cache automatically).

---

## 📄 Docs & version history

- [RELEASE_NOTES_v2.6.md](RELEASE_NOTES_v2.6.md) — v2.6 release notes
- [FIX_NOTES_v2.6.md](FIX_NOTES_v2.6.md) — full v2.4–v2.6 technical notes
- [FIX_NOTES.md](FIX_NOTES.md) — v2.0–v2.3 reverse-engineering log (historical)
- [RELEASE_NOTES.md](RELEASE_NOTES.md) — v2.3 release notes (historical)

## 🔗 Related projects

- **[pico4-tracker-firmware](https://github.com/hhhbwc/pico4-tracker-firmware)** — PICO Motion Tracker firmware update/downgrade toolkit

---

For learning & research only. Community project, not affiliated with PICO.
