//
// UIDevice+MobileGestaltCategory.m
// EquipmentInfo
//
// Created by Ray Zhang on 13-1-28.
// Copyright (c) 2013年 Ray Zhang. All rights reserved.
//
// This Categroy Depaned on Mobile Gestalt Dynamic Library
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "UIDevice+MobileGestaltCategory.h"

@implementation UIDevice (MobileGestalt)

// Mobile Gestalt EquipmentInfo
OBJC_EXTERN CFTypeRef MGCopyAnswer(CFStringRef);

- (NSString *)xxte_UDID {
    NSString *retVal = nil;
    CFTypeRef tmp = MGCopyAnswer(CFSTR("UniqueDeviceID"));
    if (tmp) {
        retVal = [NSString stringWithString:(__bridge NSString * _Nonnull)(tmp)];
        CFRelease(tmp);
    }
    return retVal;
}

- (NSString *)xxte_IMEI {
    NSString *retVal = nil;
    CFTypeRef tmp = MGCopyAnswer(CFSTR("InternationalMobileEquipmentIdentity"));
    if (tmp) {
        retVal = [NSString stringWithString:(__bridge NSString * _Nonnull)(tmp)];
        CFRelease(tmp);
    }
    return retVal;
}

- (NSString *)xxte_ICCID {
    NSString *retVal = nil;
    CFArrayRef infoArray = MGCopyAnswer(CFSTR("CarrierBundleInfoArray"));
    if (infoArray) {
        CFDictionaryRef infoDic = CFArrayGetValueAtIndex(infoArray, 0);
        if (infoDic) {
            retVal = [NSString stringWithString:CFDictionaryGetValue(infoDic, CFSTR("IntegratedCircuitCardIdentity"))];
        }
        CFRelease(infoArray);
    }
    return retVal;
}

- (NSString *)xxte_serialNumber {
    NSString *retVal = nil;
    CFTypeRef tmp = MGCopyAnswer(CFSTR("SerialNumber"));
    if (tmp) {
        retVal = [NSString stringWithString:(__bridge NSString *)tmp];
        CFRelease(tmp);
    }
    return retVal;
}

- (NSString *)xxte_modelNumberWithRegionInfo {
	NSString *retVal = nil;
	CFTypeRef modelNumber = MGCopyAnswer(CFSTR("ModelNumber"));
	if(modelNumber) {
		CFTypeRef regionInfo = MGCopyAnswer(CFSTR("RegionInfo"));
		if(regionInfo) {
			retVal = [NSString stringWithFormat:@"%@%@", (__bridge NSString *)modelNumber, (__bridge NSString *)regionInfo];
			CFRelease(regionInfo);
		}
		CFRelease(modelNumber);
	}
	return retVal;
}

- (NSString *)xxte_wifiAddress {
    NSString *retVal = nil;
    CFTypeRef tmp = MGCopyAnswer(CFSTR("WifiAddress"));
    if (tmp) {
        retVal = [NSString stringWithString:(__bridge NSString * _Nonnull)(tmp)];
        CFRelease(tmp);
    }
    return retVal;
}

- (NSString *)xxte_bluetoothAddress {
    NSString *retVal = nil;
    CFTypeRef tmp = MGCopyAnswer(CFSTR("BluetoothAddress"));
    if (tmp) {
        retVal = [NSString stringWithString:(__bridge NSString * _Nonnull)(tmp)];
        CFRelease(tmp);
    }
    return retVal;
}

- (NSString *)xxte_cpuArchitecture {
    NSString *retVal = nil;
    CFTypeRef tmp = MGCopyAnswer(CFSTR("CPUArchitecture"));
    if (tmp) {
        retVal = [NSString stringWithString:(__bridge NSString * _Nonnull)(tmp)];
        CFRelease(tmp);
    }
    return retVal;
}

- (NSString *)xxte_productType {
    NSString *retVal = nil;
    CFTypeRef tmp = MGCopyAnswer(CFSTR("ProductType"));
    if (tmp) {
        retVal = [NSString stringWithString:(__bridge NSString * _Nonnull)(tmp)];
        CFRelease(tmp);
    }
    return retVal;
}

- (BOOL)xxte_airplaneMode {
    BOOL retVal = NO;
    CFTypeRef tmp = MGCopyAnswer(CFSTR("AirplaneMode"));
    if (tmp) {
        if (tmp == kCFBooleanTrue) {
            retVal = YES;
        }
        CFRelease(tmp);
    }
    return retVal;
}

@end

/*

All Keys:

DieId
SerialNumber
UniqueChipID
WifiAddress
CPUArchitecture
BluetoothAddress
EthernetMacAddress
FirmwareVersion
MLBSerialNumber
ModelNumber
RegionInfo
RegionCode
DeviceClass
ProductType
DeviceName
UserAssignedDeviceName
HWModelStr
SigningFuse
SoftwareBehavior
SupportedKeyboards
BuildVersion
ProductVersion
ReleaseType
InternalBuild
CarrierInstallCapability
IsUIBuild
InternationalMobileEquipmentIdentity
MobileEquipmentIdentifier
DeviceColor
HasBaseband
SupportedDeviceFamilies
SoftwareBundleVersion
SDIOManufacturerTuple
SDIOProductInfo
UniqueDeviceID
InverseDeviceID
ChipID
PartitionType
ProximitySensorCalibration
CompassCalibration
WirelessBoardSnum
BasebandBoardSnum
HardwarePlatform
RequiredBatteryLevelForSoftwareUpdate
IsThereEnoughBatteryLevelForSoftwareUpdate
BasebandRegionSKU
encrypted-data-partition
BasebandKeyHashInformation
SysCfg
DiagData
BasebandFirmwareManifestData
SIMTrayStatus
CarrierBundleInfoArray
AirplaneMode
IsProductTypeValid
BoardId
AllDeviceCapabilities
wi-fi
SBAllowSensitiveUI
green-tea
not-green-tea
AllowYouTube
AllowYouTubePlugin
SBCanForceDebuggingInfo
AppleInternalInstallCapability
HasAllFeaturesCapability
ScreenDimensions
IsSimulator
BasebandSerialNumber
BasebandChipId
BasebandCertId
BasebandSkeyId
BasebandFirmwareVersion
cellular-data
contains-cellular-radio
RegionalBehaviorGoogleMail
RegionalBehaviorVolumeLimit
RegionalBehaviorShutterClick
RegionalBehaviorNTSC
RegionalBehaviorNoWiFi
RegionalBehaviorChinaBrick
RegionalBehaviorNoVOIP
RegionalBehaviorGB18030
RegionalBehaviorAll
ApNonce
*/
