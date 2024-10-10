//
//  AMapViewController.m
//  amap_flutter_map
//
//  Created by lly on 2020/10/29.
//

#import "AMapViewController.h"
#import "AMapJsonUtils.h"
#import "AMapCameraPosition.h"
#import "MAMapView+Flutter.h"
#import "MAAnnotationView+Flutter.h"
#import "AMapMarkerController.h"
#import "MAPointAnnotation+Flutter.h"
#import "AMapPolylineController.h"
#import "MAPolyline+Flutter.h"
#import "AMapPolyline.h"
#import "MAPolylineRenderer+Flutter.h"
#import <CoreLocation/CoreLocation.h>
#import "AMapPolygonController.h"
#import "AMapClusterController.h"
#import "MAPolygon+Flutter.h"
#import "MAPolygonRenderer+Flutter.h"
#import "AMapPolygon.h"
#import <AMapFoundationKit/AMapFoundationKit.h>
#import "AMapLocation.h"
#import "AMapJsonUtils.h"
#import "AMapConvertUtil.h"
#import "ClusterAnnotationView.h"
#import "ClusterAnnotation.h"
#import "FlutterMethodChannel+MethodCallDispatch.h"
#import <AMapSearchKit/AMapSearchKit.h>
#import "CommonUtility.h"
#import "MANaviRoute.h"
#import <objc/runtime.h>

static const NSInteger RoutePlanningPaddingEdge = 20;
static const NSString *RoutePlanningViewControllerStartTitle = @"起点";
static const NSString *RoutePlanningViewControllerDestinationTitle = @"终点";

@interface AMapViewController ()<MAMapViewDelegate, AMapSearchDelegate>
{
    BOOL _showTraffic;
}
@property (nonatomic,strong) MAMapView *mapView;
@property (nonatomic,strong) FlutterMethodChannel *channel;
@property (nonatomic,assign) int64_t viewId;
@property (nonatomic,strong) NSObject<FlutterPluginRegistrar>* registrar;

@property (nonatomic,strong) AMapMarkerController *markerController;
@property (nonatomic,strong) AMapPolylineController *polylinesController;
@property (nonatomic,strong) AMapPolygonController *polygonsController;
@property (nonatomic,strong) AMapClusterController *clusterController;

@property (nonatomic,copy) FlutterResult waitForMapCallBack;//waitForMap的回调，仅当地图没有加载完成时缓存使用
@property (nonatomic,assign) BOOL mapInitCompleted;//地图初始化完成，首帧回调的标记

@property (nonatomic,assign) MAMapRect initLimitMapRect;//初始化时，限制的地图范围；如果为{0,0,0,0},则没有限制

@property (nonatomic, strong) NSArray *clusterArray;

/* 路径规划 */

/// 地图内的搜索API类
@property (strong, nonatomic) AMapSearchAPI *search;
/// 路径规划信息
@property (strong, nonatomic) AMapRoute *route;
/// 用于显示当前路线方案.
@property (strong, nonatomic) MANaviRoute *naviRoute;

@end


