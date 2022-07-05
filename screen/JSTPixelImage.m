#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "JSTPixelImage.h"
#import "JSTPixelImage+Private.h"
#import "JSTPixelColor.h"
#import "JST_POS.h"
#import "JST_COLOR.h"

#import <stdlib.h>
#import <CoreGraphics/CoreGraphics.h>


#if TARGET_OS_IPHONE
#else
#pragma mark - NSImage (Compatibility)

@interface NSImage (Compatibility)

/**
   The underlying Core Graphics image object. This will actually use `CGImageForProposedRect` with the image size.
 */
@property (nonatomic, readonly, nullable) CGImageRef CGImage;
/**
   The scale factor of the image. This wil actually use `bestRepresentationForRect` with image size and pixel size to calculate the scale factor. If failed, use the default value 1.0. Should be greater than or equal to 1.0.
 */
@property (nonatomic, readonly) CGFloat scale;

// These are convenience methods to make AppKit's `NSImage` match UIKit's `UIImage` behavior. The scale factor should be greater than or equal to 1.0.

/**
   Returns an image object with the scale factor and orientation. The representation is created from the Core Graphics image object.
   @note The difference between this and `initWithCGImage:size` is that `initWithCGImage:size` will actually create a `NSCGImageSnapshotRep` representation and always use `backingScaleFactor` as scale factor. So we should avoid it and use `NSBitmapImageRep` with `initWithCGImage:` instead.
   @note The difference between this and UIKit's `UIImage` equivalent method is the way to process orientation. If the provided image orientation is not equal to Up orientation, this method will firstly rotate the CGImage to the correct orientation to work compatible with `NSImageView`. However, UIKit will not actually rotate CGImage and just store it as `imageOrientation` property.
   @param cgImage A Core Graphics image object
   @param scale The image scale factor
   @param orientation The orientation of the image data
   @return The image object
 */
- (nonnull instancetype)initWithCGImage:(nonnull CGImageRef)cgImage scale:(CGFloat)scale orientation:(CGImagePropertyOrientation)orientation;

/**
   Returns an image object with the scale factor. The representation is created from the image data.
   @note The difference between these this and `initWithData:` is that `initWithData:` will always use `backingScaleFactor` as scale factor.
   @param data The image data
   @param scale The image scale factor
   @return The image object
 */
- (nullable instancetype)initWithData:(nonnull NSData *)data scale:(CGFloat)scale;

@end

NS_INLINE CGAffineTransform SDCGContextTransformFromOrientation(CGImagePropertyOrientation orientation, CGSize size) {
    // Inspiration from @libfeihu
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (orientation) {
    case kCGImagePropertyOrientationDown:
    case kCGImagePropertyOrientationDownMirrored:
        transform = CGAffineTransformTranslate(transform, size.width, size.height);
        transform = CGAffineTransformRotate(transform, M_PI);
        break;
        
    case kCGImagePropertyOrientationLeft:
    case kCGImagePropertyOrientationLeftMirrored:
        transform = CGAffineTransformTranslate(transform, size.width, 0);
        transform = CGAffineTransformRotate(transform, M_PI_2);
        break;
        
    case kCGImagePropertyOrientationRight:
    case kCGImagePropertyOrientationRightMirrored:
        transform = CGAffineTransformTranslate(transform, 0, size.height);
        transform = CGAffineTransformRotate(transform, -M_PI_2);
        break;
    case kCGImagePropertyOrientationUp:
    case kCGImagePropertyOrientationUpMirrored:
        break;
    }
    
    switch (orientation) {
    case kCGImagePropertyOrientationUpMirrored:
    case kCGImagePropertyOrientationDownMirrored:
        transform = CGAffineTransformTranslate(transform, size.width, 0);
        transform = CGAffineTransformScale(transform, -1, 1);
        break;
        
    case kCGImagePropertyOrientationLeftMirrored:
    case kCGImagePropertyOrientationRightMirrored:
        transform = CGAffineTransformTranslate(transform, size.height, 0);
        transform = CGAffineTransformScale(transform, -1, 1);
        break;
    case kCGImagePropertyOrientationUp:
    case kCGImagePropertyOrientationDown:
    case kCGImagePropertyOrientationLeft:
    case kCGImagePropertyOrientationRight:
        break;
    }
    
    return transform;
}

