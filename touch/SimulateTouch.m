//
//  SimulateTouch.m
//  SimulateTouch
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "SimulateTouch.h"
#import <UIKit/UIGeometry.h>
#import <rocketbootstrap/rocketbootstrap.h>

#import "STHIDEventGenerator.h"


@interface SimulateTouch (Private)

@property (nonatomic, strong) CPDistributedMessagingCenter *messagingCenter;

+ (instancetype)sharedInstanceWithRole:(SimulateTouchRole)role;
- (instancetype)initWithRole:(SimulateTouchRole)role;

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;

@end


/* MARK: ----------------------------------------------------------------------- */


@implementation SimulateTouch {
    SimulateTouchRole _role;
    dispatch_queue_t _eventQueue;
}

@synthesize messagingCenter = _messagingCenter;
@synthesize shouldShowTouches = _shouldShowTouches;

+ (instancetype)sharedInstance {
    return [self sharedInstanceWithRole:SimulateTouchRoleClient];
}

+ (instancetype)sharedInstanceWithRole:(SimulateTouchRole)role {
    static SimulateTouch *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[SimulateTouch alloc] initWithRole:role];
    });
    return _server;
}

- (instancetype)initWithRole:(SimulateTouchRole)role {
    self = [super init];
    if (self) {
        _role = role;
        _eventQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.EventQueue", @XPC_INSTANCE_NAME] UTF8String], DISPATCH_QUEUE_SERIAL);
        
#if DEBUG
        _shouldShowTouches = YES;
#endif
    }
    return self;
}

- (SimulateTouchRole)role {
    return _role;
}

- (CPDistributedMessagingCenter *)messagingCenter {
    return _messagingCenter;
}

- (BOOL)shouldShowTouches {
    return _shouldShowTouches;
}

- (void)setMessagingCenter:(CPDistributedMessagingCenter *)messagingCenter {
    _messagingCenter = messagingCenter;
}

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == SimulateTouchRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    NSAssert(sendSucceed, @"cannot send message %@, userInfo = %@", messageName, userInfo);
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == SimulateTouchRoleServer, @"invalid role");
    
    @autoreleasepool {
        NSString *selectorName = [userInfo objectForKey:@"selector"];
        SEL selector = NSSelectorFromString(selectorName);
        NSAssert([self respondsToSelector:selector], @"invalid selector");
        
        NSInvocation *forwardInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
        [forwardInvocation setSelector:selector];
        [forwardInvocation setTarget:self];
        
        NSInteger argumentIndex = 2;
        NSArray *arguments = [userInfo objectForKey:@"arguments"];
        for (NSObject *argument in arguments) {
            void *argumentPtr = (__bridge void *)(argument);
            [forwardInvocation setArgument:&argumentPtr atIndex:argumentIndex];
            argumentIndex += 1;
        }
        
        [forwardInvocation invoke];
    }
}

- (void)touchDown:(CGPoint)coord {
    [self _touchDown:@[@(coord.x), @(coord.y)] touchCount:@1];
}

- (void)touchDown:(CGPoint)coord touchCount:(NSUInteger)count {
    [self _touchDown:@[@(coord.x), @(coord.y)] touchCount:@(count)];
}

- (void)touchDownAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY {
    [self _touchDown:@[@(coordX), @(coordY)] touchCount:@1];
}

- (void)touchDownAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY touchCount:(NSUInteger)count {
    [self _touchDown:@[@(coordX), @(coordY)] touchCount:@(count)];
}

- (void)_touchDown:(NSArray <NSNumber *> /* CGPoint */ *)coord touchCount:(NSNumber /* NSUInteger */ *)count {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_touchDown:touchCount:)), @"arguments": [NSArray arrayWithObjects:coord, count, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"touchDown %@", coord);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] touchDown:CGPointMake([coord[0] doubleValue], [coord[1] doubleValue]) touchCount:[count unsignedIntegerValue]];
    });
}

- (void)liftUp:(CGPoint)coord {
    [self _liftUp:@[@(coord.x), @(coord.y)] touchCount:@1];
}

- (void)liftUp:(CGPoint)coord touchCount:(NSUInteger)count {
    [self _liftUp:@[@(coord.x), @(coord.y)] touchCount:@(count)];
}

- (void)liftUpAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY {
    [self _liftUp:@[@(coordX), @(coordY)] touchCount:@1];
}

