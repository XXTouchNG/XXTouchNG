#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"
#import <pthread.h>

#import <UIKit/UIScreen.h>
#import "SimulateTouch.h"
#import "STHIDEventGenerator.h"


#pragma mark -

XXTouchF_CAPI int luaopen_touch(lua_State *);
XXTouchF_CAPI int luaopen_extouch(lua_State *);
XXTouchF_CAPI int luaopen_key(lua_State *);
XXTouchF_CAPI int luaopen_exkey(lua_State *);

typedef enum : NSUInteger {
    SimulateTouchOrientationHomeOnBottom = 0,
    SimulateTouchOrientationHomeOnRight,
    SimulateTouchOrientationHomeOnLeft,
    SimulateTouchOrientationHomeOnTop,
} SimulateTouchOrientation;

@interface SimulateTouchLuaBridge : NSObject

+ (CGSize)nativeSize;
+ (CGRect)nativeRect;

+ (instancetype)sharedBridge;

- (SimulateTouchOrientation)orientation;
- (void)setOrientation:(SimulateTouchOrientation)orientation;
- (CGSize)orientedSize;
- (CGRect)orientedBounds;

- (BOOL)containsOrientedPoint:(CGPoint)point;
- (CGPoint)rotatePoint:(CGPoint)point toOrientation:(SimulateTouchOrientation)alternativeOrientation;

@end

@implementation SimulateTouchLuaBridge {
    SimulateTouchOrientation _orientation;
}

+ (instancetype)sharedBridge {
    static SimulateTouchLuaBridge *_sharedBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedBridge = [[SimulateTouchLuaBridge alloc] init];
    });
    return _sharedBridge;
}

- (SimulateTouchOrientation)orientation {
    return _orientation;
}

- (void)setOrientation:(SimulateTouchOrientation)orientation {
    _orientation = orientation;
}

+ (CGSize)nativeSize {
    /// This rectangle is based on the device in a portrait-up orientation. This value does not change as the device rotates.
    static CGSize nativeSize;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nativeSize = [[UIScreen mainScreen] nativeBounds].size;
    });
    return nativeSize;
}

+ (CGRect)nativeRect {
    static CGRect nativeRect;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nativeRect = [[UIScreen mainScreen] nativeBounds];
    });
    return nativeRect;
}

+ (CGFloat)nativeScale {
    static CGFloat nativeScale;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nativeScale = [[UIScreen mainScreen] nativeScale];
    });
    return nativeScale;
}

- (CGSize)orientedSize {
    CGSize nativeSize = [SimulateTouchLuaBridge nativeSize];
    if (_orientation == SimulateTouchOrientationHomeOnBottom || _orientation == SimulateTouchOrientationHomeOnTop) {
        return CGSizeMake(nativeSize.width, nativeSize.height);
    }
    return CGSizeMake(nativeSize.height, nativeSize.width);
}

- (CGRect)orientedBounds {
    CGSize orientSize = [self orientedSize];
    return CGRectMake(0, 0, orientSize.width, orientSize.height);
}

/* It is allowed to go a little bit outside the screen. */
- (CGRect)allowedOrientedBounds {
    CGSize orientSize = [self orientedSize];
    return CGRectMake(-20, -20, orientSize.width + 40, orientSize.height + 40);
}

- (BOOL)containsOrientedPoint:(CGPoint)point {
    return CGRectContainsPoint([self allowedOrientedBounds], point);
}

- (CGPoint)rotatePoint:(CGPoint)point toOrientation:(SimulateTouchOrientation)alternateOrientation {
    if (_orientation == alternateOrientation) {
        return point;
    }
    CGSize nativeSize = [SimulateTouchLuaBridge nativeSize];
    if (_orientation == SimulateTouchOrientationHomeOnBottom) {
        if (alternateOrientation == SimulateTouchOrientationHomeOnLeft) {
            return CGPointMake(nativeSize.height - point.y, point.x);
        }
        if (alternateOrientation == SimulateTouchOrientationHomeOnTop) {
            return CGPointMake(nativeSize.width - point.x, nativeSize.height - point.y);
        }
        if (alternateOrientation == SimulateTouchOrientationHomeOnRight) {
            return CGPointMake(point.y, nativeSize.width - point.x);
        }
    }
    if (_orientation == SimulateTouchOrientationHomeOnTop) {
        if (alternateOrientation == SimulateTouchOrientationHomeOnRight) {
            return CGPointMake(nativeSize.height - point.y, point.x);
        }
        if (alternateOrientation == SimulateTouchOrientationHomeOnBottom) {
            return CGPointMake(nativeSize.width - point.x, nativeSize.height - point.y);
        }
        if (alternateOrientation == SimulateTouchOrientationHomeOnLeft) {
            return CGPointMake(point.y, nativeSize.width - point.x);
        }
    }
    if (_orientation == SimulateTouchOrientationHomeOnRight) {
        if (alternateOrientation == SimulateTouchOrientationHomeOnBottom) {
            return CGPointMake(nativeSize.width - point.y, point.x);
        }
        if (alternateOrientation == SimulateTouchOrientationHomeOnLeft) {
            return CGPointMake(nativeSize.width - point.x, nativeSize.height - point.y);
        }
        if (alternateOrientation == SimulateTouchOrientationHomeOnTop) {
            return CGPointMake(point.y, nativeSize.height - point.x);
        }
    }
    if (_orientation == SimulateTouchOrientationHomeOnLeft) {
        if (alternateOrientation == SimulateTouchOrientationHomeOnTop) {
            return CGPointMake(nativeSize.width - point.y, point.x);
        }
        if (alternateOrientation == SimulateTouchOrientationHomeOnRight) {
            return CGPointMake(nativeSize.width - point.x, nativeSize.height - point.y);
        }
        if (alternateOrientation == SimulateTouchOrientationHomeOnBottom) {
            return CGPointMake(point.y, nativeSize.height - point.x);
        }
    }
    return CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
}

@end


#pragma mark -

#define SIMERR_INVALID_ORIENTATION \
    "Invalid orientation %I, available values are:" "\n" \
    "  * Home on bottom = 0" "\n" \
    "  * Home on right = 1" "\n" \
    "  * Home on left = 2" "\n" \
    "  * Home on top = 3"

/**
   Setup standalone coordinate system for this module.
 */
