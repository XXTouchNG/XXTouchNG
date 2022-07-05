//
//  ProcQueue.m
//  ProcQueue
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "ProcQueue.h"
#import <rocketbootstrap/rocketbootstrap.h>
#import "OrderedDictionary.h"
#import <notify.h>


#define kProcQueueDefaultsChangedDistributedNotificationName "ch.xxtou.notification.procqueue.defaults-changed"
#define kProcQueueLaunchedDistributedNotificationName "ch.xxtou.notification.procqueue.launched"

@interface ProcQueue (Internal)

@property (nonatomic, strong) CPDistributedMessagingCenter *messagingCenter;

+ (instancetype)sharedInstanceWithRole:(ProcQueueRole)role;
- (instancetype)initWithRole:(ProcQueueRole)role;

@end


#pragma mark -

@implementation ProcQueue {
    ProcQueueRole _role;
    dispatch_queue_t _eventQueue;
    dispatch_queue_t _defaultsQueue;
    MutableOrderedDictionary <NSString *, NSString *> *_dictionary;
    MutableOrderedDictionary <NSString *, NSMutableArray <NSString *> *> *_queueDictionary;
    NSDictionary <NSString *, id> *_registeredDefaultsDictionary;
    NSMutableDictionary <NSString *, id> *_defaultsDictionary;
}

@synthesize messagingCenter = _messagingCenter;

+ (instancetype)sharedInstance {
    return [self sharedInstanceWithRole:ProcQueueRoleClient];
}

+ (instancetype)sharedInstanceWithRole:(ProcQueueRole)role {
    static ProcQueue *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[ProcQueue alloc] initWithRole:role];
    });
    return _server;
}

- (instancetype)initWithRole:(ProcQueueRole)role {
    self = [super init];
    if (self) {
        _role = role;
        _eventQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.EventQueue", @XPC_INSTANCE_NAME] UTF8String], DISPATCH_QUEUE_SERIAL);
        _defaultsQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.DefaultsQueue", @XPC_INSTANCE_NAME] UTF8String], DISPATCH_QUEUE_SERIAL);
        _dictionary = [[MutableOrderedDictionary alloc] init];
        _queueDictionary = [[MutableOrderedDictionary alloc] init];
        _defaultsDictionary = [[NSMutableDictionary alloc] init];
        _registeredDefaultsDictionary = nil;
    }
    return self;
}

- (ProcQueueRole)role {
    return _role;
}

- (CPDistributedMessagingCenter *)messagingCenter {
    return _messagingCenter;
}

- (void)setMessagingCenter:(CPDistributedMessagingCenter *)messagingCenter {
    _messagingCenter = messagingCenter;
}

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ProcQueueRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    NSAssert(sendSucceed, @"cannot send message %@, userInfo = %@", messageName, userInfo);
}

- (void)unsafeSendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ProcQueueRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    if (!sendSucceed) {
        CHLog(@"cannot send message %@, userInfo = %@", messageName, userInfo);
    }
}

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ProcQueueRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    NSAssert(sendErr == nil, @"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    return replyInfo;
}

- (NSDictionary *)unsafeSendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ProcQueueRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    if (!replyInfo) {
        CHLog(@"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    }
    return replyInfo;
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ProcQueueRoleServer, @"invalid role");
    
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

- (NSDictionary *)receiveAndReplyMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == ProcQueueRoleServer, @"invalid role to receive message");
    
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
        
        NSDictionary * __weak returnVal = nil;
        [forwardInvocation getReturnValue:&returnVal];
        NSDictionary *safeReturnVal = returnVal;
        NSAssert([safeReturnVal isKindOfClass:[NSDictionary class]], @"invalid return value");
        
        return safeReturnVal;
    }
}

#pragma mark -

- (NSDictionary *)defaultsDictionary
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(defaultsDictionary)),
                @"arguments": [NSArray array],
            }];
            
#if DEBUG
            NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSDictionary *dictionary = nil;
        dispatch_sync(_defaultsQueue, ^{
            @autoreleasepool {
                NSMutableDictionary *mDefaults = [_registeredDefaultsDictionary mutableCopy];
                [mDefaults addEntriesFromDictionary:_defaultsDictionary ?: @{}];
                dictionary = [mDefaults copy];
            }
        });
        return dictionary;
    }
}

