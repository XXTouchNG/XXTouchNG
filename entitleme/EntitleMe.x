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

%ctor {
    @autoreleasepool {
		NSString *processName = [[NSProcessInfo processInfo] processName];
        MSImageRef _SecurityLibrary = MSGetImageByName("/System/Library/Frameworks/Security.framework/Security");
		if (_SecurityLibrary)
		{
			_SecTaskCopySigningIdentifier = (sec_task_copy_id_t *)make_sym_callable(MSFindSymbol(_SecurityLibrary, "_SecTaskCopySigningIdentifier"));
			MSHookFunction(
				make_sym_callable(MSFindSymbol(_SecurityLibrary, "_SecTaskCopyValueForEntitlement")),
				(void *)replaced_SecTaskCopyValueForEntitlement,
				(void **)&original_SecTaskCopyValueForEntitlement
			);
			
			CHDebugLogSource(@"%@ hacked", processName);
		}
	}
}