static int SimulateTouch_Init(lua_State *L)
{
    /// Argument #1
    lua_Integer newOrientation = luaL_checkinteger(L, 1);
    
    /// Check argument #1
    if (newOrientation < 0 || newOrientation > 3) {
        return luaL_error(L, SIMERR_INVALID_ORIENTATION, newOrientation);
    }
    
    lua_Integer priorOrientation = (lua_Integer)[[SimulateTouchLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    [[SimulateTouchLuaBridge sharedBridge] setOrientation:(SimulateTouchOrientation)newOrientation];
    
    lua_pushinteger(L, priorOrientation);
    
    return 1;
}

static int SimulateTouch_Init_HomeOnBottom(lua_State *L)
{
    lua_Integer priorOrientation = (lua_Integer)[[SimulateTouchLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    [[SimulateTouchLuaBridge sharedBridge] setOrientation:SimulateTouchOrientationHomeOnBottom];
    
    lua_pushinteger(L, priorOrientation);
    
    return 1;
}

static int SimulateTouch_Init_HomeOnRight(lua_State *L)
{
    lua_Integer priorOrientation = (lua_Integer)[[SimulateTouchLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    [[SimulateTouchLuaBridge sharedBridge] setOrientation:SimulateTouchOrientationHomeOnRight];
    
    lua_pushinteger(L, priorOrientation);
    
    return 1;
}

static int SimulateTouch_Init_HomeOnLeft(lua_State *L)
{
    lua_Integer priorOrientation = (lua_Integer)[[SimulateTouchLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    [[SimulateTouchLuaBridge sharedBridge] setOrientation:SimulateTouchOrientationHomeOnLeft];
    
    lua_pushinteger(L, priorOrientation);
    
    return 1;
}

static int SimulateTouch_Init_HomeOnTop(lua_State *L)
{
    lua_Integer priorOrientation = (lua_Integer)[[SimulateTouchLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    [[SimulateTouchLuaBridge sharedBridge] setOrientation:SimulateTouchOrientationHomeOnTop];
    
    lua_pushinteger(L, priorOrientation);
    
    return 1;
}

static int SimulateTouch_Orientation(lua_State *L)
{
    /// Get orientation value from shared bridge
    lua_pushinteger(L, (lua_Integer)[[SimulateTouchLuaBridge sharedBridge] orientation]);
    
    return 1;
}


#pragma mark -

#define SIMERR_COORDINATE_OUT_OF_RANGE \
    "Coordinate (%I, %I) exceeds coordinate space (%I, %I)"

#define SIMERR_FINGER_POOL_OVERFLOW \
    "Finger pool overflow"

#define SIMERR_FINGER_USED \
    "Finger #%I was used"

#define SIMERR_FINGER_NOT_USED \
    "Finger #%I was not used"

#define SIMERR_EXPECT_TOUCH_STREAM \
    "touch_stream expected"

#define SIMERR_INVALID_ANIMATION \
    "Invalid animation, expected value: linear, curve"

NS_INLINE NSTimeInterval l_uptime()
{
    static float timebase_ratio;
    if (timebase_ratio == 0) {
        mach_timebase_info_data_t s_timebase_info;
        (void) mach_timebase_info(&s_timebase_info);
        
        timebase_ratio = (float)s_timebase_info.numer / s_timebase_info.denom;
    }
    return timebase_ratio * mach_absolute_time() / 1e9;
}

/**
   Get native size of internal device screen.
 */
static int SimulateTouch_Size(lua_State *L)
{
    CGSize nativeSize = [SimulateTouchLuaBridge nativeSize];
    
    lua_pushinteger(L, (lua_Integer)nativeSize.width);
    lua_pushinteger(L, (lua_Integer)nativeSize.height);
    
    return 2;
}

/**
   Apply rotate transform from existing point to another coordinate system.
 */
static int SimulateTouch_RotateXY(lua_State *L)
{
    /// Argument #1, #2: point (x, y) to apply rotation
    lua_Integer lCoordX = (lua_Integer)luaL_checknumber(L, 1);
    lua_Integer lCoordY = (lua_Integer)luaL_checknumber(L, 2);
    
    /// Convert to CGPoint
    CGPoint cPoint = CGPointMake(lCoordX, lCoordY);
    
    /// Check argument #1, #2
    if (![[SimulateTouchLuaBridge sharedBridge] containsOrientedPoint:cPoint]) {
        CGSize tSize = [[SimulateTouchLuaBridge sharedBridge] orientedSize];
        return luaL_error(L, SIMERR_COORDINATE_OUT_OF_RANGE, lCoordX, lCoordY, (NSUInteger)tSize.width, (NSUInteger)tSize.height);
    }
    
    /// Argument #3: targer orientation
    lua_Integer lOrientation = luaL_checkinteger(L, 3);
    
    /// Check argument #3
    if (lOrientation < 0 || lOrientation > 3) {
        return luaL_error(L, SIMERR_INVALID_ORIENTATION, lOrientation);
    }
    
    /// Rotated point
    CGPoint rotatedPoint = [[SimulateTouchLuaBridge sharedBridge] rotatePoint:cPoint toOrientation:(SimulateTouchOrientation)lOrientation];
    
    lua_pushinteger(L, (lua_Integer)rotatedPoint.x);
    lua_pushinteger(L, (lua_Integer)rotatedPoint.y);
    
    return 2;
}


#pragma mark -

#define L_TYPE_TOUCH_STREAM "touch_stream"

#define L_OPTION_ANIMATION_LINEAR "linear"
#define L_OPTION_ANIMATION_CURVE "curve"

typedef enum : NSUInteger {
    TouchStreamAnimationTypeLinear = 0,
    TouchStreamAnimationTypeSimpleCurve,
} TouchStreamAnimationType;

typedef struct TouchStream {
    int finger;
    CGPoint location;
    double pressure;
    double twist;
    uint32_t extra_mask;
    double step_len_px;
    NSTimeInterval step_delay_ms;
    TouchStreamAnimationType animation_type;
} TouchStream;

NS_INLINE TouchStream *toTouchStream(lua_State *L, int index)
{
    TouchStream *bar = (TouchStream *)lua_touserdata(L, index);
    if (bar == NULL)
        luaL_argerror(L, index, SIMERR_EXPECT_TOUCH_STREAM);
    return bar;
}

NS_INLINE BOOL isTouchStream(lua_State *L, int index)
{
    if (lua_type(L, index) != LUA_TUSERDATA)
        return NO;
    return NULL != luaL_testudata(L, index, L_TYPE_TOUCH_STREAM);
}

NS_INLINE TouchStream *checkTouchStream(lua_State *L, int index)
{
    TouchStream *bar;
    luaL_checktype(L, index, LUA_TUSERDATA);
    bar = (TouchStream *)luaL_checkudata(L, index, L_TYPE_TOUCH_STREAM);
    if (bar == NULL)
        luaL_argerror(L, index, SIMERR_EXPECT_TOUCH_STREAM);
    return bar;
}

NS_INLINE TouchStream *pushTouchStream(lua_State *L)
{
    TouchStream *bar = (TouchStream *)lua_newuserdata(L, sizeof(TouchStream));
    luaL_getmetatable(L, L_TYPE_TOUCH_STREAM);
    lua_setmetatable(L, -2);
    return bar;
}


#pragma mark -

#define MAX_FINGER_COUNT 30  // sizeof(int) * CHAR_BIT - 2
static int _sharedFingerPool = 0;

NS_INLINE int BitCount(unsigned int u) {
    unsigned int uCount;
    
    uCount = u
             - ((u >> 1) & 033333333333)
             - ((u >> 2) & 011111111111);
    
    return
        ((uCount + (uCount >> 3))
         & 030707070707) % 63;
}

NS_INLINE int FirstZeroBit(int i) {
    i = ~i;
    return BitCount((i & (-i)) - 1);
}

NS_INLINE int STAnyFinger() {
    int fingerIndexToLock = FirstZeroBit(_sharedFingerPool);
    if (fingerIndexToLock < 0 || fingerIndexToLock >= (sizeof(unsigned int) * CHAR_BIT)) {
        return 0;  // finger pool overflow
    }
    _sharedFingerPool |= 1 << fingerIndexToLock;
    fingerIndexToLock += 1;
    return fingerIndexToLock;
}

NS_INLINE int STFingerLock(int fingerIndexToLock) {
    if (fingerIndexToLock <= 0 || fingerIndexToLock > MAX_FINGER_COUNT) {
        return -1;  // unexpected range
    }
    fingerIndexToLock -= 1;
    if (_sharedFingerPool & (1 << fingerIndexToLock)) {
        return 0;  // already locked
    }
    _sharedFingerPool |= 1 << fingerIndexToLock;
    fingerIndexToLock += 1;
    return fingerIndexToLock;
}

NS_INLINE int STFingerIsLocked(int fingerIndexToCheck) {
    if (fingerIndexToCheck <= 0 || fingerIndexToCheck > MAX_FINGER_COUNT) {
        return -1;  // unexpected range
    }
    fingerIndexToCheck -= 1;
    if (_sharedFingerPool & (1 << fingerIndexToCheck)) {
        return 1;  // already locked
    }
    return 0;  // not locked
}

NS_INLINE void STFingerUnlock(int fingerIndexToUnlock) {
    fingerIndexToUnlock -= 1;
    _sharedFingerPool &= ~(1 << fingerIndexToUnlock);
}

/// finger status records
struct FINGER_STATUS {
    CGPoint location;
    double pressure;
    double twist;
    uint32_t extra_mask;
};
static struct FINGER_STATUS _sharedFingerStatusRecords[MAX_FINGER_COUNT];

NS_INLINE int clampInt(int v, int min, int max) {
    return MIN(MAX(v, min), max);
}

NS_INLINE struct FINGER_STATUS * STFingerStatusRecord(int fingerIndex) {
    return &_sharedFingerStatusRecords[clampInt(fingerIndex, 0, MAX_FINGER_COUNT)];
}

NS_INLINE double STRandomNumber(double minValue, double maxValue) {
    return minValue + arc4random_uniform(maxValue - minValue + 1);
}

NS_INLINE NSDictionary *STCreateDictionaryWithSingleFingerEvent
(
    int fingerIndex,
    NSString *phase,
    NSTimeInterval timeOffset,
    
    CGPoint point,
    double pressure,  // 0.0...1.0, default is 0.0
    double twist,     // -1.0...1.0, default is 0.5
    uint32_t extraMask,
    
    CGSize screenSize
) {
    return @{
        HIDEventCoordinateSpaceKey : HIDEventCoordinateSpaceTypeContent,
        HIDEventTimeOffsetKey : @(timeOffset),
        HIDEventInputType : HIDEventInputTypeHand,
        HIDEventTouchesKey : @[
            @{
                HIDEventTouchIDKey : @(fingerIndex),
                HIDEventFingerKey : @(fingerIndex),
                HIDEventInputType : HIDEventInputTypeFinger,
                HIDEventPhaseKey : phase,
                HIDEventXKey : @(point.x / screenSize.width),
                HIDEventYKey : @(point.y / screenSize.height),
                HIDEventPressureKey : @(MIN(MAX(pressure, 0.0), 1.0) * 600.f),
                HIDEventTwistKey : @(MIN(MAX(twist, -1.0), 1.0) * 180.f),
                HIDEventMaskKey : @(extraMask),
                HIDEventMinorRadiusKey: @(STRandomNumber(0.03, 0.04)),
                HIDEventMajorRadiusKey: @(STRandomNumber(0.04, 0.05)),
            },
        ],
    };
}

NS_INLINE NSDictionary *STCreateDictionaryWithInterpolatedFingerEvents
(
    int fingerIndex,
    NSString *phase,                 // default is HIDEventPhaseMoved
    NSTimeInterval timeOffset,
    NSTimeInterval duration,
    NSString *interpolateType,       // default is linear
    NSTimeInterval triggerInterval,  // default is 0.1ms = 1e-4
    
    CGPoint beginPoint,
    double beginPressure,            // default is 0
    
    CGPoint endPoint,
    double endPressure,              // default is 0
    
    double twist,                    // default is 0.5
    uint32_t extraMask,
    CGSize screenSize
) {
    return @{
        HIDEventCoordinateSpaceKey : HIDEventCoordinateSpaceTypeContent,
        HIDEventTimeOffsetKey : @(timeOffset),
        HIDEventInputType : HIDEventInputTypeHand,
        HIDEventInterpolateKey : interpolateType,
        HIDEventStartEventKey:
            STCreateDictionaryWithSingleFingerEvent(fingerIndex, phase, timeOffset, beginPoint, beginPressure, twist, extraMask, screenSize),
        HIDEventEndEventKey:
            STCreateDictionaryWithSingleFingerEvent(fingerIndex, phase, timeOffset + duration, endPoint, endPressure, twist, extraMask, screenSize),
        HIDEventTimestepKey: @(triggerInterval),
        HIDEventTouchesKey : @[],
    };
}

NS_INLINE NSDictionary *STCreateDictionaryWithFinger
(
    int fingerIndex,
    NSTimeInterval timeOffset,
    CGSize screenSize
) {
    if (STFingerIsLocked(fingerIndex) != 1) {
        return nil;
    }
    return STCreateDictionaryWithSingleFingerEvent
    (
     fingerIndex,
     HIDEventPhaseMoved,
     timeOffset,
     STFingerStatusRecord(fingerIndex)->location,
     STFingerStatusRecord(fingerIndex)->pressure,
     STFingerStatusRecord(fingerIndex)->twist,
     STFingerStatusRecord(fingerIndex)->extra_mask,
     screenSize
     );
}

NS_INLINE NSDictionary *STDictionaryJoin
(
    NSDictionary *dict,
    NSDictionary *dictToJoin
) {
    @autoreleasepool {
        if (!dictToJoin) {
            return dict;
        }
        
        NSMutableArray <NSDictionary *> *touchesList = [dict[HIDEventTouchesKey] mutableCopy];
        [touchesList addObjectsFromArray:( dictToJoin[HIDEventTouchesKey] ?: @[] )];
        NSMutableDictionary *mDict = [dict mutableCopy];
        mDict[HIDEventTouchesKey] = touchesList;
        return [mDict copy];
    }
}

NS_INLINE NSDictionary *STDictionaryJoinFinger
(
    NSDictionary *dict,
    int fingerIndex,
    NSTimeInterval timeOffset,
    CGSize screenSize
) {
    return STDictionaryJoin(dict, STCreateDictionaryWithFinger(fingerIndex, timeOffset, screenSize));
}

NS_INLINE NSDictionary *STDictionaryJoinLockedFingers
(
    NSDictionary *dict,
    int currentFingerIndex,
    NSTimeInterval timeOffset,
    CGSize screenSize
) {
    NSDictionary *current = dict;
    for (int fingerIndex = 0; fingerIndex <= MAX_FINGER_COUNT; fingerIndex++)
    {
        @autoreleasepool {
            if (fingerIndex != currentFingerIndex && STFingerIsLocked(fingerIndex) == 1)
            {
                current = STDictionaryJoinFinger(current, fingerIndex, timeOffset, screenSize);
            }
        }
    }
    return current;
}

/**
 * Change step length of event stream
 */
static int SimulateTouch_StepLen(lua_State *L)
{
    TouchStream *bar = checkTouchStream(L, 1);
    lua_Number newStepLength = luaL_optnumber(L, 2, 2.0);
    
    TouchStream *foo = pushTouchStream(L);
    memcpy(foo, bar, sizeof(TouchStream));
    foo->step_len_px = newStepLength;
    return 1;
}

/**
 * Change step delay of event stream
 */
static int SimulateTouch_StepDelay(lua_State *L)
{
    TouchStream *bar = checkTouchStream(L, 1);
    lua_Number newStepDelay = luaL_optnumber(L, 2, 0.1);
    
    TouchStream *foo = pushTouchStream(L);
    memcpy(foo, bar, sizeof(TouchStream));
    foo->step_delay_ms = newStepDelay;
    return 1;
}

/**
 * Change animation of event stream
 */
static int SimulateTouch_Animation(lua_State *L)
{
    TouchStream *bar = checkTouchStream(L, 1);
    const char *cAnimationType = luaL_optstring(L, 2, L_OPTION_ANIMATION_LINEAR);
    TouchStreamAnimationType animationType = TouchStreamAnimationTypeLinear;
    
    if (strcmp(cAnimationType, L_OPTION_ANIMATION_LINEAR) == 0) {
        animationType = TouchStreamAnimationTypeLinear;
    }
    else if (strcmp(cAnimationType, L_OPTION_ANIMATION_CURVE) == 0) {
        animationType = TouchStreamAnimationTypeSimpleCurve;
    } else {
        return luaL_argerror(L, 2, SIMERR_INVALID_ANIMATION);
    }
    
    TouchStream *foo = pushTouchStream(L);
    memcpy(foo, bar, sizeof(TouchStream));
    foo->animation_type = animationType;
    return 1;
}

static int SimulateTouch_Is(lua_State *L)
{
    lua_pushboolean(L, isTouchStream(L, 1));
    return 1;
}

/**
 * Begin touch event stream
 */
static int SimulateTouch_On(lua_State *L)
{
    lua_Integer lCoordX, lCoordY, specifiedFinger;
    uint32_t extraMask /* Swipe Mask */ = 0x0;
    
    BOOL requiresStream = NO;
    int argc = lua_gettop(L);
    if (argc > 2) {
        specifiedFinger = luaL_checkinteger(L, 1);
        lCoordX = (lua_Integer)luaL_checknumber(L, 2);
        lCoordY = (lua_Integer)luaL_checknumber(L, 3);
        extraMask = (uint32_t)luaL_optinteger(L, 4, 0x0);
    } else {
        specifiedFinger = 0;
        lCoordX = (lua_Integer)luaL_checknumber(L, 1);
        lCoordY = (lua_Integer)luaL_checknumber(L, 2);
        requiresStream = YES;
    }
    
    /// Convert to CGPoint
    CGPoint beginPoint = CGPointMake(lCoordX, lCoordY);
    
    /// Check cPoint
    if (![[SimulateTouchLuaBridge sharedBridge] containsOrientedPoint:beginPoint]) {
        CGSize tSize = [[SimulateTouchLuaBridge sharedBridge] orientedSize];
        return luaL_error(L, SIMERR_COORDINATE_OUT_OF_RANGE, lCoordX, lCoordY, (NSUInteger)tSize.width, (NSUInteger)tSize.height);
    }
    
    /// Select tap finger
    int tapFinger;
    if (specifiedFinger == 0) {
        /// Lock any finger
        tapFinger = STAnyFinger();
    } else {
        /// Lock specified finger
        tapFinger = STFingerLock((int)specifiedFinger);
    }
    if (tapFinger < 0) {
        return luaL_error(L, SIMERR_FINGER_POOL_OVERFLOW);
    } else if (tapFinger == 0) {
        return luaL_error(L, SIMERR_FINGER_USED, specifiedFinger);
    }
    
    CHDebugLogSource(@"Finger %d locked", tapFinger);
    
    {
        /// Construct event stream
        CGSize nativeSize = [SimulateTouchLuaBridge nativeSize];
        CGPoint eventPoint = [[SimulateTouchLuaBridge sharedBridge] rotatePoint:beginPoint toOrientation:SimulateTouchOrientationHomeOnBottom];
        
        /// Send event stream directly
        NSDictionary *eventStream = @{
            SecondLevelEventsKey: @[
                STDictionaryJoinLockedFingers(
                    STCreateDictionaryWithSingleFingerEvent(
                        tapFinger, HIDEventPhaseBegan, 0,
                        eventPoint, 0.0, 0.5,
                        extraMask,
                        nativeSize
                    ), tapFinger, 0, nativeSize
                ),
            ],
        };
        
        CHDebugLogSource(@"sendEventStream %@", eventStream);
        [[SimulateTouch sharedInstance] sendEventStream:eventStream];
    }
    
    /// Update records
    STFingerStatusRecord(tapFinger)->location = beginPoint;
    STFingerStatusRecord(tapFinger)->extra_mask = extraMask;
    
    if (!requiresStream)
        return 0;
    
    /// Construct touch stream
    TouchStream *bar = pushTouchStream(L);
    bar->finger = tapFinger;
    bar->location = beginPoint;
    bar->pressure = 0.0;
    bar->twist = 50.0;
    bar->extra_mask = extraMask;
    bar->step_delay_ms = 0.16;
    bar->step_len_px = 2.0;
    bar->animation_type = TouchStreamAnimationTypeLinear;
    return 1;
}

/**
 * Move existing finger
 */

typedef struct StreamSleepState {
    struct TouchStream stream;
    NSTimeInterval deadline;
    boolean_t persistent;
} StreamSleepState;

static int SimulateTouch_StreamSleep_Yield(lua_State *L, int status, lua_KContext ctx)
{
    StreamSleepState *streamSleep = (StreamSleepState *)ctx;
    [NSThread sleepForTimeInterval:1e-4];  // 0.1ms
    
    if (l_uptime() > streamSleep->deadline)
    {
        if (!streamSleep->persistent)
            return 0;
        
        TouchStream *foo = pushTouchStream(L);
        memcpy(foo, &streamSleep->stream, sizeof(TouchStream));
        return 1;
    }
    
    return lua_yieldk(L, 0, ctx, SimulateTouch_StreamSleep_Yield);
}

static int SimulateTouch_Move(lua_State *L)
{
    lua_Integer endCoordX, endCoordY;
    
    BOOL requiresStream = NO;
    TouchStream *bar;
    if (lua_type(L, 1) == LUA_TUSERDATA) {
        bar = checkTouchStream(L, 1);
        endCoordX = (lua_Integer)luaL_checknumber(L, 2);
        endCoordY = (lua_Integer)luaL_checknumber(L, 3);
        requiresStream = YES;
    } else {
        bar = NULL;
        endCoordX = (lua_Integer)luaL_checknumber(L, 2);
        endCoordY = (lua_Integer)luaL_checknumber(L, 3);
    }
    
    /// Convert to CGPoint
    CGPoint endPoint = CGPointMake(endCoordX, endCoordY);
    
    /// Check endPoint
    if (![[SimulateTouchLuaBridge sharedBridge] containsOrientedPoint:endPoint]) {
        CGSize tSize = [[SimulateTouchLuaBridge sharedBridge] orientedSize];
        return luaL_error(L, SIMERR_COORDINATE_OUT_OF_RANGE, endCoordX, endCoordY, (NSUInteger)tSize.width, (NSUInteger)tSize.height);
    }

    int specifiedFinger;
    if (bar) {
        specifiedFinger = bar->finger;
    } else {
        specifiedFinger = (int)luaL_checkinteger(L, 1);
    }
    
    /// Check finger availability
    int tapFinger = specifiedFinger;
    int isLocked = STFingerIsLocked(tapFinger);
    if (isLocked < 0) {
        /// Invalid finger
        return luaL_error(L, SIMERR_FINGER_POOL_OVERFLOW);
    } else if (isLocked == 0) {
        /// Not locked
        return luaL_error(L, SIMERR_FINGER_NOT_USED, tapFinger);
    }
    
    lua_Number endPressure, endTwist;
    uint32_t extraMask;
    if (bar) {
        endPressure = luaL_optnumber(L, 4, (lua_Number)bar->pressure);
        endTwist = luaL_optnumber(L, 5, (lua_Number)bar->twist);
        extraMask = (uint32_t)luaL_optinteger(L, 6, (lua_Integer)bar->extra_mask);
    } else {
        endPressure = luaL_optnumber(L, 4, STFingerStatusRecord(tapFinger)->pressure);
        endTwist = luaL_optnumber(L, 5, STFingerStatusRecord(tapFinger)->twist);
        extraMask = (uint32_t)luaL_optinteger(L, 6, STFingerStatusRecord(tapFinger)->extra_mask);
    }
    
    {
        /// Construct event stream
        CGSize nativeSize = [SimulateTouchLuaBridge nativeSize];
        CGPoint eventEndPoint = [[SimulateTouchLuaBridge sharedBridge] rotatePoint:endPoint toOrientation:SimulateTouchOrientationHomeOnBottom];
        
        lua_Number eventEndPressure = endPressure / 1e4;
        lua_Number eventEndTwist = endTwist / 1e2;
        
        NSTimeInterval eventDuration;
        NSDictionary *eventStream;
        if (bar == NULL) {
            
            /// Move finger directly
            eventStream = @{
                SecondLevelEventsKey: @[
                    STDictionaryJoinLockedFingers(
                        STCreateDictionaryWithSingleFingerEvent(
                            tapFinger, HIDEventPhaseMoved, 0,
                            eventEndPoint,
                            eventEndPressure,
                            eventEndTwist,
                            extraMask,
                            nativeSize
                        ), tapFinger, 0, nativeSize
                    ),
                ],
            };
            
            eventDuration = 0;
            
        } else {
            
            /// Move finger gracefully
            CGPoint eventBeginPoint = [[SimulateTouchLuaBridge sharedBridge] rotatePoint:bar->location toOrientation:SimulateTouchOrientationHomeOnBottom];
            double eventDistance = hypot(fabs(eventEndPoint.x - eventBeginPoint.x), fabs(eventEndPoint.y - eventBeginPoint.y));
            
            NSTimeInterval eventTimeStepInSeconds = bar->step_delay_ms / 1e3;
            NSTimeInterval eventEstimatedDuration = eventDistance / bar->step_len_px * eventTimeStepInSeconds;
            
            NSString *eventInterpolationType = HIDEventInterpolationTypeLinear;
            if (bar->animation_type == TouchStreamAnimationTypeLinear) {
                eventInterpolationType = HIDEventInterpolationTypeLinear;
            }
            else if (bar->animation_type == TouchStreamAnimationTypeSimpleCurve) {
                eventInterpolationType = HIDEventInterpolationTypeSimpleCurve;
            }
            
            double eventBeginPressure = bar->pressure;
            
            eventStream = @{
                SecondLevelEventsKey: @[
                    STCreateDictionaryWithInterpolatedFingerEvents(
                        tapFinger, HIDEventPhaseMoved,
                        0, eventEstimatedDuration,
                        eventInterpolationType,
                        eventTimeStepInSeconds,
                        eventBeginPoint, eventBeginPressure,
                        eventEndPoint, eventEndPressure,
                        eventEndTwist,
                        extraMask,
                        nativeSize
                    ),
                ],
            };
            
            eventDuration = eventEstimatedDuration;
            
        }
        
        CHDebugLogSource(@"sendEventStream %@", eventStream);
        [[SimulateTouch sharedInstance] sendEventStream:eventStream];
        
        /// Update records
        STFingerStatusRecord(tapFinger)->location = endPoint;
        STFingerStatusRecord(tapFinger)->pressure = endPressure;
        STFingerStatusRecord(tapFinger)->twist = endTwist;
        STFingerStatusRecord(tapFinger)->extra_mask = extraMask;
        
        /// Perform delay after operation
        BOOL isMain = lua_pushthread(L) == 1;
        lua_pop(L, 1);
        if (eventDuration > 1e-4) {
            if (isMain) {
                [NSThread sleepForTimeInterval:eventDuration];
            }
            else {
                /// Delay and unlock
                StreamSleepState *streamSleep = (StreamSleepState *)lua_newuserdata(L, sizeof(StreamSleepState));
                streamSleep->deadline = l_uptime() + eventDuration;
                streamSleep->persistent = requiresStream;
                
                memcpy(&streamSleep->stream, bar, sizeof(TouchStream));
                streamSleep->stream.finger = tapFinger;
                streamSleep->stream.location = endPoint;
                streamSleep->stream.pressure = endPressure;
                streamSleep->stream.twist = endTwist;
                streamSleep->stream.extra_mask = extraMask;
                
                return lua_yieldk(L, 0, (lua_KContext)streamSleep, SimulateTouch_StreamSleep_Yield);
            }
        }
    }
    
    if (!requiresStream)
        return 0;
    
    /// Construct touch stream
    TouchStream *foo = pushTouchStream(L);
    if (bar)
        memcpy(foo, bar, sizeof(TouchStream));
    else
        bzero(foo, sizeof(TouchStream));
    foo->finger = tapFinger;
    foo->location = endPoint;
    foo->pressure = endPressure;
    foo->twist = endTwist;
    foo->extra_mask = extraMask;
    return 1;
}

/**
 * Press existing finger
 */
// HINT: Since Apple has removed “3D Touch” feature for all new iOS devices, 
//       the parameter `pressure` may not be used in future implementation.
static int SimulateTouch_Press(lua_State *L)
{
    TouchStream *bar = checkTouchStream(L, 1);
    
    /// Convert to CGPoint
    CGPoint endPoint = bar->location;
    
    /// Check endPoint
    if (![[SimulateTouchLuaBridge sharedBridge] containsOrientedPoint:endPoint]) {
        CGSize tSize = [[SimulateTouchLuaBridge sharedBridge] orientedSize];
        return luaL_error(L, SIMERR_COORDINATE_OUT_OF_RANGE, (int)endPoint.x, (int)endPoint.y, (NSUInteger)tSize.width, (NSUInteger)tSize.height);
    }
    
    lua_Number endPressure = luaL_optnumber(L, 2, (lua_Number)bar->pressure);
    lua_Number endTwist = luaL_optnumber(L, 3, (lua_Number)bar->twist);
    uint32_t extraMask = (uint32_t)luaL_optinteger(L, 4, (lua_Integer)bar->extra_mask);
    
    /// Check finger availability
    int tapFinger = bar->finger;
    int isLocked = STFingerIsLocked(tapFinger);
    if (isLocked < 0) {
        /// Invalid finger
        return luaL_error(L, SIMERR_FINGER_POOL_OVERFLOW);
    } else if (isLocked == 0) {
        /// Not locked
        return luaL_error(L, SIMERR_FINGER_NOT_USED, tapFinger);
    }
    
    {
        /// Construct event stream
        CGSize nativeSize = [SimulateTouchLuaBridge nativeSize];
        CGPoint eventEndPoint = [[SimulateTouchLuaBridge sharedBridge] rotatePoint:endPoint toOrientation:SimulateTouchOrientationHomeOnBottom];
        
        lua_Number eventEndPressure = endPressure / 1e4;
        lua_Number eventEndTwist = endTwist / 1e2;
        
        NSDictionary *eventStream = @{
            SecondLevelEventsKey: @[
                STDictionaryJoinLockedFingers(
                    STCreateDictionaryWithSingleFingerEvent(
                        tapFinger, HIDEventPhaseMoved, 0,
                        eventEndPoint,
                        eventEndPressure,
                        eventEndTwist,
                        extraMask,
                        nativeSize
                    ), tapFinger, 0, nativeSize
                ),
            ],
        };
        
        CHDebugLogSource(@"sendEventStream %@", eventStream);
        [[SimulateTouch sharedInstance] sendEventStream:eventStream];
    }
    
    // Update records
    STFingerStatusRecord(tapFinger)->pressure = endPressure;
    STFingerStatusRecord(tapFinger)->twist = endTwist;
    STFingerStatusRecord(tapFinger)->extra_mask = extraMask;
    
    TouchStream *foo = pushTouchStream(L);
    memcpy(foo, bar, sizeof(TouchStream));
    foo->finger = tapFinger;
    foo->location = endPoint;
    foo->pressure = endPressure;
    foo->twist = endTwist;
    foo->extra_mask = extraMask;
    return 1;
}

/**
 * Off existing finger
 */
static int SimulateTouch_Off(lua_State *L)
{
    lua_Integer endCoordX, endCoordY, specifiedFinger;
    uint32_t extraMask;
    
    TouchStream *bar;
    if (lua_type(L, 1) == LUA_TUSERDATA) {
        bar = checkTouchStream(L, 1);
        specifiedFinger = bar->finger;
    } else {
        bar = NULL;
        specifiedFinger = luaL_checkinteger(L, 1);
    }
    
    /// No need to check endPoint
    /// Check finger availability
    int tapFinger = (int)specifiedFinger;
    int isLocked = STFingerIsLocked(tapFinger);
    if (isLocked < 0) {
        /// Invalid finger
        return luaL_error(L, SIMERR_FINGER_POOL_OVERFLOW);
    } else if (isLocked == 0) {
        /// Not locked
        return luaL_error(L, SIMERR_FINGER_NOT_USED, tapFinger);
    }
    
    if (bar) {
        endCoordX = (lua_Integer)luaL_optnumber(L, 2, (lua_Number)bar->location.x);
        endCoordY = (lua_Integer)luaL_optnumber(L, 3, (lua_Number)bar->location.y);
        extraMask = (uint32_t)luaL_optinteger(L, 4, (lua_Integer)bar->extra_mask);
    } else {
        endCoordX = (lua_Integer)luaL_optnumber(L, 2, STFingerStatusRecord(tapFinger)->location.x);
        endCoordY = (lua_Integer)luaL_optnumber(L, 3, STFingerStatusRecord(tapFinger)->location.y);
        extraMask = (uint32_t)luaL_optinteger(L, 4, STFingerStatusRecord(tapFinger)->extra_mask);
    }
    
    /// Convert to CGPoint
    CGPoint endPoint = CGPointMake(endCoordX, endCoordY);
    
    {
        NSTimeInterval defaultOffInterval = 30.0 / 1e3;
        
        /// Construct event stream
        CGSize nativeSize = [SimulateTouchLuaBridge nativeSize];
        CGPoint eventEndPoint = [[SimulateTouchLuaBridge sharedBridge] rotatePoint:endPoint toOrientation:SimulateTouchOrientationHomeOnBottom];
        lua_Number eventEndPressure, eventEndTwist;
        
        NSDictionary *eventStream;
        if (bar == NULL) {
            eventEndPressure = 0;
            eventEndTwist = 0;
            eventStream = @{
                SecondLevelEventsKey: @[
                    STDictionaryJoinLockedFingers(
                        STCreateDictionaryWithSingleFingerEvent(
                            tapFinger, HIDEventPhaseEnded,
                            defaultOffInterval,
                            eventEndPoint,
                            eventEndPressure,
                            eventEndTwist,
                            extraMask,
                            nativeSize
                        ), tapFinger, defaultOffInterval, nativeSize
                    ),
                ],
            };
        } else {
            eventEndPressure = bar->pressure / 1e4;
            eventEndTwist = bar->twist / 1e2;
            eventStream = @{
                SecondLevelEventsKey: @[
                    STDictionaryJoinLockedFingers(
                        STCreateDictionaryWithSingleFingerEvent(
                            tapFinger, HIDEventPhaseEnded,
                            defaultOffInterval,
                            eventEndPoint,
                            eventEndPressure,
                            eventEndTwist,
                            extraMask,
                            nativeSize
                        ), tapFinger, defaultOffInterval, nativeSize
                    ),
                ],
            };
        }
        
        CHDebugLogSource(@"sendEventStream %@", eventStream);
        [[SimulateTouch sharedInstance] sendEventStream:eventStream];
    }
    
    /// Update records
    STFingerStatusRecord(tapFinger)->location = endPoint;
    STFingerStatusRecord(tapFinger)->extra_mask = extraMask;
    
    /// Unlock finger
    STFingerUnlock(tapFinger);
    CHDebugLogSource(@"Finger %d unlocked", tapFinger);
    
    return 0;
}

/**
 * Accuate delay
 */

typedef struct SleepState {
    NSTimeInterval deadline;
} SleepState;

static int SimulateTouch_Sleep_Yield(lua_State *L, int status, lua_KContext ctx)
{
    SleepState *sleep = (SleepState *)ctx;
    // [NSThread sleepForTimeInterval:1e-4];  // 0.1ms
    
    if (l_uptime() > sleep->deadline)
        return 0;
    
    return lua_yieldk(L, 0, ctx, SimulateTouch_Sleep_Yield);
}

static int SimulateTouch_StreamSleepInSeconds(lua_State *L)
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    if (lua_type(L, 1) == LUA_TUSERDATA) {
        
        TouchStream *bar = checkTouchStream(L, 1);
        lua_Number sleepInterval = luaL_optnumber(L, 2, 1e-4);
        
        BOOL isMain = lua_pushthread(L) == 1;
        lua_pop(L, 1);
        if (!isMain) {
            
            /// Delay and unlock
            StreamSleepState *streamSleep = (StreamSleepState *)lua_newuserdata(L, sizeof(StreamSleepState));
            streamSleep->deadline = l_uptime() + sleepInterval;
            streamSleep->persistent = true;
            
            memcpy(&streamSleep->stream, bar, sizeof(TouchStream));
            return lua_yieldk(L, 0, (lua_KContext)streamSleep, SimulateTouch_StreamSleep_Yield);
        }
        
        [NSThread sleepForTimeInterval:sleepInterval];
        TouchStream *foo = pushTouchStream(L);
        memcpy(foo, bar, sizeof(TouchStream));
        
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
        
    } else {
        
        lua_Number sleepInterval = luaL_checknumber(L, 1);
        
        BOOL isMain = lua_pushthread(L) == 1;
        lua_pop(L, 1);
        if (!isMain) {
            
            /// Delay and unlock
            SleepState *sleep = (SleepState *)lua_newuserdata(L, sizeof(SleepState));
            sleep->deadline = l_uptime() + sleepInterval;
            
            return lua_yieldk(L, 0, (lua_KContext)sleep, SimulateTouch_Sleep_Yield);
        }
        
        [NSThread sleepForTimeInterval:sleepInterval];
        
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 0;
    }
}

static int SimulateTouch_StreamSleepInMilliseconds(lua_State *L)
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    if (lua_type(L, 1) == LUA_TUSERDATA) {
        
        TouchStream *bar = checkTouchStream(L, 1);
        lua_Number sleepInterval = luaL_optnumber(L, 2, 0.1);
        
        sleepInterval /= 1e3;
        
        BOOL isMain = lua_pushthread(L) == 1;
        lua_pop(L, 1);
        if (!isMain) {
            
            /// Delay and unlock
            StreamSleepState *streamSleep = (StreamSleepState *)lua_newuserdata(L, sizeof(StreamSleepState));
            streamSleep->deadline = l_uptime() + sleepInterval;
            streamSleep->persistent = true;
            
            memcpy(&streamSleep->stream, bar, sizeof(TouchStream));
            return lua_yieldk(L, 0, (lua_KContext)streamSleep, SimulateTouch_StreamSleep_Yield);
        }
        
        [NSThread sleepForTimeInterval:sleepInterval];
        TouchStream *foo = pushTouchStream(L);
        memcpy(foo, bar, sizeof(TouchStream));
        
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
        
    } else {
        
        lua_Number sleepInterval = luaL_checknumber(L, 1);
        sleepInterval /= 1e3;
        
        BOOL isMain = lua_pushthread(L) == 1;
        lua_pop(L, 1);
        if (!isMain) {
            
            /// Delay and unlock
            SleepState *sleep = (SleepState *)lua_newuserdata(L, sizeof(SleepState));
            sleep->deadline = l_uptime() + sleepInterval;
            
            return lua_yieldk(L, 0, (lua_KContext)sleep, SimulateTouch_Sleep_Yield);
        }
        
        [NSThread sleepForTimeInterval:sleepInterval];
        
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 0;
    }
}

/**
 * Touch stream garbage collection
 */
static int SimulateTouch_StreamGC(lua_State *L)
{
    fprintf(stderr, "gc, " L_TYPE_TOUCH_STREAM " = %p\n", toTouchStream(L, 1));
    return 0;
}

/**
 * Touch stream description
 */
static int SimulateTouch_StreamToString(lua_State *L)
{
    char buff[32];
    TouchStream *bar = toTouchStream(L, 1);
    snprintf(buff, 32, "%p <Finger #%d>", bar, bar->finger);
    lua_pushfstring(L, L_TYPE_TOUCH_STREAM ": %s", buff);
    return 1;
}

/**
 * Perform a single tap gesture on current coordinate system.
 */

typedef struct UnlockState {
    int finger;
    NSTimeInterval deadline;
} UnlockState;

static int SimulateTouch_Tap_Yield(lua_State *L, int status, lua_KContext ctx)
{
    UnlockState *unlock = (UnlockState *)ctx;
    [NSThread sleepForTimeInterval:1e-4];  // 0.1ms
    
    if (l_uptime() > unlock->deadline)
    {
        STFingerUnlock(unlock->finger);
        CHDebugLogSource(@"Finger %d unlocked", unlock->finger);
        return 0;
    }
    
    return lua_yieldk(L, 0, ctx, SimulateTouch_Tap_Yield);
}

static int SimulateTouch_Tap(lua_State *L)
{
    /// Argument #1, #2: point (x, y) to tap
    lua_Integer lCoordX = (lua_Integer)luaL_checknumber(L, 1);
    lua_Integer lCoordY = (lua_Integer)luaL_checknumber(L, 2);
    
    /// Convert to CGPoint
    CGPoint endPoint = CGPointMake(lCoordX, lCoordY);
    
    /// Check argument #1, #2
    if (![[SimulateTouchLuaBridge sharedBridge] containsOrientedPoint:endPoint]) {
        CGSize tSize = [[SimulateTouchLuaBridge sharedBridge] orientedSize];
        return luaL_error(L, SIMERR_COORDINATE_OUT_OF_RANGE, lCoordX, lCoordY, (NSUInteger)tSize.width, (NSUInteger)tSize.height);
    }
    
    /// Argument #3
    lua_Number delayBetweenUpAndDownInMilliseconds = luaL_optnumber(L, 3, 30);
    NSTimeInterval delayBetweenUpAndDownInSeconds = (NSTimeInterval)delayBetweenUpAndDownInMilliseconds / 1e3;
    
    /// Argument #4
    lua_Number delayAfterOperationInMilliseconds = luaL_optnumber(L, 4, 0);
    NSTimeInterval delayAfterOperationInSeconds = (NSTimeInterval)delayAfterOperationInMilliseconds / 1e3;
    
    /// Lock any finger
    int tapFinger = STAnyFinger();
    if (tapFinger <= 0) {
        return luaL_error(L, SIMERR_FINGER_POOL_OVERFLOW);
    }
    
    CHDebugLogSource(@"Finger %d locked", tapFinger);
    
    /// Construct event stream
    NSMutableDictionary *eventStream = [[NSMutableDictionary alloc] initWithCapacity:1];
    {
        CGSize nativeSize = [SimulateTouchLuaBridge nativeSize];
        CGPoint eventPoint = [[SimulateTouchLuaBridge sharedBridge] rotatePoint:endPoint toOrientation:SimulateTouchOrientationHomeOnBottom];
        NSMutableArray <NSDictionary *> *events = [[NSMutableArray alloc] initWithCapacity:2];
        {
            NSTimeInterval timeOffset = 0;
            NSDictionary *event = nil;
            
            event = STCreateDictionaryWithSingleFingerEvent(tapFinger, HIDEventPhaseBegan, timeOffset, eventPoint, 0, 0.5, 0x0, nativeSize);
            timeOffset += delayBetweenUpAndDownInSeconds;
            [events addObject:event];
            
            event = STCreateDictionaryWithSingleFingerEvent(tapFinger, HIDEventPhaseEnded, timeOffset, eventPoint, 0, 0.5, 0x0, nativeSize);
            [events addObject:event];
        }
        [eventStream setObject:events forKey:SecondLevelEventsKey];
    }
    
    /// Send event stream directly
    CHDebugLogSource(@"sendEventStream %@", eventStream);
    [[SimulateTouch sharedInstance] sendEventStream:eventStream];
    
    /// Update records
    STFingerStatusRecord(tapFinger)->location = endPoint;
    STFingerStatusRecord(tapFinger)->pressure = 0;
    STFingerStatusRecord(tapFinger)->twist = 50.0;
    STFingerStatusRecord(tapFinger)->extra_mask = 0;
    
    BOOL isMain = lua_pushthread(L) == 1;
    lua_pop(L, 1);
    
    if (!isMain) {
        
        /// Delay and unlock
        UnlockState *unlock = (UnlockState *)lua_newuserdata(L, sizeof(UnlockState));
        if (delayAfterOperationInMilliseconds > 0) {
            unlock->deadline = l_uptime() + delayBetweenUpAndDownInSeconds + delayAfterOperationInSeconds;
        } else {
            unlock->deadline = l_uptime() + delayBetweenUpAndDownInSeconds;
        }
        unlock->finger = tapFinger;
        
        return lua_yieldk(L, 0, (lua_KContext)unlock, SimulateTouch_Tap_Yield);
    }
    
    /// Perform delay after operation if specified
    if (delayAfterOperationInMilliseconds > 0) {
        [NSThread sleepForTimeInterval:delayBetweenUpAndDownInSeconds + delayAfterOperationInSeconds];
    } else {
        [NSThread sleepForTimeInterval:delayBetweenUpAndDownInSeconds];
    }
    
    /// Unlock finger
    STFingerUnlock(tapFinger);
    CHDebugLogSource(@"Finger %d unlocked", tapFinger);
    
    return 0;
}

static int SimulateTouchKey_SendText(lua_State *L)
{
    const char *cKeyCodes = luaL_checkstring(L, 1);

    NSString *keyCodes = [NSString stringWithUTF8String:cKeyCodes];
    if (keyCodes.length == 0) {
        return 0;
    }

    lua_Number cInterval = luaL_optnumber(L, 2, 0);
    cInterval /= 1e3;

    [keyCodes enumerateSubstringsInRange:NSMakeRange(0, keyCodes.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
        CHDebugLogSource(@"substring: %@, substringRange: %@, enclosingRange %@",
              substring, NSStringFromRange(substringRange), NSStringFromRange(enclosingRange));
        
        [[SimulateTouch sharedInstance] keyPress:substring];
        [NSThread sleepForTimeInterval:0.05];

        if (cInterval > 1e-4) {
            [NSThread sleepForTimeInterval:MAX(cInterval, 0.01)];
        }
    }];
    
    return 0;
}


#pragma mark -

static int SimulateTouchKey_PressHome(lua_State *L)
{
    
    [[SimulateTouch sharedInstance] menuPress];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_LongPressHome(lua_State *L)
{
    
    [[SimulateTouch sharedInstance] menuLongPress];
    [NSThread sleepForTimeInterval:2.0];
    return 0;
}

static int SimulateTouchKey_DoublePressHome(lua_State *L)
{
    
    [[SimulateTouch sharedInstance] menuDoublePress];
    [NSThread sleepForTimeInterval:0.25];
    return 0;
}

static int SimulateTouchKey_PressPower(lua_State *L)
{
    [[SimulateTouch sharedInstance] powerPress];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_LongPressPower(lua_State *L)
{
    [[SimulateTouch sharedInstance] powerLongPress];
    [NSThread sleepForTimeInterval:2.0];
    return 0;
}

static int SimulateTouchKey_DoublePressPower(lua_State *L)
{
    [[SimulateTouch sharedInstance] powerDoublePress];
    [NSThread sleepForTimeInterval:0.25];
    return 0;
}

static int SimulateTouchKey_TriplePressPower(lua_State *L)
{
    [[SimulateTouch sharedInstance] powerTriplePress];
    [NSThread sleepForTimeInterval:0.45];
    return 0;
}

static int SimulateTouchKey_PressSnapshot(lua_State *L)
{
    [[SimulateTouch sharedInstance] snapshotPress];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_ToggleKeyboard(lua_State *L)
{
    [[SimulateTouch sharedInstance] toggleOnScreenKeyboard];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_ToggleSpotlight(lua_State *L)
{
    [[SimulateTouch sharedInstance] toggleSpotlight];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_PressMute(lua_State *L)
{
    [[SimulateTouch sharedInstance] mutePress];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_PressVolumeUp(lua_State *L)
{
    [[SimulateTouch sharedInstance] volumeIncrementPress];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_PressVolumeDown(lua_State *L)
{
    [[SimulateTouch sharedInstance] volumeDecrementPress];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_PressBrightnessUp(lua_State *L)
{
    [[SimulateTouch sharedInstance] displayBrightnessIncrementPress];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_PressBrightnessDown(lua_State *L)
{
    [[SimulateTouch sharedInstance] displayBrightnessDecrementPress];
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_Press(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char *cKeyCode = luaL_checkstring(L, 1);
        NSString *keyCode = [NSString stringWithUTF8String:cKeyCode];
        NSString *uKeyCode = [keyCode uppercaseString];
        
        if ([uKeyCode isEqualToString:@"LOCK"] || [uKeyCode isEqualToString:@"POWER"]) {
            return SimulateTouchKey_PressPower(L);
        }
        else if ([uKeyCode isEqualToString:@"HOMEBUTTON"] || [uKeyCode isEqualToString:@"MENU"]) {
            return SimulateTouchKey_PressHome(L);
        }
        else if ([uKeyCode isEqualToString:@"MUTE"]) {
            return SimulateTouchKey_PressMute(L);
        }
        else if ([uKeyCode isEqualToString:@"VOLUMEUP"]) {
            return SimulateTouchKey_PressVolumeUp(L);
        }
        else if ([uKeyCode isEqualToString:@"VOLUMEDOWN"]) {
            return SimulateTouchKey_PressVolumeDown(L);
        }
        else if ([uKeyCode isEqualToString:@"BRIGHTUP"]) {
            return SimulateTouchKey_PressBrightnessUp(L);
        }
        else if ([uKeyCode isEqualToString:@"BRIGHTDOWN"]) {
            return SimulateTouchKey_PressBrightnessDown(L);
        }
        else if ([uKeyCode isEqualToString:@"SNAPSHOT"]) {
            return SimulateTouchKey_PressSnapshot(L);
        }
        else if ([uKeyCode isEqualToString:@"SHOW_HIDE_KEYBOARD"] || [uKeyCode isEqualToString:@"TOGGLE_KEYBOARD"]) {
            return SimulateTouchKey_ToggleKeyboard(L);
        }
        else if ([uKeyCode isEqualToString:@"SPOTLIGHT"]) {
            return SimulateTouchKey_ToggleSpotlight(L);
        }
        
        [[SimulateTouch sharedInstance] keyPress:keyCode];
    } else {
        uint32_t cPage = (uint32_t)luaL_checkinteger(L, 1);
        uint32_t cUsage = (uint32_t)luaL_checkinteger(L, 2);
        
        [[SimulateTouch sharedInstance] otherPage:cPage usagePress:cUsage];
    }
    
    [NSThread sleepForTimeInterval:0.05];
    return 0;
}

static int SimulateTouchKey_Down(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char *cKeyCode = luaL_checkstring(L, 1);
        NSString *keyCode = [NSString stringWithUTF8String:cKeyCode];
        NSString *uKeyCode = [keyCode uppercaseString];
        
        if ([uKeyCode isEqualToString:@"LOCK"] || [uKeyCode isEqualToString:@"POWER"]) {
            [[SimulateTouch sharedInstance] powerDown];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"HOMEBUTTON"] || [uKeyCode isEqualToString:@"MENU"]) {
            [[SimulateTouch sharedInstance] menuDown];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"MUTE"]) {
            [[SimulateTouch sharedInstance] muteDown];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"VOLUMEUP"]) {
            [[SimulateTouch sharedInstance] volumeIncrementDown];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"VOLUMEDOWN"]) {
            [[SimulateTouch sharedInstance] volumeDecrementDown];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"BRIGHTUP"]) {
            [[SimulateTouch sharedInstance] displayBrightnessIncrementDown];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"BRIGHTDOWN"]) {
            [[SimulateTouch sharedInstance] displayBrightnessDecrementDown];
            return 0;
        }
        
        [[SimulateTouch sharedInstance] keyDown:keyCode];
    } else {
        uint32_t cPage = (uint32_t)luaL_checkinteger(L, 1);
        uint32_t cUsage = (uint32_t)luaL_checkinteger(L, 2);
        
        [[SimulateTouch sharedInstance] otherPage:cPage usageDown:cUsage];
    }
    return 0;
}

static int SimulateTouchKey_Up(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char *cKeyCode = luaL_checkstring(L, 1);
        NSString *keyCode = [NSString stringWithUTF8String:cKeyCode];
        NSString *uKeyCode = [keyCode uppercaseString];
        
        if ([uKeyCode isEqualToString:@"LOCK"] || [uKeyCode isEqualToString:@"POWER"]) {
            [[SimulateTouch sharedInstance] powerUp];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"HOMEBUTTON"] || [uKeyCode isEqualToString:@"MENU"]) {
            [[SimulateTouch sharedInstance] menuUp];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"MUTE"]) {
            [[SimulateTouch sharedInstance] muteUp];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"VOLUMEUP"]) {
            [[SimulateTouch sharedInstance] volumeIncrementUp];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"VOLUMEDOWN"]) {
            [[SimulateTouch sharedInstance] volumeDecrementUp];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"BRIGHTUP"]) {
            [[SimulateTouch sharedInstance] displayBrightnessIncrementUp];
            return 0;
        }
        else if ([uKeyCode isEqualToString:@"BRIGHTDOWN"]) {
            [[SimulateTouch sharedInstance] displayBrightnessDecrementUp];
            return 0;
        }
        
        [[SimulateTouch sharedInstance] keyUp:keyCode];
    } else {
        uint32_t cPage = (uint32_t)luaL_checkinteger(L, 1);
        uint32_t cUsage = (uint32_t)luaL_checkinteger(L, 2);
        
        [[SimulateTouch sharedInstance] otherPage:cPage usageUp:cUsage];
    }
    return 0;
}

static int SimulateTouch_ShowPose(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    BOOL cEnabled = lua_toboolean(L, 1);

    [[SimulateTouch sharedInstance] setShouldShowTouches:cEnabled];
    return 0;
}


#pragma mark -

static const luaL_Reg SimulateTouch_Stream_MetaLib[] = {
    
    /* Internal APIs */
    {"__gc",       SimulateTouch_StreamGC},
    {"__tostring", SimulateTouch_StreamToString},
    
    /* Low-Level APIs */
    {"move", SimulateTouch_Move},
    {"press", SimulateTouch_Press},
    {"off", SimulateTouch_Off},
    {"step_len", SimulateTouch_StepLen},
    {"step_delay", SimulateTouch_StepDelay},
    {"animation", SimulateTouch_Animation},
    {"sleep", SimulateTouch_StreamSleepInSeconds},
    {"msleep", SimulateTouch_StreamSleepInMilliseconds},
    {"delay", SimulateTouch_StreamSleepInMilliseconds},  // alias of msleep
    
    {NULL, NULL},
};

static const luaL_Reg SimulateTouch_AuxLib[] = {
    
    /* Initialize & Coordinate System */
    {"init", SimulateTouch_Init},
    {"init_home_on_bottom", SimulateTouch_Init_HomeOnBottom},
    {"init_home_on_right", SimulateTouch_Init_HomeOnRight},
    {"init_home_on_left", SimulateTouch_Init_HomeOnLeft},
    {"init_home_on_top", SimulateTouch_Init_HomeOnTop},
    {"orientation", SimulateTouch_Orientation},
    {"size", SimulateTouch_Size},
    {"rotate_xy", SimulateTouch_RotateXY},
    
    /* Low-Level APIs */
    {"is", SimulateTouch_Is},
    {"on", SimulateTouch_On},
    {"down", SimulateTouch_On},
    {"move", SimulateTouch_Move},
    {"off", SimulateTouch_Off},
    {"up", SimulateTouch_Off},
#if DEBUG
    {"sleep", SimulateTouch_StreamSleepInSeconds},
    {"msleep", SimulateTouch_StreamSleepInMilliseconds},
#endif
    
    /* Convenience */
    {"tap", SimulateTouch_Tap},

    /* Debug */
    {"show_pose", SimulateTouch_ShowPose},
    
    {NULL, NULL},
};

static const luaL_Reg SimulateTouchKey_AuxLib[] = {
    
    /* Low-Level APIs */
    {"press", SimulateTouchKey_Press},
    {"down", SimulateTouchKey_Down},
    {"up", SimulateTouchKey_Up},
#if DEBUG
    {"sleep", SimulateTouch_StreamSleepInSeconds},
    {"msleep", SimulateTouch_StreamSleepInMilliseconds},
#endif
    {"send_text", SimulateTouchKey_SendText},
    
    /* Home Convenience */
    {"press_home", SimulateTouchKey_PressHome},
    {"long_press_home", SimulateTouchKey_LongPressHome},
    {"double_press_home", SimulateTouchKey_DoublePressHome},
    
    /* Power Convenience */
    {"press_power", SimulateTouchKey_PressPower},
    {"long_press_power", SimulateTouchKey_LongPressPower},
    {"double_press_power", SimulateTouchKey_DoublePressPower},
    {"triple_press_power", SimulateTouchKey_TriplePressPower},
    
    /* Other Convenience */
    {"press_snapshot", SimulateTouchKey_PressSnapshot},
    {"press_mute", SimulateTouchKey_PressMute},
    {"press_volume_up", SimulateTouchKey_PressVolumeUp},
    {"press_volume_down", SimulateTouchKey_PressVolumeDown},
    {"press_brightness_up", SimulateTouchKey_PressBrightnessUp},
    {"press_brightness_down", SimulateTouchKey_PressBrightnessDown},
    
    {"toggle_keyboard", SimulateTouchKey_ToggleKeyboard},
    {"toggle_spotlight", SimulateTouchKey_ToggleSpotlight},
    
    {NULL, NULL},
};

XXTouchF_CAPI int luaopen_touch(lua_State *L)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bzero(_sharedFingerStatusRecords, MAX_FINGER_COUNT * sizeof(FINGER_STATUS));
        
        luaL_newmetatable(L, L_TYPE_TOUCH_STREAM);
        lua_pushstring(L, "__index");
        lua_pushvalue(L, -2);
        lua_settable(L, -3);
        luaL_setfuncs(L, SimulateTouch_Stream_MetaLib, 0);
    });
    
    lua_createtable(L, 0, (sizeof(SimulateTouch_AuxLib) / sizeof((SimulateTouch_AuxLib)[0]) - 1) + 6);
#if DEBUG
    lua_pushliteral(L, LUA_MODULE_VERSION "+debug");
#else
    lua_pushliteral(L, LUA_MODULE_VERSION);
#endif
    lua_setfield(L, -2, "_VERSION");
    lua_pushinteger(L, 0);
    lua_setfield(L, -2, "ORIENTATION_HOME_ON_BOTTOM");
    lua_pushinteger(L, 1);
    lua_setfield(L, -2, "ORIENTATION_HOME_ON_RIGHT");
    lua_pushinteger(L, 2);
    lua_setfield(L, -2, "ORIENTATION_HOME_ON_LEFT");
    lua_pushinteger(L, 3);
    lua_setfield(L, -2, "ORIENTATION_HOME_ON_UP");
    luaL_setfuncs(L, SimulateTouch_AuxLib, 0);
    
    return 1;
}

XXTouchF_CAPI int luaopen_extouch(lua_State *L)
{
    return luaopen_touch(L);
}

XXTouchF_CAPI int luaopen_key(lua_State *L)
{
    lua_createtable(L, 0, (sizeof(SimulateTouchKey_AuxLib) / sizeof((SimulateTouchKey_AuxLib)[0]) - 1) + 2);
#if DEBUG
    lua_pushliteral(L, LUA_MODULE_VERSION "+debug");
#else
    lua_pushliteral(L, LUA_MODULE_VERSION);
#endif
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, SimulateTouchKey_AuxLib, 0);
    
    return 1;
}

XXTouchF_CAPI int luaopen_exkey(lua_State *L)
{
    return luaopen_key(L);
}
