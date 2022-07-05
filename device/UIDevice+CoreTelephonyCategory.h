//
//  UIDevice+CoreTelephonyCategory.h
//  EquipmentInfo
//
//  Created by Ray Zhang on 13-1-29.
//  Copyright (c) 2013年 Ray Zhang. All rights reserved.
//
//  This Category Depand on Core Telephony Framework.
//

#import <UIKit/UIKit.h>

@interface UIDevice (CoreTelephony)

+ (NSString *)xxte_IMEI;
+ (NSString *)xxte_CMID; // Current Mobile Identifier. Genernally, it's same as IMEI, but CDMA carrier maybe not.
+ (NSString *)xxte_ICCID;

+ (NSString *)xxte_IMSI;
+ (NSString *)xxte_CSID; // Current Subscriber Identifier. Genernally, it is same as IMSI, but CDMA carrier is not.

+ (NSString *)xxte_MEID; // Just for CDMA carrier.

@end
