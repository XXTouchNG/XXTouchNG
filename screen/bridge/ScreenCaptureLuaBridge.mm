#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"
#import <pthread.h>

#import <UIKit/UIScreen.h>
#import <Vision/Vision.h>
#import "ScreenCapture.h"

#import "luae.h"
#import "JSTPixelColor.h"
#import "JSTPixelImage+Private.h"
#import "ScreenCaptureOpenCVWrapper.h"


#pragma mark -

XXTouchF_CAPI int luaopen_screen(lua_State *);
XXTouchF_CAPI int luaopen_exscreen(lua_State *);
XXTouchF_CAPI int luaopen_image(lua_State *);
XXTouchF_CAPI int luaopen_eximage(lua_State *);

typedef enum : NSUInteger {
    ScreenCaptureOrientationHomeOnBottom = 0,
    ScreenCaptureOrientationHomeOnRight,
    ScreenCaptureOrientationHomeOnLeft,
    ScreenCaptureOrientationHomeOnTop,
} ScreenCaptureOrientation;

@interface ScreenCaptureLuaBridge : NSObject
    
+ (CGSize)nativeSize;
+ (CGRect)nativeRect;

+ (instancetype)sharedBridge;

- (ScreenCaptureOrientation)orientation;
- (void)setOrientation:(ScreenCaptureOrientation)orientation;
- (CGSize)orientedSize;
- (CGRect)orientedBounds;

- (BOOL)containsOrientedPoint:(CGPoint)point;
- (CGPoint)rotatePoint:(CGPoint)point toOrientation:(ScreenCaptureOrientation)alternativeOrientation;

- (BOOL)shouldKeepScreen;
- (void)setShouldKeepScreen:(BOOL)shouldKeepScreen;

@end

@implementation ScreenCaptureLuaBridge {
    BOOL _shouldKeepScreen;
}

+ (instancetype)sharedBridge {
    static ScreenCaptureLuaBridge *_sharedBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedBridge = [[ScreenCaptureLuaBridge alloc] init];
    });
    return _sharedBridge;
}

- (ScreenCaptureOrientation)orientation {
    return (ScreenCaptureOrientation)[[[ScreenCapture sharedCapture] pixelImage] orientation];
}

- (void)setOrientation:(ScreenCaptureOrientation)orientation {
    [[[ScreenCapture sharedCapture] pixelImage] setOrientation:orientation];
}

- (BOOL)shouldKeepScreen {
    return _shouldKeepScreen;
}

- (void)setShouldKeepScreen:(BOOL)shouldKeepScreen {
    _shouldKeepScreen = shouldKeepScreen;
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
    CGSize nativeSize = [ScreenCaptureLuaBridge nativeSize];
    if (self.orientation == ScreenCaptureOrientationHomeOnBottom || self.orientation == ScreenCaptureOrientationHomeOnTop) {
        return CGSizeMake(nativeSize.width, nativeSize.height);
    }
    return CGSizeMake(nativeSize.height, nativeSize.width);
}

- (CGRect)orientedBounds {
    CGSize orientSize = [self orientedSize];
    return CGRectMake(0, 0, orientSize.width, orientSize.height);
}

- (BOOL)containsOrientedPoint:(CGPoint)point {
    return CGRectContainsPoint([self orientedBounds], point);
}

- (CGPoint)rotatePoint:(CGPoint)point toOrientation:(ScreenCaptureOrientation)alternateOrientation {
    if (self.orientation == alternateOrientation) {
        return point;
    }
    CGSize nativeSize = [ScreenCaptureLuaBridge nativeSize];
    if (self.orientation == ScreenCaptureOrientationHomeOnBottom) {
        if (alternateOrientation == ScreenCaptureOrientationHomeOnLeft) {
            return CGPointMake(nativeSize.height - point.y, point.x);
        }
        if (alternateOrientation == ScreenCaptureOrientationHomeOnTop) {
            return CGPointMake(nativeSize.width - point.x, nativeSize.height - point.y);
        }
        if (alternateOrientation == ScreenCaptureOrientationHomeOnRight) {
            return CGPointMake(point.y, nativeSize.width - point.x);
        }
    }
    if (self.orientation == ScreenCaptureOrientationHomeOnTop) {
        if (alternateOrientation == ScreenCaptureOrientationHomeOnRight) {
            return CGPointMake(nativeSize.height - point.y, point.x);
        }
        if (alternateOrientation == ScreenCaptureOrientationHomeOnBottom) {
            return CGPointMake(nativeSize.width - point.x, nativeSize.height - point.y);
        }
        if (alternateOrientation == ScreenCaptureOrientationHomeOnLeft) {
            return CGPointMake(point.y, nativeSize.width - point.x);
        }
    }
    if (self.orientation == ScreenCaptureOrientationHomeOnRight) {
        if (alternateOrientation == ScreenCaptureOrientationHomeOnBottom) {
            return CGPointMake(nativeSize.width - point.y, point.x);
        }
        if (alternateOrientation == ScreenCaptureOrientationHomeOnLeft) {
            return CGPointMake(nativeSize.width - point.x, nativeSize.height - point.y);
        }
        if (alternateOrientation == ScreenCaptureOrientationHomeOnTop) {
            return CGPointMake(point.y, nativeSize.height - point.x);
        }
    }
    if (self.orientation == ScreenCaptureOrientationHomeOnLeft) {
        if (alternateOrientation == ScreenCaptureOrientationHomeOnTop) {
            return CGPointMake(nativeSize.width - point.y, point.x);
        }
        if (alternateOrientation == ScreenCaptureOrientationHomeOnRight) {
            return CGPointMake(nativeSize.width - point.x, nativeSize.height - point.y);
        }
        if (alternateOrientation == ScreenCaptureOrientationHomeOnBottom) {
            return CGPointMake(point.y, nativeSize.height - point.x);
        }
    }
    return CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
}

@end


#pragma mark -

#define SCERR_INVALID_ORIENTATION \
    "Invalid orientation %I, available values are:" "\n" \
    "  * Home on bottom = 0" "\n" \
    "  * Home on right = 1" "\n" \
    "  * Home on left = 2" "\n" \
    "  * Home on top = 3"

/**
   Setup standalone coordinate system for this module.
 */
static int ScreenCapture_Init(lua_State *L)
{
    /// Argument #1
    lua_Integer newOrientation = luaL_checkinteger(L, 1);
    
    /// Check argument #1
    if (newOrientation < 0 || newOrientation > 3) {
        return luaL_error(L, SCERR_INVALID_ORIENTATION, newOrientation);
    }
    
    NSUInteger originalOrientation = [[ScreenCaptureLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    [[ScreenCaptureLuaBridge sharedBridge] setOrientation:(ScreenCaptureOrientation)newOrientation];
    
    /// Set to global
    lua_pushinteger(L, newOrientation);
    lua_setglobal(L, "ORIENTATION");
    
    lua_pushinteger(L, originalOrientation);
    return 1;
}

static int ScreenCapture_Init_HomeOnBottom(lua_State *L)
{
    NSUInteger originalOrientation = [[ScreenCaptureLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    lua_Integer newOrientation = ScreenCaptureOrientationHomeOnBottom;
    [[ScreenCaptureLuaBridge sharedBridge] setOrientation:(ScreenCaptureOrientation)newOrientation];
    
    /// Set to global
    lua_pushinteger(L, newOrientation);
    lua_setglobal(L, "ORIENTATION");
    
    lua_pushinteger(L, originalOrientation);
    return 1;
}

static int ScreenCapture_Init_HomeOnRight(lua_State *L)
{
    NSUInteger originalOrientation = [[ScreenCaptureLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    lua_Integer newOrientation = ScreenCaptureOrientationHomeOnRight;
    [[ScreenCaptureLuaBridge sharedBridge] setOrientation:(ScreenCaptureOrientation)newOrientation];
    
    /// Set to global
    lua_pushinteger(L, newOrientation);
    lua_setglobal(L, "ORIENTATION");
    
    lua_pushinteger(L, originalOrientation);
    return 1;
}

static int ScreenCapture_Init_HomeOnLeft(lua_State *L)
{
    NSUInteger originalOrientation = [[ScreenCaptureLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    lua_Integer newOrientation = ScreenCaptureOrientationHomeOnLeft;
    [[ScreenCaptureLuaBridge sharedBridge] setOrientation:(ScreenCaptureOrientation)newOrientation];
    
    /// Set to global
    lua_pushinteger(L, newOrientation);
    lua_setglobal(L, "ORIENTATION");
    
    lua_pushinteger(L, originalOrientation);
    return 1;
}

static int ScreenCapture_Init_HomeOnTop(lua_State *L)
{
    NSUInteger originalOrientation = [[ScreenCaptureLuaBridge sharedBridge] orientation];
    
    /// Set orientation value to shared bridge
    lua_Integer newOrientation = ScreenCaptureOrientationHomeOnTop;
    [[ScreenCaptureLuaBridge sharedBridge] setOrientation:(ScreenCaptureOrientation)newOrientation];
    
    /// Set to global
    lua_pushinteger(L, newOrientation);
    lua_setglobal(L, "ORIENTATION");
    
    lua_pushinteger(L, originalOrientation);
    return 1;
}

static int ScreenCapture_Orientation(lua_State *L)
{
    /// Get orientation value from shared bridge
    lua_pushinteger(L, (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientation]);
    
    return 1;
}

static int ScreenCapture_Keep(lua_State *L)
{
    [[ScreenCapture sharedCapture] updateDisplay];
    [[ScreenCaptureLuaBridge sharedBridge] setShouldKeepScreen:YES];
    
    lua_pushinteger(L, [[ScreenCapture sharedCapture] seed]);
    return 1;
}

static int ScreenCapture_Unkeep(lua_State *L)
{
    [[ScreenCaptureLuaBridge sharedBridge] setShouldKeepScreen:NO];
    
    lua_pushinteger(L, [[ScreenCapture sharedCapture] seed]);
    return 1;
}


#pragma mark -

#define SCERR_COORDINATE_OUT_OF_RANGE \
    "Coordinate (%I, %I) exceeds coordinate space (%I, %I)"

#define SCERR_COORDINATE_IDX_OUT_OF_RANGE \
    "Coordinate #%I (%I, %I) exceeds coordinate space (%I, %I)"

#define SCERR_REGION_INVALID \
    "Invalid region left %I top %I right %I bottom %I"

#define SCERR_EMPTY_MATCHING_REQ \
    "Empty matching request"

#define SCERR_EXPECT_IMAGE_BUFFER \
    "image_buffer expected"

#define SCERR_DESTROYED_IMAGE_BUFFER \
    "image_buffer destroyed"

#define SCERR_EXPECT_IMAGE_OBJECT \
    "Failed fetching image, expected in order of image_buffer, valid image data or path"

/**
   Get native size of internal device screen.
 */
static int ScreenCapture_Size(lua_State *L)
{
    CGSize nativeSize = [ScreenCaptureLuaBridge nativeSize];
    
    lua_pushinteger(L, (lua_Integer)nativeSize.width);
    lua_pushinteger(L, (lua_Integer)nativeSize.height);
    
    return 2;
}

/**
   Apply rotate transform from existing point to another coordinate system.
 */
static int ScreenCapture_RotateXY(lua_State *L)
{
    /// Argument #1, #2: point (x, y) to apply rotation
    lua_Integer lCoordX = (lua_Integer)luaL_checknumber(L, 1);
    lua_Integer lCoordY = (lua_Integer)luaL_checknumber(L, 2);
    
    /// Convert to CGPoint
    CGPoint cPoint = CGPointMake(lCoordX, lCoordY);
    
    /// Check argument #1, #2
    if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:cPoint]) {
        CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
        return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, lCoordX, lCoordY, (int)tSize.width, (int)tSize.height);
    }
    
    /// Argument #3: targer orientation
    lua_Integer lOrientation = luaL_checkinteger(L, 3);
    
    /// Check argument #3
    if (lOrientation < 0 || lOrientation > 3) {
        return luaL_error(L, SCERR_INVALID_ORIENTATION, lOrientation);
    }
    
    /// Rotated point
    CGPoint rotatedPoint = [[ScreenCaptureLuaBridge sharedBridge] rotatePoint:cPoint toOrientation:(ScreenCaptureOrientation)lOrientation];
    
    lua_pushinteger(L, (lua_Integer)rotatedPoint.x);
    lua_pushinteger(L, (lua_Integer)rotatedPoint.y);
    
    return 2;
}

static int ScreenCapture_GetColor_Internal(lua_State *L, int begin, JSTPixelImage *inputImage, BOOL withAlpha)
{
    @autoreleasepool {
        /// Argument #1, #2: point (x, y) to get color
        lua_Integer lCoordX = (lua_Integer)luaL_checknumber(L, begin + 1);
        lua_Integer lCoordY = (lua_Integer)luaL_checknumber(L, begin + 2);
        
        /// Convert to CGPoint
        CGPoint cPoint = CGPointMake(lCoordX, lCoordY);
        
        /// Check argument #1, #2
        if (inputImage) {
            if (![inputImage containsOrientedPoint:cPoint]) {
                CGSize tSize = [inputImage orientedSize];
                return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, lCoordX, lCoordY, (int)tSize.width, (int)tSize.height);
            }
        } else {
            if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:cPoint]) {
                CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, lCoordX, lCoordY, (int)tSize.width, (int)tSize.height);
            }
        }
        
        /// Update display if needed
        if (!inputImage) {
            if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
                [[ScreenCapture sharedCapture] updateDisplay];
            }
        }
        
        /// Get color from cached pixel image
        JSTPixelImage *targetImage = inputImage ?: [[ScreenCapture sharedCapture] pixelImage];
        uint32_t color = [targetImage getColorOfPoint:cPoint];
        
        if (!withAlpha)
        {
            lua_pushinteger(L, color & 0xFFFFFF);
            return 1;
        }
        else
        {
            lua_pushinteger(L, color & 0xFFFFFF);
            lua_pushinteger(L, (color & 0xFF000000) >> 24);
            return 2;
        }
    }
}

