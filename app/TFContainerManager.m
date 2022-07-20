//
//  TFContainerManager.m
//  XXTouch
//
//  Created by Lessica on 5/18/22.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <Foundation/Foundation.h>


#pragma mark -

#if DEBUG
#define CHDebug 1
#endif


#pragma mark -

#import "TFContainerManager.h"
#import "TFShell.h"
#import <CaptainHook/CaptainHook.h>
#import "MyCHHook.h"
#import <rocketbootstrap/rocketbootstrap.h>


#define XPC_INSTANCE_NAME (XPC_MODULE_PREFIX CHStringify(XPC_MODULE_NAME))
#define XPC_ONEWAY_MSG_NAME "OneWayMessage"
#define XPC_TWOWAY_MSG_NAME "TwoWayMessage"


#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif


#pragma mark -

@interface TFContainerManager (Private)

@property (nonatomic, strong) CPDistributedMessagingCenter *messagingCenter;

+ (instancetype)sharedInstanceWithRole:(TFContainerManagerRole)role;
- (instancetype)initWithRole:(TFContainerManagerRole)role;

@end


#pragma mark -

@implementation TFContainerManager {
    TFContainerManagerRole _role;
    dispatch_queue_t _eventQueue;
}

@synthesize messagingCenter = _messagingCenter;

+ (instancetype)sharedManager {
    return [self sharedInstanceWithRole:TFContainerManagerRoleClient];
}

+ (instancetype)sharedInstanceWithRole:(TFContainerManagerRole)role {
    static TFContainerManager *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[TFContainerManager alloc] initWithRole:role];
    });
    return _server;
}

- (instancetype)initWithRole:(TFContainerManagerRole)role {
    self = [super init];
    if (self) {
        _role = role;
        _eventQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.queue.events", @XPC_INSTANCE_NAME] UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (TFContainerManagerRole)role {
    return _role;
}

- (CPDistributedMessagingCenter *)messagingCenter {
    return _messagingCenter;
}

- (void)setMessagingCenter:(CPDistributedMessagingCenter *)messagingCenter {
    _messagingCenter = messagingCenter;
}

- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    return [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
}

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    NSAssert(sendErr == nil, @"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    return replyInfo;
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSAssert(_role == TFContainerManagerRoleServer, @"invalid role to receive message");
    
    @autoreleasepool {
        NSString *selectorName = [userInfo objectForKey:@"selector"];
        SEL selector = NSSelectorFromString(selectorName);
        NSAssert([self respondsToSelector:selector], @"invalid selector");
        
        NSInvocation *forwardInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
        [forwardInvocation setSelector:selector];
        [forwardInvocation setTarget:self];
        
        NSInteger argumentIndex = 2;
        NSArray *arguments = [userInfo objectForKey:@"arguments"];
        for (NSObject *argument in arguments) {
            void *argumentPtr = (__bridge void *)(argument);
            [forwardInvocation setArgument:&argumentPtr atIndex:argumentIndex];
            argumentIndex += 1;
        }
        
        [forwardInvocation invoke];
    }
}

- (NSDictionary *)receiveAndReplyMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSAssert(_role == TFContainerManagerRoleServer, @"invalid role to receive message");
    
    @autoreleasepool {
        NSString *selectorName = [userInfo objectForKey:@"selector"];
        SEL selector = NSSelectorFromString(selectorName);
        NSAssert([self respondsToSelector:selector], @"invalid selector");
        
        NSInvocation *forwardInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
        [forwardInvocation setSelector:selector];
        [forwardInvocation setTarget:self];
        
        NSInteger argumentIndex = 2;
        NSArray *arguments = [userInfo objectForKey:@"arguments"];
        for (NSObject *argument in arguments) {
            void *argumentPtr = (__bridge void *)(argument);
            [forwardInvocation setArgument:&argumentPtr atIndex:argumentIndex];
            argumentIndex += 1;
        }
        
        [forwardInvocation invoke];
        
        NSDictionary * __unsafe_unretained returnVal = nil;
        [forwardInvocation getReturnValue:&returnVal];
        NSDictionary *safeReturnVal = returnVal;
        NSAssert([safeReturnVal isKindOfClass:[NSDictionary class]], @"invalid return value");
        
        return safeReturnVal;
    }
}

- (NSArray <TFAppItem *> *)appItemsWithError:(NSError *__autoreleasing *)error
{
    return [self appItemsWithOptions:TFContainerManagerFetchWithSystemApplications error:error];
}

