#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import "JSTPixelImage.h"
#import "IOSurfaceSPI.h"


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN void JSTGetColorInPixelImageSafe(JST_IMAGE *pixelImage, int x, int y, JST_COLOR *colorOfPoint);
FOUNDATION_EXTERN void JSTSetColorInPixelImageSafe(JST_IMAGE *pixelImage, int x, int y, JST_COLOR *colorOfPoint);

@interface JSTPixelImage (Private)
- (JSTPixelImage *)initWithCompatibleScreenSurface:(IOSurfaceRef)surface colorSpace:(CGColorSpaceRef)colorSpace;
@end

NS_ASSUME_NONNULL_END