static int ScreenCapture_GetColor(lua_State *L)
{
    return ScreenCapture_GetColor_Internal(L, 0, nil, NO);
}

static int ScreenCapture_GetColorRGB_Internal(lua_State *L, int begin, JSTPixelImage *inputImage)
{
    @autoreleasepool {
        /// Argument #1, #2: point (x, y) to get color
        lua_Integer lCoordX = (lua_Integer)luaL_checknumber(L, begin + 1);
        lua_Integer lCoordY = (lua_Integer)luaL_checknumber(L, begin + 2);
        
        /// Convert to CGPoint
        CGPoint cPoint = CGPointMake(lCoordX, lCoordY);
        
        /// Check argument #1, #2
        if (inputImage) {
            if (![inputImage containsOrientedPoint:cPoint]) {
                CGSize tSize = [inputImage orientedSize];
                return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, lCoordX, lCoordY, (int)tSize.width, (int)tSize.height);
            }
        } else {
            if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:cPoint]) {
                CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, lCoordX, lCoordY, (int)tSize.width, (int)tSize.height);
            }
        }
        
        /// Update display if needed
        if (!inputImage) {
            if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
                [[ScreenCapture sharedCapture] updateDisplay];
            }
        }
        
        /// Get color from cached pixel image
        JSTPixelImage *targetImage = inputImage ?: [[ScreenCapture sharedCapture] pixelImage];
        JST_COLOR color;
        color.theColor = [targetImage getColorOfPoint:cPoint];
        
        lua_pushinteger(L, color.red);
        lua_pushinteger(L, color.green);
        lua_pushinteger(L, color.blue);
        return 3;
    }
}

static int ScreenCapture_GetColorRGB(lua_State *L)
{
    return ScreenCapture_GetColorRGB_Internal(L, 0, nil);
}

NS_INLINE int JSTComputeColorSimilarity(uint32_t color1, uint32_t color2)
{
    uint8_t r1 = (color1 & 0xFF0000) >> 16;
    uint8_t r2 = (color2 & 0xFF0000) >> 16;
    
    uint8_t g1 = (color1 & 0xFF00) >> 8;
    uint8_t g2 = (color2 & 0xFF00) >> 8;
    
    uint8_t b1 = (color1 & 0xFF);
    uint8_t b2 = (color2 & 0xFF);
    
    return 100 - (int)(30.0 / 0xFF * abs(r1 - r2) + 40.0 / 0xFF * abs(g1 - g2) + 30.0 / 0xFF * abs(b1 - b2));
}

NS_INLINE uint32_t JSTComputeColorOffsetAbsolute(uint32_t color1, uint32_t color2)
{
    uint32_t off = 0;
    
    uint8_t r1 = (color1 & 0xFF0000) >> 16;
    uint8_t r2 = (color2 & 0xFF0000) >> 16;
    off |= ((r1 > r2 ? r1 - r2 : r2 - r1) << 16) & 0xFF0000;
    
    uint8_t g1 = (color1 & 0xFF00) >> 8;
    uint8_t g2 = (color2 & 0xFF00) >> 8;
    off |= ((g1 > g2 ? g1 - g2 : g2 - g1) << 8) & 0xFF00;
    
    uint8_t b1 = (color1 & 0xFF);
    uint8_t b2 = (color2 & 0xFF);
    off |= (b1 > b2 ? b1 - b2 : b2 - b1) & 0xFF;
    
    return off;
}

NS_INLINE int JSTComputeColorOffsetAbsoluteInside(uint32_t haystack, uint32_t needle)
{
    uint8_t r1 = (haystack & 0xFF0000) >> 16;
    uint8_t r2 = (needle & 0xFF0000) >> 16;
    
    uint8_t g1 = (haystack & 0xFF00) >> 8;
    uint8_t g2 = (needle & 0xFF00) >> 8;
    
    uint8_t b1 = (haystack & 0xFF);
    uint8_t b2 = (needle & 0xFF);
    
    return r1 >= r2 && g1 >= g2 && b1 >= b2;
}

static int ScreenCapture_ColorSimilarity(lua_State *L)
{
    lua_Integer color1 = luaL_checkinteger(L, 1);
    lua_Integer color2 = luaL_checkinteger(L, 2);
    
    lua_pushinteger(L, JSTComputeColorSimilarity((uint32_t)color1, (uint32_t)color2));
    return 1;
}

static int ScreenCapture_ColorOffset(lua_State *L)
{
    lua_Integer color1 = luaL_checkinteger(L, 1);
    lua_Integer color2 = luaL_checkinteger(L, 2);
    
    lua_pushinteger(L, JSTComputeColorOffsetAbsolute((uint32_t)color1, (uint32_t)color2));
    return 1;
}

static int ScreenCapture_IsColors_Internal(lua_State *L, int begin, JSTPixelImage *inputImage)
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    @autoreleasepool {
        NSArray <NSArray <NSNumber *> *> *aColorsList = lua_toNSArray(L, begin + 1);
        
        lua_Integer targetSimilarity = luaL_optinteger(L, begin + 2, 100);
        if (targetSimilarity > 100) {
            targetSimilarity = 100;
        }
        if (targetSimilarity < 1) {
            return luaL_argerror(L, begin + 2, "similarity out of range [1...100]");
        }
        
        Class arrayCls = [NSArray class];
        Class numberCls = [NSNumber class];
        
        BOOL allPassed = YES;
        NSInteger errorIndex = NSNotFound;  // begin from 0
        for (NSInteger i = 0; i < aColorsList.count; i++) {
            
            NSArray <NSNumber *> *aColors = aColorsList[i];
            
            if (![aColors isKindOfClass:arrayCls]) {
                allPassed = NO;
                errorIndex = i;
                break;
            }
            
            if (aColors.count < 3) {
                allPassed = NO;
                errorIndex = i;
                break;
            }
            
            if (![aColors[0] isKindOfClass:numberCls]) {
                allPassed = NO;
                errorIndex = i;
                break;
            }
            
            if (![aColors[1] isKindOfClass:numberCls]) {
                allPassed = NO;
                errorIndex = i;
                break;
            }
            
            if (![aColors[2] isKindOfClass:numberCls]) {
                allPassed = NO;
                errorIndex = i;
                break;
            }
            
            lua_Integer lCoordX = [aColors[0] longLongValue];
            lua_Integer lCoordY = [aColors[1] longLongValue];
            
            /// Convert to CGPoint
            CGPoint cPoint = CGPointMake(lCoordX, lCoordY);
            
            /// Check CGPoint
            if (inputImage) {
                if (![inputImage containsOrientedPoint:cPoint]) {
                    CGSize tSize = [inputImage orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_IDX_OUT_OF_RANGE, i + 1, lCoordX, lCoordY, (NSUInteger)tSize.width, (NSUInteger)tSize.height);
                }
            } else {
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:cPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_IDX_OUT_OF_RANGE, i + 1, lCoordX, lCoordY, (NSUInteger)tSize.width, (NSUInteger)tSize.height);
                }
            }
        }
        
        if (!allPassed) {
            return luaL_error(L, "Tuple #%I from argument colors is not an array of at least three numbers (coordinateX, coordinateY, matching_color)", errorIndex + 1);
        }
        
        /// Update display if needed
        if (!inputImage) {
            if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
                [[ScreenCapture sharedCapture] updateDisplay];
            }
        }
        
        JSTPixelImage *targetImage = inputImage ?: [[ScreenCapture sharedCapture] pixelImage];
        BOOL allMatched = YES;
        for (NSArray <NSNumber *> *aColors in aColorsList) {
            lua_Integer lCoordX = [aColors[0] longLongValue];
            lua_Integer lCoordY = [aColors[1] longLongValue];
            uint32_t theColor = [aColors[2] unsignedIntValue];
            
            /// Convert to CGPoint
            CGPoint cPoint = CGPointMake(lCoordX, lCoordY);
            
            uint32_t color = [targetImage getColorOfPoint:cPoint];
            int colorSimilarity = JSTComputeColorSimilarity(theColor, color);
            if (colorSimilarity < targetSimilarity) {
                allMatched = NO;
                break;
            }
        }
        
        lua_pushboolean(L, allMatched);
    }
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
    
    return 1;
}

