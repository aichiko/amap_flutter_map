import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'dart:ui' show hashValues;

/// 路径规划的参数
class RouteSearch {
  
  /// 根据当前 [marker] 创建[MarkerAnimated].
  RouteSearch.from(startLatLng, destinationLatLng, {
    int strategy = 10,
    bool showTraffic = true
  }) {
    this.startLatLng = startLatLng;
    this.destinationLatLng = destinationLatLng;
    this.strategy = strategy;
    this.showTraffic = showTraffic;
  }

  /// 起点
  late LatLng startLatLng;
  /// 终点
  late LatLng destinationLatLng;
  /// 驾车导航策略
  late int strategy;
  /// 是否显示实时路况
  bool showTraffic = true;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> updateMap = <String, dynamic>{};

    void addIfNonNull(String fieldName, dynamic value) {
      if (value != null) {
        updateMap[fieldName] = value;
      }
    }

    var map = Map.of({
      'startLatLng': startLatLng.toJson(),
      'destinationLatLng': destinationLatLng.toJson(),
      'strategy': strategy,
      'showTraffic': showTraffic,
    });

    // addIfNonNull('mapRouteSearch', map);

    return map;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if(other is !RouteSearch) return false;
    final RouteSearch typedOther = other;
    return (startLatLng.toJson() == typedOther.startLatLng.toJson());
  }

  @override
  int get hashCode =>
      hashValues(strategy, startLatLng, destinationLatLng);

  @override
  String toString() {
    return '_RouteSearch{mapRouteSearch: startLatLng: $startLatLng, '
            'destinationLatLng: $destinationLatLng'
            'strategy: $strategy }'
            'showTraffic: $showTraffic }';
  }
}