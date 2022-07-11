//
//  DeviceConfigurator.h
//  DeviceConfigurator
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#ifndef DeviceConfigurator_h
#define DeviceConfigurator_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DeviceConfiguratorRole) {
    DeviceConfiguratorRoleClient = 0,
    DeviceConfiguratorRoleServer,
};

@interface DeviceConfigurator : NSObject

@property (nonatomic, assign, readonly) DeviceConfiguratorRole role;

+ (instancetype)sharedConfigurator;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/* Idle */
- (void)resetIdleTimer;

/* Lock & Unlock */
- (void)lockScreen;
- (void)unlockScreenWithPasscode:(NSString *)passcode;
- (BOOL)isScreenLocked;

/* Orientation */
- (NSInteger)frontMostAppOrientation;
- (void)lockOrientation;
- (void)unlockOrientation;
- (BOOL)isOrientationLocked;

/* Feedback */
- (void)vibrator;

/* Notifications */
- (void)popBannerWithSectionID:(NSString *)sectionID
                  messageTitle:(NSString *)messageTitle
               messageSubtitle:(NSString *)messageSubtitle
                messageContent:(NSString *)messageContent;

/* SpringBoard Alerts */
- (NSInteger)popAlertWithTimeout:(NSTimeInterval)timeout
                    messageTitle:(NSString *)messageTitle
                  messageContent:(NSString *)messageContent
                    buttonTitles:(NSArray <NSString *> *)buttonTitles;

- (nullable NSDictionary *)popAlertWithTimeout:(NSTimeInterval)timeout
                                  messageTitle:(NSString *)messageTitle
                                messageContent:(NSString *)messageContent
                                  buttonTitles:(NSArray <NSString *> *)buttonTitles
                                    textFields:(nullable NSArray <NSString *> *)textFields
                         textFieldPlaceholders:(nullable NSArray <NSString *> *)textFieldPlaceholders;

/* Wi-Fi */
- (void)turnOnWiFi;
- (void)turnOffWiFi;
- (BOOL)isWiFiEnabled;

/* Cellular */
- (void)turnOnCellular;
- (void)turnOffCellular;
- (BOOL)isCellularEnabled;

/* Bluetooth */
- (void)turnOnBluetooth;
- (void)turnOffBluetooth;
- (BOOL)isBluetoothEnabled;

/* Airplane */
- (void)turnOnAirplane;
- (void)turnOffAirplane;
- (BOOL)isAirplaneEnabled;

/* VPN */
- (void)turnOnVPN;
- (void)turnOffVPN;
- (BOOL)isVPNEnabled;

/* Flash */
- (void)turnOnFlashWithLevel:(double)level;
- (void)turnOffFlash;
- (BOOL)isFlashEnabled;

/* Volume */
- (void)turnOnRingerMute;
- (void)turnOffRingerMute;
- (BOOL)isRingerMuteEnabled;
- (void)setCurrentVolume:(double)volume;

/* Backlight */
- (void)setBacklightLevel:(double)level;
- (double)backlightLevel;

/* Assistive Touch */
- (void)turnOnAssistiveTouch;
- (void)turnOffAssistiveTouch;
- (BOOL)isAssistiveTouchEnabled;

/* Reduce Motion */
- (void)turnOnReduceMotion;
- (void)turnOffReduceMotion;
- (BOOL)isReduceMotionEnabled;

/* Safari Remote Inspector */
- (void)turnOnRemoteInspector;
- (void)turnOffRemoteInspector;
- (BOOL)isRemoteInspectorEnabled;

/* Auto Lock */
- (void)setAutoLockTimeInSeconds:(NSTimeInterval)seconds;
- (NSTimeInterval)autoLockTimeInSeconds;

/* Standard User Defaults */
- (nullable id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;

/* Darwin Notify */
- (void)darwinNotifyPost:(NSString *)notificationName;
- (void)notifyPost:(NSString *)notificationName;

/* App Switcher */
- (void)removeAppLayoutsMatchingBundleIdentifier:(NSString *)bundleIdentifier;
- (void)removeAppLayoutsMatchingBundleIdentifiers:(NSArray <NSString *> *)bundleIdentifiers;
- (void)removeAllAppLayouts;

/* Interactions */
- (void)beginIgnoringInteractionEvents;
- (void)endIgnoringInteractionEvents;

/* Utils */
- (void)takeScreenshot;
- (void)shutdown;
- (void)reboot;
- (void)suspend;

/* Language & Region */
- (NSString *)currentLanguage;
- (void)setCurrentLanguage:(NSString *)language;  // async
- (NSString *)currentLocale;
- (void)setCurrentLocale:(NSString *)locale;  // async
- (NSString *)currentTimeZone;
- (void)setCurrentTimeZone:(NSString *)timeZoneName;

/* User Assigned Device Name */
- (NSString *)userAssignedDeviceName;
- (void)setUserAssignedDeviceName:(NSString *)userAssignedDeviceName;

/* Appearance (Not Available in OpenAPI) */
- (UIUserInterfaceStyle)currentInterfaceStyle;
- (void)setCurrentInterfaceStyle:(UIUserInterfaceStyle)interfaceStyle;
- (BOOL)boldTextEnabled;
- (void)setBoldTextEnabled:(BOOL)boldTextEnabled;
- (NSInteger)dynamicTypeValue;
- (void)setDynamicTypeValue:(NSInteger)dynamicTypeValue;
- (BOOL)isZoomedMode;
- (void)setZoomedMode:(BOOL)zoomedMode;

/* AirDrop */
- (NSInteger)airDropMode;
- (void)setAirDropMode:(NSInteger)airDropMode;

@end

NS_ASSUME_NONNULL_END

#endif  /* DeviceConfigurator_h */
