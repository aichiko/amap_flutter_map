part of amap_flutter_map;

///驾车策略
enum AMapDrivingStrategy {
  Fastest, ///<速度最快
  MinFare, ///<避免收费
  Shortest, ///<距离最短
  
  NoHighways, ///<不走高速
  AvoidCongestion, ///<躲避拥堵
  
  AvoidHighwaysAndFare, ///<不走高速且避免收费
  AvoidHighwaysAndCongestion, ///<不走高速且躲避拥堵
  AvoidFareAndCongestion, ///<躲避收费和拥堵
  AvoidHighwaysAndFareAndCongestion ///<不走高速躲避收费和拥堵
}

///公交策略
enum AMapTransitStrategy {
  Fastest,///<最快捷
  MinFare,///<最经济
  MinTransfer,///<最少换乘
  MinWalk,///<最少步行
  MostComfortable,///<最舒适
  AvoidSubway,///<不乘地铁
}

///路径规划类型
enum AMapRouteSearchType {
  Driving, ///<驾车
  Transit, ///<公交
  Walking, ///<步行
}

class AMapNaviConfig {
  ///应用返回的Scheme
  String appScheme;

  ///应用名称
  String appName;

  ///终点
  LatLng destination;

  ///导航策略
  AMapDrivingStrategy strategy;

  AMapNaviConfig(this.appScheme, this.appName, {
    required this.destination,
    this.strategy = AMapDrivingStrategy.Fastest
  });

  AMapNaviConfig clone() {
    return AMapNaviConfig(
      appScheme, 
      appName, 
      destination: destination, 
      strategy: strategy
    );
  }

  static AMapNaviConfig? fromMap(dynamic json) {
    if (null == json) {
      return null;
    }
    return AMapNaviConfig(
      json['appScheme'] ?? null,
      json['appName'] ?? null,
      destination: LatLng.fromJson(json['destination'] ?? null) ?? LatLng(0, 0),
      strategy: json['strategy'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent('appScheme', appScheme);
    addIfPresent('appName', appName);
    addIfPresent('destination', destination.toJson());
    addIfPresent('strategy', strategy.index);
    return json;
  }

  @override
  String toString() {
    return 'AMapNaviConfig{'
        'appScheme: $appScheme,'
        'appName: $appName,'
        'destination: $destination,'
        'strategy: $strategy, }';
  }

  @override
  int get hashCode =>
      hashValues(appScheme, appName, destination, strategy);
}

class AMapRouteConfig {

  ///应用返回的Scheme
  String appScheme;

  ///应用名称
  String appName;

  ///起点坐标
  LatLng startCoordinate;

  ///终点坐标
  LatLng destinationCoordinate;

  ///驾车策略
  AMapDrivingStrategy drivingStrategy;

  ///公交策略
  AMapTransitStrategy transitStrategy;

  ///路径规划类型
  AMapRouteSearchType routeType;

  AMapRouteConfig(this.appScheme, this.appName, {
    required this.startCoordinate,
    required this.destinationCoordinate,
    this.drivingStrategy = AMapDrivingStrategy.Fastest,
    this.transitStrategy = AMapTransitStrategy.Fastest,
    this.routeType = AMapRouteSearchType.Driving
  });

  AMapRouteConfig clone() {
    return AMapRouteConfig(
      appScheme, 
      appName, 
      startCoordinate: startCoordinate, 
      destinationCoordinate: destinationCoordinate, 
      drivingStrategy: drivingStrategy, 
      transitStrategy: transitStrategy, 
      routeType: routeType
    );
  }

  static AMapRouteConfig? fromMap(dynamic json) {
    if (null == json) {
      return null;
    }
    return AMapRouteConfig(
      json['appScheme'] ?? null,
      json['appName'] ?? null,
      startCoordinate: LatLng.fromJson(json['startCoordinate'] ?? null) ?? LatLng(0, 0),
      destinationCoordinate: LatLng.fromJson(json['destinationCoordinate'] ?? null) ?? LatLng(0, 0),
      drivingStrategy: json['drivingStrategy'] ?? 0,
      transitStrategy: json['transitStrategy'] ?? 0,
      routeType: json['routeType'] ?? 0,
    );
  }


  Map<String, dynamic> toMap() {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent('appScheme', appScheme);
    addIfPresent('appName', appName);
    addIfPresent('startCoordinate', startCoordinate.toJson());
    addIfPresent('destinationCoordinate', destinationCoordinate.toJson());

    addIfPresent('drivingStrategy', drivingStrategy.index);
    addIfPresent('transitStrategy', transitStrategy.index);
    addIfPresent('routeType', routeType.index);
    return json;
  }

  @override
  String toString() {
    return 'AMapNaviConfig{'
        'appScheme: $appScheme,'
        'appName: $appName,'
        'startCoordinate: $startCoordinate,'
        'destinationCoordinate: $destinationCoordinate,'
        'drivingStrategy: $drivingStrategy,'
        'transitStrategy: $transitStrategy,'
        'routeType: $routeType, }';
  }

  @override
  int get hashCode =>
      hashValues(appScheme, appName, startCoordinate, destinationCoordinate, drivingStrategy, transitStrategy, routeType);
}