static int ScreenCapture_IsColors(lua_State *L)
{
    return ScreenCapture_IsColors_Internal(L, 0, nil);
}

static int __ScreenCapture_FindColor_Internal(lua_State *L, int begin, JSTPixelImage *inputImage, BOOL isDryRun)
{
    @autoreleasepool {
        
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        int argc = lua_gettop(L) - begin;
        
        CHDebugLogSource(@"number of arguments %d", argc);
        
        NSDictionary *matchingTable = nil;
        luaL_checktype(L, begin + 1, LUA_TTABLE);
        if (lua_table_is_array(L, begin + 1)) {
            
            NSArray *matchingList = lua_toNSArray(L, begin + 1);
            NSMutableDictionary *mFindingTable = [NSMutableDictionary dictionaryWithCapacity:matchingTable.count];
            for (NSUInteger idx = 0; idx < matchingList.count; idx++) {
                id findingObj = [matchingList objectAtIndex:idx];
                [mFindingTable setObject:findingObj forKey:@(idx + 1)];
            }
            
            matchingTable = [mFindingTable copy];
        } else {
            matchingTable = lua_toNSDictionary(L, begin + 1);
        }
        
        CHDebugLogSource(@"matching table constructed %@", matchingTable);
        
        lua_Integer defaultSimilarity = 100;
        if (argc == 2 || argc >= 6) {
            defaultSimilarity = luaL_checkinteger(L, begin + 2);
            
            if (defaultSimilarity > 100) {
                CHDebugLogSource(@"default similarity is greater than 100, use 100 instead");
                defaultSimilarity = 100;
            }
            
            if (defaultSimilarity < 1) {
                return luaL_argerror(L, begin + 2, "default similarity out of range [1...100]");
            }
        }
        
        CHDebugLogSource(@"default similarity is %lld", defaultSimilarity);
        
        lua_Integer left = 0, top = 0;
        lua_Integer right = 0, bottom = 0;
        
        if (inputImage) {
            right = (lua_Integer)[inputImage orientedSize].width;
            bottom = (lua_Integer)[inputImage orientedSize].height;
        } else {
            right = (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientedSize].width;
            bottom = (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientedSize].height;
        }
        
        if (argc > 2 && argc <= 5) {
            left = (lua_Integer)luaL_checknumber(L, begin + 2);
            top = (lua_Integer)luaL_checknumber(L, begin + 3);
            right = (lua_Integer)luaL_checknumber(L, begin + 4);
            bottom = (lua_Integer)luaL_checknumber(L, begin + 5);
        } else if (argc > 5) {
            left = (lua_Integer)luaL_checknumber(L, begin + 3);
            top = (lua_Integer)luaL_checknumber(L, begin + 4);
            right = (lua_Integer)luaL_checknumber(L, begin + 5);
            bottom = (lua_Integer)luaL_checknumber(L, begin + 6);
        }
        
        if (left < 0 || top < 0 || left >= right || top >= bottom) {
            return luaL_error(L, SCERR_REGION_INVALID, left, top, right, bottom);
        }
        
        {
            /// Convert to CGPoint
            CGPoint leftTopPoint = CGPointMake(left, top);
            
            /// Check left-top CGPoint
            if (inputImage) {
                if (![inputImage containsOrientedPoint:leftTopPoint]) {
                    CGSize tSize = [inputImage orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, left, top, (int)tSize.width, (int)tSize.height);
                }
            } else {
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:leftTopPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, left, top, (int)tSize.width, (int)tSize.height);
                }
            }
        }
        
        {
            /// Convert to CGPoint
            CGPoint rightBottomPoint = CGPointMake(right - 1, bottom - 1);
            
            /// Check right-bottom CGPoint
            if (inputImage) {
                if (![inputImage containsOrientedPoint:rightBottomPoint]) {
                    CGSize tSize = [inputImage orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)tSize.width, (int)tSize.height);
                }
            } else {
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:rightBottomPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)tSize.width, (int)tSize.height);
                }
            }
        }
        
        CHDebugLogSource(@"left %lld top %lld right %lld bottom %lld", left, top, right, bottom);
        
        BOOL optFindAll = [matchingTable[@"find_all"] isKindOfClass:[NSNumber class]] ? [matchingTable[@"find_all"] boolValue] : NO;
        
        lua_Integer optMaxResults = optFindAll ? ([matchingTable[@"max_results"] isKindOfClass:[NSNumber class]]
                                                  ? MAX([matchingTable[@"max_results"] integerValue], 1)
                                                  : 100) : 1;
        
        optMaxResults = MAX(MIN(1000, optMaxResults), 1);
        
        lua_Integer optMaxMiss = [matchingTable[@"max_miss"] isKindOfClass:[NSNumber class]] ? MAX([matchingTable[@"max_miss"] integerValue], 0) : 0;
        
        CHDebugLogSource(@"options find_all %@ max_results %lld max_miss %lld", optFindAll ? @"YES" : @"NO", optMaxResults, optMaxMiss);
        
        NSMutableDictionary *mMatchingTable = [matchingTable mutableCopy];
        
        [mMatchingTable removeObjectForKey:@"find_all"];
        [mMatchingTable removeObjectForKey:@"max_results"];
        [mMatchingTable removeObjectForKey:@"max_miss"];
        
        if (!mMatchingTable.count) {
            return luaL_error(L, SCERR_EMPTY_MATCHING_REQ);
        }
        
        Class arrayCls = [NSArray class];
        Class numberCls = [NSNumber class];
        
        NSMutableArray <NSArray <NSNumber *> *> *normalizedMatchingList = [[NSMutableArray alloc] initWithCapacity:mMatchingTable.count];
        
        NSInteger firstCoordX = NSNotFound;
        NSInteger firstCoordY = NSNotFound;
        
        @autoreleasepool {
            BOOL allPassed = YES;
            NSInteger errorIndex = NSNotFound;  // begin from 1
            NSInteger currentIndex = 1;         // begin from 1
            
            while ([mMatchingTable objectForKey:@(currentIndex)]) {
                @autoreleasepool {
                    
                    NSArray *aColors = mMatchingTable[@(currentIndex)];
                    
                    CHDebugLogSource(@"processing element #%ld of matching list %@", (long)currentIndex, aColors);
                    
                    [mMatchingTable removeObjectForKey:@(currentIndex)];
                    
                    if (![aColors isKindOfClass:arrayCls]) {
                        
                        CHDebugLogSource(@"error: element #%ld must be an array, got %@", (long)currentIndex, NSStringFromClass([aColors class]));
                        
                        allPassed = NO;
                        errorIndex = currentIndex;
                        break;
                        
                    }
                    
                    if (aColors.count < 3) {
                        
                        CHDebugLogSource(@"error: number of children of element #%ld must be greater than or equal to 3, got %ld", (long)currentIndex, aColors.count);
                        
                        allPassed = NO;
                        errorIndex = currentIndex;
                        break;
                        
                    }
                    
                    // x
                    if (![aColors[0] isKindOfClass:numberCls]) {
                        
                        CHDebugLogSource(@"error: the 1st child `x` of element #%ld must be an integer, got %@", (long)currentIndex, NSStringFromClass([aColors[0] class]));
                        
                        allPassed = NO;
                        errorIndex = currentIndex;
                        break;
                        
                    }
                    
                    // y
                    if (![aColors[1] isKindOfClass:numberCls]) {
                        
                        CHDebugLogSource(@"error: the 2nd child `y` of element #%ld must be an integer, got %@", (long)currentIndex, NSStringFromClass([aColors[1] class]));
                        
                        allPassed = NO;
                        errorIndex = currentIndex;
                        break;
                        
                    }
                    
                    // color & similarity
                    BOOL useDefaultSimilarity = NO;
                    if ([aColors[2] isKindOfClass:numberCls]) {
                        
                        CHDebugLogSource(@"the 3rd child `color` of element #%ld is an integer, will use color similarity matching pattern for this element", (long)currentIndex);
                        
                        // color
                        if (aColors.count >= 4) {
                            
                            if (currentIndex == 1) {
                                
                                // similarity [1...100]
                                if (![aColors[3] isKindOfClass:numberCls]) {
                                    
                                    CHDebugLogSource(@"the 4th child `similarity` of element #%ld must be an integer, got %@", (long)currentIndex, NSStringFromClass([aColors[3] class]));
                                    
                                    allPassed = NO;
                                    errorIndex = currentIndex;
                                    break;
                                    
                                }
                                
                                unsigned int similarity = [aColors[3] unsignedIntValue];
                                if (similarity < 1 || similarity > 100) {
                                    return luaL_error(L, "similarity out of range [1...100], in tuple #%I from argument colors", currentIndex);
                                }
                                
                                CHDebugLogSource(@"the 3rd child `color` of element #%ld is an integer, the 4th child will be treated as `similarity`, %u", (long)currentIndex, similarity);
                                
                            } else {
                                
                                // similarity [-100...100]
                                if (![aColors[3] isKindOfClass:numberCls]) {
                                    
                                    CHDebugLogSource(@"the 4th child `similarity` of element #%ld must be an integer, got %@", (long)currentIndex, NSStringFromClass([aColors[3] class]));
                                    
                                    allPassed = NO;
                                    errorIndex = currentIndex;
                                    break;
                                    
                                }
                                
                                int similarity = [aColors[3] intValue];
                                if (similarity < -100 || similarity > 100) {
                                    return luaL_error(L, "similarity out of range [-100...100], in tuple #%I from argument colors", currentIndex);
                                }
                                
                                CHDebugLogSource(@"the 3rd child `color` of element #%ld is an integer, the 4th child will be treated as `similarity`, %d", (long)currentIndex, similarity);
                            }
                        } else {
                            
                            CHDebugLogSource(@"the 4th child `similarity` of element #%ld not found, use default similarity %lld instead", (long)currentIndex, defaultSimilarity);
                            
                            useDefaultSimilarity = YES;
                        }
                    }
                    else if ([aColors[2] isKindOfClass:arrayCls]) {
                        
                        if ([aColors[2] count] != 2 || ![aColors[2][0] isKindOfClass:numberCls] || ![aColors[2][1] isKindOfClass:numberCls])
                        {
                            
                            CHDebugLogSource(@"the 3rd child `color` of element #%ld is an array, but it does not contain two numbers", (long)currentIndex);
                            
                            allPassed = NO;
                            errorIndex = currentIndex;
                            break;
                            
                        }
                        
                        CHDebugLogSource(@"the 3rd child `color` of element #%ld is an array of two numbers, will use color offset matching pattern for this element", (long)currentIndex);
                        
                    }
                    else {
                        
                        CHDebugLogSource(@"if the 3rd child `color` of element #%ld is not an integer, it must be an array, got %@", (long)currentIndex, NSStringFromClass([aColors[2] class]));
                        
                        allPassed = NO;
                        errorIndex = currentIndex;
                        break;
                        
                    }
                    
                    NSMutableArray <NSNumber *> *mColors = [aColors mutableCopy];
                    
                    lua_Integer lCoordX = [aColors[0] longLongValue];
                    lua_Integer lCoordY = [aColors[1] longLongValue];
                    
                    if (firstCoordX == NSNotFound || firstCoordY == NSNotFound) {
                        
                        CHDebugLogSource(@"base coordinate is (%lld, %lld)", lCoordX, lCoordY);
                        
                        firstCoordX = lCoordX;
                        firstCoordY = lCoordY;
                        
                    } else {
                        CHDebugLogSource(@"offset coordinate is (%lld, %lld)", lCoordX - firstCoordX, lCoordY - firstCoordY);
                    }
                    
                    mColors[0] = [NSNumber numberWithLongLong:lCoordX - firstCoordX];
                    mColors[1] = [NSNumber numberWithLongLong:lCoordY - firstCoordY];
                    
                    if (useDefaultSimilarity && mColors.count == 3) {
                        [mColors addObject:@(defaultSimilarity)];
                    }
                    
                    CHDebugLogSource(@"normalized element #%ld %@", (long)currentIndex, mColors);
                    
                    [normalizedMatchingList addObject:[mColors copy]];
                    
                    currentIndex += 1;
                    
                }  // end autoreleasepool
            }
            
            if (!allPassed) {
                return luaL_error(L, "Tuple #%I from argument colors is not an array of at least three numbers (coordinateX, coordinateY, matching_color[, similarity])", errorIndex);
            }
        }
        
        if (mMatchingTable.count != 0) {
            return luaL_error(L, "Argument colors has unexpected option %s", [[[[mMatchingTable keyEnumerator] nextObject] description] UTF8String]);
        }
        
        mMatchingTable[@"find_all"] = @(optFindAll);
        mMatchingTable[@"max_results"] = @(optMaxResults);
        mMatchingTable[@"max_miss"] = @(optMaxMiss);
        
        for (NSInteger idx = 0; idx < normalizedMatchingList.count; idx++) {
            mMatchingTable[@(idx + 1)] = normalizedMatchingList[idx];
        }
        
