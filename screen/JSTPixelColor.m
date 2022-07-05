#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "JSTPixelColor.h"


@implementation JSTPixelColor

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    JST_COLOR_COMPONENT_TYPE red   = (JST_COLOR_COMPONENT_TYPE)[coder decodeIntForKey:@"red"];
    JST_COLOR_COMPONENT_TYPE green = (JST_COLOR_COMPONENT_TYPE)[coder decodeIntForKey:@"green"];
    JST_COLOR_COMPONENT_TYPE blue  = (JST_COLOR_COMPONENT_TYPE)[coder decodeIntForKey:@"blue"];
    JST_COLOR_COMPONENT_TYPE alpha = (JST_COLOR_COMPONENT_TYPE)[coder decodeIntForKey:@"alpha"];
    return [self initWithRed:red green:green blue:blue alpha:alpha];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:(int)self.red forKey:@"red"];
    [coder encodeInt:(int)self.green forKey:@"green"];
    [coder encodeInt:(int)self.blue forKey:@"blue"];
    [coder encodeInt:(int)self.alpha forKey:@"alpha"];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return [[JSTPixelColor alloc] initWithJSTColor:self];
}

+ (JSTPixelColor *)colorWithRed:(JST_COLOR_COMPONENT_TYPE)red
                          green:(JST_COLOR_COMPONENT_TYPE)green
                           blue:(JST_COLOR_COMPONENT_TYPE)blue
                          alpha:(JST_COLOR_COMPONENT_TYPE)alpha
{
    return [[JSTPixelColor alloc] initWithRed:red green:green blue:blue alpha:alpha];
}

+ (JSTPixelColor *)colorWithColorHex:(NSString *)hex
{
    return [[JSTPixelColor alloc] initWithColorHex:hex];
}

+ (JSTPixelColor *)colorWithRGBAHexInt:(JST_COLOR_TYPE)rgbaValue
{
    return [[JSTPixelColor alloc] initWithRGBAHexInt:rgbaValue];
}

+ (JSTPixelColor *)colorWithARGBHexInt:(JST_COLOR_TYPE)argbValue
{
    return [[JSTPixelColor alloc] initWithARGBHexInt:argbValue];
}

+ (JSTPixelColor *)colorWithJSTColor:(JSTPixelColor *)jstcolor
{
    return [[JSTPixelColor alloc] initWithJSTColor:jstcolor];
}

- (JST_COLOR_TYPE)argbValue
{
    JST_COLOR color;
    color.alpha = _alpha;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    return color.theColor;
}

- (JST_COLOR_TYPE)rgbValue
{
    JST_COLOR color;
    color.alpha = 0;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    return color.theColor;
}

- (NSString *)hexStringWithAlpha
{
    JST_COLOR color;
    color.alpha = _alpha;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    return [NSString stringWithFormat:@"0x%08x", color.theColor];
}

- (NSString *)hexString
{
    JST_COLOR color;
    color.alpha = 0;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    return [NSString stringWithFormat:@"0x%06x", color.theColor];
}

- (NSString *)cssString
{
    JST_COLOR color;
    color.alpha = 0;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    return [NSString stringWithFormat:@"#%06X", color.theColor];
}

- (NSString *)cssRGBAString
{
    return [NSString stringWithFormat:@"rgba(%d,%d,%d,%.2f)", self.red, self.green, self.blue, (float)self.alpha / 0xff];
}

- (instancetype)init
{
    if (self = [super init]) {
        _alpha = 0;
        _red = 0;
        _green = 0;
        _blue = 0;
    }
    return self;
}

- (instancetype)initWithRed:(JST_COLOR_COMPONENT_TYPE)red green:(JST_COLOR_COMPONENT_TYPE)green blue:(JST_COLOR_COMPONENT_TYPE)blue alpha:(JST_COLOR_COMPONENT_TYPE)alpha
{
    self = [self init];
    [self setRed:red green:green blue:blue alpha:alpha];
    return self;
}

- (instancetype)initWithColorHex:(NSString *)hex
{
    if ([hex hasPrefix:@"#"]) {
        hex = [hex substringFromIndex:1];
    } else if ([hex hasPrefix:@"0x"]) {
        hex = [hex substringFromIndex:2];
    }
    NSUInteger length = hex.length;
    if (length != 3 && length != 6 && length != 8)
        return nil;
    if (length == 3) {
        NSString *r = [hex substringWithRange:NSMakeRange(0, 1)];
        NSString *g = [hex substringWithRange:NSMakeRange(1, 1)];
        NSString *b = [hex substringWithRange:NSMakeRange(2, 1)];
        hex = [NSString stringWithFormat:@"%@%@%@%@%@%@ff", r, r, g, g, b, b];
    } else if (length == 6) {
        hex = [NSString stringWithFormat:@"%@ff", hex];
    }
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    JST_COLOR_TYPE rgbaValue = 0;
    [scanner scanHexInt:&rgbaValue];
    return [self initWithRGBAHexInt:rgbaValue];
}

