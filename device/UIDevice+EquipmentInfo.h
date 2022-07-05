//
//  UIDevice+EquipmentInfo.h
//
//  Created by Ray Zhang on 13-1-8.
//
//  This Device Category Depand on CoreTelephony, IOKit Frameworks and libMobileGestalt Dynamic Library
//

#import <UIKit/UIKit.h>


@interface UIDevice (EquipmentInfo)

// Core Telephony Device Information
+ (NSString *)xxte_ERIVersion;
+ (NSString *)xxte_ICCID;
+ (NSString *)xxte_IMEI;
+ (NSString *)xxte_IMSI;
+ (NSString *)xxte_MEID;
+ (NSString *)xxte_PRLVersion;

// UIKit Device Information
+ (NSString *)xxte_UDID;
+ (NSString *)xxte_CPUArchitecture;
+ (NSString *)xxte_serialNumber;

// IOKit Device Information
+ (NSString *)xxte_deviceIMEI;
+ (NSString *)xxte_deviceSerialNumber;

+ (NSString *)xxte_platformModel;
+ (NSString *)xxte_platformUUID;
+ (NSString *)xxte_platformSerialNumber;

// System Control Device Information
+ (NSString *)xxte_systemModel;
+ (NSString *)xxte_macAddress;

@end
