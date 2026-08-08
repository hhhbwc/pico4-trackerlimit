package com.picoxr.trackerlimit.hook;

import com.picoxr.trackerlimit.TrackerLimit;

import de.robv.android.xposed.XC_MethodHook;

/**
 * SwiftVM.isConnectedDeviceMaxSize() ends in a hardcoded `return i10 >= 3`,
 * where i10 counts the connected trackers. Callers use it to decide whether
 * the "max reached" state applies, so with the limit raised it reports
 * saturation too early.
 *
 * The count is a local, so recompute the comparison from the result: the
 * stock value tells us whether i10 >= 3, but not i10 itself. Instead of
 * guessing, re-derive the count the same way the original does and compare it
 * against the live limit.
 */
public class ConnectedMaxSizeHook extends XC_MethodHook {

    private final ClassLoader cl;

    public ConnectedMaxSizeHook(ClassLoader cl) {
        this.cl = cl;
    }

    @Override
    protected void afterHookedMethod(MethodHookParam param) throws Throwable {
        // Only ever relax the result: if stock says "not full", it is not full.
        if (!Boolean.TRUE.equals(param.getResult())) return;

        try {
            int connected = TrackerLimit.countConnected(param.thisObject);
            int limit = TrackerLimit.resolveLimit(cl);
            param.setResult(connected >= limit);
        } catch (Throwable ignored) {
            // Leave the stock result in place on any failure.
        }
    }
}
