package com.amap.flutter.map.utils;

/**
 * @author whm
 * @date 2020/11/10 9:44 PM
 * @mail hongming.whm@alibaba-inc.com
 * @since
 */
public class Const {
    /**
     * map
     */
    public static final String METHOD_MAP_WAIT_FOR_MAP = "map#waitForMap";
    public static final String METHOD_MAP_CONTENT_APPROVAL_NUMBER = "map#contentApprovalNumber";
    public static final String METHOD_MAP_SATELLITE_IMAGE_APPROVAL_NUMBER = "map#satelliteImageApprovalNumber";
    public static final String METHOD_MAP_UPDATE = "map#update";
    public static final String METHOD_MAP_MOVE_CAMERA = "camera#move";
    public static final String METHOD_MAP_SET_RENDER_FPS = "map#setRenderFps";
    public static final String METHOD_MAP_TAKE_SNAPSHOT = "map#takeSnapshot";
    public static final String METHOD_MAP_CLEAR_DISK = "map#clearDisk";

    public static final String[] METHOD_ID_LIST_FOR_MAP = {
            METHOD_MAP_CONTENT_APPROVAL_NUMBER,
            METHOD_MAP_SATELLITE_IMAGE_APPROVAL_NUMBER,
            METHOD_MAP_WAIT_FOR_MAP,
            METHOD_MAP_UPDATE,
            METHOD_MAP_MOVE_CAMERA,
            METHOD_MAP_SET_RENDER_FPS,
            METHOD_MAP_TAKE_SNAPSHOT,
            METHOD_MAP_CLEAR_DISK};


    /**
     * markers
     */
    public static final String METHOD_MARKER_UPDATE = "markers#update";
    public static final String METHOD_MARKER_SET_TRACK_DATA = "markers#setTrackData";
    public static final String METHOD_MARKER_ANIMATED = "markers#animated";
    public static final String METHOD_MARKER_STOP_ANIMATED = "markers#stopAnimated";
    public static final String[] METHOD_ID_LIST_FOR_MARKER = {METHOD_MARKER_UPDATE, METHOD_MARKER_SET_TRACK_DATA, METHOD_MARKER_ANIMATED, METHOD_MARKER_STOP_ANIMATED};

    /**
     * polygons
     */
    public static final String METHOD_POLYGON_UPDATE = "polygons#update";
    public static final String[] METHOD_ID_LIST_FOR_POLYGON = {METHOD_POLYGON_UPDATE};

    /**
     * polylines
     */
    public static final String METHOD_POLYLINE_UPDATE = "polylines#update";
    public static final String[] METHOD_ID_LIST_FOR_POLYLINE = {METHOD_POLYLINE_UPDATE};

    /**
     * clusters
     */
    public static final String METHOD_CLUSTER_UPDATE = "clusters#update";
    public static final String[] METHOD_ID_LIST_FOR_CLUSTER = {METHOD_CLUSTER_UPDATE};

}
