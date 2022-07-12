#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "EntitleMe.h"
#import <rocketbootstrap/rocketbootstrap.h>


@interface AAUISignInViewController : UIViewController
@end

@class AAUISignInController;

@protocol AAUISignInControllerDelegate <UINavigationControllerDelegate>
@optional
- (void)signInControllerDidCancel:(AAUISignInController *)arg1;
- (void)signInController:(AAUISignInController *)arg1 didCompleteWithSuccess:(_Bool)arg2 error:(NSError *)arg3;
@end

@interface AAUISignInController : UINavigationController
@property (nonatomic, weak) id <AAUISignInControllerDelegate> delegate;
- (AAUISignInViewController *)_signInViewController;
- (void)setServiceType:(NSString *)arg1;
- (NSString *)serviceType;
- (void)setUsername:(NSString *)arg1;
- (NSString *)username;
- (void)setCanEditUsername:(BOOL)arg1;
- (BOOL)canEditUsername;
@end

@interface SSAccount : NSObject
@property (nonatomic, copy) NSString *accountName;
@property (nonatomic, assign, getter=isActive) BOOL active;
@end

@interface SSAccountStore : NSObject
+ (instancetype)defaultStore;
- (void)signOutAllAccounts;
@property (nonatomic, strong, readonly) SSAccount *activeAccount;
@end

@interface EntitleMe (Internal) <AAUISignInControllerDelegate>

@property (nonatomic, strong) CPDistributedMessagingCenter *messagingCenter;

+ (instancetype)sharedInstanceWithRole:(EntitleMeRole)role;
- (instancetype)initWithRole:(EntitleMeRole)role;

- (void)akdReportStoreSignInSucceed;
- (void)akdReportStoreSignInVerificationRequired;
- (void)akdReportStoreSignInFailedWithError:(NSError *)error;
- (void)akdReportStoreSignInDidBegin;

- (void)settingsReportError:(NSError *)error;

@end

@implementation EntitleMe {
    EntitleMeRole _role;
    dispatch_queue_t _eventQueue;
    
    BOOL _akdIsPerforming;
    BOOL _akdLastSignInSucceed;
    NSError *_akdLastSignInError;
    
    NSString *_prefsUsername;
    NSString *_prefsPassword;
}

@synthesize messagingCenter = _messagingCenter;

+ (instancetype)sharedInstance {
    return [self sharedInstanceWithRole:EntitleMeRoleClient];
}

+ (instancetype)sharedInstanceWithRole:(EntitleMeRole)role {
    static EntitleMe *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[EntitleMe alloc] initWithRole:role];
    });
    return _server;
}

- (instancetype)initWithRole:(EntitleMeRole)role {
    self = [super init];
    if (self) {
        _role = role;
        _eventQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.EventQueue", @XPC_INSTANCE_NAME] UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (EntitleMeRole)role {
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
    NSAssert(_role == EntitleMeRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    NSAssert(sendSucceed, @"cannot send message %@, userInfo = %@", messageName, userInfo);
}

- (void)unsafeSendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == EntitleMeRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    if (!sendSucceed) {
        CHLog(@"cannot send message %@, userInfo = %@", messageName, userInfo);
    }
}

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == EntitleMeRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    NSAssert(sendErr == nil, @"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    return replyInfo;
}

- (NSDictionary *)unsafeSendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == EntitleMeRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    if (!replyInfo) {
        CHLog(@"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    }
    return replyInfo;
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == EntitleMeRoleServer, @"invalid role");
    
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
    NSAssert(_role == EntitleMeRoleServer, @"invalid role to receive message");
    
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

- (void)akdReportStoreSignInDidBegin
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            [self unsafeSendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(akdReportStoreSignInDidBegin)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        self->_akdIsPerforming = YES;
        self->_akdLastSignInSucceed = NO;
        self->_akdLastSignInError = nil;
    }
}

- (void)akdReportStoreSignInVerificationRequired
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            [self unsafeSendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(akdReportStoreSignInVerificationRequired)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        self->_akdIsPerforming = NO;
        self->_akdLastSignInSucceed = NO;
        self->_akdLastSignInError = [NSError errorWithDomain:@EntitleMeErrorDomain
                                                        code:101
                                                    userInfo:@{ NSLocalizedDescriptionKey: @"Verification required.",
                                                                NSLocalizedFailureReasonErrorKey: @"Two-step verification enabled.", }];
    }
}

- (void)akdReportStoreSignInSucceed
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            [self unsafeSendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(akdReportStoreSignInSucceed)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        self->_akdIsPerforming = NO;
        self->_akdLastSignInSucceed = YES;
        self->_akdLastSignInError = nil;
    }
}

