//
//  DeviceConfigurator.m
//  DeviceConfigurator
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <notify.h>
#import "pac_helper.h"
#import "DeviceConfigurator.h"
#import <rocketbootstrap/rocketbootstrap.h>
#import <Foundation/NSUserDefaults+Private.h>
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>


#pragma mark -

@interface SBIdleTimerGlobalCoordinator : NSObject
+ (instancetype)sharedInstance;
- (void)resetIdleTimer;
@end

@interface UIApplication (Private)
- (void)resetIdleTimerAndUndim;
- (UIInterfaceOrientation)_frontMostAppOrientation;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (void)remoteLock:(BOOL)arg1;
- (BOOL)isUILocked;
- (void)attemptUnlockWithPasscode:(NSString *)arg1;
- (void)attemptUnlockWithPasscode:(NSString *)arg1 finishUIUnlock:(BOOL)arg2 completion:(/*^block*/ id)arg3;
@end

@interface SBOrientationLockManager : NSObject
+ (instancetype)sharedInstance;
- (void)lock;
- (void)unlock;
- (BOOL)isLocked;
- (BOOL)isUserLocked;
- (BOOL)isEffectivelyLocked;
@end

@interface BBAction : NSObject
+ (BBAction *)actionWithLaunchBundleID:(NSString *)arg1 callblock:(/*^block*/ id)arg2;
@end

@interface BBBulletin : NSObject
@property (nonatomic, copy) NSString *header;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *sectionID;
@property (nonatomic, copy) NSString *bulletinID;
@property (nonatomic, copy) NSString *publisherBulletinID;
@property (nonatomic, copy) NSString *recordID;
@property (assign, nonatomic) BOOL clearable;
@property (assign, nonatomic) BOOL turnsOnDisplay;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSDate *lastInterruptDate;
@property (nonatomic, strong) NSDate *publicationDate;
@property (nonatomic, copy) BBAction *defaultAction;
@end

@interface BBBulletinRequest : BBBulletin
@end

@interface BBServer : NSObject
- (void)publishBulletinRequest:(BBBulletinRequest *)bulletin
                  destinations:(NSUInteger)dest;
@end

@interface SBWiFiManager : NSObject
+ (instancetype)sharedInstance;
- (void)setPowered:(BOOL)arg1;
- (void)setWiFiEnabled:(BOOL)arg1;
- (NSString *)currentNetworkName;
- (BOOL)wiFiEnabled;
@end

@interface PSCellularDataSettingsDetail : NSObject
+ (void)setEnabled:(BOOL)arg1;
+ (BOOL)deviceSupportsCellularData;
+ (BOOL)isEnabled;
@end

@interface BluetoothManager : NSObject
+ (instancetype)sharedInstance;
- (void)setEnabled:(BOOL)arg1;
- (BOOL)enabled;
@end

@interface SBAirplaneModeController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isInAirplaneMode;
- (void)setInAirplaneMode:(BOOL)arg1;
@end

@interface VPNConnection : NSObject
- (BOOL)connected;
- (BOOL)disconnected;
- (void)connect;
- (void)disconnect;
- (void)setEnabled:(BOOL)arg1;
- (BOOL)enabled;
@end

@interface VPNConnectionStore : NSObject
+ (instancetype)sharedInstance;
- (VPNConnection *)currentConnectionWithGrade:(unsigned long long)arg1;
- (unsigned long long)currentOnlyConnectionGrade;
@end

@interface SBRingerControl : NSObject
- (float)volume;
- (void)setVolume:(float)arg1;
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)arg1;
- (BOOL)lastSavedRingerMutedState;
- (void)activateRingerHUDFromMuteSwitch:(int)arg1;
- (void)activateRingerHUDForVolumeChangeWithInitialVolume:(float)arg1;
- (void)setVolume:(float)arg1 forKeyPress:(BOOL)arg2;
- (void)_softMuteChanged:(id)arg1;
- (void)activateRingerHUD:(int)arg1 withInitialVolume:(float)arg2 fromSource:(unsigned long long)arg3;
- (void)hideRingerHUDIfVisible;
- (void)toggleRingerMute;
@end

@interface SBVolumeControl : NSObject
+ (instancetype)sharedInstance;
- (void)increaseVolume;
- (void)decreaseVolume;
- (float)volumeStepUp;
- (float)volumeStepDown;
- (void)setVolume:(float)arg1 forCategory:(id)arg2;
- (void)setActiveCategoryVolume:(float)arg1;
- (void)_presentVolumeHUDWithVolume:(float)arg1;
- (float)_effectiveVolume;
- (void)_updateEffectiveVolume:(float)arg1;
@end

@interface SBBacklightController : NSObject
@property (nonatomic, readonly) BOOL screenIsOn;
@property (nonatomic, readonly) BOOL screenIsDim;
- (void)turnOnScreenFullyWithBacklightSource:(long long)arg1;
+ (instancetype)sharedInstance;
- (void)setBacklightFactor:(float)arg1 source:(long long)arg2;
- (double)backlightFactor;
@end

@interface SBBrightnessController : NSObject
+ (instancetype)sharedBrightnessController;
- (void)_setBrightnessLevel:(float)arg1 showHUD:(BOOL)arg2;
- (void)setBrightnessLevel:(float)arg1 ;
@end

@interface SBDisplayBrightnessController : NSObject
- (void)_setBrightnessLevel:(float)arg1 showHUD:(BOOL)arg2;
- (void)setBrightnessLevel:(float)arg1 ;
@end

@interface PSAssistiveTouchSettingsDetail : NSObject
+ (void)setEnabled:(BOOL)arg1;
+ (BOOL)isEnabled;
@end

@interface AXMotionController : NSObject
@property (nonatomic, retain) id reduceMotionReduceSlideTransitionsSpecifier;
- (void)_updateReduceSlideTransitionsSpecifiersAnimated:(BOOL)arg1;
- (NSNumber *)reduceMotionEnabled:(id)arg1;
- (void)setReduceMotionEnabled:(NSNumber *)arg1 specifier:(id)arg2;
@end

@interface SafariDeveloperSettingsController : NSObject
- (void)setRemoteInspectorEnabled:(NSNumber *)arg1 specifier:(id)arg2;
- (NSNumber *)remoteInspectorEnabled:(id)arg1;
- (void)setRemoteAutomationEnabled:(NSNumber *)arg1 specifier:(id)arg2;
- (NSNumber *)_remoteAutomationEnabled:(id)arg1;
- (void)_setRemoteInspectorEnabled:(BOOL)arg1;
- (void)_setRemoteAutomationEnabled:(BOOL)arg1;
- (BOOL)isJavaScriptRestricted:(id)arg1;
- (NSNumber *)isJavaScriptEnabled:(id)arg1;
@end

@interface UISUserInterfaceStyleMode : NSObject
@property (nonatomic, assign) UIUserInterfaceStyle modeValue;
@end

@interface PSSpecifier : NSObject
- (NSString *)identifier;
- (void)performSetterWithValue:(id)value;
@end

