#import "AmapLocationFlutterPlugin.h"
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import "AmapFlutterStreamManager.h"
#import <AMapNaviKit/AMapNaviKit.h>
@interface AMapFlutterLocationManager : AMapLocationManager

@property (nonatomic, assign) BOOL onceLocation;
@property (nonatomic, copy) FlutterResult flutterResult;
@property (nonatomic, strong) NSString *pluginKey;

@end

@implementation AMapFlutterLocationManager

- (instancetype)init {
    if ([super init] == self) {
        _onceLocation = false;
    }
    return self;
}

@end

@interface AmapLocationFlutterPlugin()<AMapLocationManagerDelegate,AMapNaviCompositeManagerDelegate>
@property (nonatomic, strong) NSMutableDictionary<NSString*, AMapFlutterLocationManager*> *pluginsDict;
@property (nonatomic, strong) AMapNaviCompositeManager *compositeManager;
@end

@implementation AmapLocationFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"amap_location_flutter_plugin"
                                     binaryMessenger:[registrar messenger]];
    AmapLocationFlutterPlugin* instance = [[AmapLocationFlutterPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    //AmapFlutterStreamHandler * streamHandler = [[AmapFlutterStreamHandler alloc] init];
    FlutterEventChannel *eventChanel = [FlutterEventChannel eventChannelWithName:@"amap_location_flutter_plugin_stream" binaryMessenger:[registrar messenger]];
    [eventChanel setStreamHandler:[[AmapFlutterStreamManager sharedInstance] streamHandler]];
    
    // 工具类的方法
    FlutterMethodChannel *utilityChannel = [FlutterMethodChannel
                                              methodChannelWithName:@"amap_utility_flutter"
                                              binaryMessenger:[registrar messenger]];

    [utilityChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
      // Note: this method is invoked on the UI thread.
      if ([@"map#coordinateConvert" isEqualToString:call.method]) {
          //转换目标经纬度为高德坐标系
          // 2个参数
          NSArray *arr = call.arguments;
          if (arr.count == 2) {
              NSArray<NSNumber *> *latLng = arr.firstObject;
              NSNumber *type = arr.lastObject;
              
              if (latLng == nil || type == nil) {
                  result(FlutterMethodNotImplemented);
              }
              
              NSInteger type_int = [type intValue];
              
              CLLocationCoordinate2D coor = AMapCoordinateConvert(CLLocationCoordinate2DMake(latLng.firstObject.doubleValue, latLng.lastObject.doubleValue), type_int-1);
              
              result(@[@(coor.latitude), @(coor.longitude)]);
          }
      } else if ([@"map#openAMapNavigation" isEqualToString:call.method]) {
          // 调起高德地图app驾车导航.
          NSDictionary *dic = call.arguments;
          if (dic) {
              
              NSString *appScheme = dic[@"appScheme"];
              NSString *appName = dic[@"appName"];
              
              NSNumber *strategy = dic[@"strategy"];
              NSArray<NSNumber *> *latLng = dic[@"destination"];
              
              if (latLng == nil || latLng.count == 0) {
                  result(@NO);
                  return;
              }
              
              CLLocationCoordinate2D destination = CLLocationCoordinate2DMake(latLng.firstObject.doubleValue, latLng.lastObject.doubleValue);
              
              if (destination.latitude == 0 && destination.longitude == 0) {
                  result(@NO);
                  return;
              }
              
//              AMapNaviConfig *config = [[AMapNaviConfig alloc] init];
//              config.appName = appName;
//              config.appScheme = appScheme;
//              config.strategy = strategy.intValue;
//              config.destination = destination;
              
              //BOOL aa = [AMapURLSearch openAMapNavigation:config];
              [instance startNaviDirectlyWithLatitude:destination.latitude longitude:destination.longitude];
              result(@YES);
              //result(@(aa));
          } else {
              result(@NO);
          }
      }  else if ([@"map#openAMapRouteSearch" isEqualToString:call.method]) {
          // 调起高德地图app进行路径规划.
          NSDictionary *dic = call.arguments;
          if (dic) {
              NSString *appScheme = dic[@"appScheme"];
              NSString *appName = dic[@"appName"];
              
              NSNumber *drivingStrategy = dic[@"drivingStrategy"];
              NSNumber *transitStrategy = dic[@"transitStrategy"];
              NSNumber *routeType = dic[@"routeType"];
              
              
              NSArray<NSNumber *> *start_latLng = dic[@"startCoordinate"];
              NSArray<NSNumber *> *destination_latLng = dic[@"destinationCoordinate"];
              
              if (start_latLng == nil || start_latLng.count == 0) {
                  result(@NO);
                  return;
              }
              
              if (destination_latLng == nil || destination_latLng.count == 0) {
                  result(@NO);
                  return;
              }
              
              CLLocationCoordinate2D startCoordinate = CLLocationCoordinate2DMake(start_latLng.firstObject.doubleValue, start_latLng.lastObject.doubleValue);
              
              CLLocationCoordinate2D destinationCoordinate = CLLocationCoordinate2DMake(destination_latLng.firstObject.doubleValue, destination_latLng.lastObject.doubleValue);
              
              if (startCoordinate.latitude == 0 && startCoordinate.longitude == 0) {
                  result(@NO);
                  return;
              }
              
              if (destinationCoordinate.latitude == 0 && destinationCoordinate.longitude == 0) {
                  result(@NO);
                  return;
              }
              
              AMapRouteConfig *config = [[AMapRouteConfig alloc] init];
              config.appName = appName;
              config.appScheme = appScheme;
              config.drivingStrategy = drivingStrategy.intValue;
              config.transitStrategy = transitStrategy.intValue;
              config.routeType = routeType.intValue;
              
              config.startCoordinate = startCoordinate;
              config.destinationCoordinate = destinationCoordinate;
              
              BOOL aa = [AMapURLSearch openAMapRouteSearch:config];
              
              result(@(aa));
          } else {
              result(@NO);
          }
      } else {
          result(FlutterMethodNotImplemented);
      }
    }];
}
// init
- (AMapNaviCompositeManager *)compositeManager {
    if (!_compositeManager) {
        _compositeManager = [[AMapNaviCompositeManager alloc] init];  // 初始化
        //_compositeManager.delegate = self;  // 如果需要使用AMapNaviCompositeManagerDelegate的相关回调（如自定义语音、获取实时位置等），需要设置delegate
    }
    return _compositeManager;
}
// 进入导航界面
- (void)startNaviDirectlyWithLatitude:(CGFloat)lat longitude:(CGFloat)lon {
    AMapNaviCompositeUserConfig *config = [[AMapNaviCompositeUserConfig alloc] init];
    [config setRoutePlanPOIType:AMapNaviRoutePlanPOITypeEnd location:[AMapNaviPoint locationWithLatitude:lat longitude:lon] name:@"" POIId:nil];  //传入终点
    //[config setStartNaviDirectly:YES];  //直接进入导航界面
    [self.compositeManager presentRoutePlanViewControllerWithOptions:config];
}
- (instancetype)init {
    if ([super init] == self) {
        _pluginsDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"startLocation" isEqualToString:call.method]){
        [self startLocation:call result:result];
    }else if ([@"stopLocation" isEqualToString:call.method]){
        [self stopLocation:call];
        result(@YES);
    }else if ([@"setLocationOption" isEqualToString:call.method]){
        [self setLocationOption:call];
    }else if ([@"destroy" isEqualToString:call.method]){
        [self destroyLocation:call];
    }else if ([@"setApiKey" isEqualToString:call.method]){
        NSString *apiKey = call.arguments[@"ios"];
        if (apiKey && [apiKey isKindOfClass:[NSString class]]) {
            [AMapServices sharedServices].apiKey = apiKey;
            result(@YES);
        }else {
            result(@NO);
        }

    }else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)startLocation:(FlutterMethodCall*)call result:(FlutterResult)result
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }

    if (manager.onceLocation) {
        [manager requestLocationWithReGeocode:manager.locatingWithReGeocode completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            [self handlePlugin:manager.pluginKey location:location reGeocode:regeocode error:error];
        }];
    } else {
        [manager setFlutterResult:result];
        [manager startUpdatingLocation];
    }
}

