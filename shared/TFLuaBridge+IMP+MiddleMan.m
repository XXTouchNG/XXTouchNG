//
//  TFLuaBridge+IMP.m
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#ifdef TF_MIDDLE_MAN

#import "TFLuaBridge.h"
#import <notify.h>
#import <pthread.h>
#import <rocketbootstrap/rocketbootstrap.h>


static NSString * const kMessageNameClientPutArguments   = @"PutArguments";
static NSString * const kMessageNameClientGetResponse    = @"GetResponse";
static NSString * const kMessageNameServerGetArguments   = @"GetArguments";
static NSString * const kMessageNameServerPutResponse    = @"PutResponse";

NSString * const kMessageNameClientReadDefaults          = @"ClientReadDefaults";
NSString * const kMessageNameServerWriteDefaults         = @"ServerWriteDefaults";


#pragma mark -

@interface FBApplicationProcess : NSObject
@end

@interface FBProcessState : NSObject
@property (nonatomic, assign, readonly) pid_t pid;
@property (getter=isRunning, nonatomic, assign, readonly) BOOL running;
@property (getter=isForeground, nonatomic, assign, readonly) BOOL foreground;
@property (nonatomic, readonly) NSInteger taskState;   // 2 - Running
@property (nonatomic, readonly) NSInteger visibility;  // 2 - Foreground
@end

@interface SBApplicationProcessState : FBProcessState
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (SBApplicationProcessState *)processState;
- (void)_noteProcess:(FBApplicationProcess *)process didChangeToState:(FBProcessState *)state;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface SpringBoard : UIApplication
+ (SpringBoard *)sharedApplication;
- (SBApplication *)_accessibilityFrontMostApplication;
@end


#pragma mark -

@protocol TFLuaBridgeProcessStateObserver <NSObject>
- (void)notifyLocalClientDidGetArguments;
- (void)notifyLocalClientDidPutResponse;
@end


#pragma mark -

@interface TFLuaBridge (Observer) <TFLuaBridgeProcessStateObserver>
@end

@implementation TFLuaBridge
{
    NSString *_sessionID;
    CPDistributedMessagingCenter *_messagingCenter;
    
    pthread_rwlock_t _lockArguments;
    pthread_rwlock_t _lockResponse;
    
    NSDictionary <NSString *, id> *_arguments;
    NSDictionary <NSString *, id> *_response;
    
    dispatch_semaphore_t _requestPulled;
    dispatch_semaphore_t _responsePushed;
    
    NSString *_localGetNotificationName;
    NSString *_localPutNotificationName;
    
    dispatch_queue_t _remoteMonitorQueue;
}

NSString *kLuaBridgeInstanceName                        = @"";
static NSString *kLuaBridgeMessagingCenterName          = @"";
static NSString *kLuaBridgeRemoteNotificationCenterName = @"";
static NSString *kLuaBridgeLocalNotificationCenterName  = @"";
static CFNotificationSuspensionBehavior kLuaBridgeNotificationSuspensionBehavior = CFNotificationSuspensionBehaviorCoalesce;

+ (void)setSharedInstanceName:(NSString *)instanceName
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kLuaBridgeInstanceName = [instanceName copy];
        kLuaBridgeMessagingCenterName = [[NSString stringWithFormat:@"%@.MessagingCenter", instanceName] copy];
        kLuaBridgeRemoteNotificationCenterName = [[NSString stringWithFormat:@"%@.Notification.Remote", instanceName] copy];
        kLuaBridgeLocalNotificationCenterName = [[NSString stringWithFormat:@"%@.Notification.Local", instanceName] copy];
    });
}

+ (void)setSharedNotificationSuspensionBehavior:(CFNotificationSuspensionBehavior)behavior
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kLuaBridgeNotificationSuspensionBehavior = behavior;
    });
}