@implementation AMapViewController

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    if (self = [super init]) {
        NSAssert([args isKindOfClass:[NSDictionary class]], @"传参错误");
        //构建methedChannel
        NSString* channelName =
        [NSString stringWithFormat:@"amap_flutter_map_%lld", viewId];
        _channel = [FlutterMethodChannel methodChannelWithName:channelName
                                               binaryMessenger:registrar.messenger];
        
        NSDictionary *dict = args;
        
        NSDictionary *apiKey = dict[@"apiKey"];
        if (apiKey && [apiKey isKindOfClass:[NSDictionary class]]) {
            NSString *iosKey = apiKey[@"iosKey"];
            if (iosKey && iosKey.length > 0) {//通过flutter传入key，则再重新设置一次key
                [AMapServices sharedServices].apiKey = iosKey;
            }
        }
        
        // 需要先提示隐私状态，才可以初始化mapview
        [MAMapView updatePrivacyShow:AMapPrivacyShowStatusDidShow privacyInfo:AMapPrivacyInfoStatusDidContain];
        [MAMapView updatePrivacyAgree:AMapPrivacyAgreeStatusDidAgree];
        
        //这里统一检查key的设置是否生效
        NSAssert(([AMapServices sharedServices].apiKey != nil), @"没有设置APIKey，请先设置key");
        
        NSDictionary *cameraDict = [dict objectForKey:@"initialCameraPosition"];
        AMapCameraPosition *cameraPosition = [AMapJsonUtils modelFromDict:cameraDict modelClass:[AMapCameraPosition class]];
        
        _viewId = viewId;
        
        self.mapInitCompleted = NO;
        _mapView = [[MAMapView alloc] initWithFrame:frame];
        _mapView.delegate = self;
        _mapView.accessibilityElementsHidden = NO;
        [_mapView setCameraPosition:cameraPosition animated:NO duration:0];
        _registrar = registrar;
        [self.mapView updateMapViewOption:[dict objectForKey:@"options"] withRegistrar:_registrar];
        self.initLimitMapRect = [self getLimitMapRectFromOption:[dict objectForKey:@"options"]];
        if (MAMapRectIsEmpty(self.initLimitMapRect) == NO) {//限制了显示区域，则添加KVO监听
            [_mapView addObserver:self forKeyPath:@"frame" options:0 context:nil];
        }
        
        _markerController = [[AMapMarkerController alloc] init:_channel
                                                       mapView:_mapView
                                                     registrar:registrar];
        _polylinesController = [[AMapPolylineController alloc] init:_channel
                                                            mapView:_mapView
                                                          registrar:registrar];
        _polygonsController = [[AMapPolygonController alloc] init:_channel
                                                          mapView:_mapView
                                                        registrar:registrar];
        
        _clusterController = [[AMapClusterController alloc] init:_channel
                                                         mapView:_mapView
                                                       registrar:registrar];
        
        id markersToAdd = args[@"markersToAdd"];
        if ([markersToAdd isKindOfClass:[NSArray class]]) {
            [_markerController addMarkers:markersToAdd];
        }
        id polylinesToAdd = args[@"polylinesToAdd"];
        if ([polylinesToAdd isKindOfClass:[NSArray class]]) {
            [_polylinesController addPolylines:polylinesToAdd];
        }
        id polygonsToAdd = args[@"polygonsToAdd"];
        if ([polygonsToAdd isKindOfClass:[NSArray class]]) {
            [_polygonsController addPolygons:polygonsToAdd];
        }
        id clustersToAdd = args[@"clustersToAdd"];
        if ([clustersToAdd isKindOfClass:[NSArray class]]) {
            _clusterArray = clustersToAdd;
            NSLog(@"%@",clustersToAdd);
        }
        
        [self setMethodCallHandler];
    }
    return self;
}

- (UIView*)view {
    return _mapView;
}

- (void)dealloc {
    if (MAMapRectIsEmpty(_initLimitMapRect) == NO) {//避免没有开始渲染，frame监听还存在时，快速销毁
        [_mapView removeObserver:self forKeyPath:@"frame"];
    }
}

