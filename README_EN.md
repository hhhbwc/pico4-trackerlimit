🌐 [简体中文](README.md) | English | [Русский](README_RU.md)

# PICO 4 Motion Tracker Unlock (2.0.5)

Full unlock of the PICO Motion Tracker app **2.0.5** for the **PICO 4 standard edition** (A8110 / Phoenix, CN ROM 5.13.7).
The Ultra edition's "Motion Tracker 2.0.5" app is fully ported via a **Magisk module**, with **2 / 3 / 5-point tracking mode switching**. Zero system partition modifications — uninstall restores everything.

> 📦 Download: [Releases](../../releases) → `PICO4_MotionTracker_2.0.5_v2.0.zip`
> 🔧 Requirements: Magisk 27+, PICO 4 (standard edition / other 4-series devices locked by the same gates)

---

## ✨ What gets unlocked

| Capability | Stock (standard edition) | After unlock |
|---|---|---|
| Motion Tracker 2.0.5 app | "Device not supported, please upgrade" | Fully working |
| Tracker pairing limit | 2 or 3 (fixed by wear mode) | **2 / 3 / 5, switchable in-app** |
| Privileged permissions | Unobtainable (signature mismatch) | Full priv-app grant |
| 5-point (5tk_thigh) | Ultra-only tier | Unlocked at system level (see below) |

---

## 📥 Install

1. Make sure you are rooted (Magisk 27+)
2. Magisk → Modules → Install from storage → `PICO4_MotionTracker_2.0.5_v2.0.zip`
3. Reboot
4. Open the "Motion Tracker" app: scan & pair → wear calibration → go

## 🗑️ Uninstall

Remove the module in Magisk → reboot. The system partition is never touched, everything reverts to stock.

---

## 🔄 Mode switching (2 / 3 / 5-point)

- **Settings → Tracker limit**: choose 3 or 5 (if more devices are already bonded than the target, a stock "unpair first" confirmation appears)
- **Wear mode page**: switch 2-point (2tk) / 3-point (3tk_waist) / 5-point (5tk_thigh); confirming **automatically syncs the pairing limit** (2pt→2, 3pt→3, 5pt→5)
- All switches take effect immediately, no dependency on PICO config service write access

> ⚠️ **Note: I only have 3 trackers, so pairing 5 could not be tested.**
> System-level evidence (MCU `tracker_num=5`, Stationservice working with 5 slots) suggests 5-point is feasible,
> but a fully-populated 5-tracker setup has not been verified on real hardware. If you hit issues pairing beyond the 3rd tracker, open an issue with logcat attached.

---

## 🧩 How it works: why so many layers

The app refuses to run on the standard edition because of **five stacked gates**:

| # | Layer | Stock behavior | Fix |
|---|---|---|---|
| 1 | Product-tier gate | `ro.pxr.externalfunc=0` → app reports "device not supported" | priv-app overlay + forced checks |
| 2 | Privileged permissions | Test-signed /data install can't get `SWIFT_ACCESS` etc. (signature\|privileged) | Magisk overlay to `/system/priv-app`, permissions granted via "or" logic |
| 3 | Native compat | 2.0.5 `libswift.so` requires the `getSwiftTrackerInfoVector` export missing on P4 → garbage data straight to JNI → `negative array length` crash loop | Corresponding vtable call path disabled |
| 4 | Device enumeration | Enumeration unusable, device list always empty, calibration unreachable | Device list rebuilt from system `statusChangedCallback` |
| 5 | Mode switching | PICO config service rejects app writes to system keys (wear mode stuck at 5-point, limit stuck at 5) | In-app override, immediate effect |

Also: the discovery switch used for pairing was ignored due to the app's power/foreground-visibility checks — now forced on
(that was the direct cause of "tapped scan, nothing happened").

The full reverse-engineering story — smali changes, ARM64 binary patches and the crash-chain analysis — is in
[FIX_NOTES.md](FIX_NOTES.md) (including the complete anatomy of `negative array length: -954437177`).

---

## 🆚 Old approach (LSPosed / Zygisk hook) comparison

This repo originally hosted an LSPosed hook solution (removed in v2.0):

| | LSPosed hook (old) | Magisk priv-app overlay (new) |
|---|---|---|
| Approach | Runtime hooks intercepting checks | App replacement + binary patches |
| Crash risk | High (ClassLoader re-entry at handleLoadPackage → crash loop; method-body hardcoded checks unreachable by hooks) | No hooks, changes baked into the APK |
| Permissions | Priv-app privileges still unobtainable | ✅ Fully granted |
| Native layer | Not covered (Xposed can't hook native) | ✅ Patched directly |
| Dependencies | Zygisk Vector framework | Magisk only |
| Maintenance | Every offset change requires code edits | Re-flash module after OTA |

---

## ❓ FAQ

**Q: Tapped scan, nothing happens?**
Make sure the app is 2.0.5 and the module is installed (rebooted). v2.0 force-enables discovery;
if it still fails, attach logcat filtered by `SwiftRepo|TrackingClient` to an issue.

**Q: Tracker disconnects seconds after successful pairing?**
Log shows `reason: tracker_power_off` while all HMD-side settings are correct —
that's tracker-side firmware trouble (usually after unbinding a tracker while it was online).
**Put it on the charging dock for a few minutes or factory-reset it**, then pair again.

**Q: Does 5-point work?**
All software gates are open. But 5-point needs 5 trackers — I only have 3, so pairing 5 could not be tested.

**Q: Broken after a system OTA?**
Expected. The Magisk overlay needs the module re-flashed and a reboot after OTA.

---

## 📦 Checksums (v2.0)

```
MD5:    3f8c378bc7e705e28fb1551a4789dd44
SHA256: 42be4bb94919cfa5ea8db4549c14bd8966df363e82020331222993c1c9f81fe5
```

## 📄 Docs

- [RELEASE_NOTES.md](RELEASE_NOTES.md) — v2.0 release notes
- [FIX_NOTES.md](FIX_NOTES.md) — full reverse-engineering & troubleshooting log

For study and research only. Please support the original developers.

---

## ❓ More FAQ
**Q: App keeps waiting for "DK trackers"?**
DK (Developer Kit) is the product name of the 2.0 trackers — the 2.0.5 app runs in 2.0 mode by default.
If you own the **1st-generation PICO Motion Tracker** (the Bluetooth-pairing one), go to
Settings → Tracker Version → switch to **1.0** (unbind all paired trackers first).

**Q: Switching to 2.0 fails ("version toggle failed")?**
Unbind ALL paired trackers in the app first, then switch. If it still fails, run
`adb shell setprop persist.pxr.tracking.swiftVersion 2` as root, restart the app and try again,
and open an issue with `getprop persist.pxr.tracking.swiftVersion`, `ro.pxr.support.swiftversion` and logcat.

**Q: PICO Store pops "Verification failed: illegal signature" and asks to buy?**
Expected — the modified APK uses a test signature, not the store signature. Dismiss it.
**Do NOT** buy/restore the store version — that would overwrite the unlock.
