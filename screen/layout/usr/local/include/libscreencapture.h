//
//  ScreenCapture.h
//  ScreenCapture
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#ifndef ScreenCapture_h
#define ScreenCapture_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

#import "JSTPixelImage.h"


typedef NS_ENUM(NSUInteger, ScreenCaptureRole) {
    ScreenCaptureRoleClient = 0,
    ScreenCaptureRoleServer,
};

@interface ScreenCapture : NSObject

@property (nonatomic, assign, readonly) ScreenCaptureRole role;
@property (nonatomic, strong, readonly) JSTPixelImage *pixelImage;
@property (nonatomic, assign, readonly) uint32_t seed;

+ (instancetype)sharedCapture;
+ (NSDictionary *)sharedRenderProperties;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (void)updateDisplay;
- (void)updateDisplayWithoutTransfer;

/* Photos Proxy */
- (NSDictionary *)performSavePhotoToAlbumRequestWithData:(NSData *)data timeout:(NSTimeInterval)timeout;

/* Vision Proxy */
- (NSDictionary *)performRecognizeTextRequestInRect:(CGRect)rect
                                      toOrientation:(NSInteger)orientation
                                   recognitionLevel:(NSInteger)level
                                            timeout:(NSTimeInterval)timeout;

/* Vision Proxy */
- (NSDictionary *)performDetectBarcodesRequestInRect:(CGRect)rect
                                       toOrientation:(NSInteger)orientation
                                             timeout:(NSTimeInterval)timeout;

/* Vision Proxy */
- (NSDictionary *)performRecognizeTextRequestWithData:(NSData *)data
                                     recognitionLevel:(NSInteger)level
                                              timeout:(NSTimeInterval)timeout;

/* Vision Proxy */
- (NSDictionary *)performDetectBarcodesRequestWithData:(NSData *)data
                                               timeout:(NSTimeInterval)timeout;

/* Graphic Proxy */
- (JSTPixelImage *)performQuickResponseImageGeneratingRequestWithPayload:(NSString *)payload
                                                             fittingSize:(CGSize)size
                                                               fillColor:(JSTPixelColor *)fillColor
                                                         backgroundColor:(JSTPixelColor *)backgroundColor;

@end

#endif  /* ScreenCapture_h */