- (void)stopLocation:(FlutterMethodCall*)call
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }

    [manager setFlutterResult:nil];
    [[self locManagerWithCall:call] stopUpdatingLocation];
}

- (void)setLocationOption:(FlutterMethodCall*)call
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }
    
    NSNumber *needAddress = call.arguments[@"needAddress"];
    if (needAddress) {
        [manager setLocatingWithReGeocode:[needAddress boolValue]];
    }
        
    NSNumber *geoLanguage = call.arguments[@"geoLanguage"];
    if (geoLanguage) {
        if ([geoLanguage integerValue] == 0) {
            [manager setReGeocodeLanguage:AMapLocationReGeocodeLanguageDefault];
        } else if ([geoLanguage integerValue] == 1) {
            [manager setReGeocodeLanguage:AMapLocationReGeocodeLanguageChinse];
        } else if ([geoLanguage integerValue] == 2) {
            [manager setReGeocodeLanguage:AMapLocationReGeocodeLanguageEnglish];
        }
    }

    NSNumber *onceLocation = call.arguments[@"onceLocation"];
    if (onceLocation) {
        manager.onceLocation = [onceLocation boolValue];
    }

    NSNumber *pausesLocationUpdatesAutomatically = call.arguments[@"pausesLocationUpdatesAutomatically"];
    if (pausesLocationUpdatesAutomatically) {
        [manager setPausesLocationUpdatesAutomatically:[pausesLocationUpdatesAutomatically boolValue]];
    }
    
    NSNumber *desiredAccuracy = call.arguments[@"desiredAccuracy"];
    if (desiredAccuracy) {
        
        if (desiredAccuracy.integerValue == 0) {
            [manager setDesiredAccuracy:kCLLocationAccuracyBest];
        } else if (desiredAccuracy.integerValue == 1){
            [manager setDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
        } else if (desiredAccuracy.integerValue == 2){
            [manager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
        } else if (desiredAccuracy.integerValue == 3){
            [manager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
        } else if (desiredAccuracy.integerValue == 4){
            [manager setDesiredAccuracy:kCLLocationAccuracyKilometer];
        } else if (desiredAccuracy.integerValue == 5){
            [manager setDesiredAccuracy:kCLLocationAccuracyThreeKilometers];
        }
    }
    
    NSNumber *distanceFilter = call.arguments[@"distanceFilter"];
    if (distanceFilter) {
        if (distanceFilter.doubleValue == -1) {
            [manager setDistanceFilter:kCLDistanceFilterNone];
        } else if (distanceFilter.doubleValue > 0) {
            [manager setDistanceFilter:distanceFilter.doubleValue];
        }
    }

}

- (void)destroyLocation:(FlutterMethodCall*)call
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }
    
    @synchronized (self) {
        if (manager.pluginKey) {
            [_pluginsDict removeObjectForKey:manager.pluginKey];
        }
    }
    
}

