import 'dart:ui' show hashValues;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:flutter/foundation.dart' show VoidCallback, setEquals;

import 'types.dart';
import 'marker.dart';

/// 用以描述Marker的更新项
class MarkerAnimated {
  /// 根据当前 [marker] 创建[MarkerAnimated].
  MarkerAnimated.from(this.animated_marker,
      {required List<LatLng> points,
      double duration = 0.25,
      String? name,
      int totalDurationTime = 180,
      int playSpeed = 1,
      bool isPlaying = false,
      VoidCallback? completeCallback}) {
    _points = points;
    _duration = duration;
    _name = name;
    _totalDurationTime = totalDurationTime;
    _playSpeed = playSpeed;
    _completeCallback = completeCallback;
    _isPlaying = isPlaying;
  }

  late List<LatLng> _points;
  late double _duration;
  String? _name;
  VoidCallback? _completeCallback;

  Marker animated_marker;

  //播放总时长
  late int _totalDurationTime;

  //播放速度
  late int _playSpeed;
  late bool _isPlaying;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> updateMap = <String, dynamic>{};

    void addIfNonNull(String fieldName, dynamic value) {
      if (value != null) {
        updateMap[fieldName] = value;
      }
    }

    var arr = _points.map((e) => e.toJson()).toList();
    var map = Map.of({
      'marker': animated_marker.id,
      'id': animated_marker.id,
      'points': arr,
      'duration': _duration,
      'totalDurationTime': _totalDurationTime,
      'playSpeed': _playSpeed,
      'isPlaying': _isPlaying,
    });

    addIfNonNull('markersToAnimated', map);
    addIfNonNull('markersToStopAnimated', map);
    addIfNonNull('setTrackData', map);

    return updateMap;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! MarkerAnimated) return false;
    final MarkerAnimated typedOther = other;
    return (animated_marker.id == typedOther.animated_marker.id);
  }

  @override
  int get hashCode => hashValues(animated_marker, _points, _duration);

  @override
  String toString() {
    return '_MarkerAnimated{markersToAnimated: $animated_marker, '
        'points: $_points }';
  }
}
