//
//  ScreenCaptureOpenCVWrapper.mm
//  screen
//
//  Created by Lessica on 2022/6/7.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "ScreenCaptureOpenCVWrapper.h"
#import <opencv2/opencv.hpp>
#import "UIImage+OpenCV.h"

@implementation ScreenCaptureOpenCVWrapper

+ (cv::Mat)cvMatWithSystemImageRedraw:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;

    cv::Mat cvMat(rows, cols, CV_8UC4);  // 8 bits per component, 4 channels

    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to backing data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGBitmapByteOrder32Host |  // Bitmap info flags
                                                    kCGImageAlphaNoneSkipLast);

    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);

    return cvMat;
}

+ (cv::Mat)cvMatWithPixelImageNoCopy:(JSTPixelImage *)pixelImage
{
    JST_IMAGE *rawImage = [pixelImage internalPointer];
    return cv::Mat(
                   cv::Size(
                            rawImage->width,
                            rawImage->height
                            ),
                   CV_8UC4,
                   rawImage->pixels,
                   rawImage->alignedWidth * sizeof(JST_COLOR)
                   );
}

+ (CGPoint)matchTemplateWithSourceImage:(JSTPixelImage *)sourceImage
                          templateImage:(JSTPixelImage *)templateImage
                             similarity:(CGFloat *)outSimilarity
{
    @autoreleasepool {
        cv::Mat srcImage = [ScreenCaptureOpenCVWrapper cvMatWithPixelImageNoCopy:sourceImage];
        cv::Mat tmplImage = [ScreenCaptureOpenCVWrapper cvMatWithPixelImageNoCopy:templateImage];
        
        cv::Mat matchedImage;
        cv::matchTemplate(srcImage, tmplImage, matchedImage, cv::TM_CCOEFF_NORMED);
        
        CGFloat maxVal;
        cv::Point maxLoc;
        cv::minMaxLoc(matchedImage, NULL, &maxVal, NULL, &maxLoc);
        
        srcImage.release();
        tmplImage.release();
        
        *outSimilarity = maxVal;
        return CGPointMake(maxLoc.x, maxLoc.y);
    }
}

+ (CGPoint)matchTemplateWithSourceImage:(JSTPixelImage *)sourceImage
                          templateImage:(JSTPixelImage *)templateImage
{
    CGFloat similarity;
    return [ScreenCaptureOpenCVWrapper matchTemplateWithSourceImage:sourceImage templateImage:templateImage similarity:&similarity];
}