- (void)settingsReportError:(NSError *)error
{
    [self akdReportStoreSignInFailedWithError:error];
}

- (void)akdReportStoreSignInFailedWithError:(NSError *)error
{
    [self _akdReportStoreSignInFailedWithError:@{
        @"code": @(error.code),
        @"domain": error.domain,
        @"desc": [NSString stringWithFormat:@"%@", error.localizedDescription],
        @"reason": [NSString stringWithFormat:@"%@", error.localizedFailureReason],
    }];
}

- (void)_akdReportStoreSignInFailedWithError:(NSDictionary *)error
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            [self unsafeSendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_akdReportStoreSignInFailedWithError:)),
                @"arguments": [NSArray arrayWithObjects:error, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        self->_akdIsPerforming = NO;
        self->_akdLastSignInSucceed = NO;
        self->_akdLastSignInError = [NSError errorWithDomain:error[@"domain"]
                                                        code:[error[@"code"] integerValue]
                                                    userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@", error[@"desc"]],
                                                                NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"%@", error[@"reason"]],
                                                             }];
    }
}

- (NSDictionary *)queryAuthKitDaemonStatus
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(queryAuthKitDaemonStatus)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLogSource(@"queryAuthKitDaemonStatus -> %@", replyObject);
            
#if DEBUG
            NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        return @{
            @"processing": @(self->_akdIsPerforming),
            @"succeed": @(self->_akdLastSignInSucceed),
            @"code": @(self->_akdLastSignInError.code),
            @"domain": [NSString stringWithFormat:@"%@", self->_akdLastSignInError.domain],
            @"desc": [NSString stringWithFormat:@"%@", self->_akdLastSignInError.localizedDescription],
            @"reason": [NSString stringWithFormat:@"%@", self->_akdLastSignInError.localizedFailureReason],
        };
    }
}

- (void)setupSignInSessionWithUsername:(NSString *)username Password:(NSString *)password
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(setupSignInSessionWithUsername:Password:)),
                @"arguments": [NSArray arrayWithObjects:username, password, nil],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        self->_prefsUsername = username;
        self->_prefsPassword = password;
        
        self->_akdIsPerforming = YES;
        self->_akdLastSignInSucceed = NO;
        self->_akdLastSignInError = nil;
    }
}

- (void)tearDownSignInSession
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(tearDownSignInSession)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        self->_prefsUsername = nil;
        self->_prefsPassword = nil;
    }
}

- (NSDictionary *)querySignInSessionContext
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(querySignInSessionContext)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLogSource(@"querySignInSessionContext -> %@", replyObject);
            
#if DEBUG
            NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        return @{
            @"daemon": @{
                @"processing": @(self->_akdIsPerforming),
                @"succeed": @(self->_akdLastSignInSucceed),
                @"code": @(self->_akdLastSignInError.code),
                @"domain": [NSString stringWithFormat:@"%@", self->_akdLastSignInError.domain],
                @"desc": [NSString stringWithFormat:@"%@", self->_akdLastSignInError.localizedDescription],
                @"reason": [NSString stringWithFormat:@"%@", self->_akdLastSignInError.localizedFailureReason],
            },
            @"username": [NSString stringWithFormat:@"%@", self->_prefsUsername],
            @"password": [NSString stringWithFormat:@"%@", self->_prefsPassword],
        };
    }
}

- (void)signInControllerDidCancel:(AAUISignInController *)arg1
{
    [arg1 dismissViewControllerAnimated:YES
                             completion:^{
        [self akdReportStoreSignInFailedWithError:[NSError errorWithDomain:@EntitleMeErrorDomain
                                                                      code:102 userInfo:@{ NSLocalizedDescriptionKey: @"Operation cancelled.",
                                                                                           NSLocalizedFailureReasonErrorKey: @"User cancalled current sign in session manually.",
                                                                                        }]];
    }];
}

- (void)signInController:(AAUISignInController *)arg1 didCompleteWithSuccess:(BOOL)arg2 error:(NSError *)arg3
{
    [arg1 dismissViewControllerAnimated:YES
                             completion:^{
        if (arg2)
        {
            [self akdReportStoreSignInSucceed];
        }
        else
        {
            [self akdReportStoreSignInFailedWithError:arg3];
        }
    }];
}

+ (void)loadStoreServicesFramework
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/StoreServices.framework"] load];
    });
}

- (NSDictionary *)currentStoreAccount
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(currentStoreAccount)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLogSource(@"currentStoreAccount -> %@", replyObject);
            