- (void)liftUpAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY touchCount:(NSUInteger)count {
    [self _liftUp:@[@(coordX), @(coordY)] touchCount:@(count)];
}

- (void)_liftUp:(NSArray <NSNumber *> /* CGPoint */ *)coord touchCount:(NSNumber /* NSUInteger */ *)count {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_liftUp:touchCount:)), @"arguments": [NSArray arrayWithObjects:coord, count, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"liftUp %@", coord);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] liftUp:CGPointMake([coord[0] doubleValue], [coord[1] doubleValue]) touchCount:[count unsignedIntegerValue]];
    });
}

- (void)tap:(CGPoint)coord {
    [self _tap:@[@(coord.x), @(coord.y)]];
}

- (void)tapAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY {
    [self _tap:@[@(coordX), @(coordY)]];
}

- (void)_tap:(NSArray <NSNumber *> /* CGPoint */ *)coord {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_tap:)), @"arguments": [NSArray arrayWithObjects:coord, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"tap %@", coord);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] tap:CGPointMake([coord[0] doubleValue], [coord[1] doubleValue])];
    });
}

- (void)doubleTap:(CGPoint)coord {
    [self _doubleTap:@[@(coord.x), @(coord.y)]];
}

- (void)doubleTapAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY {
    [self _doubleTap:@[@(coordX), @(coordY)]];
}

- (void)_doubleTap:(NSArray <NSNumber *> /* CGPoint */ *)coord {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_doubleTap:)), @"arguments": [NSArray arrayWithObjects:coord, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"doubleTap %@", coord);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] doubleTap:CGPointMake([coord[0] doubleValue], [coord[1] doubleValue])];
    });
}

- (void)twoFingerTap:(CGPoint)coord {
    [self _twoFingerTap:@[@(coord.x), @(coord.y)]];
}

- (void)twoFingerTapAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY {
    [self _twoFingerTap:@[@(coordX), @(coordY)]];
}

- (void)_twoFingerTap:(NSArray <NSNumber *> /* CGPoint */ *)coord {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_twoFingerTap:)), @"arguments": [NSArray arrayWithObjects:coord, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"twoFingerTap %@", coord);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] twoFingerTap:CGPointMake([coord[0] doubleValue], [coord[1] doubleValue])];
    });
}

- (void)threeFingerTap:(CGPoint)coord {
    [self _threeFingerTap:@[@(coord.x), @(coord.y)]];
}

- (void)threeFingerTapAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY {
    [self _threeFingerTap:@[@(coordX), @(coordY)]];
}

- (void)_threeFingerTap:(NSArray <NSNumber *> /* CGPoint */ *)coord {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_threeFingerTap:)), @"arguments": [NSArray arrayWithObjects:coord, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"threeFingerTap %@", coord);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] threeFingerTap:CGPointMake([coord[0] doubleValue], [coord[1] doubleValue])];
    });
}

- (void)longPress:(CGPoint)coord {
    [self _longPress:@[@(coord.x), @(coord.y)]];
}

- (void)longPressAtCoordinateX:(CGFloat)coordX coordinateY:(CGFloat)coordY {
    [self _longPress:@[@(coordX), @(coordY)]];
}

- (void)_longPress:(NSArray <NSNumber *> /* CGPoint */ *)coord {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_longPress:)), @"arguments": [NSArray arrayWithObjects:coord, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"longPress %@", coord);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] longPress:CGPointMake([coord[0] doubleValue], [coord[1] doubleValue])];
    });
}

- (void)dragCurveWithStartPoint:(CGPoint)coordA endPoint:(CGPoint)coordB duration:(NSTimeInterval)duration {
    [self _dragWithStartPoint:@[@(coordA.x), @(coordA.y)] endPoint:@[@(coordB.x), @(coordB.y)] duration:@(duration)];
}

- (void)dragCurveWithStartPointAtCoordinateX:(CGFloat)coordAX
                                 coordinateY:(CGFloat)coordAY
                       endPointAtCoordinateX:(CGFloat)coordBX
                                 coordinateY:(CGFloat)coordBY
                                    duration:(NSTimeInterval)duration
{
    [self _dragWithStartPoint:@[@(coordAX), @(coordAY)] endPoint:@[@(coordBX), @(coordBY)] duration:@(duration)];
}

