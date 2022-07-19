#ifndef AuthPolicy_h
#define AuthPolicy_h

#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

NS_ASSUME_NONNULL_BEGIN

#define AuthPolicyErrorDomain   "ch.xxtou.error.authpolicy"

typedef NS_ENUM(NSUInteger, AuthPolicyRole) {
    AuthPolicyRoleClient = 0,
    AuthPolicyRoleServer,
};

@protocol AuthPolicyNotificationHandler <NSObject>
@optional
- (void)remoteDefaultsChanged;
@end

@interface AuthPolicy : NSObject <AuthPolicyNotificationHandler>

@property (nonatomic, strong, readonly) CPDistributedMessagingCenter *messagingCenter;
@property (nonatomic, assign, readonly) AuthPolicyRole role;

+ (instancetype)sharedInstance;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (NSDictionary *)copyCodeSignStatusWithError:(NSError *__autoreleasing  _Nullable * _Nullable)error;
- (NSDictionary *)copyCodeSignStatusWithProcessIdentifier:(pid_t)processIdentifier error:(NSError *__autoreleasing  _Nullable * _Nullable)error;

- (NSDictionary *)copyCodeSignatureWithError:(NSError *__autoreleasing  _Nullable * _Nullable)error;
- (NSDictionary *)copyCodeSignatureWithProcessPath:(NSString *)processPath error:(NSError *__autoreleasing  _Nullable * _Nullable)error;
- (NSDictionary *)copyCodeSignatureWithProcessIdentifier:(pid_t)processIdentifier error:(NSError *__autoreleasing  _Nullable * _Nullable)error;

- (NSDictionary *)copyEntitlementsWithError:(NSError *__autoreleasing  _Nullable * _Nullable)error;
- (NSDictionary *)copyEntitlementsWithProcessIdentifier:(pid_t)processIdentifier error:(NSError *__autoreleasing  _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif  /* AuthPolicy_h */
