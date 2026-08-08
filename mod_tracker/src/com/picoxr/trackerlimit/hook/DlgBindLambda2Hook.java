package com.picoxr.trackerlimit.hook;

import de.robv.android.xposed.XC_MethodHook;

import com.picoxr.trackerlimit.TrackerLimit;

/**
 * ConnectDlgTrackerAdapter:
 *   bind$lambda-2(int count, holder, view) -> if (count >= 2) skip createBindTracker()
 *
 * The comparison constant is inlined, so we rewrite the incoming count: report
 * 0 while the user is still under their configured limit, and pass the real
 * value through once the limit is actually reached.
 */
public class DlgBindLambda2Hook extends XC_MethodHook {

    private final ClassLoader cl;

    public DlgBindLambda2Hook(ClassLoader cl) {
        this.cl = cl;
    }

    @Override
    protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
        if (!(param.args[0] instanceof Integer)) return;
        int count = (Integer) param.args[0];
        int limit = TrackerLimit.resolveLimit(cl);
        if (count < limit) {
            param.args[0] = Integer.valueOf(0);
        }
    }
}
