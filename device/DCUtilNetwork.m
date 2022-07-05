//
//  DCUtilNetwork.m
//
//
//  Created by qpiu on 2016/2/12.
//
//

#import "DCUtilNetwork.h"
#import <CoreFoundation/CoreFoundation.h>

@implementation DCUtilNetwork

@synthesize _networkRef      = _network;
@synthesize SSID             = _SSID;
@synthesize encryptionModel  = _encryptionModel;
@synthesize BSSID            = _BSSID;
@synthesize username         = _username;
@synthesize password         = _password;
@synthesize channel          = _channel;
@synthesize isCurrentNetwork = _isCurrentNetwork;
@synthesize isHidden         = _isHidden;
@synthesize isAssociating    = _isAssociating;
@synthesize requiresUsername = _requiresUsername;
@synthesize requiresPassword = _requiresPassword;

- (id)initWithNetwork:(WiFiNetworkRef)network
{
    self = [super init];
    
    if (self) {
        _network = (WiFiNetworkRef)CFRetain(network);
    }
    
    return self;
}

- (void)dealloc
{
    [_SSID release];
    [_BSSID release];
    [_encryptionModel release];
    [_username release];
    [_password release];
    CFRelease(_network);
    
    [super dealloc];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ SSID: %@ Encryption Model: %@ Channel: %i CurrentNetwork: %i Hidden: %i Associating: %i", [super description], [self SSID], [self encryptionModel], [self channel], [self isCurrentNetwork], [self isHidden], [self isAssociating]];
}

- (void)populateData
{
    // SSID
    NSString *SSID = (__bridge NSString *)WiFiNetworkGetSSID(_network);
    [self setSSID:SSID];
    
    // Encryption model
    if (WiFiNetworkIsWEP(_network)) {
        [self setEncryptionModel:@"WEP"];
    }
    else if (WiFiNetworkIsWPA(_network)) {
        [self setEncryptionModel:@"WPA"];
    }
    else {
        [self setEncryptionModel:@"None"];
    }
    
    // BSSID
    NSString *BSSID = (__bridge NSString *)WiFiNetworkGetProperty(_network, CFSTR("BSSID"));
    [self setBSSID:BSSID];
    
    // Channel
    CFNumberRef networkChannel = (CFNumberRef)WiFiNetworkGetProperty(_network, CFSTR("CHANNEL"));
    int channel;
    CFNumberGetValue(networkChannel, 9, &channel);  // 9: kCFNumberIntType
    [self setChannel:channel];
    
    // Hidden
    BOOL isHidden = WiFiNetworkIsHidden(_network);
    [self setIsHidden:isHidden];
    
    // Requires username
    BOOL requiresUsername = WiFiNetworkRequiresUsername(_network);
    [self setRequiresUsername:requiresUsername];
    
    // Requires password
    BOOL requiresPassword = WiFiNetworkRequiresPassword(_network);
    [self setRequiresPassword:requiresPassword];
}

@end
