package com.picoxr.trackerlimit.hook;

import java.util.List;

import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;

import com.picoxr.trackerlimit.TrackerLimit;

/**
 * ConnectableTrackerAdapter$ConnectableTrackerViewHolder.createBindTracker():
 *
 *   if (bondedDevices.size() < 2) { stopScanImmediately(); createBond(); }   // inlined 2
 *
 * The literal 2 sits inside the method body, so the only way to lift it is to
 * make the size check see a smaller number. We temporarily swap the data
 * source's bonded-device list for a shorter one while the original method
 * runs, then restore it immediately afterwards.
 *
 * The swap is skipped once the user's real limit is reached, so the stock
 * guard still fires at the configured maximum.
 */
public class CreateBindTrackerHook extends XC_MethodHook {

    private final ClassLoader cl;
    private static final ThreadLocal<Object[]> SAVED = new ThreadLocal<>();

    public CreateBindTrackerHook(ClassLoader cl) {
        this.cl = cl;
    }

    @Override
    protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
        SAVED.remove();
        try {
            Object holder = param.thisObject;
            Object repository = XposedHelpers.getObjectField(holder, "mSwiftRepository");
            if (repository == null) return;

            Object ds = XposedHelpers.getObjectField(repository, "mSwiftDataSource");
            if (ds == null) return;

            Object bonded = XposedHelpers.callMethod(repository, "getBondedDevices");
            int paired = (bonded instanceof List) ? ((List<?>) bonded).size() : 0;

            int limit = TrackerLimit.resolveLimit(cl);
            if (paired < TrackerLimit.STOCK_TRACKER_LIMIT) {
                // Under the stock threshold: original logic already works.
                return;
            }
            if (paired >= limit) {
                // Genuinely at the user's limit: let the stock guard stop it.
                return;
            }

            // Find the field holding the bonded list and shrink it for the
            // duration of the call so the inlined "< 2" test passes.
            java.lang.reflect.Field target = null;
            for (java.lang.reflect.Field f : ds.getClass().getDeclaredFields()) {
                if (!List.class.isAssignableFrom(f.getType())) continue;
                f.setAccessible(true);
                Object val = f.get(ds);
                if (val == bonded) {
                    target = f;
                    break;
                }
            }
            if (target == null) return;

            target.set(ds, new java.util.ArrayList<>());
            SAVED.set(new Object[] { ds, target, bonded });
        } catch (Throwable t) {
            XposedBridge.log(TrackerLimit.TAG + ": createBindTracker pre failed");
            XposedBridge.log(t);
        }
    }

    @Override
    protected void afterHookedMethod(MethodHookParam param) throws Throwable {
        Object[] saved = SAVED.get();
        SAVED.remove();
        if (saved == null) return;
        try {
            java.lang.reflect.Field f = (java.lang.reflect.Field) saved[1];
            f.set(saved[0], saved[2]);
        } catch (Throwable t) {
            XposedBridge.log(TrackerLimit.TAG + ": createBindTracker restore failed");
            XposedBridge.log(t);
        }
    }
}