@interface DBSSettingsController : NSObject
- (NSNumber *)screenLock:(id)arg1;
- (void)setScreenLock:(NSNumber *)arg1 specifier:(id)arg2;
- (NSNumber *)getAutomaticAppearanceEnabledForSpecifier:(id)arg1;
- (void)setAutomaticAppearanceEnabled:(NSNumber *)arg1 forSpecifier:(id)arg2;
- (UISUserInterfaceStyleMode *)_styleMode;
- (void)_updateDeviceAppearanceToNewInterfaceStyle:(UIUserInterfaceStyle)arg1;  // 1 light 2 dark
- (NSNumber *)boldTextEnabledForSpecifier:(id)arg1 ;
- (void)setBoldTextEnabled:(NSNumber *)arg1 specifier:(id)arg2 ;
@end

@interface DBSLargeTextSliderListController : NSObject
- (void)loadView;
- (NSArray <PSSpecifier *> *)specifiers;
- (void)setDynamicTypeValue:(NSNumber *)arg1 forSpecifier:(PSSpecifier *)arg2;
- (NSNumber *)getDynamicTypeValueForSpecifier:(PSSpecifier *)arg1;
@end

@interface DBSDisplayZoomMode : NSObject
- (NSUInteger)displayZoomOption;  // 0 Standard 1 Zoomed
@end

@interface DBSDisplayZoomConfigurationController : NSObject
+ (instancetype)defaultController;
- (DBSDisplayZoomMode *)currentDisplayZoomMode;
- (NSDictionary <NSString *, DBSDisplayZoomMode *> *)displayZoomModes;  // Standard, Zoomed
- (void)setDisplayZoomMode:(DBSDisplayZoomMode *)arg1 withRelaunchURL:(NSURL *)arg2;
@end

@interface SBRestartManager : NSObject
- (void)shutdownForReason:(id)arg1;
- (void)rebootForReason:(id)arg1;
@end

@interface SpringBoard : UIApplication
+ (SpringBoard *)sharedApplication;
- (void)beginIgnoringInteractionEvents;
- (void)endIgnoringInteractionEvents;
- (void)takeScreenshot;
- (SBRestartManager *)restartManager;
- (void)suspend;
@end

@interface SBDisplayItem : NSObject
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface SBAppLayout : NSObject
- (NSArray <SBDisplayItem *> *)allItems;  // iOS 14
- (NSDictionary <NSNumber *, SBDisplayItem *> *)rolesToLayoutItemsMap;  // iOS 13
@end

@interface SBMainSwitcherViewController : UIViewController
+ (instancetype)sharedInstance;
- (NSArray <SBAppLayout *> *)recentAppLayouts;
- (void)_deleteAppLayoutsMatchingBundleIdentifier:(NSString *)arg1;  // iOS 14
- (void)_deleteAppLayout:(SBAppLayout *)arg1 forReason:(long long)arg2;  // iOS 13
@end

@interface InternationalSettingsController : NSObject
+ (void)setPreferredLanguages:(NSArray <NSString *> *)arg1;
+ (void)setLanguage:(NSString *)arg1;
- (void)setLocaleOnly:(NSString *)arg1;
+ (void)syncPreferencesAndPostNotificationForLanguageChange;
@end

@interface ALCity : NSObject
@end

static ALCity *(*PSCityForTimeZone)(CFTimeZoneRef timeZone);

@interface PSGDateTimeController : NSObject
- (NSArray <PSSpecifier *> *)specifiers;
- (void)reloadTimezone;
- (PSSpecifier *)timeZoneSpecifier;
- (void)setUseAutomaticTime:(NSNumber *)arg1 specifier:(id)arg2;
- (void)setTimeZoneValue:(ALCity *)arg1 specifier:(id)arg2;
@end

@interface PSTimeZoneController : UITableViewController
+ (void)setTimeZone:(NSString *)arg1;
@end

@interface PSGAboutController : NSObject
- (void)setDeviceName:(NSString *)arg1 specifier:(id)arg2 ;
- (NSString *)deviceName:(id)arg1 ;
@end

NS_INLINE
NSString *InternationalSettingsExtractLanguageCode(NSString *languageCode) {
    languageCode = [languageCode stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    if ([languageCode hasPrefix:@"zh"]) {
        if ([languageCode hasPrefix:@"zh-Hans"] || [languageCode hasPrefix:@"zh-CN"])
            return @"zh-Hans";
        else if ([languageCode isEqualToString:@"zh-Hant-HK"] || [languageCode hasPrefix:@"zh-HK"])
            return @"zh-Hant-HK";
        else
            return @"zh-Hant";
    } else if ([languageCode hasPrefix:@"en"]) {
        if ([languageCode isEqualToString:@"en-US"])
            return @"en-US";
        else if ([languageCode isEqualToString:@"en-GB"])
            return @"en-GB";
        else if ([languageCode isEqualToString:@"en-AU"])
            return @"en-AU";
        else if ([languageCode isEqualToString:@"en-IN"])
            return @"en-IN";
        else
            return @"en";
    } else if ([languageCode hasPrefix:@"es"]) {
        if ([languageCode isEqualToString:@"es-MX"])
            return @"es-MX";
        else if ([languageCode isEqualToString:@"es-US"])
            return @"es-US";
        else if ([languageCode isEqualToString:@"es-419"])
            return @"es-419";
        else
            return @"es";
    } else if ([languageCode hasPrefix:@"fr"]) {
        if ([languageCode isEqualToString:@"fr-CA"])
            return @"fr-CA";
        else
            return @"fr";
    } else if ([languageCode hasPrefix:@"ja"]) {
        return @"ja";
    } else if ([languageCode hasPrefix:@"de"]) {
        return @"de";
    } else if ([languageCode hasPrefix:@"ru"]) {
        return @"ru";
    } else if ([languageCode hasPrefix:@"pt"]) {
        if ([languageCode isEqualToString:@"pt-BR"])
            return @"pr-BR";
        else
            return @"pt-PT";
    } else if ([languageCode hasPrefix:@"it"]) {
        return @"it";
    } else if ([languageCode hasPrefix:@"ko"]) {
        return @"ko";
    } else if ([languageCode hasPrefix:@"tr"]) {
        return @"tr";
    } else if ([languageCode hasPrefix:@"nl"]) {
        return @"nl";
    } else if ([languageCode hasPrefix:@"ar"]) {
        return @"ar";
    } else if ([languageCode hasPrefix:@"th"]) {
        return @"th";
    } else if ([languageCode hasPrefix:@"sv"]) {
        return @"sv";
    } else if ([languageCode hasPrefix:@"da"]) {
        return @"da";
    } else if ([languageCode hasPrefix:@"vi"]) {
        return @"vi";
    } else if ([languageCode hasPrefix:@"pl"]) {
        return @"pl";
    } else if ([languageCode hasPrefix:@"fi"]) {
        return @"fi";
    } else if ([languageCode hasPrefix:@"id"]) {
        return @"id";
    } else if ([languageCode hasPrefix:@"he"]) {
        return @"he";
    } else if ([languageCode hasPrefix:@"el"]) {
        return @"el";
    } else if ([languageCode hasPrefix:@"ro"]) {
        return @"ro";
    } else if ([languageCode hasPrefix:@"hu"]) {
        return @"hu";
    } else if ([languageCode hasPrefix:@"cs"]) {
        return @"cs";
    } else if ([languageCode hasPrefix:@"sk"]) {
        return @"sk";
    } else if ([languageCode hasPrefix:@"uk"]) {
        return @"uk";
    } else if ([languageCode hasPrefix:@"hr"]) {
        return @"hr";
    } else if ([languageCode hasPrefix:@"ms"]) {
        return @"ms";
    }
    return @"en";
}


#pragma mark -

static int _sharedDCAlertDismissalToken;
@interface DCAlertController : UIAlertController
@end
@implementation DCAlertController
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self removeAssociatedObject];
}
- (void)dealloc
{
    [self removeAssociatedObject];
    
    CHDebugLogSource(@"");
}
- (void)removeAssociatedObject
{
    NSValue *ptrVal = objc_getAssociatedObject(self, &_sharedDCAlertDismissalToken);
    if (ptrVal) {
        NSInteger *ptr = [ptrVal pointerValue];
        if (ptr) {
            *ptr = 71;
        }
        objc_setAssociatedObject(self, &_sharedDCAlertDismissalToken, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
@end

@interface DCAlertWindow : UIWindow
@end
@implementation DCAlertWindow
- (void)dealloc
{
    CHDebugLogSource(@"");
}
@end


#pragma mark -

@interface DeviceConfigurator (Private)

+ (instancetype)sharedConfiguratorWithRole:(DeviceConfiguratorRole)role;
- (instancetype)initWithRole:(DeviceConfiguratorRole)role;

@property (nonatomic, strong) CPDistributedMessagingCenter *messagingCenter;

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSDictionary *)receiveAndReplyMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;

@end


#pragma mark -

@implementation DeviceConfigurator {
    CPDistributedMessagingCenter *_messagingCenter;
}

+ (instancetype)sharedConfigurator {
    return [self sharedConfiguratorWithRole:DeviceConfiguratorRoleClient];
}

+ (instancetype)sharedConfiguratorWithRole:(DeviceConfiguratorRole)role {
    static DeviceConfigurator *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[DeviceConfigurator alloc] initWithRole:role];
    });
    return _server;
}

