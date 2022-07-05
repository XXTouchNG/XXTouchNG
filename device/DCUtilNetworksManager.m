//
//  DCUtilNetworksManager.m
//
//
//  Created by qpiu on 2016/2/12.
//
//

#import "DCUtilNetworksManager.h"
#import "DCUtilNetwork.h"

@interface DCUtilNetworksManager ()

- (BOOL)_scanWithTimeout:(NSTimeInterval)timeout;
- (void)_clearNetworks;
- (void)_addNetwork:(DCUtilNetwork *)network;
- (void)_reloadCurrentNetwork;
- (void)_scanDidFinishWithError:(int)error;
- (void)_associationDidFinishWithError:(int)error;
- (WiFiNetworkRef)_currentNetwork;

static void DCUtilScanCallback(WiFiDeviceClientRef device, CFArrayRef results, CFErrorRef error, void *token);
static void DCUtilAssociationCallback(WiFiDeviceClientRef device, WiFiNetworkRef networkRef, CFDictionaryRef dict, CFErrorRef error, void *token);

@end

@implementation DCUtilNetworksManager
@synthesize networks = _networks;
@synthesize scanning = _scanning;
@synthesize statusCode = _statusCode;

+ (instancetype)sharedInstance
{
    static DCUtilNetworksManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        _manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
        
        CFArrayRef devices = WiFiManagerClientCopyDevices(_manager);
        if (!devices) {
            fprintf(stderr, "Couldn't get WiFi devices. Bailing.\n");
            exit(EXIT_FAILURE);
        }
        
        _client = (WiFiDeviceClientRef)CFArrayGetValueAtIndex(devices, 0);
        CFRetain(_client);
        CFRelease(devices);
        
        _networks = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    CFRelease(_currentNetwork);
    CFRelease(_client);
    CFRelease(_manager);
    
    [self _clearNetworks];
    
    [super dealloc];
}

- (BOOL)scanWithTimeout:(NSTimeInterval)timeout
{
    _statusCode = -1;
    
    // If WiFi is off
    if (![self isWiFiEnabled]) {
        [self setWiFiEnabled:YES];
        [NSThread sleepForTimeInterval:5.0];
    }
    
    // Prevent initiating a scan when we're already scanning.
    if (_scanning) {
        CHDebugLogSource(@"is scanning...stop");
        return NO;
    }
    
    _scanning = YES;
    
    // Reload the current network.
    [self _reloadCurrentNetwork];
    
    // Actually initiate a scan.
    return [self _scanWithTimeout:timeout];
}

- (BOOL)associateWithNetwork:(DCUtilNetwork *)network Timeout:(NSTimeInterval)timeout
{
    _statusCode = -1;
    
    // Prevent initiating an association if we're already associating.
    if (_associating) {
        CHDebugLogSource(@"already associating...stop");
        return NO;
    }
    
    if (_currentNetwork) {
        CHDebugLogSource(@"Disassociate with the current network");
        [self disassociate];
    }
    
    WiFiManagerClientUnscheduleFromRunLoop(_manager);
    WiFiManagerClientScheduleWithRunLoop(_manager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    WiFiNetworkRef net = [network _networkRef];
    if (!net) {
        CHDebugLogSource(@"Cannot get networkRef");
        return NO;
    }
    
    [network setIsAssociating:YES];
    _associating = YES;
    
    CHDebugLogSource(@"Start associating");
    WiFiDeviceClientAssociateAsync(_client, net, (WiFiDeviceAssociateCallback)DCUtilAssociationCallback, 0);
    CFRunLoopRunResult result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout, false);
    
    if (_associating)
        [self _associationDidFinishWithError:-1];
    return result != kCFRunLoopRunTimedOut;
}

- (BOOL)associateWithEncNetwork:(DCUtilNetwork *)network Password:(NSString *)passwd Timeout:(NSTimeInterval)timeout
{
    _statusCode = -1;
    
    // Prevent initiating an association if we're already associating.
    if (_associating) {
        CHDebugLogSource(@"already associating...stop");
        return NO;
    }
    
    if (_currentNetwork) {
        // Disassociate with the current network before association.
        CHDebugLogSource(@"Disassociate with the current network");
        [self disassociate];
    }
    
    WiFiManagerClientUnscheduleFromRunLoop(_manager);
    WiFiManagerClientScheduleWithRunLoop(_manager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    WiFiNetworkRef net = [network _networkRef];
    if (!net) {
        CHDebugLogSource(@"Cannot get networkRef");
        return NO;
    }
    
    WiFiNetworkSetPassword(net, (__bridge CFStringRef)passwd);
    
    [network setIsAssociating:YES];
    _associating = YES;
    
    CHDebugLogSource(@"Start associating");
    WiFiDeviceClientAssociateAsync(_client, net, (WiFiDeviceAssociateCallback)DCUtilAssociationCallback, 0);
    CFRunLoopRunResult result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout, false);
    
    if (_associating)
        [self _associationDidFinishWithError:-1];
    return result != kCFRunLoopRunTimedOut;
}

- (BOOL)isWiFiEnabled
{
    CFBooleanRef enabled = WiFiManagerClientCopyProperty(_manager, CFSTR("AllowEnable"));
    BOOL value = CFBooleanGetValue(enabled);
    CFRelease(enabled);
    return value;
}

- (void)setWiFiEnabled:(BOOL)enabled
{
    CFBooleanRef value = (enabled ? kCFBooleanTrue : kCFBooleanFalse);
    WiFiManagerClientSetProperty(_manager, CFSTR("AllowEnable"), value);
    return;
}

- (void)disassociate
{
    WiFiDeviceClientDisassociate(_client);
}