#if DEBUG
            NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
#endif
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        [EntitleMe loadStoreServicesFramework];
        
        SSAccount *activeAccount = [[objc_getClass("SSAccountStore") defaultStore] activeAccount];
        return @{
            @"name": [NSString stringWithFormat:@"%@", activeAccount.accountName],
            @"active": @(activeAccount.isActive),
        };
    }
}

- (void)logoutCurrentStoreAccount
{
    if (_role == EntitleMeRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(logoutCurrentStoreAccount)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        [EntitleMe loadStoreServicesFramework];
        [[objc_getClass("SSAccountStore") defaultStore] signOutAllAccounts];
    }
}

@end


#pragma mark -

#import "pac_helper.h"

typedef CFStringRef (sec_task_copy_id_t)(void *task, CFErrorRef _Nullable *error);
static sec_task_copy_id_t *_SecTaskCopySigningIdentifier = NULL;

static CFTypeRef (*original_SecTaskCopyValueForEntitlement)(void *task, CFStringRef entitlement, CFErrorRef _Nullable *error);
static CFTypeRef replaced_SecTaskCopyValueForEntitlement(void *task, CFStringRef entitlement, CFErrorRef _Nullable *error)
{
    NSArray <NSString *> *expectedNames = @[
        @"get-task-allow",
        @"com.apple.security.get-task-allow",
        @"com.apple.webinspector.allow",
        @"com.apple.private.webinspector.allow-remote-inspection",
        @"com.apple.private.webinspector.allow-carrier-remote-inspection",
        @"com.apple.authkit.client.private",
        @"com.apple.authkit.client.internal",
        @"com.apple.authkit.writer.internal",
    ];
    NSString *castedEntitlementName = (__bridge NSString *)entitlement;
    if (_SecTaskCopySigningIdentifier) {
        NSString *identifier = (__bridge NSString *)_SecTaskCopySigningIdentifier(task, NULL);
        CHDebugLogSource(@"check entitlement: %@ for %@", castedEntitlementName, identifier);
    }
    if ([expectedNames containsObject:castedEntitlementName]) {
        return kCFBooleanTrue;
    }
    return original_SecTaskCopyValueForEntitlement(task, entitlement, error);
}


#pragma mark - AuthKit Daemon

static void (*original_AKAppleIDAuthenticationService__beginServerDrivenSecondaryActionWithURLKey_context_initialAuthResponse_completion_)(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4);
static void replaced_AKAppleIDAuthenticationService__beginServerDrivenSecondaryActionWithURLKey_context_initialAuthResponse_completion_(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4)
{
    CHDebugLogSource(@"");
    original_AKAppleIDAuthenticationService__beginServerDrivenSecondaryActionWithURLKey_context_initialAuthResponse_completion_(self, _cmd, arg1, arg2, arg3, arg4);
    [[EntitleMe sharedInstance] akdReportStoreSignInVerificationRequired];
}

static void (*original_AKAppleIDAuthenticationService__showAlertForLoginError_context_completion_)(id self, SEL _cmd, NSError *error, id arg2, id arg3);
static void replaced_AKAppleIDAuthenticationService__showAlertForLoginError_context_completion_(id self, SEL _cmd, NSError *error, id arg2, id arg3)
{
    CHDebugLogSource(@"%@", error);
    original_AKAppleIDAuthenticationService__showAlertForLoginError_context_completion_(self, _cmd, error, arg2, arg3);
    [[EntitleMe sharedInstance] akdReportStoreSignInFailedWithError:error];
}

static void (*original_AKAppleIDAuthenticationService__handleBasicLoginUICompletionWithUsername_password_context_additionalData_collectionError_completion_)(id self, SEL _cmd, NSString *username, NSString *password, id arg3, id arg4, id arg5, id arg6);
static void replaced_AKAppleIDAuthenticationService__handleBasicLoginUICompletionWithUsername_password_context_additionalData_collectionError_completion_(id self, SEL _cmd, NSString *username, NSString *password, id arg3, id arg4, id arg5, id arg6)
{
    CHDebugLogSource(@"username = %@, password = %@", username, password);
    original_AKAppleIDAuthenticationService__handleBasicLoginUICompletionWithUsername_password_context_additionalData_collectionError_completion_(self, _cmd, username, password, arg3, arg4, arg5, arg6);
    [[EntitleMe sharedInstance] akdReportStoreSignInDidBegin];
}

