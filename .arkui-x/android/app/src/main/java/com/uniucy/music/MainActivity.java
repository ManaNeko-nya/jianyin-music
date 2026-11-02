package com.uniucy.music;

import android.Manifest;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Insets;
import android.os.Build;
import android.os.Bundle;
import android.util.DisplayMetrics;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowMetrics;

import java.io.File;
import java.io.FileWriter;

import ohos.stage.ability.adapter.StageActivity;

public class MainActivity extends StageActivity {
    public static MainActivity current;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        current = this;
        writeInsets();
        setInstanceName("com.uniucy.music:entry:EntryAbility:");
        super.onCreate(savedInstanceState);
        new AppBridgePlugin(this, "AppBridge", getInstanceId());
        requestNotificationPermission();
    }

    public void applySystemBars(boolean lightContent) {
        runOnUiThread(() -> {
            Window window = getWindow();
            View decor = window.getDecorView();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                WindowInsetsController controller = decor.getWindowInsetsController();
                if (controller != null) {
                    int mask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                        | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
                    controller.setSystemBarsAppearance(lightContent ? 0 : mask, mask);
                }
            } else {
                int flags = decor.getSystemUiVisibility();
                int light = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                    | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
                decor.setSystemUiVisibility(lightContent ? (flags & ~light) : (flags | light));
            }
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
        });
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33
            && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] { Manifest.permission.POST_NOTIFICATIONS }, 11);
        }
    }

    /** ArkUI-X 的 window.getWindowAvoidArea 在 Android 返回 0，这里把真实安全区交给 ArkTS。 */
    private void writeInsets() {
        try {
            int top;
            int bottom;
            int left;
            int right;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                WindowMetrics metrics = getWindowManager().getCurrentWindowMetrics();
                WindowInsets insets = metrics.getWindowInsets();
                Insets bars = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
                top = bars.top;
                bottom = bars.bottom;
                left = bars.left;
                right = bars.right;
            } else {
                top = dimen("status_bar_height");
                bottom = dimen("navigation_bar_height");
                left = 0;
                right = 0;
            }
            DisplayMetrics dm = getResources().getDisplayMetrics();
            File dir = new File(getFilesDir(), "files");
            dir.mkdirs();
            try (FileWriter writer = new FileWriter(new File(dir, "insets.txt"))) {
                writer.write("top=" + top + ";bottom=" + bottom + ";left=" + left + ";right=" + right
                    + ";density=" + dm.density + ";");
            }
        } catch (Throwable ignored) {
        }
    }

    private int dimen(String name) {
        int id = getResources().getIdentifier(name, "dimen", "android");
        return id > 0 ? getResources().getDimensionPixelSize(id) : 0;
    }
}
