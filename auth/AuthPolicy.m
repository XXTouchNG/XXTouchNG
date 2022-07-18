#if !__has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "AuthPolicy.h"
#import "pac_helper.h"
#import "SecCode.h"
#import "SecStaticCode.h"
#import "SecTask.h"
#import "CSCommon.h"
#import "cs_blobs.h"
#import <rocketbootstrap/rocketbootstrap.h>
#import <Security/Security.h>
#import <sys/sysctl.h>

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

+ (nullable NSString *)binaryPathOfProcessIdentifier:(pid_t)pid {
    
    // First ask the system how big a buffer we should allocate
    int mib[3] = {CTL_KERN, KERN_ARGMAX, 0};
    
    size_t argmaxsize = sizeof(size_t);
    size_t size = 0;
    
    int ret = sysctl(mib, 2, &size, &argmaxsize, NULL, 0);
    if (ret != 0) {
        CHDebugLogSource(@"Error '%s' (%d) getting KERN_ARGMAX", strerror(errno), errno);
        return nil;
    }
    
    // Then we can get the path information we actually want
    mib[1] = KERN_PROCARGS2;
    mib[2] = (int)pid;
    
    char *procargv = malloc(size);
    bzero(procargv, size);
    
    ret = sysctl(mib, 3, procargv, &size, NULL, 0);
    
    if (ret != 0) {
        CHDebugLogSource(@"Error '%s' (%d) for pid %d", strerror(errno), errno, pid);
        free(procargv);
        return nil;
    }
    
    // procargv is actually a data structure.
    // The path is at procargv + sizeof(int)
    NSString *path = [NSString stringWithUTF8String:(procargv + sizeof(int))];
    free(procargv);
    return path;
}

+ (id)mutableCopyOfConvertedObject:(id)object
{
    return [self mutableCopyOfConvertedObject:object depth:0 parent:nil];
}

+ (id)mutableCopyOfConvertedObject:(id)object depth:(int)depth parent:(id)parent
{
    NSAssert(depth < 15, @"max depth reached");
    if ([object isKindOfClass:[NSDictionary class]])
    {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[object count]];
        for (id key in [object allKeys])
        {
            id child = [object objectForKey:key];
            id val = [self mutableCopyOfConvertedObject:child depth:(depth + 1) parent:object];
            id strKey = key;
            if (![key isKindOfClass:[NSString class]])
                strKey = [NSString stringWithFormat:@"%@", key];
            if (val) [dict setObject:val forKey:strKey];
        }
        return dict;
    }
    else if ([object isKindOfClass:[NSArray class]])
    {
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[object count]];
        for (id child in object)
        {
            id val = [self mutableCopyOfConvertedObject:child depth:(depth + 1) parent:object];
            if (val) [arr addObject:val];
        }
        return arr;
    }
    else
    {
        if ([object isKindOfClass:[NSData class]]) { return [object copy]; }
        else if ([object isKindOfClass:[NSString class]]) { return [object copy]; }
        else if ([object isKindOfClass:[NSDate class]]) { return [object copy]; }
        else if ([object isKindOfClass:[NSNumber class]]) { return [object copy]; }
        else if ([object isKindOfClass:[NSURL class]]) {
            return [object isFileURL] ? [object path] : [object absoluteString];
        }
        else {
            CFTypeID typeID = CFGetTypeID((__bridge CFTypeRef)(object));
            if (typeID == SecCertificateGetTypeID())
            {
                NSMutableDictionary *secCertificateDict = [NSMutableDictionary dictionaryWithCapacity:4];
                SecCertificateRef secCertificateObject = (__bridge SecCertificateRef)(object);
                
                OSStatus osStatus;
                CFStringRef commonName;
                osStatus = SecCertificateCopyCommonName(secCertificateObject, &commonName);
                if (osStatus == errSecSuccess)
                {
                    [secCertificateDict setObject:(NSString *)CFBridgingRelease(commonName) forKey:@"CommonName"];
                }
                
                CFArrayRef emailAddresses;
                osStatus = SecCertificateCopyEmailAddresses(secCertificateObject, &emailAddresses);
                if (osStatus == errSecSuccess)
                {
                    [secCertificateDict setObject:(NSArray <NSString *> *)CFBridgingRelease(emailAddresses) forKey:@"EmailAddresses"];
                }
                
                CFStringRef subjectSummary = SecCertificateCopySubjectSummary(secCertificateObject);
                if (subjectSummary)
                {
                    [secCertificateDict setObject:(NSString *)CFBridgingRelease(subjectSummary) forKey:@"SubjectSummary"];
                }
                
                CFErrorRef error = NULL;
                CFDataRef serialNumberData = SecCertificateCopySerialNumberData(secCertificateObject, &error);
                if (serialNumberData)
                {
                    [secCertificateDict setObject:(NSData *)CFBridgingRelease(serialNumberData) forKey:@"SerialNumberData"];
                }
                
                if (error)
                {
                    CFRelease(error);
                }
                
                return secCertificateDict;
            }
            return nil;
        }
    }
}

- (NSDictionary *)copyCodeSignature
{
    return [self _copyCodeSignature:@(getpid())];
}