- (nullable NSDictionary *)unsafeDefaultsDictionary
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self unsafeSendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(defaultsDictionary)),
                @"arguments": [NSArray array],
            }];
            
#if DEBUG
            NSAssert(replyObject == nil || [replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSDictionary *dictionary = nil;
        dispatch_sync(_defaultsQueue, ^{
            @autoreleasepool {
                NSMutableDictionary *mDefaults = [_registeredDefaultsDictionary mutableCopy];
                [mDefaults addEntriesFromDictionary:_defaultsDictionary ?: @{}];
                dictionary = [mDefaults copy];
            }
        });
        return dictionary;
    }
}

- (nullable id)objectForKey:(NSString *)key
{
    return [self _objectForKey:key][@"reply"];
}

- (nonnull NSDictionary *)_objectForKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_objectForKey:)),
                @"arguments": [NSArray arrayWithObjects:key, nil],
            }];
            
#if DEBUG
            NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block id replyObject = nil;
        dispatch_sync(_defaultsQueue, ^{
            replyObject = [_defaultsDictionary objectForKey:key];
            if (!replyObject) {
                replyObject = [_registeredDefaultsDictionary objectForKey:key];
            }
        });
        if (!replyObject) {
            return @{ };
        }
        return @{ @"reply": replyObject };
    }
}

- (void)registerDefaultEntries:(NSDictionary *)dictionary
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(registerDefaultEntries:)),
                @"arguments": [NSArray arrayWithObjects:dictionary, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        dispatch_sync(_defaultsQueue, ^{
            _registeredDefaultsDictionary = [dictionary copy];
        });
    }
}

- (void)addEntriesFromDictionary:(NSDictionary *)dictionary
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(addEntriesFromDictionary:)),
                @"arguments": [NSArray arrayWithObjects:dictionary, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        dispatch_sync(_defaultsQueue, ^{
            [_defaultsDictionary addEntriesFromDictionary:dictionary];
            [self writeDefaultsToDiskAtomically];
        });
    }
}

- (void)setObject:(id)object forKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(setObject:forKey:)),
                @"arguments": [NSArray arrayWithObjects:object, key, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        dispatch_sync(_defaultsQueue, ^{
            [_defaultsDictionary setObject:object forKey:key];
            [self writeDefaultsToDiskAtomically];
        });
    }
}

+ (NSFileManager *)defaultsFileManager
{
    static NSFileManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[NSFileManager alloc] init];
    });
    return manager;
}

+ (NSString *)defaultsPath
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [NSString stringWithFormat:@"/usr/local/xxtouch/etc/xxtouch.plist"];
        NSString *etcDirectory = [path stringByDeletingLastPathComponent];
        if (![[self defaultsFileManager] fileExistsAtPath:etcDirectory])
        {
            NSError *createError = nil;
            BOOL createSucceed = [[self defaultsFileManager] createDirectoryAtPath:etcDirectory
                                                       withIntermediateDirectories:YES
                                                                        attributes:nil
                                                                             error:&createError];
            NSAssert(createSucceed, @"%@", createError);
        }
    });
    return path;
}

- (void)writeDefaultsToDiskAtomically
{
    @autoreleasepool {
        NSError *propertyListError = nil;
        NSData *propertyListData = [NSPropertyListSerialization dataWithPropertyList:_defaultsDictionary
                                                                              format:NSPropertyListXMLFormat_v1_0
                                                                             options:0
                                                                               error:&propertyListError];
        NSAssert(propertyListData, @"%@", propertyListError);
        BOOL writeSucceed = [propertyListData writeToFile:[ProcQueue defaultsPath] options:kNilOptions error:&propertyListError];
        NSAssert(writeSucceed, @"%@", propertyListError);
        notify_post(kProcQueueDefaultsChangedDistributedNotificationName);
    }
}

- (void)removeObjectForKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(removeObjectForKey:)),
                @"arguments": [NSArray arrayWithObjects:key, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        dispatch_sync(_defaultsQueue, ^{
            [_defaultsDictionary removeObjectForKey:key];
            [self writeDefaultsToDiskAtomically];
        });
    }
}

