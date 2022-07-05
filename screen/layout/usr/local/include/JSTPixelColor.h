#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

#define SystemColor UIColor
#define SystemColorSpace CGColorSpaceRef
#else
#import <AppKit/AppKit.h>

#define SystemColor NSColor
#define SystemColorSpace NSColorSpace *
#endif

#import "JST_COLOR.h"


NS_ASSUME_NONNULL_BEGIN

/** JSTPixelColor is the pixel color representation of the JSTPixelImage,
 * which represents any RGB or grayscale color with alpha channel.
 * It does not belong to any color space.
 */
@interface JSTPixelColor : NSObject <NSSecureCoding, NSCopying> {
    JST_COLOR_COMPONENT_TYPE _alpha;
    JST_COLOR_COMPONENT_TYPE _red;
    JST_COLOR_COMPONENT_TYPE _green;
    JST_COLOR_COMPONENT_TYPE _blue;
}

@property (assign, readonly) JST_COLOR_COMPONENT_TYPE alpha;
@property (assign, readonly) JST_COLOR_COMPONENT_TYPE red;
@property (assign, readonly) JST_COLOR_COMPONENT_TYPE green;
@property (assign, readonly) JST_COLOR_COMPONENT_TYPE blue;

@property (assign, readonly) JST_COLOR_TYPE rgbValue;
@property (assign, readonly) JST_COLOR_TYPE argbValue;

@property (copy, readonly) NSString *hexString;
@property (copy, readonly) NSString *hexStringWithAlpha;
@property (copy, readonly) NSString *cssString;
@property (copy, readonly) NSString *cssRGBAString;

+ (JSTPixelColor *)colorWithColorHex:(NSString *)hex;
+ (JSTPixelColor *)colorWithRGBAHexInt:(JST_COLOR_TYPE)rgbaValue;
+ (JSTPixelColor *)colorWithARGBHexInt:(JST_COLOR_TYPE)argbValue;

/* Color Space Independent */
+ (JSTPixelColor *)colorWithRed:(JST_COLOR_COMPONENT_TYPE)red green:(JST_COLOR_COMPONENT_TYPE)green blue:(JST_COLOR_COMPONENT_TYPE)blue alpha:(JST_COLOR_COMPONENT_TYPE)alpha;
+ (JSTPixelColor *)colorWithJSTColor:(JSTPixelColor *)jstcolor;
- (void)setRed:(JST_COLOR_COMPONENT_TYPE)red green:(JST_COLOR_COMPONENT_TYPE)green blue:(JST_COLOR_COMPONENT_TYPE)blue alpha:(JST_COLOR_COMPONENT_TYPE)alpha;

/* Color Space Related */
+ (JSTPixelColor *)colorWithSystemColor:(SystemColor *)systemColor;
- (void)setColorWithSystemColor:(SystemColor *)systemColor;
- (SystemColor *)toSystemColorWithColorSpace:(SystemColorSpace)colorSpace;

@end

NS_ASSUME_NONNULL_END

