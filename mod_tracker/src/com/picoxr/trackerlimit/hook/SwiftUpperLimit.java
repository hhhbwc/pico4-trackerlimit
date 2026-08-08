package com.picoxr.trackerlimit.hook;

import de.robv.android.xposed.XC_MethodHook;

import com.picoxr.trackerlimit.TrackerLimit;

/**
 * SwiftImpl.getSwiftUpperLimit() reads "com.pvr.swift.upper.limit" from config
 * and falls back to 2. We do NOT force a fixed value here any more: the user
 * picks 2 / 3 / 5 in Settings and that choice must be honoured.
 *
 * We only clamp the result into the allowed range, so a stale or corrupt config
 * value cannot push it past what we support.
 */
public class SwiftUpperLimit extends XC_MethodHook {
    @Override
    protected void afterHookedMethod(MethodHookParam param) throws Throwable {
        Object r = param.getResult();
        if (!(r instanceof Integer)) return;
        int v = (Integer) r;
        int clamped = v;
        if (clamped < TrackerLimit.STOCK_TRACKER_LIMIT) clamped = TrackerLimit.STOCK_TRACKER_LIMIT;
        if (clamped > TrackerLimit.getMaxTrackerLimit()) clamped = TrackerLimit.getMaxTrackerLimit();
        if (clamped != v) {
            param.setResult(clamped);
        }
    }
}
