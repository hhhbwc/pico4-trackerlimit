> ⚠️ **Maintenance status**: This project can no longer be tested or maintained — I sold my PICO Motion Trackers and switched to Rebocap.
> Existing releases still install and work as documented, but there is no on-device verification behind them any more, so I cannot validate or fix new compatibility issues.

🌐 [简体中文](README.md) | English | [Русский](README_RU.md)

# PICO 4 Motion Tracker Unlock (2.0.5)

Full unlock of the PICO Motion Tracker app **2.0.5** for the **PICO 4 standard edition** (A8110 / Phoenix, ROM 5.13.x).
The app is enabled via a **Magisk module**: **tracker detection works, and install / upgrade / uninstall are fully reliable**. Zero system partition modifications — uninstall restores stock.

> 📦 Download: [Releases](../../releases) → **v2.9.1** (`PICO4_MotionTracker_v2.9.1.zip`: fully automatic KarlVis/DirectTouch compatibility + cleanup of v2.0–v2.2 leftovers; keeps the v2.8 library-isolation fix)
> 🔧 Requirements: Magisk 27+, PICO 4 standard edition (or other 4-series devices behind the same gates)

---

## ❌ About 5-point full-body tracking (real-world test verdict, stated up front)

**Not supported in practice — sorry to everyone who was waiting for it.**

The connection layer is indeed open: 5 trackers pair, and the app lets you pick the 5-point tier.
But **full-body solving does not work** — the stock BODYPOSE algorithm of the standard edition lacks
the 5-point forearm / knee neural network models (`e2e_*_8_*`), and the Ultra 1.0.0.54 algorithm as
a replacement is unverified. Full 5-point capture on the standard edition is currently a dead end —
**use 2 / 3 points**.

The module is still genuinely useful:

- full unlock of Motion Tracker 2.0.5 on the standard edition (stock APK, stock signature, gates bypassed)
- 2 / 3-point mode switching, pairing / calibration / device listing all work
- per user feedback it solves real problems: trackers dropping in games (e.g. VRChat),
  recalibration pop-ups interrupting use
- automatically compatible with KarlVis/DirectTouch — the boundary confirm button stops going dead

---

## 🆕 v2.9.1: fix for "boundary confirm button not clickable" (conflict with KarlVis/DirectTouch, fully automatic)

**User report**: on v2.0, the in-game boundary-confirmation / recalibration window cannot be
confirmed — the pointer hover circle never appears; both controller and hand tracking fail;
first boot after install is fine, then it reproduces after any reboot.

**Real conflict point (confirmed by reverse-engineering KarlVis O1.13.7S)**: KarlVis's DirectTouch
is an LSPosed module (`com.picodirecttouch.lsposed`) that injects a native library into
`com.picoxr.xrshell` and interposes (proxy/orig) the engine's **ray update (rayProxy)** and
**cursor / hover-circle update (cursorProxy)** plus the panel-manager sync. Only panels in its
registry get normal pointer interaction; the tracker boundary/recalibration panel (PvrSwift's
VSTPanel app layer) is not in it → no hover circle, button unclickable. Without the tracker
module the panel never appears; without KarlVis the engine's original hit-testing covers all
layers — the conflict needs both. "First boot fine, broken after reboot" = LSPosed hooks activate
after reboot. Full analysis: [RELEASE_NOTES_v2.9.md](RELEASE_NOTES_v2.9.md).

| Change | Details |
|---|---|
| 🤖 **Automatic DirectTouch compatibility (v2.9.1)** | a boot-started watcher (`dt_compat.sh`; exits immediately if KarlVis is absent, zero overhead): when the boundary panel appears it temporarily sets `persist.dt.enable 0` (DirectTouch stands down), auto-restoring afterwards; if the panel hangs 120s with a game in the foreground it auto-dismisses the panel (**in-game tracking is not interrupted**). **No manual clicks needed** |
| 🧹 **Upgrade cleanup** | removes the `key_mod_wear_mode` / `key_mod_upper_limit` prefs from the patched-APK era; also eliminates the v2.0 patched-APK side effect (background discovery held ON — the stock APK keeps all guards) |
| 🛟 **Rescue + diagnostics (fallback)** | Magisk "Action" button = immediate rescue + `/sdcard/pico4_diag_*.log` dump (incl. a DirectTouch/lspd section) |
| 🔒 Architecture unchanged | stock PICO-signed APK + priv-app private lib dir (v2.8 route) |