- (MAMapRect)getLimitMapRectFromOption:(NSDictionary *)dict {
    NSArray *limitBounds = dict[@"limitBounds"];
    if (limitBounds) {
        return [AMapConvertUtil mapRectFromArray:limitBounds];
    } else {
        return MAMapRectMake(0, 0, 0, 0);
    }
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {
    if (MAMapRectIsEmpty(self.initLimitMapRect) == YES ) {//初始化时，没有设置显示范围，则不再监听frame的变化
        [_mapView removeObserver:self forKeyPath:@"frame"];
        return;
    }
    if (object == _mapView && [keyPath isEqualToString:@"frame"]) {
        CGRect bounds = _mapView.bounds;
        if (CGRectEqualToRect(bounds, CGRectZero)) {
            // 忽略初始化时，frame为0的情况，仅当frame更新为非0时，才设置limitRect
            return;
        }
        //监听到一次，就直接移除KVO
        [_mapView removeObserver:self forKeyPath:@"frame"];
        if (MAMapRectIsEmpty(self.initLimitMapRect) == NO) {
            //加0.1s的延迟，确保地图的frame和内部引擎都已经更新
            MAMapRect tempLimitMapRect = self.initLimitMapRect;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.mapView.limitMapRect = tempLimitMapRect;
            });
            //避免KVO短时间触发多次，造成多次延迟派发
            self.initLimitMapRect = MAMapRectMake(0, 0, 0, 0);
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (void)setMethodCallHandler {
    __weak __typeof__(self) weakSelf = self;
    [self.channel addMethodName:@"map#update" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        [weakSelf.mapView updateMapViewOption:call.arguments[@"options"] withRegistrar:weakSelf.registrar];
        result(nil);
    }];
    [self.channel addMethodName:@"map#waitForMap" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        if (weakSelf.mapInitCompleted) {
            result(nil);
        } else {
            weakSelf.waitForMapCallBack = result;
        }
    }];
    [self.channel addMethodName:@"camera#move" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        [weakSelf.mapView setCameraUpdateDict:call.arguments];
        result(nil);
    }];
    [self.channel addMethodName:@"map#takeSnapshot" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        [weakSelf.mapView takeSnapshotInRect:weakSelf.mapView.frame withCompletionBlock:^(UIImage *resultImage, NSInteger state) {
            if (state == 1 && resultImage) {
                NSData *data = UIImagePNGRepresentation(resultImage);
                result([FlutterStandardTypedData typedDataWithBytes:data]);
            } else if (state == 0) {
                NSLog(@"takeSnapsShot 载入不完整");
            }
        }];
    }];
    [self.channel addMethodName:@"map#setRenderFps" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        NSInteger fps = [call.arguments[@"fps"] integerValue];
        [weakSelf.mapView setMaxRenderFrame:fps];
        result(nil);
    }];
    [self.channel addMethodName:@"map#contentApprovalNumber" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        NSString *approvalNumber = [weakSelf.mapView mapContentApprovalNumber];
        result(approvalNumber);
    }];
    [self.channel addMethodName:@"map#satelliteImageApprovalNumber" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        NSString *sateApprovalNumber = [weakSelf.mapView satelliteImageApprovalNumber];
        result(sateApprovalNumber);
    }];
    [self.channel addMethodName:@"map#clearDisk" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        [weakSelf.mapView clearDisk];
        result(nil);
    }];
    [self.channel addMethodName:@"map#drivingRouteSearch" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        NSDictionary *dic = call.arguments;
        if (dic) {
            
            NSArray<NSNumber *> *start_latLng = dic[@"startLatLng"];
            NSArray<NSNumber *> *destination_latLng = dic[@"destinationLatLng"];
            
            NSNumber *strategy_num = dic[@"strategy"];
            
            NSNumber *showTraffic_num = dic[@"showTraffic"];
            
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
            
            [weakSelf searchRoutePlanningDrive:startCoordinate destinationCoordinate:destinationCoordinate strategy:[strategy_num integerValue] showTraffic:showTraffic_num.boolValue];
            
            result(@YES);
        } else {
            result(FlutterMethodNotImplemented);
        }
    }];
}

//驾车路线开始规划

- (void)searchRoutePlanningDrive:(CLLocationCoordinate2D)startCoordinate
           destinationCoordinate:(CLLocationCoordinate2D)destinationCoordinate
                        strategy:(NSInteger)strategy
                     showTraffic:(BOOL)showTraffic {
    
    _showTraffic = showTraffic;
//    
    AMapPOISearchBaseRequest *navi = [[AMapPOISearchBaseRequest alloc] init];
//    navi.requireExtension = YES;
//    navi.strategy = strategy; //驾车导航策略,5-多策略（同时使用速度优先、费用优先、距离优先三个策略）
//    
//    /* 出发点. */
//    navi.origin = [AMapGeoPoint locationWithLatitude:startCoordinate.latitude
//                                           longitude:startCoordinate.longitude];
//    /* 目的地. */
//    navi.destination = [AMapGeoPoint locationWithLatitude:destinationCoordinate.latitude
//                                                longitude:destinationCoordinate.longitude];
    
//    [self.search AMapDrivingRouteSearch:navi];
}

- (void)searchRoutePlanningDrive:(CLLocationCoordinate2D)startCoordinate
           destinationCoordinate:(CLLocationCoordinate2D)destinationCoordinate strategy:(NSInteger)strategy {
    
    [self searchRoutePlanningDrive:startCoordinate destinationCoordinate:destinationCoordinate strategy:strategy showTraffic:NO];
}

