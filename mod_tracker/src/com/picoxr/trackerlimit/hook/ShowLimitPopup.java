package com.picoxr.trackerlimit.hook;

import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

import de.robv.android.xposed.XC_MethodReplacement;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;

import com.picoxr.trackerlimit.TrackerLimit;

/**
 * Replaces SwiftSettingFragment.showLimitTogglePopup().
 *
 * The stock method builds a two-entry popup (2 and 3 trackers) and marks the
 * current one with `getSwiftUpperLimit() != 3 ? 0 : 1`. We rebuild the same
 * popup with the options from TrackerLimit.getOptions() (default 2 / 3 / 5)
 * and install our own click listener.
 *
 * Everything is done reflectively against the app's own classes so we do not
 * need its resources at build time.
 */
public class ShowLimitPopup extends XC_MethodReplacement {

    private final ClassLoader cl;

    public ShowLimitPopup(ClassLoader cl) {
        this.cl = cl;
    }

    @Override
    protected Object replaceHookedMethod(MethodHookParam param) throws Throwable {
        Object frag = param.thisObject;
        try {
            build(frag);
        } catch (Throwable t) {
            XposedBridge.log(TrackerLimit.TAG + ": showLimitTogglePopup replacement failed");
            XposedBridge.log(t);
            // Fall back to the original implementation on any failure.
            return XposedBridge.invokeOriginalMethod(param.method, param.thisObject, param.args);
        }
        return null;
    }

    private void build(Object frag) throws Throwable {
        final int[] options = TrackerLimit.getOptions();

        Object repo = XposedHelpers.getObjectField(frag, "repo");
        int current = (Integer) XposedHelpers.callMethod(repo, "getSwiftUpperLimit");

        android.content.Context ctx =
                (android.content.Context) XposedHelpers.callMethod(frag, "getContext");
        android.content.res.Resources res =
                (android.content.res.Resources) XposedHelpers.callMethod(frag, "getResources");

        // R.plurals.swift2_setting_limit_count / R.drawable.ic_swift_right /
        // R.color.color_bfffffff, resolved by name so we do not hardcode ids.
        String pkg = ctx.getPackageName();
        int pluralId = res.getIdentifier("swift2_setting_limit_count", "plurals", pkg);
        int iconId = res.getIdentifier("ic_swift_right", "drawable", pkg);
        int colorId = res.getIdentifier("color_bfffffff", "color", pkg);

        // s5.a item(s5.b.TYPE_TITLE_CHECK)
        //
        // s5.b is an enum whose constant names are obfuscated in the real dex,
        // so a by-name lookup throws NoSuchFieldError. Each constant carries
        // the layout it inflates, so identify the right one by resolving
        // R.layout.osui_item_title_check and matching that id.
        Class<?> itemCls = cl.loadClass("s5.a");
        Class<?> typeCls = cl.loadClass("s5.b");
        Object typeTitleCheck = resolveTitleCheck(typeCls, res, pkg);
        Constructor<?> itemCtor = itemCls.getDeclaredConstructor(typeCls);
        itemCtor.setAccessible(true);

        // Same story for the item fields: match them by type and by their
        // declared defaults instead of the names jadx invented.
        //   f9351b CharSequence title
        //   f9352c int  titleColor, defaults to 0
        //   f9353d int  iconRes,    defaults to -1
        //   f9354e int  titleRes,   defaults to -1
        Object probe = itemCtor.newInstance(typeTitleCheck);
        Field fTitle = null, fColor = null, fIcon = null;
        for (Field f : itemCls.getDeclaredFields()) {
            if (java.lang.reflect.Modifier.isStatic(f.getModifiers())) continue;
            f.setAccessible(true);
            if (CharSequence.class.isAssignableFrom(f.getType())) {
                if (fTitle == null) fTitle = f;
            } else if (f.getType() == int.class) {
                int def = f.getInt(probe);
                if (def == 0) {
                    if (fColor == null) fColor = f;
                } else if (def == -1) {
                    // iconRes is declared before titleRes
                    if (fIcon == null) fIcon = f;
                }
            }
        }
        if (fTitle == null || fColor == null || fIcon == null) {
            throw new NoSuchFieldException("s5.a layout changed");
        }

        int color = colorId != 0 ? ctx.getColor(colorId) : 0xBFFFFFFF;
        // getView() treats -1 as "no icon", so keep that sentinel if the
        // drawable could not be resolved.
        int icon = iconId != 0 ? iconId : -1;

        List<Object> items = new ArrayList<>();
        int checked = 0;
        for (int i = 0; i < options.length; i++) {
            int n = options[i];
            Object item = itemCtor.newInstance(typeTitleCheck);
            String label = pluralId != 0
                    ? res.getQuantityString(pluralId, n, n)
                    : String.valueOf(n);
            fTitle.set(item, label);
            fColor.set(item, color);
            fIcon.set(item, icon);
            items.add(item);
            if (n == current) checked = i;
        }

        // s5.d adapter(Context, List)
        Class<?> adapterCls = cl.loadClass("s5.d");
        Constructor<?> adapterCtor =
                adapterCls.getDeclaredConstructor(android.content.Context.class, List.class);
        adapterCtor.setAccessible(true);
        Object adapter = adapterCtor.newInstance(ctx, items);

        Object activity = XposedHelpers.callMethod(frag, "requireActivity");
        Object binding = XposedHelpers.getObjectField(frag, "binding");
        Object anchor = XposedHelpers.getObjectField(binding, "swiftSettingLimit");

        Object listener = makeListener(frag, options);

        Class<?> helperCls = cl.loadClass("com.pvr.swift.utils.PopupMenuHelper");
        Method show = null;
        for (Method m : helperCls.getDeclaredMethods()) {
            if ("showListPopup".equals(m.getName()) && m.getParameterTypes().length == 5) {
                show = m;
                break;
            }
        }
        if (show == null) throw new NoSuchMethodException("showListPopup");
        show.setAccessible(true);

        Object popup = show.invoke(null, activity, anchor, adapter, listener, checked);
        XposedHelpers.setObjectField(frag, "togglePopup", popup);
    }

