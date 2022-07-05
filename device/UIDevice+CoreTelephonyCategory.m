//
//  UIDevice+CoreTelephonyCategory.m
//  EquipmentInfo
//
//  Created by Ray Zhang on 13-1-29.
//  Copyright (c) 2013年 Ray Zhang. All rights reserved.
//
//  This Category Depand on Core Telephony Framework.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "UIDevice+CoreTelephonyCategory.h"

typedef struct CTResult {
    int flag;
    int a;
} CTResult;

typedef const struct __CTServerConnection * CTServerConnectionRef;

OBJC_EXTERN CTServerConnectionRef _CTServerConnectionCreate(CFAllocatorRef, int (*)(void *, CFStringRef, CFDictionaryRef, void *), int *);

#ifdef __arm__
OBJC_EXTERN void _CTServerConnectionCopyMobileEquipmentInfo(CTResult *status, CTServerConnectionRef connection, CFMutableDictionaryRef *equipmentInfo);
#elif defined __arm64__
OBJC_EXTERN void _CTServerConnectionCopyMobileEquipmentInfo(CTServerConnectionRef connection, CFMutableDictionaryRef *equipmentInfo, NSInteger *unknown);
#endif

static int callback(void *connection, CFStringRef string, CFDictionaryRef dictionary, void *data) {
    return 0;
}

@implementation UIDevice (CoreTelephony)

// Core Telephony Device Information

+ (NSString *)xxte_coreTelephonyInfoForKey:(const NSString *)key {
    NSString *retVal = nil;
    CTServerConnectionRef ctsc = _CTServerConnectionCreate(kCFAllocatorDefault, callback, NULL);
    if (ctsc) {
        CFMutableDictionaryRef equipmentInfo = nil;
#ifdef __arm__
        struct CTResult result;
        _CTServerConnectionCopyMobileEquipmentInfo(&result, ctsc, &equipmentInfo);
#elif defined __arm64__
        _CTServerConnectionCopyMobileEquipmentInfo(ctsc, &equipmentInfo, NULL);
#endif
        if (equipmentInfo) {
            CFStringRef value = CFDictionaryGetValue(equipmentInfo, (__bridge const void *)(key));
            if (value) {
                retVal = [NSString stringWithString:(__bridge id)value];
            }
            CFRelease(equipmentInfo);
        }
        CFRelease(ctsc);
    }
    return retVal;
}

+ (NSString *)xxte_IMEI {
    return [self xxte_coreTelephonyInfoForKey:@"kCTMobileEquipmentInfoIMEI"];
}

+ (NSString *)xxte_CMID {
    return [self xxte_coreTelephonyInfoForKey:@"kCTMobileEquipmentInfoCurrentMobileId"];
}

+ (NSString *)xxte_ICCID {
    return [self xxte_coreTelephonyInfoForKey:@"kCTMobileEquipmentInfoICCID"];
}

+ (NSString *)xxte_MEID {
    return [self xxte_coreTelephonyInfoForKey:@"kCTMobileEquipmentInfoMEID"];
}

+ (NSString *)xxte_IMSI {
    return [self xxte_coreTelephonyInfoForKey:@"kCTMobileEquipmentInfoIMSI"];
}

+ (NSString *)xxte_CSID {
    return [self xxte_coreTelephonyInfoForKey:@"kCTMobileEquipmentInfoCurrentSubscriberId"];
}

@end