+ (instancetype)sharedInstance
{
    __strong static id shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

static void LocalClientDidPutArguments(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    @autoreleasepool {
        CHDebugLog(@"[%@][Client #2] Notification arrived and get arguments from %@, %zu bytes memory used", kLuaBridgeInstanceName, (__bridge NSString *)name, [TFLuaBridge __getMemoryUsedInBytes]);
        
        NSDictionary *extraUserInfo = @{ @"bundleIdentifier": [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] bundleIdentifier]] };
        
        NSError *sendErr = nil;
        NSDictionary *req = [[(__bridge TFLuaBridge *)observer messagingCenter] sendMessageAndReceiveReplyName:kMessageNameServerGetArguments userInfo:extraUserInfo error:&sendErr];
        if (!req) {
            CHDebugLog(@"[%@][Client #2] Fail to get arguments: %@", kLuaBridgeInstanceName, sendErr);
            return;
        }
        
        CHDebugLog(@"[%@][Client #2] Got and handle request %@, %zu bytes memory used", kLuaBridgeInstanceName, req, [TFLuaBridge __getMemoryUsedInBytes]);
        
        NSMutableDictionary *resp = [[(__bridge TFLuaBridge *)observer handleRemoteActionWithRequest:req] mutableCopy];
        if (!resp) {
            CHDebugLog(@"[%@][Client #2] Skipped put response due to an empty return value.", kLuaBridgeInstanceName);
            return;
        }
        
        CHDebugLog(@"[%@][Client #2] Request handled and send response %@, %zu bytes memory used", kLuaBridgeInstanceName, resp, [TFLuaBridge __getMemoryUsedInBytes]);
        
        [resp addEntriesFromDictionary:extraUserInfo];
        NSDictionary *backingResp = [[(__bridge TFLuaBridge *)observer messagingCenter] sendMessageAndReceiveReplyName:kMessageNameServerPutResponse userInfo:resp error:&sendErr];
        if (!backingResp) {
            CHDebugLog(@"[%@][Client #2] Fail to put response: %@", kLuaBridgeInstanceName, sendErr);
            return;
        }
        
        CHDebugLog(@"[%@][Client #2] Sent response %@, %zu bytes memory used", kLuaBridgeInstanceName, backingResp, [TFLuaBridge __getMemoryUsedInBytes]);
    }
}

+ (NSArray <NSString *> *)allowedAppleProductBackgroundBundleIDs
{
    static NSArray <NSString *> *_backgroundIDs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _backgroundIDs =
        @[
            /* Background UI Services */
            @"com.apple.SafariViewService",
            @"com.apple.iMessageAppsViewService",
            @"com.apple.ios.StoreKitUIService",
            @"com.apple.Spotlight",
            @"com.apple.siri",
            
            // ...
        ];
    });
    
    return _backgroundIDs;
}

+ (NSArray <NSString *> *)allowedAppleProductForegroundBundleIDs
{
    static NSArray <NSString *> *_foregroundIDs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _foregroundIDs =
        @[
              @"com.apple.springboard",
              
              /* System UIKit Applications */
              @"com.apple.facetime",           // FaceTime
              @"com.apple.Preferences",        // Settings
              @"com.apple.AppStore",           // App Store
              @"com.apple.mobilesafari",       // Safari
              @"com.apple.mobilecal",          // Calendar
              @"com.apple.mobileslideshow",    // Photos
              @"com.apple.camera",             // Camera
              @"com.apple.mobilemail",         // Mail
              @"com.apple.mobiletimer",        // Clock
              @"com.apple.Maps",               // Maps
              @"com.apple.weather",            // Weather
              @"com.apple.reminders",          // Reminders
              @"com.apple.mobilenotes",        // Notes
              @"com.apple.stocks",             // Stocks
              @"com.apple.news",               // News
              @"com.apple.iBooks",             // Books
              @"com.apple.podcasts",           // Podcasts
              @"com.apple.tv",                 // TV
              @"com.apple.Health",             // Health
              @"com.apple.Home",               // Home
              @"com.apple.Passbook",           // Wallet
              @"com.apple.mobilephone",        // Phone
              @"com.apple.MobileSMS",          // Messages
              @"com.apple.DocumentsApp",       // Files
              @"com.apple.findmy",             // Find My
              @"com.apple.shortcuts",          // Shortcuts
              @"com.apple.MobileStore",        // iTunes Store
              @"com.apple.Translate",          // Translate
              @"com.apple.MobileAddressBook",  // Contacts
              @"com.apple.Bridge",             // Watch
              @"com.apple.tips",               // Tips
              @"com.apple.VoiceMemos",         // Voice Memos
              @"com.apple.compass",            // Compass
              @"com.apple.measure",            // Measure
              @"com.apple.calculator",         // Calculator
              @"com.apple.Music",              // Music
              
              /* Store Applications */
              @"com.apple.store.Jolly",        // Apple Store
              @"com.apple.AppStoreConnect",    // Connect
              @"com.apple.TestFlight",         // TestFlight
              @"com.apple.airport.mobileairportutility",  // AirPort Utility
              @"com.apple.Pages",              // Pages
              @"com.apple.Numbers",            // Numbers
              @"com.apple.Keynote",            // Keynote
              @"com.apple.Research",           // Research
              @"com.apple.supportapp",         // Support
              @"com.apple.artistconnect",      // Artists
              @"com.apple.Remote",             // Remote
              @"com.apple.bnd",                // Beats Pill
              
              // ...
        ];
    });
    
    return _foregroundIDs;
}