//model转化为字典
- (NSDictionary *)dicFromObject:(__kindof NSObject *)object {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList([object class], &count);
    
    for (int i = 0; i < count; i++) {
        objc_property_t property = propertyList[i];
        const char *cName = property_getName(property);
        NSString *name = [NSString stringWithUTF8String:cName];
        NSObject *value = [object valueForKey:name];//valueForKey返回的数字和字符串都是对象
        
        if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
            //string , bool, int ,NSinteger
            [dic setObject:value forKey:name];
            
        } else if ([value isKindOfClass:[NSArray class]]) {
            //数组或字典
            [dic setObject:[self arrayWithObject:value] forKey:name];
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            //数组或字典
            [dic setObject:[self dicWithObject:value] forKey:name];
        } else if (value == nil) {
            //null
            //[dic setObject:[NSNull null] forKey:name];//这行可以注释掉?????
        } else {
            //model
            [dic setObject:[self dicFromObject:value] forKey:name];
        }
    }
    
    return [dic copy];
}

- (NSArray *)arrayWithObject:(id)object {
    //数组
    NSMutableArray *array = [NSMutableArray array];
    NSArray *originArr = (NSArray *)object;
    if ([originArr isKindOfClass:[NSArray class]]) {
        for (NSObject *object in originArr) {
            if ([object isKindOfClass:[NSString class]]||[object isKindOfClass:[NSNumber class]]) {
                //string , bool, int ,NSinteger
                [array addObject:object];
            } else if ([object isKindOfClass:[NSArray class]]) {
                //数组或字典
                [array addObject:[self arrayWithObject:object]];
            } else if ([object isKindOfClass:[NSDictionary class]]) {
                //数组或字典
                [array addObject:[self dicWithObject:object]];
            } else {
                //model
                [array addObject:[self dicFromObject:object]];
            }
        }
        return [array copy];
    }
    return array.copy;
}

- (NSDictionary *)dicWithObject:(id)object {
    //字典
    NSDictionary *originDic = (NSDictionary *)object;
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    if ([object isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in originDic.allKeys) {
            id object = [originDic objectForKey:key];
            if ([object isKindOfClass:[NSString class]]||[object isKindOfClass:[NSNumber class]]) {
                //string , bool, int ,NSinteger
                [dic setObject:object forKey:key];
            } else if ([object isKindOfClass:[NSArray class]]) {
                //数组或字典
                [dic setObject:[self arrayWithObject:object] forKey:key];
            } else if ([object isKindOfClass:[NSDictionary class]]) {
                //数组或字典
                [dic setObject:[self dicWithObject:object] forKey:key];
            } else {
                //model
                [dic setObject:[self dicFromObject:object] forKey:key];
            }
        }
        return [dic copy];
    }
    return dic.copy;
}


//MARK: Getter

- (AMapSearchAPI *)search {
    if (!_search) {
        _search = [[AMapSearchAPI alloc] init];
        _search.delegate = self;
    }
    return _search;
}

//MARK: AMapSearchDelegate