- (void)_dragWithStartPoint:(NSArray <NSNumber *> /* CGPoint */ *)coordA endPoint:(NSArray <NSNumber *> /* CGPoint */ *)coordB duration:(NSNumber /* double */ *)duration {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_dragWithStartPoint:endPoint:duration:)), @"arguments": [NSArray arrayWithObjects:coordA, coordB, duration, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"drag %@ %@ %@", coordA, coordB, duration);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] dragCurveWithStartPoint:CGPointMake([coordA[0] doubleValue], [coordA[1] doubleValue])
                                                                        endPoint:CGPointMake([coordB[0] doubleValue], [coordB[1] doubleValue])
                                                                        duration:[duration doubleValue]];
    });
}

- (void)pinchLinearInBoundOriginX:(CGFloat)boundOriginX
                     boundOriginY:(CGFloat)boundOriginY
                   boundSizeWidth:(CGFloat)boundSizeWidth
                  boundSizeHeight:(CGFloat)boundSizeHeight
                            scale:(CGFloat)scale
                            angle:(CGFloat)angle
                         duration:(NSTimeInterval)seconds
{
    [self _pinchLinearInBounds:@[ @(boundOriginX), @(boundOriginY), @(boundSizeWidth), @(boundSizeHeight) ]
                   scale:@(scale)
                   angle:@(angle)
                duration:@(seconds)];
}

- (void)pinchLinearInBounds:(CGRect)bounds
                      scale:(CGFloat)scale
                      angle:(CGFloat)angle
                   duration:(NSTimeInterval)seconds
{
    [self _pinchLinearInBounds:@[ @(bounds.origin.x), @(bounds.origin.y), @(bounds.size.width), @(bounds.size.height) ]
                   scale:@(scale)
                   angle:@(angle)
                duration:@(seconds)];
}

- (void)_pinchLinearInBounds:(NSArray <NSNumber /* double */ *> *)bounds
                       scale:(NSNumber /* double */ *)scale
                       angle:(NSNumber /* double */ *)angle
                    duration:(NSNumber /* double */ *)seconds
{
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_pinchLinearInBounds:scale:angle:duration:)), @"arguments": [NSArray arrayWithObjects:bounds, scale, angle, seconds, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"pinch %@ %@ %@ %@", bounds, scale, angle, seconds);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] pinchLinearInBounds:CGRectMake([bounds[0] doubleValue], [bounds[1] doubleValue], [bounds[2] doubleValue], [bounds[3] doubleValue]) scale:[scale doubleValue] angle:[angle doubleValue] duration:[seconds doubleValue]];
    });
}

- (void)sendEventStream:(NSDictionary *)eventInfo {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(sendEventStream:)), @"arguments": [NSArray arrayWithObjects:eventInfo, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"sendEvent %@", eventInfo);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] sendEventStream:eventInfo];
    });
}

- (void)sendText:(NSString *)characters {
    [self _sendText:characters];
}

- (void)_sendText:(NSString *)characters {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_sendText:)), @"arguments": [NSArray arrayWithObjects:characters, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"sendText %@", characters);
    
    dispatch_async(_eventQueue, ^{
        [characters enumerateSubstringsInRange:NSMakeRange(0, characters.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
            CHDebugLog(@"substring: %@, substringRange: %@, enclosingRange %@",
                substring, NSStringFromRange(substringRange), NSStringFromRange(enclosingRange));
            
            [[STHIDEventGenerator sharedSTHIDEventGenerator] keyPress:substring];
        }];
    });
}

- (void)keyPress:(NSString *)character {
    [self _keyPress:character];
}

- (void)_keyPress:(NSString *)character {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_keyPress:)), @"arguments": [NSArray arrayWithObjects:character, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"keyPress %@", character);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] keyPress:character];
    });
}

- (void)keyDown:(NSString *)character {
    [self _keyDown:character];
}

- (void)_keyDown:(NSString *)character {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_keyDown:)), @"arguments": [NSArray arrayWithObjects:character, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"keyDown %@", character);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] keyDown:character];
    });
}

- (void)keyUp:(NSString *)character {
    [self _keyUp:character];
}

- (void)_keyUp:(NSString *)character {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_keyUp:)), @"arguments": [NSArray arrayWithObjects:character, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"keyUp %@", character);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] keyUp:character];
    });
}

- (void)menuPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(menuPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"menuPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] menuPress];
    });
}

- (void)menuDoublePress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(menuDoublePress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"menuDoublePress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] menuDoublePress];
    });
}