- (NSArray <TFAppItem *> *)userAppItemsWithError:(NSError *__autoreleasing *)error
{
    return [self appItemsWithOptions:TFContainerManagerFetchDefault error:error];
}

- (NSArray <TFAppItem *> *)appItemsWithOptions:(TFContainerManagerFetchOptions)options error:(NSError *__autoreleasing *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_appItemsWithOptions:)),
        @"arguments": [NSArray arrayWithObjects:@(options), nil],
    }];
    
    CHDebugLog(@"_appItemsWithOptions: %lu -> %@", (unsigned long)options, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSArray class]], @"invalid xpc reply");
    NSArray <NSDictionary *> *replyList = replyObject[@"reply"];
    NSMutableArray <TFAppItem *> *appItems = [NSMutableArray arrayWithCapacity:replyList.count];
    for (NSDictionary *replyDict in replyList) {
        [appItems addObject:[[TFAppItem alloc] initWithDictionary:replyDict]];
    }
    
    return appItems;
}

- (NSDictionary *)_appItemsWithOptions:(NSNumber *)opts
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        TFContainerManagerFetchOptions options = [opts intValue];
        BOOL userOnly = !(options & TFContainerManagerFetchWithSystemApplications);
        NSArray <TFAppItem *> *appItems = TFCopyAppItems(userOnly, options, &internalErr);
        
        if (!appItems) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"cannot find any app item",
            };
            return;
        }
        
        NSMutableArray <NSDictionary *> *replyList = [NSMutableArray arrayWithCapacity:appItems.count];
        for (TFAppItem *appItem in appItems) {
            NSDictionary *replyDict = [appItem toDictionaryWithIconData:(options & TFContainerManagerFetchWithIconData) entitlements:(options & TFContainerManagerFetchWithEntitlements)];
            if ([replyDict isKindOfClass:[NSDictionary class]]) {
                [replyList addObject:replyDict];
            }
        }
        
        replyObject = @{
            @"reply": replyList,
        };
        return;
    });
    return replyObject;
}

- (TFAppItem *)appItemForIdentifier:(NSString *)identifier error:(NSError *__autoreleasing *)error
{
    return [self appItemForIdentifier:identifier options:TFContainerManagerFetchWithSystemApplications error:error];
}

- (TFAppItem *)userAppItemForIdentifier:(NSString *)identifier error:(NSError *__autoreleasing *)error
{
    return [self appItemForIdentifier:identifier options:TFContainerManagerFetchDefault error:error];
}

- (TFAppItem *)appItemForIdentifier:(NSString *)identifier options:(TFContainerManagerFetchOptions)options error:(NSError *__autoreleasing *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_appItemForIdentifier:options:)),
        @"arguments": [NSArray arrayWithObjects:identifier, @(options), nil],
    }];
    
    CHDebugLog(@"_appItemForIdentifier:options: %@ %lu -> %@", identifier, (unsigned long)options, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSDictionary class]], @"invalid xpc reply");
    NSDictionary *replyDict = replyObject[@"reply"];
    TFAppItem *appItem = [[TFAppItem alloc] initWithDictionary:replyDict];
    return appItem;
}

- (NSDictionary *)_appItemForIdentifier:(NSString *)identifier options:(NSNumber *)opts
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        TFContainerManagerFetchOptions options = [opts intValue];
        TFAppItem *appItem = nil;
        if (options & TFContainerManagerFetchWithSystemApplications) {
            appItem = TFCopyAppItemForIdentifier(identifier, options, &internalErr);
        } else {
            appItem = TFCopyUserAppItemForIdentifier(identifier, options, &internalErr);
        }
        
        if (!appItem) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"no such app item",
            };
            return;
        }
        
        NSDictionary *replyDict = [appItem toDictionaryWithIconData:YES entitlements:YES];
        
        if ([replyDict isKindOfClass:[NSDictionary class]]) {
            replyObject = @{
                @"reply": replyDict,
            };
        }
        
        return;
    });
    return replyObject;
}

- (NSArray <TFAppItem *> *)searchAppItemsWithDisplayName:(NSString *)displayName options:(TFContainerManagerFetchOptions)options error:(NSError *__autoreleasing  _Nullable *)error
{
    NSArray <TFAppItem *> *allAppItems = [self appItemsWithOptions:options error:error];
    NSMutableArray <TFAppItem *> *filteredAppItems = [NSMutableArray arrayWithCapacity:allAppItems.count];
    for (TFAppItem *appItem in allAppItems) {
        if ([appItem.name isEqualToString:displayName]) {
            [filteredAppItems addObject:appItem];
        }
    }
    return [filteredAppItems copy];
}