//当路径规划搜索请求发生错误时，会调用代理的此方法
- (void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error {
    NSLog(@"Error: %@", error);
//    [self resetSearchResultAndXibViewsToDefault];
}

//路径规划搜索完成回调.
- (void)onRouteSearchDone:(AMapRouteSearchBaseRequest *)request response:(AMapRouteSearchResponse *)response {
    if (response.route == nil){
//        [self resetSearchResultAndXibViewsToDefault];
        return;
    }
    
    self.route = response.route;
    
    NSInteger totalRouteNums = self.route.paths.count;
    NSInteger currentRouteIndex = 0;
//    self.switchRouteBtn.enabled = self.routeDetailBtn.enabled = self.showTrafficSwitch.enabled = self.totalRouteNums > 0;
//    self.infoLabel.text = @"";
    
    [self presentCurrentRouteCourseResponse:response];
}

//在地图上显示当前选择的路径
- (void)presentCurrentRouteCourseResponse:(AMapRouteSearchResponse *)response {
    NSInteger totalRouteNums = self.route.paths.count;
    
    if (totalRouteNums <= 0) {
        return;
    }
    //清空地图上已有的路线
    if (self.naviRoute) {
        [self.naviRoute removeFromMapView];
    }
    
    [_channel invokeMethod:@"map#onDrivingRouteResult" arguments:@{@"mapRoute" : [AMapJsonUtils jsonObjectFromModel:response.route]}];
    
    MANaviAnnotationType type = MANaviAnnotationTypeDrive; //驾车类型
    
    AMapGeoPoint *startPoint = response.route.origin; //起点
    
    AMapGeoPoint *endPoint = response.route.destination;  //终点
    
    //根据已经规划的路径，起点，终点，规划类型，是否显示实时路况，生成显示方案
    self.naviRoute = [MANaviRoute naviRouteForPath:self.route.paths[0] withNaviType:type showTraffic:_showTraffic startPoint:startPoint endPoint:endPoint];
    
    [self.naviRoute addToMapView:self.mapView];  //显示到地图上
    
    UIEdgeInsets edgePaddingRect = UIEdgeInsetsMake(RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge);
    
    //缩放地图使其适应polylines的展示
    [self.mapView setVisibleMapRect:[CommonUtility mapRectForOverlays:self.naviRoute.routePolylines]
                        edgePadding:edgePaddingRect
                           animated:NO];
}

//MARK: MAMapViewDelegate

//MARK: 定位相关回调

- (void)mapView:(MAMapView *)mapView didChangeUserTrackingMode:(MAUserTrackingMode)mode animated:(BOOL)animated {
    NSLog(@"%s,mapView:%@ mode:%ld",__func__,mapView,(long)mode);
}
/**
 * @brief 在地图View将要启动定位时，会调用此函数
 * @param mapView 地图View
 */
- (void)mapViewWillStartLocatingUser:(MAMapView *)mapView {
    NSLog(@"%s,mapView:%@",__func__,mapView);
}

/**
 * @brief 在地图View停止定位后，会调用此函数
 * @param mapView 地图View
 */
- (void)mapViewDidStopLocatingUser:(MAMapView *)mapView {
    NSLog(@"%s,mapView:%@",__func__,mapView);
}

/**
 * @brief 位置或者设备方向更新后，会调用此函数
 * @param mapView 地图View
 * @param userLocation 用户定位信息(包括位置与设备方向等数据)
 * @param updatingLocation 标示是否是location数据更新, YES:location数据更新 NO:heading数据更新
 */
- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation {
    if (updatingLocation && userLocation.location) {
        AMapLocation *location = [[AMapLocation alloc] init];
        [location updateWithUserLocation:userLocation.location];
        NSDictionary *jsonObjc = [AMapJsonUtils jsonObjectFromModel:location];
        NSArray *latlng = [AMapConvertUtil jsonArrayFromCoordinate:location.latLng];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:jsonObjc];
        [dict setValue:latlng forKey:@"latLng"];
        [_channel invokeMethod:@"location#changed" arguments:@{@"location" : dict}];
    }
}

/**
 *  @brief 当plist配置NSLocationAlwaysUsageDescription或者NSLocationAlwaysAndWhenInUseUsageDescription，并且[CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined，会调用代理的此方法。
 此方法实现调用后台权限API即可（ 该回调必须实现 [locationManager requestAlwaysAuthorization] ）; since 6.8.0
 *  @param locationManager  地图的CLLocationManager。
 */
- (void)mapViewRequireLocationAuth:(CLLocationManager *)locationManager {
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        [locationManager requestAlwaysAuthorization];
    }
}

/**
 * @brief 定位失败后，会调用此函数
 * @param mapView 地图View
 * @param error 错误号，参考CLError.h中定义的错误号
 */
- (void)mapView:(MAMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    NSLog(@"%s,mapView:%@ error:%@",__func__,mapView,error);
}


/**
 * @brief 地图加载成功
 * @param mapView 地图View
 */
- (void)mapViewDidFinishLoadingMap:(MAMapView *)mapView {
    NSLog(@"%s,mapView:%@",__func__,mapView);
}

- (void)mapInitComplete:(MAMapView *)mapView {
    NSLog(@"%s,mapView:%@",__func__,mapView);
    self.mapInitCompleted = YES;
    if (self.waitForMapCallBack) {
        self.waitForMapCallBack(nil);
        self.waitForMapCallBack = nil;
    }
}

