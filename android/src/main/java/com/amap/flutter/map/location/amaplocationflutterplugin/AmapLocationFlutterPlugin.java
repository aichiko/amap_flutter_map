package com.amap.flutter.map.location.amaplocationflutterplugin;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.text.TextUtils;
import android.util.ArrayMap;

import com.amap.api.location.AMapLocationClient;
import com.amap.api.maps.model.LatLng;
import com.amap.flutter.map.location.amaplocationflutterplugin.AMapLocationClientImpl;

import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * 高德地图定位sdkFlutterPlugin
 */
public class AmapLocationFlutterPlugin implements MethodCallHandler,
        EventChannel.StreamHandler,
        FlutterPlugin {

    private static final String CHANNEL_METHOD_LOCATION = "amap_location_flutter_plugin";
    private static final String CHANNEL_STREAM_LOCATION = "amap_location_flutter_plugin_stream";

    private static final String CHANNEL_METHOD_UTILITY = "amap_utility_flutter";


    private Context mContext = null;

    public static EventChannel.EventSink mEventSink = null;


    private Map<String, AMapLocationClientImpl> locationClientMap = new HashMap<String, AMapLocationClientImpl>(10);

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        String callMethod = call.method;
        switch (call.method) {
            case "setApiKey":
                setApiKey((Map) call.arguments);
                break;
            case "setLocationOption":
                setLocationOption((Map) call.arguments);
                break;
            case "startLocation":
                startLocation((Map) call.arguments);
                break;
            case "stopLocation":
                stopLocation((Map) call.arguments);
                break;
            case "destroy":
                destroy((Map) call.arguments);
                break;
            default:
                result.notImplemented();
                break;

        }
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        mEventSink = eventSink;
    }

    @Override
    public void onCancel(Object o) {
        for (Map.Entry<String, AMapLocationClientImpl> entry : locationClientMap.entrySet()) {
            entry.getValue().stopLocation();
        }
    }

    /**
     * 开始定位
     */
    private void startLocation(Map argsMap) {
        if (null == locationClientMap) {
            locationClientMap = new HashMap<String, AMapLocationClientImpl>(10);
        }

        String pluginKey = getPluginKeyFromArgs(argsMap);
        if (TextUtils.isEmpty(pluginKey)) {
            return;
        }

        AMapLocationClientImpl locationClientImp;
        if (!locationClientMap.containsKey(pluginKey)) {
            locationClientImp = new AMapLocationClientImpl(mContext, pluginKey, mEventSink);
            locationClientMap.put(pluginKey, locationClientImp);
        } else {
            locationClientImp = getLocationClientImp(argsMap);
        }

        if (null != locationClientImp) {
            locationClientImp.startLocation();
        }
    }


    /**
     * 停止定位
     */
    private void stopLocation(Map argsMap) {
        AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
        if (null != locationClientImp) {
            locationClientImp.stopLocation();
        }
    }

    /**
     * 销毁
     *
     * @param argsMap
     */
    private void destroy(Map argsMap) {
        AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
        if (null != locationClientImp) {
            locationClientImp.destroy();
        }
    }

    /**
     * 设置apikey
     *
     * @param apiKeyMap
     */
    private void setApiKey(Map apiKeyMap) {
        if (null != apiKeyMap) {
            if (apiKeyMap.containsKey("android")
                    && !TextUtils.isEmpty((String) apiKeyMap.get("android"))) {
                AMapLocationClient.setApiKey((String) apiKeyMap.get("android"));
            }
        }
    }

    /**
     * 设置定位参数
     *
     * @param argsMap
     */
    private void setLocationOption(Map argsMap) {
        AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
        if (null != locationClientImp) {
            locationClientImp.setLocationOption(argsMap);
        }
    }

    /**
     * 获取当前运行的activity
     */
    public static Activity getTopActivity() {
        try {
            Class activityThreadClass = Class.forName("android.app.ActivityThread");
            Object activityThread = activityThreadClass.getMethod("currentActivityThread").invoke(null);
            Field activitiesField = activityThreadClass.getDeclaredField("mActivities");
            activitiesField.setAccessible(true);
            //16~18 HashMap
            //19~27 ArrayMap
            Map<Object, Object> activities;
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
                activities = (HashMap<Object, Object>) activitiesField.get(activityThread);
            } else {
                activities = (ArrayMap<Object, Object>) activitiesField.get(activityThread);
            }
            if (activities.size() < 1) {
                return null;
            }
            for (Object activityRecord : activities.values()) {
                Class activityRecordClass = activityRecord.getClass();
                Field pausedField = activityRecordClass.getDeclaredField("paused");
                pausedField.setAccessible(true);
                if (!pausedField.getBoolean(activityRecord)) {
                    Field activityField = activityRecordClass.getDeclaredField("activity");
                    activityField.setAccessible(true);
                    Activity activity = (Activity) activityField.get(activityRecord);
                    return activity;
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        if (null == mContext) {
            mContext = binding.getApplicationContext();

            /**
             * 方法调用通道
             */
            final MethodChannel channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_METHOD_LOCATION);
            channel.setMethodCallHandler(this);

            /**
             * 工具方法调用通道
             */
            final MethodChannel utilty_channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_METHOD_UTILITY);
            utilty_channel.setMethodCallHandler(new MethodCallHandler() {
                @Override
                public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
                    String callMethod = call.method;
                    switch (callMethod) {
                        case "map#openAMapRouteSearch":
                            // 调起高德地图app进行路径规划.
                            Map routeMap = (Map) call.arguments;
                            if (null != routeMap) {
                                String appScheme = routeMap.get("appScheme").toString();
                                String appName = routeMap.get("appName").toString();
                                int drivingStrategy = Integer.parseInt(routeMap.get("drivingStrategy").toString());
                                int transitStrategy = Integer.parseInt(routeMap.get("transitStrategy").toString());

                                int routeType = Integer.parseInt(routeMap.get("routeType").toString());

                                List<Double> start_latLng = (List<Double>) routeMap.get("startCoordinate");
                                List<Double> destination_latLng = (List<Double>) routeMap.get("destinationCoordinate");

                                if (start_latLng == null || start_latLng.size() == 0) {
                                    result.success(false);
                                    return;
                                }

                                if (destination_latLng == null || destination_latLng.size() == 0) {
                                    result.success(false);
                                    return;
                                }

                                LatLng startCoordinate = new LatLng(start_latLng.get(0), start_latLng.get(1));
                                LatLng destinationCoordinate = new LatLng(destination_latLng.get(0), destination_latLng.get(1));

                                if (startCoordinate.latitude == 0 && startCoordinate.longitude == 0) {
                                    result.success(false);
                                    return;
                                }

                                if (destinationCoordinate.latitude == 0 && destinationCoordinate.longitude == 0) {
                                    result.success(false);
                                    return;
                                }

                                Intent intent = new Intent();
                                intent.setAction(Intent.ACTION_VIEW);
                                intent.addCategory(Intent.CATEGORY_DEFAULT);


                                //将功能Scheme以URI的方式传入data
                                String mapUrl = "amapuri://route/plan/?sourceApplication=" + appName;

                                mapUrl += "&slat=" + startCoordinate.latitude + "&slon=" + startCoordinate.longitude;
                                mapUrl += "&dlat=" + destinationCoordinate.latitude + "&dlon=" + destinationCoordinate.longitude;
                                mapUrl += "&dev=0";
                                mapUrl += "&t=" + routeType;

                                Uri uri = Uri.parse(mapUrl);
                                intent.setData(uri);
                                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                //启动该页面即可
                                mContext.startActivity(intent);

                                result.success(true);
                                return;
                            }
                            result.notImplemented();
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                }
            });

            /**
             * 回调监听通道
             */
            final EventChannel eventChannel = new EventChannel(binding.getBinaryMessenger(), CHANNEL_STREAM_LOCATION);
            eventChannel.setStreamHandler(this);
        }

    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        for (Map.Entry<String, AMapLocationClientImpl> entry : locationClientMap.entrySet()) {
            entry.getValue().destroy();
        }
    }

    private AMapLocationClientImpl getLocationClientImp(Map argsMap) {
        if (null == locationClientMap || locationClientMap.size() <= 0) {
            return null;
        }
        String pluginKey = null;
        if (null != argsMap) {
            pluginKey = (String) argsMap.get("pluginKey");
        }
        if (TextUtils.isEmpty(pluginKey)) {
            return null;
        }

        return locationClientMap.get(pluginKey);
    }

    private String getPluginKeyFromArgs(Map argsMap) {
        String pluginKey = null;
        try {
            if (null != argsMap) {
                pluginKey = (String) argsMap.get("pluginKey");
            }
        } catch (Throwable e) {
            e.printStackTrace();
        }
        return pluginKey;
    }


}
