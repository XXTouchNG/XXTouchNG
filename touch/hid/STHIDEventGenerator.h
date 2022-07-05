/*
 * Copyright (C) 2015 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "IOKitSPI.h"
#import <CoreGraphics/CGGeometry.h>


// Keys for `sendEventStream:`.
OBJC_EXTERN NSString *const TopLevelEventInfoKey;
OBJC_EXTERN NSString *const SecondLevelEventsKey;
OBJC_EXTERN NSString *const HIDEventInputType;
OBJC_EXTERN NSString *const HIDEventTimeOffsetKey;
OBJC_EXTERN NSString *const HIDEventTouchesKey;
OBJC_EXTERN NSString *const HIDEventPhaseKey;
OBJC_EXTERN NSString *const HIDEventInterpolateKey;
OBJC_EXTERN NSString *const HIDEventTimestepKey;
OBJC_EXTERN NSString *const HIDEventCoordinateSpaceKey;
OBJC_EXTERN NSString *const HIDEventStartEventKey;
OBJC_EXTERN NSString *const HIDEventEndEventKey;
OBJC_EXTERN NSString *const HIDEventTouchIDKey;
OBJC_EXTERN NSString *const HIDEventPressureKey;
OBJC_EXTERN NSString *const HIDEventXKey;
OBJC_EXTERN NSString *const HIDEventYKey;
OBJC_EXTERN NSString *const HIDEventTwistKey;
OBJC_EXTERN NSString *const HIDEventMaskKey;
OBJC_EXTERN NSString *const HIDEventMajorRadiusKey;
OBJC_EXTERN NSString *const HIDEventMinorRadiusKey;
OBJC_EXTERN NSString *const HIDEventFingerKey;

// Values for HIDEventInputType.
OBJC_EXTERN NSString *const HIDEventInputTypeHand;
OBJC_EXTERN NSString *const HIDEventInputTypeFinger;
OBJC_EXTERN NSString *const HIDEventInputTypeStylus;

// Values for HIDEventCoordinateSpaceKey.
OBJC_EXTERN NSString *const HIDEventCoordinateSpaceTypeGlobal;
OBJC_EXTERN NSString *const HIDEventCoordinateSpaceTypeContent;

OBJC_EXTERN NSString *const HIDEventInterpolationTypeLinear;
OBJC_EXTERN NSString *const HIDEventInterpolationTypeSimpleCurve;

// Values for HIDEventPhaseKey.
OBJC_EXTERN NSString *const HIDEventPhaseBegan;
OBJC_EXTERN NSString *const HIDEventPhaseMoved;
OBJC_EXTERN NSString *const HIDEventPhaseEnded;
OBJC_EXTERN NSString *const HIDEventPhaseCanceled;

// Values for touch counts, etc, to keep debug code in sync

OBJC_EXTERN NSUInteger const HIDMaxTouchCount;

@interface STHIDEventGenerator : NSObject

@property (nonatomic, assign) BOOL shouldShowTouches;

+ (STHIDEventGenerator *)sharedSTHIDEventGenerator;

/* MARK: --- Touches --- */

- (void)touchDown:(CGPoint)location;
- (void)liftUp:(CGPoint)location;
- (void)touchDown:(CGPoint)location
       touchCount:(NSUInteger)count;
- (void)liftUp:(CGPoint)location
    touchCount:(NSUInteger)count;

/* MARK: --- Stylus --- */

- (void)stylusDownAtPoint:(CGPoint)location
             azimuthAngle:(CGFloat)azimuthAngle
            altitudeAngle:(CGFloat)altitudeAngle
                 pressure:(CGFloat)pressure;

- (void)stylusMoveToPoint:(CGPoint)location
             azimuthAngle:(CGFloat)azimuthAngle
            altitudeAngle:(CGFloat)altitudeAngle
                 pressure:(CGFloat)pressure;

- (void)stylusUpAtPoint:(CGPoint)location;

// sync 0.05
- (void)stylusTapAtPoint:(CGPoint)location
            azimuthAngle:(CGFloat)azimuthAngle
           altitudeAngle:(CGFloat)altitudeAngle
                pressure:(CGFloat)pressure;

/* MARK: --- Taps --- */