//MARK: Annotation相关回调

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation {
    
    if ([annotation isKindOfClass:[ClusterAnnotation class]]) {
        /* dequeue重用annotationView. */
        static NSString *const AnnotatioViewReuseID = @"AnnotatioViewReuseID";
        
        ClusterAnnotationView *annotationView = (ClusterAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:AnnotatioViewReuseID];
        
        if (!annotationView) {
            annotationView = [[ClusterAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotatioViewReuseID];
        }
        
        /* 设置annotationView的属性. */
        annotationView.annotation = annotation;
        annotationView.count = [(ClusterAnnotation *)annotation count];
        /* 不弹出原生annotation */
        annotationView.canShowCallout = NO;
        
        ClusterAnnotation *an = (ClusterAnnotation *)annotation;
        BOOL haveWarning = false;
        //判断是否存在告警
        for (AMapPOI *poi in an.pois) {
            NSDictionary * dic =(NSDictionary *)[AMapJsonUtils stringToJson:poi.address];
            if ([dic.allKeys containsObject:@"warning_num"] && [dic[@"warning_num"] intValue]>0) {
                haveWarning = true;
            }
        }
        // annotationView.hasWarning = haveWarning;
        return annotationView;
    }
    
    MAPointAnnotation *fAnno = (MAPointAnnotation *)annotation;
    
    if (fAnno.markerId == nil) {
        // 路径规划拐点的图标标注
        if ([annotation isKindOfClass:[MANaviAnnotation class]]) {
            //标注的view的初始化和复用
            static NSString *routePlanningCellIdentifier = @"RoutePlanningCellIdentifier";
            
            MAAnnotationView *poiAnnotationView = (MAAnnotationView*)[self.mapView dequeueReusableAnnotationViewWithIdentifier:routePlanningCellIdentifier];
            
            if (poiAnnotationView == nil) {
                poiAnnotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:routePlanningCellIdentifier];
            }
            
            poiAnnotationView.canShowCallout = YES;
            poiAnnotationView.image = nil;
            
            switch (((MANaviAnnotation*)annotation).type) {
                case MANaviAnnotationTypeRailway:
                    poiAnnotationView.image = [UIImage imageNamed:@"railway_station"];
                    break;
                    
                case MANaviAnnotationTypeBus:
                    poiAnnotationView.image = [UIImage imageNamed:@"bus"];
                    break;
                    
                case MANaviAnnotationTypeDrive:
                    poiAnnotationView.image = [UIImage imageNamed:@"car"];
                    break;
                    
                case MANaviAnnotationTypeWalking:
                    poiAnnotationView.image = [UIImage imageNamed:@"man"];
                    break;
                    
                default:
                    break;
            }
            return poiAnnotationView;
        }
        
        return nil;
    }
    
    if ([annotation isKindOfClass:[MAPointAnnotation class]] == NO) {
        return nil;
    }
    
    AMapMarker *marker = [_markerController markerForId:fAnno.markerId];
    //    TODO: 这里只实现基础AnnotationView，不再根据marker的数据差异，区分是annotationView还是pinAnnotationView了；
    MAAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:AMapFlutterAnnotationViewIdentifier];
    if (view == nil) {
        view = [[MAAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AMapFlutterAnnotationViewIdentifier];
    }
    [view updateViewWithMarker:marker];
    return view;
}

/**
 * @brief 当mapView新添加annotation views时，调用此接口
 * @param mapView 地图View
 * @param views 新添加的annotation views
 */
- (void)mapView:(MAMapView *)mapView didAddAnnotationViews:(NSArray *)views {
    for (MAAnnotationView *view in views) {
        if ([view.annotation isKindOfClass:[MAAnnotationView class]] == NO) {
            return;
        }
        MAPointAnnotation *fAnno = view.annotation;
        if (fAnno.markerId == nil) {
            return;
        }
        AMapMarker *marker = [_markerController markerForId:fAnno.markerId];
        [view updateViewWithMarker:marker];
    }
}


/**
 * @brief 标注view的calloutview整体点击时，触发该回调。只有使用默认calloutview时才生效。
 * @param mapView 地图的view
 * @param view calloutView所属的annotationView
 */