+ (NSArray <NSString *> *)allowedAppleProductBundleIDs
{
    static NSMutableArray <NSString *> *_bundleIDs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _bundleIDs = [[NSMutableArray alloc] init];
        [_bundleIDs addObjectsFromArray:[self allowedAppleProductForegroundBundleIDs]];
        [_bundleIDs addObjectsFromArray:[self allowedAppleProductBackgroundBundleIDs]];
    });;
    return _bundleIDs;
}

- (instancetype)init
{
    if (self = [super init])
    {
        @autoreleasepool {
            
            // initialize variables
            assert(kLuaBridgeInstanceName.length > 0);
            assert(kLuaBridgeMessagingCenterName.length > 0);
            assert(kLuaBridgeRemoteNotificationCenterName.length > 0);
            assert(kLuaBridgeLocalNotificationCenterName.length > 0);
            
            _sessionID = [[NSUUID UUID] UUIDString];
            _localGetNotificationName = [NSString stringWithFormat:@"%@.GetArguments", kLuaBridgeLocalNotificationCenterName];
            _localPutNotificationName = [NSString stringWithFormat:@"%@.PutResponse", kLuaBridgeLocalNotificationCenterName];
            
            _requestPulled = dispatch_semaphore_create(0);
            _responsePushed = dispatch_semaphore_create(0);
            
            _arguments = nil;
            _response = nil;
            int lock_state;
            lock_state = pthread_rwlock_init(&_lockArguments, NULL);
            assert(lock_state == 0);
            lock_state = pthread_rwlock_init(&_lockResponse, NULL);
            assert(lock_state == 0);
            
            NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
            
            if ([bundleId isEqualToString:@"com.apple.springboard"]) {
                
                // monitor queue
                _remoteMonitorQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.queue.monitor", kLuaBridgeInstanceName] UTF8String], DISPATCH_QUEUE_SERIAL);
                
                // unblocker
                rocketbootstrap_unlock(kLuaBridgeMessagingCenterName.UTF8String);
                
                // apply rocketbootstrap regardless of iOS version (via rpetrich)
                _messagingCenter = [CPDistributedMessagingCenter centerNamed:kLuaBridgeMessagingCenterName];
                rocketbootstrap_distributedmessagingcenter_apply(_messagingCenter);
                
                // server
                [_messagingCenter runServerOnCurrentThread];
                [_messagingCenter registerForMessageName:kMessageNameClientPutArguments target:self selector:@selector(clientPutArguments:userInfo:)];
                [_messagingCenter registerForMessageName:kMessageNameClientGetResponse target:self selector:@selector(clientGetResponse:userInfo:)];
                [_messagingCenter registerForMessageName:kMessageNameServerGetArguments target:self selector:@selector(serverGetArguments:userInfo:)];
                [_messagingCenter registerForMessageName:kMessageNameServerPutResponse target:self selector:@selector(serverPutResponse:userInfo:)];
                [_messagingCenter registerForMessageName:kMessageNameClientReadDefaults target:self selector:@selector(clientReadDefaults:userInfo:)];
                [_messagingCenter registerForMessageName:kMessageNameServerWriteDefaults target:self selector:@selector(serverWriteDefaults:userInfo:)];
                
                _instanceRole = TFLuaBridgeRoleMiddleMan;
                CHDebugLog(@"[%@][Server] Launched from %@", kLuaBridgeInstanceName, bundleId);
                
            } else {
                
                // check if sandbox app
                NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
                    
                BOOL isAppleProduct = [bundleId isKindOfClass:[NSString class]] && [bundleId hasPrefix:@"com.apple."];
                BOOL isSandboxedProduct = [bundleId isKindOfClass:[NSString class]] && ([bundlePath hasPrefix:@"/private/var/containers/"] || [bundlePath hasPrefix:@"/var/containers/"] || [bundlePath hasPrefix:@"/Applications/"]);
                
                BOOL isWhitelistAppleProduct = [bundleId isKindOfClass:[NSString class]] && [[TFLuaBridge allowedAppleProductBundleIDs] containsObject:bundleId];
                
                if (!isAppleProduct || isWhitelistAppleProduct) {
                    
                    // apply rocketbootstrap regardless of iOS version (via rpetrich)
                    _messagingCenter = [CPDistributedMessagingCenter centerNamed:kLuaBridgeMessagingCenterName];
                    rocketbootstrap_distributedmessagingcenter_apply(_messagingCenter);
                    
                    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
                    if (!isAppleProduct && !isSandboxedProduct) {
                        
                        // client #1: privileged tool
                        _instanceRole = TFLuaBridgeRoleServer;
                        CHDebugLog(@"[%@][Client #1] Loaded for privileged tool %@", kLuaBridgeInstanceName, bundlePath);

                        {   // register notification for step #2
                            int getToken;
                            notify_register_dispatch([_localGetNotificationName UTF8String], &getToken, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(int token) {
                                CHDebugLog(@"[%@][Client #1] Notification arrived from %@, %zu bytes memory used", kLuaBridgeInstanceName, self->_localGetNotificationName, [TFLuaBridge __getMemoryUsedInBytes]);
                                [self signalRemoteClientDidGetArguments];
                            });

                            CHDebugLog(@"[%@][Client #1] Notification handler registered for %@", kLuaBridgeInstanceName, _localGetNotificationName);
                        }

                        {   // register notification for step #3
                            int putToken;
                            notify_register_dispatch([_localPutNotificationName UTF8String], &putToken, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(int token) {
                                CHDebugLog(@"[%@][Client #1] Notification arrived from %@, %zu bytes memory used", kLuaBridgeInstanceName, self->_localPutNotificationName, [TFLuaBridge __getMemoryUsedInBytes]);
                                [self signalRemoteClientDidPutResponse];
                            });
                            
                            CHDebugLog(@"[%@][Client #1] Notification handler registered for %@", kLuaBridgeInstanceName, _localPutNotificationName);
                        }
                        
                        // setup defaults
                        [self setupDefaultsReloadNotifications];
                        
                    } else {
                        
                        BOOL isBackgroundAppleProduct = [bundleId isKindOfClass:[NSString class]] && [[TFLuaBridge allowedAppleProductBackgroundBundleIDs] containsObject:bundleId];
                        
                        if (isBackgroundAppleProduct) {
                            kLuaBridgeNotificationSuspensionBehavior = CFNotificationSuspensionBehaviorDeliverImmediately;
                        }
                        
                        // client #2: sandboxed app
                        _instanceRole = TFLuaBridgeRoleClient;
                        CHDebugLog(@"[%@][Client #2] Loaded for sandbox app %@", kLuaBridgeInstanceName, bundleId);
                        
                        CFNotificationCenterAddObserver(darwin, (__bridge_retained const void *)(self), LocalClientDidPutArguments, (__bridge_retained CFStringRef)kLuaBridgeRemoteNotificationCenterName, NULL, kLuaBridgeNotificationSuspensionBehavior);
                        
                        CHDebugLog(@"[%@][Client #2] Notification handler registered for %@", kLuaBridgeInstanceName, kLuaBridgeRemoteNotificationCenterName);
                        
                        // setup defaults
                        [self setupDefaultsReloadNotifications];
                        
                        // run reveal server
#if DEBUG
                        NSURL *revealBundleURL = [NSURL fileURLWithPath:@"/Library/Frameworks/RevealServer.framework" isDirectory:YES];
                        BOOL revealLoaded = [[NSBundle bundleWithURL:revealBundleURL] load];
                        if (revealLoaded) {
                            CHDebugLog(@"[%@][Client #2] RevealServer.framework side-loaded", kLuaBridgeInstanceName);
                        } else {
                            CHDebugLog(@"[%@][Client #2] RevealServer.framework failed to load", kLuaBridgeInstanceName);
                        }
#endif
                    }
                }
            }
        }
    }
    
    return self;
}