- (NSString *)frontmostAppIdentifierWithError:(NSError *__autoreleasing *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_frontmostAppIdentifier)),
        @"arguments": [NSArray array],
    }];
    
    CHDebugLog(@"_frontmostAppIdentifier -> %@", replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSString class]], @"invalid xpc reply");
    return replyObject[@"reply"];
}

- (NSDictionary *)_frontmostAppIdentifier
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        NSString *appIdentifier = TFFrontmostAppIdentifier(&internalErr);
        
        if (!appIdentifier) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"no frontmost app",
            };
            return;
        }
        
        replyObject = @{
            @"reply": appIdentifier,
        };
        return;
    });
    return replyObject;
}

- (BOOL)launchAppWithIdentifier:(NSString *)identifier error:(NSError *__autoreleasing *)error
{
    return [self launchAppWithIdentifier:identifier inBackground:NO error:error];
}

- (BOOL)launchAppWithIdentifier:(NSString *)identifier inBackground:(BOOL)inBackground error:(NSError *__autoreleasing *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_launchAppWithIdentifier:inBackground:)),
        @"arguments": [NSArray arrayWithObjects:identifier, @(inBackground), nil],
    }];
    
    CHDebugLog(@"_launchAppWithIdentifier: %@ -> %@", identifier, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc reply");
    return [replyObject[@"reply"] boolValue];
}

- (NSDictionary *)_launchAppWithIdentifier:(NSString *)identifier inBackground:(NSNumber *)inBackground
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        BOOL launched = TFLaunchAppWithIdentifier(identifier, [inBackground boolValue], &internalErr);
        
        if (!launched) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"no such application",
            };
            return;
        }
        
        replyObject = @{
            @"reply": @(launched),
        };
        return;
    });
    return replyObject;
}

- (BOOL)terminateAppWithIdentifier:(NSString *)identifier
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_terminateAppWithIdentifier:)),
        @"arguments": [NSArray arrayWithObjects:identifier, nil],
    }];
    
    CHDebugLog(@"_terminateAppWithIdentifier: %@ -> %@", identifier, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        return NO;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc reply");
    return [replyObject[@"reply"] intValue] > 0;
}

- (NSDictionary *)_terminateAppWithIdentifier:(NSString *)identifier
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        pid_t pid = TFProcessIDOfApplicationXPC(identifier, YES);
        
        if (pid == 0) {
            replyObject = @{
                @"error": @"no such application",
            };
            return;
        }
        
        replyObject = @{
            @"reply": @(pid),
        };
        return;
    });
    return replyObject;
}

- (BOOL)terminateAllApp
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    return [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_terminateAllApp)),
        @"arguments": [NSArray array],
    }];
}

- (void)_terminateAllApp
{
    dispatch_sync(_eventQueue, ^{
        TFStopRunningUIKitApplications(YES);
    });
}

- (pid_t)processIdentifierForAppIdentifier:(NSString *)identifier
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_processIdentifierForAppIdentifier:)),
        @"arguments": [NSArray arrayWithObjects:identifier, nil],
    }];
    
    CHDebugLog(@"_processIdentifierForAppIdentifier: %@ -> %@", identifier, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        return NO;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc reply");
    return [replyObject[@"reply"] intValue];
}

- (NSDictionary *)_processIdentifierForAppIdentifier:(NSString *)identifier
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        pid_t pid = TFProcessIDOfApplicationXPC(identifier, NO);
        
        if (pid == 0) {
            replyObject = @{
                @"error": @"no such application",
            };
            return;
        }
        
        replyObject = @{
            @"reply": @(pid),
        };
        return;
    });
    return replyObject;
}

- (NSArray <TFAppItem *> *)runningAppItemsWithError:(NSError *__autoreleasing  _Nullable *)error
{
    return [self runningAppItemsWithOptions:TFContainerManagerFetchDefault error:error];
}

- (NSArray <TFAppItem *> *)runningAppItemsWithOptions:(TFContainerManagerFetchOptions)options error:(NSError *__autoreleasing  _Nullable *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_runningAppItemsWithOptions:)),
        @"arguments": [NSArray arrayWithObjects:@(options), nil],
    }];
    
    CHDebugLog(@"_runningAppItemsWithOptions: %lu -> %@", (unsigned long)options, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSArray class]], @"invalid xpc reply");
    NSArray <NSDictionary *> *replyList = replyObject[@"reply"];
    NSMutableArray <TFAppItem *> *appItems = [NSMutableArray arrayWithCapacity:replyList.count];
    for (NSDictionary *replyDict in replyList) {
        [appItems addObject:[[TFAppItem alloc] initWithDictionary:replyDict]];
    }
    
    return appItems;
}

