//
//  UIDevice+EquipmentInfo.m
//
//  Created by Ray Zhang on 13-1-8.
//
//  This Device Category Depand on CoreTelephony, IOKit Frameworks and libMobileGestalt Dynamic Library
//

#import "UIDevice+EquipmentInfo.h"

#import <net/if.h>
#import <net/if_dl.h>
#import <sys/socket.h>
#import <sys/sysctl.h>
#import <IOKit/IOKitKeys.h>
#import <IOKit/IOKitLib.h>


@implementation UIDevice (EquipmentInfo)

// Core Telephony Device Information
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
typedef struct CTResult {
    int flag;
    int a;
} CTResult;

OBJC_EXTERN struct CTServerConnection *_CTServerConnectionCreate(CFAllocatorRef, int (*)(void *, CFStringRef, CFDictionaryRef, void *), int *);
OBJC_EXTERN void _CTServerConnectionCopyMobileEquipmentInfo(CTResult *status, CFTypeRef connection, CFMutableDictionaryRef *equipmentInfo);

static int callback(void *connection, CFStringRef string, CFDictionaryRef dictionary, void *data) {
    return 0;
}

OBJC_EXTERN const NSString * const kCTMobileEquipmentInfoERIVersion;
OBJC_EXTERN const NSString * const kCTMobileEquipmentInfoICCID;
OBJC_EXTERN const NSString * const kCTMobileEquipmentInfoIMEI;
OBJC_EXTERN const NSString * const kCTMobileEquipmentInfoMEID;
OBJC_EXTERN const NSString * const kCTMobileEquipmentInfoPRLVersion;
OBJC_EXTERN const NSString * const kCTMobileEquipmentInfoIMSI;

+ (NSString *)xxte_mobileDeviceInfoForKey:(const NSString *)key {
    NSString *retVal = nil;
    CFTypeRef ctsc = _CTServerConnectionCreate(kCFAllocatorDefault, callback, NULL);
    if (ctsc) {
        struct CTResult result;
        CFMutableDictionaryRef equipmentInfo = nil;
        _CTServerConnectionCopyMobileEquipmentInfo(&result, ctsc, &equipmentInfo);
        if (equipmentInfo) {
            retVal = [NSString stringWithString:CFDictionaryGetValue(equipmentInfo, (__bridge const void *)(key))];
            CFRelease(equipmentInfo);
        }
        CFRelease(ctsc);
    }
    return retVal;
}

+ (NSString *)xxte_ERIVersion {
    return [self xxte_mobileDeviceInfoForKey:kCTMobileEquipmentInfoERIVersion];
}

+ (NSString *)xxte_ICCID {
    return [self xxte_mobileDeviceInfoForKey:kCTMobileEquipmentInfoICCID];
}

+ (NSString *)xxte_IMEI {
    return [self xxte_mobileDeviceInfoForKey:kCTMobileEquipmentInfoIMEI];
}

+ (NSString *)xxte_IMSI {
    return [self xxte_mobileDeviceInfoForKey:kCTMobileEquipmentInfoIMSI];
}

+ (NSString *)xxte_MEID {
    return [self xxte_mobileDeviceInfoForKey:kCTMobileEquipmentInfoMEID];
}

+ (NSString *)xxte_PRLVersion {
    return [self xxte_mobileDeviceInfoForKey:kCTMobileEquipmentInfoPRLVersion];
}

// UIKit Device Information
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
static const CFStringRef kMobileDeviceUniqueIdentifier = CFSTR("UniqueDeviceID");
static const CFStringRef kMobileDeviceCPUArchitecture = CFSTR("CPUArchitecture");
static const CFStringRef kMobileDeviceSerialNumber = CFSTR("SerialNumber");

OBJC_EXTERN CFTypeRef MGCopyAnswer(CFStringRef);

+ (NSString *)xxte_UDID {
    return CFBridgingRelease(MGCopyAnswer(kMobileDeviceUniqueIdentifier));
}

+ (NSString *)xxte_CPUArchitecture {
    return CFBridgingRelease(MGCopyAnswer(kMobileDeviceCPUArchitecture));
}

+ (NSString *)xxte_serialNumber {
    return CFBridgingRelease(MGCopyAnswer(kMobileDeviceSerialNumber));
}

// IOKit Device Information
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
static const CFStringRef kIODeviceModel = CFSTR("model");

static const CFStringRef kIODeviceIMEI = CFSTR("device-imei");
static const CFStringRef kIODeviceSerialNumber = CFSTR("serial-number");

+ (NSString *)xxte_IODeviceInfoForKey:(CFStringRef)key {
    NSString *retVal = nil;
    io_registry_entry_t entry = IORegistryGetRootEntry(kIOMasterPortDefault);
    if (entry) {
        CFTypeRef property = IORegistryEntrySearchCFProperty(entry, kIODeviceTreePlane, key, kCFAllocatorDefault, kIORegistryIterateRecursively);
        if (property) {
            CFTypeID typeID = CFGetTypeID(property);
            if (CFStringGetTypeID() == typeID) {
                retVal = [NSString stringWithString:(__bridge NSString *)property];
            } else if (CFDataGetTypeID() == typeID) {
                CFStringRef modelString = CFStringCreateWithBytes(kCFAllocatorDefault,
                                                                  CFDataGetBytePtr(property),
                                                                  CFDataGetLength(property),
                                                                  kCFStringEncodingUTF8, NO);
                retVal = [NSString stringWithString:(__bridge NSString *)modelString];
                CFRelease(modelString);
            }
            CFRelease(property);
        }
        IOObjectRelease(entry);
    }
    return retVal;
}

+ (NSString *)xxte_platformModel {
    return [self xxte_IODeviceInfoForKey:kIODeviceModel];
}

+ (NSString *)xxte_deviceIMEI {
    return [self xxte_IODeviceInfoForKey:kIODeviceIMEI];
}

+ (NSString *)xxte_deviceSerialNumber {
    return [self xxte_IODeviceInfoForKey:kIODeviceSerialNumber];
}

+ (NSString *)xxte_platformUUID {
    return [self xxte_IODeviceInfoForKey:CFSTR(kIOPlatformUUIDKey)];
}

+ (NSString *)xxte_platformSerialNumber {
    return [self xxte_IODeviceInfoForKey:CFSTR(kIOPlatformSerialNumberKey)];
}

// System Control Device Information
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSString *)xxte_macAddress {
    int mib[6] = {CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST};
    size_t len = 0;
    char *buf = NULL;
    unsigned char *ptr = NULL;
    struct if_msghdr *ifm = NULL;
    struct sockaddr_dl *sdl = NULL;
    
    mib[5] = if_nametoindex("en0");
    if (mib[5] == 0) return nil;
    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) return nil;
        
    if ((buf = malloc(len)) == NULL) return nil;
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0)
    {
        free(buf);
        return NULL;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);
    
    NSMutableString *outString = [[NSMutableString alloc] initWithCapacity:6];
    for (int i = 0; i < 6; i++) {
        if (i < 5) {
            [outString appendFormat:@"%02X:", ptr[i]];
        } else {
            [outString appendFormat:@"%02X", ptr[i]];
        }
    }
    NSString *retVal = [NSString stringWithString:outString];
    [outString release];
    free(buf);
    
    return retVal;
}

+ (NSString *)xxte_systemModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *answer = malloc(size);
	sysctlbyname("hw.machine", answer, &size, NULL, 0);
	NSString *results = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
	free(answer);
	return results;
}

@end
