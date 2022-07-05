//
//  UIImage+OpenCV.m
//  JSTColorPicker
//
//  Created by Darwin on 5/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "UIImage+OpenCV.h"


//static void ProviderReleaseDataNOP(void *info, const void *data, size_t size) { return; }

@implementation UIImage (OpenCV)

- (CGImageRef)copyOpenCVCGImage
{
    if ([self CGImage]) {
        return CGImageRetain([self CGImage]);
    }
    
    UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    CGImageRef cgImage = CGBitmapContextCreateImage(UIGraphicsGetCurrentContext());
    UIGraphicsEndImageContext();
    
    return cgImage;
}

- (cv::Mat)CVMat
{
    CGImageRef imageRef = [self copyOpenCVCGImage];
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageRef);
    CGFloat cols = self.size.width;
    CGFloat rows = self.size.height;
    cv::Mat cvMat(rows, cols, CV_8UC4);  // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                  // Pointer to backing data
                                                    cols,                        // Width of bitmap
                                                    rows,                        // Height of bitmap
                                                    8,                           // Bits per component
                                                    cvMat.step[0],               // Bytes per row
                                                    colorSpace,                  // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrder32Host);   // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), imageRef);
    CGContextRelease(contextRef);
    CGImageRelease(imageRef);
    return cvMat;
}

- (cv::Mat)CVGrayscaleMat
{
    CGImageRef imageRef = [self copyOpenCVCGImage];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGFloat cols = self.size.width;
    CGFloat rows = self.size.height;
    cv::Mat cvMat = cv::Mat(rows, cols, CV_8UC1);  // 8 bits per component, 1 channel
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                  // Pointer to backing data
                                                    cols,                        // Width of bitmap
                                                    rows,                        // Height of bitmap
                                                    8,                           // Bits per component
                                                    cvMat.step[0],               // Bytes per row
                                                    colorSpace,                  // Colorspace
                                                    kCGImageAlphaNone |
                                                    kCGBitmapByteOrder32Host);   // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), imageRef);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageRef);
    return cvMat;
}

+ (UIImage *)imageWithCVMat:(const cv::Mat &)cvMat
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    UIImage *image = [[UIImage alloc] initWithCVMat:cvMat colorSpace:colorSpace bitmapInfo:kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host];
    CGColorSpaceRelease(colorSpace);
    return image;
}

+ (UIImage *)imageWithCVMat:(const cv::Mat &)cvMat colorSpace:(CGColorSpaceRef)colorSpace
{
    return [[UIImage alloc] initWithCVMat:cvMat colorSpace:colorSpace bitmapInfo:kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host];
}

+ (UIImage *)imageWithCVMat:(const cv::Mat &)cvMat colorSpace:(CGColorSpaceRef)colorSpace bitmapInfo:(CGBitmapInfo)bitmapInfo
{
    return [[UIImage alloc] initWithCVMat:cvMat colorSpace:colorSpace bitmapInfo:bitmapInfo];
}

- (instancetype)initWithCVMat:(const cv::Mat &)cvMat colorSpace:(CGColorSpaceRef)colorSpace bitmapInfo:(CGBitmapInfo)bitmapInfo
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize() * cvMat.total()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                     // Width
                                        cvMat.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * cvMat.elemSize(),                           // Bits per pixel
                                        cvMat.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Color space
                                        bitmapInfo,                                     // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    self = [self initWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    
    return self;
}

@end