static void (*original_AKAppleIDAuthenticationService__handleSuccessfulVerificationForAccount_withResults_serverResponse_context_completion_)(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4, id arg5);
static void replaced_AKAppleIDAuthenticationService__handleSuccessfulVerificationForAccount_withResults_serverResponse_context_completion_(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4, id arg5)
{
    CHDebugLogSource(@"account = %@", arg1);
    original_AKAppleIDAuthenticationService__handleSuccessfulVerificationForAccount_withResults_serverResponse_context_completion_(self, _cmd, arg1, arg2, arg3, arg4, arg5);
    [[EntitleMe sharedInstance] akdReportStoreSignInSucceed];
}

static void (*original_AKAppleIDAuthenticationService__handleSuccessfulVerificationForContext_withResults_serverResponse_completion_)(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4);
static void replaced_AKAppleIDAuthenticationService__handleSuccessfulVerificationForContext_withResults_serverResponse_completion_(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4)
{
    CHDebugLogSource(@"");
    original_AKAppleIDAuthenticationService__handleSuccessfulVerificationForContext_withResults_serverResponse_completion_(self, _cmd, arg1, arg2, arg3, arg4);
    [[EntitleMe sharedInstance] akdReportStoreSignInSucceed];
}


#pragma mark - Preferences

CHDeclareClass(PreferencesAppController);

CHOptimizedMethod(2, self, void, PreferencesAppController, application, UIApplication *, application, didFinishLaunchingWithOptions, NSDictionary *, launchOptions)
{
    @autoreleasepool {
        CHSuper(2, PreferencesAppController, application, application, didFinishLaunchingWithOptions, launchOptions);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSDictionary *context = [[EntitleMe sharedInstance] querySignInSessionContext];
            
            NSString *sessionUsername = context[@"username"];
            if (!sessionUsername.length || [sessionUsername isEqualToString:@"(null)"])
            {
                return;
            }
            
            NSString *sessionPassword = context[@"password"];
            if (!sessionPassword.length || [sessionUsername isEqualToString:@"(null)"])
            {
                return;
            }
            
            UIWindow *foundKeyWindow = nil;
            NSArray <UIWindow *> *windows = [application windows];
            for (UIWindow *window in windows) {
                if (window.isKeyWindow) {
                    foundKeyWindow = window;
                    break;
                }
            }
            
            if (!foundKeyWindow && windows.count == 1)
            {
                foundKeyWindow = [windows firstObject];
            }
            
            if (!foundKeyWindow)
            {
                [[EntitleMe sharedInstance] settingsReportError:[NSError errorWithDomain:@EntitleMeErrorDomain
                                                                                    code:500
                                                                                userInfo:@{ NSLocalizedDescriptionKey: @"Internal server error.",
                                                                                            NSLocalizedFailureReasonErrorKey: @"Target process is in a bad state.", }]];
                return;
            }
            
            UIViewController *rootCtrl = [foundKeyWindow rootViewController];
            
            if (rootCtrl.presentedViewController)
            {
                [[EntitleMe sharedInstance] settingsReportError:[NSError errorWithDomain:@EntitleMeErrorDomain
                                                                                    code:503
                                                                                userInfo:@{ NSLocalizedDescriptionKey: @"Service unavailable.",
                                                                                            NSLocalizedFailureReasonErrorKey: @"Target process is presenting another modal sheet.", }]];
                return;
            }
            
            [[EntitleMe sharedInstance] tearDownSignInSession];
            
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/AppleAccountUI.framework"] load];
            });
            
            AAUISignInController *signInCtrl = [[objc_getClass("AAUISignInController") alloc] init];
            [signInCtrl setUsername:sessionUsername];
            [signInCtrl setCanEditUsername:NO];
            [signInCtrl setServiceType:@"com.apple.AppleID.Service.Store"];
            [signInCtrl setDelegate:[EntitleMe sharedInstance]];
            
            [rootCtrl presentViewController:signInCtrl animated:YES completion:nil];
        });
    }
}


#pragma mark -

