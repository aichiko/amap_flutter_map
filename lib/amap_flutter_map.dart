/// 高德地图Flutter插件入口文件
library amap_flutter_map;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/src/core/amap_flutter_platform.dart';
import 'package:amap_flutter_map/src/core/map_event.dart';
import 'package:amap_flutter_map/src/core/method_channel_amap_flutter_map.dart';
import 'package:amap_flutter_map/src/types/types.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'package:amap_flutter_map/src/types/types.dart';

part 'src/amap_controller.dart';
part 'src/amap_widget.dart';

// 新增 地图方法
part 'src/amap_config_model.dart';
part 'src/amap_utility.dart';
// 定位
part 'src/location/amap_location_option.dart';
part 'src/location/amap_location_flutter_plugin.dart';