@implementation NSImage (Compatibility)

+ (BOOL)CGImageContainsAlpha:(CGImageRef)cgImage {
    if (!cgImage) {
        return NO;
    }
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage);
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    return hasAlpha;
}

+ (CGColorSpaceRef)colorSpaceGetDeviceRGB {
    CGColorSpaceRef screenColorSpace = NSScreen.mainScreen.colorSpace.CGColorSpace;
    if (screenColorSpace) {
        return screenColorSpace;
    }
    static CGColorSpaceRef colorSpace;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceRGB();
    });
    return colorSpace;
}

+ (CGImageRef)CGImageCreateDecoded:(CGImageRef)cgImage orientation:(CGImagePropertyOrientation)orientation {
    if (!cgImage) {
        return NULL;
    }
    
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return NULL;
    
    size_t newWidth;
    size_t newHeight;
    switch (orientation) {
    case kCGImagePropertyOrientationLeft:
    case kCGImagePropertyOrientationLeftMirrored:
    case kCGImagePropertyOrientationRight:
    case kCGImagePropertyOrientationRightMirrored: {
        // These orientation should swap width & height
        newWidth = height;
        newHeight = width;
    }
    break;
    default: {
        newWidth = width;
        newHeight = height;
    }
    break;
    }
    
    BOOL hasAlpha = NO /* [self CGImageContainsAlpha:cgImage] */;
    // iOS prefer BGRA8888 (premultiplied) or BGRX8888 bitmapInfo for screen rendering, which is same as `UIGraphicsBeginImageContext()` or `- [CALayer drawInContext:]`
    // Though you can use any supported bitmapInfo (see: https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB ) and let Core Graphics reorder it when you call `CGContextDrawImage`
    
    // But since our build-in coders use this bitmapInfo, this can have a little performance benefit
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
    bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
    CGContextRef context = CGBitmapContextCreate(NULL, newWidth, newHeight, 8, 0 /* auto calculated and aligned */, [self colorSpaceGetDeviceRGB], bitmapInfo);
    if (!context) {
        return NULL;
    }
    
    // Apply transform
    CGAffineTransform transform = SDCGContextTransformFromOrientation(orientation, CGSizeMake(newWidth, newHeight));
    CGContextConcatCTM(context, transform);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage); // The rect is bounding box of CGImage, don't swap width & height
    CGImageRef newImageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    return newImageRef;
}

- (nullable CGImageRef)CGImage {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    CGImageRef cgImage = [self CGImageForProposedRect:&imageRect context:nil hints:nil];
    return cgImage;
}

- (CGFloat)scale {
    CGFloat scale = 1;
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    CGFloat width = imageRep.size.width;
    CGFloat height = imageRep.size.height;
    NSUInteger pixelWidth = imageRep.pixelsWide;
    NSUInteger pixelHeight = imageRep.pixelsHigh;
    if (width > 0 && height > 0) {
        CGFloat widthScale = pixelWidth / width;
        CGFloat heightScale = pixelHeight / height;
        if (widthScale == heightScale && widthScale >= 1) {
            // Protect because there may be `NSImageRepMatchesDevice` (0)
            scale = widthScale;
        }
    }
    
    return scale;
}

