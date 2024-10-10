package com.amap.flutter.map.utils;

import android.os.Looper;

import io.flutter.plugin.common.MethodChannel;

import android.os.Handler;

import java.util.Map;

public class MainThreadCallback {
    private Handler handler;

    public void callback(final MethodChannel methodChannel, final String invokeMethod, final Map<String, Object> data) {
        if (handler == null) {
            handler = new Handler(Looper.getMainLooper());
        }
        handler.post(
                new Runnable() {
                    @Override
                    public void run() {
                        methodChannel.invokeMethod(invokeMethod, data);
                    }
                });
    }
}