// sync 0.05
- (void)tap:(CGPoint)location;

// sync 0.05 + 0.15 + 0.05 = 0.25
- (void)doubleTap:(CGPoint)location;

// sync 0.05
- (void)twoFingerTap:(CGPoint)location;

// sync 0.05
- (void)threeFingerTap:(CGPoint)location;

// sync 0.05 * tapCount + MAX(0.15, delay) * (tapCount - 1)
- (void)sendTaps:(NSUInteger)tapCount
        location:(CGPoint)location
 numberOfTouches:(NSUInteger)touchCount
delayBetweenTaps:(NSTimeInterval)delay;

/* MARK: --- Long Press --- */

// async 2.0
- (void)longPress:(CGPoint)location;

/* MARK: --- Drags --- */

// sync seconds
- (void)dragLinearWithStartPoint:(CGPoint)startLocation
                        endPoint:(CGPoint)endLocation
                        duration:(NSTimeInterval)seconds;

// sync seconds
- (void)dragCurveWithStartPoint:(CGPoint)startLocation
                       endPoint:(CGPoint)endLocation
                       duration:(NSTimeInterval)seconds;

/* MARK: --- Pinches --- */

// sync seconds
- (void)pinchLinearInBounds:(CGRect)bounds
                      scale:(CGFloat)scale
                      angle:(CGFloat)angle
                   duration:(NSTimeInterval)seconds;

/* MARK: --- Event Stream --- */

- (void)sendEventStream:(NSDictionary *)eventInfo;

/* MARK: --- ASCII Keyboard --- */

// sync 0.05
- (void)keyPress:(NSString *)character;

- (void)keyDown:(NSString *)character;
- (void)keyUp:(NSString *)character;

/* MARK: --- Home Button --- */

// sync 0.05
- (void)menuPress;

- (void)muteDown;  // not likely to use but preserved
- (void)muteUp;    // not likely to use but preserved

// sync 0.05 + 0.15 + 0.05 = 0.25
- (void)menuDoublePress;

// async 2.0
- (void)menuLongPress;

- (void)menuDown;
- (void)menuUp;

/* MARK: --- Power Button --- */

// sync 0.05
- (void)powerPress;

// sync 0.05 + 0.15 + 0.05 = 0.25
- (void)powerDoublePress;

// sync 0.05 + 0.15 + 0.05 + 0.15 + 0.05 = 0.45
- (void)powerTriplePress;

// async 2.0
- (void)powerLongPress;

- (void)powerDown;
- (void)powerUp;

/* MARK: --- Home + Power Button --- */

// sync 0.05
- (void)snapshotPress;

// sync 0.05
- (void)toggleOnScreenKeyboard;

// sync 0.05
- (void)toggleSpotlight;

/* MARK: --- Mute Trigger --- */

// sync 0.05
- (void)mutePress;

/* MARK: --- Volume Buttons --- */

// sync 0.05
- (void)volumeIncrementPress;

- (void)volumeIncrementDown;
- (void)volumeIncrementUp;

// sync 0.05
- (void)volumeDecrementPress;

- (void)volumeDecrementDown;
- (void)volumeDecrementUp;

/* MARK: --- Brightness Buttons --- */

// sync 0.05
- (void)displayBrightnessIncrementPress;

- (void)displayBrightnessIncrementDown;
- (void)displayBrightnessIncrementUp;

// sync 0.05
- (void)displayBrightnessDecrementPress;

- (void)displayBrightnessDecrementDown;
- (void)displayBrightnessDecrementUp;

/* MARK: --- Accelerometer --- */

// async 2.0
- (void)shakeIt;

/* MARK: --- Other Consumer Usages --- */

// sync 0.05
- (void)otherConsumerUsagePress:(uint32_t)usage;
- (void)otherConsumerUsageDown:(uint32_t)usage;
- (void)otherConsumerUsageUp:(uint32_t)usage;

// sync 0.05
- (void)otherPage:(uint32_t)page usagePress:(uint32_t)usage;
- (void)otherPage:(uint32_t)page usageDown:(uint32_t)usage;
- (void)otherPage:(uint32_t)page usageUp:(uint32_t)usage;

@end