- (instancetype)initWithCGImage:(nonnull CGImageRef)cgImage scale:(CGFloat)scale orientation:(CGImagePropertyOrientation)orientation {
    NSBitmapImageRep *imageRep;
    if (orientation != kCGImagePropertyOrientationUp) {
        // AppKit design is different from UIKit. Where CGImage based image rep does not respect to any orientation. Only data based image rep which contains the EXIF metadata can automatically detect orientation.
        // This should be nonnull, until the memory is exhausted cause `CGBitmapContextCreate` failed.
        CGImageRef rotatedCGImage = [NSImage CGImageCreateDecoded:cgImage orientation:orientation];
        imageRep = [[NSBitmapImageRep alloc] initWithCGImage:rotatedCGImage];
        CGImageRelease(rotatedCGImage);
    } else {
        imageRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    }
    if (scale < 1) {
        scale = 1;
    }
    CGFloat pixelWidth = imageRep.pixelsWide;
    CGFloat pixelHeight = imageRep.pixelsHigh;
    NSSize size = NSMakeSize(pixelWidth / scale, pixelHeight / scale);
    self = [self initWithSize:size];
    if (self) {
        imageRep.size = size;
        [self addRepresentation:imageRep];
    }
    return self;
}

- (instancetype)initWithData:(nonnull NSData *)data scale:(CGFloat)scale {
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:data];
    if (!imageRep) {
        return nil;
    }
    if (scale < 1) {
        scale = 1;
    }
    CGFloat pixelWidth = imageRep.pixelsWide;
    CGFloat pixelHeight = imageRep.pixelsHigh;
    NSSize size = NSMakeSize(pixelWidth / scale, pixelHeight / scale);
    self = [self initWithSize:size];
    if (self) {
        imageRep.size = size;
        [self addRepresentation:imageRep];
    }
    return self;
}

@end
#endif


#pragma mark - JSTPixelImage

NS_INLINE JST_IMAGE *JSTCreatePixelImageWithCGImage(CGImageRef cgimg, CGColorSpaceRef *cgColorSpace)
{
    CGSize imgSize = CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg));
    
    JST_IMAGE *newPixelImage = (JST_IMAGE *)malloc(sizeof(JST_IMAGE));
    bzero(newPixelImage, sizeof(JST_IMAGE));
    newPixelImage->width = imgSize.width;
    newPixelImage->alignedWidth = imgSize.width;
    newPixelImage->height = imgSize.height;
    
    /* New pixel image is not aligned */
    size_t pixelsSize = imgSize.width * imgSize.height * sizeof(JST_COLOR);
    JST_COLOR *pixels = (JST_COLOR *)malloc(pixelsSize);
    bzero(pixels, pixelsSize);
    newPixelImage->pixels = pixels;
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgimg);
    if (colorSpace) {
        *cgColorSpace = (CGColorSpaceRef)CFRetain(colorSpace);
    } else {
        *cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    }
    
    CGContextRef context = CGBitmapContextCreate(
        pixels,
        (size_t) imgSize.width,
        (size_t) imgSize.height,
        sizeof(JST_COLOR_COMPONENT_TYPE) * BYTE_SIZE,
        imgSize.width * sizeof(JST_COLOR),
        *cgColorSpace,
        kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst  /* kCGImageAlphaNoneSkipFirst */
    );
    
    CGContextDrawImage(context, CGRectMake(0, 0, imgSize.width, imgSize.height), cgimg);
    CGContextRelease(context);
    return newPixelImage;
}

#if TARGET_OS_IPHONE
NS_INLINE JST_IMAGE *JSTCreatePixelImageWithUIImage(UIImage *uiimg, CGColorSpaceRef *cgColorSpace)
{
    return JSTCreatePixelImageWithCGImage(uiimg.CGImage, cgColorSpace);
}
#else
NS_INLINE JST_IMAGE *JSTCreatePixelImageWithNSImage(NSImage *nsimg, CGColorSpaceRef *cgColorSpace)
{
    CGSize imgSize = nsimg.size;
    CGRect imgRect = CGRectMake(0, 0, imgSize.width, imgSize.height);
    return JSTCreatePixelImageWithCGImage([nsimg CGImageForProposedRect:&imgRect context:nil hints:nil], cgColorSpace);
}
#endif


