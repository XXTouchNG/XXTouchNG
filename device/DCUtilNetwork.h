//
//  DCUtilNetwork.h
//
//
//  Created by qpiu on 2016/2/12.
//
//

#ifndef UtilNetwork_h
#define UtilNetwork_h

#import <Foundation/Foundation.h>
#import "MobileWiFi/MobileWiFi.h"

@interface DCUtilNetwork : NSObject {
    WiFiNetworkRef _network;
    NSString *_SSID;
    NSString *_encryptionModel;
    NSString *_BSSID;
    NSString *_username;
    NSString *_password;
    
    int _channel;
    BOOL _isCurrentNetwork;
    BOOL _isHidden;
    BOOL _isAssociating;
    BOOL _requiresUsername;
    BOOL _requiresPassword;
}

@property (nonatomic, copy) NSString *SSID;
@property (nonatomic, copy) NSString *encryptionModel;
@property (nonatomic, copy) NSString *BSSID;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;

@property (nonatomic, assign) int channel;
@property (nonatomic, assign) BOOL isCurrentNetwork;
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, assign) BOOL isAssociating;
@property (nonatomic, assign) BOOL requiresPassword;
@property (nonatomic, assign) BOOL requiresUsername;
@property (nonatomic, assign, readonly) WiFiNetworkRef _networkRef;

- (id)initWithNetwork:(WiFiNetworkRef)network;
- (void)populateData;


@end
#endif  /* UtilNetwork_h */
