package com.amap.flutter.map.overlays.marker;

import android.text.TextUtils;

import androidx.annotation.NonNull;

import com.amap.api.maps.AMap;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.Marker;
import com.amap.api.maps.model.MarkerOptions;
import com.amap.api.maps.model.Poi;
import com.amap.api.maps.utils.overlay.SmoothMoveMarker;
import com.amap.flutter.map.MyMethodCallHandler;
import com.amap.flutter.map.overlays.AbstractOverlayController;
import com.amap.flutter.map.utils.AMapUtil;
import com.amap.flutter.map.utils.Const;
import com.amap.flutter.map.utils.ConvertUtil;
import com.amap.flutter.map.utils.LogUtil;
import com.amap.flutter.map.utils.MainThreadCallback;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * @author whm
 * @date 2020/11/6 5:38 PM
 * @mail hongming.whm@alibaba-inc.com
 * @since
 */
public class MarkersController
        extends AbstractOverlayController<MarkerController>
        implements MyMethodCallHandler,
        AMap.OnMapClickListener,
        AMap.OnMarkerClickListener,
        AMap.OnMarkerDragListener,
        AMap.OnPOIClickListener, SmoothMoveMarker.MoveListener {
    private static final String CLASS_NAME = "MarkersController";
    private String selectedMarkerDartId;
    private AMap aMap;
    private MainThreadCallback mainThreadCallback;

    /**
     * 总轨迹点
     */
    private List<LatLng> totalPoints = new ArrayList<>();
    /**
     * 剩下未播放的点
     */
    private List<LatLng> restPoints = new ArrayList<>();
    /**
     * 总轨迹长度
     */
    private double totalDistance;
    /**
     * 剩下轨迹长度
     */
    private double restDistance;
    /**
     * 总时长
     */
    private int totalDurationTime = 180;
    /**
     * 剩余时长
     */
    private int restDurationTime = 180;

    /**
     * 当前播放点位置
     */
    private int currentPostion;

    private SmoothMoveMarker smoothMoveMarker;
    private int startIndex = -1, endIndex = -1;

    private int currentMultiple = 1;
    private boolean isPlaying = false;

    public MarkersController(MethodChannel methodChannel, AMap amap) {
        super(methodChannel, amap);
        amap.addOnMarkerClickListener(this);
        amap.addOnMarkerDragListener(this);
        amap.addOnMapClickListener(this);
        amap.addOnPOIClickListener(this);
        this.aMap = amap;
        mainThreadCallback = new MainThreadCallback();
    }

    @Override
    public String[] getRegisterMethodIdArray() {
        return Const.METHOD_ID_LIST_FOR_MARKER;
    }

    @Override
    public void doMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        LogUtil.i(CLASS_NAME, "doMethodCall===>" + call.method);
        switch (call.method) {
            case Const.METHOD_MARKER_SET_TRACK_DATA:
                invokeSetTrackDataMarkerOptions(call, result);
                break;
            case Const.METHOD_MARKER_UPDATE:
                invokeMarkerOptions(call, result);
                break;
            case Const.METHOD_MARKER_ANIMATED:
                invokeAnimatedMarkerOptions(call, result);
                break;
            case Const.METHOD_MARKER_STOP_ANIMATED:
                invokeStopAnimatedMarkerOptions(call, result);
                break;
        }
    }

    public void invokeSetTrackDataMarkerOptions(MethodCall methodCall, MethodChannel.Result result) {
        if (null == methodCall) {
            return;
        }
        Object trackData = methodCall.argument("setTrackData");
        final Map<?, ?> data = ConvertUtil.toMap(trackData);
        currentMultiple = ConvertUtil.toInt(data.get("playSpeed"));
        isPlaying = ConvertUtil.toBoolean(data.get("isPlaying"));
        if (totalPoints.size() == 0) {
            totalDurationTime = ConvertUtil.toInt(data.get("totalDurationTime"));
            restDurationTime = totalDurationTime;
            final List<LatLng> points = ConvertUtil.toPoints(data.get("points"));
            if (points != null && points.size() > 0) {
                totalPoints.addAll(points);
                if (restPoints.size() == 0) {
                    restPoints.addAll(totalPoints);
                }
                totalDistance = AMapUtil.calculateOriginDistance(totalPoints);
                aMap.animateCamera(CameraUpdateFactory.newLatLngBounds(AMapUtil.getBounds(totalPoints), 200));
                points.clear();
            }
        }
        Object dartMarkerId = ConvertUtil.getKeyValueFromMapObject(trackData, "marker");
        if (null != dartMarkerId) {
            MarkerController markerController = controllerMapByDartId.get(dartMarkerId);
            if (null != markerController) {
                if (markerController.getMoveMarker() != null) {
                    if (smoothMoveMarker == null) {
                        smoothMoveMarker = markerController.getMoveMarker();
                        smoothMoveMarker.setMoveListener(this);
                    }
                }
            }
        }
        if (isPlaying) {
            playSmooth();
        }
        result.success(null);
    }

    public void invokeAnimatedMarkerOptions(MethodCall methodCall, MethodChannel.Result result) {
        if (null == methodCall) {
            return;
        }
        Object markersToAnimated = methodCall.argument("markersToAnimated");

        Object dartMarkerId = ConvertUtil.getKeyValueFromMapObject(markersToAnimated, "marker");
        if (null != dartMarkerId) {
            MarkerController markerController = controllerMapByDartId.get(dartMarkerId);
            if (null != markerController) {
                if (markerController.getMoveMarker() != null) {
                    if (smoothMoveMarker == null) {
                        smoothMoveMarker = markerController.getMoveMarker();
                    }
//                    final Map<?, ?> data = ConvertUtil.toMap(markersToAnimated);
//                    final List<LatLng> points = ConvertUtil.toPoints(data.get("points"));
                }
            }
        }
        isPlaying = true;
        playSmooth();
        result.success(null);
    }

    public void invokeStopAnimatedMarkerOptions(MethodCall methodCall, MethodChannel.Result result) {
        if (null == methodCall) {
            return;
        }
        isPlaying = false;
        pauseSmooth();
        result.success(null);
    }

    /**
     * 执行主动方法更新marker
     *
     * @param methodCall
     * @param result
     */
    public void invokeMarkerOptions(MethodCall methodCall, MethodChannel.Result result) {
        if (null == methodCall) {
            return;
        }
        Object markersToAdd = methodCall.argument("markersToAdd");
        addByList((List<Object>) markersToAdd);
        Object markersToChange = methodCall.argument("markersToChange");
        updateByList((List<Object>) markersToChange);
        Object markerIdsToRemove = methodCall.argument("markerIdsToRemove");
        removeByIdList((List<Object>) markerIdsToRemove);
        result.success(null);
    }

    public void addByList(List<Object> markersToAdd) {
        if (markersToAdd != null) {
            for (Object markerToAdd : markersToAdd) {
                add(markerToAdd);
            }
        }
    }

    private void add(Object markerObj) {
        if (null != amap) {
            MarkerOptionsBuilder builder = new MarkerOptionsBuilder();
            String dartMarkerId = MarkerUtil.interpretMarkerOptions(markerObj, builder);
            if (!TextUtils.isEmpty(dartMarkerId)) {
                MarkerOptions markerOptions = builder.build();
                if (builder.animated) {
                    // 这个为平滑移动的marker
                    final SmoothMoveMarker moveMarker = new SmoothMoveMarker(amap);
//                    amap.addMarker(markerOptions);
                    moveMarker.setPosition(markerOptions.getPosition());
                    moveMarker.setDescriptor(markerOptions.getIcon());
                    MarkerController markerController = new MarkerController(moveMarker);
                    controllerMapByDartId.put(dartMarkerId, markerController);
                    idMapByOverlyId.put(markerController.getMarkerId(), dartMarkerId);
                } else {
                    final Marker marker = amap.addMarker(markerOptions);
                    Object clickable = ConvertUtil.getKeyValueFromMapObject(markerObj, "clickable");
                    if (null != clickable) {
                        marker.setClickable(ConvertUtil.toBoolean(clickable));
                    }
                    MarkerController markerController = new MarkerController(marker);
                    controllerMapByDartId.put(dartMarkerId, markerController);
                    idMapByOverlyId.put(marker.getId(), dartMarkerId);
                }
            }
        }

    }

    private void updateByList(List<Object> markersToChange) {
        if (markersToChange != null) {
            for (Object markerToChange : markersToChange) {
                update(markerToChange);
            }
        }
    }

    private void update(Object markerToChange) {
        Object dartMarkerId = ConvertUtil.getKeyValueFromMapObject(markerToChange, "id");
        if (null != dartMarkerId) {
            MarkerController markerController = controllerMapByDartId.get(dartMarkerId);
            if (null != markerController) {
                MarkerUtil.interpretMarkerOptions(markerToChange, markerController);
            }
        }
    }


    private void removeByIdList(List<Object> markerIdsToRemove) {
        if (markerIdsToRemove == null) {
            return;
        }
        for (Object rawMarkerId : markerIdsToRemove) {
            if (rawMarkerId == null) {
                continue;
            }
            String markerId = (String) rawMarkerId;
            final MarkerController markerController = controllerMapByDartId.remove(markerId);
            if (markerController != null) {

                idMapByOverlyId.remove(markerController.getMarkerId());
                markerController.remove();
            }
        }
    }

    private void showMarkerInfoWindow(String dartMarkId) {
        MarkerController markerController = controllerMapByDartId.get(dartMarkId);
        if (null != markerController) {
            markerController.showInfoWindow();
        }
    }

    private void hideMarkerInfoWindow(String dartMarkId, LatLng newPosition) {
        if (TextUtils.isEmpty(dartMarkId)) {
            return;
        }
        if (!controllerMapByDartId.containsKey(dartMarkId)) {
            return;
        }
        MarkerController markerController = controllerMapByDartId.get(dartMarkId);
        if (null != markerController) {
            if (null != newPosition && null != markerController.getPosition()) {
                if (markerController.getPosition().equals(newPosition)) {
                    return;
                }
            }
            markerController.hideInfoWindow();
        }
    }

    @Override
    public void onMapClick(LatLng latLng) {
        hideMarkerInfoWindow(selectedMarkerDartId, null);
    }

    @Override
    public boolean onMarkerClick(Marker marker) {
        String dartId = idMapByOverlyId.get(marker.getId());
        if (null == dartId) {
            return false;
        }
        final Map<String, Object> data = new HashMap<>(1);
        data.put("markerId", dartId);
        selectedMarkerDartId = dartId;
        showMarkerInfoWindow(dartId);
        methodChannel.invokeMethod("marker#onTap", data);
        LogUtil.i(CLASS_NAME, "onMarkerClick==>" + data);
        return true;
    }

    @Override
    public void onMarkerDragStart(Marker marker) {

    }

    @Override
    public void onMarkerDrag(Marker marker) {

    }

    @Override
    public void onMarkerDragEnd(Marker marker) {
        String markerId = marker.getId();
        String dartId = idMapByOverlyId.get(markerId);
        LatLng latLng = marker.getPosition();
        if (null == dartId) {
            return;
        }
        final Map<String, Object> data = new HashMap<>(2);
        data.put("markerId", dartId);
        data.put("position", ConvertUtil.latLngToList(latLng));
        methodChannel.invokeMethod("marker#onDragEnd", data);

        LogUtil.i(CLASS_NAME, "onMarkerDragEnd==>" + data);
    }

    @Override
    public void onPOIClick(Poi poi) {
        hideMarkerInfoWindow(selectedMarkerDartId, null != poi ? poi.getCoordinate() : null);
    }

    @Override
    public void move(final double v) {
        if (restPoints != null && restPoints.size() > 0 && currentPostion < totalPoints.size()) {
            restDistance = v;
            if (startIndex == -1) {
                startIndex = smoothMoveMarker.getIndex();
                restPoints.remove(0);
                currentPostion = currentPostion + 1;
            } else {
                endIndex = smoothMoveMarker.getIndex();
                for (int i = 0; i < endIndex - startIndex; i++) {
                    restPoints.remove(0);
                    currentPostion = currentPostion + 1;
                }
                startIndex = endIndex;
            }

            restDurationTime = (int) (totalDurationTime * restDistance / totalDistance);
            LogUtil.i(CLASS_NAME, "restDurationTime==>" + restDurationTime);

            if (mainThreadCallback == null) {
                mainThreadCallback = new MainThreadCallback();
            }
            final Map<String, Object> data = new HashMap<>(2);
            data.put("progress", (int) (100 - v * 100 / totalDistance));
            data.put("position", currentPostion);
            mainThreadCallback.callback(methodChannel, "marker#smoothMoveProgress", data);

            if (v < 1) {
                endSmooth();
            } else {

            }
        }
    }

    /**
     * 播放
     */
    private void playSmooth() {
        if (restPoints.size() == 0) {
            restPoints.addAll(totalPoints);
            restDurationTime = totalDurationTime;
            currentPostion = 0;
        }
        smoothMoveMarker.setPoints(restPoints);
        smoothMoveMarker.setTotalDuration(restDurationTime / currentMultiple);
        if (isPlaying) {
            smoothMoveMarker.startSmoothMove();
        }
    }

    /**
     * 暂停
     */
    private void pauseSmooth() {
        if (smoothMoveMarker != null) {
            smoothMoveMarker.stopMove();
        }
    }

    /**
     * 结束
     */
    private void endSmooth() {
        pauseSmooth();
        restPoints.clear();
        currentPostion = 0;
    }

}
