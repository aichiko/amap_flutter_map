import 'dart:math';

import 'package:amap_flutter_base/amap_flutter_base.dart';

class LatLngBoundUtils {
  static LatLngBounds? buildLatLngBound(List<LatLng> list) {
    if (list.isEmpty) return null;
    double mSouth = list[0].latitude;
    double mNorth = list[0].latitude;
    double mWest = list[0].longitude;
    double mEast = list[0].longitude;

    for (int i = 0; i < list.length; i++) {
      LatLng latLng = list[i];
      mSouth = min(mSouth, latLng.latitude);
      mNorth = max(mNorth, latLng.latitude);
      double longitude = latLng.longitude;
      bool next = false;
      if (mWest <= mEast) {
        next = mWest <= longitude && longitude <= mEast;
      } else {
        next = mWest <= longitude || longitude <= mEast;
      }
      if (!next) {
        if ((mWest - longitude + 360.0) % 360.0 <
            (longitude - mEast + 360.0) % 360.0) {
          mWest = longitude;
        } else {
          mEast = longitude;
        }
      }
    }

    if (mWest > mEast) {
      double var1 = mWest;
      mWest = mEast;
      mEast = var1;
    }
    if (mSouth > mNorth) {
      double var3 = mSouth;
      mSouth = mNorth;
      mNorth = var3;
    }
    return LatLngBounds(
        southwest: LatLng(mSouth, mWest), northeast: LatLng(mNorth, mEast));
  }
}
