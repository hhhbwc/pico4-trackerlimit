package com.picoxr.trackerlimit;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

import com.picoxr.trackerlimit.hook.BindLambda3Hook;
import com.picoxr.trackerlimit.hook.ConnectedMaxSizeHook;
import com.picoxr.trackerlimit.hook.CreateBindTrackerHook;
import com.picoxr.trackerlimit.hook.DeviceSizeChangedHook;
import com.picoxr.trackerlimit.hook.DlgBindLambda2Hook;
import com.picoxr.trackerlimit.hook.ShowLimitPopup;
import com.picoxr.trackerlimit.hook.SwiftUpperLimit;

/**
 * Lets the PICO Swift tracker limit be switched between 2 / 3 / 5 instead of
 * the stock 2 / 3.
 *
 * The limit itself is just a config string ("com.pvr.swift.upper.limit") that
 * SwiftImpl reads back and hands to the native pairing calls, so raising it
 * needs no native patching. What blocks it are UI-side checks compiled with
 * the literal 2, which are handled individually:
 *
 *   1. SwiftSettingFragment.showLimitTogglePopup() -> rebuilt with 3 entries
 *   2. SwiftImpl.getSwiftUpperLimit()              -> clamped, not forced
 *   3. SwiftDataSource.MAX_TRACKER_SIZE            -> raised to the max option
 *   4. ConnectableTrackerAdapter / ConnectDlgTrackerAdapter view holders
 *      -> "limit reached" checks compared against the live limit
 */
public class TrackerLimit implements IXposedHookLoadPackage {

    public static final String TAG = "PicoTrackerLimit";

    public static final int STOCK_TRACKER_LIMIT = 2;
    public static final int HARD_CEILING = 10;
    /** Options offered in Settings. Override with persist.pico.tracker.options=2,3,5 */
    public static final String PROP_OPTIONS = "persist.pico.tracker.options";
    private static final int[] DEFAULT_OPTIONS = { 2, 3, 5 };

    public static int[] getOptions() {
        String raw = getProp(PROP_OPTIONS);
        if (raw == null || raw.trim().isEmpty()) return DEFAULT_OPTIONS;
        try {
            String[] parts = raw.split(",");
            java.util.TreeSet<Integer> set = new java.util.TreeSet<>();
            for (String p : parts) {
                int v = Integer.parseInt(p.trim());
                if (v >= STOCK_TRACKER_LIMIT && v <= HARD_CEILING) set.add(v);
            }
            if (set.isEmpty()) return DEFAULT_OPTIONS;
            int[] out = new int[set.size()];
            int i = 0;
            for (Integer v : set) out[i++] = v;
            return out;
        } catch (Throwable t) {
            return DEFAULT_OPTIONS;
        }
    }

    public static int getMaxTrackerLimit() {
        int[] o = getOptions();
        return o[o.length - 1];
    }

    private static String getProp(String key) {
        try {
            Class<?> sp = Class.forName("android.os.SystemProperties");
            java.lang.reflect.Method m = sp.getMethod("get", String.class, String.class);
            return (String) m.invoke(null, key, "");
        } catch (Throwable t) {
            return null;
        }
    }

    private static final ThreadLocal<Boolean> RESOLVING = new ThreadLocal<>();

    /**
     * Resolves the live upper limit from the SwiftRepo singleton.
     *
     * Must only be called from UI callbacks, never from handleLoadPackage:
     * SwiftRepo pulls in Utils.<clinit>, which calls back into the class
     * loader and dies if it runs while the loader is still being created.
     *
     * The re-entry guard keeps us from looping when this is reached from
     * inside the getSwiftUpperLimit hook itself.
     */
    public static int resolveLimit(ClassLoader cl) {
        if (Boolean.TRUE.equals(RESOLVING.get())) return STOCK_TRACKER_LIMIT;
        RESOLVING.set(Boolean.TRUE);
        try {
            Class<?> repoCls = cl.loadClass("com.pvr.swift.data.SwiftRepo");
            Object companion = XposedHelpers.getStaticObjectField(repoCls, "Companion");
            Object repo = XposedHelpers.callMethod(companion, "getInstance");
            Object v = XposedHelpers.callMethod(repo, "getSwiftUpperLimit");
            if (v instanceof Integer) return (Integer) v;
        } catch (Throwable ignored) {
        } finally {
            RESOLVING.remove();
        }
        return STOCK_TRACKER_LIMIT;
    }

