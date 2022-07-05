//
//  TFLuaBridge+IMP.h
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    TFLuaBridgeRoleClient = 0,  // Client #1
    TFLuaBridgeRoleMiddleMan,   // Server
    TFLuaBridgeRoleServer,      // Client #2
} TFLuaBridgeRole;

@interface TFLuaBridge : NSObject

@property (nonatomic, assign) TFLuaBridgeRole instanceRole;
@property (nonatomic, copy, readonly) NSString *instanceRoleName;
@property (nonatomic, strong, nullable) NSMutableDictionary *cachedDefaults;

+ (instancetype)sharedInstance;
+ (void)setSharedInstanceName:(NSString *)instanceName;
+ (void)setSharedNotificationSuspensionBehavior:(CFNotificationSuspensionBehavior)behavior;

+ (NSArray <NSString *> *)allowedAppleProductBundleIDs;
+ (NSArray <NSString *> *)allowedAppleProductForegroundBundleIDs;
+ (NSArray <NSString *> *)allowedAppleProductBackgroundBundleIDs;

- (CPDistributedMessagingCenter *)messagingCenter;
- (NSString *)sessionID;

#ifdef TF_MIDDLE_MAN
- (nullable id)localClientDoAction:(NSString *)actionName userInfo:(NSDictionary *)userInfo error:(NSError *__autoreleasing*)error;
- (nullable id)localClientDoAction:(NSString *)actionName userInfo:(NSDictionary *)userInfo timeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing*)error;
#endif

@end

NS_ASSUME_NONNULL_END
