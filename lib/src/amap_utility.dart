// 主要是高德地图自带的几何类方法 具体请查看 MAGeometry 文件代码
part of amap_flutter_map;

enum AMapCoordinateType {
  AMap,

  ///<AMap
  Baidu,

  ///<Baidu
  MapBar,

  ///<MapBar
  MapABC,

  ///<MapABC
  SoSoMap,

  ///<SoSoMap
  AliYun,

  ///<AliYun
  Google,

  ///<Google
  GPS,
}

// typedef AMapLatLng LatLng;

/// 一些工具类的方法，暂时只有转换坐标的方法(暂时只调试了iOS部分)
class AMapUtility {
  static const String _CHANNEL_METHOD_UTILITY = "amap_utility_flutter";

  static const MethodChannel _methodChannel =
      const MethodChannel(_CHANNEL_METHOD_UTILITY);

  /// 转换目标经纬度为高德坐标系，不在枚举范围内的经纬度将直接返回。
  static Future<LatLng> coordinateConvert(
      LatLng latLng, AMapCoordinateType type) async {
    List arr = await _methodChannel
        .invokeMethod('map#coordinateConvert', [latLng.toJson(), type.index]);
    LatLng? t_latLng = LatLng.fromJson(arr);
    if (t_latLng != null) {
      return t_latLng;
    }
    return LatLng(0, 0);
  }

  /// 调起高德地图api驾车导航.
  static Future<bool> openAMapNavigation(AMapNaviConfig config) async {
    bool ss = await _methodChannel.invokeMethod(
        'map#openAMapNavigation', config.toMap());
    return ss;
  }

  /// 调起高德地图app进行路径规划.
  static Future<bool> openAMapRouteSearch(AMapRouteConfig config) async {
    bool ss = await _methodChannel.invokeMethod(
        'map#openAMapRouteSearch', config.toMap());
    return ss;
  }
}
