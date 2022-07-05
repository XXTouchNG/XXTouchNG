//
//  ScreenCaptureOpenCVWrapper.h
//  screen
//
//  Created by Lessica on 2022/6/7.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import "JSTPixelImage.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScreenCaptureOpenCVWrapper : NSObject

+ (CGPoint)matchTemplateWithSourceImage:(JSTPixelImage *)sourceImage
                          templateImage:(JSTPixelImage *)templateImage
                             similarity:(double *)outSimilarity;

+ (CGRect)multiscaleMatchTemplateWithSourceImage:(JSTPixelImage *)sourceImage
                                   templateImage:(JSTPixelImage *)templateImage
                                targetSimilarity:(CGFloat)targetSimilarity
                                      similarity:(CGFloat *)outSimilarity;

+ (void)performBinarizationToImage:(JSTPixelImage *)inputImage
                         threshold:(CGFloat)threshold;

+ (JSTPixelImage *)resizeImage:(JSTPixelImage *)sourceImage toSize:(CGSize)newSize;

@end

NS_ASSUME_NONNULL_END