- (void)removeAllObjects
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(removeAllObjects)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        dispatch_sync(_defaultsQueue, ^{
            [_defaultsDictionary removeAllObjects];
            [self writeDefaultsToDiskAtomically];
        });
    }
}

- (void)synchronize
{
    if (_role == ProcQueueRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(synchronize)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        dispatch_sync(_defaultsQueue, ^{
            [self _synchronize];
        });
    }
}

- (void)_synchronize
{
    if ([[ProcQueue defaultsFileManager] fileExistsAtPath:[ProcQueue defaultsPath]])
    {
        NSError *readError = nil;
        NSData *defaultsData = [[NSData alloc] initWithContentsOfFile:[ProcQueue defaultsPath] options:kNilOptions error:&readError];
        if (defaultsData)
        {
            NSAssert(defaultsData, @"%@", readError);
            NSDictionary *propertyListObject = [NSPropertyListSerialization propertyListWithData:defaultsData
                                                                                         options:0
                                                                                          format:NULL
                                                                                           error:&readError];
            if ([propertyListObject isKindOfClass:[NSDictionary class]])
            {
                NSAssert([propertyListObject isKindOfClass:[NSDictionary class]], @"%@", readError);
                _defaultsDictionary = [propertyListObject mutableCopy];
            }
            else
            {
                CHDebugLogSource(@"%@", readError);
                _defaultsDictionary = [[NSMutableDictionary alloc] init];
                [self writeDefaultsToDiskAtomically];
            }
        }
        else
        {
            CHDebugLogSource(@"%@", readError);
            _defaultsDictionary = [[NSMutableDictionary alloc] init];
            [self writeDefaultsToDiskAtomically];
        }
    }
    else
    {
        CHDebugLogSource(@"initialize new user defaults");
        _defaultsDictionary = [[NSMutableDictionary alloc] init];
        [self writeDefaultsToDiskAtomically];
    }
}


#pragma mark -

- (NSString *)dictionaryDescription
{
    @autoreleasepool {
        return (NSString *)[self _dictionaryDescription][@"reply"];
    }
}

- (NSDictionary *)_dictionaryDescription
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_dictionaryDescription)),
                @"arguments": [NSArray array],
            }];
            
            NSString *replyString = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyString isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:_dictionary
                                                           options:(NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted)
                                                             error:nil];
        return @{ @"reply": [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] };
    }
}

- (NSString *)queueDictionaryDescription
{
    @autoreleasepool {
        return (NSString *)[self _queueDictionaryDescription][@"reply"];
    }
}

- (NSDictionary *)_queueDictionaryDescription
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_queueDictionaryDescription)),
                @"arguments": [NSArray array],
            }];
            
            NSString *replyString = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyString isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:_queueDictionary
                                                           options:(NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted)
                                                             error:nil];
        return @{ @"reply": [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] };
    }
}


#pragma mark -

- (NSString *)procObjectForKey:(NSString *)key
{
    @autoreleasepool {
        NSAssert([key isKindOfClass:[NSString class]], @"invalid key");
        NSString *retObj = (NSString *)[self _procObjectForKey:key][@"reply"];
        NSAssert([retObj isKindOfClass:[NSString class]], @"invalid return value");
        return retObj;
    }
}

- (NSDictionary *)_procObjectForKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_procObjectForKey:)),
                @"arguments": [NSArray arrayWithObjects:key, nil],
            }];
            
            CHDebugLog(@"_procGetObjectForKeyForKey: %@ -> %@", key, replyObject);
            
            NSString *replyString = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyString isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSString *priorObject = nil;
        dispatch_sync(_eventQueue, ^{
            priorObject = [_dictionary objectForKey:key];
        });
        return @{ @"reply": priorObject ?: @"" };
    }
}

- (NSString *)procPutObject:(nullable NSString *)object forKey:(NSString *)key
{
    @autoreleasepool {
        NSAssert(object == nil || [object isKindOfClass:[NSString class]], @"invalid object");
        NSAssert([key isKindOfClass:[NSString class]], @"invalid key");
        NSString *retObj = (NSString *)[self _procPutObject:(object ?: @"") forKey:key][@"reply"];
        NSAssert([retObj isKindOfClass:[NSString class]], @"invalid return value");
        return retObj;
    }
}