- (instancetype)initWithRole:(DeviceConfiguratorRole)role {
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


#pragma mark - Messaging

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSAssert(_role == DeviceConfiguratorRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    NSAssert(sendSucceed, @"cannot send message %@, userInfo = %@", messageName, userInfo);
}

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == DeviceConfiguratorRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    NSAssert(sendErr == nil, @"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    return replyInfo;
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == DeviceConfiguratorRoleServer, @"invalid role");
    
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
    NSAssert(_role == DeviceConfiguratorRoleServer, @"invalid role to receive message");
    
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

- (void)resetIdleTimer
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(resetIdleTimer)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class coordinator = objc_getClass("SBIdleTimerGlobalCoordinator");
        if (coordinator) {
            [[coordinator sharedInstance] resetIdleTimer];
        } else {
            [[UIApplication sharedApplication] resetIdleTimerAndUndim];
        }
    }
}

- (void)lockScreen
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(lockScreen)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class mgrCls = objc_getClass("SBLockScreenManager");
        [[mgrCls sharedInstance] remoteLock:YES];
    }
}

- (void)unlockScreenWithPasscode:(NSString *)passcode
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(unlockScreenWithPasscode:)),
                 @"arguments": [NSArray arrayWithObjects:passcode, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        {   // Turn on backlights
            Class ctrl = objc_getClass("SBBacklightController");
            SBBacklightController *backlightCtrl = [ctrl sharedInstance];
            if ([backlightCtrl respondsToSelector:@selector(turnOnScreenFullyWithBacklightSource:)]) {
                [backlightCtrl turnOnScreenFullyWithBacklightSource:1];
            }
        }
        
        {   // Attempt unlock with passcode
            Class manager = objc_getClass("SBLockScreenManager");
            SBLockScreenManager *screenManager = [manager sharedInstance];
            if ([screenManager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)]) {
                [screenManager attemptUnlockWithPasscode:passcode finishUIUnlock:YES completion:nil];
            } else {
                [screenManager attemptUnlockWithPasscode:passcode];
            }
        }
    }
}

- (BOOL)isScreenLocked {
    return [[self _isScreenLocked][@"reply"] boolValue];
}

- (NSDictionary *)_isScreenLocked
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isScreenLocked)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isScreenLocked -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class mgrCls = objc_getClass("SBLockScreenManager");
        return @{ @"reply": @([[mgrCls sharedInstance] isUILocked]) };
    }
}

- (NSInteger)frontMostAppOrientation
{
    return [[self _frontMostAppOrientation][@"reply"] integerValue];
}

- (NSDictionary *)_frontMostAppOrientation
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_frontMostAppOrientation)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_frontMostAppOrientation -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        return @{ @"reply": @([[UIApplication sharedApplication] _frontMostAppOrientation]) };
    }
}

- (void)lockOrientation
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(lockOrientation)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class manager = objc_getClass("SBOrientationLockManager");
        SBOrientationLockManager *lockMgr = [manager sharedInstance];
        [lockMgr lock];
    }
}

- (void)unlockOrientation
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(unlockOrientation)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class manager = objc_getClass("SBOrientationLockManager");
        SBOrientationLockManager *lockMgr = [manager sharedInstance];
        [lockMgr unlock];
    }
}

- (BOOL)isOrientationLocked
{
    @autoreleasepool {
        return [[self _isOrientationLocked][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isOrientationLocked
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isOrientationLocked)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isOrientationLocked -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class manager = objc_getClass("SBOrientationLockManager");
        SBOrientationLockManager *lockMgr = [manager sharedInstance];
        
        if ([lockMgr respondsToSelector:@selector(isLocked)]) {
            return @{ @"reply": @([lockMgr isLocked]) };
        } else if ([lockMgr respondsToSelector:@selector(isUserLocked)]) {
            return @{ @"reply": @([lockMgr isUserLocked]) };
        } else {
            return @{ @"reply": @([lockMgr isEffectivelyLocked]) };
        }
    }
}

- (void)vibrator
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(vibrator)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

OBJC_EXTERN BBServer *_sharedBBServer;
OBJC_EXTERN dispatch_queue_t _sharedBBServerQueue;

- (void)popBannerWithSectionID:(NSString *)sectionID
                  messageTitle:(NSString *)messageTitle
               messageSubtitle:(NSString *)messageSubtitle
                messageContent:(NSString *)messageContent
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(popBannerWithSectionID:messageTitle:messageSubtitle:messageContent:)),
                @"arguments": [NSArray arrayWithObjects:sectionID, messageTitle, messageSubtitle, messageContent, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        NSDate *date = [NSDate date];
        
        BBBulletinRequest *bulletinRequest = [objc_getClass("BBBulletinRequest") new];
        NSString *randomID = [[NSUUID UUID] UUIDString];
        
        [bulletinRequest setTitle:messageTitle];
        if (messageSubtitle.length > 0) {
            [bulletinRequest setSubtitle:messageSubtitle];
        }
        if (messageContent.length > 0) {
            [bulletinRequest setMessage:messageContent];
        }
        [bulletinRequest setSectionID:sectionID];
        [bulletinRequest setRecordID:randomID];
        [bulletinRequest setPublisherBulletinID:randomID];
        [bulletinRequest setClearable:YES];
        [bulletinRequest setTurnsOnDisplay:YES];
        [bulletinRequest setDate:date];
        [bulletinRequest setPublicationDate:date];
        [bulletinRequest setLastInterruptDate:date];
        [bulletinRequest setDefaultAction:[objc_getClass("BBAction") actionWithLaunchBundleID:sectionID callblock:nil]];
        
        dispatch_async(_sharedBBServerQueue, ^{
            if (@available(iOS 14.0, *))
            {
                [_sharedBBServer publishBulletinRequest:bulletinRequest destinations:270];  // 0b10001110
            }
            else
            {
                [_sharedBBServer publishBulletinRequest:bulletinRequest destinations:14];   // 0b00001110
            }
        });
    }
}