- (NSString *)instanceRoleName {
    if (_instanceRole == TFLuaBridgeRoleClient) {
        return @"Client #2";
    }
    if (_instanceRole == TFLuaBridgeRoleServer) {
        return @"Client #1";
    }
    if (_instanceRole == TFLuaBridgeRoleMiddleMan) {
        return @"Server";
    }
    return @"Unknown Role";
}

- (CPDistributedMessagingCenter *)messagingCenter
{
    return _messagingCenter;
}

- (NSString *)sessionID
{
    return _sessionID;
}

- (void)signalRemoteClientDidGetArguments
{
    dispatch_semaphore_signal(_requestPulled);
}

- (void)signalRemoteClientDidPutResponse
{
    dispatch_semaphore_signal(_responsePushed);
}

- (void)notifyLocalClientDidGetArguments
{
    notify_post([_localGetNotificationName UTF8String]);
}

- (void)notifyLocalClientDidPutResponse
{
    notify_post([_localPutNotificationName UTF8String]);
}

- (nullable id)localClientDoAction:(NSString *)actionName
                          userInfo:(NSDictionary *)userInfo
                             error:(NSError *__autoreleasing*)error
{
    return [self localClientDoAction:actionName userInfo:userInfo timeout:-1 error:error];
}

- (nullable id)localClientDoAction:(NSString *)actionName
                          userInfo:(NSDictionary *)userInfo
                           timeout:(NSTimeInterval)timeout
                             error:(NSError *__autoreleasing*)error
{
    NSError *strongErr = nil;
    
    NSDictionary *args = @{
        @"action": actionName,
        @"data": userInfo,
    };
    
    CHDebugLog(@"[%@][Client #1] Will put arguments action %@ user info %@, %zu bytes memory used", kLuaBridgeInstanceName, actionName, userInfo, [TFLuaBridge __getMemoryUsedInBytes]);
    
    _requestPulled = dispatch_semaphore_create(0);
    _responsePushed = dispatch_semaphore_create(0);
    
    NSError *reqErr = nil;
    NSDictionary *req = nil;
    
    @autoreleasepool {
        req = [_messagingCenter sendMessageAndReceiveReplyName:kMessageNameClientPutArguments userInfo:args error:&reqErr];
        
        if (timeout < 0) {
            CHDebugLog(@"[%@][Client #1] Did put arguments response %@ error %@ wait forever, %zu bytes memory used", kLuaBridgeInstanceName, req, reqErr, [TFLuaBridge __getMemoryUsedInBytes]);
        } else {
            CHDebugLog(@"[%@][Client #1] Did put arguments response %@ error %@ wait for %.2fs, %zu bytes memory used", kLuaBridgeInstanceName, req, reqErr, timeout, [TFLuaBridge __getMemoryUsedInBytes]);
        }
        
        if (![req isKindOfClass:[NSDictionary class]]) {
            strongErr = [NSError errorWithDomain:[NSString stringWithFormat:@"%@.FatalError", kLuaBridgeInstanceName] code:500 userInfo:@{
                             NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot put arguments to remote: %@", reqErr.localizedDescription],
            }];
        }
        else if ([req isKindOfClass:[NSDictionary class]] && [req objectForKey:@"error"]) {
            strongErr = [NSError errorWithDomain:[NSString stringWithFormat:@"%@.RecoverableError", kLuaBridgeInstanceName] code:500 userInfo:@{
                             NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot put arguments to remote: %@", req[@"error"]],
            }];
        }
    }
    
    if (!strongErr) {
        BOOL pullTimedOut = dispatch_wait(_requestPulled, dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC)) != 0;
        if (!pullTimedOut) {
            if (timeout < 0) {
                dispatch_wait(_responsePushed, DISPATCH_TIME_FOREVER);
            } else {
                dispatch_wait(_responsePushed, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC));
            }
        }
        
        CHDebugLog(@"[%@][Client #1] Will get response, %zu bytes memory used", kLuaBridgeInstanceName, [TFLuaBridge __getMemoryUsedInBytes]);
        
        NSError *respErr = nil;
        NSDictionary *resp = nil;
        
        @autoreleasepool {
            resp = [_messagingCenter sendMessageAndReceiveReplyName:kMessageNameClientGetResponse userInfo:nil /* optional dictionary */ error:&respErr];
            
            if (!resp && !respErr) {
                strongErr = [NSError errorWithDomain:[NSString stringWithFormat:@"%@.RecoverableError", kLuaBridgeInstanceName] code:500 userInfo:@{
                    NSLocalizedDescriptionKey: @"Operation timed out",
                }];
            } else {
                
                CHDebugLog(@"[%@][Client #1] Did get response %@ error %@, %zu bytes memory used", kLuaBridgeInstanceName, resp, respErr, [TFLuaBridge __getMemoryUsedInBytes]);
                
                if (![resp isKindOfClass:[NSDictionary class]]) {
                    strongErr = [NSError errorWithDomain:[NSString stringWithFormat:@"%@.RecoverableError", kLuaBridgeInstanceName] code:500 userInfo:@{
                        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot get response from remote: %@", respErr.localizedDescription],
                    }];
                } else {
                    NSDictionary <NSString *, id> *respDict = (NSDictionary <NSString *, id> *)resp;
                    int respCode = [respDict[@"code"] intValue];
                    if (respCode == 200) {
                        return respDict[@"data"];
                    } else {
                        strongErr = [NSError errorWithDomain:[NSString stringWithFormat:@"%@.RecoverableError", kLuaBridgeInstanceName] code:respCode userInfo:@{
                            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@", respDict[@"msg"]],
                        }];
                    }
                }
            }
        }
        
        if (!strongErr) {
            return resp;
        }
    }
    
    if (error) {
        if (*error == nil) {
            *error = strongErr;
        }
    }
    
    return nil;
}