- (NSDictionary *)_procPutObject:(nonnull NSString *)object forKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_procPutObject:forKey:)),
                @"arguments": [NSArray arrayWithObjects:object, key, nil],
            }];
            
            CHDebugLog(@"_procPutObject: %@ forKey: %@ -> %@", object, key, replyObject);
            
            NSString *replyString = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyString isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSString *priorObject = nil;
        if (!object.length) {
            dispatch_sync(_eventQueue, ^{
                priorObject = [_dictionary objectForKey:key];
                [_dictionary removeObjectForKey:key];
            });
        } else {
            dispatch_sync(_eventQueue, ^{
                priorObject = [_dictionary objectForKey:key];
                [_dictionary setObject:object forKey:key];
            });
        }
        return @{ @"reply": priorObject ?: @"" };
    }
}


#pragma mark -

- (NSUInteger)procQueuePushObject:(nonnull NSString *)object forKey:(NSString *)key
{
    @autoreleasepool {
        NSAssert([object isKindOfClass:[NSString class]] && object.length > 0, @"invalid object");
        NSAssert([key isKindOfClass:[NSString class]], @"invalid key");
        NSNumber *retObj = (NSNumber *)[self _procQueuePushObject:object forKey:key][@"reply"];
        NSAssert([retObj isKindOfClass:[NSNumber class]], @"invalid return value");
        return [retObj unsignedIntegerValue];
    }
}

- (NSDictionary *)_procQueuePushObject:(nonnull NSString *)object forKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_procQueuePushObject:forKey:)),
                @"arguments": [NSArray arrayWithObjects:object, key, nil],
            }];
            
            CHDebugLog(@"_procQueuePushObject: %@ forKey: %@ -> %@", object, key, replyObject);
            
            NSNumber *replySize = replyObject[@"reply"];
#if DEBUG
            NSAssert([replySize isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSUInteger afterSize = 0;
        dispatch_sync(_eventQueue, ^{
            NSMutableArray <NSString *> *queue = [_queueDictionary objectForKey:key];
            if (!queue) {
                queue = [[NSMutableArray alloc] initWithObjects:object, nil];
                [_queueDictionary setObject:queue forKey:key];
            } else {
                [queue addObject:object];
            }
            afterSize = queue.count;
        });
        return @{ @"reply": @(afterSize) };
    }
}

- (NSString *)procQueuePopObjectForKey:(nonnull NSString *)key
{
    @autoreleasepool {
        NSAssert([key isKindOfClass:[NSString class]], @"invalid key");
        NSString *retObj = (NSString *)[self _procQueuePopObjectForKey:key][@"reply"];
        NSAssert([retObj isKindOfClass:[NSString class]], @"invalid return value");
        return retObj;
    }
}

- (NSDictionary *)_procQueuePopObjectForKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_procQueuePopObjectForKey:)),
                @"arguments": [NSArray arrayWithObjects:key, nil],
            }];
            
            CHDebugLog(@"_procQueuePopObjectForKey: %@ -> %@", key, replyObject);
            
            NSString *replyString = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyString isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSString *popObject = nil;
        dispatch_sync(_eventQueue, ^{
            NSMutableArray <NSString *> *queue = [_queueDictionary objectForKey:key];
            popObject = [queue firstObject];
            if (popObject) {
                [queue removeObjectAtIndex:0];
            }
        });
        return @{ @"reply": popObject ?: @"" };
    }
}

- (NSArray <NSString *> *)procQueueClearObjectsForKey:(nonnull NSString *)key
{
    @autoreleasepool {
        NSAssert([key isKindOfClass:[NSString class]], @"invalid key");
        NSArray <NSString *> *retObj = (NSArray <NSString *> *)[self _procQueueClearObjectsForKey:key][@"reply"];
        NSAssert([retObj isKindOfClass:[NSArray class]], @"invalid return value");
        return retObj;
    }
}

