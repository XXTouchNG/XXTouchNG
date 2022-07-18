//
//  ScreenCapture.m
//  ScreenCapture
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "ScreenCapture.h"
#import <UIKit/UIDevice.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIGeometry.h>
#import <UIKit/UIScreen.h>
#import <Vision/Vision.h>
#import <Photos/Photos.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

#import "JSTPixelImage+Private.h"
#import "JSTPixelColor.h"


#pragma mark -

OBJC_EXTERN UIImage *_UICreateScreenUIImage(void);
OBJC_EXTERN CGImageRef UICreateCGImageFromIOSurface(IOSurfaceRef ioSurface);
OBJC_EXTERN void CARenderServerRenderDisplay(kern_return_t a, CFStringRef b, IOSurfaceRef surface, int x, int y);


#pragma mark -

@interface ScreenCapture (Private)

+ (instancetype)sharedCaptureWithRole:(ScreenCaptureRole)role;
- (instancetype)initWithRole:(ScreenCaptureRole)role;

@property (nonatomic, strong) CPDistributedMessagingCenter *messagingCenter;

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSDictionary *)receiveAndReplyMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;

@end


#pragma mark -

@implementation ScreenCapture {
    IOSurfaceRef _screenSurface;
    CPDistributedMessagingCenter *_messagingCenter;
}

@synthesize pixelImage = _pixelImage;

+ (instancetype)sharedCapture {
    return [self sharedCaptureWithRole:ScreenCaptureRoleClient];
}

+ (instancetype)sharedCaptureWithRole:(ScreenCaptureRole)role {
    static ScreenCapture *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[ScreenCapture alloc] initWithRole:role];
    });
    return _server;
}

- (instancetype)initWithRole:(ScreenCaptureRole)role {
    self = [super init];
    if (self) {
        _role = role;
    }
    return self;
}

- (CPDistributedMessagingCenter *)messagingCenter {
    return _messagingCenter;
}

- (void)setMessagingCenter:(CPDistributedMessagingCenter *)messagingCenter {
    _messagingCenter = messagingCenter;
}

+ (NSDictionary *)sharedRenderProperties
{
    static NSDictionary *properties = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        CGRect screenRect = [[UIScreen mainScreen] nativeBounds];
        
        // Setup the width and height of the framebuffer for the device
        int width, height;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            // iPhone frame buffer is Portrait
            width = screenRect.size.width;
            height = screenRect.size.height;
        } else {
            // iPad frame buffer is Landscape
            width = screenRect.size.height;
            height = screenRect.size.width;
        }
        
        // Pixel format for Alpha, Red, Green and Blue
        unsigned pixelFormat = 0x42475241;  // 'ARGB'
        
        // 1 or 2 bytes per component
        int bytesPerComponent = sizeof(uint8_t);
        
        // 8 bytes per pixel
        int bytesPerElement = bytesPerComponent * 4;
        
        // Bytes per row (must be aligned)
        int bytesPerRow = (int)IOSurfaceAlignProperty(kIOSurfaceBytesPerRow, bytesPerElement * width);
        
        // Properties included:
        // BytesPerElement, BytesPerRow, Width, Height, PixelFormat, AllocSize
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        
        CFPropertyListRef colorSpacePropertyList = CGColorSpaceCopyPropertyList(colorSpace);
        CGColorSpaceRelease(colorSpace);
        
        properties = [NSDictionary dictionaryWithObjectsAndKeys:
                      [NSNumber numberWithInt:bytesPerElement], kIOSurfaceBytesPerElement,
                      [NSNumber numberWithInt:bytesPerRow], kIOSurfaceBytesPerRow,
                      [NSNumber numberWithInt:width], kIOSurfaceWidth,
                      [NSNumber numberWithInt:height], kIOSurfaceHeight,
                      [NSNumber numberWithUnsignedInt:pixelFormat], kIOSurfacePixelFormat,
                      [NSNumber numberWithInt:bytesPerRow * height], kIOSurfaceAllocSize,
                      CFBridgingRelease(colorSpacePropertyList), kIOSurfaceColorSpace,
                      nil];
        
        CHDebugLogSource(@"render properties %@", properties);
    });
    
    return properties;
}

- (void)createScreenSurfaceIfNeeded
{
    if (!_screenSurface)
    {
        NSDictionary *properties = [ScreenCapture sharedRenderProperties];
        _screenSurface = IOSurfaceCreate((__bridge CFDictionaryRef)properties);
    }
}

- (JSTPixelImage *)pixelImage
{
    if (!_pixelImage)
    {
        [self createScreenSurfaceIfNeeded];
        
        NSDictionary *properties = [ScreenCapture sharedRenderProperties];
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName((__bridge CFStringRef)properties[(__bridge NSString *)kIOSurfaceColorSpace]);
        _pixelImage = [[JSTPixelImage alloc] initWithCompatibleScreenSurface:_screenSurface colorSpace:colorSpace];
        CGColorSpaceRelease(colorSpace);
    }
    return _pixelImage;
}

+ (NSDictionary *)renderPropertiesInRect:(CGRect)rect
{
    int width = (int)rect.size.width;
    int height = (int)rect.size.height;
    
    // Pixel format for Alpha, Red, Green and Blue
    unsigned pixelFormat = 0x42475241;  // 'ARGB'
    
    // 1 or 2 bytes per component
    int bytesPerComponent = sizeof(uint8_t);
    
    // 8 bytes per pixel
    int bytesPerElement = bytesPerComponent * 4;
    
    // Bytes per row (must be aligned)
    int bytesPerRow = (int)IOSurfaceAlignProperty(kIOSurfaceBytesPerRow, bytesPerElement * width);
    
    // Properties included:
    // BytesPerElement, BytesPerRow, Width, Height, PixelFormat, AllocSize
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    
    CFPropertyListRef colorSpacePropertyList = CGColorSpaceCopyPropertyList(colorSpace);
    CGColorSpaceRelease(colorSpace);
    
    NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInt:bytesPerElement], kIOSurfaceBytesPerElement,
                                [NSNumber numberWithInt:bytesPerRow], kIOSurfaceBytesPerRow,
                                [NSNumber numberWithInt:width], kIOSurfaceWidth,
                                [NSNumber numberWithInt:height], kIOSurfaceHeight,
                                [NSNumber numberWithUnsignedInt:pixelFormat], kIOSurfacePixelFormat,
                                [NSNumber numberWithInt:bytesPerRow * height], kIOSurfaceAllocSize,
                                CFBridgingRelease(colorSpacePropertyList), kIOSurfaceColorSpace,
                                nil];
    
    CHDebugLogSource(@"render properties %@", properties);
    return properties;
}