//- (void)mapView:(MAMapView *)mapView didAnnotationViewCalloutTapped:(MAAnnotationView *)view {
//    MAPointAnnotation *fAnno = view.annotation;
//    if (fAnno.markerId == nil) {
//        return;
//    }
//    [_markerController onInfoWindowTap:fAnno.markerId];
//}

/**
 * @brief 标注view被点击时，触发该回调。（since 5.7.0）
 * @param mapView 地图的view
 * @param view annotationView
 */
- (void)mapView:(MAMapView *)mapView didAnnotationViewTapped:(MAAnnotationView *)view {
    
    MAPointAnnotation *fAnno = (MAPointAnnotation *)view.annotation;
    
    if ([fAnno isKindOfClass:[ClusterAnnotation class]]) {
        ClusterAnnotation *annotation = (ClusterAnnotation *)view.annotation;
        if (annotation.pois.count != 0) {
            AMapPOI *poi = annotation.pois[0];
            BOOL isSame = YES;
            if (annotation.pois.count > 1) {
                for (AMapPOI* p in annotation.pois) {
                    if (![poi.address isEqualToString:p.address]) {
                        isSame = NO;
                    }
                }
            }
            //点击聚合点 回传数据
            if(annotation.pois.count==1|| isSame){
              
                NSMutableDictionary * dic = [[NSMutableDictionary alloc]init];
                [dic setObject:poi.address forKey:@"data"];
                [dic setObject:@{@"latitude":@(poi.location.latitude),@"longitude":@(poi.location.longitude)} forKey:@"position"];
                [self.channel invokeMethod:@"cluster#onTap" arguments:@{@"items" :[AMapJsonUtils jsonToString:dic]}];
            }
        }
    } else {
        if (fAnno.markerId == nil) {
            return;
        }
        [_markerController onMarkerTap:fAnno.markerId];
    }
}

/**
 * @brief 拖动annotation view时view的状态变化
 * @param mapView 地图View
 * @param view annotation view
 * @param newState 新状态
 * @param oldState 旧状态
 */
- (void)mapView:(MAMapView *)mapView annotationView:(MAAnnotationView *)view didChangeDragState:(MAAnnotationViewDragState)newState
   fromOldState:(MAAnnotationViewDragState)oldState {
    if (newState == MAAnnotationViewDragStateEnding) {
        MAPointAnnotation *fAnno = view.annotation;
        if (fAnno.markerId == nil) {
            return;
        }
        [_markerController onMarker:fAnno.markerId endPostion:fAnno.coordinate];
    }
}

/**
 * @brief 根据overlay生成对应的Renderer
 * @param mapView 地图View
 * @param overlay 指定的overlay
 * @return 生成的覆盖物Renderer
 */
- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay {
    
    //虚线，如需要步行的
    if ([overlay isKindOfClass:[LineDashPolyline class]]) {
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:((LineDashPolyline *)overlay).polyline];
        polylineRenderer.lineWidth = 6;
        polylineRenderer.lineDashType = kMALineDashTypeSquare;
        polylineRenderer.strokeColor = [UIColor redColor];
        
        return polylineRenderer;
    }
    
    //showTraffic为NO时，不需要带实时路况，路径为单一颜色，比如驾车线路目前为blueColor
    if ([overlay isKindOfClass:[MANaviPolyline class]]) {
        MANaviPolyline *naviPolyline = (MANaviPolyline *)overlay;
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:naviPolyline.polyline];
        
        polylineRenderer.lineWidth = 6;
        
        if (naviPolyline.type == MANaviAnnotationTypeWalking) {
            polylineRenderer.strokeColor = self.naviRoute.walkingColor;
        } else if (naviPolyline.type == MANaviAnnotationTypeRailway) {
            polylineRenderer.strokeColor = self.naviRoute.railwayColor;
        } else {
            polylineRenderer.strokeColor = self.naviRoute.routeColor;
        }
        
        return polylineRenderer;
    }
    
    //showTraffic为YES时，需要带实时路况，路径为多颜色渐变
    if ([overlay isKindOfClass:[MAMultiPolyline class]]) {
        MAMultiColoredPolylineRenderer * polylineRenderer = [[MAMultiColoredPolylineRenderer alloc] initWithMultiPolyline:overlay];
        
        polylineRenderer.lineWidth = 6;
        polylineRenderer.strokeColors = [self.naviRoute.multiPolylineColors copy];
        
        return polylineRenderer;
    }
    
    if ([overlay isKindOfClass:[MAPolyline class]]) {
        MAPolyline *polyline = overlay;
        if (polyline.polylineId == nil) {
            return nil;
        }
        AMapPolyline *fPolyline = [_polylinesController polylineForId:polyline.polylineId];
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        [polylineRenderer updateRenderWithPolyline:fPolyline];
        return polylineRenderer;
    } else if ([overlay isKindOfClass:[MAPolygon class]]) {
        MAPolygon *polygon = overlay;
        if (polygon.polygonId == nil) {
            return nil;
        }
        AMapPolygon *fPolygon = [_polygonsController polygonForId:polygon.polygonId];
        MAPolygonRenderer *polygonRenderer = [[MAPolygonRenderer alloc] initWithPolygon:polygon];
        [polygonRenderer updateRenderWithPolygon:fPolygon];
        return polygonRenderer;
    } else {
        return nil;
    }
}

