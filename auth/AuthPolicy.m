#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "AuthPolicy.h"
#import "pac_helper.h"
#import "SecCode.h"
#import "SecTask.h"
#import "CSCommon.h"
#import "cs_blobs.h"
#import <rocketbootstrap/rocketbootstrap.h>
#import <Security/Security.h>

typedef struct __CFRuntimeBase {
    uintptr_t _cfisa;
    uint8_t _cfinfo[4];
#if __LP64__
    uint32_t _rc;
#endif
} CFRuntimeBase;

struct __SecTask {
    CFRuntimeBase base;
    
    audit_token_t token;
    
    /* Track whether we've loaded entitlements independently since after the
     * load, entitlements may legitimately be NULL */
    Boolean entitlementsLoaded;
    CFDictionaryRef entitlements;
    
    /* for debugging only, shown by debugDescription */
    int lastFailure;
};

NS_INLINE
int audit_token_for_pid(pid_t pid, audit_token_t *tokenp)
{
    kern_return_t kr = KERN_FAILURE;
    mach_msg_type_number_t autoken_cnt = TASK_AUDIT_TOKEN_COUNT;
    mach_port_t task;
    
    kr = task_for_pid(mach_task_self(), pid, &task);
    if (kr != KERN_SUCCESS)
    {
        return kr;
    }
    
    kr = task_info(task, TASK_AUDIT_TOKEN, (task_info_t)tokenp, &autoken_cnt);
    mach_port_deallocate(mach_task_self(), task);
    
    if (kr != KERN_SUCCESS)
    {
        return kr;
    }
    
    return KERN_SUCCESS;
}

/* Not available on iOS */
static OSStatus (*SecCodeCopyGuestWithAttributes)(SecCodeRef __nullable host, CFDictionaryRef __nullable attributes, SecCSFlags flags, SecCodeRef * __nonnull CF_RETURNS_RETAINED guest) = NULL;


#pragma mark -

@interface AuthPolicy (Internal)

@property (nonatomic, strong) CPDistributedMessagingCenter *messagingCenter;

+ (instancetype)sharedInstanceWithRole:(AuthPolicyRole)role;
- (instancetype)initWithRole:(AuthPolicyRole)role;

@end


#pragma mark -

@implementation AuthPolicy {
    AuthPolicyRole _role;
    dispatch_queue_t _eventQueue;
}

@synthesize messagingCenter = _messagingCenter;

+ (instancetype)sharedInstance {
    return [self sharedInstanceWithRole:AuthPolicyRoleClient];
}

+ (instancetype)sharedInstanceWithRole:(AuthPolicyRole)role {
    static AuthPolicy *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[AuthPolicy alloc] initWithRole:role];
    });
    return _server;
}