- (void)turnOnWiFi
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnWiFi)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        SBWiFiManager *mgr = [objc_getClass("SBWiFiManager") sharedInstance];
        [mgr setPowered:YES];
        [mgr setWiFiEnabled:YES];
    }
}

- (void)turnOffWiFi
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffWiFi)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        SBWiFiManager *mgr = [objc_getClass("SBWiFiManager") sharedInstance];
        [mgr setPowered:YES];
        [mgr setWiFiEnabled:NO];
    }
}

- (BOOL)isWiFiEnabled
{
    @autoreleasepool {
        return [[self _isWiFiEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isWiFiEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isWiFiEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isWiFiEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        SBWiFiManager *mgr = [objc_getClass("SBWiFiManager") sharedInstance];
        return @{ @"reply": @([mgr wiFiEnabled]) };
    }
}

- (void)turnOnCellular
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnCellular)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class cellularCls = objc_getClass("PSCellularDataSettingsDetail");
        if ([cellularCls deviceSupportsCellularData]) {
            [cellularCls setEnabled:YES];
        }
    }
}

- (void)turnOffCellular
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffCellular)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class cellularCls = objc_getClass("PSCellularDataSettingsDetail");
        if ([cellularCls deviceSupportsCellularData]) {
            [cellularCls setEnabled:NO];
        }
    }
}

- (BOOL)isCellularEnabled
{
    @autoreleasepool {
        return [[self _isCellularEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isCellularEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isCellularEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isCellularEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class cellularCls = objc_getClass("PSCellularDataSettingsDetail");
        if ([cellularCls deviceSupportsCellularData]) {
            return @{ @"reply": @([cellularCls isEnabled]) };
        }
        return @{ @"reply": @(NO) };
    }
}

- (void)turnOnBluetooth
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnBluetooth)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class bluetoothCls = objc_getClass("BluetoothManager");
        [[bluetoothCls sharedInstance] setEnabled:YES];
    }
}

- (void)turnOffBluetooth
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffBluetooth)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class bluetoothCls = objc_getClass("BluetoothManager");
        [[bluetoothCls sharedInstance] setEnabled:NO];
    }
}

- (BOOL)isBluetoothEnabled
{
    @autoreleasepool {
        return [[self _isBluetoothEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isBluetoothEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isBluetoothEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isBluetoothEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class bluetoothCls = objc_getClass("BluetoothManager");
        return @{ @"reply": @([[bluetoothCls sharedInstance] enabled]) };
    }
}

- (void)turnOnAirplane
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnAirplane)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class airplaneCls = objc_getClass("SBAirplaneModeController");
        [[airplaneCls sharedInstance] setInAirplaneMode:YES];
    }
}

- (void)turnOffAirplane
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffAirplane)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class airplaneCls = objc_getClass("SBAirplaneModeController");
        [[airplaneCls sharedInstance] setInAirplaneMode:NO];
    }
}

- (BOOL)isAirplaneEnabled
{
    @autoreleasepool {
        return [[self _isAirplaneEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isAirplaneEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isAirplaneEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isAirplaneEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        Class airplaneCls = objc_getClass("SBAirplaneModeController");
        return @{ @"reply": @([[airplaneCls sharedInstance] isInAirplaneMode]) };
    }
}

+ (void)loadVPNPreferencesBundle
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/VPNPreferences.bundle"] load];
    });
}

- (void)turnOnVPN
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnVPN)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [DeviceConfigurator loadVPNPreferencesBundle];
        VPNConnectionStore *store = [objc_getClass("VPNConnectionStore") sharedInstance];
        unsigned long long grade = [store currentOnlyConnectionGrade];
        VPNConnection *vpn = [store currentConnectionWithGrade:grade];
        [vpn connect];
    }
}

- (void)turnOffVPN
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffVPN)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [DeviceConfigurator loadVPNPreferencesBundle];
        VPNConnectionStore *store = [objc_getClass("VPNConnectionStore") sharedInstance];
        unsigned long long grade = [store currentOnlyConnectionGrade];
        VPNConnection *vpn = [store currentConnectionWithGrade:grade];
        [vpn disconnect];
    }
}

- (BOOL)isVPNEnabled
{
    @autoreleasepool {
        return [[self _isVPNEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isVPNEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isVPNEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isVPNEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [DeviceConfigurator loadVPNPreferencesBundle];
        VPNConnectionStore *store = [objc_getClass("VPNConnectionStore") sharedInstance];
        unsigned long long grade = [store currentOnlyConnectionGrade];
        VPNConnection *vpn = [store currentConnectionWithGrade:grade];
        return @{ @"reply": @([vpn connected]) };
    }
}

- (void)turnOnFlashWithLevel:(double)level
{
    [self _turnOnFlashWithLevel:@(level)];
}

- (void)_turnOnFlashWithLevel:(NSNumber *)level
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_turnOnFlashWithLevel:)),
                @"arguments": [NSArray arrayWithObjects:level, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasFlash]) {
            [device lockForConfiguration:nil];
            [device setTorchModeOnWithLevel:(float)[level doubleValue] error:nil];
            [device unlockForConfiguration];
        }
    }
}

- (void)turnOffFlash
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffFlash)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasFlash]) {
            [device lockForConfiguration:nil];
            [device setTorchMode:AVCaptureTorchModeOff];
            [device unlockForConfiguration];
        }
    }
}

- (BOOL)isFlashEnabled
{
    @autoreleasepool {
        return [[self _isFlashEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isFlashEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isFlashEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isFlashEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasFlash]) {
            [device lockForConfiguration:nil];
            AVCaptureTorchMode torchMode = [device torchMode];
            [device unlockForConfiguration];
            return @{ @"reply": @(torchMode == AVCaptureTorchModeOn) };
        }
        return @{ @"reply": @(NO) };
    }
}

OBJC_EXTERN SBRingerControl *_globalRingerControl;

- (void)turnOnRingerMute
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnRingerMute)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [_globalRingerControl setRingerMuted:YES];
        [_globalRingerControl activateRingerHUDFromMuteSwitch:0];
    }
}

- (void)turnOffRingerMute
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffRingerMute)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [_globalRingerControl setRingerMuted:NO];
        [_globalRingerControl activateRingerHUDFromMuteSwitch:1];
    }
}

- (BOOL)isRingerMuteEnabled
{
    @autoreleasepool {
        return [[self _isRingerMuteEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isRingerMuteEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isRingerMuteEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isRingerMuteEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        return @{ @"reply": @([_globalRingerControl isRingerMuted]) };
    }
}

- (void)setCurrentVolume:(double)volume
{
    [self _setCurrentVolume:@(volume)];
}

- (void)_setCurrentVolume:(NSNumber *)volume
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_setCurrentVolume:)),
                @"arguments": [NSArray arrayWithObjects:volume, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        float newVol = (float)[volume doubleValue];
        SBVolumeControl *volCtrl = [objc_getClass("SBVolumeControl") sharedInstance];
        [volCtrl setActiveCategoryVolume:newVol];
        [volCtrl _presentVolumeHUDWithVolume:newVol];
    }
}