#define SHIFT_XY_BY_ORIEN_NOM1(X, Y, W, H, O) \
    { \
        switch (O) { \
            int Z; \
        case 0: \
            break; \
        case 1: \
            (Z) = (X); \
            (X) = (W) -(Y); \
            (Y) = (Z); \
            break; \
        case 2: \
            (Z) = (Y); \
            (Y) = (H) -(X); \
            (X) = (Z); \
            break; \
        case 3: \
            (X) = (W) -(X); \
            (Y) = (H) -(Y); \
            break; \
        } \
    }

#define SHIFT_XY_BY_ORIEN(X, Y, W, H, O) SHIFT_XY_BY_ORIEN_NOM1((X), (Y), ((W)-1), ((H)-1), (O))

#define UNSHIFT_XY_BY_ORIEN_NOM1(X, Y, W, H, O) \
    { \
        switch (O) { \
            int Z; \
        case 0: \
            break; \
        case 1: \
            (Z) = (Y); \
            (Y) = (W) -(X); \
            (X) = (Z); \
            break; \
        case 2: \
            (Z) = (X); \
            (X) = (H) -(Y); \
            (Y) = (Z); \
            break; \
        case 3: \
            (X) = (W) -(X); \
            (Y) = (H) -(Y); \
            break; \
        } \
    }

#define UNSHIFT_XY_BY_ORIEN(X, Y, W, H, O) UNSHIFT_XY_BY_ORIEN_NOM1((X), (Y), ((W)-1), ((H)-1), (O))

#define SHIFT_RECT_BY_ORIEN_NOM1(X1, Y1, X2, Y2, W, H, O) \
    { \
        int Z; \
        SHIFT_XY_BY_ORIEN_NOM1((X1), (Y1), (W), (H), (O)); \
        SHIFT_XY_BY_ORIEN_NOM1((X2), (Y2), (W), (H), (O)); \
        if ((X1) > (X2)) { \
            (Z) = (X1); \
            (X1) = (X2); \
            (X2) = (Z); \
        } \
        if ((Y1) > (Y2)) { \
            (Z) = (Y1); \
            (Y1) = (Y2); \
            (Y2) = (Z); \
        } \
    }

#define SHIFT_RECT_BY_ORIEN(X1, Y1, X2, Y2, W, H, O) SHIFT_RECT_BY_ORIEN_NOM1((X1), (Y1), (X2), (Y2), (W - 1), (H - 1), (O))

#define UNSHIFT_RECT_BY_ORIEN_NOM1(X1, Y1, X2, Y2, W, H, O) \
    { \
        int Z; \
        UNSHIFT_XY_BY_ORIEN_NOM1((X1), (Y1), (W), (H), (O)); \
        UNSHIFT_XY_BY_ORIEN_NOM1((X2), (Y2), (W), (H), (O)); \
        if ((X1) > (X2)) { \
            (Z) = (X1); \
            (X1) = (X2); \
            (X2) = (Z); \
        } \
        if ((Y1) > (Y2)) { \
            (Z) = (Y1); \
            (Y1) = (Y2); \
            (Y2) = (Z); \
        } \
    }

#define UNSHIFT_RECT_BY_ORIEN(X1, Y1, X2, Y2, W, H, O) UNSHIFT_RECT_BY_ORIEN_NOM1((X1), (Y1), (X2), (Y2), (W - 1), (H - 1), (O))