- (NSDictionary *)_procQueueClearObjectsForKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_procQueueClearObjectsForKey:)),
                @"arguments": [NSArray arrayWithObjects:key, nil],
            }];
            
            CHDebugLog(@"_procQueueClearObjectsForKey: %@ -> %@", key, replyObject);
            
            NSArray *replyArray = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyArray isKindOfClass:[NSArray class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSArray <NSString *> *priorQueue = nil;
        dispatch_sync(_eventQueue, ^{
            NSMutableArray <NSString *> *queue = [_queueDictionary objectForKey:key];
            priorQueue = [queue copy];
            [queue removeAllObjects];
        });
        return @{ @"reply": priorQueue ?: [NSArray array] };
    }
}

- (NSUInteger)procQueueSizeForKey:(nonnull NSString *)key
{
    @autoreleasepool {
        NSAssert([key isKindOfClass:[NSString class]], @"invalid key");
        NSNumber *retObj = (NSNumber *)[self _procQueueSizeForKey:key][@"reply"];
        NSAssert([retObj isKindOfClass:[NSNumber class]], @"invalid return value");
        return [retObj unsignedIntegerValue];
    }
}

- (NSDictionary *)_procQueueSizeForKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_procQueueSizeForKey:)),
                @"arguments": [NSArray arrayWithObjects:key, nil],
            }];
            
            CHDebugLog(@"_procQueueSizeForKey: %@ -> %@", key, replyObject);
            
            NSNumber *replySize = replyObject[@"reply"];
#if DEBUG
            NSAssert([replySize isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSUInteger theSize = 0;
        dispatch_sync(_eventQueue, ^{
            NSMutableArray <NSString *> *queue = [_queueDictionary objectForKey:key];
            theSize = queue.count;
        });
        return @{ @"reply": @(theSize) };
    }
}

- (NSUInteger)procQueuePushFrontObject:(nonnull NSString *)object forKey:(NSString *)key
{
    @autoreleasepool {
        NSAssert([object isKindOfClass:[NSString class]] && object.length > 0, @"invalid object");
        NSAssert([key isKindOfClass:[NSString class]], @"invalid key");
        NSNumber *retObj = (NSNumber *)[self _procQueuePushFrontObject:object forKey:key][@"reply"];
        NSAssert([retObj isKindOfClass:[NSNumber class]], @"invalid return value");
        return [retObj unsignedIntegerValue];
    }
}

- (NSDictionary *)_procQueuePushFrontObject:(nonnull NSString *)object forKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_procQueuePushFrontObject:forKey:)),
                @"arguments": [NSArray arrayWithObjects:object, key, nil],
            }];
            
            CHDebugLog(@"_procQueuePushFrontObject: %@ forKey: %@ -> %@", object, key, replyObject);
            
            NSNumber *replySize = replyObject[@"reply"];
#if DEBUG
            NSAssert([replySize isKindOfClass:[NSNumber class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSUInteger afterSize = 0;
        dispatch_sync(_eventQueue, ^{
            NSMutableArray <NSString *> *queue = [_queueDictionary objectForKey:key];
            if (!queue) {
                queue = [[NSMutableArray alloc] initWithObjects:object, nil];
                [_queueDictionary setObject:queue forKey:key];
            } else {
                [queue insertObject:object atIndex:0];
            }
            afterSize = queue.count;
        });
        return @{ @"reply": @(afterSize) };
    }
}

- (NSString *)procQueuePopBackObjectForKey:(nonnull NSString *)key
{
    @autoreleasepool {
        NSAssert([key isKindOfClass:[NSString class]], @"invalid key");
        NSString *retObj = (NSString *)[self _procQueuePopBackObjectForKey:key][@"reply"];
        NSAssert([retObj isKindOfClass:[NSString class]], @"invalid return value");
        return retObj;
    }
}

- (NSDictionary *)_procQueuePopBackObjectForKey:(NSString *)key
{
    if (_role == ProcQueueRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_procQueuePopBackObjectForKey:)),
                @"arguments": [NSArray arrayWithObjects:key, nil],
            }];
            
            CHDebugLog(@"_procQueuePopBackObjectForKey: %@ -> %@", key, replyObject);
            
            NSString *replyString = replyObject[@"reply"];