#pragma mark - Messaging

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ScreenCaptureRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    NSAssert(sendSucceed, @"cannot send message %@, userInfo = %@", messageName, userInfo);
}

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ScreenCaptureRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    NSAssert(sendErr == nil, @"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    return replyInfo;
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ScreenCaptureRoleServer, @"invalid role");
    
    @autoreleasepool {
        NSString *selectorName = [userInfo objectForKey:@"selector"];
        SEL selector = NSSelectorFromString(selectorName);
        NSAssert([self respondsToSelector:selector], @"invalid selector");
        
        NSInvocation *forwardInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
        [forwardInvocation setSelector:selector];
        [forwardInvocation setTarget:self];
        
        NSInteger argumentIndex = 2;
        NSArray *arguments = [userInfo objectForKey:@"arguments"];
        for (NSObject *argument in arguments) {
            void *argumentPtr = (__bridge void *)(argument);
            [forwardInvocation setArgument:&argumentPtr atIndex:argumentIndex];
            argumentIndex += 1;
        }
        
        [forwardInvocation invoke];
    }
}

- (NSDictionary *)receiveAndReplyMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ScreenCaptureRoleServer, @"invalid role to receive message");
    
    @autoreleasepool {
        NSString *selectorName = [userInfo objectForKey:@"selector"];
        SEL selector = NSSelectorFromString(selectorName);
        NSAssert([self respondsToSelector:selector], @"invalid selector");
        
        NSInvocation *forwardInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
        [forwardInvocation setSelector:selector];
        [forwardInvocation setTarget:self];
        
        NSInteger argumentIndex = 2;
        NSArray *arguments = [userInfo objectForKey:@"arguments"];
        for (NSObject *argument in arguments) {
            void *argumentPtr = (__bridge void *)(argument);
            [forwardInvocation setArgument:&argumentPtr atIndex:argumentIndex];
            argumentIndex += 1;
        }
        
        [forwardInvocation invoke];
        
        NSDictionary * __weak returnVal = nil;
        [forwardInvocation getReturnValue:&returnVal];
        NSDictionary *safeReturnVal = returnVal;
        NSAssert([safeReturnVal isKindOfClass:[NSDictionary class]], @"invalid return value");
        
        return safeReturnVal;
    }
}


#pragma mark - Testing

#if DEBUG
+ (unsigned long)__getMemoryUsedInBytes
{
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.resident_size;
    } else {
        return 0;
    }
}
#endif

- (BOOL)writeScreenUIImagePNGDataToFile:(NSString *)path
{
    return [[self getScreenUIImagePNGData] writeToFile:path atomically:YES];
}


#pragma mark - Rendering

- (void)renderDisplayToScreenSurface:(IOSurfaceRef)dstSurface
{
    NSAssert(self.role == ScreenCaptureRoleServer, @"invalid role");
    
    static IOSurfaceAcceleratorRef accelerator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        IOSurfaceAcceleratorCreate(kCFAllocatorDefault, nil, &accelerator);
        
        CFRunLoopSourceRef runLoopSource = IOSurfaceAcceleratorGetRunLoopSource(accelerator);
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopDefaultMode);
    });
    
    /// Fast ~20ms, sRGB, while the image is GOOD. Recommended.
    IOSurfaceRef srcSurface = IOSurfaceCreate((__bridge CFDictionaryRef)[ScreenCapture sharedRenderProperties]);
    CARenderServerRenderDisplay(0, CFSTR("LCD"), srcSurface, 0, 0);
    IOSurfaceAcceleratorTransformSurface(accelerator, srcSurface, dstSurface, NULL, NULL, NULL, NULL, NULL);
    CFRelease(srcSurface);
}

- (void)renderDisplayToSharedScreenSurface
{
    NSAssert(self.role == ScreenCaptureRoleServer, @"invalid role");
    
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    [self createScreenSurfaceIfNeeded];
    
    // Lock the surface
    IOSurfaceLock(_screenSurface, 0, &_seed);
    
    [self renderDisplayToScreenSurface:_screenSurface];
    
    // Unlock the surface
    IOSurfaceUnlock(_screenSurface, 0, &_seed);
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms, %zu bytes memory used", used, [ScreenCapture __getMemoryUsedInBytes]);
#endif
}

- (IOSurfaceRef)copyScreenSurface
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)[ScreenCapture sharedRenderProperties]);
    
    // Lock the surface
    IOSurfaceLock(surface, 0, &_seed);
    
    if (_role == ScreenCaptureRoleClient) {
        [self transferDisplayToScreenSurface:surface];
    } else {
        [self renderDisplayToScreenSurface:surface];
    }
    
    // Unlock the surface
    IOSurfaceUnlock(surface, 0, &_seed);
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
    
    return surface;
}

- (CGImageRef)copyScreenCGImage
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    NSDictionary *screenProperties = [ScreenCapture sharedRenderProperties];
    
    IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)screenProperties);
    
    // Lock the surface
    IOSurfaceLock(surface, 0, &_seed);
    
    if (self.role == ScreenCaptureRoleClient) {
        [self transferDisplayToScreenSurface:surface];
    } else {
        [self renderDisplayToScreenSurface:surface];
    }
    
    // Make a raw memory copy of the surface
    void *baseAddr = IOSurfaceGetBaseAddress(surface);
    size_t allocSize = IOSurfaceGetAllocSize(surface);
    
    CFDataRef rawData = CFDataCreate(kCFAllocatorDefault, baseAddr, allocSize);
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(rawData);
    
    int width = [screenProperties[(__bridge NSString *)kIOSurfaceWidth] intValue];
    int height = [screenProperties[(__bridge NSString *)kIOSurfaceHeight] intValue];
    int bytesPerRow = [screenProperties[(__bridge NSString *)kIOSurfaceBytesPerRow] intValue];
    int bytesPerComponent = sizeof(uint8_t);
    int bytesPerElement = [screenProperties[(__bridge NSString *)kIOSurfaceBytesPerElement] intValue];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName((__bridge CFStringRef)screenProperties[(__bridge NSString *)kIOSurfaceColorSpace]);
    
    CGImageRef cgImage = CGImageCreate(
        width, height,
        bytesPerComponent * BYTE_SIZE,
        bytesPerElement * BYTE_SIZE,
        bytesPerRow  /* already aligned */,
        colorSpace,
        kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst,
        dataProvider, NULL,
        NO, kCGRenderingIntentDefault
    );
    
    CGDataProviderRelease(dataProvider);
    CGColorSpaceRelease(colorSpace);
    CFRelease(rawData);
    
    // Unlock and release the surface
    IOSurfaceUnlock(surface, 0, &_seed);
    CFRelease(surface);
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
    return cgImage;
}

