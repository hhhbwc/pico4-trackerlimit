package de.robv.android.xposed;
public final class XposedBridge {
    public static XC_MethodHook.Unhook findAndHookMethod(Class<?> clazz, String methodName, Object... parameterTypesAndCallback) { return null; }
    public static XC_MethodHook.Unhook findAndHookMethod(String className, ClassLoader classLoader, String methodName, Object... parameterTypesAndCallback) { return null; }
    public static java.util.Set<XC_MethodHook.Unhook> hookAllMethods(Class<?> hookClass, String methodName, XC_MethodHook callback) { return null; }
    public static void log(String text) {}
    public static void log(Throwable t) {}
    public static Object invokeOriginalMethod(java.lang.reflect.Member method, Object thisObject, Object[] args) throws Throwable { return null; }
    public static class Unhook {
        public void unhook() {}
    }
}
