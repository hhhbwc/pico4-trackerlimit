package com.picoxr.trackerlimit.hook;

import com.picoxr.trackerlimit.TrackerLimit;

import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;

import java.lang.reflect.Proxy;
import java.util.Collection;

/**
 * Restores the "pair another tracker" button once more than 3 trackers are
 * allowed.
 *
 * SwiftMainFragment.updateDeviceSizeChanged() decides the button visibility
 * inside a hardcoded branch:
 *
 *   if (1 <= size && size < 3) {          // <- literal 3, not the upper limit
 *       ...
 *       bind.setVisibility(size < repo.getSwiftUpperLimit() ? VISIBLE : GONE);
 *       bind.setOnClickListener(new s(this, 6));
 *       return;
 *   }
 *   ...
 *   binding.swiftMainDeviceBind.setVisibility(GONE);   // tail, always hides
 *
 * With 3 paired trackers the guarded branch is skipped entirely and execution
 * falls through to the tail that unconditionally hides the button, so raising
 * the limit alone has no visible effect.
 *
 * The literal 3 is inlined, so it cannot be rewritten. Instead let the method
 * run untouched and fix up the result afterwards: if the live limit still has
 * room, make the button visible again and attach the same pairing action the
 * stock code would have used.
 */
public class DeviceSizeChangedHook extends XC_MethodHook {

    private final ClassLoader cl;

    public DeviceSizeChangedHook(ClassLoader cl) {
        this.cl = cl;
    }

    @Override
    protected void afterHookedMethod(MethodHookParam param) throws Throwable {
        try {
            Object frag = param.thisObject;

            int size = currentDeviceCount(frag);
            int limit = TrackerLimit.resolveLimit(cl);

            // Stock behaviour already covers everything below 3; only step in
            // where the hardcoded branch stopped applying.
            if (size < 3 || size >= limit) return;
            // Mid-pairing the stock code shows a spinner instead of the
            // button. Leave that state alone.
            Object vm = XposedHelpers.callMethod(frag, "getVm");
            Object pairing = XposedHelpers.callMethod(vm, "isPairing");
            if (pairing instanceof Boolean && (Boolean) pairing) return;

            Object binding = XposedHelpers.getObjectField(frag, "binding");
            if (binding == null) return;
            Object bind = XposedHelpers.getObjectField(binding, "swiftMainDeviceBind");
            if (bind == null) return;

            XposedHelpers.callMethod(bind, "setVisibility", 0); // View.VISIBLE
            XposedHelpers.callMethod(bind, "setOnClickListener", pairListener(frag));
            XposedBridge.log(TrackerLimit.TAG + ": bind button restored (size="
                    + size + ", limit=" + limit + ")");
        } catch (Throwable t) {
            XposedBridge.log(TrackerLimit.TAG + ": updateDeviceSizeChanged fixup failed");
            XposedBridge.log(t);
        }
    }

    private int currentDeviceCount(Object frag) throws Throwable {
        Object vm = XposedHelpers.callMethod(frag, "getVm");
        Object devicesLd = XposedHelpers.callMethod(vm, "getDevices");
        Object list = XposedHelpers.callMethod(devicesLd, "d"); // LiveData.getValue()
        if (list instanceof Collection) return ((Collection<?>) list).size();
        return 0;
    }

    /**
     * Rebuilds the stock click action. The original is `new s(this, 6)`, whose
     * case 6 calls the private startPair(String) with "swiftMainDeviceBind";
     * invoke that directly instead of constructing the synthetic class.
     */
    private Object pairListener(final Object frag) throws Throwable {
        Class<?> listenerCls = cl.loadClass("android.view.View$OnClickListener");
        return Proxy.newProxyInstance(
                cl,
                new Class<?>[]{listenerCls},
                (proxy, method, args) -> {
                    if ("onClick".equals(method.getName())) {
                        // startPair(String) is private, so pass the parameter
                        // type explicitly rather than relying on arg matching.
                        XposedHelpers.callMethod(frag, "startPair",
                                new Class<?>[]{String.class}, "swiftMainDeviceBind");
                        return null;
                    }
                    if ("hashCode".equals(method.getName())) return System.identityHashCode(proxy);
                    if ("equals".equals(method.getName())) return proxy == args[0];
                    if ("toString".equals(method.getName())) return "PicoTrackerLimit$PairListener";
                    return null;
                });
    }
}