- (UIImage *)getScreenUIImage
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    __block UIImage *uiImage = nil;
    
    if (self.role == ScreenCaptureRoleClient) {
        CGImageRef cgImg = [self copyScreenCGImage];
        uiImage = [UIImage imageWithCGImage:cgImg];
        CGImageRelease(cgImg);
    } else {
        uiImage = _UICreateScreenUIImage();
    }
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
    return uiImage;
}

- (NSData *)getScreenUIImagePNGData
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    // coding is slow: ~200ms
    NSData *data = UIImagePNGRepresentation([self getScreenUIImage]);
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
    return data;
}


#pragma mark - Transfer

- (NSData *)getScreenUIImageRAWDataNoCopy
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    [self createScreenSurfaceIfNeeded];
    
    if (self.role == ScreenCaptureRoleClient) {
        [self transferDisplayToSharedScreenSurface];
    } else {
        [self renderDisplayToSharedScreenSurface];
    }
    
    void *baseAddr = IOSurfaceGetBaseAddress(_screenSurface);
    size_t allocSize = IOSurfaceGetAllocSize(_screenSurface);
    NSData *data = nil;
    
    if (baseAddr && allocSize > 0) {
        data = [NSData dataWithBytesNoCopy:baseAddr length:allocSize freeWhenDone:NO];
    } else {
        data = [NSData data];
    }
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms, %zu bytes memory used", used, [ScreenCapture __getMemoryUsedInBytes]);
#endif
    return data;
}

- (NSDictionary *)getScreenUIImageRAWObjectNoCopy
{
    return @{
        @"reply": [self getScreenUIImageRAWDataNoCopy],
    };
}


#pragma mark - Remote Client

- (void)transferDisplayToSharedScreenSurface
{
    [self createScreenSurfaceIfNeeded];
    [self transferDisplayToScreenSurface:_screenSurface];
}

- (void)transferDisplayToScreenSurface:(IOSurfaceRef)surface
{
    NSAssert(_role == ScreenCaptureRoleClient, @"invalid role");
    
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    // Lock the surface
    IOSurfaceLock(surface, 0, &_seed);
    
    @autoreleasepool {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(getScreenUIImageRAWObjectNoCopy)),
            @"arguments": [NSArray array],
        }];
        
        NSData *replyData = replyObject[@"reply"];
        
#if DEBUG
        NSAssert([replyData isKindOfClass:[NSData class]], @"invalid xpc response");
#endif
        
        void *baseAddr = IOSurfaceGetBaseAddress(surface);
        size_t allocSize = IOSurfaceGetAllocSize(surface);
        
        if ([replyData isKindOfClass:[NSData class]]) {
            memcpy(baseAddr, replyData.bytes, MIN(replyData.length, allocSize));
        } else {
            bzero(baseAddr, allocSize);
        }
    }
    
    // Unlock the surface
    IOSurfaceUnlock(surface, 0, &_seed);
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms, %zu bytes memory used", used, [ScreenCapture __getMemoryUsedInBytes]);
#endif
}

- (void)notifyServerRenderSharedScreenSurface
{
    NSAssert(_role == ScreenCaptureRoleClient, @"invalid role");
    
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
         @"selector": NSStringFromSelector(@selector(getScreenUIImageRAWObjectNoCopy)),
         @"arguments": [NSArray array],
    }];
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms, %zu bytes memory used", used, [ScreenCapture __getMemoryUsedInBytes]);
#endif
}


#pragma mark - Remote Client: Convenience

- (void)updateDisplay
{
    if (_role == ScreenCaptureRoleClient) {
        [self transferDisplayToSharedScreenSurface];
    } else {
        [self renderDisplayToSharedScreenSurface];
    }
}

- (void)updateDisplayWithoutTransfer
{
    if (_role == ScreenCaptureRoleClient) {
        [self notifyServerRenderSharedScreenSurface];
    }
}


#pragma mark - Photos Proxy

- (NSDictionary *)performSavePhotoToAlbumRequestWithData:(NSData *)data timeout:(NSTimeInterval)timeout
{
    return [self _performSavePhotoToAlbumRequestWithData:data timeout:@(timeout)];
}

- (NSDictionary *)_performSavePhotoToAlbumRequestWithData:(NSData *)data timeout:(NSNumber *)timeout
{
    if (_role == ScreenCaptureRoleClient) {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(_performSavePhotoToAlbumRequestWithData:timeout:)),
            @"arguments": [NSArray arrayWithObjects:data, timeout, nil],
        }];
        
#if DEBUG
        NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
        
        CHDebugLog(@"- performSavePhotoToAlbumRequestWithData: <%lu bytes> -> %@, %zu bytes memory used", (unsigned long)data.length, replyObject, [ScreenCapture __getMemoryUsedInBytes]);
        
        return replyObject;
    }
    
    @autoreleasepool {
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        NSTimeInterval checkEveryInterval = 0.01;  // 10ms
        
        __block BOOL proxySucceed = NO;
        __block NSError *proxyError = nil;
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:[UIImage imageWithData:data]];
        } completionHandler:^(BOOL succeed, NSError * _Nullable error) {
            proxySucceed = succeed;
            proxyError = error;
            dispatch_semaphore_signal(sema);
        }];
        
        int waitStatus = 0;
        NSTimeInterval deadline = [[NSDate date] timeIntervalSinceReferenceDate] + [timeout doubleValue];
        while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:checkEveryInterval]];
            if ([[NSDate date] timeIntervalSinceReferenceDate] > deadline) {
                waitStatus = 94;
                break;
            }
        }
        
        NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithCapacity:3];
        
        resultDict[@"succeed"] = @(proxySucceed);
        resultDict[@"status"] = @(waitStatus);
        
        if (proxyError) {
            resultDict[@"error"] = [NSString stringWithFormat:@"%@", proxyError];
        }
        
        return resultDict;
    }
}


#pragma mark - Vision Proxy

- (NSDictionary *)performDetectBarcodesRequestInRect:(CGRect)rect toOrientation:(NSInteger)orientation timeout:(NSTimeInterval)timeout
{
    return [self _performDetectBarcodesRequestInRect:@[@(rect.origin.x), @(rect.origin.y), @(rect.size.width), @(rect.size.height)] toOrientation:@(orientation) timeout:@(timeout)];
}