OBJC_EXTERN SBDisplayBrightnessController *_globalBrightnessController;

- (void)setBacklightLevel:(double)level
{
    [self _setBacklightLevel:@(level)];
}

- (void)_setBacklightLevel:(NSNumber *)level
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_setBacklightLevel:)),
                @"arguments": [NSArray arrayWithObjects:level, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        static SBDisplayBrightnessController *brightnessCtrl = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            brightnessCtrl = [[objc_getClass("SBDisplayBrightnessController") alloc] init];
        });
        if (brightnessCtrl)
            [brightnessCtrl _setBrightnessLevel:(float)[level doubleValue] showHUD:YES];
        else
            [[objc_getClass("SBBrightnessController") sharedBrightnessController] _setBrightnessLevel:(float)[level doubleValue] showHUD:YES];
    }
}

- (double)backlightLevel
{
    @autoreleasepool {
        return [[self _backlightLevel][@"reply"] doubleValue];
    }
}

- (NSDictionary *)_backlightLevel
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_backlightLevel)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_backlightLevel -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        return @{ @"reply": @([[UIScreen mainScreen] brightness]) };
    }
}

- (void)turnOnAssistiveTouch
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnAssistiveTouch)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [objc_getClass("PSAssistiveTouchSettingsDetail") setEnabled:YES];
    }
}

- (void)turnOffAssistiveTouch
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffAssistiveTouch)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [objc_getClass("PSAssistiveTouchSettingsDetail") setEnabled:NO];
    }
}

- (BOOL)isAssistiveTouchEnabled
{
    @autoreleasepool {
        return [[self _isAssistiveTouchEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isAssistiveTouchEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isAssistiveTouchEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isAssistiveTouchEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        return @{ @"reply": @([objc_getClass("PSAssistiveTouchSettingsDetail") isEnabled]) };
    }
}

OBJC_EXTERN void reinitializeHooks(void);

+ (void)loadAccessibilitySettingsBundle
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/AccessibilitySettings.bundle"] load];
        reinitializeHooks();
    });
}

+ (AXMotionController *)sharedMotionController
{
    static AXMotionController *motionCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadAccessibilitySettingsBundle];
        motionCtrl = [[objc_getClass("AXMotionController") alloc] init];
    });
    return motionCtrl;
}

- (void)turnOnReduceMotion
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnReduceMotion)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [[DeviceConfigurator sharedMotionController] setReduceMotionEnabled:@(YES) specifier:nil];
    }
}

- (void)turnOffReduceMotion
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffReduceMotion)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [[DeviceConfigurator sharedMotionController] setReduceMotionEnabled:@(NO) specifier:nil];
    }
}

- (BOOL)isReduceMotionEnabled
{
    @autoreleasepool {
        return [[self _isReduceMotionEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isReduceMotionEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isReduceMotionEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isReduceMotionEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        return @{ @"reply": @([[[DeviceConfigurator sharedMotionController] reduceMotionEnabled:nil] boolValue]) };
    }
}

+ (void)loadMobileSafariSettingsBundle
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/MobileSafariSettings.bundle"] load];
    });
}

+ (SafariDeveloperSettingsController *)sharedSafariDeveloperSettingsController
{
    static SafariDeveloperSettingsController *safariCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadMobileSafariSettingsBundle];
        safariCtrl = [[objc_getClass("SafariDeveloperSettingsController") alloc] init];
    });
    return safariCtrl;
}

- (void)turnOnRemoteInspector
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOnRemoteInspector)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [[DeviceConfigurator sharedSafariDeveloperSettingsController] setRemoteInspectorEnabled:@(YES) specifier:nil];
    }
}

- (void)turnOffRemoteInspector
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                 @"selector": NSStringFromSelector(@selector(turnOffRemoteInspector)),
                 @"arguments": [NSArray array],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [[DeviceConfigurator sharedSafariDeveloperSettingsController] setRemoteInspectorEnabled:@(NO) specifier:nil];
    }
}

- (BOOL)isRemoteInspectorEnabled
{
    @autoreleasepool {
        return [[self _isRemoteInspectorEnabled][@"reply"] boolValue];
    }
}

- (NSDictionary *)_isRemoteInspectorEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isRemoteInspectorEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isRemoteInspectorEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        return @{ @"reply": @([[[DeviceConfigurator sharedSafariDeveloperSettingsController] remoteInspectorEnabled:nil] boolValue]) };
    }
}

+ (void)loadDisplayAndBrightnessSettingsFramework
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Settings/DisplayAndBrightnessSettings.framework"] load];
    });
}

+ (DBSSettingsController *)sharedDBSSettingsController
{
    static DBSSettingsController *dbsCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadDisplayAndBrightnessSettingsFramework];
        dbsCtrl = [[objc_getClass("DBSSettingsController") alloc] init];
    });
    return dbsCtrl;
}

- (void)setAutoLockTimeInSeconds:(NSTimeInterval)seconds
{
    [self _setAutoLockTimeInMinutes:@(seconds)];
}

- (void)_setAutoLockTimeInMinutes:(NSNumber *)seconds
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_setAutoLockTimeInMinutes:)),
                @"arguments": [NSArray arrayWithObjects:seconds, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        [[DeviceConfigurator sharedDBSSettingsController] setScreenLock:@((NSInteger)round([seconds doubleValue])) specifier:nil];
    }
}

- (NSTimeInterval)autoLockTimeInSeconds
{
    @autoreleasepool {
        return [[self _autoLockTimeInMinutes][@"reply"] doubleValue];
    }
}

- (NSDictionary *)_autoLockTimeInMinutes
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_autoLockTimeInMinutes)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_autoLockTimeInMinutes -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        return @{ @"reply": @([[[DeviceConfigurator sharedDBSSettingsController] screenLock:nil] integerValue]) };
    }
}

- (NSInteger)popAlertWithTimeout:(NSTimeInterval)timeout
                    messageTitle:(NSString *)messageTitle
                  messageContent:(NSString *)messageContent
                    buttonTitles:(NSArray <NSString *> *)buttonTitles
{
    @autoreleasepool {
        NSNumber *replyNumber = [self _popAlertWithTimeout:@(timeout)
                                              messageTitle:messageTitle
                                            messageContent:messageContent
                                              buttonTitles:buttonTitles
                                                textFields:nil
                                     textFieldPlaceholders:nil][@"reply"];
        if (!replyNumber) {
            return 71;  // xpc died
        }
        return [replyNumber integerValue];
    }
}

- (nullable NSDictionary *)popAlertWithTimeout:(NSTimeInterval)timeout
                                  messageTitle:(NSString *)messageTitle
                                messageContent:(NSString *)messageContent
                                  buttonTitles:(NSArray<NSString *> *)buttonTitles
                                    textFields:(nullable NSArray<NSString *> *)textFields
                         textFieldPlaceholders:(nullable NSArray<NSString *> *)textFieldPlaceholders
{
    return [self _popAlertWithTimeout:@(timeout)
                         messageTitle:messageTitle
                       messageContent:messageContent
                         buttonTitles:buttonTitles
                           textFields:textFields
                textFieldPlaceholders:textFieldPlaceholders][@"reply"];
}

