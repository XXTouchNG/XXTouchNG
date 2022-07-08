//
//  ProcQueue.h
//  ProcQueue
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#ifndef ProcQueue_h
#define ProcQueue_h

#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ProcQueueRole) {
    ProcQueueRoleClient = 0,
    ProcQueueRoleServer,
};

@protocol ProcQueueNotificationHandler <NSObject>
@optional
- (void)remoteDefaultsChanged;
@end

@interface ProcQueue : NSObject <ProcQueueNotificationHandler>

@property (nonatomic, strong, readonly) CPDistributedMessagingCenter *messagingCenter;
@property (nonatomic, assign, readonly) ProcQueueRole role;

+ (instancetype)sharedInstance;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (NSString *)dictionaryDescription;
- (NSString *)queueDictionaryDescription;

/* Defaults Dictionary */
- (NSDictionary *)defaultsDictionary;
- (nullable NSDictionary *)unsafeDefaultsDictionary;
- (nullable id)objectForKey:(NSString *)key;
- (void)registerDefaultEntries:(NSDictionary *)dictionary;
- (void)addEntriesFromDictionary:(NSDictionary *)dictionary;
- (void)setObject:(id)object forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (void)removeAllObjects;
- (void)synchronize;

/* Proc Dictionary */
- (NSString *)procObjectForKey:(nonnull NSString *)key;
- (NSString *)procPutObject:(nullable NSString *)object forKey:(nonnull NSString *)key;

/* Proc Queue Dictionary */
- (NSUInteger)procQueuePushTailObject:(nonnull NSString *)object forKey:(nonnull NSString *)key;
- (NSUInteger)procQueueUnshiftObject:(nonnull NSString *)object forKey:(NSString *)key;
- (NSString *)procQueuePopTailObjectForKey:(nonnull NSString *)key;
- (NSString *)procQueueShiftObjectForKey:(nonnull NSString *)key;
- (NSArray <NSString *> *)procQueueClearObjectsForKey:(nonnull NSString *)key;
- (NSUInteger)procQueueSizeForKey:(nonnull NSString *)key;

@end

NS_ASSUME_NONNULL_END

#endif  /* ProcQueue_h */