#if DEBUG
        __uint64_t normalizedAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double normalizeUsed = (normalizedAt - beginAt) / 1e6;
        CHDebugLogSource(@"matching table successfully normalized %@, time elapsed %.2fms", mMatchingTable, normalizeUsed);
#endif
        
        if (isDryRun) {
            int pushedCount = 1;
            lua_pushNSDictionary(L, [mMatchingTable copy]);
            
            if (argc == 2 || argc >= 6) {
                lua_pushinteger(L, defaultSimilarity);
                pushedCount += 1;
            }
            
            if (argc >= 5) {
                lua_pushinteger(L, left);
                lua_pushinteger(L, top);
                lua_pushinteger(L, right);
                lua_pushinteger(L, bottom);
                
                pushedCount += 4;
            }
            
            return pushedCount;
        }
        
        /// Update display if needed
        if (!inputImage) {
            if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
                [[ScreenCapture sharedCapture] updateDisplay];
                
                CHDebugLogSource(@"screen display updated");
            } else {
                CHDebugLogSource(@"screen display kept");
            }
        }
        
        JSTPixelImage *targetImage = inputImage ?: [[ScreenCapture sharedCapture] pixelImage];
        JST_IMAGE *rawImage = [targetImage internalPointer];
        
        NSMutableArray <NSArray <NSNumber *> *> *runMatchedResults = [[NSMutableArray alloc] initWithCapacity:optMaxResults];
        
        NSUInteger runElementCount = normalizedMatchingList.count;
        NSArray *runElement = nil;
        NSArray *runNestedElement = nil;
        
        for (int runX = (int)left; runX < right; runX++) {
            for (int runY = (int)top; runY < bottom; runY++) {
                
                int loopMissedCount = 0;
                BOOL runElementMatched = YES;
                
                for (NSUInteger runElementIndex = 0; runElementIndex < runElementCount; runElementIndex++) {
                    
                    if (loopMissedCount > optMaxMiss) {
                        runElementMatched = NO;
                        break;
                    }
                    
                    runElement = normalizedMatchingList[runElementIndex];
                    
                    int imageCoordX = runX + [runElement[0] intValue];
                    int imageCoordY = runY + [runElement[1] intValue];
                    
                    if (imageCoordX < 0 || imageCoordY < 0 || imageCoordX >= rawImage->width || imageCoordY >= rawImage->height) {
                        loopMissedCount += 1;
                        continue;
                    }
                    
                    JST_COLOR runColor;
                    JSTGetColorInPixelImageSafe(rawImage, imageCoordX, imageCoordY, &runColor);
                    
                    if (![runElement[2] isKindOfClass:arrayCls] /* isSimilarityMatchingPattern */) {
                        
                        uint32_t runElementColor = [runElement[2] unsignedIntValue];
                        int runElementSimilarity = [runElement[3] intValue];
                        
                        if ((runColor.theColor & 0xFFFFFF) != (runElementColor & 0xFFFFFF)) {
                            int runSimilarity = JSTComputeColorSimilarity(runColor.theColor, runElementColor);
                            if (runElementIndex == 0) {
                                if (runSimilarity < runElementSimilarity) {
                                    runElementMatched = NO;
                                    break;
                                }
                            } else {
                                if (runElementSimilarity > 0) {
                                    if (runSimilarity < runElementSimilarity) {
                                        loopMissedCount += 1;
                                        continue;
                                    }
                                } else {
                                    if (runSimilarity > -runElementSimilarity) {
                                        loopMissedCount += 1;
                                        continue;
                                    }
                                }
                            }
                        }
                        
                    } else {
                        
                        runNestedElement = runElement[2];
                        
                        uint32_t runElementColor = [runNestedElement[0] unsignedIntValue];
                        uint32_t runElementColorOffset = [runNestedElement[1] unsignedIntValue];
                        
                        if ((runColor.theColor & 0xFFFFFF) != (runElementColor & 0xFFFFFF)) {
                            uint32_t runOffset = JSTComputeColorOffsetAbsolute(runColor.theColor, runElementColor);
                            if (runElementIndex == 0) {
                                if (!JSTComputeColorOffsetAbsoluteInside(runElementColorOffset, runOffset)) {
                                    runElementMatched = NO;
                                    break;
                                }
                            } else {
                                if (runElementColorOffset <= 0xFF000000) {
                                    if (!JSTComputeColorOffsetAbsoluteInside(runElementColorOffset, runOffset)) {
                                        loopMissedCount += 1;
                                        continue;
                                    }
                                } else {
                                    if (JSTComputeColorOffsetAbsoluteInside(runElementColorOffset, runOffset)) {
                                        loopMissedCount += 1;
                                        continue;
                                    }
                                }
                            }
                        }
                        
                    }
                }
                
                if (!runElementMatched) {
                    continue;
                }
                
                [runMatchedResults addObject:@[@(runX), @(runY)]];
                
                if (!optFindAll) {
                    goto endMatching;
                }
                
                if (runMatchedResults.count > optMaxResults) {
                    goto endMatching;
                }
                
            }
        }
        
endMatching:
        
        runElement = nil;
        runNestedElement = nil;
        
        if (!optFindAll) {
            
            if (!runMatchedResults.count) {
                lua_pushinteger(L, -1);
                lua_pushinteger(L, -1);
                
#if DEBUG
                __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
                double used = (endAt - beginAt) / 1e6;
                CHDebugLogSource(@"no matches found, time elapsed %.2fms", used);
#endif
                
                return 2;
            }
            
            lua_pushinteger(L, [runMatchedResults[0][0] intValue]);
            lua_pushinteger(L, [runMatchedResults[0][1] intValue]);
            
#if DEBUG
            __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
            double used = (endAt - beginAt) / 1e6;
            CHDebugLogSource(@"single coordinate matched (%@, %@), time elapsed %.2fms", runMatchedResults[0][0], runMatchedResults[0][1], used);
#endif
            
            return 2;
        }
        
        lua_pushNSArray(L, [runMatchedResults copy]);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"multiple coordinates matched %@, time elapsed %.2fms", runMatchedResults, used);
#endif
        
        return 1;
        
    }
}

static int ScreenCapture_FindColor_Normalize(lua_State *L)
{
    return __ScreenCapture_FindColor_Internal(L, 0, nil, YES);
}

static int ScreenCapture_FindColor(lua_State *L)
{
    return __ScreenCapture_FindColor_Internal(L, 0, nil, NO);
}