CHConstructor {
    @autoreleasepool {
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSString *processName = [[NSProcessInfo processInfo] processName];
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"])
        {   /* Server Process - SpringBoard */
            
            rocketbootstrap_unlock(XPC_INSTANCE_NAME);
            
            CPDistributedMessagingCenter *serverMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(serverMessagingCenter);
            [serverMessagingCenter runServerOnCurrentThread];
            
            EntitleMe *serverInstance = [EntitleMe sharedInstanceWithRole:EntitleMeRoleServer];
            [serverMessagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
            [serverMessagingCenter registerForMessageName:@XPC_TWOWAY_MSG_NAME target:serverInstance selector:@selector(receiveAndReplyMessageName:userInfo:)];
            [serverInstance setMessagingCenter:serverMessagingCenter];
            
            CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", serverMessagingCenter, bundleIdentifier, processName, getpid());
        }
        else if ([bundleIdentifier isEqualToString:@"com.apple.Preferences"])
        {   /* Client Process #1 - Settings */
            
            CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
            
            EntitleMe *clientInstance = [EntitleMe sharedInstanceWithRole:EntitleMeRoleClient];
            [clientInstance setMessagingCenter:clientMessagingCenter];
            
            CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
            
            CHLoadLateClass(PreferencesAppController);
            CHHook(2, PreferencesAppController, application, didFinishLaunchingWithOptions);
        }
        else if ([processName isEqualToString:@"akd"] || [processName isEqualToString:@"webinspectord"])
        {
            MSImageRef _SecurityLibrary = MSGetImageByName("/System/Library/Frameworks/Security.framework/Security");
            if (_SecurityLibrary)
            {
                _SecTaskCopySigningIdentifier = (sec_task_copy_id_t *)make_sym_callable(MSFindSymbol(_SecurityLibrary, "_SecTaskCopySigningIdentifier"));
                MSHookFunction(
                    make_sym_callable(MSFindSymbol(_SecurityLibrary, "_SecTaskCopyValueForEntitlement")),
                    (void *)replaced_SecTaskCopyValueForEntitlement,
                    (void **)&original_SecTaskCopyValueForEntitlement
                );
                
                CHDebugLogSource(@"%@ got entitled", processName);
            }
            
            if ([processName isEqualToString:@"akd"])
            {   /* Client Process #2 - akd */
                
                CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
                rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
                
                EntitleMe *clientInstance = [EntitleMe sharedInstanceWithRole:EntitleMeRoleClient];
                [clientInstance setMessagingCenter:clientMessagingCenter];
                
                CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
            }

            Class akdServiceCls = objc_getClass("AKAppleIDAuthenticationService");
            if (akdServiceCls)
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                MSHookMessageEx
                (
                    akdServiceCls,
                    @selector(_handleSuccessfulVerificationForAccount:withResults:serverResponse:context:completion:),
                    (IMP)replaced_AKAppleIDAuthenticationService__handleSuccessfulVerificationForAccount_withResults_serverResponse_context_completion_,
                    (IMP *)&original_AKAppleIDAuthenticationService__handleSuccessfulVerificationForAccount_withResults_serverResponse_context_completion_
                );
                MSHookMessageEx
                (
                    akdServiceCls,
                    @selector(_handleSuccessfulVerificationForContext:withResults:serverResponse:completion:),
                    (IMP)replaced_AKAppleIDAuthenticationService__handleSuccessfulVerificationForContext_withResults_serverResponse_completion_,
                    (IMP *)&original_AKAppleIDAuthenticationService__handleSuccessfulVerificationForContext_withResults_serverResponse_completion_
                );
                MSHookMessageEx
                (
                    akdServiceCls,
                    @selector(_handleBasicLoginUICompletionWithUsername:password:context:additionalData:collectionError:completion:),
                    (IMP)replaced_AKAppleIDAuthenticationService__handleBasicLoginUICompletionWithUsername_password_context_additionalData_collectionError_completion_,
                    (IMP *)&original_AKAppleIDAuthenticationService__handleBasicLoginUICompletionWithUsername_password_context_additionalData_collectionError_completion_
                );
                MSHookMessageEx
                (
                    akdServiceCls,
                    @selector(_showAlertForLoginError:context:completion:),
                    (IMP)replaced_AKAppleIDAuthenticationService__showAlertForLoginError_context_completion_,
                    (IMP *)&original_AKAppleIDAuthenticationService__showAlertForLoginError_context_completion_
                );
                MSHookMessageEx
                (
                    akdServiceCls,
                    @selector(_beginServerDrivenSecondaryActionWithURLKey:context:initialAuthResponse:completion:),
                    (IMP)replaced_AKAppleIDAuthenticationService__beginServerDrivenSecondaryActionWithURLKey_context_initialAuthResponse_completion_,
                    (IMP *)&original_AKAppleIDAuthenticationService__beginServerDrivenSecondaryActionWithURLKey_context_initialAuthResponse_completion_
                );
#pragma clang diagnostic pop
            }
        }
        else
        {   /* Client Process #3 - entitleme.so */
            
            CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
            
            EntitleMe *clientInstance = [EntitleMe sharedInstanceWithRole:EntitleMeRoleClient];
            [clientInstance setMessagingCenter:clientMessagingCenter];
            
            CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
        }
	}
}
