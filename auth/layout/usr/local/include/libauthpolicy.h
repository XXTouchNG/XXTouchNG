#ifndef AuthPolicy_h
#define AuthPolicy_h

#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

NS_ASSUME_NONNULL_BEGIN

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

- (void)verifyCodeSignatureAndExitIfNotQualifiedForCodeInjection;
- (NSDictionary *)copyCodeSignStatus;
- (NSDictionary *)copyCodeSignature;
- (NSDictionary *)copyEntitlements;

@end

NS_ASSUME_NONNULL_END

#endif  /* AuthPolicy_h */