- (NSDictionary *)_performDetectBarcodesRequestInRect:(NSArray <NSNumber *> *)rect toOrientation:(NSNumber *)orientation timeout:(NSNumber *)timeout
{
    if (_role == ScreenCaptureRoleClient) {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(_performDetectBarcodesRequestInRect:toOrientation:timeout:)),
            @"arguments": [NSArray arrayWithObjects:rect, orientation, timeout, nil],
        }];
        
#if DEBUG
        NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
        
        CHDebugLog(@"- performDetectBarcodesRequestInRect: %@ toOrientation: %@ timeout: %@ -> %@, %zu bytes memory used", rect, orientation, timeout, replyObject, [ScreenCapture __getMemoryUsedInBytes]);
        
        return replyObject;
    }
    
    @autoreleasepool {
        
        CGRect cropRegion = CGRectMake([rect[0] doubleValue], [rect[1] doubleValue], [rect[2] doubleValue], [rect[3] doubleValue]);
        
        [self.pixelImage setOrientation:(uint8_t)[orientation integerValue]];
        
        JSTPixelImage *cropImage = [self.pixelImage crop:cropRegion];
        CGImageRef cropCGImage = (CGImageRef)CGImageRetain([[cropImage toSystemImage] CGImage]);
        CGFloat screenHeight = self.pixelImage.orientedSize.height;
        
        __block NSArray <NSString *> *_resultTextStringList = nil;
        __block NSArray <NSDictionary *> *_resultDetails = nil;
        __block NSError *_requestError = nil;
        
        VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithCGImage:cropCGImage options:@{}];
        CGImageRelease(cropCGImage);
        
        VNDetectBarcodesRequest *detectBarcodesRequest = [[VNDetectBarcodesRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            if (error) {
                _requestError = error;
                return;
            }
            
            @autoreleasepool {
                NSArray <VNBarcodeObservation *> *barcodeObservations = [request results];
                NSMutableArray <NSString *> *recognizedTextStringList = [[NSMutableArray alloc] initWithCapacity:barcodeObservations.count];
                NSMutableArray <NSDictionary *> *recognizedDetails = [[NSMutableArray alloc] initWithCapacity:barcodeObservations.count];
                
                for (VNBarcodeObservation *barcodeObservation in barcodeObservations) {
                    @autoreleasepool {
                        NSString *recognizedTextString = [barcodeObservation payloadStringValue];
                        if (recognizedTextString) {
                            [recognizedTextStringList addObject:recognizedTextString];
                        }
                        
                        CGRect boundingBox = [barcodeObservation boundingBox];
                        CGRect normalizedBoundingBox = VNImageRectForNormalizedRect(boundingBox, cropRegion.size.width, cropRegion.size.height);
                        
                        NSDictionary *recognizedDetail = @{
                            @"payload": recognizedTextString ?: @"",
                            @"confidence": @([barcodeObservation confidence]),
                            @"bounding_box": @[
                                @((int)round(normalizedBoundingBox.origin.x)),  // x1
                                @((int)round(screenHeight - (normalizedBoundingBox.origin.y + normalizedBoundingBox.size.height))),  // y2
                                @((int)round(normalizedBoundingBox.origin.x + normalizedBoundingBox.size.width)),   // x2
                                @((int)round(screenHeight - (normalizedBoundingBox.origin.y))),  // y1
                            ],
                        };
                        [recognizedDetails addObject:recognizedDetail];
                    }
                }
                
                CHDebugLog(@"recognized details %@, %zu bytes memory used", recognizedDetails, [ScreenCapture __getMemoryUsedInBytes]);
                
                _resultTextStringList = [recognizedTextStringList copy];
                _resultDetails = [recognizedDetails copy];
            }
        }];
        
        __block NSError *_resultError = nil;
        __block BOOL _resultSucceed = NO;
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        NSTimeInterval checkEveryInterval = 0.01;  // 10ms
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            NSError *requestError = nil;
            BOOL requestSucceed = [imageRequestHandler performRequests:@[detectBarcodesRequest] error:&requestError];
            
            _resultError = requestError;
            _resultSucceed = requestSucceed;
            
            dispatch_semaphore_signal(sema);
        });
        
        int waitStatus = 0;
        NSTimeInterval deadline = [[NSDate date] timeIntervalSinceReferenceDate] + [timeout doubleValue];
        while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:checkEveryInterval]];
            if ([[NSDate date] timeIntervalSinceReferenceDate] > deadline) {
                waitStatus = 94;
                break;
            }
        }
        
        NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithCapacity:5];
        
        resultDict[@"succeed"] = @(_resultSucceed);
        resultDict[@"status"] = @(waitStatus);
        
        if (_resultError || _requestError) {
            if (_resultError) {
                resultDict[@"error"] = [NSString stringWithFormat:@"%@", _resultError];
            }
            else if (_requestError) {
                resultDict[@"error"] = [NSString stringWithFormat:@"%@", _requestError];
            }
        }
        
        if (_resultTextStringList) {
            resultDict[@"texts"] = [_resultTextStringList copy];
        }
        
        if (_resultDetails) {
            resultDict[@"details"] = [_resultDetails copy];
        }
        
        return resultDict;
    }
}

- (NSDictionary *)performRecognizeTextRequestInRect:(CGRect)rect
                                      toOrientation:(NSInteger)orientation
                                   recognitionLevel:(NSInteger)level
                                            timeout:(NSTimeInterval)timeout
{
    return [self _performRecognizeTextRequestInRect:@[@(rect.origin.x), @(rect.origin.y), @(rect.size.width), @(rect.size.height)] toOrientation:@(orientation) recognitionLevel:@(level) timeout:@(timeout)];
}

- (NSDictionary *)_performRecognizeTextRequestInRect:(NSArray <NSNumber *> *)rect
                                       toOrientation:(NSNumber *)orientation
                                    recognitionLevel:(NSNumber *)level
                                             timeout:(NSNumber *)timeout
{
    if (_role == ScreenCaptureRoleClient) {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(_performRecognizeTextRequestInRect:toOrientation:recognitionLevel:timeout:)),
            @"arguments": [NSArray arrayWithObjects:rect, orientation, level, timeout, nil],
        }];
        
