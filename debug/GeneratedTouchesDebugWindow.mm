/*
 * Copyright (C) 2017 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "GeneratedTouchesDebugWindow.h"
#import "UIApplicationRotationFollowingWindow.h"
#import "UIApplicationRotationFollowingControllerNoTouches.h"
#import <UIKit/UIScreen.h>
#import "PassWindow.h"

#import "UIView+XXTEToast.h"
#import "UIColor+SKColor.h"

#import <notify.h>


#define HIDMaxTouchCount 30

static const CGFloat debugTouchDotRadius = 6;
static const CGFloat debugTouchDotSize = debugTouchDotRadius * 2;

OBJC_EXTERN GeneratedTouchesDebugWindow *_touchesDebugWindow;
OBJC_EXTERN PassWindow *_sharedDebugWindow;
OBJC_EXTERN UILabel *_sharedDebugLabel;


#pragma mark -

@interface GeneratedTouchesDebugWindow ()
@property (nonatomic, strong) NSArray <UIView *> *debugTouchViews;
@property (nonatomic, strong) PassWindow *debugTouchWindow;
@property (nonatomic, strong) NSDictionary <NSNumber *, PassWindow *> *debugToastWindows;
@end

@implementation GeneratedTouchesDebugWindow {
    GeneratedTouchesDebugWindowRole _role;
}

@synthesize messagingCenter = _messagingCenter;

+ (NSString *)messagingCenterName
{
#ifdef XPC_INSTANCE_NAME
    return @XPC_INSTANCE_NAME;
#else
    return @"ch.xxtou.DebugWindow";
#endif
}

+ (GeneratedTouchesDebugWindow *)sharedGeneratedTouchesDebugWindow
{
    return [self sharedGeneratedTouchesDebugWindowWithRole:GeneratedTouchesDebugWindowRoleClient];
}

+ (instancetype)sharedGeneratedTouchesDebugWindowWithRole:(GeneratedTouchesDebugWindowRole)role
{
    static GeneratedTouchesDebugWindow *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[GeneratedTouchesDebugWindow alloc] initWithRole:role];
    });
    return _server;
}

+ (NSArray <UIColor *> *)preparedColors
{
    static NSArray <UIColor *> *colors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray <NSString *> *colorHexes = @[
            @"#e74c3c",
            @"#e67e22",
            @"#f1c40f",
            @"#3498db",
            @"#2ecc71",
            @"#1abc9c",
            @"#34495e",
            @"#9b59b6",
        ];
        NSMutableArray <UIColor *> *mColors = [NSMutableArray arrayWithCapacity:colorHexes.count];
        for (NSString *colorHex in colorHexes) {
            [mColors addObject:[UIColor xxte_colorWithHex:colorHex]];
        }
        colors = [mColors copy];
    });
    return colors;
}

+ (NSString *)localizedString:(NSString *)string
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray <NSString *> *languages = [defs objectForKey:@"AppleLanguages"];
    NSString *dLanguage = [languages objectAtIndex:0];
    
    if ([dLanguage isEqualToString:@"zh-Hans"] || [dLanguage hasPrefix:@"zh-Hans-"]) {
        if ([string isEqualToString:@"TASK_TERMINATED"]) {
            return @"任务进程已终止";
        }
        else if ([string isEqualToString:@"RECORD_DID_BEGIN"]) {
            return @"即将开始录制";
        }
        else if ([string isEqualToString:@"RECORD_DID_END"]) {
            return @"即将结束录制";
        }
        else if ([string isEqualToString:@"DMCA_BLOCK"]) {
            return @"目标应用受著作权保护\nXXTouch 部分功能不可用";
        }
    }
    
    if ([string isEqualToString:@"TASK_TERMINATED"]) {
        return @"Task Terminated";
    }
    else if ([string isEqualToString:@"RECORD_DID_BEGIN"]) {
        return @"Now Recording";
    }
    else if ([string isEqualToString:@"RECORD_DID_END"]) {
        return @"Record Completed";
    }
    else if ([string isEqualToString:@"DMCA_BLOCK"]) {
        return @"Target application is protected by copyright, some features of XXTouch are not available.";
    }
    
    return string;
}

- (instancetype)initWithRole:(GeneratedTouchesDebugWindowRole)role {
    self = [super init];
    if (self) {
        _role = role;
        
#if DEBUG
        _shouldShowTouches = YES;
#endif
        
        if (role == GeneratedTouchesDebugWindowRoleServer) {
            int toastDismissalToken;
            notify_register_dispatch(NOTIFY_DISMISSAL_SYS_TOAST, &toastDismissalToken, dispatch_get_main_queue(), ^(int token) {
                [self.debugToastWindows[@(UIInterfaceOrientationPortrait)] hideToastActivity];
            });
            
            int poseDismissalToken;
            notify_register_dispatch(NOTIFY_DISMISSAL_TOUCH_POSE, &poseDismissalToken, dispatch_get_main_queue(), ^(int token) {
                [self resetDebugIndicatorForTouches];
            });
            
            int taskDidEndHintToken;
            notify_register_dispatch(NOTIFY_TASK_DID_END_HINT, &taskDidEndHintToken, dispatch_get_main_queue(), ^(int token) {
                [self makeToast:[GeneratedTouchesDebugWindow localizedString:@"TASK_TERMINATED"]
                       duration:[XXTEToastManager defaultDuration]
                       position:XXTEToastPositionBottom
                    orientation:UIInterfaceOrientationPortrait];
            });
            
            int recordDidBeginToken;
            notify_register_dispatch(NOTIFY_RECORD_DID_BEGIN, &recordDidBeginToken, dispatch_get_main_queue(), ^(int token) {
                [self makeToast:[GeneratedTouchesDebugWindow localizedString:@"RECORD_DID_BEGIN"]
                       duration:[XXTEToastManager defaultDuration]
                       position:XXTEToastPositionBottom
                    orientation:UIInterfaceOrientationPortrait];
            });
            
            int recordDidEndToken;
            notify_register_dispatch(NOTIFY_RECORD_DID_END, &recordDidEndToken, dispatch_get_main_queue(), ^(int token) {
                [self makeToast:[GeneratedTouchesDebugWindow localizedString:@"RECORD_DID_END"]
                       duration:[XXTEToastManager defaultDuration]
                       position:XXTEToastPositionBottom
                    orientation:UIInterfaceOrientationPortrait];
            });
            
            int dmcaBlockToken;
            notify_register_dispatch(NOTIFY_INELIGIBLE_INJECTION, &dmcaBlockToken, dispatch_get_main_queue(), ^(int token) {
                [self makeToast:[GeneratedTouchesDebugWindow localizedString:@"DMCA_BLOCK"]
                       duration:[XXTEToastManager defaultDuration]
                       position:XXTEToastPositionTop
                    orientation:UIInterfaceOrientationPortrait];
            });
        }
    }
    return self;
}

- (GeneratedTouchesDebugWindowRole)role {
    return _role;
}

- (CPDistributedMessagingCenter *)messagingCenter {
    return _messagingCenter;
}

- (void)setMessagingCenter:(CPDistributedMessagingCenter *)messagingCenter {
    _messagingCenter = messagingCenter;
}

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSAssert(_role == GeneratedTouchesDebugWindowRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    NSAssert(sendSucceed, @"cannot send message %@, userInfo = %@", messageName, userInfo);
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSAssert(_role == GeneratedTouchesDebugWindowRoleServer, @"invalid role");
    
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

- (void)dealloc
{
    [_debugTouchWindow setHidden:YES];
    for (UIView *debugTouchView in _debugTouchViews) {
        [debugTouchView release];
    }
    
    for (NSNumber *debugToastWindowKey in _debugToastWindows) {
        [_debugToastWindows[debugToastWindowKey] setHidden:YES];
    }
    
    [_debugTouchWindow release];
    [_debugToastWindows release];
    [_debugTouchViews release];
    [_messagingCenter release];
    
    [super dealloc];
}

- (void)setShouldShowTouches:(BOOL)shouldShowTouches
{
    _shouldShowTouches = shouldShowTouches;
    if (shouldShowTouches) {
        [_debugTouchWindow setHidden:NO];
        for (NSNumber *debugToastWindowKey in _debugToastWindows) {
            [_debugToastWindows[debugToastWindowKey] hideToastActivity];
            [_debugToastWindows[debugToastWindowKey] setHidden:NO];
        }
    } else {
        [_debugTouchWindow setHidden:YES];
        for (NSNumber *debugToastWindowKey in _debugToastWindows) {
            [_debugToastWindows[debugToastWindowKey] hideToastActivity];
            [_debugToastWindows[debugToastWindowKey] setHidden:YES];
        }
    }
}

- (void)resetDebugIndicatorForTouches
{
    for (UIView *debugTouchView in _debugTouchViews) {
        [debugTouchView setHidden:YES];
    }
}

- (void)initDebugViewsIfNeeded
{
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{

        {
            PassWindow *touchWindow = [[PassWindow alloc] _initWithFrame:CGRectZero attached:NO];
            
            [touchWindow commonInit];
            [touchWindow setupOrientation:UIInterfaceOrientationPortrait];
            [touchWindow setWindowLevel:UIWindowLevelStatusBar + 1];
            [touchWindow setHidden:NO];
            [touchWindow setBackgroundColor:[UIColor clearColor]];
            [touchWindow setUserInteractionEnabled:NO];

            self.debugTouchWindow = touchWindow;
            
            NSMutableArray *debugViews = [[NSMutableArray alloc] initWithCapacity:HIDMaxTouchCount];
            
            for (NSUInteger i = 0; i < HIDMaxTouchCount; ++i) {

                UIView *newView = [[UIView alloc] initWithFrame:CGRectMake(10, 10, debugTouchDotSize, debugTouchDotSize)];
                [newView setUserInteractionEnabled:NO];
                [newView layer].cornerRadius = debugTouchDotRadius;
                [newView layer].borderWidth = 1.0;
                [newView layer].borderColor = [[UIColor blackColor] CGColor];
                
                [newView setBackgroundColor:[GeneratedTouchesDebugWindow preparedColors][i % 8]];
                [newView setHidden:YES];

                debugViews[i] = newView;

                [touchWindow addSubview:debugViews[i]];
            }

            self.debugTouchViews = debugViews;
        }
        
        {
            NSArray <NSNumber *> *debugDirections = @[@(UIInterfaceOrientationPortrait), @(UIInterfaceOrientationLandscapeLeft), @(UIInterfaceOrientationLandscapeRight), @(UIInterfaceOrientationPortraitUpsideDown)];
            
            NSMutableDictionary <NSNumber *, PassWindow *> *debugWindows = [[NSMutableDictionary alloc] initWithCapacity:debugDirections.count];
            
            for (NSNumber *debugDirection in debugDirections) {
                PassWindow *toastWindow = [[PassWindow alloc] _initWithFrame:CGRectZero attached:NO];
                
                [toastWindow commonInit];
                [toastWindow setupOrientation:(UIInterfaceOrientation)[debugDirection integerValue]];
                [toastWindow setWindowLevel:UIWindowLevelStatusBar + 1];
                
                UIApplicationRotationFollowingControllerNoTouches *viewController = [[UIApplicationRotationFollowingControllerNoTouches alloc] init];
                
                [toastWindow setRootViewController:viewController];
                [toastWindow setHidden:NO];
                [toastWindow setBackgroundColor:[UIColor clearColor]];
                [toastWindow setUserInteractionEnabled:NO];
                
                [debugWindows setObject:toastWindow forKey:debugDirection];
            }
            
            self.debugToastWindows = debugWindows;
        }
        
    });
}

- (void)updateDebugIndicatorForTouch:(NSUInteger)index withPointInWindowCoordinates:(CGPoint)point isTouching:(BOOL)isTouching
{
    [self _updateDebugIndicatorForTouch:@(index) withPointInWindowCoordinates:@[@(point.x), @(point.y)] isTouching:@(isTouching)];
}

- (void)_updateDebugIndicatorForTouch:(NSNumber /* NSUInteger */ *)index withPointInWindowCoordinates:(NSArray <NSNumber *> /* CGPoint */ *)point isTouching:(NSNumber /* BOOL */ *)isTouching
{
    if (_role == GeneratedTouchesDebugWindowRoleClient) {
        [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_updateDebugIndicatorForTouch:withPointInWindowCoordinates:isTouching:)), @"arguments": [NSArray arrayWithObjects:index, point, isTouching, nil] }];
        return;
    }
    
    if (!self.shouldShowTouches)
        return;
    
    CHDebugLogSource(@"updateDebugIndicatorForTouch %@ %@ %@", index, point, [isTouching boolValue] ? @"YES" : @"NO");
    
    [self initDebugViewsIfNeeded];

    static CGFloat screenScale;
    static CGSize screenSize;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        screenScale = [[UIScreen mainScreen] scale];
        screenSize = [[UIScreen mainScreen] nativeBounds].size;
        screenSize.width /= screenScale;
        screenSize.height /= screenScale;
    });
    
    NSUInteger cIndex = [index unsignedIntegerValue];
    if (cIndex < self.debugTouchViews.count) {
        self.debugTouchViews[cIndex].hidden = ![isTouching boolValue];
        self.debugTouchViews[cIndex].center = CGPointMake(screenSize.width * [point[0] doubleValue], screenSize.height * [point[1] doubleValue]);
    }
}