#define GET_ROTATE_ROTATE(OO, FO, OUTO) \
    { \
        switch (FO) { \
        case 1: \
            switch (OO) { \
            case 0: \
                (OUTO) = 1; \
                break; \
            case 1: \
                (OUTO) = 3; \
                break; \
            case 2: \
                (OUTO) = 0; \
                break; \
            case 3: \
                (OUTO) = 2; \
                break; \
            } \
            break; \
        case 2: \
            switch (OO) { \
            case 0: \
                (OUTO) = 2; \
                break; \
            case 1: \
                (OUTO) = 0; \
                break; \
            case 2: \
                (OUTO) = 3; \
                break; \
            case 3: \
                (OUTO) = 1; \
                break; \
            } \
            break; \
        case 3: \
            switch (OO) { \
            case 0: \
                (OUTO) = 3; \
                break; \
            case 1: \
                (OUTO) = 2; \
                break; \
            case 2: \
                (OUTO) = 1; \
                break; \
            case 3: \
                (OUTO) = 0; \
                break; \
            } \
            break; \
        case 0: \
            (OUTO) = OO; \
        } \
    }

#define GET_ROTATE_ROTATE2(OO, FO) GET_ROTATE_ROTATE((OO), (FO), (OO))

#define GET_ROTATE_ROTATE3 GET_ROTATE_ROTATE

FOUNDATION_EXTERN_INLINE void JSTGetColorInPixelImageSafe(JST_IMAGE *pixelImage, int x, int y, JST_COLOR *colorOfPoint)
{
    SHIFT_XY_BY_ORIEN(x, y, pixelImage->width, pixelImage->height, pixelImage->orientation);
    if (x >= pixelImage->width ||
        y >= pixelImage->height)
    {
        colorOfPoint->theColor = 0;
        return;
    }
    colorOfPoint->theColor = pixelImage->pixels[y * pixelImage->alignedWidth + x].theColor;
}

NS_INLINE void JSTGetColorInPixelImageUnsafe(JST_IMAGE *pixels_image, int x, int y, JST_COLOR *color_of_point)
{
    SHIFT_XY_BY_ORIEN(x, y, pixels_image->width, pixels_image->height, pixels_image->orientation);
    color_of_point->theColor = pixels_image->pixels[y * pixels_image->alignedWidth + x].theColor;
}

FOUNDATION_EXTERN_INLINE void JSTSetColorInPixelImageSafe(JST_IMAGE *pixels_image, int x, int y, JST_COLOR *color_of_point)
{
    SHIFT_XY_BY_ORIEN(x, y, pixels_image->width, pixels_image->height, pixels_image->orientation);
    if (x >= pixels_image->width ||
        y >= pixels_image->height)
    {
        return;
    }
    pixels_image->pixels[y * pixels_image->alignedWidth + x].theColor = color_of_point->theColor;
}

NS_INLINE CGImageRef JSTCreateCGImageWithPixelImage(JST_IMAGE *pixelImage, CGColorSpaceRef cgColorSpace)
{
    int width, height;
    switch (pixelImage->orientation) {
    case 1:
    case 2:
        height = pixelImage->width;
        width = pixelImage->height;
        break;
    default:
        width = pixelImage->width;
        height = pixelImage->height;
        break;
    }
    
    /* CGImage is not aligned */
    size_t pixelsBufferLength = (size_t)(width * height * sizeof(JST_COLOR));
    JST_COLOR *pixelsBuffer = (JST_COLOR *)malloc(pixelsBufferLength);
    if (0 == pixelImage->orientation && pixelImage->width == pixelImage->alignedWidth) {
        memcpy(pixelsBuffer, pixelImage->pixels, pixelsBufferLength);
    } else {
        uint64_t bigCountOffset = 0;
        JST_COLOR colorOfPoint;
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                JSTGetColorInPixelImageUnsafe(pixelImage, x, y, &colorOfPoint);
                pixelsBuffer[bigCountOffset++].theColor = colorOfPoint.theColor;
            }
        }
    }
    
    CFDataRef imageData = CFDataCreateWithBytesNoCopy(kCFAllocatorMalloc, (const UInt8 *)pixelsBuffer, pixelsBufferLength, kCFAllocatorMalloc);
    CGDataProviderRef imageDataProvider = CGDataProviderCreateWithCFData(imageData);
    
    CGImageRef cgImage = CGImageCreate(
                                   (size_t)width, (size_t)height,
                                   sizeof(JST_COLOR_COMPONENT_TYPE) * BYTE_SIZE,
                                   sizeof(JST_COLOR_COMPONENT_TYPE) * BYTE_SIZE * JST_COLOR_COMPONENTS_PER_ELEMENT,
                                   JST_COLOR_COMPONENTS_PER_ELEMENT * width, cgColorSpace,
                                   kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst,
                                   imageDataProvider, NULL, YES, kCGRenderingIntentDefault
                                   );
    
    CGDataProviderRelease(imageDataProvider);
    CFRelease(imageData);
    
    return cgImage;
}