#if DEBUG
            NSAssert([replyString isKindOfClass:[NSString class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        __block NSString *popObject = nil;
        dispatch_sync(_eventQueue, ^{
            NSMutableArray <NSString *> *queue = [_queueDictionary objectForKey:key];
            popObject = [queue lastObject];
            if (popObject) {
                [queue removeLastObject];
            }
        });
        return @{ @"reply": popObject ?: @"" };
    }
}

@end


#pragma mark -

CHConstructor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] arguments][0];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        BOOL forceClient = [[[NSProcessInfo processInfo] environment][@"CLIENT"] boolValue];
        
        if (!forceClient && ([processName isEqualToString:@"procqueued"] || [processName hasSuffix:@"/procqueued"]))
        {   /* Server Process - procqueued */
            
            rocketbootstrap_unlock(XPC_INSTANCE_NAME);
            
            CPDistributedMessagingCenter *serverMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(serverMessagingCenter);
            [serverMessagingCenter runServerOnCurrentThread];
            
            ProcQueue *serverInstance = [ProcQueue sharedInstanceWithRole:ProcQueueRoleServer];
            [serverMessagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
            [serverMessagingCenter registerForMessageName:@XPC_TWOWAY_MSG_NAME target:serverInstance selector:@selector(receiveAndReplyMessageName:userInfo:)];
            [serverInstance setMessagingCenter:serverMessagingCenter];
            [serverInstance synchronize];
            
            [serverInstance registerDefaultEntries:@{
                @"ch.xxtou.defaults.selected-script": @"main.lua",
                @"ch.xxtou.defaults.recording": @{
                    @"record_volume_up": @(NO),
                    @"record_volume_down": @(NO),
                },
                @"ch.xxtou.defaults.action": @{
                    @"hold_volume_up": @"0",
                    @"hold_volume_down": @"0",
                    @"click_volume_up": @"0",
                    @"click_volume_down": @"0",
                    @"activator_installed": @(NO),
                },
                @"ch.xxtou.defaults.startup": @{
                    @"startup_run": @(NO),
                    @"startup_script": @"bootstrap.lua",
                },
                @"ch.xxtou.defaults.user": @{
                    @"device_control_toggle": @(YES),
                    @"no_nosim_alert": @(YES),
                    @"no_low_power_alert": @(YES),
                    @"no_idle": @(NO),
                    @"script_on_daemon": @(NO),
                    @"script_end_hint": @(YES),
                    @"use_classic_control_alert": @(YES),
                    @"no_nosim_statusbar": @(NO),
                },
                @"ch.xxtou.defaults.env": @{
                    @"XXT_ENTRYPOINT": @"",
                    @"XXT_ENTRYTYPE": @"unknown",
                    
                    // unknown
                    // * openapi        Unrecognized User-Agent
                    // * application    X.X.T.
                    // * scheduler      os.restart
                    // * terminal       Terminal
                    // * volume         Volume Button
                    // * startup        Boot Script
                    // * touchsprite    Legacy IDE
                    // * daemon         Daemon Mode
                },
            }];
            
            CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", serverMessagingCenter, bundleIdentifier, processName, getpid());
            
            // Notify client that server has launched
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                notify_post(kProcQueueLaunchedDistributedNotificationName);
            });
        }
        else
        {   /* Client Process */
            
            CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
            
            ProcQueue *clientInstance = [ProcQueue sharedInstanceWithRole:ProcQueueRoleClient];
            [clientInstance setMessagingCenter:clientMessagingCenter];
            
            int launchedToken;
            notify_register_dispatch(kProcQueueLaunchedDistributedNotificationName, &launchedToken, dispatch_get_main_queue(), ^(int token) {
                if ([clientInstance respondsToSelector:@selector(remoteDefaultsChanged)]) {
                    [clientInstance remoteDefaultsChanged];
                }
            });
            
            int defaultsToken;
            notify_register_dispatch(kProcQueueDefaultsChangedDistributedNotificationName, &defaultsToken, dispatch_get_main_queue(), ^(int token) {
                if ([clientInstance respondsToSelector:@selector(remoteDefaultsChanged)]) {
                    [clientInstance remoteDefaultsChanged];
                }
            });
            
            CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
        }
    }
}
