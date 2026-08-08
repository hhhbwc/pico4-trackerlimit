package com.picoxr.trackerlimit.hook;

import java.util.List;

import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;

import com.picoxr.trackerlimit.TrackerLimit;

/**
 * ConnectableTrackerAdapter$ConnectableTrackerViewHolder.bind$lambda-3:
 *
 *   if (bondedDevices.size() >= 2) { showToast(); }   // inlined 2
 *
 * This lambda only shows the "limit reached" toast; the real pairing entry is
 * bind$lambda-0. While the paired count is still under the user's configured
 * limit we route the click to bind$lambda-0 instead, and once the limit is
 * genuinely reached we let the original toast run.
 */
public class BindLambda3Hook extends XC_MethodHook {

    private final ClassLoader cl;

    public BindLambda3Hook(ClassLoader cl) {
        this.cl = cl;
    }

    @Override
    protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
        try {
            Object holder = param.args[0];
            int paired = pairedCount(holder);
            int limit = TrackerLimit.resolveLimit(cl);

            if (paired >= limit) {
                return; // at the real limit, keep stock behaviour
            }

            Class<?> cls = holder.getClass();
            java.lang.reflect.Method lambda0 =
                    cls.getDeclaredMethod("bind$lambda-0", cls, android.view.View.class);
            lambda0.setAccessible(true);
            lambda0.invoke(null, param.args[0], param.args[1]);
            param.setResult(null);
        } catch (Throwable t) {
            XposedBridge.log(TrackerLimit.TAG + ": bind$lambda-3 redirect failed");
            XposedBridge.log(t);
        }
    }

    static int pairedCount(Object holder) {
        try {
            Object repository = XposedHelpers.getObjectField(holder, "mSwiftRepository");
            if (repository == null) return 0;
            Object devices = XposedHelpers.callMethod(repository, "getBondedDevices");
            if (devices instanceof List) return ((List<?>) devices).size();
        } catch (Throwable ignored) {
        }
        return 0;
    }
}
