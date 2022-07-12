#ifndef EntitleMe_h
#define EntitleMe_h

#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

NS_ASSUME_NONNULL_BEGIN

#define EntitleMeErrorDomain   "ch.xxtou.error.entitleme"

typedef NS_ENUM(NSUInteger, EntitleMeRole) {
    EntitleMeRoleClient = 0,
    EntitleMeRoleServer,
};

@interface EntitleMe : NSObject

@property (nonatomic, strong, readonly) CPDistributedMessagingCenter *messagingCenter;
@property (nonatomic, assign, readonly) EntitleMeRole role;

+ (instancetype)sharedInstance;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (NSDictionary *)querySignInSessionContext;
- (NSDictionary *)queryAuthKitDaemonStatus;
- (void)setupSignInSessionWithUsername:(NSString *)username Password:(NSString *)password;
- (void)tearDownSignInSession;

- (NSDictionary *)currentStoreAccount;
- (void)logoutCurrentStoreAccount;

@end

NS_ASSUME_NONNULL_END

#endif /* EntitleMe_h */
