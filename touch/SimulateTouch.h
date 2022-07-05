//
//  SimulateTouch.h
//  SimulateTouch
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#ifndef SimulateTouch_h
#define SimulateTouch_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

typedef NS_ENUM(NSUInteger, SimulateTouchRole) {
    SimulateTouchRoleClient = 0,
    SimulateTouchRoleServer,
};

@interface SimulateTouch : NSObject

@property (nonatomic, strong, readonly) CPDistributedMessagingCenter *messagingCenter;
@property (nonatomic, assign, readonly) SimulateTouchRole role;
@property (nonatomic, assign) BOOL shouldShowTouches;

+ (instancetype)sharedInstance;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

// Touches
- (void)touchDown:(CGPoint)coord;
- (void)touchDownAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY;
- (void)liftUp:(CGPoint)coord;
- (void)liftUpAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY;
- (void)touchDown:(CGPoint)coord touchCount:(NSUInteger)count;
- (void)touchDownAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY touchCount:(NSUInteger)count;
- (void)liftUp:(CGPoint)coord touchCount:(NSUInteger)count;
- (void)liftUpAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY touchCount:(NSUInteger)count;

// Taps
- (void)tap:(CGPoint)coord;
- (void)tapAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY;
- (void)doubleTap:(CGPoint)coord;
- (void)doubleTapAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY;
- (void)twoFingerTap:(CGPoint)coord;
- (void)twoFingerTapAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY;
- (void)threeFingerTap:(CGPoint)coord;
- (void)threeFingerTapAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY;

// Long Press
- (void)longPress:(CGPoint)coord;
- (void)longPressAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY;

// Drags
- (void)dragCurveWithStartPoint:(CGPoint)coordA endPoint:(CGPoint)coordB duration:(NSTimeInterval)duration;
- (void)dragCurveWithStartPointAtCoordinateX:(CGFloat)coordAX
                                 coordinateY:(CGFloat)coordAY
                       endPointAtCoordinateX:(CGFloat)coordBX
                                 coordinateY:(CGFloat)coordBY
                                    duration:(NSTimeInterval)duration;

// Pinches
- (void)pinchLinearInBounds:(CGRect)bounds
                      scale:(CGFloat)scale
                      angle:(CGFloat)angle
                   duration:(NSTimeInterval)seconds;
- (void)pinchLinearInBoundOriginX:(CGFloat)boundOriginX
                     boundOriginY:(CGFloat)boundOriginY
                   boundSizeWidth:(CGFloat)boundSizeWidth
                  boundSizeHeight:(CGFloat)boundSizeHeight
                            scale:(CGFloat)scale
                            angle:(CGFloat)angle
                         duration:(NSTimeInterval)seconds;

// Event Stream
- (void)sendEventStream:(NSDictionary *)eventInfo;

// ASCII Keyboard
- (void)sendText:(NSString *)characters;
- (void)keyPress:(NSString *)character;
- (void)keyDown:(NSString *)character;
- (void)keyUp:(NSString *)character;

// Home Button
- (void)menuPress;
- (void)menuDoublePress;
- (void)menuLongPress;
- (void)menuDown;
- (void)menuUp;

// Power Button
- (void)powerPress;
- (void)powerDoublePress;
- (void)powerTriplePress;
- (void)powerLongPress;
- (void)powerDown;
- (void)powerUp;

// Home + Power Button
- (void)snapshotPress;
- (void)toggleOnScreenKeyboard;
- (void)toggleSpotlight;

// Mute Trigger
- (void)mutePress;
- (void)muteDown;
- (void)muteUp;

// Volume Buttons
- (void)volumeIncrementPress;
- (void)volumeIncrementDown;
- (void)volumeIncrementUp;
- (void)volumeDecrementPress;
- (void)volumeDecrementDown;
- (void)volumeDecrementUp;

// Brightness Buttons
- (void)displayBrightnessIncrementPress;
- (void)displayBrightnessIncrementDown;
- (void)displayBrightnessIncrementUp;
- (void)displayBrightnessDecrementPress;
- (void)displayBrightnessDecrementDown;
- (void)displayBrightnessDecrementUp;

// Other Consumer Usages
- (void)otherConsumerUsagePress:(uint32_t)usage;
- (void)otherConsumerUsageDown:(uint32_t)usage;
- (void)otherConsumerUsageUp:(uint32_t)usage;

// Other Usages
- (void)otherPage:(uint32_t)page usagePress:(uint32_t)usage;
- (void)otherPage:(uint32_t)page usageDown:(uint32_t)usage;
- (void)otherPage:(uint32_t)page usageUp:(uint32_t)usage;

@end

#endif  /* SimulateTouch_h */