- (NSDictionary *)_popAlertWithTimeout:(NSNumber *)timeout
                          messageTitle:(NSString *)messageTitle
                        messageContent:(NSString *)messageContent
                          buttonTitles:(NSArray <NSString *> *)buttonTitles
                            textFields:(nullable NSArray <NSString *> *)textFields
                 textFieldPlaceholders:(nullable NSArray <NSString *> *)textFieldPlaceholders
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_popAlertWithTimeout:messageTitle:messageContent:buttonTitles:textFields:textFieldPlaceholders:)),
                @"arguments": [NSArray arrayWithObjects:timeout, messageTitle, messageContent, buttonTitles, textFields, textFieldPlaceholders, nil],
            }];
            
            CHDebugLog(@"_popAlertWithTimeout: %@ messageTitle: %@ messageContent: %@ buttonTitles: %@ textFields: %@ textFieldPlaceholders: %@ -> %@", timeout, messageTitle, messageContent, buttonTitles, textFields, textFieldPlaceholders, replyObject);
            
            id replyInnerObject = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyInnerObject isKindOfClass:[NSNumber class]] || [replyInnerObject isKindOfClass:[NSDictionary class]],
                     @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        if (!buttonTitles.count) {
            buttonTitles = @[ @"OK" ];
        }
        
        DCAlertController *alertCtrl = [DCAlertController alertControllerWithTitle:(messageTitle.length > 0 ? messageTitle : @"Script Message")
                                                                           message:messageContent
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        
        __block NSInteger selectedActionIndex = NSNotFound;
        objc_setAssociatedObject(alertCtrl, &_sharedDCAlertDismissalToken, [NSValue valueWithPointer:&selectedActionIndex], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        NSMutableArray <UIAlertAction *> *alertActions = [NSMutableArray arrayWithCapacity:3];
        for (NSInteger buttonIndex = 0; buttonIndex < MIN(buttonTitles.count, 3); buttonIndex++) {
            NSString *buttonTitle = buttonTitles[buttonIndex];
            
            __weak typeof(alertCtrl) weakAlertCtrl = alertCtrl;
            UIAlertAction *alertAction = [UIAlertAction actionWithTitle:buttonTitle
                                                                  style:(buttonIndex == 0 ? UIAlertActionStyleCancel : UIAlertActionStyleDefault)
                                                                handler:^(UIAlertAction * _Nonnull action) {
                if (weakAlertCtrl)
                    objc_setAssociatedObject(weakAlertCtrl, &_sharedDCAlertDismissalToken, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                
                selectedActionIndex = [alertActions indexOfObject:action];
            }];
            
            [alertActions addObject:alertAction];
            [alertCtrl addAction:alertAction];
        }
        
        for (NSInteger textFieldIndex = 0; textFieldIndex < MIN(MAX(textFields.count, textFieldPlaceholders.count), 2); textFieldIndex++) {
            NSString *textFieldContent = textFieldIndex < textFields.count ? textFields[textFieldIndex] : @"";
            NSString *textFieldPlaceholder = textFieldIndex < textFieldPlaceholders.count ? textFieldPlaceholders[textFieldIndex] : @"";
            
            [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                textField.text = textFieldContent;
                textField.placeholder = textFieldPlaceholder;
            }];
        }
        
        __block BOOL cancelled = NO; int dismissalToken; {
            __weak typeof(alertCtrl) weakAlertCtrl = alertCtrl;
            notify_register_dispatch(NOTIFY_DISMISSAL_SYS_ALERT, &dismissalToken, dispatch_get_main_queue(), ^(int token) {
                
                cancelled = YES;
                notify_cancel(token);
                
                if (weakAlertCtrl)
                    objc_setAssociatedObject(weakAlertCtrl, &_sharedDCAlertDismissalToken, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                
                selectedActionIndex = 3;  // timeout
                
                [alertCtrl dismissViewControllerAnimated:YES completion:nil];
            });
        }
        
        NSTimeInterval timeoutInSeconds = [timeout doubleValue];
        if (timeoutInSeconds > 1e-3) {
            __weak typeof(alertCtrl) weakAlertCtrl = alertCtrl;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (weakAlertCtrl)
                    objc_setAssociatedObject(weakAlertCtrl, &_sharedDCAlertDismissalToken, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                
                selectedActionIndex = 3;  // timeout
                
                [alertCtrl dismissViewControllerAnimated:YES completion:nil];
            });
        }
        
        UIViewController *presentController = [[UIViewController alloc] init];
        DCAlertWindow *presentWindow = [[DCAlertWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        [presentWindow setRootViewController:presentController];
        [presentWindow setWindowLevel:UIWindowLevelStatusBar + 1];
        [presentWindow setHidden:NO];
        [presentController presentViewController:alertCtrl animated:YES completion:nil];
        
        while (selectedActionIndex == NSNotFound) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
        
        // Remove notification token
        if (!cancelled)
            notify_cancel(dismissalToken);
        
        // Remove associated window
        [[[presentWindow rootViewController] view] removeFromSuperview];
        [presentWindow setRootViewController:nil];
        [presentWindow setHidden:YES];
        [presentWindow setWindowScene:nil];
        
        if (!alertCtrl.textFields.count) {
            return @{ @"reply": @(selectedActionIndex) };
        }
        
        NSMutableArray <NSString *> *textFieldInputs = [NSMutableArray arrayWithCapacity:2];
        for (UITextField *textField in alertCtrl.textFields) {
            [textFieldInputs addObject:(textField.text ?: @"")];
        }
        
        return @{ @"reply": @{
            @"choice": @(selectedActionIndex),
            @"inputs": textFieldInputs,
        } };
    }
}

- (nullable id)objectForKey:(NSString *)key inDomain:(NSString *)domain
{
    return [self _objectForKey:key inDomain:domain][@"reply"];
}

- (nonnull NSDictionary *)_objectForKey:(NSString *)key inDomain:(NSString *)domain
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_objectForKey:inDomain:)),
                @"arguments": [NSArray arrayWithObjects:key, domain, nil],
            }];
            
#if DEBUG
            NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        id replyObject = [[NSUserDefaults standardUserDefaults] objectForKey:key inDomain:domain];
        if (!replyObject) {
            return @{ };
        }
        return @{ @"reply": replyObject };
    }
}

- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(setObject:forKey:inDomain:)),
                @"arguments": [NSArray arrayWithObjects:value, key, domain, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:key inDomain:domain];
    }
}

- (void)darwinNotifyPost:(NSString *)notificationName
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(darwinNotifyPost:)),
                @"arguments": [NSArray arrayWithObjects:notificationName, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)notificationName, NULL, NULL, true);
    }
}

- (void)notifyPost:(NSString *)notificationName
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(notifyPost:)),
                @"arguments": [NSArray arrayWithObjects:notificationName, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        notify_post([notificationName UTF8String]);
    }
}

- (void)removeAppLayoutsMatchingBundleIdentifier:(NSString *)bundleIdentifier
{
    [self removeAppLayoutsMatchingBundleIdentifiers:@[ bundleIdentifier ]];
}