/**
 * @brief 单击地图回调，返回经纬度
 * @param mapView 地图View
 * @param coordinate 经纬度
 */
- (void)mapView:(MAMapView *)mapView didSingleTappedAtCoordinate:(CLLocationCoordinate2D)coordinate {
    NSArray *latLng = [AMapConvertUtil jsonArrayFromCoordinate:coordinate];
    [_channel invokeMethod:@"map#onTap" arguments:@{@"latLng":latLng}];
    NSArray *polylineRenderArray = [mapView getHittedPolylinesWith:coordinate traverseAll:NO];
    if (polylineRenderArray && polylineRenderArray.count > 0) {
        MAOverlayRenderer *render = polylineRenderArray.firstObject;
        MAPolyline *polyline = render.overlay;
        if (polyline.polylineId) {
            [_polylinesController onPolylineTap:polyline.polylineId];
        }
    }
}

/**
 * @brief 长按地图，返回经纬度
 * @param mapView 地图View
 * @param coordinate 经纬度
 */
- (void)mapView:(MAMapView *)mapView didLongPressedAtCoordinate:(CLLocationCoordinate2D)coordinate {
    NSArray *latLng = [AMapConvertUtil jsonArrayFromCoordinate:coordinate];
    [_channel invokeMethod:@"map#onLongPress" arguments:@{@"latLng":latLng}];
}

/**
 * @brief 当touchPOIEnabled == YES时，单击地图使用该回调获取POI信息
 * @param mapView 地图View
 * @param pois 获取到的poi数组(由MATouchPoi组成)
 */
- (void)mapView:(MAMapView *)mapView didTouchPois:(NSArray *)pois {
    MATouchPoi *poi = pois.firstObject;
    NSDictionary *dict = [AMapConvertUtil dictFromTouchPOI:poi];
    if (dict) {
        [_channel invokeMethod:@"map#onPoiTouched" arguments:@{@"poi":dict}];
    }
}

/**
 * @brief 地图区域改变过程中会调用此接口 since 4.6.0
 * @param mapView 地图View
 */
- (void)mapViewRegionChanged:(MAMapView *)mapView {
//    TODO: 这里消息回调太多，channel可能有性能影响
    AMapCameraPosition *cameraPos = [mapView getCurrentCameraPosition];
    NSDictionary *dict = [cameraPos toDictionary];
    if (dict) {
        [_channel invokeMethod:@"camera#onMove" arguments:@{@"position":dict}];
    }
}

/**
 * @brief 地图区域改变完成后会调用此接口
 * @param mapView 地图View
 * @param animated 是否动画
 */
- (void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    AMapCameraPosition *cameraPos = [mapView getCurrentCameraPosition];
    NSDictionary *dict = [cameraPos toDictionary];
    if (dict) {
        [_channel invokeMethod:@"camera#onMoveEnd" arguments:@{@"position":dict}];
    }
    
    if(_clusterArray.count != 0){
        [_clusterController addClusters:_clusterArray];
    }
}

@end