// step #1
- (NSDictionary *)clientPutArguments:(NSString *)messageName
                            userInfo:(NSDictionary *)userInfo
{
    @autoreleasepool {
        SpringBoard *springboard = (SpringBoard *)[NSClassFromString(@"SpringBoard") sharedApplication];
        NSString *clientIdentifier = [[springboard _accessibilityFrontMostApplication] bundleIdentifier];
        if (!clientIdentifier.length) {
            CHDebugLog(@"[%@][Server] Client #1 try touch Client #2", kLuaBridgeInstanceName);
            return @{ @"error": @"No available accessibility front most application" };
        }
        CHDebugLog(@"[%@][Server] Client #1 touched Client #2 %@", kLuaBridgeInstanceName, clientIdentifier);
        if (pthread_rwlock_trywrlock(&_lockArguments) != 0) {
            CHDebugLog(@"[%@][Server] Client #1 try put arguments", kLuaBridgeInstanceName);
            return nil;
        }
        _arguments = [userInfo copy];
        pthread_rwlock_unlock(&_lockArguments);
        if (pthread_rwlock_trywrlock(&_lockResponse) != 0) {
            CHDebugLog(@"[%@][Server] Client #1 try clear response", kLuaBridgeInstanceName);
            return nil;
        }
        _response = nil;
        pthread_rwlock_unlock(&_lockResponse);
        CHDebugLog(@"[%@][Server] Client #1 clear response and put arguments %@, %zu bytes memory used", kLuaBridgeInstanceName, _arguments, [TFLuaBridge __getMemoryUsedInBytes]);
        notify_post([kLuaBridgeRemoteNotificationCenterName UTF8String]);
        return _arguments;
    }
}

