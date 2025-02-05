#import "AMapFlutterMapPlugin.h"
#import "AMapFlutterFactory.h"

#import "AmapLocationFlutterPlugin.h"


@implementation AMapFlutterMapPlugin{
  NSObject<FlutterPluginRegistrar>* _registrar;
  FlutterMethodChannel* _channel;
  NSMutableDictionary* _mapControllers;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    AMapFlutterFactory* aMapFactory = [[AMapFlutterFactory alloc] initWithRegistrar:registrar];
    [registrar registerViewFactory:aMapFactory
                            withId:@"com.amap.flutter.map"
  gestureRecognizersBlockingPolicy:
     FlutterPlatformViewGestureRecognizersBlockingPolicyWaitUntilTouchesEnded];
    [AmapLocationFlutterPlugin registerWithRegistrar:registrar];
}

@end