- (void)handlePlugin:(NSString *)pluginKey location:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode error:(NSError *)error
{
    if (!pluginKey || ![[AmapFlutterStreamManager sharedInstance] streamHandler].eventSink) {
        return;
    }
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:1];
    [dic setObject:[self getFormatTime:[NSDate date]] forKey:@"callbackTime"];
    [dic setObject:pluginKey forKey:@"pluginKey"];
    
    if (location) {
        [dic setObject:[self getFormatTime:location.timestamp] forKey:@"locTime"];
        [dic setValue:@1 forKey:@"locationType"];
        [dic setObject:[NSString stringWithFormat:@"%f",location.coordinate.latitude] forKey:@"latitude"];
        [dic setObject:[NSString stringWithFormat:@"%f",location.coordinate.longitude] forKey:@"longitude"];
        [dic setValue:[NSNumber numberWithDouble:location.horizontalAccuracy] forKey:@"accuracy"];
        [dic setValue:[NSNumber numberWithDouble:location.altitude] forKey:@"altitude"];
        [dic setValue:[NSNumber numberWithDouble:location.course] forKey:@"bearing"];
        [dic setValue:[NSNumber numberWithDouble:location.speed] forKey:@"speed"];
        
        if (reGeocode) {
            if (reGeocode.country) {
                [dic setValue:reGeocode.country forKey:@"country"];
            }
            
            if (reGeocode.province) {
                [dic setValue:reGeocode.province forKey:@"province"];
            }
            
            if (reGeocode.city) {
                [dic setValue:reGeocode.city forKey:@"city"];
            }
            
            if (reGeocode.district) {
                [dic setValue:reGeocode.district forKey:@"district"];
            }
            
            if (reGeocode.street) {
                [dic setValue:reGeocode.street forKey:@"street"];
            }
            
            
            if (reGeocode.number) {
                [dic setValue:reGeocode.number forKey:@"streetNumber"];
            }
            
            if (reGeocode.number) {
                [dic setValue:reGeocode.number forKey:@"streetNumber"];
            }

            if (reGeocode.adcode) {
                [dic setValue:reGeocode.adcode forKey:@"adCode"];
            }
            
            if (reGeocode.description) {
                [dic setValue:reGeocode.formattedAddress forKey:@"description"];
            }
                        
            if (reGeocode.formattedAddress.length) {
                [dic setObject:reGeocode.formattedAddress forKey:@"address"];
            }
        }
        
    } else {
        [dic setObject:@"-1" forKey:@"errorCode"];
        [dic setObject:@"location is null" forKey:@"errorInfo"];
        
    }
    
    if (error) {
        [dic setObject:[NSNumber numberWithInteger:error.code]  forKey:@"errorCode"];
        [dic setObject:error.description forKey:@"errorInfo"];
    }
    
    [[AmapFlutterStreamManager sharedInstance] streamHandler].eventSink(dic);
    //NSLog(@"x===%f,y===%f",location.coordinate.latitude,location.coordinate.longitude);
}