- (void)menuLongPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(menuLongPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"menuLongPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] menuLongPress];
    });
}

- (void)menuDown {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(menuDown)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"menuDown");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] menuDown];
    });
}

- (void)menuUp {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(menuUp)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"menuUp");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] menuUp];
    });
}

- (void)powerPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(powerPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"powerPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] powerPress];
    });
}

- (void)powerDoublePress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(powerDoublePress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"powerDoublePress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] powerDoublePress];
    });
}

- (void)powerTriplePress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(powerTriplePress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"powerTriplePress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] powerTriplePress];
    });
}

- (void)powerLongPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(powerLongPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"powerLongPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] powerLongPress];
    });
}

- (void)powerDown {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(powerDown)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"powerDown");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] powerDown];
    });
}

- (void)powerUp {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(powerUp)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"powerUp");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] powerUp];
    });
}

- (void)mutePress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(mutePress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"mutePress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] mutePress];
    });
}

- (void)muteDown {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(muteDown)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"muteDown");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] muteDown];
    });
}

- (void)muteUp {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(muteUp)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"muteUp");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] muteUp];
    });
}

- (void)volumeIncrementPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(volumeIncrementPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"volumeIncrementPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] volumeIncrementPress];
    });
}

- (void)volumeIncrementDown {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(volumeIncrementDown)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"volumeIncrementDown");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] volumeIncrementDown];
    });
}

- (void)volumeIncrementUp {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(volumeIncrementUp)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"volumeIncrementUp");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] volumeIncrementUp];
    });
}

- (void)volumeDecrementPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(volumeDecrementPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"volumeDecrementPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] volumeDecrementPress];
    });
}

- (void)volumeDecrementDown {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(volumeDecrementDown)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"volumeDecrementDown");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] volumeDecrementDown];
    });
}

- (void)volumeDecrementUp {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(volumeDecrementUp)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"volumeDecrementUp");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] volumeDecrementUp];
    });
}

- (void)displayBrightnessIncrementPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(displayBrightnessIncrementPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"displayBrightnessIncrementPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] displayBrightnessIncrementPress];
    });
}

- (void)displayBrightnessIncrementDown {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(displayBrightnessIncrementDown)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"displayBrightnessIncrementDown");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] displayBrightnessIncrementDown];
    });
}

- (void)displayBrightnessIncrementUp {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(displayBrightnessIncrementUp)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"displayBrightnessIncrementUp");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] displayBrightnessIncrementUp];
    });
}

- (void)displayBrightnessDecrementPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(displayBrightnessDecrementPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"displayBrightnessDecrementPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] displayBrightnessDecrementPress];
    });
}

- (void)displayBrightnessDecrementDown {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(displayBrightnessDecrementDown)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"displayBrightnessDecrementDown");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] displayBrightnessDecrementDown];
    });
}

- (void)displayBrightnessDecrementUp {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(displayBrightnessDecrementUp)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"displayBrightnessDecrementUp");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] displayBrightnessDecrementUp];
    });
}

- (void)snapshotPress {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(snapshotPress)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"snapshotPress");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] snapshotPress];
    });
}

- (void)toggleOnScreenKeyboard {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(toggleOnScreenKeyboard)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"toggleOnScreenKeyboard");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] toggleOnScreenKeyboard];
    });
}

- (void)toggleSpotlight {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(toggleSpotlight)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"toggleSpotlight");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] toggleSpotlight];
    });
}

- (void)otherConsumerUsagePress:(uint32_t)usage {
    [self _otherConsumerUsagePress:@(usage)];
}

- (void)_otherConsumerUsagePress:(NSNumber *)usage {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_otherConsumerUsagePress:)), @"arguments": [NSArray arrayWithObjects:usage, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"otherConsumerUsagePress %u", [usage unsignedIntValue]);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] otherConsumerUsagePress:[usage unsignedIntValue]];
    });
}

- (void)otherConsumerUsageDown:(uint32_t)usage {
    [self _otherConsumerUsageDown:@(usage)];
}

- (void)_otherConsumerUsageDown:(NSNumber *)usage {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_otherConsumerUsageDown:)), @"arguments": [NSArray arrayWithObjects:usage, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"otherConsumerUsageDown %u", [usage unsignedIntValue]);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] otherConsumerUsageDown:[usage unsignedIntValue]];
    });
}

