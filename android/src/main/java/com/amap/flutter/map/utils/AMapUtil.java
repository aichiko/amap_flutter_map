package com.amap.flutter.map.utils;

import com.amap.api.maps.AMapUtils;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.LatLngBounds;

import java.util.List;

public class AMapUtil {

    /**
     * 计算原始轨迹长度
     * @param points
     */
    public static float calculateOriginDistance(List<LatLng> points) {
        float totalDistance = 0f;
        for(int var9 = 0; var9 < points.size() - 1; ++var9) {
            double var11 = (double) AMapUtils.calculateLineDistance(points.get(var9), points.get(var9 + 1));
            totalDistance += var11;
        }
        return totalDistance;
    }

    /**
     * 计算点集合的范围
     * @param pointList
     * @return
     */
    public static LatLngBounds getBounds(List<LatLng> pointList) {
        LatLngBounds.Builder b = LatLngBounds.builder();
        if (pointList == null) {
            return b.build();
        }
        for (int i = 0; i < pointList.size(); i++) {
            b.include(pointList.get(i));
        }
        return b.build();
    }
}