- (AMapFlutterLocationManager *)locManagerWithCall:(FlutterMethodCall*)call {
    
    if (!call || !call.arguments || !call.arguments[@"pluginKey"] || [call.arguments[@"pluginKey"] isKindOfClass:[NSString class]] == NO) {
        return nil;
    }
    
    NSString *pluginKey = call.arguments[@"pluginKey"];
    
    AMapFlutterLocationManager *manager = nil;
    @synchronized (self) {
            manager = [_pluginsDict objectForKey:pluginKey];
    }
    
    if (!manager) {
        manager = [[AMapFlutterLocationManager alloc] init];
        manager.pluginKey = pluginKey;
        manager.locatingWithReGeocode = YES;
        manager.delegate = self;
        @synchronized (self) {
            [_pluginsDict setObject:manager forKey:pluginKey];
        }
    }
    return manager;
}

/**
 *  @brief 当plist配置NSLocationAlwaysUsageDescription或者NSLocationAlwaysAndWhenInUseUsageDescription，并且[CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined，会调用代理的此方法。
     此方法实现调用申请后台权限API即可：[locationManager requestAlwaysAuthorization](必须调用,不然无法正常获取定位权限)
 *  @param manager 定位 AMapLocationManager 类。
 *  @param locationManager  需要申请后台定位权限的locationManager。
 *  @since 2.6.2
 */
- (void)amapLocationManager:(AMapLocationManager *)manager doRequireLocationAuth:(CLLocationManager*)locationManager
{
    [locationManager requestWhenInUseAuthorization];
}

 /**
 *  @brief 当定位发生错误时，会调用代理的此方法。
 *  @param manager 定位 AMapLocationManager 类。
 *  @param error 返回的错误，参考 CLError 。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didFailWithError:(NSError *)error
{
    [self handlePlugin:((AMapFlutterLocationManager *)manager).pluginKey location:nil reGeocode:nil error:error];
}


/**
 *  @brief 连续定位回调函数.注意：如果实现了本方法，则定位信息不会通过amapLocationManager:didUpdateLocation:方法回调。
 *  @param manager 定位 AMapLocationManager 类。
 *  @param location 定位结果。
 *  @param reGeocode 逆地理信息。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode
{
    [self handlePlugin:((AMapFlutterLocationManager *)manager).pluginKey location:location reGeocode:reGeocode error:nil];
}

- (NSString *)getFormatTime:(NSDate*)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    NSString *timeString = [formatter stringFromDate:date];
    return timeString;
}

@end
