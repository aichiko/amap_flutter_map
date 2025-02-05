package com.amap.flutter.map.overlays.cluster;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.Message;
import android.text.Layout;
import android.text.TextUtils;
import android.util.Log;
import android.util.LruCache;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONObject;
import com.amap.api.maps.AMap;
import com.amap.api.maps.AMapUtils;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.model.CameraPosition;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.LatLngBounds;
import com.amap.api.maps.model.Marker;
import com.amap.api.maps.model.MarkerOptions;
import com.amap.api.maps.model.animation.AlphaAnimation;
import com.amap.api.maps.model.animation.Animation;
import com.amap.flutter.amap_flutter_map.R;
import com.amap.flutter.map.MyMethodCallHandler;
import com.amap.flutter.map.overlays.AbstractOverlayController;
import com.amap.flutter.map.utils.Const;
import com.amap.flutter.map.utils.ConvertUtil;
import com.amap.flutter.map.utils.LogUtil;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import androidx.annotation.NonNull;

import io.flutter.plugin.common.JSONUtil;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;


/**
 * Created by yiyi.qi on 16/10/10.
 * 整体设计采用了两个线程,一个线程用于计算组织聚合数据,一个线程负责处理Marker相关操作
 */
public class ClustersController
        extends AbstractOverlayController<ClusterController>
        implements AMap.OnCameraChangeListener,
        ClusterRender,
        MyMethodCallHandler,
        AMap.OnMarkerClickListener {
    private AMap mAMap;
    private Context mContext;
    private List<ClusterOptionsSink> mClusterItems;
    private List<ClusterController> mClusters;
    private int mClusterSize;
    private ClusterClickListener mClusterClickListener;
    private ClusterRender mClusterRender;
    private List<Marker> mAddMarkers = new ArrayList<Marker>();
    private double mClusterDistance;
    private LruCache<String, BitmapDescriptor> mLruCache;
    private HandlerThread mMarkerHandlerThread = new HandlerThread("addMarker");
    private HandlerThread mSignClusterThread = new HandlerThread("calculateCluster");
    private Handler mMarkerhandler;
    private Handler mSignClusterHandler;
    private float mPXInMeters;
    private boolean mIsCanceled = false;

    private int radius = 80;
    private int clusterRadius = 100;

    private static final String CLASS_NAME = "ClustersController";

    private Map<String, Drawable> mBackDrawAbles = new HashMap<String, Drawable>();

    /**
     * 构造函数
     *
     * @param methodChannel
     * @param amap
     */
    public ClustersController(MethodChannel methodChannel, AMap amap, Context context) {
        super(methodChannel, amap);
        mClusterRender = this;
        mContext = context;
        mClusters = new ArrayList<ClusterController>();
        mClusterItems = new ArrayList<ClusterOptionsSink>();
        //默认最多会缓存80张图片作为聚合显示元素图片,根据自己显示需求和app使用内存情况,可以修改数量
        mLruCache = new LruCache<String, BitmapDescriptor>(80) {
            protected void entryRemoved(boolean evicted, Integer key, BitmapDescriptor oldValue, BitmapDescriptor newValue) {
                reycleBitmap(oldValue.getBitmap());
            }
        };
        this.mAMap = amap;
        mClusterSize = dp2px(mContext, clusterRadius);
        mPXInMeters = mAMap.getScalePerPixel();
        mClusterDistance = mPXInMeters * mClusterSize;

        amap.setOnCameraChangeListener(this);
        amap.setOnMarkerClickListener(this);
        initThreadHandler();
        assignClusters();
    }

    private void reycleBitmap(Bitmap bitmap) {
        if (bitmap == null) {
            return;
        }
        //高版本不调用recycle
        if (Build.VERSION.SDK_INT <= 10) {
            if (!bitmap.isRecycled()) {
                bitmap.recycle();
            }
        }
    }

    /**
     * 设置聚合点的点击事件
     *
     * @param clusterClickListener
     */
    public void setOnClusterClickListener(
            ClusterClickListener clusterClickListener) {
        mClusterClickListener = clusterClickListener;
    }

    /**
     * 添加一个聚合点
     *
     * @param item
     */
    public void addClusterItem(ClusterOptionsSink item) {
        Message message = Message.obtain();
        message.what = SignClusterHandler.CALCULATE_SINGLE_CLUSTER;
        message.obj = item;
        mSignClusterHandler.sendMessage(message);
    }

    /**
     * 设置聚合元素的渲染样式，不设置则默认为气泡加数字形式进行渲染
     *
     * @param render
     */
    public void setClusterRenderer(ClusterRender render) {
        mClusterRender = this;
    }

    public void onDestroy() {
        mIsCanceled = true;
        mSignClusterHandler.removeCallbacksAndMessages(null);
        mMarkerhandler.removeCallbacksAndMessages(null);
        mSignClusterThread.quit();
        mMarkerHandlerThread.quit();
        for (Marker marker : mAddMarkers) {
            marker.remove();

        }
        mAddMarkers.clear();
        mLruCache.evictAll();
    }

    //初始化Handler
    private void initThreadHandler() {
        mMarkerHandlerThread.start();
        mSignClusterThread.start();
        mMarkerhandler = new MarkerHandler(mMarkerHandlerThread.getLooper());
        mSignClusterHandler = new SignClusterHandler(mSignClusterThread.getLooper());
    }

    @Override
    public void onCameraChange(CameraPosition arg0) {


    }

    @Override
    public void onCameraChangeFinish(CameraPosition arg0) {
        mPXInMeters = mAMap.getScalePerPixel();
        mClusterDistance = mPXInMeters * mClusterSize;
        assignClusters();
    }

    //点击事件
    @Override
    public boolean onMarkerClick(Marker arg0) {
        ClusterController cluster = (ClusterController) arg0.getObject();
        if (cluster != null) {
            final Map<String, Object> data = new HashMap<>(1);
            List<ClusterOptionsSink> items = cluster.getClusterItems();
            if (items.size() > 1) {
                LatLngBounds.Builder builder = new LatLngBounds.Builder();
                for (ClusterOptionsSink clusterItem : items) {
                    builder.include(clusterItem.getPosition());
                }
                LatLngBounds latLngBounds = builder.build();
                mAMap.animateCamera(CameraUpdateFactory.newLatLngBounds(latLngBounds, 0)
                );
            } else {
                data.put("items", JSON.toJSONString(items.get(0)));
                methodChannel.invokeMethod("cluster#onTap", data);
            }
            return true;
        }
        return false;
    }


    /**
     * 将聚合元素添加至地图上
     */
    private void addClusterToMap(List<ClusterController> clusters) {

        ArrayList<Marker> removeMarkers = new ArrayList<>();
        removeMarkers.addAll(mAddMarkers);
        AlphaAnimation alphaAnimation = new AlphaAnimation(1, 0);
        MyAnimationListener myAnimationListener = new MyAnimationListener(removeMarkers);
        for (Marker marker : removeMarkers) {
            marker.setAnimation(alphaAnimation);
            marker.setAnimationListener(myAnimationListener);
            marker.startAnimation();
        }

        for (ClusterController cluster : clusters) {
            addSingleClusterToMap(cluster);
        }
    }

    private AlphaAnimation mADDAnimation = new AlphaAnimation(0, 1);

    /**
     * 将单个聚合元素添加至地图显示
     *
     * @param cluster
     */
    private void addSingleClusterToMap(ClusterController cluster) {
        LatLng latlng = cluster.getCenterLatLng();
        MarkerOptions markerOptions = new MarkerOptions();
        int num = getWarningNum(cluster);
        markerOptions.anchor(0.5f, 0.5f)
                .icon(getBitmapDes(cluster.getClusterCount(), num, cluster)).position(latlng);
        Marker marker = mAMap.addMarker(markerOptions);

        marker.setAnimation(mADDAnimation);
        marker.setObject(cluster);

        marker.startAnimation();
        cluster.setMarker(marker);
        mAddMarkers.add(marker);

    }

    private int getWarningNum(ClusterController cluster) {
        int num = 0;
        List<ClusterOptionsSink> items = cluster.getClusterItems();
        for (ClusterOptionsSink s : items) {
            String data = s.getData();
            JSONObject json = JSON.parseObject(data);
            if (json.containsKey("warning_num")) {
                num += json.getIntValue("warning_num");
            }
        }
        return num;
    }


    private void calculateClusters() {
        mIsCanceled = false;
        mClusters.clear();
        LatLngBounds visibleBounds = mAMap.getProjection().getVisibleRegion().latLngBounds;
        for (ClusterOptionsSink clusterItem : mClusterItems) {
            if (mIsCanceled) {
                return;
            }
            LatLng latlng = clusterItem.getPosition();
            String data = clusterItem.getData();
            if (visibleBounds.contains(latlng)) {
                ClusterController cluster = getCluster(latlng, mClusters);
                if (cluster != null) {
                    cluster.addClusterItem(clusterItem);
                } else {
                    cluster = new ClusterController();
                    cluster.setPosition(latlng);
                    cluster.setData(data);
                    mClusters.add(cluster);
                    cluster.addClusterItem(clusterItem);
                }

            }
        }

        //复制一份数据，规避同步
        List<ClusterController> clusters = new ArrayList<ClusterController>();
        clusters.addAll(mClusters);
        Message message = Message.obtain();
        message.what = MarkerHandler.ADD_CLUSTER_LIST;
        message.obj = clusters;
        if (mIsCanceled) {
            return;
        }
        mMarkerhandler.sendMessage(message);
    }

    /**
     * 对点进行聚合
     */
    private void assignClusters() {
        mIsCanceled = true;
        mSignClusterHandler.removeMessages(SignClusterHandler.CALCULATE_CLUSTER);
        mSignClusterHandler.sendEmptyMessage(SignClusterHandler.CALCULATE_CLUSTER);
    }

    /**
     * 在已有的聚合基础上，对添加的单个元素进行聚合
     *
     * @param clusterItem
     */
    private void calculateSingleCluster(ClusterOptionsSink clusterItem) {
        LatLngBounds visibleBounds = mAMap.getProjection().getVisibleRegion().latLngBounds;
        LatLng latlng = clusterItem.getPosition();
        String data = clusterItem.getData();
        if (!visibleBounds.contains(latlng)) {
            return;
        }
        ClusterController cluster = getCluster(latlng, mClusters);
        if (cluster != null) {
            cluster.addClusterItem(clusterItem);
            Message message = Message.obtain();
            message.what = MarkerHandler.UPDATE_SINGLE_CLUSTER;

            message.obj = cluster;
            mMarkerhandler.removeMessages(MarkerHandler.UPDATE_SINGLE_CLUSTER);
            mMarkerhandler.sendMessageDelayed(message, 5);


        } else {

            cluster = new ClusterController();
            cluster.setPosition(latlng);
            cluster.setData(data);
            mClusters.add(cluster);
            cluster.addClusterItem(clusterItem);
            Message message = Message.obtain();
            message.what = MarkerHandler.ADD_SINGLE_CLUSTER;
            message.obj = cluster;
            mMarkerhandler.sendMessage(message);

        }
    }

    /**
     * 根据一个点获取是否可以依附的聚合点，没有则返回null
     *
     * @param latLng
     * @return
     */
    private ClusterController getCluster(LatLng latLng, List<ClusterController> clusters) {
        for (ClusterController cluster : clusters) {
            LatLng clusterCenterPoint = cluster.getCenterLatLng();
            double distance = AMapUtils.calculateLineDistance(latLng, clusterCenterPoint);
            if (distance < mClusterDistance && mAMap.getCameraPosition().zoom < 19) {
                return cluster;
            }
        }

        return null;
    }


    /**
     * 获取每个聚合点的绘制样式
     */
    private BitmapDescriptor getBitmapDes(int num, int warning_num, ClusterController cluster) {
        String plate = "";
        boolean online=false;
        JSONObject json = JSON.parseObject(cluster.getData());
        if (json.containsKey("plate")) {
            plate = json.getString("plate");
        }
        if (json.containsKey("online")) {
            online = json.getBoolean("online");
        }
        String key = "cluster" + num + "plateNo" + plate;
        BitmapDescriptor bitmapDescriptor = mLruCache.get(key);
        if (bitmapDescriptor == null) {
            TextView textView = new TextView(mContext);
            if (num > 1) {
                String tile = String.valueOf(num);
                textView.setText(tile);
                textView.setGravity(Gravity.CENTER);
                textView.setTextColor(Color.WHITE);
                textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
                if (mClusterRender != null && mClusterRender.getDrawAble(num, warning_num) != null) {
                    textView.setBackground(mClusterRender.getDrawAble(num, warning_num));
                } else {
                    textView.setBackgroundResource(R.drawable.defaultcluster);
                }
                bitmapDescriptor = BitmapDescriptorFactory.fromView(textView);
            } else {
                View view = LayoutInflater.from(mContext).inflate(R.layout.view_cluster, null);
                if (!TextUtils.isEmpty(plate)) {
                    ((TextView) view.findViewById(R.id.tv1)).setText(plate.substring(0, 1));
                    ((TextView) view.findViewById(R.id.tv2)).setText(plate.substring(1));
                }
                ((TextView) view.findViewById(R.id.tv1)).setSelected(online);
                ((TextView) view.findViewById(R.id.tv2)).setSelected(online);
                view.findViewById(R.id.ll).setSelected(online);
                view.findViewById(R.id.iv).setSelected(online);
                bitmapDescriptor = BitmapDescriptorFactory.fromView(view);
            }
            mLruCache.put(key, bitmapDescriptor);

        }
        return bitmapDescriptor;
    }

    /**
     * 更新已加入地图聚合点的样式
     */
    private void updateCluster(ClusterController cluster) {
        Marker marker = cluster.getMarker();
        int num = getWarningNum(cluster);
        marker.setIcon(getBitmapDes(cluster.getClusterCount(), num, cluster));


    }

    @Override
    public void doMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        LogUtil.i(CLASS_NAME, "doMethodCall===>" + call.method);
        switch (call.method) {
            case Const.METHOD_CLUSTER_UPDATE:
                invokeMarkerOptions(call, result);
                break;
        }
    }

    @Override
    public String[] getRegisterMethodIdArray() {
        return Const.METHOD_ID_LIST_FOR_CLUSTER;
    }

    /**
     * 执行主动方法更新cluster
     *
     * @param methodCall
     * @param result
     */
    public void invokeMarkerOptions(MethodCall methodCall, MethodChannel.Result result) {
        if (null == methodCall) {
            return;
        }
        Object clustersToAdd = methodCall.argument("clustersToAdd");
        addByList((List<Object>) clustersToAdd);
//        Object clustersToChange = methodCall.argument("clustersToChange");
//        updateByList((List<Object>) clustersToChange);
//        Object clusterIdsToRemove = methodCall.argument("clusterIdsToRemove");
//        removeByIdList((List<Object>) clusterIdsToRemove);
        result.success(null);
    }

    public void addByList(List<Object> clusertsToAdd) {
        if (clusertsToAdd != null) {
            for (Object object : clusertsToAdd) {
                add(object);
            }
        }
    }

    private void add(Object clusterObj) {
        if (null != amap) {
            ClusterOptionsBuilder builder = new ClusterOptionsBuilder();
            String dartClusterId = ClusterUtil.interpretClusterOptions(clusterObj, builder);
            if (!TextUtils.isEmpty(dartClusterId)) {
                ClusterOptions clusterOptions = builder.build();

                addClusterItem(clusterOptions);
            }
        }
    }