#if DEBUG
        NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
        
        CHDebugLog(@"- performRecognizeTextRequestInRect: %@ toOrientation: %@ recognitionLevel: %@ timeout: %@ -> %@, %zu bytes memory used", rect, orientation, level, timeout, replyObject, [ScreenCapture __getMemoryUsedInBytes]);
        
        return replyObject;
    }
    
    @autoreleasepool {
        
        CGRect cropRegion = CGRectMake([rect[0] doubleValue], [rect[1] doubleValue], [rect[2] doubleValue], [rect[3] doubleValue]);
        
        [self.pixelImage setOrientation:(uint8_t)[orientation integerValue]];
        
        JSTPixelImage *cropImage = [self.pixelImage crop:cropRegion];
        CGImageRef cropCGImage = (CGImageRef)CGImageRetain([[cropImage toSystemImage] CGImage]);
        CGFloat screenHeight = self.pixelImage.orientedSize.height;
        
        __block NSArray <NSString *> *_resultTextStringList = nil;
        __block NSArray <NSDictionary *> *_resultDetails = nil;
        __block NSError *_requestError = nil;
        
        VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithCGImage:cropCGImage options:@{}];
        CGImageRelease(cropCGImage);
        
        VNRecognizeTextRequest *recognizeTextRequest = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            if (error) {
                _requestError = error;
                return;
            }
            
            @autoreleasepool {
                NSArray <VNRecognizedTextObservation *> *recognizedTextObservations = [request results];
                NSMutableArray <NSString *> *recognizedTextStringList = [[NSMutableArray alloc] initWithCapacity:recognizedTextObservations.count];
                NSMutableArray <NSDictionary *> *recognizedDetails = [[NSMutableArray alloc] initWithCapacity:recognizedTextObservations.count];
                
                for (VNRecognizedTextObservation *recognizedTextObservation in recognizedTextObservations) {
                    @autoreleasepool {
                        VNRecognizedText *recognizedText = [[recognizedTextObservation topCandidates:1] firstObject];
                        
                        NSString *recognizedTextString = [recognizedText string];
                        if (recognizedTextString) {
                            [recognizedTextStringList addObject:recognizedTextString];
                        }
                        
                        NSError *rectangleError = nil;
                        VNRectangleObservation *recognizedTextRectangleObservation = [recognizedText boundingBoxForRange:NSMakeRange(0, recognizedTextString.length) error:&rectangleError];
                        if (!recognizedTextRectangleObservation) {
                            CHDebugLogSource(@"cannot fetch bounding box of %@, error %@", recognizedTextString, rectangleError);
                            continue;
                        }
                        
                        CGRect boundingBox = [recognizedTextRectangleObservation boundingBox];
                        CGRect normalizedBoundingBox = VNImageRectForNormalizedRect(boundingBox, cropRegion.size.width, cropRegion.size.height);
                        NSDictionary *recognizedDetail = @{
                            @"recognized_text": recognizedTextString ?: @"",
                            @"bounding_box": @[
                                @((int)round(normalizedBoundingBox.origin.x)),  // x1
                                @((int)round(screenHeight - (normalizedBoundingBox.origin.y + normalizedBoundingBox.size.height))),  // y2
                                @((int)round(normalizedBoundingBox.origin.x + normalizedBoundingBox.size.width)),   // x2
                                @((int)round(screenHeight - (normalizedBoundingBox.origin.y))),  // y1
                            ],
                        };
                        [recognizedDetails addObject:recognizedDetail];
                    }
                }
                
                CHDebugLogSource(@"recognized details %@, %zu bytes memory used", recognizedDetails, [ScreenCapture __getMemoryUsedInBytes]);
                
                _resultTextStringList = [recognizedTextStringList copy];
                _resultDetails = [recognizedDetails copy];
            }
        }];
        
        VNRequestTextRecognitionLevel recognitionLevel = [level integerValue];
        [recognizeTextRequest setRecognitionLevel:recognitionLevel];
        [recognizeTextRequest setRecognitionLanguages:@[@"en-US"]];
        [recognizeTextRequest setUsesCPUOnly:(recognitionLevel == VNRequestTextRecognitionLevelAccurate)];
        
        __block NSError *_resultError = nil;
        __block BOOL _resultSucceed = NO;
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        NSTimeInterval checkEveryInterval = 0.01;  // 10ms
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            NSError *requestError = nil;
            BOOL requestSucceed = [imageRequestHandler performRequests:@[recognizeTextRequest] error:&requestError];
            
            _resultError = requestError;
            _resultSucceed = requestSucceed;
            
            dispatch_semaphore_signal(sema);
        });
        
        int waitStatus = 0;
        NSTimeInterval deadline = [[NSDate date] timeIntervalSinceReferenceDate] + [timeout doubleValue];
        while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:checkEveryInterval]];
            if ([[NSDate date] timeIntervalSinceReferenceDate] > deadline) {
                waitStatus = 94;
                break;
            }
        }
        
        NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithCapacity:5];
        
        resultDict[@"succeed"] = @(_resultSucceed);
        resultDict[@"status"] = @(waitStatus);
        
        if (_resultError || _requestError) {
            if (_resultError) {
                resultDict[@"error"] = [NSString stringWithFormat:@"%@", _resultError];
            }
            else if (_requestError) {
                resultDict[@"error"] = [NSString stringWithFormat:@"%@", _requestError];
            }
        }
        
        if (_resultTextStringList) {
            resultDict[@"texts"] = [_resultTextStringList copy];
        }
        
        if (_resultDetails) {
            resultDict[@"details"] = [_resultDetails copy];
        }
        
        return resultDict;
    }
}

- (NSDictionary *)performDetectBarcodesRequestWithData:(NSData *)data timeout:(NSTimeInterval)timeout
{
    return [self _performDetectBarcodesRequestWithData:data timeout:@(timeout)];
}

- (NSDictionary *)_performDetectBarcodesRequestWithData:(NSData *)data timeout:(NSNumber *)timeout
{
    if (_role == ScreenCaptureRoleClient) {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(_performDetectBarcodesRequestWithData:timeout:)),
            @"arguments": [NSArray arrayWithObjects:data, timeout, nil],
        }];
        