- (instancetype)initWithRGBAHexInt:(JST_COLOR_TYPE)rgbaValue
{
    return [self initWithRed:(JST_COLOR_COMPONENT_TYPE)((rgbaValue & 0xFF000000) >> 24)
                       green:(JST_COLOR_COMPONENT_TYPE)((rgbaValue & 0xFF0000) >> 16)
                        blue:(JST_COLOR_COMPONENT_TYPE)((rgbaValue & 0xFF00) >> 8)
                       alpha:(JST_COLOR_COMPONENT_TYPE)((rgbaValue & 0xFF))];
}

- (instancetype)initWithARGBHexInt:(JST_COLOR_TYPE)argbValue
{
    return [self initWithRed:(JST_COLOR_COMPONENT_TYPE)((argbValue & 0xFF0000) >> 16)
                       green:(JST_COLOR_COMPONENT_TYPE)((argbValue & 0xFF00) >> 8)
                        blue:(JST_COLOR_COMPONENT_TYPE)((argbValue & 0xFF))
                       alpha:(JST_COLOR_COMPONENT_TYPE)((argbValue & 0xFF000000) >> 24)];
}

- (instancetype)initWithJSTColor:(JSTPixelColor *)jstcolor
{
    return [self initWithRed:jstcolor.red green:jstcolor.green blue:jstcolor.blue alpha:jstcolor.alpha];
}

- (void)setRed:(JST_COLOR_COMPONENT_TYPE)red green:(JST_COLOR_COMPONENT_TYPE)green blue:(JST_COLOR_COMPONENT_TYPE)blue alpha:(JST_COLOR_COMPONENT_TYPE)alpha
{
    _red = red;
    _green = green;
    _blue = blue;
    _alpha = alpha;
}

- (JST_COLOR_COMPONENT_TYPE)red
{
    return _red;
}

- (void)setRed:(JST_COLOR_COMPONENT_TYPE)red
{
    _red = red;
}

- (JST_COLOR_COMPONENT_TYPE)green
{
    return _green;
}

- (void)setGreen:(JST_COLOR_COMPONENT_TYPE)green
{
    _green = green;
}

- (JST_COLOR_COMPONENT_TYPE)blue
{
    return _blue;
}

- (void)setBlue:(JST_COLOR_COMPONENT_TYPE)blue
{
    _blue = blue;
}

- (JST_COLOR_COMPONENT_TYPE)alpha
{
    return _alpha;
}

- (void)setAlpha:(JST_COLOR_COMPONENT_TYPE)alpha
{
    _alpha = alpha;
}

- (JSTPixelColor *)initWithSystemColor:(SystemColor *)systemColor
{
    self = [self init];
    if (self) {
        [self setColorWithSystemColor:systemColor];
    }
    return self;
}

+ (JSTPixelColor *)colorWithSystemColor:(SystemColor *)systemColor
{
    return [[JSTPixelColor alloc] initWithSystemColor:systemColor];
}

- (NSString *)description {
    return self.cssString;
}