> **v2.0 / v2.1 / v2.2 users**: flash v2.9.1 over the existing module (same module id, no
> uninstall needed, bonds kept).
> ✅ The watcher state machine was verified end-to-end on the author's device (A8110 / 5.13.7);
> whether DirectTouch reads `persist.dt.enable` live still needs confirmation on a KarlVis device
> (the author's device runs a different XRShell build — installing KarlVis there risks a crash),
> but there is a fallback path (auto-dismiss of the hung panel). Neither path needs manual action.
> The "dock window follows head rotation" issue = Pico2Dock (it replaces the system dock
> `com.pvr.shortcut`) × KarlVis (DockHook) — unrelated to this module.

---

## 🛑 v2.7 users: upgrade to v2.8 ASAP (black screen risk)

**v2.7 has a critical flaw**: the native compat libraries are mounted at the global path `/system/lib64/`.
**Every** process that loads trackingclient — including `com.pico.xr.openxr_runtime` — gets the shim pulled in,
causing an OpenXR SIGBUS crash loop → tombstones pile up (447 measured) → system_server crashes → **black screen** (forced reboot only).

**v2.8 fix**: the libraries now live in `/system/priv-app/PvrSwift/lib/arm64/` (priv-app private nativeLibraryDir).
Only the tracker app sees them; the OpenXR runtime keeps using the stock system library.
Verified on device: **0 tombstones, 3 trackers enumerated, app opens normally**.
Overlay-install v2.8 over v2.7 — no uninstall needed. The APK is back to the unmodified, PICO-signed original, and auto-unbond has been removed (manual commands in [RELEASE_NOTES_v2.8.md](RELEASE_NOTES_v2.8.md)).

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

## 🆕 v2.8.1

- 🎛️ Optional experimental add-on `pico4_algo_tuning_v0.1.1.zip`: re-encrypted .cpt runtime configs — solver threads pinned to big cores (cpu4-7), RT prio 8/5, 200Hz, n_iter 20. Controller untouched. Independent rollback.
- 📄 [CPT_FORMAT.md](CPT_FORMAT.md): .cpt binary format spec + a real crash-loop postmortem. The service fails by **crash-looping, not degrading** — read before writing any .cpt tool.

## ✨ What gets unlocked

| Capability | Stock (standard edition) | After unlock |
|---|---|---|
| Motion Tracker 2.0.5 app | "Device not supported, please upgrade" | Fully working (**stock APK, original signature, zero modifications**) |
| Tracker detection | — | ✅ List / connect / calibrate |
| Privileged permissions | Unobtainable (signature mismatch) | Full priv-app grant |
| Tracker count | 2 or 3 (fixed by wear mode) | 2 / 3 work; ❌ 5-point is NOT supported in practice (see above) |
| 5-point (forearm / knee) | Ultra-only tier | ❌ **Not supported in practice**: pairing works, full-body solve does not (see section above) |

---

## 📥 Install / Upgrade / Uninstall

### Install
1. Make sure you're rooted (Magisk 27+)
2. Magisk → Modules → Install from storage → pick the ZIP
3. Reboot
4. Open the "Motion Tracker" app

> **Two tracker modules cannot coexist.** If the old `pico4_swift205_libpreload` (v2.0.0) is present, the installer in the current source aborts (this guard ships in the published `v2.8.2` ZIP). Remove it first (`touch /data/adb/modules/pico4_swift205_libpreload/remove`, reboot), then flash this ZIP. Both modules overlay the same `PvrSwift` APK/libs, and uninstalling one deletes the other's nativeLibraryDir.

### Upgrade (from any old version, incl. old Performance/EXTREME)
Just flash the v2.8.2 ZIP over it (**no uninstall needed**); takes effect after reboot, tracker bonds are kept, legacy tuning properties are restored.

### Uninstall
Remove the module in Magisk → reboot. The system partition was never touched; stock 2.0.4 is restored automatically.

| Build | Notes | Download |
|---|---|---|
| ✅ **v2.8.2 (recommended)** | Library isolation + duplicate-module guard; 0-crash device verified | [`PICO4_MotionTracker_v2.8.2.zip`](../../releases/download/v2.8.2/PICO4_MotionTracker_v2.8.2.zip) |
| v2.8 | Library isolation fix (no duplicate-module guard) | [`PICO4_MotionTracker_v2.8.zip`](../../releases/download/v2.8/PICO4_MotionTracker_v2.8.zip) |
| ⚠️ v2.7 (legacy) | Compat libraries on the global path — **black-screen risk, do not install** | [Releases](../../releases/tag/v2.7) |

The optional tuning add-on ships separately from v2.8.1 as `pico4_algo_tuning_v0.1.1.zip`.

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

**Q: Does 5-point full-body capture work?**
**No. Real-world verdict (2026-11, multiple users): not supported.** Pairing and the 5-point tier in
the app work, but the body solve does not — the stock algorithm lacks forearm / knee models, and the
Ultra algorithm swap is unverified. Use **2 / 3 points**. Apologies again to everyone who wanted
5-point specifically — but unlocking 2.0.5 and stable, non-dropping trackers on the standard edition
are real, working value of this module.

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
