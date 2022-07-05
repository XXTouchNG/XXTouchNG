//
//  UIImage+OpenCV.h
//  JSTColorPicker
//
//  Created by Darwin on 5/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/opencv.hpp>


NS_ASSUME_NONNULL_BEGIN

@interface UIImage (OpenCV)

/// DeviceRGB, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host
+ (UIImage *)imageWithCVMat:(const cv::Mat &)cvMat;

/// kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host
+ (UIImage *)imageWithCVMat:(const cv::Mat &)cvMat colorSpace:(CGColorSpaceRef)colorSpace;

/// Customized cv::Mat
+ (UIImage *)imageWithCVMat:(const cv::Mat &)cvMat colorSpace:(CGColorSpaceRef)colorSpace bitmapInfo:(CGBitmapInfo)bitmapInfo;

/// Alpha channel is skipped
@property (nonatomic, readonly) cv::Mat CVMat;
@property (nonatomic, readonly) cv::Mat CVGrayscaleMat;

@end

NS_ASSUME_NONNULL_END