- (DCUtilNetwork *)getNetworkWithSSID:(NSString *)ssid
{
    for (DCUtilNetwork *network in _networks)
    {
        if ([[network SSID] isEqualToString:ssid])
            return network;  // network exists
    }
    return nil;  // cannot find the network
}

- (NSString *)prettyPrintNetworks
{
    NSString *output = nil;
    NSString *str = nil;
    
    for (DCUtilNetwork *network in _networks)
    {
        str = [NSString stringWithFormat:@" %30s\t| %20s\t| %s %d\t", [[network SSID] UTF8String], [[network BSSID] UTF8String], "channel", [network channel]];
        output = [NSString stringWithFormat:@"%@\n%@", output, str];
    }
    return output;
}


#pragma mark - Private APIs

- (BOOL)_scanWithTimeout:(NSTimeInterval)timeout
{
    WiFiManagerClientUnscheduleFromRunLoop(_manager);
    WiFiManagerClientScheduleWithRunLoop(_manager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    WiFiDeviceClientScanAsync(_client, (__bridge CFDictionaryRef)[NSDictionary dictionary], (WiFiDeviceScanCallback)DCUtilScanCallback, 0);
    CFRunLoopRunResult result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout, false);
    
    if (_scanning)
        [self _scanDidFinishWithError:-1];
    return result != kCFRunLoopRunTimedOut;
}

- (void)_clearNetworks
{
    [_networks removeAllObjects];
}

- (void)_addNetwork:(DCUtilNetwork *)network
{
    [_networks addObject:network];
}

- (WiFiNetworkRef)_currentNetwork
{
    return _currentNetwork;
}

- (void)_reloadCurrentNetwork
{
    if (_currentNetwork) {
        CFRelease(_currentNetwork);
        _currentNetwork = nil;
    }
    
    _currentNetwork = WiFiDeviceClientCopyCurrentNetwork(_client);
}

- (void)_scanDidFinishWithError:(int)error
{
    WiFiManagerClientUnscheduleFromRunLoop(_manager);
    
    _statusCode = error;
    if (_statusCode == 0) {
        CHDebugLogSource(@"Scanning is successful :) ");
    } else if (_statusCode < 0) {
        CHDebugLogSource(@"Scanning failed :( ");
    }
    
    _scanning = NO;
}

- (void)_associationDidFinishWithError:(int)error
{
    WiFiManagerClientUnscheduleFromRunLoop(_manager);
    
    for (DCUtilNetwork *network in [[DCUtilNetworksManager sharedInstance] networks]) {
        if ([network isAssociating])
            [network setIsAssociating:NO];
    }
    
    _statusCode = error;
    if (_statusCode == 0) {
        CHDebugLogSource(@"Association is successful :) ");
    } else if (_statusCode < 0) {
        CHDebugLogSource(@"Association failed :( ");
    }
    
    _associating = NO;
    
    // Reload the current network.
    [self _reloadCurrentNetwork];
}

#pragma mark - Functions

static void DCUtilScanCallback(WiFiDeviceClientRef device, CFArrayRef results, CFErrorRef error, void *token)
{
    CFRunLoopStop(CFRunLoopGetCurrent());
    
    [[DCUtilNetworksManager sharedInstance] _clearNetworks];
    for (unsigned x = 0; x < CFArrayGetCount(results); x++) {
        WiFiNetworkRef networkRef = (WiFiNetworkRef)CFArrayGetValueAtIndex(results, x);
        
        DCUtilNetwork *network = [[DCUtilNetwork alloc] initWithNetwork:networkRef];
        [network populateData];
        
        WiFiNetworkRef currentNetwork = [[DCUtilNetworksManager sharedInstance] _currentNetwork];
        
        // WiFiNetworkGetProperty() crashes if the network parameter is NULL therefore we need to check if it exists first.
        if (currentNetwork) {
            if ([[network BSSID] isEqualToString:(__bridge NSString *)WiFiNetworkGetProperty(currentNetwork, CFSTR("BSSID"))])
                [network setIsCurrentNetwork:YES];
        }
        
        BOOL netExists = 0;
        for (DCUtilNetwork *n in [[DCUtilNetworksManager sharedInstance] networks])
        {
            if ([[n BSSID] isEqualToString: [network BSSID]]) {
                netExists = 1;
                NSString *str = [NSString stringWithFormat:@"(%@, %@) is already exists.", [network SSID], [network BSSID]];
                CHDebugLogSource(@"%@", str);
                break; // network is already in _networks
            }
        }
        if (!netExists)
            [[DCUtilNetworksManager sharedInstance] _addNetwork: network];
        
        [network release];
    }
    
    NSString *str = [NSString stringWithFormat:@"Finished scanning! %lu networks: %@",
                     (unsigned long)[[[DCUtilNetworksManager sharedInstance] networks] count], [[DCUtilNetworksManager sharedInstance] prettyPrintNetworks]];
    CHDebugLogSource(@"%@", str);
    [[DCUtilNetworksManager sharedInstance] _scanDidFinishWithError:(int)[(__bridge NSError *)error code]];
}

static void DCUtilAssociationCallback(WiFiDeviceClientRef device, WiFiNetworkRef networkRef, CFDictionaryRef dict, CFErrorRef error, void *token)
{
    CFRunLoopStop(CFRunLoopGetCurrent());
    
    // Reload every network's data.
    for (DCUtilNetwork *network in [[DCUtilNetworksManager sharedInstance] networks]) {
        [network populateData];
        
        if (networkRef) {
            [network setIsCurrentNetwork:[[network BSSID] isEqualToString:(__bridge NSString *)WiFiNetworkGetProperty(networkRef, CFSTR("BSSID"))]];
        }
    }
    
    [[DCUtilNetworksManager sharedInstance] _associationDidFinishWithError:(int)[(__bridge NSError *)error code]];
}

@end