#if DEBUG
        NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
        
        CHDebugLog(@"- performDetectBarcodesRequestWithData: <%lu bytes> timeout: %@ -> %@, %zu bytes memory used", (unsigned long)data.length, timeout, replyObject, [ScreenCapture __getMemoryUsedInBytes]);
        
        return replyObject;
    }
    
    @autoreleasepool {
        
        UIImage *targetImage = [UIImage imageWithData:data];
        CGSize targetImageSize = targetImage.size;
        
        if (!targetImage) {
            return @{
                @"succeed": @(NO),
                @"status": @(1),
                @"error": @"vision proxy failed decoding image",
            };
        }
        
        __block NSArray <NSString *> *_resultTextStringList = nil;
        __block NSArray <NSDictionary *> *_resultDetails = nil;
        __block NSError *_requestError = nil;
        
        VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithCGImage:[targetImage CGImage] options:@{}];
        VNDetectBarcodesRequest *detectBarcodesRequest = [[VNDetectBarcodesRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            if (error) {
                _requestError = error;
                return;
            }
            
            @autoreleasepool {
                NSArray <VNBarcodeObservation *> *barcodeObservations = [request results];
                NSMutableArray <NSString *> *recognizedTextStringList = [[NSMutableArray alloc] initWithCapacity:barcodeObservations.count];
                NSMutableArray <NSDictionary *> *recognizedDetails = [[NSMutableArray alloc] initWithCapacity:barcodeObservations.count];
                
                for (VNBarcodeObservation *barcodeObservation in barcodeObservations) {
                    @autoreleasepool {
                        NSString *recognizedTextString = [barcodeObservation payloadStringValue];
                        if (recognizedTextString) {
                            [recognizedTextStringList addObject:recognizedTextString];
                        }
                        
                        CGRect boundingBox = [barcodeObservation boundingBox];
                        CGRect normalizedBoundingBox = VNImageRectForNormalizedRect(boundingBox, targetImageSize.width, targetImageSize.height);
                        
                        NSDictionary *recognizedDetail = @{
                            @"payload": recognizedTextString ?: @"",
                            @"confidence": @([barcodeObservation confidence]),
                            @"bounding_box": @[
                                @((int)round(normalizedBoundingBox.origin.x)),  // x1
                                @((int)round(targetImageSize.height - (normalizedBoundingBox.origin.y + normalizedBoundingBox.size.height))),  // y2
                                @((int)round(normalizedBoundingBox.origin.x + normalizedBoundingBox.size.width)),   // x2
                                @((int)round(targetImageSize.height - (normalizedBoundingBox.origin.y))),  // y1
                            ],
                        };
                        [recognizedDetails addObject:recognizedDetail];
                    }
                }
                
                CHDebugLogSource(@"recognized details %@, %zu bytes memory used", recognizedDetails, [ScreenCapture __getMemoryUsedInBytes]);
                
                _resultTextStringList = [recognizedTextStringList copy];
                _resultDetails = [recognizedDetails copy];
            }
        }];
        
        __block NSError *_resultError = nil;
        __block BOOL _resultSucceed = NO;
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        NSTimeInterval checkEveryInterval = 0.01;  // 10ms
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            NSError *requestError = nil;
            BOOL requestSucceed = [imageRequestHandler performRequests:@[detectBarcodesRequest] error:&requestError];
            
            _resultError = requestError;
            _resultSucceed = requestSucceed;
            
            dispatch_semaphore_signal(sema);
        });
        
        int waitStatus = 0;
        NSTimeInterval deadline = [[NSDate date] timeIntervalSinceReferenceDate] + [timeout doubleValue];
        while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:checkEveryInterval]];
            if ([[NSDate date] timeIntervalSinceReferenceDate] > deadline) {
                waitStatus = 94;
                break;
            }
        }
        
        NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithCapacity:5];
        
        resultDict[@"succeed"] = @(_resultSucceed);
        resultDict[@"status"] = @(waitStatus);
        
        if (_resultError || _requestError) {
            if (_resultError) {
                resultDict[@"error"] = [NSString stringWithFormat:@"%@", _resultError];
            }
            else if (_requestError) {
                resultDict[@"error"] = [NSString stringWithFormat:@"%@", _requestError];
            }
        }
        
        if (_resultTextStringList) {
            resultDict[@"texts"] = [_resultTextStringList copy];
        }
        
        if (_resultDetails) {
            resultDict[@"details"] = [_resultDetails copy];
        }
        
        return resultDict;
    }
}

- (NSDictionary *)performRecognizeTextRequestWithData:(NSData *)data
                                     recognitionLevel:(NSInteger)level
                                              timeout:(NSTimeInterval)timeout
{
    return [self _performRecognizeTextRequestWithData:data recognitionLevel:@(level) timeout:@(timeout)];
}

- (NSDictionary *)_performRecognizeTextRequestWithData:(NSData *)data
                                      recognitionLevel:(NSNumber *)level
                                               timeout:(NSNumber *)timeout
{
    if (_role == ScreenCaptureRoleClient) {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(_performRecognizeTextRequestWithData:recognitionLevel:timeout:)),
            @"arguments": [NSArray arrayWithObjects:data, level, timeout, nil],
        }];
        