static int ScreenCapture_OcrText_Internal(lua_State *L, int begin, JSTPixelImage *inputImage)
{
    @autoreleasepool {
        
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        lua_Integer left, top, right, bottom;
        lua_Integer level;
        lua_Number remoteTimeout;
        
        int argc = lua_gettop(L) - begin;
        if (argc <= 2) {
            left = 0;
            top = 0;
            if (inputImage) {
                right = (lua_Integer)[inputImage orientedSize].width;
                bottom = (lua_Integer)[inputImage orientedSize].height;
            } else {
                right = (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientedSize].width;
                bottom = (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientedSize].height;
            }
            level = luaL_optinteger(L, begin + 1, 0);
            remoteTimeout = luaL_optnumber(L, begin + 2, 3000);
        } else {
            left = (lua_Integer)luaL_checknumber(L, begin + 1);
            top = (lua_Integer)luaL_checknumber(L, begin + 2);
            right = (lua_Integer)luaL_checknumber(L, begin + 3);
            bottom = (lua_Integer)luaL_checknumber(L, begin + 4);
            level = luaL_optinteger(L, begin + 5, 0);
            remoteTimeout = luaL_optnumber(L, begin + 6, 3000);
        }
        
        remoteTimeout /= 1e3;
        
        if (left < 0 || top < 0 || left >= right || top >= bottom) {
            return luaL_error(L, SCERR_REGION_INVALID, left, top, right, bottom);
        }
        
        {
            /// Convert to CGPoint
            CGPoint leftTopPoint = CGPointMake(left, top);
            
            /// Check left-top CGPoint
            if (inputImage) {
                if (![inputImage containsOrientedPoint:leftTopPoint]) {
                    CGSize tSize = [inputImage orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, left, top, (int)tSize.width, (int)tSize.height);
                }
            } else {
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:leftTopPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, left, top, (int)tSize.width, (int)tSize.height);
                }
            }
        }
        
        {
            /// Convert to CGPoint
            CGPoint rightBottomPoint = CGPointMake(right - 1, bottom - 1);
            
            /// Check right-bottom CGPoint
            if (inputImage) {
                if (![inputImage containsOrientedPoint:rightBottomPoint]) {
                    CGSize tSize = [inputImage orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)tSize.width, (int)tSize.height);
                }
            } else {
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:rightBottomPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)tSize.width, (int)tSize.height);
                }
            }
        }
        
        CHDebugLogSource(@"left %lld top %lld right %lld bottom %lld", left, top, right, bottom);
        
        /// Update display if needed
        if (!inputImage) {
            if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
                [[ScreenCapture sharedCapture] updateDisplayWithoutTransfer];
                
                CHDebugLogSource(@"screen display updated");
            } else {
                CHDebugLogSource(@"screen display kept");
            }
        }
        
        NSInteger localOrientation;
        if (inputImage) {
            localOrientation = [inputImage orientation];
        } else {
            localOrientation = [[ScreenCaptureLuaBridge sharedBridge] orientation];
        }
        
        CGRect cropRegion = CGRectMake(left, top, right - left, bottom - top);
        VNRequestTextRecognitionLevel recognitionLevel = level == 0 ? VNRequestTextRecognitionLevelAccurate : VNRequestTextRecognitionLevelFast;
        NSDictionary *remoteProxyResult;
        if (inputImage) {
            remoteProxyResult = [[ScreenCapture sharedCapture] performRecognizeTextRequestWithData:[inputImage pngRepresentation]
                                                                                  recognitionLevel:recognitionLevel
                                                                                           timeout:remoteTimeout];
        } else {
            remoteProxyResult = [[ScreenCapture sharedCapture] performRecognizeTextRequestInRect:cropRegion
                                                                                   toOrientation:localOrientation
                                                                                recognitionLevel:recognitionLevel
                                                                                         timeout:remoteTimeout];
        }
        
        /// Check if it timed out
        if ([remoteProxyResult[@"status"] intValue] != 0) {
            lua_pushnil(L);
            lua_pushstring(L, "vision proxy timed out");
            return 2;
        }
        
        /// Check if it succeed
        if (![remoteProxyResult[@"succeed"] boolValue]) {
            lua_pushnil(L);
            if (remoteProxyResult[@"error"]) {
                lua_pushstring(L, [remoteProxyResult[@"error"] UTF8String]);
            } else {
                lua_pushnil(L);
            }
            return 2;
        }
        
        if (remoteProxyResult[@"texts"]) {
            lua_pushNSArray(L, remoteProxyResult[@"texts"]);
        } else {
            lua_pushnil(L);
        }
        
        if (remoteProxyResult[@"details"]) {
            lua_pushNSArray(L, remoteProxyResult[@"details"]);
        } else {
            lua_pushnil(L);
        }
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 2;
    }
}

static int ScreenCapture_OcrText(lua_State *L)
{
    return ScreenCapture_OcrText_Internal(L, 0, nil);
}

static int ScreenCapture_DetectBarcodes_Internal(lua_State *L, int begin, JSTPixelImage *inputImage, BOOL firstResultOnly)
{
    @autoreleasepool {
        
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        lua_Integer left, top, right, bottom;
        lua_Number remoteTimeout;
        
        int argc = lua_gettop(L) - begin;
        if (argc <= 1) {
            left = 0;
            top = 0;
            if (inputImage) {
                right = (lua_Integer)[inputImage orientedSize].width;
                bottom = (lua_Integer)[inputImage orientedSize].height;
            } else {
                right = (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientedSize].width;
                bottom = (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientedSize].height;
            }
            remoteTimeout = luaL_optnumber(L, begin + 1, 3000);
        } else {
            left = (lua_Integer)luaL_checknumber(L, begin + 1);
            top = (lua_Integer)luaL_checknumber(L, begin + 2);
            right = (lua_Integer)luaL_checknumber(L, begin + 3);
            bottom = (lua_Integer)luaL_checknumber(L, begin + 4);
            remoteTimeout = luaL_optnumber(L, begin + 5, 3000);
        }
        
        remoteTimeout /= 1e3;
        
        if (left < 0 || top < 0 || left >= right || top >= bottom) {
            return luaL_error(L, SCERR_REGION_INVALID, left, top, right, bottom);
        }
        
        {
            /// Convert to CGPoint
            CGPoint leftTopPoint = CGPointMake(left, top);
            
            /// Check left-top CGPoint
            if (inputImage) {
                if (![inputImage containsOrientedPoint:leftTopPoint]) {
                    CGSize tSize = [inputImage orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, left, top, (int)tSize.width, (int)tSize.height);
                }
            } else {
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:leftTopPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, left, top, (int)tSize.width, (int)tSize.height);
                }
            }
        }
        
        {
            /// Convert to CGPoint
            CGPoint rightBottomPoint = CGPointMake(right - 1, bottom - 1);
            
            /// Check right-bottom CGPoint
            if (inputImage) {
                if (![inputImage containsOrientedPoint:rightBottomPoint]) {
                    CGSize tSize = [inputImage orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)tSize.width, (int)tSize.height);
                }
            } else {
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:rightBottomPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)tSize.width, (int)tSize.height);
                }
            }
        }
        
        CHDebugLogSource(@"left %lld top %lld right %lld bottom %lld", left, top, right, bottom);
        
        /// Update display if needed
        if (!inputImage) {
            if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
                [[ScreenCapture sharedCapture] updateDisplayWithoutTransfer];
                
                CHDebugLogSource(@"screen display updated");
            } else {
                CHDebugLogSource(@"screen display kept");
            }
        }
        
        NSInteger localOrientation;
        if (inputImage) {
            localOrientation = [inputImage orientation];
        } else {
            localOrientation = [[ScreenCaptureLuaBridge sharedBridge] orientation];
        }
        
        CGRect cropRegion = CGRectMake(left, top, right - left, bottom - top);
        NSDictionary *remoteProxyResult;
        if (inputImage) {
            remoteProxyResult = [[ScreenCapture sharedCapture] performDetectBarcodesRequestWithData:[inputImage pngRepresentation]
                                                                                            timeout:remoteTimeout];
        } else {
            remoteProxyResult = [[ScreenCapture sharedCapture] performDetectBarcodesRequestInRect:cropRegion
                                                                                    toOrientation:localOrientation
                                                                                          timeout:remoteTimeout];
        }
        
        /// Check if it timed out
        if ([remoteProxyResult[@"status"] intValue] != 0) {
            lua_pushnil(L);
            lua_pushstring(L, "vision proxy timed out");
            return 2;
        }
        
        /// Check if it succeed
        if (![remoteProxyResult[@"succeed"] boolValue]) {
            lua_pushnil(L);
            if (remoteProxyResult[@"error"]) {
                lua_pushstring(L, [remoteProxyResult[@"error"] UTF8String]);
            } else {
                lua_pushnil(L);
            }
            return 2;
        }
        
        if (firstResultOnly)
        {
            if (remoteProxyResult[@"texts"] && [[remoteProxyResult[@"texts"] firstObject] isKindOfClass:[NSString class]]) {
                lua_pushstring(L, [[remoteProxyResult[@"texts"] firstObject] UTF8String]);
            } else {
                lua_pushnil(L);
            }
            
            if (remoteProxyResult[@"details"] && [[remoteProxyResult[@"details"] firstObject] isKindOfClass:[NSDictionary class]]) {
                lua_pushNSDictionary(L, [remoteProxyResult[@"details"] firstObject]);
            } else {
                lua_pushnil(L);
            }
        }
        else
        {
            if (remoteProxyResult[@"texts"]) {
                lua_pushNSArray(L, remoteProxyResult[@"texts"]);
            } else {
                lua_pushnil(L);
            }
            
            if (remoteProxyResult[@"details"]) {
                lua_pushNSArray(L, remoteProxyResult[@"details"]);
            } else {
                lua_pushnil(L);
            }
        }
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 2;
    }
}

static int ScreenCapture_DetectBarcodes(lua_State *L)
{
    return ScreenCapture_DetectBarcodes_Internal(L, 0, nil, NO);
}

#pragma mark -

#define L_TYPE_IMAGE_BUFFER "image_buffer"

static NSMutableDictionary <NSNumber *, JSTPixelImage *> *__globalImageObjects = nil;
static int __globalImageAutoIncrementID = 0;
static pthread_mutex_t __globalImageObjectsLock;

typedef struct ImageBuffer {
    int imageID;
    __weak JSTPixelImage *image;
} ImageBuffer;

