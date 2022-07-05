//
//  DCUtilNetworksManager.h
//
//
//  Created by qpiu on 2016/2/12.
//
//

#ifndef UtilNetworksManager_h
#define UtilNetworksManager_h

#import <UIKit/UIKit.h>
#import "MobileWiFi/MobileWiFi.h"

@class DCUtilNetwork;

@interface DCUtilNetworksManager : NSObject {
    WiFiManagerRef _manager;
    WiFiDeviceClientRef _client;
    WiFiNetworkRef _currentNetwork;
    BOOL _scanning;
    BOOL _associating;
    NSMutableArray *_networks;
    int _statusCode;
}

@property (nonatomic, retain, readonly) NSArray <DCUtilNetwork *> *networks;
@property (nonatomic, assign, readonly, getter = isScanning) BOOL scanning;
@property (nonatomic, assign, readonly) int statusCode;
@property (nonatomic, assign, getter = isWiFiEnabled) BOOL wiFiEnabled;

+ (instancetype)sharedInstance;
- (BOOL)scanWithTimeout:(NSTimeInterval)timeout;
- (NSString *)prettyPrintNetworks;

- (BOOL)associateWithNetwork:(DCUtilNetwork *)network Timeout:(NSTimeInterval)timeout;
- (BOOL)associateWithEncNetwork:(DCUtilNetwork *)network Password:(NSString *)passwd Timeout:(NSTimeInterval)timeout;
- (void)disassociate;
- (DCUtilNetwork *)getNetworkWithSSID:(NSString *)ssid;

@end
#endif  /* UtilNetworksManager_h */
