import 'dart:convert';

import 'package:amap_flutter_base/amap_flutter_base.dart';

import 'base_overlay.dart';

class Cluster extends BaseOverlay {
  /// 位置,不能为空
  LatLng? position;
  dynamic data;

  Cluster({required this.position, this.data});
  Cluster.fromJson(Map<String, dynamic> json) {
    position =
        LatLng(json['position']["latitude"], json['position']["longitude"]);
    data = jsonDecode(json['data']);
  }

  /// copy的真正复制的参数，主要用于需要修改某个属性参数时使用
  Cluster copyWith({
    LatLng? positionParam = null,
    dynamic dataParam,
  }) {
    Cluster copyCluster = Cluster(
      position: positionParam,
      data: dataParam ?? data,
    );
    copyCluster.setIdForCopy(id);
    return copyCluster;
  }

  Cluster clone() => copyWith();

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> json = <String, dynamic>{};
    json['id'] = id;
    json['position'] = position?.toJson();
    json['data'] = data;
    return json;
  }
}