- (void)removeAppLayoutsMatchingBundleIdentifiers:(NSArray <NSString *> *)bundleIdentifiers
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(removeAppLayoutsMatchingBundleIdentifiers:)),
                @"arguments": [NSArray arrayWithObjects:bundleIdentifiers, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        SBMainSwitcherViewController *switcher = [objc_getClass("SBMainSwitcherViewController") sharedInstance];
        for (SBAppLayout *appLayout in [switcher recentAppLayouts]) {
            if (@available(iOS 14.0, *)) {
                NSArray <SBDisplayItem *> *displayItems = [appLayout allItems];
                NSString *bundleIdentifier = [[displayItems firstObject] bundleIdentifier];
                if (![bundleIdentifiers containsObject:bundleIdentifier]) {
                    continue;
                }
                [switcher _deleteAppLayoutsMatchingBundleIdentifier:bundleIdentifier];
            } else {
                SBDisplayItem *displayItem = [appLayout.rolesToLayoutItemsMap objectForKey:@1];
                NSString *bundleIdentifier = [displayItem bundleIdentifier];
                if (![bundleIdentifiers containsObject:bundleIdentifier]) {
                    continue;
                }
                [switcher _deleteAppLayout:appLayout forReason:1];
            }
        }
    }
}

- (void)removeAllAppLayouts
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(removeAllAppLayouts)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        SBMainSwitcherViewController *switcher = [objc_getClass("SBMainSwitcherViewController") sharedInstance];
        for (SBAppLayout *appLayout in [switcher recentAppLayouts]) {
            if (@available(iOS 14.0, *)) {
                NSArray <SBDisplayItem *> *displayItems = [appLayout allItems];
                [switcher _deleteAppLayoutsMatchingBundleIdentifier:[[displayItems firstObject] bundleIdentifier]];
            } else {
                [switcher _deleteAppLayout:appLayout forReason:1];
            }
        }
    }
}

- (void)beginIgnoringInteractionEvents
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(beginIgnoringInteractionEvents)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] beginIgnoringInteractionEvents];
    }
}

- (void)endIgnoringInteractionEvents
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(endIgnoringInteractionEvents)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] endIgnoringInteractionEvents];
    }
}

- (void)takeScreenshot
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(takeScreenshot)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] takeScreenshot];
    }
}

- (void)shutdown
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(shutdown)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [(SBRestartManager *)[(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] restartManager] shutdownForReason:nil];
    }
}

- (void)reboot
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(reboot)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [(SBRestartManager *)[(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] restartManager] rebootForReason:nil];
    }
}

- (void)suspend
{
    if (_role == DeviceConfiguratorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(suspend)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [(SpringBoard *)[objc_getClass("SpringBoard") sharedApplication] suspend];
    }
}

+ (void)loadInternationalSettingsBundle
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/InternationalSettings.bundle"] load];
    });
}

- (NSString *)currentLanguage
{
    return [self _currentLanguage][@"reply"];
}

- (NSDictionary *)_currentLanguage
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_currentLanguage)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_currentLanguage -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        return @{ @"reply": [[NSLocale preferredLanguages] firstObject] };
    }
}

- (void)setCurrentLanguage:(NSString *)language
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(setCurrentLanguage:)),
                @"arguments": [NSArray arrayWithObjects:language, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [DeviceConfigurator loadInternationalSettingsBundle];
                
                NSString *languageCode = InternationalSettingsExtractLanguageCode(language);
                [objc_getClass("InternationalSettingsController") setPreferredLanguages:@[languageCode]];
                [objc_getClass("InternationalSettingsController") setCurrentLanguage:languageCode];
            }
        });
    }
}

- (NSString *)currentLocale
{
    return [self _currentLocale][@"reply"];
}

- (NSDictionary *)_currentLocale
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_currentLocale)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_currentLocale -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        return @{ @"reply": [[NSLocale currentLocale] localeIdentifier] };
    }
}

+ (InternationalSettingsController *)sharedInternationalSettingsController
{
    static InternationalSettingsController *isCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadInternationalSettingsBundle];
        isCtrl = [[objc_getClass("InternationalSettingsController") alloc] init];
    });
    return isCtrl;
}

- (void)setCurrentLocale:(NSString *)locale
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(setCurrentLocale:)),
                @"arguments": [NSArray arrayWithObjects:locale, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [[DeviceConfigurator sharedInternationalSettingsController] setLocaleOnly:locale];
                [objc_getClass("InternationalSettingsController") syncPreferencesAndPostNotificationForLanguageChange];
            }
        });
    }
}

+ (void)loadGeneralSettingsUIFramework
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Settings/GeneralSettingsUI.framework"] load];
    });
}

- (NSString *)currentTimeZone
{
    return [self _currentTimeZone][@"reply"];
}

- (NSDictionary *)_currentTimeZone
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_currentTimeZone)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_currentTimeZone -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        return @{ @"reply": [[NSTimeZone systemTimeZone] name] };
    }
}

+ (PSGDateTimeController *)sharedPSGDateTimeController
{
    static PSGDateTimeController *dtCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadGeneralSettingsUIFramework];
        dtCtrl = [[objc_getClass("PSGDateTimeController") alloc] init];
    });
    return dtCtrl;
}

- (void)setCurrentTimeZone:(NSString *)timeZoneName
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(setCurrentTimeZone:)),
                @"arguments": [NSArray arrayWithObjects:timeZoneName, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [DeviceConfigurator loadGeneralSettingsUIFramework];
                
                MSImageRef PreferencesBinary = MSGetImageByName("/System/Library/PrivateFrameworks/Preferences.framework/Preferences");
                if (PreferencesBinary)
                {
                    PSCityForTimeZone = make_sym_callable(MSFindSymbol(PreferencesBinary, "_PSCityForTimeZone"));
                }
                
                if (PSCityForTimeZone)
                {
                    CFTimeZoneRef timeZone = CFTimeZoneCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)timeZoneName, true);
                    
                    if (timeZone)
                    {
                        ALCity *cityObject = PSCityForTimeZone(timeZone);
                        if (cityObject)
                        {
                            PSGDateTimeController *dateTimeCtrl = [DeviceConfigurator sharedPSGDateTimeController];
                            [dateTimeCtrl reloadTimezone];
                            
                            PSSpecifier *autoTimeZoneSpecifierObject = nil;
                            for (PSSpecifier *specifierObject in [dateTimeCtrl specifiers]) {
                                if ([[specifierObject identifier] isEqualToString:@"SET_AUTOMATICALLY"])
                                {
                                    autoTimeZoneSpecifierObject = specifierObject;
                                    break;
                                }
                            }
                            
                            if (autoTimeZoneSpecifierObject)
                            {
                                [autoTimeZoneSpecifierObject performSetterWithValue:@(NO)];
                            }
                            
                            PSSpecifier *timeZoneSpecifierObject = [dateTimeCtrl timeZoneSpecifier];
                            if (timeZoneSpecifierObject)
                            {
                                [timeZoneSpecifierObject performSetterWithValue:cityObject];
                            }
                            
                            // this is where changes actually happen
                            [objc_getClass("PSTimeZoneController") setCurrentTimeZone:timeZoneName];
                        }
                        
                        CFRelease(timeZone);
                    }
                }
            }
        });
    }
}

- (NSString *)userAssignedDeviceName
{
    return [self _userAssignedName][@"reply"];
}

+ (PSGAboutController *)sharedPSGAboutController
{
    static PSGAboutController *aboutCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadGeneralSettingsUIFramework];
        aboutCtrl = [[objc_getClass("PSGAboutController") alloc] init];
    });
    return aboutCtrl;
}