- (instancetype)initWithRole:(AuthPolicyRole)role {
    self = [super init];
    if (self) {
        _role = role;
        _eventQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.queue.events", @XPC_INSTANCE_NAME] UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (AuthPolicyRole)role {
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
    NSAssert(_role == AuthPolicyRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    NSAssert(sendSucceed, @"cannot send message %@, userInfo = %@", messageName, userInfo);
}

- (void)unsafeSendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == AuthPolicyRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    if (!sendSucceed) {
        CHLog(@"cannot send message %@, userInfo = %@", messageName, userInfo);
    }
}

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == AuthPolicyRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    NSAssert(sendErr == nil, @"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    return replyInfo;
}

- (NSDictionary *)unsafeSendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == AuthPolicyRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    if (!replyInfo) {
        CHLog(@"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    }
    return replyInfo;
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == AuthPolicyRoleServer, @"invalid role");
    
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
    NSAssert(_role == AuthPolicyRoleServer, @"invalid role to receive message");
    
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

- (void)verifyCodeSignatureAndExitIfNotQualified
{
//    NSDictionary *replyObject = [self _copyCodeSignature:@(getpid())];
    
}

- (NSDictionary *)copyCodeSignature
{
    return [self _copyCodeSignature:@(getpid())];
}

- (NSDictionary *)_copyCodeSignature:(NSNumber /* pid_t */ *)processIdentifier
{
    if (_role == AuthPolicyRoleClient)
    {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(_copyCodeSignature:)),
            @"arguments": [NSArray arrayWithObjects:processIdentifier, nil],
        }];
        
        CHDebugLogSource(@"_copyCodeSignature: %@ -> %@", processIdentifier, replyObject);
        
        NSDictionary *replyState = replyObject[@"reply"];
        NSAssert([replyState isKindOfClass:[NSDictionary class]], @"invalid xpc response");
        
        return replyObject;
    }
    
    @autoreleasepool {
        
        audit_token_t autoken = { 0 };
        int kr = audit_token_for_pid((pid_t)[processIdentifier intValue], &autoken);
        if (kr != KERN_SUCCESS)
        {
            return @{ @"reply": @{} };
        }
        
        OSStatus osStatus;
        SecCodeRef secCodeGuest;
        CFDataRef auditData = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)&autoken, sizeof(audit_token_t));
        osStatus = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)@{
            (__bridge NSString *)kSecGuestAttributeAudit: CFBridgingRelease(auditData),
        }, kSecCSDefaultFlags, &secCodeGuest);  // FIXME
        
        if (osStatus != errSecSuccess) {
            return @{ @"reply": @{}, @"error": [NSString stringWithFormat:@"SecCodeCopyGuestWithAttributes (%d): %@", osStatus, (NSString *)CFBridgingRelease(SecCopyErrorMessageString(osStatus, NULL))] };
        }
        
        // Check Client Path
        CFURLRef cfClientPath = NULL;
        osStatus = SecCodeCopyPath(secCodeGuest, kSecCSDefaultFlags, &cfClientPath);
        
        if (osStatus != errSecSuccess) {
            CFRelease(secCodeGuest);
            return @{ @"reply": @{}, @"error": [NSString stringWithFormat:@"SecCodeCopyPath (%d): %@", osStatus, (NSString *)CFBridgingRelease(SecCopyErrorMessageString(osStatus, NULL))] };
        }

        // Copy POSIX Client Path
        CFStringRef cfClientPOSIXPath = CFURLCopyFileSystemPath(cfClientPath, kCFURLPOSIXPathStyle);
        CFRelease(cfClientPath);
        
        if (cfClientPOSIXPath == NULL) {
            CFRelease(secCodeGuest);
            return @{ @"reply": @{}, @"error": @"CFURLCopyFileSystemPath" };
        }
        
        NSString *clientPOSIXPath = (NSString *)CFBridgingRelease(cfClientPOSIXPath);
        CHDebugLogSource(@"clientPOSIXPath = %@", clientPOSIXPath);
        
        SecStaticCodeRef secStaticCodeGuest;
        osStatus = SecCodeCopyStaticCode(secCodeGuest, kSecCSDefaultFlags, &secStaticCodeGuest);
        if (osStatus != errSecSuccess) {
            CFRelease(secCodeGuest);
            return @{ @"reply": @{}, @"error": [NSString stringWithFormat:@"SecCodeCopyStaticCode (%d): %@", osStatus, (NSString *)CFBridgingRelease(SecCopyErrorMessageString(osStatus, NULL))] };
        }
        
        CFDictionaryRef codeSigningInformation;
        osStatus = SecCodeCopySigningInformation(secStaticCodeGuest, kSecCSDefaultFlags, &codeSigningInformation);
        CFRelease(secCodeGuest);
        
        if (osStatus != errSecSuccess) {
            return @{ @"reply": @{}, @"error": [NSString stringWithFormat:@"SecCodeCopySigningInformation (%d): %@", osStatus, (NSString *)CFBridgingRelease(SecCopyErrorMessageString(osStatus, NULL))] };
        }
        
        return @{ @"reply": (NSDictionary *)CFBridgingRelease(codeSigningInformation), @"error": @"" };
    }
}

- (NSDictionary *)copyCodeSignStatus
{
    return [self _copyCodeSignStatus:@(getpid())];
}

- (NSDictionary *)_copyCodeSignStatus:(NSNumber /* pid_t */ *)processIdentifier
{
    if (_role == AuthPolicyRoleClient)
    {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(_copyCodeSignStatus:)),
            @"arguments": [NSArray arrayWithObjects:processIdentifier, nil],
        }];
        
        CHDebugLogSource(@"_copyCodeSignature: %@ -> %@", processIdentifier, replyObject);
        
        NSNumber *replyState = replyObject[@"status"];
        NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
        
        return replyObject;
    }
    
    @autoreleasepool {
        audit_token_t autoken = { 0 };
        int kr = audit_token_for_pid((pid_t)[processIdentifier intValue], &autoken);
        if (kr != KERN_SUCCESS)
        {
            return @{ @"reply": @{} };
        }
        
        SecTaskRef targetTask = SecTaskCreateWithAuditToken(kCFAllocatorDefault, autoken);
        if (!targetTask)
        {
            return @{ @"reply": @{} };
        }
        
        CFErrorRef error = NULL;
        CFStringRef signingIdentifier = SecTaskCopySigningIdentifier(targetTask, &error);
        uint32_t signStatus = SecTaskGetCodeSignStatus(targetTask);
        
        CFRelease(targetTask);
        
        /*
         * Sadly, these fields do not make any scene on a jailbroken device.
         */
        return @{
            @"token": @[
                @(autoken.val[0]),
                @(autoken.val[1]),
                @(autoken.val[2]),
                @(autoken.val[3]),
                @(autoken.val[4]),
                @(autoken.val[5]),
                @(autoken.val[6]),
                @(autoken.val[7]),
            ],
            @"status": @(signStatus),
            @"valid": [NSNumber numberWithBool:(BOOL)(signStatus & CS_VALID)],
            @"platform": [NSNumber numberWithBool:(BOOL)(signStatus & CS_PLATFORM_BINARY)],
            @"signed": [NSNumber numberWithBool:(BOOL)(signStatus & CS_SIGNED)],
            @"debugged": [NSNumber numberWithBool:(BOOL)(signStatus & CS_DEBUGGED)],
            @"identifier": signingIdentifier != NULL ? (NSString *)CFBridgingRelease(signingIdentifier) : @"",
        };
    }
}