    /**
     * Picks the TYPE_TITLE_CHECK constant out of the obfuscated s5.b enum.
     *
     * Tries three things in order: the declared name (in case it survived),
     * the layout id each constant stores, and finally the known ordinal.
     */
    private Object resolveTitleCheck(Class<?> typeCls,
                                     android.content.res.Resources res,
                                     String pkg) throws Throwable {
        Object[] values = (Object[]) typeCls.getMethod("values").invoke(null);

        for (Object v : values) {
            if ("TYPE_TITLE_CHECK".equals(((Enum<?>) v).name())) return v;
        }

        int layoutId = res.getIdentifier("osui_item_title_check", "layout", pkg);
        if (layoutId != 0) {
            for (Object v : values) {
                for (Field f : typeCls.getDeclaredFields()) {
                    if (java.lang.reflect.Modifier.isStatic(f.getModifiers())) continue;
                    if (f.getType() != int.class) continue;
                    f.setAccessible(true);
                    if (f.getInt(v) == layoutId) return v;
                }
            }
        }

        // Declaration order: DIVIDER, TITLE, TITLE_CHECK, ...
        if (values.length > 2) return values[2];
        throw new NoSuchFieldException("s5.b#TYPE_TITLE_CHECK");
    }

    /** AdapterView.OnItemClickListener that applies the picked limit. */
    private Object makeListener(final Object frag, final int[] options) throws Throwable {
        Class<?> listenerCls = cl.loadClass("android.widget.AdapterView$OnItemClickListener");
        return java.lang.reflect.Proxy.newProxyInstance(
                cl,
                new Class<?>[] { listenerCls },
                new java.lang.reflect.InvocationHandler() {
                    @Override
                    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
                        if (!"onItemClick".equals(method.getName())) {
                            if ("hashCode".equals(method.getName())) return System.identityHashCode(proxy);
                            if ("equals".equals(method.getName())) return proxy == args[0];
                            if ("toString".equals(method.getName())) return "PicoLimitListener";
                            return null;
                        }
                        int position = (Integer) args[2];
                        try {
                            // Mirror the stock guard against double taps.
                            if (args[1] != null && isFastClick(args[1])) return null;
                            apply(frag, options, position);
                        } catch (Throwable t) {
                            XposedBridge.log(TrackerLimit.TAG + ": limit apply failed");
                            XposedBridge.log(t);
                        }
                        return null;
                    }
                });
    }

    private void apply(Object frag, int[] options, int position) throws Throwable {
        Object popup = XposedHelpers.getObjectField(frag, "togglePopup");
        if (popup != null) {
            XposedHelpers.callMethod(popup, "dismiss");
        }
        if (position < 0 || position >= options.length) return;

        int target = options[position];
        Object repo = XposedHelpers.getObjectField(frag, "repo");
        int current = (Integer) XposedHelpers.callMethod(repo, "getSwiftUpperLimit");
        if (current == target) return;

        // Lowering the limit below the number of paired trackers would leave
        // orphaned devices, which is exactly what the stock "unpair first"
        // dialog guards against. Keep that behaviour.
        Object devicesObj = XposedHelpers.callMethod(repo, "getDevices");
        int paired = (devicesObj instanceof List) ? ((List<?>) devicesObj).size() : 0;
        if (target < paired) {
            toast(frag, "请先解绑多余的追踪器（当前已配对 " + paired + " 个）");
            return;
        }

        XposedHelpers.callMethod(repo, "setSwiftUpperLimit", target);
        int now = (Integer) XposedHelpers.callMethod(repo, "getSwiftUpperLimit");

        // Refresh the summary text under the settings row.
        try {
            Object binding = XposedHelpers.getObjectField(frag, "binding");
            Object tv = XposedHelpers.getObjectField(binding, "swiftSettingLimitText");
            android.content.res.Resources res =
                    (android.content.res.Resources) XposedHelpers.callMethod(frag, "getResources");
            android.content.Context ctx =
                    (android.content.Context) XposedHelpers.callMethod(frag, "getContext");
            int pluralId = res.getIdentifier("swift2_setting_limit_count", "plurals",
                    ctx.getPackageName());
            String label = pluralId != 0
                    ? res.getQuantityString(pluralId, now, now)
                    : String.valueOf(now);
            XposedHelpers.callMethod(tv, "setText", label);
        } catch (Throwable ignored) {
        }

        // Nudge the view model so dependent UI refreshes, using the live
        // device count the way the stock listener does.
        try {
            Object vm = XposedHelpers.callMethod(frag, "getVm");
            Object changed = XposedHelpers.callMethod(vm, "getDevicesSizeChanged");
            Object nowDevices = XposedHelpers.callMethod(repo, "getDevices");
            Integer size = (nowDevices instanceof List)
                    ? Integer.valueOf(((List<?>) nowDevices).size()) : null;
            XposedHelpers.callMethod(changed, "k", size);
        } catch (Throwable ignored) {
        }

        XposedBridge.log(TrackerLimit.TAG + ": upper limit " + current + " -> " + now);
    }

    private boolean isFastClick(Object view) {
        try {
            Class<?> viewKt = cl.loadClass("com.pvr.swift.extra.ViewKt");
            Object r = XposedHelpers.callStaticMethod(viewKt, "isFastClick", view);
            return (r instanceof Boolean) && (Boolean) r;
        } catch (Throwable t) {
            return false;
        }
    }

    private void toast(Object frag, String msg) {
        try {
            android.content.Context ctx =
                    (android.content.Context) XposedHelpers.callMethod(frag, "getContext");
            if (ctx == null) return;
            Class<?> toastCls = cl.loadClass("android.widget.Toast");
            Object t = XposedHelpers.callStaticMethod(toastCls, "makeText",
                    ctx, (CharSequence) msg, 1);
            XposedHelpers.callMethod(t, "show");
        } catch (Throwable ignored) {
        }
    }
}