- (NSDictionary *)_userAssignedName
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_userAssignedName)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_userAssignedName -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        NSString *deviceName = [[DeviceConfigurator sharedPSGAboutController] deviceName:nil];
        return @{ @"reply": deviceName ?: @"" };
    }
}

- (void)setUserAssignedDeviceName:(NSString *)userAssignedDeviceName
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(setUserAssignedDeviceName:)),
                @"arguments": [NSArray arrayWithObjects:userAssignedDeviceName, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [[DeviceConfigurator sharedPSGAboutController] setDeviceName:userAssignedDeviceName specifier:nil];
    }
}

- (UIUserInterfaceStyle)currentInterfaceStyle
{
    return [[self _currentInterfaceStyle][@"reply"] integerValue];
}

- (NSDictionary *)_currentInterfaceStyle
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_currentInterfaceStyle)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_currentInterfaceStyle -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        return @{ @"reply": @([[[DeviceConfigurator sharedDBSSettingsController] _styleMode] modeValue]) };
    }
}

- (void)setCurrentInterfaceStyle:(UIUserInterfaceStyle)interfaceStyle
{
    [self _setCurrentInterfaceStyle:@(interfaceStyle)];
}

- (void)_setCurrentInterfaceStyle:(NSNumber /* NSInteger */ *)interfaceStyle
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_setCurrentInterfaceStyle:)),
                @"arguments": [NSArray arrayWithObjects:interfaceStyle, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [[DeviceConfigurator sharedDBSSettingsController] _updateDeviceAppearanceToNewInterfaceStyle:MIN(MAX([interfaceStyle integerValue], 0), 2)];
    }
}

- (BOOL)boldTextEnabled
{
    return [[self _boldTextEnabled][@"reply"] boolValue];
}

- (NSDictionary *)_boldTextEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_boldTextEnabled)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_boldTextEnabled -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        return @{ @"reply": @([[[DeviceConfigurator sharedDBSSettingsController] boldTextEnabledForSpecifier:nil] boolValue]) };
    }
}

- (void)setBoldTextEnabled:(BOOL)boldTextEnabled
{
    [self _setBoldTextEnabled:@(boldTextEnabled)];
}

- (void)_setBoldTextEnabled:(NSNumber /* BOOL */ *)boldTextEnabled
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_setBoldTextEnabled:)),
                @"arguments": [NSArray arrayWithObjects:boldTextEnabled, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        [[DeviceConfigurator sharedDBSSettingsController] setBoldTextEnabled:@([boldTextEnabled boolValue]) specifier:nil];
    }
}

+ (DBSLargeTextSliderListController *)sharedDBSLargeTextSliderListController
{
    static DBSLargeTextSliderListController *dbsCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadDisplayAndBrightnessSettingsFramework];
        dbsCtrl = [[objc_getClass("DBSLargeTextSliderListController") alloc] init];
        [dbsCtrl loadView];
    });
    return dbsCtrl;
}

- (NSInteger)dynamicTypeValue
{
    return [[self _dynamicTypeValue][@"reply"] integerValue];
}

- (NSDictionary *)_dynamicTypeValue
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_dynamicTypeValue)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_dynamicTypeValue -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        DBSLargeTextSliderListController *ctrl = [DeviceConfigurator sharedDBSLargeTextSliderListController];
        PSSpecifier *spec = [[ctrl specifiers] firstObject];
        return @{ @"reply": @([[ctrl getDynamicTypeValueForSpecifier:spec] integerValue]) };
    }
}

- (void)setDynamicTypeValue:(NSInteger)dynamicTypeValue
{
    [self _setDynamicTypeValue:@(dynamicTypeValue)];
}

- (void)_setDynamicTypeValue:(NSNumber /* NSInteger */ *)dynamicTypeValue
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_setDynamicTypeValue:)),
                @"arguments": [NSArray arrayWithObjects:dynamicTypeValue, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        DBSLargeTextSliderListController *ctrl = [DeviceConfigurator sharedDBSLargeTextSliderListController];
        PSSpecifier *spec = [[ctrl specifiers] firstObject];
        [ctrl setDynamicTypeValue:@(MIN(MAX([dynamicTypeValue integerValue], 0), 11)) forSpecifier:spec];
    }
}

+ (DBSDisplayZoomConfigurationController *)sharedDBSDisplayZoomConfigurationController
{
    static DBSDisplayZoomConfigurationController *dbsCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadDisplayAndBrightnessSettingsFramework];
        dbsCtrl = [objc_getClass("DBSDisplayZoomConfigurationController") defaultController];
    });
    return dbsCtrl;
}

- (BOOL)isZoomedMode
{
    return [[self _isZoomedMode][@"reply"] boolValue];
}

- (NSDictionary *)_isZoomedMode
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_isZoomedMode)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"_isZoomedMode -> %@", replyObject);
            
            NSNumber *replyState = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        return @{ @"reply": @([[[DeviceConfigurator sharedDBSDisplayZoomConfigurationController] currentDisplayZoomMode] displayZoomOption]) };
    }
}

- (void)setZoomedMode:(BOOL)zoomedMode
{
    [self _setZoomedMode:@(zoomedMode)];
}

- (void)_setZoomedMode:(NSNumber /* BOOL */ *)zoomedMode
{
    if (_role == DeviceConfiguratorRoleClient) {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_setZoomedMode:)),
                @"arguments": [NSArray arrayWithObjects:zoomedMode, nil],
            }];
        }
        return;
    }
    
    @autoreleasepool {
        NSAssert([NSThread isMainThread], @"not main thread");
        
        DBSDisplayZoomConfigurationController *ctrl = [DeviceConfigurator sharedDBSDisplayZoomConfigurationController];
        DBSDisplayZoomMode *zoomMode = nil;
        if ([zoomedMode boolValue])
        {
            zoomMode = [ctrl displayZoomModes][@"Zoomed"];
        }
        else
        {
            zoomMode = [ctrl displayZoomModes][@"Standard"];
        }
        
        if (zoomMode && [ctrl.currentDisplayZoomMode displayZoomOption] != [zoomMode displayZoomOption])
        {
            [ctrl setDisplayZoomMode:zoomMode withRelaunchURL:[NSURL URLWithString:@"prefs:root=DISPLAY&path=MAGNIFY"]];
        }
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
        
        DeviceConfigurator *serverInstance = [DeviceConfigurator sharedConfiguratorWithRole:DeviceConfiguratorRoleServer];
        [serverMessagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
        [serverMessagingCenter registerForMessageName:@XPC_TWOWAY_MSG_NAME target:serverInstance selector:@selector(receiveAndReplyMessageName:userInfo:)];
        [serverInstance setMessagingCenter:serverMessagingCenter];
        
        CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", serverMessagingCenter, bundleIdentifier, processName, getpid());
    }
}


#pragma mark - Initializers

CHConstructor
{
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"])
        {   /* Server Process - Device Configurator */
            
            rocketbootstrap_unlock(XPC_INSTANCE_NAME);
        }
        else
        {   /* Client Process - device.so */
            
            CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
            
            DeviceConfigurator *clientInstance = [DeviceConfigurator sharedConfiguratorWithRole:DeviceConfiguratorRoleClient];
            [clientInstance setMessagingCenter:clientMessagingCenter];
            
            CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
        }
        
        CHLoadLateClass(SpringBoard);
        CHHook(1, SpringBoard, applicationDidFinishLaunching);
    }
}