- (NSDictionary *)copyCodeSignatureWithProcessIdentifier:(pid_t)processIdentifier
{
    return [self _copyCodeSignature:@(processIdentifier)];
}

- (NSDictionary *)_copyCodeSignature:(NSNumber /* pid_t */ *)processIdentifier
{
    if (_role == AuthPolicyRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_copyCodeSignature:)),
                @"arguments": [NSArray arrayWithObjects:processIdentifier, nil],
            }];
            
            CHDebugLogSource(@"_copyCodeSignature: %@ -> %@", processIdentifier, replyObject);
            
            NSDictionary *replyState = replyObject[@"reply"];
            NSAssert([replyState isKindOfClass:[NSDictionary class]], @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        
        NSString *binaryPath = [AuthPolicy binaryPathOfProcessIdentifier:[processIdentifier intValue]];
        if (!binaryPath)
        {
            return @{ @"reply": @{}, @"error": @"sysctl" };
        }
        
        CFURLRef binaryURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef)binaryPath, kCFURLPOSIXPathStyle, false);
        
        OSStatus osStatus;
        SecStaticCodeRef secStaticCodeGuest;
        osStatus = SecStaticCodeCreateWithPath(binaryURL, kSecCSDefaultFlags, &secStaticCodeGuest);
        CFRelease(binaryURL);
        
        if (osStatus != errSecSuccess) {
            return @{ @"reply": @{}, @"error": [NSString stringWithFormat:@"SecCodeCopyStaticCode (%d): %@", osStatus, (NSString *)CFBridgingRelease(SecCopyErrorMessageString(osStatus, NULL))] };
        }
        
        SecCSFlags flags =
        (
         kSecCSDefaultFlags |
         kSecCSSigningInformation |  // This is what we actually want.
         kSecCSSkipResourceDirectory
         );
        
        CFDictionaryRef codeSigningInformation;
        osStatus = SecCodeCopySigningInformation(secStaticCodeGuest, flags, &codeSigningInformation);
        
        if (osStatus != errSecSuccess) {
            return @{ @"reply": @{}, @"error": [NSString stringWithFormat:@"SecCodeCopySigningInformation (%d): %@", osStatus, (NSString *)CFBridgingRelease(SecCopyErrorMessageString(osStatus, NULL))] };
        }
        
        return @{ @"reply": (NSDictionary *)[AuthPolicy mutableCopyOfConvertedObject:CFBridgingRelease(codeSigningInformation)], @"error": @"" };
    }
}

- (NSDictionary *)copyCodeSignStatus
{
    return [self _copyCodeSignStatus:@(getpid())];
}

- (NSDictionary *)copyCodeSignStatusWithProcessIdentifier:(pid_t)processIdentifier
{
    return [self _copyCodeSignStatus:@(processIdentifier)];
}

- (NSDictionary *)_copyCodeSignStatus:(NSNumber /* pid_t */ *)processIdentifier
{
    if (_role == AuthPolicyRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_copyCodeSignStatus:)),
                @"arguments": [NSArray arrayWithObjects:processIdentifier, nil],
            }];
            
            CHDebugLogSource(@"_copyCodeSignature: %@ -> %@", processIdentifier, replyObject);
            
            NSNumber *replyState = replyObject[@"status"];
            NSAssert([replyState isKindOfClass:[NSNumber class]], @"invalid xpc response");
            
            return replyObject;
        }
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

- (NSDictionary *)copyEntitlementsWithProcessIdentifier:(pid_t)processIdentifier
{
    return [self _copyEntitlements:@(processIdentifier)][@"reply"];
}

- (NSDictionary *)_copyEntitlements:(NSNumber /* pid_t */ *)processIdentifier
{
    if (_role == AuthPolicyRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_copyEntitlements:)),
                @"arguments": [NSArray arrayWithObjects:processIdentifier, nil],
            }];
            
            CHDebugLogSource(@"_copyEntitlements: %@ -> %@", processIdentifier, replyObject);
            NSAssert([replyObject[@"reply"] isKindOfClass:[NSDictionary class]], @"invalid xpc response");
            
            return replyObject;
        }
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
            @"error": error != NULL ? [(NSError *)CFBridgingRelease (error) localizedDescription] : @"",
        };
    }
}

@end


#pragma mark -

#import "MyAntiDebugging.h"

CHConstructor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] arguments][0];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        BOOL forceClient = [[[NSProcessInfo processInfo] environment][@"CLIENT"] boolValue];
        
        if (!forceClient && ([processName isEqualToString:@"authpolicyd"] || [processName hasSuffix:@"/authpolicyd"]))
        {   /* Server Process - authpolicyd */
            
            do {
                
                /// do inject to protected executable only
                if (!dlsym(RTLD_MAIN_ONLY, "plugin_i_love_xxtouch")) {
                    break;
                }
                
                root_anti_debugging(NO);
                
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
                
            } while (NO);
        }
        else
        {   /* Client Process */
            
            do {
                
                CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
                rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
                
                AuthPolicy *clientInstance = [AuthPolicy sharedInstanceWithRole:AuthPolicyRoleClient];
                [clientInstance setMessagingCenter:clientMessagingCenter];
                
                CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());

            } while (NO);
        }
    }
}