#if DEBUG
        NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
        
        CHDebugLog(@"- performRecognizeTextRequestWithData: <%lu bytes> recognitionLevel: %@ timeout: %@ -> %@, %zu bytes memory used", (unsigned long)data.length, level, timeout, replyObject, [ScreenCapture __getMemoryUsedInBytes]);
        
        return replyObject;
    }
    
    @autoreleasepool {
        
        UIImage *targetImage = [UIImage imageWithData:data];
        CGSize targetImageSize = targetImage.size;
        
        if (!targetImage) {
            return @{
                @"succeed": @(NO),
                @"status": @(1),
                @"error": @"vision proxy failed decoding image",
            };
        }
        
        __block NSArray <NSString *> *_resultTextStringList = nil;
        __block NSArray <NSDictionary *> *_resultDetails = nil;
        __block NSError *_requestError = nil;
        
        VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithCGImage:[targetImage CGImage] options:@{}];
        VNRecognizeTextRequest *recognizeTextRequest = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            if (error) {
                _requestError = error;
                return;
            }
            
            @autoreleasepool {
                NSArray <VNRecognizedTextObservation *> *recognizedTextObservations = [request results];
                NSMutableArray <NSString *> *recognizedTextStringList = [[NSMutableArray alloc] initWithCapacity:recognizedTextObservations.count];
                NSMutableArray <NSDictionary *> *recognizedDetails = [[NSMutableArray alloc] initWithCapacity:recognizedTextObservations.count];
                
                for (VNRecognizedTextObservation *recognizedTextObservation in recognizedTextObservations) {
                    @autoreleasepool {
                        VNRecognizedText *recognizedText = [[recognizedTextObservation topCandidates:1] firstObject];
                        
                        NSString *recognizedTextString = [recognizedText string];
                        if (recognizedTextString) {
                            [recognizedTextStringList addObject:recognizedTextString];
                        }
                        
                        NSError *rectangleError = nil;
                        VNRectangleObservation *recognizedTextRectangleObservation = [recognizedText boundingBoxForRange:NSMakeRange(0, recognizedTextString.length) error:&rectangleError];
                        if (!recognizedTextRectangleObservation) {
                            CHDebugLogSource(@"cannot fetch bounding box of %@, error %@", recognizedTextString, rectangleError);
                            continue;
                        }
                        
                        CGRect boundingBox = [recognizedTextRectangleObservation boundingBox];
                        CGRect normalizedBoundingBox = VNImageRectForNormalizedRect(boundingBox, targetImageSize.width, targetImageSize.height);
                        NSDictionary *recognizedDetail = @{
                            @"recognized_text": recognizedTextString ?: @"",
                            @"bounding_box": @[
                                @((int)round(normalizedBoundingBox.origin.x)),  // x1
                                @((int)round(targetImageSize.height - (normalizedBoundingBox.origin.y + normalizedBoundingBox.size.height))),  // y2
                                @((int)round(normalizedBoundingBox.origin.x + normalizedBoundingBox.size.width)),   // x2
                                @((int)round(targetImageSize.height - (normalizedBoundingBox.origin.y))),  // y1
                            ],
                        };
                        [recognizedDetails addObject:recognizedDetail];
                    }
                }
                
                CHDebugLogSource(@"recognized details %@, %zu bytes memory used", recognizedDetails, [ScreenCapture __getMemoryUsedInBytes]);
                
                _resultTextStringList = [recognizedTextStringList copy];
                _resultDetails = [recognizedDetails copy];
            }
        }];
        
        VNRequestTextRecognitionLevel recognitionLevel = [level integerValue];
        [recognizeTextRequest setRecognitionLevel:recognitionLevel];
        [recognizeTextRequest setRecognitionLanguages:@[@"en-US"]];
        [recognizeTextRequest setUsesCPUOnly:(recognitionLevel == VNRequestTextRecognitionLevelAccurate)];
        
        __block NSError *_resultError = nil;
        __block BOOL _resultSucceed = NO;
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        NSTimeInterval checkEveryInterval = 0.01;  // 10ms
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            NSError *requestError = nil;
            BOOL requestSucceed = [imageRequestHandler performRequests:@[recognizeTextRequest] error:&requestError];
            
            _resultError = requestError;
            _resultSucceed = requestSucceed;
            
            dispatch_semaphore_signal(sema);
        });
        
        int waitStatus = 0;
        NSTimeInterval deadline = [[NSDate date] timeIntervalSinceReferenceDate] + [timeout doubleValue];
        while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:checkEveryInterval]];
            if ([[NSDate date] timeIntervalSinceReferenceDate] > deadline) {
                waitStatus = 94;
                break;
            }
        }
        
        NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithCapacity:5];
        
        resultDict[@"succeed"] = @(_resultSucceed);
        resultDict[@"status"] = @(waitStatus);
        
        if (_resultError || _requestError) {
            if (_resultError) {
                resultDict[@"error"] = [NSString stringWithFormat:@"%@", _resultError];
            }
            else if (_requestError) {
                resultDict[@"error"] = [NSString stringWithFormat:@"%@", _requestError];
            }
        }
        
        if (_resultTextStringList) {
            resultDict[@"texts"] = [_resultTextStringList copy];
        }
        
        if (_resultDetails) {
            resultDict[@"details"] = [_resultDetails copy];
        }
        
        return resultDict;
    }
}

- (JSTPixelImage *)performQuickResponseImageGeneratingRequestWithPayload:(NSString *)payload
                                                             fittingSize:(CGSize)size
                                                               fillColor:(JSTPixelColor *)fillColor
                                                         backgroundColor:(JSTPixelColor *)backgroundColor
{
    @autoreleasepool {
        JST_COLOR_TYPE fillColorValue = [fillColor argbValue];
        JST_COLOR_TYPE backgroundColorValue = [backgroundColor argbValue];
        
        IOSurfaceRef surface = [self copyQuickResponseImageSurfaceWithPayload:payload
                                                                  fittingSize:@[@(size.width), @(size.height)]
                                                                    fillColor:@(fillColorValue)
                                                              backgroundColor:@(backgroundColorValue)];
        
        CGImageRef cgImage = UICreateCGImageFromIOSurface(surface);
        UIImage *systemImage = [UIImage imageWithCGImage:cgImage];
        
        CGImageRelease(cgImage);
        CFRelease(surface);
        
        return [JSTPixelImage imageWithSystemImage:systemImage];
    }
}

