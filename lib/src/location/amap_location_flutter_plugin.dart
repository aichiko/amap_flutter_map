part of amap_flutter_map;

/// 高德地图定位 插件
class AmapLocationFlutterPlugin {
  static const String _CHANNEL_METHOD_LOCATION = "amap_location_flutter_plugin";
  static const String _CHANNEL_STREAM_LOCATION =
      "amap_location_flutter_plugin_stream";

  static const MethodChannel _methodChannel =
      const MethodChannel(_CHANNEL_METHOD_LOCATION);

  static const EventChannel _eventChannel =
      const EventChannel(_CHANNEL_STREAM_LOCATION);

  static Stream<Map<String, Object>> _onLocationChanged = _eventChannel
      .receiveBroadcastStream()
      .asBroadcastStream()
      .map<Map<String, Object>>((element) => element.cast<String, Object>());

  late StreamController<Map<String, Object>> _receiveStream;
  late StreamSubscription<Map<String, Object>>? _subscription;
  late String _pluginKey;

  /// 申请定位权限
  /// 授予定位权限返回true， 否则返回false
  Future<bool> requestLocationPermission() async {
    var status = await Permission.location.status;
    // 申请结果
    if (status == PermissionStatus.granted) {
      return true;
    }
    // 申请权限
    var f_status = await Permission.location.request();
    // 申请结果
    if (f_status == PermissionStatus.granted) {
      return true;
    } else {
      return false;
    }
  }

  ///初始化
  AmapLocationFlutterPlugin() {
    _pluginKey = DateTime.now().millisecondsSinceEpoch.toString();
    _receiveStream = StreamController();
  }

  ///开始定位
  void startLocation() {
    _methodChannel.invokeMethod('startLocation', {'pluginKey': _pluginKey});
    return;
  }

  ///停止定位
  void stopLocation() {
    _methodChannel.invokeMethod('stopLocation', {'pluginKey': _pluginKey});
    return;
  }

  ///设置Android和iOS的apikey，建议在weigdet初始化时设置<br>
  ///apiKey的申请请参考高德开放平台官网<br>
  ///Android端: https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key<br>
  ///iOS端: https://lbs.amap.com/api/ios-location-sdk/guide/create-project/get-key<br>
  ///[androidKey] Android平台的key<br>
  ///[iosKey] ios平台的key<br>
  static void setApiKey(String androidKey, String iosKey) {
    _methodChannel
        .invokeMethod('setApiKey', {'android': androidKey, 'ios': iosKey});
  }

  /// 设置定位参数
  void setLocationOption(AMapLocationOption locationOption) {
    Map option = locationOption.getOptionsMap();
    option['pluginKey'] = _pluginKey;
    _methodChannel.invokeMethod('setLocationOption', option);
  }

  ///销毁定位
  void destroy() {
    _methodChannel.invokeListMethod('destroy', {'pluginKey': _pluginKey});
    if (_subscription != null) {
      _receiveStream.close();
      _subscription!.cancel();
      _subscription = null;
    }
  }

  ///定位结果回调
  Stream<Map<String, Object>> onLocationChanged() {
    _subscription = _onLocationChanged.listen((Map<String, Object> event) {
      if (event['pluginKey'] == _pluginKey) {
        Map<String, Object> newEvent = Map<String, Object>.of(event);
        newEvent.remove('pluginKey');
        _receiveStream.add(newEvent);
      }
    });
    return _receiveStream.stream;
  }
}