//    private void updateByList(List<Object> clustersToChange) {
//        if (clustersToChange != null) {
//            for (Object clusterToChange : clustersToChange) {
//                update(clusterToChange);
//            }
//        }
//    }
//
//    private void update(Object clusterToChange) {
//        Object dartMarkerId = ConvertUtil.getKeyValueFromMapObject(clusterToChange, "id");
//        if (null != dartMarkerId) {
//            ClusterController clusterController = controllerMapByDartId.get(dartMarkerId);
//            if (null != clusterController) {
//                ClusterUtil.interpretClusterOptions(clusterToChange, clusterController);
//            }
//        }
//    }


    /**
     * 根据手机的分辨率从 dp 的单位 转成为 px(像素)
     */
    public int dp2px(Context context, float dpValue) {
        final float scale = context.getResources().getDisplayMetrics().density;
        return (int) (dpValue * scale + 0.5f);
    }

    @Override
    public Drawable getDrawAble(int clusterNum, int warning_num) {
        int radius = dp2px(mContext, this.radius);
        int _color;
        String key = "cluster" + clusterNum + "-warnint_num" + warning_num;
        Drawable bitmapDrawable = mBackDrawAbles.get(key);
        if (bitmapDrawable == null) {
            if (warning_num > 0) {
                _color = Color.parseColor("#FFA7CC3D");
            } else {
                _color = Color.parseColor("#FFA7CC3D");
            }
            if (clusterNum == 1) {
                if (warning_num > 0) {
                    bitmapDrawable = mContext.getResources().getDrawable(
                            R.drawable.dp_error);

                } else {
                    bitmapDrawable =
                            mContext.getResources().getDrawable(
                                    R.drawable.dp);
                }

            } else {
                bitmapDrawable = new BitmapDrawable(null, drawCircle(radius,
                        _color));
            }
            mBackDrawAbles.put(key, bitmapDrawable);
            return bitmapDrawable;
        }
        return bitmapDrawable;

    }

    private Bitmap drawCircle(int radius, int color) {

        Bitmap bitmap = Bitmap.createBitmap(radius * 2, radius * 2,
                Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint paint = new Paint();
        RectF background = new RectF(0, 0, radius * 2, radius * 2);
        paint.setColor(Color.parseColor("#e8e8e8"));
        canvas.drawArc(background, 0, 360, true, paint);
        int padding = dp2px(mContext, 2);
        RectF rectF = new RectF(padding, padding, radius * 2 - padding, radius * 2 - padding);
        paint.setColor(Color.WHITE);
        canvas.drawArc(rectF, 0, 360, true, paint);
        int width = dp2px(mContext, 10);
        RectF rect = new RectF(width, width, radius * 2 - width, radius * 2 - width);
        paint.setColor(color);
        canvas.drawArc(rect, 0, 360, true, paint);
        return bitmap;
    }


//-----------------------辅助内部类用---------------------------------------------

    /**
     * marker渐变动画，动画结束后将Marker删除
     */
    class MyAnimationListener implements Animation.AnimationListener {
        private List<Marker> mRemoveMarkers;

        MyAnimationListener(List<Marker> removeMarkers) {
            mRemoveMarkers = removeMarkers;
        }

        @Override
        public void onAnimationStart() {

        }

        @Override
        public void onAnimationEnd() {
            for (Marker marker : mRemoveMarkers) {
                marker.remove();
            }
            mRemoveMarkers.clear();
        }
    }

    /**
     * 处理market添加，更新等操作
     */
    class MarkerHandler extends Handler {

        static final int ADD_CLUSTER_LIST = 0;

        static final int ADD_SINGLE_CLUSTER = 1;

        static final int UPDATE_SINGLE_CLUSTER = 2;

        MarkerHandler(Looper looper) {
            super(looper);
        }

        public void handleMessage(Message message) {
            switch (message.what) {
                case ADD_CLUSTER_LIST:
                    List<ClusterController> clusters = (List<ClusterController>) message.obj;
                    addClusterToMap(clusters);
                    break;
                case ADD_SINGLE_CLUSTER:
                    ClusterController cluster = (ClusterController) message.obj;
                    addSingleClusterToMap(cluster);
                    break;
                case UPDATE_SINGLE_CLUSTER:
                    ClusterController updateCluster = (ClusterController) message.obj;
                    updateCluster(updateCluster);
                    break;
            }
        }
    }

    /**
     * 处理聚合点算法线程
     */
    class SignClusterHandler extends Handler {
        static final int CALCULATE_CLUSTER = 0;
        static final int CALCULATE_SINGLE_CLUSTER = 1;

        SignClusterHandler(Looper looper) {
            super(looper);
        }

        public void handleMessage(Message message) {
            switch (message.what) {
                case CALCULATE_CLUSTER:
                    calculateClusters();
                    break;
                case CALCULATE_SINGLE_CLUSTER:
                    ClusterOptionsSink item = (ClusterOptionsSink) message.obj;
                    mClusterItems.add(item);
                    Log.i("yiyi.qi", "calculate single cluster");
                    calculateSingleCluster(item);
                    break;
            }
        }
    }
}