NS_INLINE JST_IMAGE *JSTCreatePixelImageWithPixelImageInRect(JST_IMAGE *pixelImage, JST_ORIENTATION orientation, int x1, int y1, int x2, int y2)
{
    int oldAlignedWidth = pixelImage->alignedWidth;
    int newWidth = x2 - x1;
    int newHeight = y2 - y1;
    
    JST_IMAGE *newPixelImage = (JST_IMAGE *)malloc(sizeof(JST_IMAGE));
    bzero(newPixelImage, sizeof(JST_IMAGE));
    newPixelImage->width = newWidth;
    newPixelImage->alignedWidth = newWidth;
    newPixelImage->height = newHeight;
    
    /* New pixel image is not aligned */
    size_t newPixelsSize = newWidth * newHeight * sizeof(JST_COLOR);
    JST_COLOR *newPixels = (JST_COLOR *)malloc(newPixelsSize);
    bzero(newPixels, newPixelsSize);
    newPixelImage->pixels = newPixels;
    
    uint64_t bigCountOffset = 0;
    for (int y = y1; y < y2; ++y) {
        for (int x = x1; x < x2; ++x) {
            newPixels[bigCountOffset++] = pixelImage->pixels[y * oldAlignedWidth + x];
        }
    }
    
    GET_ROTATE_ROTATE3(pixelImage->orientation, orientation, newPixelImage->orientation);
    return newPixelImage;
}

NS_INLINE void JSTFreePixelImage(JST_IMAGE *pixelImage) {
    if (!pixelImage->isDestroyed) {
        free(pixelImage->pixels);
        pixelImage->isDestroyed = true;
    }
    free(pixelImage);
}

@implementation JSTPixelImage

- (JSTPixelImage *)initWithInternalPointer:(JST_IMAGE *)pointer colorSpace:(CGColorSpaceRef)colorSpace {
    self = [super init];
    if (self) {
        _pixelImage = pointer;
        _colorSpace = CGColorSpaceRetain(colorSpace);
    }
    return self;
}

- (JSTPixelImage *)initWithCompatibleScreenSurface:(IOSurfaceRef)surface colorSpace:(CGColorSpaceRef)colorSpace {
    self = [super init];
    if (self) {
        
        _pixelImage = (JST_IMAGE *)malloc(sizeof(JST_IMAGE));
        bzero(_pixelImage, sizeof(JST_IMAGE));
        
        size_t width = IOSurfaceGetWidth(surface);
        size_t height = IOSurfaceGetHeight(surface);
        
        OSType pixelFormat = IOSurfaceGetPixelFormat(surface);
        NSAssert(pixelFormat == 0x42475241 || pixelFormat == 0x0  /* Not Specified */,
                 @"pixel format not supported 0x%x", pixelFormat);
        
        size_t bytesPerElement = IOSurfaceGetBytesPerElement(surface);
        NSAssert(bytesPerElement == sizeof(JST_COLOR),
                 @"bpc not supported %ld", bytesPerElement);
        
        size_t bytesPerRow = IOSurfaceGetBytesPerRow(surface);
        NSAssert(bytesPerRow == width * sizeof(JST_COLOR) || (bytesPerRow > width * sizeof(JST_COLOR) && bytesPerRow % 32 == 0),
                 @"bpr not aligned %ld", bytesPerRow);
        
        /* Pixel image from IOSurface is aligned */
        size_t alignedWidth = bytesPerRow / sizeof(JST_COLOR);
        void *pixels = IOSurfaceGetBaseAddress(surface);
        
        _pixelImage->width = (int)width;
        _pixelImage->alignedWidth = (int)alignedWidth;
        _pixelImage->height = (int)height;
        _pixelImage->pixels = pixels;
        _pixelImage->isDestroyed = true;
        
        _colorSpace = CGColorSpaceRetain(colorSpace);
    }
    return self;
}