+ (CGRect)multiscaleMatchTemplateWithSourceImage:(JSTPixelImage *)sourceImage
                                   templateImage:(JSTPixelImage *)templateImage
                                targetSimilarity:(CGFloat)targetSimilarity
                                      similarity:(CGFloat *)outSimilarity
{
    @autoreleasepool {
        
        /// load the image image, convert it to grayscale, and detect edges
        cv::Mat tmplImage = [ScreenCaptureOpenCVWrapper cvMatWithPixelImageNoCopy:templateImage];
        cv::Mat grayTemplate, cannyTemplate;
        cv::cvtColor(tmplImage, grayTemplate, cv::COLOR_BGR2GRAY);
        cv::Canny(grayTemplate, cannyTemplate, 50, 200);
        
        CGFloat tmplHeight = tmplImage.size().height;
        CGFloat tmplWidth = tmplImage.size().width;
        
        /// load the image, convert it to grayscale, and initialize the
        /// bookkeeping variable to keep track of the matched region
        cv::Mat srcImage = [ScreenCaptureOpenCVWrapper cvMatWithPixelImageNoCopy:sourceImage];
        cv::Mat graySource;
        cv::cvtColor(srcImage, graySource, cv::COLOR_BGR2GRAY);
        
        NSArray <NSNumber *> *found = nil;
        
        /// loop over the scales of the image
        CGFloat ratio;
        NSUInteger loopTimes = 0;
        for (CGFloat scale = 1.0; scale > 0.2; scale -= 0.04) {
            
            /// resize the image according to the scale, and keep track
            /// of the ratio of the resizing
            cv::Mat resized;
            cv::Size dstSize
            (
             (int)round(graySource.size().width * scale),
             (int)round(graySource.size().height * scale)
             );
            cv::resize(graySource, resized, dstSize);
            ratio = graySource.size().width / resized.size().width;
            
            CHDebugLogSource(@"round #%lu: try scale %.2f width %d height %d", (unsigned long)loopTimes, scale, dstSize.width, dstSize.height);
            
            /// if the resized image is smaller than the template, then break
            /// from the loop
            if (resized.size().height < tmplHeight || resized.size().width < tmplWidth) {
                resized.release();
                break;
            }
            
            /// detect edges in the resized, grayscale image and apply template
            /// matching to find the template in the image
            cv::Mat edged;
            cv::Canny(resized, edged, 50, 200);
            
            cv::Mat result;
            cv::matchTemplate(edged, cannyTemplate, result, cv::TM_CCOEFF_NORMED);
            
            CGFloat maxVal;
            cv::Point maxLoc;
            cv::minMaxLoc(result, NULL, &maxVal, NULL, &maxLoc);
            
            CHDebugLogSource(@"round #%lu: match similarity %.2f x %d y %d", (unsigned long)loopTimes, maxVal, maxLoc.x, maxLoc.y);
            
            /// if we have found a new maximum correlation value, then ipdate
            /// the bookkeeping variable
            if (!found || maxVal > [found[0] doubleValue]) {
                found = @[@(maxVal), @(maxLoc.x), @(maxLoc.y), @(ratio)];
            }
            
            resized.release();
            edged.release();
            result.release();
            
            /// target similarity satisfied, break from the loop
            if (maxVal > targetSimilarity) {
                break;
            }
            
            loopTimes++;
        }
        
        tmplImage.release();
        grayTemplate.release();
        cannyTemplate.release();
        srcImage.release();
        graySource.release();
        
        if (found.count != 4) {
            return CGRectNull;
        }
        
        CGFloat maxVal = [found[0] doubleValue];
        *outSimilarity = maxVal;
        
        CGPoint maxLoc = CGPointMake([found[1] doubleValue], [found[2] doubleValue]);
        CGFloat bestRatio = [found[3] doubleValue];
        CGFloat startX = maxLoc.x * bestRatio, startY = maxLoc.y * bestRatio;
        CGFloat endX = (maxLoc.x + tmplWidth) * bestRatio, endY = (maxLoc.y + tmplHeight) * bestRatio;
        
        return CGRectMake(startX, startY, endX - startX, endY - startY);
    }
}

+ (void)performBinarizationToImage:(JSTPixelImage *)inputImage
                         threshold:(CGFloat)threshold
{
    @autoreleasepool {
        cv::Mat srcImage = [ScreenCaptureOpenCVWrapper cvMatWithPixelImageNoCopy:inputImage];
        cv::Mat grayImage;
        cv::cvtColor(srcImage, grayImage, cv::COLOR_BGR2GRAY);
        cv::Mat binaryImage;
        cv::threshold(grayImage, binaryImage, MAX(MIN(threshold, 255), 0), 255, cv::THRESH_BINARY);
        cv::cvtColor(binaryImage, srcImage, cv::COLOR_GRAY2BGRA);
        
        binaryImage.release();
        grayImage.release();
        srcImage.release();
    }
}

+ (JSTPixelImage *)resizeImage:(JSTPixelImage *)sourceImage toSize:(CGSize)newSize
{
    @autoreleasepool {
        cv::Mat srcImage = [ScreenCaptureOpenCVWrapper cvMatWithPixelImageNoCopy:sourceImage];
        
        cv::Mat resized;
        cv::Size dstSize
        (
         (int)round(newSize.width),
         (int)round(newSize.height)
         );
        cv::resize(srcImage, resized, dstSize);
        
        UIImage *systemImage = [UIImage imageWithCVMat:resized colorSpace:sourceImage.colorSpace];
        return [[JSTPixelImage alloc] initWithSystemImage:systemImage];
    }
}

@end
