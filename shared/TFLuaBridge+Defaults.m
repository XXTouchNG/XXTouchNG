//
//  TFLuaBridge+Defaults.m
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TFLuaBridge.h"
#import <pthread.h>
#import <notify.h>

OBJC_EXTERN NSString *kLuaBridgeInstanceName;
OBJC_EXTERN NSString *const kMessageNameClientReadDefaults;
OBJC_EXTERN NSString *const kMessageNameServerWriteDefaults;

@implementation TFLuaBridge (Defaults)

#pragma mark - Client/Server

+ (pthread_mutex_t *)sharedDefaultsLock {
    static pthread_mutex_t _sharedDefaultsLock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_mutex_init(&_sharedDefaultsLock, NULL);
    });
    return &_sharedDefaultsLock;
}

- (void)setupDefaultsReloadNotifications {
    @autoreleasepool {
        NSString *notifyName = [NSString stringWithFormat:@"%@.DefaultsReloadNotification", kLuaBridgeInstanceName];
        
        int token;
        notify_register_dispatch([notifyName UTF8String], &token, [TFLuaBridge sharedDefaultsQueue], ^(int token) {
            @autoreleasepool {
                CHDebugLog(@"[%@][%@] notified reload, will reset cached defaults", kLuaBridgeInstanceName, self.instanceRoleName);
                
                pthread_mutex_lock([TFLuaBridge sharedDefaultsLock]);
                self.cachedDefaults = nil;  // reset cached defaults
                pthread_mutex_unlock([TFLuaBridge sharedDefaultsLock]);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    @autoreleasepool {
                        if ([self respondsToSelector:@selector(defaultsDidReload)]) {
                            [self performSelector:@selector(defaultsDidReload)];
                        }
                    }
                });
                
                CHDebugLog(@"[%@][%@] did reset cached defaults", kLuaBridgeInstanceName, self.instanceRoleName);
            }
        });

        CHDebugLog(@"[%@][%@] setup defaults reload notifications", kLuaBridgeInstanceName, self.instanceRoleName);
    }
}

- (NSDictionary *)readDefaultsWithError:(NSError *__autoreleasing*)error {
    NSError *strongErr = nil;
    NSDictionary *result = nil;
    @autoreleasepool {
        if (self.instanceRole == TFLuaBridgeRoleMiddleMan) {
            result = [self clientReadDefaults:[NSString stringWithFormat:@"%@.%@", kMessageNameClientReadDefaults, @"__LOCAL__"] userInfo:@{}];
            CHDebugLog(@"[%@][%@] read defaults from %@ %@", kLuaBridgeInstanceName, self.instanceRoleName, @"LOCAL", result);
            return result;
        }
        pthread_mutex_lock([TFLuaBridge sharedDefaultsLock]);
        if (self.cachedDefaults) {
            result = [self.cachedDefaults copy];
            CHDebugLog(@"[%@][%@] read defaults from %@ %@", kLuaBridgeInstanceName, self.instanceRoleName, @"CACHE", result);
        } else {
            NSDictionary *respResult = [[self messagingCenter] sendMessageAndReceiveReplyName:kMessageNameClientReadDefaults userInfo:@{} error:&strongErr];
            if ([respResult isKindOfClass:[NSDictionary class]]) {
                self.cachedDefaults = [respResult mutableCopy];
                result = respResult;
            }
            
            CHDebugLog(@"[%@][%@] read defaults from %@ %@", kLuaBridgeInstanceName, self.instanceRoleName, @"REMOTE", result);
        }
        pthread_mutex_unlock([TFLuaBridge sharedDefaultsLock]);
    }
    if (error) {
        *error = strongErr;
    }
    return result;
}

- (BOOL)writeDefaults:(NSDictionary *)defaults withError:(NSError *__autoreleasing*)error {
    BOOL result;
    NSError *strongErr = nil;
    @autoreleasepool {
        NSMutableDictionary *mPayload = [defaults mutableCopy];
        [mPayload setObject:@(YES) forKey:@"__OVERWRITE__"];
        result = [self rawWriteDefaults:mPayload withError:&strongErr];
    }
    if (error) {
        *error = strongErr;
    }
    return result;
}

- (BOOL)addEnteriesToDefaults:(NSDictionary *)defaults withError:(NSError *__autoreleasing*)error {
    BOOL result;
    NSError *strongErr = nil;
    @autoreleasepool {
        NSMutableDictionary *mPayload = [defaults mutableCopy];
        result = [self rawWriteDefaults:mPayload withError:&strongErr];
    }
    if (error) {
        *error = strongErr;
    }
    return result;
}

