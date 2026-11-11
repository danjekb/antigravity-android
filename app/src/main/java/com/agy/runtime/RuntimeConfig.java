package com.agy.runtime;

import android.content.Context;

import com.agy.BuildConfig;

/** App-level constants sourced from the generated BuildConfig. */
public final class RuntimeConfig {
    private static final String TAG = "RuntimeConfig";
    public static final int DEFAULT_HTTPS_PORT = BuildConfig.PORT;
    public static final String CORE_VERSION = BuildConfig.CORE_VERSION;
    public static final String APP_VERSION_NAME = BuildConfig.APP_VERSION_NAME;
    public static final int APP_VERSION_CODE = BuildConfig.APP_VERSION_CODE;
    public static final int MIN_API = BuildConfig.MIN_API;
    public static final int TARGET_SDK = BuildConfig.TARGET_SDK;
    public static final boolean DEBUG = BuildConfig.DEBUG;

    private static volatile int resolvedHttpsPort = 0;

    private RuntimeConfig() {
    }

    /** The port from res/values/gen.xml, else the BuildConfig default, with automatic conflict resolution. */
    public static synchronized int httpsPort(Context appContext) {
        if (resolvedHttpsPort > 0) {
            return resolvedHttpsPort;
        }

        int basePort = DEFAULT_HTTPS_PORT;
        if (appContext != null) {
            try {
                int resId = appContext.getResources().getIdentifier(
                        "https_server_port", "integer", appContext.getPackageName());
                if (resId != 0) {
                    basePort = appContext.getResources().getInteger(resId);
                }
            } catch (Exception ignored) {
            }
        }

        int candidate = basePort;
        for (int i = 0; i < 10; i++) {
            if (isPortAvailable(candidate)) {
                resolvedHttpsPort = candidate;
                if (candidate != basePort) {
                    android.util.Log.i(TAG, "Base port " + basePort + " in use; selected fallback port " + candidate);
                }
                return resolvedHttpsPort;
            }
            candidate++;
        }

        resolvedHttpsPort = basePort;
        return resolvedHttpsPort;
    }

    private static boolean isPortAvailable(int port) {
        try (java.net.ServerSocket ss = new java.net.ServerSocket()) {
            ss.setReuseAddress(true);
            ss.bind(new java.net.InetSocketAddress(java.net.InetAddress.getByName("127.0.0.1"), port), 1);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