- (NSDictionary *)copyEntitlements
{
    return [self _copyEntitlements:@(getpid())][@"reply"];
}

- (NSDictionary *)_copyEntitlements:(NSNumber /* pid_t */ *)processIdentifier
{
    if (_role == AuthPolicyRoleClient)
    {
        NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
            @"selector": NSStringFromSelector(@selector(_copyEntitlements:)),
            @"arguments": [NSArray arrayWithObjects:processIdentifier, nil],
        }];
        
        CHDebugLogSource(@"_copyEntitlements: %@ -> %@", processIdentifier, replyObject);
        NSAssert([replyObject[@"reply"] isKindOfClass:[NSDictionary class]], @"invalid xpc response");
        
        return replyObject;
    }
    
    @autoreleasepool {
        audit_token_t autoken = { 0 };
        int kr = audit_token_for_pid((pid_t)[processIdentifier intValue], &autoken);
        if (kr != KERN_SUCCESS)
        {
            return @{ @"reply": @{}, @"error": @"audit_token_for_pid" };
        }
        
        SecTaskRef targetTask = SecTaskCreateWithAuditToken(kCFAllocatorDefault, autoken);
        if (!targetTask)
        {
            return @{ @"reply": @{}, @"error": @"SecTaskCreateWithAuditToken" };
        }
        
        CFErrorRef error = NULL;
        CFDictionaryRef partialEntitlements = SecTaskCopyValuesForEntitlements(targetTask, (__bridge CFArrayRef)@[], &error);
        
        int errorCode = targetTask->lastFailure;
        CHDebugLogSource(@"%d", errorCode);
        
        NSDictionary *entitlements = nil;
        if (targetTask->entitlements) {
            entitlements = CFBridgingRelease(CFRetain(targetTask->entitlements));
        }
        
        if (partialEntitlements) {
            CFRelease(partialEntitlements);
        }
        
        CFRelease(targetTask);
        
        return @{
            @"reply": entitlements ?: @{},
            @"error": error != NULL ? [(NSError *)CFBridgingRelease(error) localizedDescription] : @"",
        };
    }
}

@end


#pragma mark -

CHConstructor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] arguments][0];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        BOOL forceClient = [[[NSProcessInfo processInfo] environment][@"CLIENT"] boolValue];
        
        if (!forceClient && ([processName isEqualToString:@"authpolicyd"] || [processName hasSuffix:@"/authpolicyd"]))
        {   /* Server Process - authpolicyd */
            
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                void *SecurityBinary = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY);
                NSCAssert(SecurityBinary, [NSString stringWithUTF8String:dlerror()]);
            });

            rocketbootstrap_unlock(XPC_INSTANCE_NAME);
            
            CPDistributedMessagingCenter *serverMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(serverMessagingCenter);
            [serverMessagingCenter runServerOnCurrentThread];
            
            AuthPolicy *serverInstance = [AuthPolicy sharedInstanceWithRole:AuthPolicyRoleServer];
            [serverMessagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
            [serverMessagingCenter registerForMessageName:@XPC_TWOWAY_MSG_NAME target:serverInstance selector:@selector(receiveAndReplyMessageName:userInfo:)];
            [serverInstance setMessagingCenter:serverMessagingCenter];
            
            CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", serverMessagingCenter, bundleIdentifier, processName, getpid());
        }
        else
        {   /* Client Process */
            
            CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
            
            AuthPolicy *clientInstance = [AuthPolicy sharedInstanceWithRole:AuthPolicyRoleClient];
            [clientInstance setMessagingCenter:clientMessagingCenter];
            
            CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
        }
    }
}