- (void)makeToast:(NSString *)message
         duration:(NSTimeInterval)duration
         position:(id)position
      orientation:(UIInterfaceOrientation)orientation
{
    return [self _makeToast:message duration:@(duration) position:position orientation:@(orientation)];
}

- (void)_makeToast:(NSString *)message
          duration:(NSNumber *)duration
          position:(NSString *)position
       orientation:(NSNumber *)orientation
{
    if (_role == GeneratedTouchesDebugWindowRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(_makeToast:duration:position:orientation:)), @"arguments": [NSArray arrayWithObjects:message, duration, position, orientation, nil] }];
        }
        return;
    }
    
    if (!self.shouldShowTouches)
        return;
    
    CHDebugLogSource(@"makeToast: %@ duration: %@ position: %@ orientation: %@", message, duration, position, orientation);
    
    [self initDebugViewsIfNeeded];
    
    UIView *targetView = [self.debugToastWindows[orientation] rootViewController].view;
    [targetView makeToast:message duration:[duration doubleValue] position:position];
}

- (void)hideToasts
{
    if (_role == GeneratedTouchesDebugWindowRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(hideToasts)), @"arguments": [NSArray array] }];
        }
        return;
    }
    
    CHDebugLogSource(@"hideToasts");
    
    for (NSNumber *orient in self.debugToastWindows) {
        PassWindow *window = self.debugToastWindows[orient];
        UIView *parentView = [[window rootViewController] view];
        UIView *toastView = [[parentView subviews] firstObject];
        if (toastView) {
            [parentView hideToast:toastView];
        }
    }
}