- (void)otherConsumerUsageUp:(uint32_t)usage {
    [self _otherConsumerUsageUp:@(usage)];
}

- (void)_otherConsumerUsageUp:(NSNumber *)usage {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_otherConsumerUsageUp:)), @"arguments": [NSArray arrayWithObjects:usage, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"otherConsumerUsageUp %u", [usage unsignedIntValue]);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] otherConsumerUsageUp:[usage unsignedIntValue]];
    });
}

- (void)otherPage:(uint32_t)page usagePress:(uint32_t)usage {
    [self _otherPage:@(page) usagePress:@(usage)];
}

- (void)_otherPage:(NSNumber *)page usagePress:(NSNumber *)usage {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_otherPage:usagePress:)), @"arguments": [NSArray arrayWithObjects:page, usage, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"otherPage %u usagePress %u", [page unsignedIntValue], [usage unsignedIntValue]);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] otherPage:[page unsignedIntValue] usagePress:[usage unsignedIntValue]];
    });
}

- (void)otherPage:(uint32_t)page usageDown:(uint32_t)usage {
    [self _otherPage:@(page) usageDown:@(usage)];
}

- (void)_otherPage:(NSNumber *)page usageDown:(NSNumber *)usage {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_otherPage:usageDown:)), @"arguments": [NSArray arrayWithObjects:page, usage, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"otherPage %u usageDown %u", [page unsignedIntValue], [usage unsignedIntValue]);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] otherPage:[page unsignedIntValue] usageDown:[usage unsignedIntValue]];
    });
}

- (void)otherPage:(uint32_t)page usageUp:(uint32_t)usage {
    [self _otherPage:@(page) usageUp:@(usage)];
}

- (void)_otherPage:(NSNumber *)page usageUp:(NSNumber *)usage {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_otherPage:usageUp:)), @"arguments": [NSArray arrayWithObjects:page, usage, nil] }];
            return;
        }
    }
    
    CHDebugLog(@"otherPage %u usageUp %u", [page unsignedIntValue], [usage unsignedIntValue]);
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] otherPage:[page unsignedIntValue] usageUp:[usage unsignedIntValue]];
    });
}

- (void)shakeIt {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(shakeIt)), @"arguments": [NSArray array] }];
            return;
        }
    }
    
    CHDebugLog(@"shakeIt");
    
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] shakeIt];
    });
}

- (void)setShouldShowTouches:(BOOL)shouldShowTouches {
    _shouldShowTouches = shouldShowTouches;
    [self _setShouldShowTouches:@(shouldShowTouches)];
}

- (void)_setShouldShowTouches:(NSNumber *)shouldShowTouches {
    if (_role == SimulateTouchRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_setShouldShowTouches:)), @"arguments": [NSArray arrayWithObjects:shouldShowTouches, nil] }];
            return;
        }
    }

    CHDebugLog(@"setShouldShowTouches %@", [shouldShowTouches boolValue] ? @"YES" : @"NO");
    dispatch_async(_eventQueue, ^{
        [[STHIDEventGenerator sharedSTHIDEventGenerator] setShouldShowTouches:[shouldShowTouches boolValue]];
    });
}

@end


/* MARK: ----------------------------------------------------------------------- */


CHConstructor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] arguments][0];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        BOOL forceClient = [[[NSProcessInfo processInfo] environment][@"CLIENT"] boolValue];
        
        if (!forceClient && ([processName isEqualToString:@"simulatetouchd"] || [processName hasSuffix:@"/simulatetouchd"]))
        {   /* Server Process - simulatetouchd */
            
            rocketbootstrap_unlock(XPC_INSTANCE_NAME);
            
            CPDistributedMessagingCenter *serverMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(serverMessagingCenter);
            [serverMessagingCenter runServerOnCurrentThread];
            
            SimulateTouch *serverInstance = [SimulateTouch sharedInstanceWithRole:SimulateTouchRoleServer];
            [serverMessagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
            [serverInstance setMessagingCenter:serverMessagingCenter];
            
            CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", serverMessagingCenter, bundleIdentifier, processName, getpid());
        }
        else
        {   /* Client Process */
            
            CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
            
            SimulateTouch *clientInstance = [SimulateTouch sharedInstanceWithRole:SimulateTouchRoleClient];
            [clientInstance setMessagingCenter:clientMessagingCenter];
            
            CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
        }
    }
}