NS_INLINE ImageBuffer *toImageBuffer(lua_State *L, int index)
{
    ImageBuffer *buf = (ImageBuffer *)lua_touserdata(L, index);
    if (buf == NULL)
        luaL_argerror(L, index, SCERR_EXPECT_IMAGE_BUFFER);
    return buf;
}

NS_INLINE BOOL isImageBuffer(lua_State *L, int index)
{
    if (lua_type(L, index) != LUA_TUSERDATA)
        return NO;
    return NULL != luaL_testudata(L, index, L_TYPE_IMAGE_BUFFER);
}

NS_INLINE ImageBuffer *checkImageBuffer(lua_State *L, int index)
{
    ImageBuffer *buf;
    luaL_checktype(L, index, LUA_TUSERDATA);
    buf = (ImageBuffer *)luaL_checkudata(L, index, L_TYPE_IMAGE_BUFFER);
    if (buf == NULL)
        luaL_argerror(L, index, SCERR_EXPECT_IMAGE_BUFFER);
    return buf;
}

NS_INLINE ImageBuffer *pushImageBuffer(lua_State *L)
{
    ImageBuffer *buf = (ImageBuffer *)lua_newuserdata(L, sizeof(ImageBuffer));
    luaL_getmetatable(L, L_TYPE_IMAGE_BUFFER);
    lua_setmetatable(L, -2);
    return buf;
}

static int ScreenCapture_Image(lua_State *L)
{
    @autoreleasepool {
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        JSTPixelImage *cropImage = nil;
        if (lua_gettop(L) > 0) {
            lua_Integer left, top, right, bottom;
            
            left = (lua_Integer)luaL_checknumber(L, 1);
            top = (lua_Integer)luaL_checknumber(L, 2);
            right = (lua_Integer)luaL_checknumber(L, 3);
            bottom = (lua_Integer)luaL_checknumber(L, 4);
            
            if (left < 0 || top < 0 || left >= right || top >= bottom) {
                return luaL_error(L, SCERR_REGION_INVALID, left, top, right, bottom);
            }
            
            {
                /// Convert to CGPoint
                CGPoint leftTopPoint = CGPointMake(left, top);
                
                /// Check left-top CGPoint
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:leftTopPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, left, top, (int)tSize.width, (int)tSize.height);
                }
            }
            
            {
                /// Convert to CGPoint
                CGPoint rightBottomPoint = CGPointMake(right - 1, bottom - 1);
                
                /// Check right-bottom CGPoint
                if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:rightBottomPoint]) {
                    CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                    return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)tSize.width, (int)tSize.height);
                }
            }
            
            CHDebugLogSource(@"left %lld top %lld right %lld bottom %lld", left, top, right, bottom);
            
            /// Update display if needed
            if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
                [[ScreenCapture sharedCapture] updateDisplay];
                
                CHDebugLogSource(@"screen display updated");
            } else {
                CHDebugLogSource(@"screen display kept");
            }
            
            CGRect cropRegion = CGRectMake(left, top, right - left, bottom - top);
            cropImage = [[[ScreenCapture sharedCapture] pixelImage] crop:cropRegion];
        } else {
            
            /// Update display if needed
            if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
                [[ScreenCapture sharedCapture] updateDisplay];
                
                CHDebugLogSource(@"screen display updated");
            } else {
                CHDebugLogSource(@"screen display kept");
            }
            
            cropImage = [[[ScreenCapture sharedCapture] pixelImage] copy];
        }
        
        /// Construct image buffer
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *buf = pushImageBuffer(L);
        buf->imageID = ++__globalImageAutoIncrementID;
        buf->image = cropImage;
        __globalImageObjects[@(buf->imageID)] = cropImage;
        pthread_mutex_unlock(&__globalImageObjectsLock);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
    }
}

static int ScreenCapture_FindImage(lua_State *L)
{
    @autoreleasepool {
        
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        int argc = lua_gettop(L);
        
        JSTPixelImage *needleImage = nil;
        if (lua_type(L, 1) == LUA_TUSERDATA) {
            ImageBuffer *buf = checkImageBuffer(L, 1);
            if (!buf->image) {
                return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
            }
            needleImage = buf->image;
        } else if (lua_type(L, 1) == LUA_TSTRING) {
            size_t cDataLen;
            const char *cData = luaL_checklstring(L, 1, &cDataLen);
            NSData *data = [NSData dataWithBytes:cData length:cDataLen];
            UIImage *systemImage = [UIImage imageWithData:data];
            if (!systemImage) {
                NSString *path = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (path) {
                    systemImage = [[UIImage alloc] initWithContentsOfFile:path];
                }
            }
            if (!systemImage) {
                return luaL_argerror(L, 1, SCERR_EXPECT_IMAGE_OBJECT);
            }
            needleImage = [JSTPixelImage imageWithSystemImage:systemImage];
        } else {
            return luaL_argerror(L, 1, SCERR_EXPECT_IMAGE_OBJECT);
        }
        
        lua_Integer targetSimilarity = luaL_optinteger(L, 2, 95);
        if (targetSimilarity > 100) {
            targetSimilarity = 100;
        }
        if (targetSimilarity < 1) {
            return luaL_argerror(L, 2, "similarity out of range [1...100]");
        }
        
        lua_Integer left, top, right, bottom;
        if (argc > 2) {
            left = (lua_Integer)luaL_checknumber(L, 3);
            top = (lua_Integer)luaL_checknumber(L, 4);
            right = (lua_Integer)luaL_checknumber(L, 5);
            bottom = (lua_Integer)luaL_checknumber(L, 6);
        } else {
            left = 0;
            top = 0;
            right = (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientedSize].width;
            bottom = (lua_Integer)[[ScreenCaptureLuaBridge sharedBridge] orientedSize].height;
        }
        
        if (left < 0 || top < 0 || left >= right || top >= bottom) {
            return luaL_error(L, SCERR_REGION_INVALID, left, top, right, bottom);
        }
        
        {
            /// Convert to CGPoint
            CGPoint leftTopPoint = CGPointMake(left, top);
            
            /// Check left-top CGPoint
            if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:leftTopPoint]) {
                CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, left, top, (int)tSize.width, (int)tSize.height);
            }
        }
        
        {
            /// Convert to CGPoint
            CGPoint rightBottomPoint = CGPointMake(right - 1, bottom - 1);
            
            /// Check right-bottom CGPoint
            if (![[ScreenCaptureLuaBridge sharedBridge] containsOrientedPoint:rightBottomPoint]) {
                CGSize tSize = [[ScreenCaptureLuaBridge sharedBridge] orientedSize];
                return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)tSize.width, (int)tSize.height);
            }
        }
        
        CHDebugLogSource(@"left %lld top %lld right %lld bottom %lld", left, top, right, bottom);
        
        /// Update display if needed
        if (![[ScreenCaptureLuaBridge sharedBridge] shouldKeepScreen]) {
            [[ScreenCapture sharedCapture] updateDisplay];
            
            CHDebugLogSource(@"screen display updated");
        } else {
            CHDebugLogSource(@"screen display kept");
        }
        
        CGRect cropRegion = CGRectMake(left, top, right - left, bottom - top);
        JSTPixelImage *haystackImage = [[[ScreenCapture sharedCapture] pixelImage] crop:cropRegion];
        
        CGFloat similarity;  // [0.0...1.0]
        CGRect boundingBox = [ScreenCaptureOpenCVWrapper multiscaleMatchTemplateWithSourceImage:haystackImage
                                                                                  templateImage:needleImage
                                                                               targetSimilarity:(CGFloat)targetSimilarity / 1e2
                                                                                     similarity:&similarity];
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        if (CGRectIsNull(boundingBox)) {
            lua_pushnil(L);
            lua_pushnil(L);
            lua_pushnil(L);
            lua_pushnil(L);
            lua_pushnil(L);
            return 5;
        }
        
        lua_pushinteger(L, (lua_Integer)(boundingBox.origin.x));
        lua_pushinteger(L, (lua_Integer)(boundingBox.origin.y));
        lua_pushinteger(L, (lua_Integer)(boundingBox.origin.x + boundingBox.size.width));
        lua_pushinteger(L, (lua_Integer)(boundingBox.origin.y + boundingBox.size.height));
        lua_pushnumber(L, similarity * 1e2);
        return 5;
    }
}

/**
 * Image buffer garbage collection
 */
static int ScreenCapture_ImageGC(lua_State *L)
{
    ImageBuffer *buf = toImageBuffer(L, 1);
    fprintf(stderr, "gc, " L_TYPE_IMAGE_BUFFER " = %p\n", buf);
    buf->image = nil;
    if (buf->imageID > 0) {
        pthread_mutex_lock(&__globalImageObjectsLock);
        [__globalImageObjects removeObjectForKey:@(buf->imageID)];
        pthread_mutex_unlock(&__globalImageObjectsLock);
    }
    return 0;
}

/**
 * Image buffer description
 */
static int ScreenCapture_ImageToString(lua_State *L)
{
    char buff[32];
    ImageBuffer *buf = toImageBuffer(L, 1);
    if (buf->image) {
        snprintf(buff, 32, "%p", buf);
    } else {
        snprintf(buff, 32, "%p <deallocated>", buf);
    }
    lua_pushfstring(L, L_TYPE_IMAGE_BUFFER ": %s", buff);
    return 1;
}

/**
 * Image buffer force dereference
 */
static int ScreenCapture_Image_Destroy(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    buf->image = nil;
    pthread_mutex_lock(&__globalImageObjectsLock);
    [__globalImageObjects removeObjectForKey:@(buf->imageID)];
    pthread_mutex_unlock(&__globalImageObjectsLock);
    return 0;
}

/**
 * Image buffer copy
 */
static int ScreenCapture_Image_Copy(lua_State *L)
{
    ImageBuffer *bar = checkImageBuffer(L, 1);
    JSTPixelImage *copiedImage = [bar->image copy];
    
    if (!copiedImage) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    
    /// Construct image buffer
    pthread_mutex_lock(&__globalImageObjectsLock);
    ImageBuffer *buf = pushImageBuffer(L);
    buf->imageID = ++__globalImageAutoIncrementID;
    buf->image = copiedImage;
    __globalImageObjects[@(buf->imageID)] = copiedImage;
    pthread_mutex_unlock(&__globalImageObjectsLock);
    
    return 1;
}

/**
 * Image buffer crop
 */
