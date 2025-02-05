//
//  ClusterAnnotationView.m
//  officialDemo2D
//
//  Created by yi chen on 14-5-15.
//  Copyright (c) 2014年 AutoNavi. All rights reserved.
//

#import "ClusterAnnotationView.h"
#import "ClusterAnnotation.h"
#import <UIKit/UIBezierPath.h>

static CGFloat const ScaleFactorAlpha = 0.3;
static CGFloat const ScaleFactorBeta = 0.4;

/* 返回rect的中心. */
CGPoint RectCenter(CGRect rect)
{
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

/* 返回中心为center，尺寸为rect.size的rect. */
CGRect CenterRect(CGRect rect, CGPoint center)
{
    CGRect r = CGRectMake(center.x - rect.size.width/2.0,
                          center.y - rect.size.height/2.0,
                          rect.size.width,
                          rect.size.height);
    return r;
}

/* 根据count计算annotation的scale. */
CGFloat ScaledValueForValue(CGFloat value)
{
    return 1.0 / (1.0 + expf(-1 * ScaleFactorAlpha * powf(value, ScaleFactorBeta)));
}

#pragma mark -

@interface ClusterAnnotationView ()

@property (nonatomic, strong) UILabel *countLabel;

@end

@implementation ClusterAnnotationView

#pragma mark Initialization

- (id)initWithAnnotation:(id<MAAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        self.image = [self generateCircleImage];
        [self setupLabel];
        [self setCount:1];
    }
    
    return self;
}

#pragma mark Utility

- (void)setupLabel
{
    _countLabel = [[UILabel alloc] initWithFrame:self.frame];
    _countLabel.backgroundColor = [UIColor clearColor];
    _countLabel.textColor       = [UIColor whiteColor];
    _countLabel.textAlignment   = NSTextAlignmentCenter;
//    _countLabel.shadowColor     = [UIColor colorWithWhite:0.0 alpha:0.75];
//    _countLabel.shadowOffset    = CGSizeMake(0, -1);
    _countLabel.adjustsFontSizeToFitWidth = YES;
    _countLabel.numberOfLines = 1;
    _countLabel.font = [UIFont boldSystemFontOfSize:18];
    _countLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [self addSubview:_countLabel];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    NSArray *subViews = self.subviews;
    if ([subViews count] > 1)
    {
        for (UIView *aSubView in subViews)
        {
            if ([aSubView pointInside:[self convertPoint:point toView:aSubView] withEvent:event])
            {
                return YES;
            }
        }
    }
    if (point.x > 0 && point.x < self.frame.size.width && point.y > 0 && point.y < self.frame.size.height)
    {
        return YES;
    }
    return NO;
}

- (void)setCount:(NSUInteger)count
{
    _count = count;
    
    /* 按count数目设置view的大小. */
//    CGRect newBounds = CGRectMake(0, 0, roundf(44 * ScaledValueForValue(count)), roundf(44 * ScaledValueForValue(count)));
//    self.frame = CenterRect(newBounds, self.center);
    CGRect newBounds = CGRectMake(0, 0, 44, 44);
    self.frame = CenterRect(newBounds, self.center);
    
    CGRect newLabelBounds = CGRectMake(0, 0, newBounds.size.width / 1.3, newBounds.size.height / 1.3);
    self.countLabel.frame = CenterRect(newLabelBounds, RectCenter(newBounds));
    self.countLabel.text = [@(_count) stringValue];
    
    [self setNeedsDisplay];
}

#pragma mark - annimation

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    
    [self addBounceAnnimation];
}

- (void)addBounceAnnimation
{
    CAKeyframeAnimation *bounceAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    
    bounceAnimation.values = @[@(0.05), @(1.1), @(0.9), @(1)];
    bounceAnimation.duration = 0.6;
    
    NSMutableArray *timingFunctions = [[NSMutableArray alloc] initWithCapacity:bounceAnimation.values.count];
    for (NSUInteger i = 0; i < bounceAnimation.values.count; i++)
    {
        [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    }
    [bounceAnimation setTimingFunctions:timingFunctions.copy];
    
    bounceAnimation.removedOnCompletion = NO;
    
    [self.layer addAnimation:bounceAnimation forKey:@"bounce"];
}

#pragma mark generate circle image

// 生成圆形图片
- (UIImage *)generateCircleImage {
    CGRect circleFrame = CGRectMake(0, 0, 42, 42);
    UIColor *innerCircleStrokeColor = [UIColor colorWithRed:(55.0 / 255.0) green:(108 / 255.0) blue:(128 / 255.0) alpha:0.7];
    // rgba(55, 108, 128, 0.7)
    UIColor *innerCircleFillColor = [UIColor colorWithRed:(55.0 / 255.0) green:(108 / 255.0) blue:(128 / 255.0) alpha:0.7];
    
    
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithOvalInRect:circleFrame];
    // 裁剪上下文
    [bezierPath addClip];
    
    CAShapeLayer *circleLayer = [CAShapeLayer layer];
    circleLayer.path = bezierPath.CGPath;
    circleLayer.fillColor = innerCircleFillColor.CGColor;
    circleLayer.strokeColor = innerCircleStrokeColor.CGColor;
    circleLayer.lineWidth = 1.0;
    circleLayer.lineJoin = kCALineJoinRound;
    
    // circleFrame size width +1 height +1
    CGRect imageRect = circleFrame;
    imageRect.size.width += 2;
    imageRect.size.height += 2;
    
    // generate image
    UIGraphicsBeginImageContextWithOptions(imageRect.size, NO, 0.0);
    [circleLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *circleImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return circleImage;
}

//- (void)drawRect:(CGRect)rect
//{
//    CGContextRef context = UIGraphicsGetCurrentContext();
//    
//    CGContextSetAllowsAntialiasing(context, true);
//    
////    UIColor *outerCircleStrokeColor = [UIColor colorWithWhite:0 alpha:0.25];
////    UIColor *innerCircleStrokeColor = [UIColor whiteColor];
//    UIColor *innerCircleStrokeColor = [UIColor colorWithRed:(55.0 / 255.0) green:(108 / 255.0) blue:(128 / 255.0) alpha:0.7];
//    // rgba(55, 108, 128, 0.7)
//    UIColor *innerCircleFillColor = [UIColor colorWithRed:(55.0 / 255.0) green:(108 / 255.0) blue:(128 / 255.0) alpha:0.7];
////    UIColor *innerCircleFillColor = [UIColor colorWithRed:(255.0 / 255.0) green:(95 / 255.0) blue:(42 / 255.0) alpha:1.0];
//    
//    CGRect circleFrame = CGRectInset(rect, 42, 42);
//    
////    [outerCircleStrokeColor setStroke];
////    CGContextSetLineWidth(context, 5.0);
////    CGContextStrokeEllipseInRect(context, circleFrame);
//    
//    [innerCircleStrokeColor setStroke];
//    CGContextSetLineWidth(context, 1);
//    CGContextStrokeEllipseInRect(context, circleFrame);
//    
//    [innerCircleFillColor setFill];
//    CGContextFillEllipseInRect(context, circleFrame);
//}

@end