- (NSDictionary *)_runningAppItemsWithOptions:(NSNumber *)opts
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        TFContainerManagerFetchOptions options = [opts intValue];
        
        int pidc;
        pid_t *pidp;
        BOOL userOnly = !(options & TFContainerManagerFetchWithSystemApplications);
        NSArray <NSString *> *bids = TFCopyRunningUIKitApplications(!userOnly, &pidp, &pidc);
        NSAssert(pidc == bids.count, @"not matched");
        
        CHDebugLog(@"TFCopyRunningUIKitApplications -> %@", bids);
        
        NSArray <TFAppItem *> *allAppItems = TFCopyAppItems(userOnly, options, &internalErr);
        NSMutableArray <TFAppItem *> *appItems = [NSMutableArray arrayWithCapacity:MIN(bids.count, allAppItems.count)];
        for (TFAppItem *appItem in allAppItems) {
            NSUInteger foundIdx = [bids indexOfObject:appItem.identifier];
            if (foundIdx == NSNotFound)
                continue;
            appItem.processIdentifier = *(pidp + (int)foundIdx);
            [appItems addObject:appItem];
        }
        
        if (!appItems) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"cannot find any app item",
            };
            return;
        }
        
        NSMutableArray <NSDictionary *> *replyList = [NSMutableArray arrayWithCapacity:appItems.count];
        for (TFAppItem *appItem in appItems) {
            NSDictionary *replyDict = [appItem toDictionaryWithIconData:(options & TFContainerManagerFetchWithIconData) entitlements:(options & TFContainerManagerFetchWithEntitlements)];
            if ([replyDict isKindOfClass:[NSDictionary class]]) {
                [replyList addObject:replyDict];
            }
        }
        
        replyObject = @{
            @"reply": replyList,
        };
        return;
    });
    return replyObject;
}

- (BOOL)installIPAArchiveAtPath:(NSString *)path removeAfterInstallation:(BOOL)remove error:(NSError *__autoreleasing  _Nullable *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_installIPAArchiveAtPath:removeAfterInstallation:)),
        @"arguments": [NSArray arrayWithObjects:path, @(remove), nil],
    }];
    
    CHDebugLog(@"_installIPAArchiveAtPath:removeAfterInstallation: %@ %@ -> %@", path, remove ? @"YES" : @"NO", replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc reply");
    return [replyObject[@"reply"] boolValue];
}

- (NSDictionary *)_installIPAArchiveAtPath:(NSString *)path removeAfterInstallation:(NSNumber *)remove
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        BOOL installed = TFInstallIPAArchiveAtPath(path, [remove boolValue], &internalErr);
        
        if (!installed) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"unknown error",
            };
            return;
        }
        
        replyObject = @{
            @"reply": @(installed),
        };
        return;
    });
    return replyObject;
}

- (BOOL)uninstallApplicationWithIdentifier:(NSString *)identifier error:(NSError *__autoreleasing  _Nullable *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_uninstallApplicationWithIdentifier:)),
        @"arguments": [NSArray arrayWithObjects:identifier, nil],
    }];
    
    CHDebugLog(@"_uninstallApplicationWithIdentifier: %@ -> %@", identifier, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc reply");
    return [replyObject[@"reply"] boolValue];
}

- (NSDictionary *)_uninstallApplicationWithIdentifier:(NSString *)identifier
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        BOOL installed = TFUninstallAppWithIdentifier(identifier, &internalErr);
        
        if (!installed) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"no such application",
            };
            return;
        }
        
        replyObject = @{
            @"reply": @(installed),
        };
        return;
    });
    return replyObject;
}

- (BOOL)packAppWithIdentifier:(NSString *)identifier toIPAArchivePath:(NSString *)ipaPath error:(NSError *__autoreleasing  _Nullable *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_packAppWithIdentifier:toIPAArchivePath:)),
        @"arguments": [NSArray arrayWithObjects:identifier, ipaPath, nil],
    }];
    
    CHDebugLog(@"_packAppWithIdentifier:toIPAArchivePath: %@ %@ -> %@", identifier, ipaPath, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc reply");
    return [replyObject[@"reply"] boolValue];
}

- (BOOL)packBundleContainerAtPath:(NSString *)path toIPAArchivePath:(NSString *)ipaPath error:(NSError *__autoreleasing  _Nullable *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_packBundleContainerAtPath:toIPAArchivePath:)),
        @"arguments": [NSArray arrayWithObjects:path, ipaPath, nil],
    }];
    
    CHDebugLog(@"_packBundleContainerAtPath:toIPAArchivePath: %@ %@ -> %@", path, ipaPath, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc reply");
    return [replyObject[@"reply"] boolValue];
}