// step #2
- (NSDictionary *)serverGetArguments:(NSString *)messageName
                            userInfo:(NSDictionary *)userInfo
{
    @autoreleasepool {
        if (pthread_rwlock_tryrdlock(&_lockArguments) != 0) {
            CHDebugLog(@"[%@][Server] Client #2 try get arguments", kLuaBridgeInstanceName);
            return nil;
        }
        
        NSString *foregroundIdentifier = nil;
        SBApplication *foregroundApplication = nil;
        if ([[userInfo objectForKey:@"bundleIdentifier"] isKindOfClass:[NSString class]]) {
            NSString *remoteIdentifier = userInfo[@"bundleIdentifier"];
            SBApplication *remoteApplication = [[objc_getClass("SBApplicationController") sharedInstance] applicationWithBundleIdentifier:remoteIdentifier];
            if (remoteApplication) {
                SBApplicationProcessState *processState = [remoteApplication processState];
                if ([processState isRunning] && [processState isForeground]) {
                    foregroundIdentifier = remoteIdentifier;
                    foregroundApplication = remoteApplication;
                }
            }
        }
        
        if (!foregroundIdentifier) {
            pthread_rwlock_unlock(&_lockArguments);
            CHDebugLog(@"[%@][Server] Invalid client %@, refused to feed arguments, %zu bytes memory used", kLuaBridgeInstanceName, userInfo, [TFLuaBridge __getMemoryUsedInBytes]);
            
            return nil;
        }
        
        NSDictionary *args = _arguments;
        pthread_rwlock_unlock(&_lockArguments);
        CHDebugLog(@"[%@][Server] Client #2 %@ got arguments %@, %zu bytes memory used", kLuaBridgeInstanceName, foregroundApplication, args, [TFLuaBridge __getMemoryUsedInBytes]);
        
        if (foregroundApplication) {
            objc_setAssociatedObject(foregroundApplication, &kMessageNameServerPutResponse, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        [self notifyLocalClientDidGetArguments];
        return args;
    }
}

// step #3
- (NSDictionary *)serverPutResponse:(NSString *)messageName
                           userInfo:(NSDictionary *)userInfo
{
    @autoreleasepool {
        if (pthread_rwlock_trywrlock(&_lockResponse) != 0) {
            CHDebugLog(@"[%@][Server] Client #2 try put response", kLuaBridgeInstanceName);
            return nil;
        }
        
        NSString *foregroundIdentifier = nil;
        SBApplication *foregroundApplication = nil;
        if ([[userInfo objectForKey:@"bundleIdentifier"] isKindOfClass:[NSString class]]) {
            NSString *remoteIdentifier = userInfo[@"bundleIdentifier"];
            SBApplication *remoteApplication = [[objc_getClass("SBApplicationController") sharedInstance] applicationWithBundleIdentifier:remoteIdentifier];
            if (remoteApplication) {
                SBApplicationProcessState *processState = [remoteApplication processState];
                if ([processState isRunning]) {
                    foregroundIdentifier = remoteIdentifier;
                    foregroundApplication = remoteApplication;
                }
            }
        }
        
        if (!foregroundIdentifier) {
            pthread_rwlock_unlock(&_lockArguments);
            CHDebugLog(@"[%@][Server] Invalid client %@, refused to put response, %zu bytes memory used", kLuaBridgeInstanceName, userInfo, [TFLuaBridge __getMemoryUsedInBytes]);
            
            return nil;
        }
        
        _response = [userInfo copy];
        pthread_rwlock_unlock(&_lockResponse);
        CHDebugLog(@"[%@][Server] Client #2 put response %@, %zu bytes memory used", kLuaBridgeInstanceName, _response, [TFLuaBridge __getMemoryUsedInBytes]);
        
        if (foregroundApplication) {
            objc_setAssociatedObject(foregroundApplication, &kMessageNameServerPutResponse, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        [self notifyLocalClientDidPutResponse];
        return _response;
    }
}

// step #4
- (NSDictionary *)clientGetResponse:(NSString *)messageName
                           userInfo:(NSDictionary *)userInfo
{
    @autoreleasepool {
        if (pthread_rwlock_tryrdlock(&_lockResponse) != 0) {
            CHDebugLog(@"[%@][Server] Client #1 try get response", kLuaBridgeInstanceName);
            return nil;
        }
        NSDictionary *resp = _response;
        pthread_rwlock_unlock(&_lockResponse);
        CHDebugLog(@"[%@][Server] Client #1 got response %@, %zu bytes memory used", kLuaBridgeInstanceName, resp, [TFLuaBridge __getMemoryUsedInBytes]);
        return resp;
    }
}

@end


#pragma mark -

CHDeclareClass(SBApplication);

CHOptimizedMethod(2, self, void, SBApplication, _noteProcess, id, process, didChangeToState, id, state)
{
    @autoreleasepool {
        CHSuper(2, SBApplication, _noteProcess, process, didChangeToState, state);
        
        id <TFLuaBridgeProcessStateObserver> observer = objc_getAssociatedObject(self, &kMessageNameServerPutResponse);
        if (observer && state && ![state isRunning]) {
            [observer notifyLocalClientDidPutResponse];
            objc_setAssociatedObject(self, &kMessageNameServerPutResponse, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        CHDebugLogSource(@"application = %@, process = %@, state = %@, observer = %@", self, process, state, observer);
    }
}


#pragma mark -

CHConstructor {
    @autoreleasepool {
        CHLoadLateClass(SBApplication);
        CHHook(2, SBApplication, _noteProcess, didChangeToState);
    }
}


#endif  // TF_MIDDLE_MAN=1