- (IOSurfaceRef)copyQuickResponseImageSurfaceWithPayload:(NSString *)payload
                                             fittingSize:(NSArray <NSNumber *> *)size
                                               fillColor:(NSNumber *)fillColor
                                         backgroundColor:(NSNumber *)backgroundColor
{
    @autoreleasepool {
        CGSize fittingSize = CGSizeMake([size[0] doubleValue], [size[1] doubleValue]);
        CGRect fittingBounds = CGRectMake(0, 0, fittingSize.width, fittingSize.height);
        
        NSDictionary *defaultProperties = [ScreenCapture renderPropertiesInRect:fittingBounds];
        IOSurfaceRef defaultSurface = IOSurfaceCreate((__bridge CFDictionaryRef)defaultProperties);
        uint32_t defaultSeed;
        
        // Lock the surface
        IOSurfaceLock(defaultSurface, 0, &defaultSeed);
        
        // Make a raw memory copy of the surface
        void *baseAddr = IOSurfaceGetBaseAddress(defaultSurface);
        size_t allocSize = IOSurfaceGetAllocSize(defaultSurface);
        
        if (_role == ScreenCaptureRoleClient) {
            
            NSDictionary *replyObject = [self _performQuickResponseImageGeneratingRequestWithPayload:payload
                                                                                         fittingSize:size
                                                                                           fillColor:fillColor
                                                                                     backgroundColor:backgroundColor];
            
            NSData *replyData = replyObject[@"reply"];
            
            if ([replyData isKindOfClass:[NSData class]]) {
                memcpy(baseAddr, replyData.bytes, MIN(replyData.length, allocSize));
            } else {
                bzero(baseAddr, allocSize);
            }
            
        } else {
            
            // Generate and render Quick Response code image
            CIFilter *generatorFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
            [generatorFilter setValue:[payload dataUsingEncoding:NSISOLatin1StringEncoding] forKey:@"inputMessage"];
            
            CIImage *generatedImage = [generatorFilter outputImage];
            CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName((__bridge CFStringRef)defaultProperties[(__bridge NSString *)kIOSurfaceColorSpace]);
            
            JSTPixelColor *foregroundJSTColor = [JSTPixelColor colorWithARGBHexInt:[fillColor unsignedIntValue]];
            JSTPixelColor *backgroundJSTColor = [JSTPixelColor colorWithARGBHexInt:[backgroundColor unsignedIntValue]];
            
            CGColorRef foregroundCGColor = [[foregroundJSTColor toSystemColorWithColorSpace:colorSpace] CGColor];
            CGColorRef backgroundCGColor = [[backgroundJSTColor toSystemColorWithColorSpace:colorSpace] CGColor];
            
            CHDebugLogSource(@"filter payload %@ foreground %@ background %@", payload, foregroundJSTColor, backgroundJSTColor);
            
            CIFilter *colorFilter = [CIFilter filterWithName:@"CIFalseColor" withInputParameters:@{
                @"inputImage": generatedImage,
                @"inputColor0": [CIColor colorWithCGColor:foregroundCGColor],
                @"inputColor1": [CIColor colorWithCGColor:backgroundCGColor],
            }];
            
            CIImage *coloredImage = [colorFilter outputImage];
            
            // Transform image
            CGRect fittingExtent = coloredImage.extent;
            CGFloat fittingScale = MIN(fittingSize.width / CGRectGetWidth(fittingExtent),
                                       fittingSize.height / CGRectGetHeight(fittingExtent));
            size_t fittingWidth = (size_t)(fittingScale * CGRectGetWidth(fittingExtent));
            size_t fittingHeight = (size_t)(fittingScale * CGRectGetHeight(fittingExtent));
            
            int bytesPerComponent = sizeof(uint8_t);
            int bytesPerRow = [defaultProperties[(__bridge NSString *)kIOSurfaceBytesPerRow] intValue];
            
            CGContextRef bitmapContextRef = CGBitmapContextCreate(
                baseAddr,
                fittingWidth, fittingHeight,
                bytesPerComponent * BYTE_SIZE,
                bytesPerRow  /* already aligned */,
                colorSpace,
                kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst
            );
            
            CGColorSpaceRelease(colorSpace);
            
            CGContextSetInterpolationQuality(bitmapContextRef, kCGInterpolationNone);
            CGContextScaleCTM(bitmapContextRef, fittingScale, fittingScale);
            
            CIContext *ciContext = [CIContext contextWithOptions:nil];
            CGImageRef ciBitmapImage = [ciContext createCGImage:coloredImage fromRect:fittingExtent];
            CGContextDrawImage(bitmapContextRef, fittingExtent, ciBitmapImage);
            
            CGImageRelease(ciBitmapImage);
            CGContextRelease(bitmapContextRef);
        }
        
        // Unlock and release the surface
        IOSurfaceUnlock(defaultSurface, 0, &defaultSeed);
        
        return defaultSurface;
    }
}

- (NSDictionary *)_performQuickResponseImageGeneratingRequestWithPayload:(NSString *)payload
                                                             fittingSize:(NSArray <NSNumber *> *)size
                                                               fillColor:(NSNumber *)fillColor
                                                         backgroundColor:(NSNumber *)backgroundColor
{
    if (_role == ScreenCaptureRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_performQuickResponseImageGeneratingRequestWithPayload:fittingSize:fillColor:backgroundColor:)),
                @"arguments": [NSArray arrayWithObjects:payload, size, fillColor, backgroundColor, nil],
            }];
            
#if DEBUG
            NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
            NSAssert([replyObject[@"reply"] isKindOfClass:[NSData class]], @"invalid xpc response");
#endif
            
            CHDebugLog(@"- performQuickResponseImageGeneratingRequestWithPayload: %@ fittingSize: %@ fillColor: %@ backgroundColor: %@ -> %@, %zu bytes memory used", payload, size, [JSTPixelColor colorWithARGBHexInt:[fillColor unsignedIntValue]], [JSTPixelColor colorWithARGBHexInt:[backgroundColor unsignedIntValue]], replyObject, [ScreenCapture __getMemoryUsedInBytes]);
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        IOSurfaceRef generatedSurface = [self copyQuickResponseImageSurfaceWithPayload:payload
                                                                           fittingSize:size
                                                                             fillColor:fillColor
                                                                       backgroundColor:backgroundColor];
        
        void *baseAddr = IOSurfaceGetBaseAddress(generatedSurface);
        size_t allocSize = IOSurfaceGetAllocSize(generatedSurface);
        
        NSData *data = [NSData dataWithBytes:baseAddr length:allocSize];
        CFRelease(generatedSurface);
        
        return @{ @"reply": data };
    }
}

@end


#pragma mark - Server Initializers

CHDeclareClass(SpringBoard);

CHOptimizedMethod(1, self, void, SpringBoard, applicationDidFinishLaunching, UIApplication *, application)
{
    @autoreleasepool {
        CHSuper(1, SpringBoard, applicationDidFinishLaunching, application);
        
        NSString *processName = [[NSProcessInfo processInfo] processName];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        
        CPDistributedMessagingCenter *serverMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
        rocketbootstrap_distributedmessagingcenter_apply(serverMessagingCenter);
        [serverMessagingCenter runServerOnCurrentThread];
        
        ScreenCapture *serverInstance = [ScreenCapture sharedCaptureWithRole:ScreenCaptureRoleServer];
        [serverMessagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
        [serverMessagingCenter registerForMessageName:@XPC_TWOWAY_MSG_NAME target:serverInstance selector:@selector(receiveAndReplyMessageName:userInfo:)];
        [serverInstance setMessagingCenter:serverMessagingCenter];
        
        CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", serverMessagingCenter, bundleIdentifier, processName, getpid());
    }
}


#pragma mark - Initializers

CHConstructor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"])
        {   /* Server Process - Screen Capture */
            
            rocketbootstrap_unlock(XPC_INSTANCE_NAME);
        }
        else
        {   /* Client Process - screen.so */
            
            CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
            
            ScreenCapture *clientInstance = [ScreenCapture sharedCaptureWithRole:ScreenCaptureRoleClient];
            [clientInstance setMessagingCenter:clientMessagingCenter];
            
            CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
        }
        
        CHLoadLateClass(SpringBoard);
        CHHook(1, SpringBoard, applicationDidFinishLaunching);
    }
}
