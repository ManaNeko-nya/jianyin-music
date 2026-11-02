package com.uniucy.music;

import android.content.Context;
import android.content.res.Configuration;
import android.util.Log;

import ohos.ace.adapter.capability.bridge.BridgePlugin;

/** ArkTS 与 Android 的平台桥：后台播放服务、状态同步与媒体按键回调。 */
public class AppBridgePlugin extends BridgePlugin {
    private static final String TAG = "JianYinBridge";
    public static volatile AppBridgePlugin instance;

    private final Context context;

    public AppBridgePlugin(Context context, String name, int instanceId) {
        super(context, name, instanceId);
        this.context = context.getApplicationContext();
        instance = this;
    }

    public boolean isSystemDark() {
        int mode = context.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
        return mode == Configuration.UI_MODE_NIGHT_YES;
    }

    public String setBars(boolean lightContent) {
        MainActivity activity = MainActivity.current;
        if (activity == null) {
            return "no-activity";
        }
        activity.applySystemBars(lightContent);
        return "ok";
    }

    public String startMedia() {
        MediaService.start(context);
        return "ok";
    }

    public String stopMedia() {
        MediaService.stop(context);
        return "ok";
    }

    public String updateMedia(String json) {
        MediaService.update(context, json);
        return "ok";
    }

    /** 服务/通知/媒体按键 -> ArkTS。 */
    public static void dispatch(String action, long position) {
        AppBridgePlugin plugin = instance;
        if (plugin == null) {
            return;
        }
        try {
            plugin.callMethod("onMediaAction", action, (double) position);
        } catch (Throwable t) {
            Log.w(TAG, "dispatch failed: " + action, t);
        }
    }
}