- (SystemColor *)toSystemColorWithColorSpace:(SystemColorSpace)colorSpace
{
#if TARGET_OS_IPHONE
    NSAssert(CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelRGB || CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelMonochrome, @"unsupported color model");
#else
    NSAssert(colorSpace.colorSpaceModel == NSColorSpaceModelRGB || colorSpace.colorSpaceModel == NSColorSpaceModelGray,
             @"unsupported color model");
#endif
    
#if TARGET_OS_IPHONE
    if (CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelRGB) {
        CGFloat components[5];
        bzero(components, sizeof(components));
        components[0] = (CGFloat)_red / JST_COLOR_COMPONENT_MAX_VALUE;
        components[1] = (CGFloat)_green / JST_COLOR_COMPONENT_MAX_VALUE;
        components[2] = (CGFloat)_blue / JST_COLOR_COMPONENT_MAX_VALUE;
        components[3] = (CGFloat)_alpha / JST_COLOR_COMPONENT_MAX_VALUE;
        CGColorRef cgColor = CGColorCreate(colorSpace, components);
        SystemColor *color = [SystemColor colorWithCGColor:cgColor];
        CGColorRelease(cgColor);
        return color;
    } else {
        CGFloat _gray = 0.299 * (CGFloat)_red / JST_COLOR_COMPONENT_MAX_VALUE + 0.587 * (CGFloat)_green / JST_COLOR_COMPONENT_MAX_VALUE + 0.114 * (CGFloat)_blue / JST_COLOR_COMPONENT_MAX_VALUE;
        CGFloat components[3];
        bzero(components, sizeof(components));
        components[0] = (CGFloat)_gray / JST_COLOR_COMPONENT_MAX_VALUE;
        components[1] = (CGFloat)_alpha / JST_COLOR_COMPONENT_MAX_VALUE;
        CGColorRef cgColor = CGColorCreate(colorSpace, components);
        SystemColor *color = [SystemColor colorWithCGColor:cgColor];
        CGColorRelease(cgColor);
        return color;
    }
#else
    if (colorSpace.colorSpaceModel == NSColorSpaceModelRGB) {
        CGFloat components[5];
        bzero(components, sizeof(components));
        components[0] = (CGFloat)_red / JST_COLOR_COMPONENT_MAX_VALUE;
        components[1] = (CGFloat)_green / JST_COLOR_COMPONENT_MAX_VALUE;
        components[2] = (CGFloat)_blue / JST_COLOR_COMPONENT_MAX_VALUE;
        components[3] = (CGFloat)_alpha / JST_COLOR_COMPONENT_MAX_VALUE;
        return [SystemColor colorWithColorSpace:colorSpace components:components count:4];
    } else {
        CGFloat _gray = 0.299 * (CGFloat)_red / JST_COLOR_COMPONENT_MAX_VALUE + 0.587 * (CGFloat)_green / JST_COLOR_COMPONENT_MAX_VALUE + 0.114 * (CGFloat)_blue / JST_COLOR_COMPONENT_MAX_VALUE;
        CGFloat components[3];
        bzero(components, sizeof(components));
        components[0] = (CGFloat)_gray / JST_COLOR_COMPONENT_MAX_VALUE;
        components[1] = (CGFloat)_alpha / JST_COLOR_COMPONENT_MAX_VALUE;
        return [SystemColor colorWithColorSpace:colorSpace components:components count:2];
    }
#endif
}

- (void)setColorWithSystemColor:(SystemColor *)systemColor
{
    NSDictionary *colorDict = [self getRGBDictionaryFromSystemColor:systemColor];
    
    _red = (JST_COLOR_COMPONENT_TYPE)([colorDict[@"R"] doubleValue] * JST_COLOR_COMPONENT_MAX_VALUE);
    _green = (JST_COLOR_COMPONENT_TYPE)([colorDict[@"G"] doubleValue] * JST_COLOR_COMPONENT_MAX_VALUE);
    _blue = (JST_COLOR_COMPONENT_TYPE)([colorDict[@"B"] doubleValue] * JST_COLOR_COMPONENT_MAX_VALUE);
    _alpha = (JST_COLOR_COMPONENT_TYPE)([colorDict[@"A"] doubleValue] * JST_COLOR_COMPONENT_MAX_VALUE);
}

- (NSDictionary *)getRGBDictionaryFromSystemColor:(SystemColor *)systemColor
{
#if TARGET_OS_IPHONE
    NSAssert(CGColorSpaceGetModel(CGColorGetColorSpace(systemColor.CGColor)) == kCGColorSpaceModelRGB || CGColorSpaceGetModel(CGColorGetColorSpace(systemColor.CGColor)) == kCGColorSpaceModelMonochrome, @"unsupported color model");
#else
    NSAssert(systemColor.colorSpace.colorSpaceModel == NSColorSpaceModelRGB || systemColor.colorSpace.colorSpaceModel == NSColorSpaceModelGray,
             @"unsupported color model");
#endif
    
    CGFloat r = 0, g = 0, b = 0, a = 0, w = 0;
#if TARGET_OS_IPHONE
    if (![systemColor getRed:&r green:&g blue:&b alpha:&a]) {
        if ([systemColor getWhite:&w alpha:&a]) {
            r = w;
            g = w;
            b = w;
        }
    }
#else
    if (systemColor.numberOfComponents == 4) {
        if ([self respondsToSelector:@selector(getRed:green:blue:alpha:)]) {
            [systemColor getRed:&r green:&g blue:&b alpha:&a];
        } else {
            const CGFloat *components = CGColorGetComponents(systemColor.CGColor);
            r = components[0];
            g = components[1];
            b = components[2];
            a = components[3];
        }
    } else if (systemColor.numberOfComponents == 2) {
        if ([self respondsToSelector:@selector(getWhite:alpha:)]) {
            [systemColor getWhite:&w alpha:&a];
            r = w;
            g = w;
            b = w;
        } else {
            const CGFloat *components = CGColorGetComponents(systemColor.CGColor);
            r = components[0];
            g = components[0];
            b = components[0];
            a = components[1];
        }
    }
#endif
    
    return @{
        @"A":@(a),
        @"R":@(r),
        @"G":@(g),
        @"B":@(b),
    };
}

@end