- (BOOL)rawWriteDefaults:(NSDictionary *)defaults withError:(NSError *__autoreleasing*)error {
    if (self.instanceRole == TFLuaBridgeRoleMiddleMan) {
        @autoreleasepool {
            NSDictionary *result = [self serverWriteDefaults:[NSString stringWithFormat:@"%@.%@", kMessageNameServerWriteDefaults, @"__LOCAL__"] userInfo:defaults];
            CHDebugLog(@"[%@][%@] write defaults to %@ %@", kLuaBridgeInstanceName, self.instanceRoleName, @"LOCAL", result);
            return YES;
        }
    }
    
    NSError *strongErr = nil;
    BOOL result = YES;
    @autoreleasepool {
        NSDictionary *resp = [[self messagingCenter] sendMessageAndReceiveReplyName:kMessageNameServerWriteDefaults userInfo:defaults error:&strongErr];
        if (![resp isKindOfClass:[NSDictionary class]]) {
            CHDebugLog(@"[%@][%@] fail to write defaults to %@, error %@", kLuaBridgeInstanceName, self.instanceRoleName, @"REMOTE", strongErr);
            result = NO;
        }
        
        CHDebugLog(@"[%@][%@] write defaults to %@ %@", kLuaBridgeInstanceName, self.instanceRoleName, @"REMOTE", resp);
    }
    
    if (!result) {
        if (error) {
            *error = strongErr;
        }
    }
    return result;
}

#pragma mark - Server

+ (dispatch_queue_t)sharedDefaultsQueue {
    static dispatch_queue_t _sharedDefaultsQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *queueName = [NSString stringWithFormat:@"%@.queue.defaults", kLuaBridgeInstanceName];
        _sharedDefaultsQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
    });
    return _sharedDefaultsQueue;
}

- (NSDictionary *)clientReadDefaults:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    @autoreleasepool {
        NSString *preferencesPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"Preferences"];
        NSString *defaultsPath = [[preferencesPath stringByAppendingPathComponent:kLuaBridgeInstanceName] stringByAppendingPathExtension:@"plist"];
        
        CHDebugLog(@"[%@][%@] Client #2 try read defaults", kLuaBridgeInstanceName, self.instanceRoleName);
        __block NSDictionary *result = nil;
        dispatch_sync([TFLuaBridge sharedDefaultsQueue], ^{
            result = [NSDictionary dictionaryWithContentsOfFile:defaultsPath] ?: @{};
        });
        
        CHDebugLog(@"[%@][%@] Client #2 read defaults %@", kLuaBridgeInstanceName, self.instanceRoleName, result);
        return result;
    }
}

- (NSDictionary *)serverWriteDefaults:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    @autoreleasepool {
        NSString *preferencesPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"Preferences"];
        NSString *defaultsPath = [[preferencesPath stringByAppendingPathComponent:kLuaBridgeInstanceName] stringByAppendingPathExtension:@"plist"];
        BOOL isOverwrite = [[userInfo objectForKey:@"__OVERWRITE__"] boolValue];
        
        CHDebugLog(@"[%@][%@] Client #1 try %@ defaults %@", kLuaBridgeInstanceName, self.instanceRoleName, isOverwrite ? @"overwrite" : @"write", userInfo);
        __block NSDictionary *result = nil;
        dispatch_sync([TFLuaBridge sharedDefaultsQueue], ^{
            @autoreleasepool {
                NSMutableDictionary *mDefaults = [([NSDictionary dictionaryWithContentsOfFile:defaultsPath] ?: @{}) mutableCopy];
                if ([mDefaults isKindOfClass:[NSDictionary class]]) {
                    if (isOverwrite) {
                        mDefaults = [userInfo mutableCopy];
                    } else {
                        [mDefaults addEntriesFromDictionary:userInfo];
                    }
                    [mDefaults removeObjectForKey:@"__OVERWRITE__"];
                } else {
                    mDefaults = [[NSMutableDictionary alloc] init];
                }
                [mDefaults writeToFile:defaultsPath atomically:YES];
                
                NSString *notifyName = [NSString stringWithFormat:@"%@.DefaultsReloadNotification", kLuaBridgeInstanceName];
                notify_post([notifyName UTF8String]);
                
                result = [mDefaults copy];
            }
        });
        
        CHDebugLog(@"[%@][%@] Client #1 wrote defaults %@", kLuaBridgeInstanceName, self.instanceRoleName, userInfo);
        return result;
    }
}

@end