- (void)showToastActivity
{
    if (_role == GeneratedTouchesDebugWindowRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(showToastActivity)), @"arguments": [NSArray array] }];
        }
        return;
    }
    
    if (!self.shouldShowTouches)
        return;
    
    CHDebugLogSource(@"showToastActivity");
    
    [self initDebugViewsIfNeeded];
    [self.debugToastWindows[@(UIInterfaceOrientationPortrait)] makeToastActivity:XXTEToastPositionCenter];
}

- (void)hideToastActivity
{
    if (_role == GeneratedTouchesDebugWindowRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(hideToastActivity)), @"arguments": [NSArray array] }];
        }
        return;
    }
    
    if (!self.shouldShowTouches)
        return;
    
    CHDebugLogSource(@"hideToastActivity");
    
    [self initDebugViewsIfNeeded];
    [self.debugToastWindows[@(UIInterfaceOrientationPortrait)] hideToastActivity];
}

- (void)setLogBarColorInHexString:(NSString *)hexString
{
    if (_role == GeneratedTouchesDebugWindowRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{ @"selector": NSStringFromSelector(@selector(setLogBarColorInHexString:)), @"arguments": [NSArray arrayWithObjects:hexString, nil] }];
        }
        return;
    }
    
    @autoreleasepool {
        if ([NSThread isMainThread]) {
            [_sharedDebugLabel setBackgroundColor:[UIColor xxte_colorWithHex:hexString]];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool {
                    [_sharedDebugLabel setBackgroundColor:[UIColor xxte_colorWithHex:hexString]];
                }
            });
        }
    }
}

@end