    /**
     * Counts trackers in the connected state, mirroring what
     * SwiftVM.isConnectedDeviceMaxSize() computes into a local before its
     * hardcoded `>= 3` comparison.
     */
    public static int countConnected(Object vm) throws Throwable {
        Object devicesLd = XposedHelpers.callMethod(vm, "getDevices");
        Object list = XposedHelpers.callMethod(devicesLd, "d"); // LiveData.getValue()
        if (!(list instanceof Iterable)) return 0;
        int n = 0;
        for (Object dev : (Iterable<?>) list) {
            if (dev == null) continue;
            Object state = XposedHelpers.callMethod(dev, "getConnectState");
            if (state instanceof Integer && (Integer) state == 1) n++;
        }
        return n;
    }

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lp) throws Throwable {
        if (lp.packageName == null) return;
        if (!"com.pvr.swift".equals(lp.packageName)) return;

        final ClassLoader cl = lp.classLoader;
        final int[] options = getOptions();
        final int max = getMaxTrackerLimit();

        // 1. Settings popup: 2 / 3 / 5 instead of 2 / 3.
        try {
            Class<?> frag = XposedHelpers.findClass(
                    "com.pvr.swift.fragment.SwiftSettingFragment", cl);
            XposedHelpers.findAndHookMethod(frag, "showLimitTogglePopup",
                    new ShowLimitPopup(cl));
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": showLimitTogglePopup hook failed");
            XposedBridge.log(t);
        }

        // 1b. Main page: restore the "pair another" button past 3 trackers.
        // SwiftMainFragment gates it behind an inlined `size < 3`, so the
        // visibility has to be corrected after the method runs.
        try {
            Class<?> mainFrag = XposedHelpers.findClass(
                    "com.pvr.swift.fragment.SwiftMainFragment", cl);
            XposedHelpers.findAndHookMethod(mainFrag, "updateDeviceSizeChanged",
                    new DeviceSizeChangedHook(cl));
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": updateDeviceSizeChanged hook failed");
            XposedBridge.log(t);
        }

        // 1c. SwiftVM.isConnectedDeviceMaxSize() ends in a hardcoded `>= 3`.
        try {
            Class<?> vmCls = XposedHelpers.findClass(
                    "com.pvr.swift.data.SwiftVM", cl);
            XposedHelpers.findAndHookMethod(vmCls, "isConnectedDeviceMaxSize",
                    new ConnectedMaxSizeHook(cl));
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": isConnectedDeviceMaxSize hook failed");
            XposedBridge.log(t);
        }

        // 2. Clamp the getter into range (does not force a fixed value).
        try {
            Class<?> swiftImpl = XposedHelpers.findClass(
                    "com.pvr.swift.sdk.SwiftImpl", cl);
            XposedHelpers.findAndHookMethod(swiftImpl, "getSwiftUpperLimit",
                    new SwiftUpperLimit());
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": getSwiftUpperLimit hook failed");
            XposedBridge.log(t);
        }

        // 3. Static ceiling used by the data source. Deferred: touching the
        // class during handleLoadPackage would force it to initialise too early.
        try {
            Class<?> ds = XposedHelpers.findClass(
                    "com.pvr.swift.datasource.SwiftDataSource", cl);
            XposedHelpers.findAndHookMethod(ds, "getBondedDevices", new XC_MethodHook() {
                private boolean done;
                @Override
                protected void beforeHookedMethod(MethodHookParam param) {
                    if (done) return;
                    done = true;
                    try {
                        XposedHelpers.setStaticIntField(
                                param.thisObject.getClass(), "MAX_TRACKER_SIZE", max);
                    } catch (Throwable t) {
                        XposedBridge.log(TAG + ": MAX_TRACKER_SIZE set failed");
                        XposedBridge.log(t);
                    }
                }
            });
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": SwiftDataSource hook failed");
            XposedBridge.log(t);
        }

        // 4. Adapter-side "limit reached" gates.
        try {
            Class<?> vh = XposedHelpers.findClass(
                    "com.pvr.swift.adapter.ConnectableTrackerAdapter$ConnectableTrackerViewHolder",
                    cl);
            XposedHelpers.findAndHookMethod(vh, "bind$lambda-3",
                    vh, android.view.View.class, new BindLambda3Hook(cl));
            XposedHelpers.findAndHookMethod(vh, "createBindTracker",
                    new CreateBindTrackerHook(cl));
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": ConnectableTrackerAdapter hook failed");
            XposedBridge.log(t);
        }

        try {
            Class<?> vh2 = XposedHelpers.findClass(
                    "com.pvr.swift.adapter.ConnectDlgTrackerAdapter$ConnectableTrackerViewHolder",
                    cl);
            XposedHelpers.findAndHookMethod(vh2, "bind$lambda-2",
                    int.class, vh2, android.view.View.class, new DlgBindLambda2Hook(cl));
            XposedHelpers.findAndHookMethod(vh2, "createBindTracker",
                    new CreateBindTrackerHook(cl));
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": ConnectDlgTrackerAdapter hook failed");
            XposedBridge.log(t);
        }

        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < options.length; i++) {
            if (i > 0) sb.append('/');
            sb.append(options[i]);
        }
        // NOTE: never touch the app's own classes here. handleLoadPackage runs
        // while the class loader is still being built, and calling into
        // SwiftRepo at this point triggers Utils.<clinit> -> Utils.app() ->
        // createOrUpdateClassLoaderLocked re-entrancy and crashes the process.
        XposedBridge.log(TAG + ": installed (options=" + sb + ", max=" + max + ")");
    }
}
