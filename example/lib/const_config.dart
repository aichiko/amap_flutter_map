import 'package:amap_flutter_base/amap_flutter_base.dart';

class ConstConfig {

  // 安卓包名 com.example.flutter_project
  static const AMapApiKey amapApiKeys =
      AMapApiKey(androidKey: '900f72eeee0f21e435cebb0ef155582a', iosKey: '4dfdec97b7bf0b8c13e94777103015a9');

  static const AMapPrivacyStatement amapPrivacyStatement =
      AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true);
}