- (NSDictionary *)_packAppWithIdentifier:(NSString *)identifier toIPAArchivePath:(NSString *)ipaPath
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        TFAppItem *appItem = TFCopyUserAppItemForIdentifier(identifier, TFContainerManagerFetchDefault, &internalErr);
        if (!appItem) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"no such app item",
            };
            return;
        }
        
        BOOL installed = TFPackBundleContainerAtPath([appItem bundleContainer], ipaPath, &internalErr);
        if (!installed) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"unknown error",
            };
            return;
        }
        
        replyObject = @{
            @"reply": @(installed),
        };
        return;
    });
    return replyObject;
}

- (NSDictionary *)_packBundleContainerAtPath:(NSString *)path toIPAArchivePath:(NSString *)ipaPath
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        BOOL installed = TFPackBundleContainerAtPath(path, ipaPath, &internalErr);
        
        if (!installed) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"unknown error",
            };
            return;
        }
        
        replyObject = @{
            @"reply": @(installed),
        };
        return;
    });
    return replyObject;
}

- (BOOL)openSensitiveURL:(NSURL *)url error:(NSError *__autoreleasing  _Nullable *)error
{
    return [self openSensitiveURLWithString:url.absoluteString error:error];
}

- (BOOL)openSensitiveURLWithString:(NSString *)urlString error:(NSError *__autoreleasing  _Nullable *)error
{
    NSAssert(_role == TFContainerManagerRoleClient, @"invalid role to send message");
    
    NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
        @"selector": NSStringFromSelector(@selector(_openSensitiveURLWithString:)),
        @"arguments": [NSArray arrayWithObjects:urlString, nil],
    }];
    
    CHDebugLog(@"_openSensitiveURLWithString: %@ -> %@", urlString, replyObject);
    
    if ([replyObject[@"error"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: replyObject[@"error"] }];
        }
        return nil;
    }
    
    NSAssert([replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc reply");
    return [replyObject[@"reply"] boolValue];
}

- (NSDictionary *)_openSensitiveURLWithString:(NSString *)urlString
{
    __block NSDictionary *replyObject = nil;
    dispatch_sync(_eventQueue, ^{
        
        NSError *internalErr = nil;
        BOOL installed = TFOpenSensitiveURL([NSURL URLWithString:urlString], &internalErr);
        
        if (!installed) {
            replyObject = @{
                @"error": [internalErr localizedDescription] ?: @"unknown error",
            };
            return;
        }
        
        replyObject = @{
            @"reply": @(installed),
        };
        return;
    });
    return replyObject;
}

@end


#pragma mark -

#import "MyAntiDebugging.h"

CHConstructor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] arguments][0];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        BOOL forceClient = [[[NSProcessInfo processInfo] environment][@"CLIENT"] boolValue];
        
        if (!forceClient && ([processName isEqualToString:@"tfcontainermanagerd"] || [processName hasSuffix:@"/tfcontainermanagerd"]))
        {   /* Server Process - tfcontainermanagerd */
            
            do {
                
                /// do inject to protected executable only
                if (!dlsym(RTLD_MAIN_ONLY, "plugin_i_love_xxtouch")) {
                    break;
                }
                
                root_anti_debugging(NO);
                
                rocketbootstrap_unlock(XPC_INSTANCE_NAME);
                
                CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
                rocketbootstrap_distributedmessagingcenter_apply(messagingCenter);
                [messagingCenter runServerOnCurrentThread];
                
                TFContainerManager *serverInstance = [TFContainerManager sharedInstanceWithRole:TFContainerManagerRoleServer];
                [messagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
                [messagingCenter registerForMessageName:@XPC_TWOWAY_MSG_NAME target:serverInstance selector:@selector(receiveAndReplyMessageName:userInfo:)];
                [serverInstance setMessagingCenter:messagingCenter];
                
                CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", messagingCenter, bundleIdentifier, processName, getpid());
                
            } while (NO);
        }
        else
        {   /* Client */
            
            do {
                
                CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
                rocketbootstrap_distributedmessagingcenter_apply(messagingCenter);
                
                TFContainerManager *clientInstance = [TFContainerManager sharedInstanceWithRole:TFContainerManagerRoleClient];
                [clientInstance setMessagingCenter:messagingCenter];
                
                CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", messagingCenter, bundleIdentifier, processName, getpid());
                
            } while (NO);
        }
    }
}