- (JSTPixelImage *)initWithCGImage:(CGImageRef)cgimage {
    self = [super init];
    if (self) {
        _pixelImage = JSTCreatePixelImageWithCGImage(cgimage, &_colorSpace);
    }
    return self;
}

+ (JSTPixelImage *)imageWithSystemImage:(SystemImage *)systemImage {
    return [[JSTPixelImage alloc] initWithSystemImage:systemImage];
}

- (JSTPixelImage *)initWithSystemImage:(SystemImage *)systemImage {
    self = [super init];
    if (self) {
#if TARGET_OS_IPHONE
        _pixelImage = JSTCreatePixelImageWithUIImage(systemImage, &_colorSpace);
#else
        _pixelImage = JSTCreatePixelImageWithNSImage(systemImage, &_colorSpace);
#endif
    }
    return self;
}

- (SystemImage *)toSystemImage {
    CGImageRef cgimg = JSTCreateCGImageWithPixelImage(_pixelImage, _colorSpace);
#if TARGET_OS_IPHONE
    UIImage *img0 = [UIImage imageWithCGImage:cgimg];
#else
    NSImage *img0 = [[NSImage alloc] initWithCGImage:cgimg scale:1.0 orientation:kCGImagePropertyOrientationUp];
#endif
    CGImageRelease(cgimg);
    return img0;
}

- (NSData *)pngRepresentation {
    CGImageRef cgimg = JSTCreateCGImageWithPixelImage(_pixelImage, _colorSpace);
#if TARGET_OS_IPHONE
    NSData *data = UIImagePNGRepresentation([UIImage imageWithCGImage:cgimg]);
#else
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgimg];
    [newRep setSize:CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg))];
    NSData *data = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
#endif
    CGImageRelease(cgimg);
    return data;
}

#if TARGET_OS_IPHONE
- (NSData *)jpegRepresentationWithCompressionQuality:(CGFloat)compressionQuality {
    CGImageRef cgimg = JSTCreateCGImageWithPixelImage(_pixelImage, _colorSpace);
    NSData *data = UIImageJPEGRepresentation([UIImage imageWithCGImage:cgimg], compressionQuality);
    CGImageRelease(cgimg);
    return data;
}
#else
- (NSData *)tiffRepresentation {
    CGImageRef cgimg = JSTCreateCGImageWithPixelImage(_pixelImage, _colorSpace);
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgimg];
    [newRep setSize:CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg))];
    NSData *data = [newRep representationUsingType:NSBitmapImageFileTypeTIFF properties:@{}];
    CGImageRelease(cgimg);
    return data;
}
#endif

- (JSTPixelImage *)crop:(CGRect)rect {
    int x1 = (int) rect.origin.x;
    int y1 = (int) rect.origin.y;
    int x2 = (int) rect.origin.x + (int) rect.size.width;
    int y2 = (int) rect.origin.y + (int) rect.size.height;
    SHIFT_RECT_BY_ORIEN(x1, y1, x2, y2, _pixelImage->width, _pixelImage->height, _pixelImage->orientation);
    y2 = (y2 > _pixelImage->height) ? _pixelImage->height : y2;
    x2 = (x2 > _pixelImage->width) ? _pixelImage->width : x2;
    return [[JSTPixelImage alloc] initWithInternalPointer:JSTCreatePixelImageWithPixelImageInRect(_pixelImage, 0, x1, y1, x2, y2) colorSpace:_colorSpace];
}