static int ScreenCapture_Image_Crop(lua_State *L)
{
    ImageBuffer *bar = checkImageBuffer(L, 1);
    
    lua_Integer left, top, right, bottom;
    left = (lua_Integer)luaL_checknumber(L, 2);
    top = (lua_Integer)luaL_checknumber(L, 3);
    right = (lua_Integer)luaL_checknumber(L, 4);
    bottom = (lua_Integer)luaL_checknumber(L, 5);
    
    if (left < 0 || top < 0 || left >= right || top >= bottom) {
        return luaL_error(L, SCERR_REGION_INVALID, left, top, right, bottom);
    }
    
    if (!bar->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    
    JSTPixelImage *fullImage = bar->image;
    CGSize imageSize = [fullImage orientedSize];
    CGRect imageBounds = CGRectMake(0, 0, imageSize.width, imageSize.height);
    CGRect cropRegion = CGRectMake(left, top, right - left, bottom - top);
    
    if (!CGRectContainsRect(imageBounds, cropRegion)) {
        return luaL_error(L, SCERR_COORDINATE_OUT_OF_RANGE, right, bottom, (int)imageSize.width, (int)imageSize.height);
    }
    
    @autoreleasepool {
        JSTPixelImage *cropImage = [bar->image crop:cropRegion];
        
        /// Construct image buffer
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *buf = pushImageBuffer(L);
        buf->imageID = ++__globalImageAutoIncrementID;
        buf->image = cropImage;
        __globalImageObjects[@(buf->imageID)] = cropImage;
        pthread_mutex_unlock(&__globalImageObjectsLock);
    }
    
    return 1;
}

static int ScreenCapture_Image_SaveToAlbum(lua_State *L)
{
    @autoreleasepool {
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        ImageBuffer *bar = checkImageBuffer(L, 1);
        lua_Number remoteTimeout = luaL_optnumber(L, 2, 3000);
        
        remoteTimeout /= 1e3;
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        NSData *pngData = [bar->image pngRepresentation];
        NSDictionary *remoteProxyResult = [[ScreenCapture sharedCapture] performSavePhotoToAlbumRequestWithData:pngData timeout:remoteTimeout];
        
        /// Check if it timed out
        if ([remoteProxyResult[@"status"] intValue] != 0) {
            lua_pushboolean(L, false);
            lua_pushstring(L, "photo proxy timed out");
            return 2;
        }
        
        /// Check if it succeed
        if (![remoteProxyResult[@"succeed"] boolValue]) {
            lua_pushboolean(L, false);
            if (remoteProxyResult[@"error"]) {
                lua_pushstring(L, [remoteProxyResult[@"error"] UTF8String]);
            } else {
                lua_pushnil(L);
            }
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 2;
    }
}

static int ScreenCapture_Image_PNGData(lua_State *L)
{
    @autoreleasepool {
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        ImageBuffer *bar = checkImageBuffer(L, 1);
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        NSData *pngData = [bar->image pngRepresentation];
        lua_pushlstring(L, (const char *)[pngData bytes], [pngData length]);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
    }
}

static int ScreenCapture_Image_JPEGData(lua_State *L)
{
    @autoreleasepool {
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        ImageBuffer *bar = checkImageBuffer(L, 1);
        lua_Number cQuality = luaL_optnumber(L, 2, 1.0);
        
        cQuality = MAX(MIN(cQuality, 1.0), 0.0);
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        NSData *jpegData = [bar->image jpegRepresentationWithCompressionQuality:cQuality];
        lua_pushlstring(L, (const char *)[jpegData bytes], [jpegData length]);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
    }
}

static int ScreenCapture_Image_SaveToPNG(lua_State *L)
{
    @autoreleasepool {
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        ImageBuffer *bar = checkImageBuffer(L, 1);
        const char *cPath = luaL_checkstring(L, 2);
        
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        NSData *pngData = [bar->image pngRepresentation];
        BOOL writeSucceed = [pngData writeToFile:path atomically:YES];
        lua_pushboolean(L, writeSucceed);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
    }
}

static int ScreenCapture_Image_SaveToJPEG(lua_State *L)
{
    @autoreleasepool {
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        ImageBuffer *bar = checkImageBuffer(L, 1);
        const char *cPath = luaL_checkstring(L, 2);
        lua_Number cQuality = luaL_optnumber(L, 3, 1.0);
        
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        cQuality = MAX(MIN(cQuality, 1.0), 0.0);
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        NSData *jpegData = [bar->image jpegRepresentationWithCompressionQuality:cQuality];
        BOOL writeSucceed = [jpegData writeToFile:path atomically:YES];
        lua_pushboolean(L, writeSucceed);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
    }
}

static int ScreenCapture_Image_TurnLeft(lua_State *L)
{
    @autoreleasepool {
        ImageBuffer *bar = checkImageBuffer(L, 1);
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        JST_ORIENTATION orient = [bar->image orientation];
        if (orient == ScreenCaptureOrientationHomeOnBottom) {
            orient = ScreenCaptureOrientationHomeOnRight;
        } else if (orient == ScreenCaptureOrientationHomeOnRight) {
            orient = ScreenCaptureOrientationHomeOnTop;
        } else if (orient == ScreenCaptureOrientationHomeOnLeft) {
            orient = ScreenCaptureOrientationHomeOnBottom;
        } else if (orient == ScreenCaptureOrientationHomeOnTop) {
            orient = ScreenCaptureOrientationHomeOnLeft;
        }
        
        [bar->image setOrientation:orient];
        
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *foo = pushImageBuffer(L);
        foo->imageID = ++__globalImageAutoIncrementID;
        foo->image = bar->image;
        __globalImageObjects[@(foo->imageID)] = bar->image;
        pthread_mutex_unlock(&__globalImageObjectsLock);
        
        return 1;
    }
}

static int ScreenCapture_Image_TurnRight(lua_State *L)
{
    @autoreleasepool {
        ImageBuffer *bar = checkImageBuffer(L, 1);
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        JST_ORIENTATION orient = [bar->image orientation];
        if (orient == ScreenCaptureOrientationHomeOnBottom) {
            orient = ScreenCaptureOrientationHomeOnLeft;
        } else if (orient == ScreenCaptureOrientationHomeOnRight) {
            orient = ScreenCaptureOrientationHomeOnBottom;
        } else if (orient == ScreenCaptureOrientationHomeOnLeft) {
            orient = ScreenCaptureOrientationHomeOnTop;
        } else if (orient == ScreenCaptureOrientationHomeOnTop) {
            orient = ScreenCaptureOrientationHomeOnRight;
        }
        
        [bar->image setOrientation:orient];
        
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *foo = pushImageBuffer(L);
        foo->imageID = ++__globalImageAutoIncrementID;
        foo->image = bar->image;
        __globalImageObjects[@(foo->imageID)] = bar->image;
        pthread_mutex_unlock(&__globalImageObjectsLock);
        
        return 1;
    }
}

static int ScreenCapture_Image_TurnUponDown(lua_State *L)
{
    @autoreleasepool {
        ImageBuffer *bar = checkImageBuffer(L, 1);
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        JST_ORIENTATION orient = [bar->image orientation];
        if (orient == ScreenCaptureOrientationHomeOnBottom) {
            orient = ScreenCaptureOrientationHomeOnTop;
        } else if (orient == ScreenCaptureOrientationHomeOnRight) {
            orient = ScreenCaptureOrientationHomeOnLeft;
        } else if (orient == ScreenCaptureOrientationHomeOnLeft) {
            orient = ScreenCaptureOrientationHomeOnRight;
        } else if (orient == ScreenCaptureOrientationHomeOnTop) {
            orient = ScreenCaptureOrientationHomeOnBottom;
        }
        
        [bar->image setOrientation:orient];
        
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *foo = pushImageBuffer(L);
        foo->imageID = ++__globalImageAutoIncrementID;
        foo->image = bar->image;
        __globalImageObjects[@(foo->imageID)] = bar->image;
        pthread_mutex_unlock(&__globalImageObjectsLock);
        
        return 1;
    }
}

static int ScreenCapture_Image_Is(lua_State *L)
{
    lua_pushboolean(L, isImageBuffer(L, 1));
    return 1;
}

static int ScreenCapture_Image_Size(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    
    CGSize imgSize = [buf->image orientedSize];
    
    lua_pushinteger(L, imgSize.width);
    lua_pushinteger(L, imgSize.height);
    return 2;
}

static int ScreenCapture_Image_Width(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    
    CGSize imgSize = [buf->image orientedSize];
    
    lua_pushinteger(L, imgSize.width);
    return 1;
}

static int ScreenCapture_Image_Height(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    
    CGSize imgSize = [buf->image orientedSize];
    
    lua_pushinteger(L, imgSize.height);
    return 1;
}

static int ScreenCapture_Image_LoadFile(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (!image) {
            lua_pushnil(L);
            return 1;
        }
        
        JSTPixelImage *pixelImage = [[JSTPixelImage alloc] initWithSystemImage:image];
        
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *foo = pushImageBuffer(L);
        foo->imageID = ++__globalImageAutoIncrementID;
        foo->image = pixelImage;
        __globalImageObjects[@(foo->imageID)] = pixelImage;
        pthread_mutex_unlock(&__globalImageObjectsLock);
        
        return 1;
    }
}

static int ScreenCapture_Image_LoadData(lua_State *L)
{
    @autoreleasepool {
        size_t cLength = 0;
        const char *cData = luaL_checklstring(L, 1, &cLength);
        NSData *data = [NSData dataWithBytesNoCopy:(void *)cData length:cLength freeWhenDone:NO];
        
        UIImage *image = [UIImage imageWithData:data];
        if (!image) {
            lua_pushnil(L);
            return 1;
        }
        
        JSTPixelImage *pixelImage = [[JSTPixelImage alloc] initWithSystemImage:image];
        
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *foo = pushImageBuffer(L);
        foo->imageID = ++__globalImageAutoIncrementID;
        foo->image = pixelImage;
        __globalImageObjects[@(foo->imageID)] = pixelImage;
        pthread_mutex_unlock(&__globalImageObjectsLock);
        
        return 1;
    }
}

static int ScreenCapture_Image_GetColor(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    return ScreenCapture_GetColor_Internal(L, 1, buf->image, YES);
}

static int ScreenCapture_Image_GetColorRGB(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    return ScreenCapture_GetColorRGB_Internal(L, 1, buf->image);
}

static int ScreenCapture_Image_IsColors(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    return ScreenCapture_IsColors_Internal(L, 1, buf->image);
}

static int ScreenCapture_Image_FindColor(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    return __ScreenCapture_FindColor_Internal(L, 1, buf->image, NO);
}

static int ScreenCapture_Image_FindColor_Normalize(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    return __ScreenCapture_FindColor_Internal(L, 1, buf->image, YES);
}

static int ScreenCapture_Image_OcrText(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    return ScreenCapture_OcrText_Internal(L, 1, buf->image);
}

static int ScreenCapture_Image_DetectBarcodes(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    return ScreenCapture_DetectBarcodes_Internal(L, 1, buf->image, NO);
}

static int ScreenCapture_Image_QRDecode(lua_State *L)
{
    ImageBuffer *buf = checkImageBuffer(L, 1);
    if (!buf->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    return ScreenCapture_DetectBarcodes_Internal(L, 1, buf->image, YES);
}

static int ScreenCapture_Image_CVFindImage(lua_State *L)
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    ImageBuffer *haystack = checkImageBuffer(L, 1);
    if (!haystack->image) {
        return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    
    ImageBuffer *needle = checkImageBuffer(L, 2);
    if (!needle->image) {
        return luaL_argerror(L, 2, SCERR_DESTROYED_IMAGE_BUFFER);
    }
    
    CGFloat similarity;  // [0.0...1.0]
    CGPoint boundingPosition = [ScreenCaptureOpenCVWrapper matchTemplateWithSourceImage:haystack->image
                                                                          templateImage:needle->image
                                                                             similarity:&similarity];
    
    lua_pushinteger(L, (lua_Integer)boundingPosition.x);
    lua_pushinteger(L, (lua_Integer)boundingPosition.y);
    lua_pushnumber(L, similarity * 1e2);
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
    
    return 3;
}

static int ScreenCapture_Image_CVBinarization(lua_State *L)
{
    @autoreleasepool {
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        ImageBuffer *bar = checkImageBuffer(L, 1);
        lua_Number threshold = luaL_optnumber(L, 2, 127.0);
        
        if (!bar->image) {
            return luaL_argerror(L, 1, SCERR_DESTROYED_IMAGE_BUFFER);
        }
        
        [ScreenCaptureOpenCVWrapper performBinarizationToImage:bar->image threshold:threshold];
        
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *foo = pushImageBuffer(L);
        foo->imageID = ++__globalImageAutoIncrementID;
        foo->image = bar->image;
        __globalImageObjects[@(foo->imageID)] = bar->image;
        pthread_mutex_unlock(&__globalImageObjectsLock);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
    }
}

static int ScreenCapture_Image_QREncode(lua_State *L)
{
    @autoreleasepool {
#if DEBUG
        __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        
        const char *cPayload = luaL_checkstring(L, 1);
        NSString *payload = [NSString stringWithUTF8String:cPayload];
        
        NSDictionary *options = nil;
        if (lua_type(L, 2) == LUA_TTABLE) {
            options = lua_toNSDictionary(L, 2);
        }
        
        CGFloat borderWidth = options[@"size"] != nil ? [options[@"size"] doubleValue] : 320.0;
        CGSize fittingSize = CGSizeMake(borderWidth, borderWidth);
        
        uint32_t fillARGBColor = options[@"fill_color"] != nil ? [options[@"fill_color"] unsignedIntValue] : 0xFF000000;
        uint32_t backgroundARGBColor = options[@"background_color"] != nil ? [options[@"background_color"] unsignedIntValue] : 0xFFFFFFFF;
        
        JSTPixelColor *foregroundJSTColor = [JSTPixelColor colorWithARGBHexInt:fillARGBColor];
        JSTPixelColor *backgroundJSTColor = [JSTPixelColor colorWithARGBHexInt:backgroundARGBColor];
        
        JSTPixelImage *pixelImage = [[ScreenCapture sharedCapture] performQuickResponseImageGeneratingRequestWithPayload:payload
                                                                                                             fittingSize:fittingSize
                                                                                                               fillColor:foregroundJSTColor
                                                                                                         backgroundColor:backgroundJSTColor];
        
        pthread_mutex_lock(&__globalImageObjectsLock);
        ImageBuffer *foo = pushImageBuffer(L);
        foo->imageID = ++__globalImageAutoIncrementID;
        foo->image = pixelImage;
        __globalImageObjects[@(foo->imageID)] = pixelImage;
        pthread_mutex_unlock(&__globalImageObjectsLock);
        
#if DEBUG
        __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        double used = (endAt - beginAt) / 1e6;
        CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
        
        return 1;
    }
}


#pragma mark -

static const luaL_Reg ScreenCapture_Image_MetaLib[] = {
    
    /* Internal APIs */
    {"__gc",       ScreenCapture_ImageGC},
    {"__tostring", ScreenCapture_ImageToString},
    
    /* Low-Level APIs */
    {"size", ScreenCapture_Image_Size},
    {"width", ScreenCapture_Image_Width},
    {"height", ScreenCapture_Image_Height},
    
    /* Output */
    {"save_to_album", ScreenCapture_Image_SaveToAlbum},
    {"save_to_png_file", ScreenCapture_Image_SaveToPNG},
    {"save_to_jpeg_file", ScreenCapture_Image_SaveToJPEG},
    {"png_data", ScreenCapture_Image_PNGData},
    {"jpeg_data", ScreenCapture_Image_JPEGData},
    
    /* Rotate */
    {"turn_left", ScreenCapture_Image_TurnLeft},   // counterclockwise
    {"turn_right", ScreenCapture_Image_TurnRight},  // clockwise
    {"turn_upondown", ScreenCapture_Image_TurnUponDown},
    
    /* Memory Management */
    {"destroy", ScreenCapture_Image_Destroy},
    {"copy", ScreenCapture_Image_Copy},
    {"crop", ScreenCapture_Image_Crop},
    
    /* Common APIs */
    {"get_color", ScreenCapture_Image_GetColor},
    {"get_color_rgb", ScreenCapture_Image_GetColorRGB},
    {"is_colors", ScreenCapture_Image_IsColors},
    {"find_color", ScreenCapture_Image_FindColor},
    {"find_color_normalize", ScreenCapture_Image_FindColor_Normalize},
    
    /* Proxy APIs */
    {"ocr_text", ScreenCapture_Image_OcrText},
    {"qr_decode", ScreenCapture_Image_QRDecode},
    {"detect_barcodes", ScreenCapture_Image_DetectBarcodes},
    
    /* OpenCV APIs */
    {"cv_find_image", ScreenCapture_Image_CVFindImage},
    {"cv_binarization", ScreenCapture_Image_CVBinarization},
    
    {NULL, NULL},
};


#pragma mark -

static const luaL_Reg ScreenCapture_Image_AuxLib[] = {
    
    /* Low-Level APIs */
    {"is", ScreenCapture_Image_Is},
    
    /* Input */
    {"load_file", ScreenCapture_Image_LoadFile},
    {"load_data", ScreenCapture_Image_LoadData},
    
    /* Generator */
    {"qr_encode", ScreenCapture_Image_QREncode},
    
    /* Data Preprocessing */
    {"color_similarity", ScreenCapture_ColorSimilarity},
    {"color_offset", ScreenCapture_ColorOffset},
    
    {NULL, NULL},
};


#pragma mark -

static const luaL_Reg ScreenCapture_AuxLib[] = {
    
    /* Initialize & Coordinate System */
    {"init", ScreenCapture_Init},
    {"init_home_on_bottom", ScreenCapture_Init_HomeOnBottom},
    {"init_home_on_right", ScreenCapture_Init_HomeOnRight},
    {"init_home_on_left", ScreenCapture_Init_HomeOnLeft},
    {"init_home_on_top", ScreenCapture_Init_HomeOnTop},
    {"orientation", ScreenCapture_Orientation},
    {"size", ScreenCapture_Size},
    {"rotate_xy", ScreenCapture_RotateXY},
    
    /* Screen Caching */
    {"keep", ScreenCapture_Keep},
    {"unkeep", ScreenCapture_Unkeep},
    
    /* Data Preprocessing */
    {"color_similarity", ScreenCapture_ColorSimilarity},
    {"color_offset", ScreenCapture_ColorOffset},
    
    /* Common APIs */
    {"get_color", ScreenCapture_GetColor},
    {"get_color_rgb", ScreenCapture_GetColorRGB},
    {"is_colors", ScreenCapture_IsColors},
    {"find_color", ScreenCapture_FindColor},
    {"find_color_normalize", ScreenCapture_FindColor_Normalize},
    
    /* Proxy APIs */
    {"ocr_text", ScreenCapture_OcrText},
    {"detect_barcodes", ScreenCapture_DetectBarcodes},
    
    /* Image Related */
    {"image", ScreenCapture_Image},
    {"find_image", ScreenCapture_FindImage},
    
    {NULL, NULL},
};

XXTouchF_CAPI int luaopen_image(lua_State *L)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __globalImageObjects = [[NSMutableDictionary alloc] init];
        pthread_mutex_init(&__globalImageObjectsLock, NULL);
        
        luaL_newmetatable(L, L_TYPE_IMAGE_BUFFER);
        lua_pushstring(L, "__index");
        lua_pushvalue(L, -2);
        lua_settable(L, -3);
        luaL_setfuncs(L, ScreenCapture_Image_MetaLib, 0);
    });
    
    lua_createtable(L, 0, (sizeof(ScreenCapture_Image_AuxLib) / sizeof((ScreenCapture_Image_AuxLib)[0]) - 1) + 2);
#if DEBUG
    lua_pushliteral(L, LUA_MODULE_VERSION "+debug");
#else
    lua_pushliteral(L, LUA_MODULE_VERSION);
#endif
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, ScreenCapture_Image_AuxLib, 0);
    
    return 1;
}

XXTouchF_CAPI int luaopen_screen(lua_State *L)
{
    luaL_requiref(L, "image", luaopen_image, YES);
    lua_pop(L, 1);
    
    lua_createtable(L, 0, (sizeof(ScreenCapture_AuxLib) / sizeof((ScreenCapture_AuxLib)[0]) - 1) + 6);
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
    luaL_setfuncs(L, ScreenCapture_AuxLib, 0);
    
    return 1;
}

XXTouchF_CAPI int luaopen_eximage(lua_State *L)
{
    return luaopen_image(L);
}

XXTouchF_CAPI int luaopen_exscreen(lua_State *L)
{
    return luaopen_screen(L);
}