- (CGSize)orientedSize {
    int width = 0, height = 0;
    switch (_pixelImage->orientation) {
    case 1:
    case 2:
        height = _pixelImage->width;
        width = _pixelImage->height;
        break;
    default:
        width = _pixelImage->width;
        height = _pixelImage->height;
        break;
    }
    return CGSizeMake(width, height);
}

- (JST_IMAGE *)internalPointer {
    return _pixelImage;
}

- (JSTPixelColor *)getJSTColorOfPoint:(CGPoint)point {
    JST_COLOR colorOfPoint;
    JSTGetColorInPixelImageSafe(_pixelImage, (int) point.x, (int) point.y, &colorOfPoint);
    return [JSTPixelColor colorWithRed:colorOfPoint.red green:colorOfPoint.green blue:colorOfPoint.blue alpha:colorOfPoint.alpha];
}

- (JST_COLOR_TYPE)getColorOfPoint:(CGPoint)point {
    JST_COLOR colorOfPoint;
    JSTGetColorInPixelImageSafe(_pixelImage, (int) point.x, (int) point.y, &colorOfPoint);
    return colorOfPoint.theColor;
}

- (NSString *)getColorHexOfPoint:(CGPoint)point {
    JST_COLOR colorOfPoint;
    JSTGetColorInPixelImageSafe(_pixelImage, (int) point.x, (int) point.y, &colorOfPoint);
    return [[JSTPixelColor colorWithRed:colorOfPoint.red green:colorOfPoint.green blue:colorOfPoint.blue alpha:colorOfPoint.alpha] hexString];
}

- (void)setJSTColor:(JSTPixelColor *)color ofPoint:(CGPoint)point {
    JST_COLOR colorOfPoint;
    colorOfPoint.red = color.red;
    colorOfPoint.green = color.green;
    colorOfPoint.blue = color.blue;
    colorOfPoint.alpha = 0xff;
    JSTSetColorInPixelImageSafe(_pixelImage, (int) point.x, (int) point.y, &colorOfPoint);
}

- (void)setColor:(JST_COLOR_TYPE)color ofPoint:(CGPoint)point {
    JST_COLOR colorOfPoint;
    colorOfPoint.theColor = color;
    JSTSetColorInPixelImageSafe(_pixelImage, (int) point.x, (int) point.y, &colorOfPoint);
}

- (void)setOrientation:(JST_ORIENTATION)orientation {
    _pixelImage->orientation = orientation;
}

- (JST_ORIENTATION)orientation {
    return _pixelImage->orientation;
}

- (void)dealloc {
    JSTFreePixelImage(_pixelImage);
    CGColorSpaceRelease(_colorSpace);
    CHDebugLog(@"- [JSTPixelImage dealloc]");
}

- (id)copyWithZone:(NSZone *)zone {
    
    JST_IMAGE *newImage = (JST_IMAGE *)malloc(sizeof(JST_IMAGE));
    memcpy(newImage, _pixelImage, sizeof(JST_IMAGE));
    
    /* Copied pixel image has the same alignment with the original ones */
    size_t pixelSize = newImage->alignedWidth * newImage->height * sizeof(JST_COLOR);
    JST_COLOR *pixels = (JST_COLOR *)malloc(pixelSize);
    
    memcpy(pixels, newImage->pixels, pixelSize);
    
    newImage->pixels = pixels;
    newImage->isDestroyed = NO;
    
    return [[JSTPixelImage alloc] initWithInternalPointer:newImage colorSpace:_colorSpace];
}

- (CGRect)orientedBounds {
    CGSize orientSize = [self orientedSize];
    return CGRectMake(0, 0, orientSize.width, orientSize.height);
}

- (BOOL)containsOrientedPoint:(CGPoint)orientedPoint {
    return CGRectContainsPoint([self orientedBounds], orientedPoint);
}

@end
