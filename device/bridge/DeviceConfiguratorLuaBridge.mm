#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"
#import <pthread.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <sys/sysctl.h>
#import <sys/mount.h>
#import <sys/utsname.h>
#import <sys/socket.h>
#import <net/if_dl.h>
#import <net/if_types.h>
#import <ifaddrs.h>
#import <mach/mach.h>
#import <netdb.h>

#import "DeviceConfigurator.h"
#import "GeneratedTouchesDebugWindow.h"
#import "UIView+XXTEToast.h"
#import "UIDevice+EquipmentInfo.h"
#import "NSDate+NetworkClock.h"
#import "DCUtilNetwork.h"
#import "DCUtilNetworksManager.h"

#import "luae.h"
#import "TFShell.h"
#import <MobileGestalt/MobileGestalt.h>


#pragma mark -

XXTouchF_CAPI int luaopen_sys(lua_State *);
XXTouchF_CAPI int luaopen_exsys(lua_State *);
XXTouchF_CAPI int luaopen_device(lua_State *);
XXTouchF_CAPI int luaopen_exdevice(lua_State *);


#pragma mark -

typedef enum : NSUInteger {
    DeviceConfiguratorToastOrientationHomeOnBottom = 0,
    DeviceConfiguratorToastOrientationHomeOnRight,
    DeviceConfiguratorToastOrientationHomeOnLeft,
    DeviceConfiguratorToastOrientationHomeOnTop,
} DeviceConfiguratorToastOrientation;


@interface DeviceConfiguratorLuaBridge : NSObject
+ (instancetype)sharedBridge;
@end

@implementation DeviceConfiguratorLuaBridge

+ (instancetype)sharedBridge {
    static DeviceConfiguratorLuaBridge *_sharedBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedBridge = [[DeviceConfiguratorLuaBridge alloc] init];
    });
    return _sharedBridge;
}

@end


#pragma mark -

#define DCERR_INVALID_ORIENTATION \
    "Invalid orientation %I, available values are:" "\n" \
    "  * Home on bottom = 0" "\n" \
    "  * Home on right = 1" "\n" \
    "  * Home on left = 2" "\n" \
    "  * Home on top = 3"

NS_INLINE NSTimeInterval l_uptime()
{
    static float timebase_ratio;
    if (timebase_ratio == 0) {
        mach_timebase_info_data_t s_timebase_info;
        (void) mach_timebase_info(&s_timebase_info);
        
        timebase_ratio = (float)s_timebase_info.numer / s_timebase_info.denom;
    }
    return timebase_ratio * mach_absolute_time() / 1e9;
}


#pragma mark -

static int DeviceConfigurator_System_Toast(lua_State *L)
{
    @autoreleasepool {
        const char *cContent = luaL_checkstring(L, 1);
        
        /// Argument #2
        DeviceConfiguratorToastOrientation gOrientation = DeviceConfiguratorToastOrientationHomeOnBottom;
        int gType = lua_getglobal(L, "ORIENTATION");
        if (gType == LUA_TNUMBER) {
            gOrientation = (DeviceConfiguratorToastOrientation)lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        lua_Integer cOrientation = luaL_optinteger(L, 2, gOrientation);
        
        // Special case: hide existing toasts
        if (cOrientation == -1) {
            [[GeneratedTouchesDebugWindow sharedGeneratedTouchesDebugWindow] hideToasts];
            return 0;
        }
        
        /// Check argument #2
        if (cOrientation < 0 || cOrientation > 3) {
            return luaL_error(L, DCERR_INVALID_ORIENTATION, cOrientation);
        }
        
        /// Convert orientation
        UIInterfaceOrientation systemOrientation;
        switch (cOrientation) {
        case DeviceConfiguratorToastOrientationHomeOnBottom:
            systemOrientation = UIInterfaceOrientationPortrait;
            break;
        case DeviceConfiguratorToastOrientationHomeOnRight:
            systemOrientation = UIInterfaceOrientationLandscapeRight;
            break;
        case DeviceConfiguratorToastOrientationHomeOnLeft:
            systemOrientation = UIInterfaceOrientationLandscapeLeft;
            break;
        case DeviceConfiguratorToastOrientationHomeOnTop:
            systemOrientation = UIInterfaceOrientationPortraitUpsideDown;
            break;
        }
        
        /// Make remote toast
        NSString *toastContent = [NSString stringWithUTF8String:cContent];
        [[GeneratedTouchesDebugWindow sharedGeneratedTouchesDebugWindow] makeToast:toastContent
                                                                          duration:2.8
                                                                          position:XXTEToastPositionBottom
                                                                       orientation:systemOrientation];
        
        return 0;
    }
}

static int DeviceConfigurator_System_ToastActivity(lua_State *L)
{
    @autoreleasepool {
        BOOL shouldShow = lua_isboolean(L, 1) ? lua_toboolean(L, 1) : YES;
        if (shouldShow) {
            [[GeneratedTouchesDebugWindow sharedGeneratedTouchesDebugWindow] showToastActivity];
        } else {
            [[GeneratedTouchesDebugWindow sharedGeneratedTouchesDebugWindow] hideToastActivity];
        }
        return 0;
    }
}

static int DeviceConfigurator_System_MGCopyAnswer(lua_State *L)
{
    @autoreleasepool {
        const char *cQuestion = luaL_checkstring(L, 1);
        CFStringRef question = CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, cQuestion, kCFStringEncodingUTF8, kCFAllocatorNull);
        id answer = CFBridgingRelease(MGCopyAnswer(question, NULL));
        CFRelease(question);
        lua_pushNSValue(L, answer);
        return 1;
    }
}

static int DeviceConfigurator_System_Version(lua_State *L)
{
    @autoreleasepool {
        lua_pushstring(L, [[[UIDevice currentDevice] systemVersion] UTF8String]);
        return 1;
    }
}

static int DeviceConfigurator_System_XXTVersion(lua_State *L)
{
    @autoreleasepool {
        lua_pushliteral(L, XXT_VERSION);
        return 1;
    }
}

static int DeviceConfigurator_System_TimeInMilliseconds(lua_State *L)
{
    @autoreleasepool {
        lua_pushinteger(L, (lua_Integer)floor([[NSDate date] timeIntervalSince1970] * 1e3));
        return 1;
    }
}

static int DeviceConfigurator_System_NetworkTime(lua_State *L)
{
    @autoreleasepool {
        NHNetworkClock *clock = [NHNetworkClock sharedNetworkClock];
        
        static BOOL didBeginSynchronize = NO;
        if (!didBeginSynchronize) {
            didBeginSynchronize = [clock synchronize];  // which never stops
        }
        
        __block BOOL isSynchronized = NO;
        dispatch_sync(clock.accessQueue, ^{
            isSynchronized = clock.isSynchronized;
        });
        
        lua_pushinteger(L, (lua_Integer)floor([[NSDate networkDate] timeIntervalSince1970]));
        lua_pushboolean(L, isSynchronized);
        return 2;
    }
}

/**
 * Accuate delay
 */

typedef struct SleepState {
    NSTimeInterval deadline;
} SleepState;

static int DeviceConfigurator_System_Sleep_Yield(lua_State *L, int status, lua_KContext ctx)
{
    SleepState *sleep = (SleepState *)ctx;
    [NSThread sleepForTimeInterval:1e-4];  // 0.1ms
    
    if (l_uptime() > sleep->deadline)
    {
        return 0;
    }
    
    return lua_yieldk(L, 0, ctx, DeviceConfigurator_System_Sleep_Yield);
}

static int DeviceConfigurator_System_StreamSleepInSeconds(lua_State *L)
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    lua_Number sleepInterval = luaL_checknumber(L, 1);
    
    BOOL isMain = lua_pushthread(L) == 1;
    lua_pop(L, 1);
    if (!isMain) {
        
        /// Delay and unlock
        SleepState *sleep = (SleepState *)lua_newuserdata(L, sizeof(SleepState));
        sleep->deadline = l_uptime() + sleepInterval;
        
        return lua_yieldk(L, 0, (lua_KContext)sleep, DeviceConfigurator_System_Sleep_Yield);
    }
    
    [NSThread sleepForTimeInterval:sleepInterval];
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
    
    return 0;
}

static int DeviceConfigurator_System_StreamSleepInMilliseconds(lua_State *L)
{
#if DEBUG
    __uint64_t beginAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
    
    lua_Number sleepInterval = luaL_checknumber(L, 1);
    sleepInterval /= 1e3;
    
    BOOL isMain = lua_pushthread(L) == 1;
    lua_pop(L, 1);
    if (!isMain) {
        
        /// Delay and unlock
        SleepState *sleep = (SleepState *)lua_newuserdata(L, sizeof(SleepState));
        sleep->deadline = l_uptime() + sleepInterval;
        
        return lua_yieldk(L, 0, (lua_KContext)sleep, DeviceConfigurator_System_Sleep_Yield);
    }
    
    [NSThread sleepForTimeInterval:sleepInterval];
    
#if DEBUG
    __uint64_t endAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    double used = (endAt - beginAt) / 1e6;
    CHDebugLogSource(@"time elapsed %.2fms", used);
#endif
    
    return 0;
}

static int DeviceConfigurator_System_RealRandom(lua_State *L)
{
    lua_pushinteger(L, arc4random());
    return 1;
}

static int DeviceConfigurator_System_AvailableMemory(lua_State *L)
{
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    mach_port_t mach_host = mach_host_self();
    kern_return_t kernReturn = host_statistics(mach_host,
                                               HOST_VM_INFO,
                                               (host_info_t)&vmStats,
                                               &infoCount);
    mach_port_deallocate(mach_task_self(), mach_host);
    
    if (kernReturn != KERN_SUCCESS) {
        lua_pushnil(L);
        return 1;
    }
    
    lua_pushnumber(L, ((vm_page_size * vmStats.free_count) / 1024.0) / 1024.0);
    return 1;
}

static int DeviceConfigurator_System_XXTUsedMemory(lua_State *L)
{
    task_basic_info_data_t taskInfo;
    mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
    kern_return_t kernReturn = task_info(mach_task_self(),
                                         TASK_BASIC_INFO,
                                         (task_info_t)&taskInfo,
                                         &infoCount);
    
    if (kernReturn != KERN_SUCCESS) {
        lua_pushnil(L);
        return 1;
    }
    
    lua_pushnumber(L, taskInfo.resident_size / 1024.0 / 1024.0);
    return 1;
}

static int DeviceConfigurator_System_TotalMemory(lua_State *L)
{
    @autoreleasepool {
        lua_pushnumber(L, [[NSProcessInfo processInfo] physicalMemory] / 1024.0 / 1024.0);
        return 1;
    }
}

static int    lflag, nflag;
static char   **typelist = NULL;
static enum   { IN_LIST, NOT_IN_LIST } which;

NS_INLINE int selected(const char *type)
{
    char **av;

    /* If no type specified, it's always selected. */
    if (typelist == NULL)
        return (1);
    for (av = typelist; *av != NULL; ++av)
        if (!strncmp(type, *av, MFSNAMELEN))
            return (which == IN_LIST ? 1 : 0);
    return (which == IN_LIST ? 0 : 1);
}

NS_INLINE long regetmntinfo(struct statfs **mntbufp, long mntsize)
{
    int i, j;
    struct statfs *mntbuf;

    if (!lflag && typelist == NULL)
        return (nflag ? mntsize : getmntinfo(mntbufp, MNT_WAIT));

    mntbuf = *mntbufp;
    j = 0;
    for (i = 0; i < mntsize; i++) {
        if (lflag && (mntbuf[i].f_flags & MNT_LOCAL) == 0)
            continue;
        if (!selected(mntbuf[i].f_fstypename))
            continue;
        if (nflag)
            mntbuf[j] = mntbuf[i];
        else
            (void)statfs(mntbuf[i].f_mntonname, &mntbuf[j]);
        j++;
    }
    return (j);
}

static int DeviceConfigurator_System_MountedVolumes(lua_State *L)
{
    @autoreleasepool {
        struct statfs *mntbuf;
        long mntsize;
        
        mntsize = getmntinfo(&mntbuf, MNT_NOWAIT);
        if (mntsize == 0)
            return luaL_error(L, "retrieving information on mounted file systems");
        
        mntsize = regetmntinfo(&mntbuf, mntsize);
        if (mntsize == 0)
            return luaL_error(L, "retrieving information on mounted file systems");
        
        NSMutableDictionary <NSString *, NSString *> *volumeURLStrings = [[NSMutableDictionary alloc] initWithCapacity:mntsize];
        for (int i = 0; i < mntsize; i++) {
            [volumeURLStrings setObject:[NSString stringWithUTF8String:(const char *)&mntbuf[i].f_mntfromname] forKey:[NSString stringWithUTF8String:(const char *)&mntbuf[i].f_mntonname]];
        }
        
        lua_pushNSDictionary(L, volumeURLStrings);
        return 1;
    }
}

static int DeviceConfigurator_System_FreeDiskSpace(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        NSError *attrErr = nil;
        NSDictionary <NSFileAttributeKey, id> *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:&attrErr];
        if (!attrs) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushinteger(L, [attrs[NSFileSystemFreeSize] longLongValue] / 1024.0 / 1024.0);
        return 1;
    }
}

static int DeviceConfigurator_System_TotalDiskSpace(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        NSError *attrErr = nil;
        NSDictionary <NSFileAttributeKey, id> *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:&attrErr];
        if (!attrs) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushinteger(L, [attrs[NSFileSystemSize] longLongValue] / 1024.0 / 1024.0);
        return 1;
    }
}

static int DeviceConfigurator_System_Respring(lua_State *L)
{
    ios_system("killall -9 SpringBoard backboardd");
    return 0;
}

static int DeviceConfigurator_System_Reboot(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] reboot];
        return 0;
    }
}

static int DeviceConfigurator_System_Halt(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] shutdown];
        return 0;
    }
}

static int DeviceConfigurator_System_LDRestart(lua_State *L)
{
    ios_system("ldrestart");
    return 0;
}

static int DeviceConfigurator_System_Alert(lua_State *L)
{
    @autoreleasepool {
        const char *cContent = luaL_checkstring(L, 1);
        NSString *content = [NSString stringWithUTF8String:cContent];
        
        lua_Number timeoutInSeconds = luaL_optnumber(L, 2, 0);
        
        const char *cTitle = luaL_optstring(L, 3, "Script Message");
        NSString *title = [NSString stringWithUTF8String:cTitle];
        
        const char *bTitle0 = luaL_optstring(L, 4, "OK");
        NSString *title0 = [NSString stringWithUTF8String:bTitle0];
        
        const char *bTitle1 = luaL_optstring(L, 5, "");
        NSString *title1 = [NSString stringWithUTF8String:bTitle1];
        
        const char *bTitle2 = luaL_optstring(L, 6, "");
        NSString *title2 = [NSString stringWithUTF8String:bTitle2];
        
        NSMutableArray <NSString *> *buttonTitles = [NSMutableArray arrayWithCapacity:3];
        
        if (title0.length) {
            [buttonTitles addObject:title0];
        }
        
        if (title1.length) {
            [buttonTitles addObject:title1];
        }
        
        if (title2.length) {
            [buttonTitles addObject:title2];
        }
        
        NSInteger choice = [[DeviceConfigurator sharedConfigurator] popAlertWithTimeout:timeoutInSeconds
                                                                           messageTitle:title
                                                                         messageContent:content
                                                                           buttonTitles:buttonTitles];
        
        lua_pushinteger(L, choice);
        return 1;
    }
}

static int DeviceConfigurator_System_InputBox(lua_State *L)
{
    @autoreleasepool {
        int argc = lua_gettop(L);
        
        NSString *title = nil;
        NSString *content = nil;
        lua_Number timeoutInSeconds = 0;
        
        NSString *shadow0 = nil;
        NSString *content0 = nil;
        NSString *shadow1 = nil;
        NSString *content1 = nil;
        
        NSString *button0 = nil;
        NSString *button1 = nil;
        NSString *button2 = nil;
        
        if (argc == 1) {
            const char *cContent = luaL_checkstring(L, 1);
            content = [NSString stringWithUTF8String:cContent];
            shadow0 = @"";
        }
        else if (argc == 2) {
            const char *cTitle = luaL_checkstring(L, 1);
            title = [NSString stringWithUTF8String:cTitle];
            const char *cContent = luaL_checkstring(L, 2);
            content = [NSString stringWithUTF8String:cContent];
            shadow0 = @"";
        }
        else if (argc == 3) {
            const char *cTitle = luaL_checkstring(L, 1);
            title = [NSString stringWithUTF8String:cTitle];
            const char *cContent = luaL_checkstring(L, 2);
            content = [NSString stringWithUTF8String:cContent];
            shadow0 = @"";
            if (lua_type(L, 3) == LUA_TTABLE) {
                NSArray <NSString *> *cShadows = lua_toNSArray(L, 3);
                if (cShadows.count > 0) {
                    shadow0 = [cShadows[0] isKindOfClass:[NSString class]] ? cShadows[0] : @"";
                }
                if (cShadows.count > 1) {
                    shadow1 = [cShadows[1] isKindOfClass:[NSString class]] ? cShadows[1] : @"";
                }
            } else if (lua_type(L, 3) == LUA_TSTRING) {
                const char *cShadow0 = luaL_checkstring(L, 3);
                shadow0 = [NSString stringWithUTF8String:cShadow0];
            } else {
                timeoutInSeconds = luaL_checknumber(L, 3);
            }
        }
        else if (argc == 4) {
            const char *cTitle = luaL_checkstring(L, 1);
            title = [NSString stringWithUTF8String:cTitle];
            const char *cContent = luaL_checkstring(L, 2);
            content = [NSString stringWithUTF8String:cContent];
            shadow0 = @"";
            if (lua_type(L, 3) == LUA_TTABLE) {
                NSArray <NSString *> *cShadows = lua_toNSArray(L, 3);
                if (cShadows.count > 0) {
                    shadow0 = [cShadows[0] isKindOfClass:[NSString class]] ? cShadows[0] : @"";
                }
                if (cShadows.count > 1) {
                    shadow1 = [cShadows[1] isKindOfClass:[NSString class]] ? cShadows[1] : @"";
                }
            } else {
                const char *cShadow0 = luaL_checkstring(L, 3);
                shadow0 = [NSString stringWithUTF8String:cShadow0];
            }
            if (lua_type(L, 4) == LUA_TTABLE) {
                NSArray <NSString *> *cContents = lua_toNSArray(L, 4);
                if (cContents.count > 0) {
                    content0 = [cContents[0] isKindOfClass:[NSString class]] ? cContents[0] : @"";
                }
                if (cContents.count > 1) {
                    content1 = [cContents[1] isKindOfClass:[NSString class]] ? cContents[1] : @"";
                }
            } else if (lua_type(L, 4) == LUA_TSTRING) {
                const char *cContent0 = luaL_checkstring(L, 4);
                content0 = [NSString stringWithUTF8String:cContent0];
            } else {
                timeoutInSeconds = luaL_checknumber(L, 4);
            }
        }
        else if (argc == 5) {
            const char *cTitle = luaL_checkstring(L, 1);
            title = [NSString stringWithUTF8String:cTitle];
            const char *cContent = luaL_checkstring(L, 2);
            content = [NSString stringWithUTF8String:cContent];
            shadow0 = @"";
            if (lua_type(L, 3) == LUA_TTABLE) {
                NSArray <NSString *> *cShadows = lua_toNSArray(L, 3);
                if (cShadows.count > 0) {
                    shadow0 = [cShadows[0] isKindOfClass:[NSString class]] ? cShadows[0] : @"";
                }
                if (cShadows.count > 1) {
                    shadow1 = [cShadows[1] isKindOfClass:[NSString class]] ? cShadows[1] : @"";
                }
            } else {
                const char *cShadow0 = luaL_checkstring(L, 3);
                shadow0 = [NSString stringWithUTF8String:cShadow0];
            }
            if (lua_type(L, 4) == LUA_TTABLE) {
                NSArray <NSString *> *cContents = lua_toNSArray(L, 4);
                if (cContents.count > 0) {
                    content0 = [cContents[0] isKindOfClass:[NSString class]] ? cContents[0] : @"";
                }
                if (cContents.count > 1) {
                    content1 = [cContents[1] isKindOfClass:[NSString class]] ? cContents[1] : @"";
                }
            } else {
                const char *cContent0 = luaL_checkstring(L, 4);
                content0 = [NSString stringWithUTF8String:cContent0];
            }
            if (lua_type(L, 5) == LUA_TSTRING) {
                const char *cButton0 = luaL_checkstring(L, 5);
                button0 = [NSString stringWithUTF8String:cButton0];
            } else {
                timeoutInSeconds = luaL_checknumber(L, 5);
            }
        }
        else if (argc == 6) {
            const char *cTitle = luaL_checkstring(L, 1);
            title = [NSString stringWithUTF8String:cTitle];
            const char *cContent = luaL_checkstring(L, 2);
            content = [NSString stringWithUTF8String:cContent];
            shadow0 = @"";
            if (lua_type(L, 3) == LUA_TTABLE) {
                NSArray <NSString *> *cShadows = lua_toNSArray(L, 3);
                if (cShadows.count > 0) {
                    shadow0 = [cShadows[0] isKindOfClass:[NSString class]] ? cShadows[0] : @"";
                }
                if (cShadows.count > 1) {
                    shadow1 = [cShadows[1] isKindOfClass:[NSString class]] ? cShadows[1] : @"";
                }
            } else {
                const char *cShadow0 = luaL_checkstring(L, 3);
                shadow0 = [NSString stringWithUTF8String:cShadow0];
            }
            if (lua_type(L, 4) == LUA_TTABLE) {
                NSArray <NSString *> *cContents = lua_toNSArray(L, 4);
                if (cContents.count > 0) {
                    content0 = [cContents[0] isKindOfClass:[NSString class]] ? cContents[0] : @"";
                }
                if (cContents.count > 1) {
                    content1 = [cContents[1] isKindOfClass:[NSString class]] ? cContents[1] : @"";
                }
            } else {
                const char *cContent0 = luaL_checkstring(L, 4);
                content0 = [NSString stringWithUTF8String:cContent0];
            }
            const char *cButton0 = luaL_checkstring(L, 5);
            button0 = [NSString stringWithUTF8String:cButton0];
            if (lua_type(L, 6) == LUA_TSTRING) {
                const char *cButton1 = luaL_checkstring(L, 6);
                button1 = [NSString stringWithUTF8String:cButton1];
            } else {
                timeoutInSeconds = luaL_checknumber(L, 6);
            }
        }
        else if (argc == 7) {
            const char *cTitle = luaL_checkstring(L, 1);
            title = [NSString stringWithUTF8String:cTitle];
            const char *cContent = luaL_checkstring(L, 2);
            content = [NSString stringWithUTF8String:cContent];
            shadow0 = @"";
            if (lua_type(L, 3) == LUA_TTABLE) {
                NSArray <NSString *> *cShadows = lua_toNSArray(L, 3);
                if (cShadows.count > 0) {
                    shadow0 = [cShadows[0] isKindOfClass:[NSString class]] ? cShadows[0] : @"";
                }
                if (cShadows.count > 1) {
                    shadow1 = [cShadows[1] isKindOfClass:[NSString class]] ? cShadows[1] : @"";
                }
            } else {
                const char *cShadow0 = luaL_checkstring(L, 3);
                shadow0 = [NSString stringWithUTF8String:cShadow0];
            }
            if (lua_type(L, 4) == LUA_TTABLE) {
                NSArray <NSString *> *cContents = lua_toNSArray(L, 4);
                if (cContents.count > 0) {
                    content0 = [cContents[0] isKindOfClass:[NSString class]] ? cContents[0] : @"";
                }
                if (cContents.count > 1) {
                    content1 = [cContents[1] isKindOfClass:[NSString class]] ? cContents[1] : @"";
                }
            } else {
                const char *cContent0 = luaL_checkstring(L, 4);
                content0 = [NSString stringWithUTF8String:cContent0];
            }
            const char *cButton0 = luaL_checkstring(L, 5);
            button0 = [NSString stringWithUTF8String:cButton0];
            const char *cButton1 = luaL_checkstring(L, 6);
            button1 = [NSString stringWithUTF8String:cButton1];
            if (lua_type(L, 7) == LUA_TSTRING) {
                const char *cButton2 = luaL_checkstring(L, 7);
                button2 = [NSString stringWithUTF8String:cButton2];
            } else {
                timeoutInSeconds = luaL_checknumber(L, 7);
            }
        }
        else if (argc == 8) {
            const char *cTitle = luaL_checkstring(L, 1);
            title = [NSString stringWithUTF8String:cTitle];
            const char *cContent = luaL_checkstring(L, 2);
            content = [NSString stringWithUTF8String:cContent];
            shadow0 = @"";
            if (lua_type(L, 3) == LUA_TTABLE) {
                NSArray <NSString *> *cShadows = lua_toNSArray(L, 3);
                if (cShadows.count > 0) {
                    shadow0 = [cShadows[0] isKindOfClass:[NSString class]] ? cShadows[0] : @"";
                }
                if (cShadows.count > 1) {
                    shadow1 = [cShadows[1] isKindOfClass:[NSString class]] ? cShadows[1] : @"";
                }
            } else {
                const char *cShadow0 = luaL_checkstring(L, 3);
                shadow0 = [NSString stringWithUTF8String:cShadow0];
            }
            if (lua_type(L, 4) == LUA_TTABLE) {
                NSArray <NSString *> *cContents = lua_toNSArray(L, 4);
                if (cContents.count > 0) {
                    content0 = [cContents[0] isKindOfClass:[NSString class]] ? cContents[0] : @"";
                }
                if (cContents.count > 1) {
                    content1 = [cContents[1] isKindOfClass:[NSString class]] ? cContents[1] : @"";
                }
            } else {
                const char *cContent0 = luaL_checkstring(L, 4);
                content0 = [NSString stringWithUTF8String:cContent0];
            }
            const char *cButton0 = luaL_checkstring(L, 5);
            button0 = [NSString stringWithUTF8String:cButton0];
            const char *cButton1 = luaL_checkstring(L, 6);
            button1 = [NSString stringWithUTF8String:cButton1];
            const char *cButton2 = luaL_checkstring(L, 7);
            button2 = [NSString stringWithUTF8String:cButton2];
            timeoutInSeconds = luaL_checknumber(L, 8);
        }
        else {
            return luaL_error(L, "too many arguments");
        }
        
        NSMutableArray <NSString *> *buttonTitles = [NSMutableArray arrayWithCapacity:3];
        
        if (button0.length) {
            [buttonTitles addObject:button0];
        }
        
        if (button1.length) {
            [buttonTitles addObject:button1];
        }
        
        if (button2.length) {
            [buttonTitles addObject:button2];
        }
        
        NSMutableArray <NSString *> *textFieldPlaceholders = [NSMutableArray arrayWithCapacity:2];
        
        if (shadow0) {
            [textFieldPlaceholders addObject:shadow0];
        }
        
        if (shadow1) {
            [textFieldPlaceholders addObject:shadow1];
        }
        
        NSMutableArray <NSString *> *textFields = [NSMutableArray arrayWithCapacity:2];
        
        if (content0) {
            [textFields addObject:content0];
        }
        
        if (content1) {
            [textFields addObject:content1];
        }
        
        NSDictionary *replyDictionary = [[DeviceConfigurator sharedConfigurator] popAlertWithTimeout:timeoutInSeconds
                                                                                        messageTitle:(title ?: @"")
                                                                                      messageContent:(content ?: @"")
                                                                                        buttonTitles:buttonTitles
                                                                                          textFields:textFields
                                                                               textFieldPlaceholders:textFieldPlaceholders];
        
        int returnCount = 0;
        NSArray <NSString *> *inputStrings = replyDictionary[@"inputs"];
        if ([inputStrings isKindOfClass:[NSArray class]]) {
            if (inputStrings.count > 0) {
                lua_pushstring(L, [inputStrings[0] UTF8String]);
                returnCount++;
            }
            if (inputStrings.count > 1) {
                lua_pushstring(L, [inputStrings[1] UTF8String]);
                returnCount++;
            }
        }
        
        lua_pushinteger(L, [replyDictionary[@"choice"] integerValue]);
        returnCount++;
        
        return returnCount;
    }
}

static int DeviceConfigurator_System_AppSuspend(lua_State *L)
{
    @autoreleasepool {
        const char *cBundleIdentifier = luaL_checkstring(L, 1);
        NSString *bundleIdentifier = [NSString stringWithUTF8String:cBundleIdentifier];
        if ([bundleIdentifier isEqualToString:@"*"]) {
            [[DeviceConfigurator sharedConfigurator] removeAllAppLayouts];
        } else {
            [[DeviceConfigurator sharedConfigurator] removeAppLayoutsMatchingBundleIdentifier:bundleIdentifier];
        }
        return 0;
    }
}

static int DeviceConfigurator_System_GetLanguage(lua_State *L)
{
    @autoreleasepool {
        NSString *currentLanguage = [[DeviceConfigurator sharedConfigurator] currentLanguage];
        if (!currentLanguage)
        {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [currentLanguage UTF8String]);
        return 1;
    }
}

static int DeviceConfigurator_System_SetLanguage(lua_State *L)
{
    @autoreleasepool {
        const char *cLanguage = luaL_checkstring(L, 1);
        NSString *language = [NSString stringWithUTF8String:cLanguage];
        [[DeviceConfigurator sharedConfigurator] setCurrentLanguage:language];
        return 0;
    }
}

static int DeviceConfigurator_System_GetLocale(lua_State *L)
{
    @autoreleasepool {
        NSString *currentLocale = [[DeviceConfigurator sharedConfigurator] currentLocale];
        if (!currentLocale)
        {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [currentLocale UTF8String]);
        return 1;
    }
}

static int DeviceConfigurator_System_SetLocale(lua_State *L)
{
    @autoreleasepool {
        const char *cLocale = luaL_checkstring(L, 1);
        NSString *locale = [NSString stringWithUTF8String:cLocale];
        [[DeviceConfigurator sharedConfigurator] setCurrentLocale:locale];
        return 0;
    }
}

static int DeviceConfigurator_System_GetTimeZone(lua_State *L)
{
    @autoreleasepool {
        NSString *currentTimeZone = [[DeviceConfigurator sharedConfigurator] currentTimeZone];
        if (!currentTimeZone)
        {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [currentTimeZone UTF8String]);
        return 1;
    }
}

static int DeviceConfigurator_System_SetTimeZone(lua_State *L)
{
    @autoreleasepool {
        const char *cTimeZone = luaL_checkstring(L, 1);
        NSString *timeZone = [NSString stringWithUTF8String:cTimeZone];
        [[DeviceConfigurator sharedConfigurator] setCurrentTimeZone:timeZone];
        return 0;
    }
}

static int DeviceConfigurator_System_GetAppearance(lua_State *L)
{
    @autoreleasepool {
        lua_pushinteger(L, [[DeviceConfigurator sharedConfigurator] currentInterfaceStyle]);
        return 1;
    }
}

static int DeviceConfigurator_System_SetAppearance(lua_State *L)
{
    @autoreleasepool {
        lua_Integer cStyle = luaL_checkinteger(L, 1);
        [[DeviceConfigurator sharedConfigurator] setCurrentInterfaceStyle:(UIUserInterfaceStyle)cStyle];
        return 0;
    }
}

static int DeviceConfigurator_System_IsBoldTextOn(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] boldTextEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_System_SetBoldTextOn(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] setBoldTextEnabled:YES];
        return 0;
    }
}

static int DeviceConfigurator_System_SetBoldTextOff(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] setBoldTextEnabled:NO];
        return 0;
    }
}

static int DeviceConfigurator_System_IsZoomOn(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isZoomedMode]);
        return 1;
    }
}

static int DeviceConfigurator_System_SetZoomOn(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] setZoomedMode:YES];
        return 0;
    }
}

static int DeviceConfigurator_System_SetZoomOff(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] setZoomedMode:NO];
        return 0;
    }
}

static int DeviceConfigurator_System_GetTextSize(lua_State *L)
{
    @autoreleasepool {
        lua_pushinteger(L, [[DeviceConfigurator sharedConfigurator] dynamicTypeValue]);
        return 1;
    }
}

static int DeviceConfigurator_System_SetTextSize(lua_State *L)
{
    @autoreleasepool {
        lua_Integer cSizeLevel = luaL_checkinteger(L, 1);
        [[DeviceConfigurator sharedConfigurator] setDynamicTypeValue:(NSInteger)cSizeLevel];
        return 0;
    }
}


#pragma mark -

static int DeviceConfigurator_Device_ResetIdle(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] resetIdleTimer];
        return 0;
    }
}

static int DeviceConfigurator_Device_LockScreen(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] lockScreen];
        return 0;
    }
}

static int DeviceConfigurator_Device_UnlockScreen(lua_State *L)
{
    @autoreleasepool {
        const char *cPasscode = luaL_optstring(L, 1, "");
        NSString *passcode = [NSString stringWithUTF8String:cPasscode];
        
        [[DeviceConfigurator sharedConfigurator] unlockScreenWithPasscode:passcode];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsScreenLocked(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isScreenLocked]);
        return 1;
    }
}

static int DeviceConfigurator_Device_FrontOrientation(lua_State *L)
{
    @autoreleasepool {
        UIInterfaceOrientation orientation = (UIInterfaceOrientation)[[DeviceConfigurator sharedConfigurator] frontMostAppOrientation];
        switch (orientation) {
            case UIInterfaceOrientationUnknown:
                lua_pushinteger(L, 4);
                break;
            case UIInterfaceOrientationPortrait:
                lua_pushinteger(L, 0);
                break;
            case UIInterfaceOrientationPortraitUpsideDown:
                lua_pushinteger(L, 3);
                break;
            case UIInterfaceOrientationLandscapeLeft:
                lua_pushinteger(L, 2);
                break;
            case UIInterfaceOrientationLandscapeRight:
                lua_pushinteger(L, 1);
                break;
        }
        return 1;
    }
}

static int DeviceConfigurator_Device_LockOrientation(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] lockOrientation];
        return 0;
    }
}

static int DeviceConfigurator_Device_UnlockOrientation(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] unlockOrientation];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsOrientationLocked(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isOrientationLocked]);
        return 1;
    }
}

static int DeviceConfigurator_Device_Vibrator(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] vibrator];
        return 0;
    }
}

static int DeviceConfigurator_Device_PopBanner(lua_State *L)
{
    @autoreleasepool {
        const char *cBundleID = luaL_checkstring(L, 1);
        const char *cTitle = luaL_checkstring(L, 2);
        const char *cMessage = luaL_optstring(L, 3, "");
        
        NSString *bundleID = [NSString stringWithUTF8String:cBundleID];
        NSString *title = [NSString stringWithUTF8String:cTitle];
        NSString *message = [NSString stringWithUTF8String:cMessage];
        
        [[DeviceConfigurator sharedConfigurator] popBannerWithSectionID:bundleID
                                                           messageTitle:title
                                                        messageSubtitle:@""
                                                         messageContent:message];
        
        return 0;
    }
}

static int DeviceConfigurator_Device_Type(lua_State *L)
{
    struct utsname systemInfo;
    uname(&systemInfo);
    lua_pushstring(L, systemInfo.machine);
    return 1;
}

static int DeviceConfigurator_Device_Name(lua_State *L)
{
    @autoreleasepool {
        NSString *userAssignedDeviceName = [[DeviceConfigurator sharedConfigurator] userAssignedDeviceName];
        if (!userAssignedDeviceName.length)
        {
            id answer = CFBridgingRelease(MGCopyAnswer(kMGUserAssignedDeviceName, NULL));
            lua_pushNSValue(L, answer);
            return 1;
        }
        
        lua_pushstring(L, [userAssignedDeviceName UTF8String]);
        return 1;
    }
}

static int DeviceConfigurator_Device_SetName(lua_State *L)
{
    @autoreleasepool {
        size_t cNameLen;
        const char *cName = luaL_checklstring(L, 1, &cNameLen);
        if (sethostname(cName, (int)cNameLen)) {
            perror("sethostname");
            
            lua_pushboolean(L, false);
            return 1;
        }
        
        CFStringRef name = CFStringCreateWithBytesNoCopy(kCFAllocatorDefault, (const unsigned char *)cName, cNameLen, kCFStringEncodingUTF8, false, kCFAllocatorNull);
        int mgRet = MGSetAnswer(kMGUserAssignedDeviceName, name);
        CFRelease(name);
        
        if (!mgRet)
        {
            lua_pushboolean(L, mgRet);
            return 1;
        }
        
        [[DeviceConfigurator sharedConfigurator] setUserAssignedDeviceName:[NSString stringWithUTF8String:cName]];
        
        lua_pushboolean(L, true);
        return 1;
    }
}

static int DeviceConfigurator_Device_UDID(lua_State *L)
{
    id answer = CFBridgingRelease(MGCopyAnswer(kMGUniqueDeviceID, NULL));
    lua_pushNSValue(L, answer);
    return 1;
}

static int DeviceConfigurator_Device_SerialNumber(lua_State *L)
{
    id answer = CFBridgingRelease(MGCopyAnswer(kMGSerialNumber, NULL));
    lua_pushNSValue(L, answer);
    return 1;
}

static int DeviceConfigurator_Device_WifiMac(lua_State *L)
{
    id answer = CFBridgingRelease(MGCopyAnswer(kMGWifiAddress, NULL));
    lua_pushNSValue(L, answer);
    return 1;
}

static int DeviceConfigurator_Device_BluetoothMac(lua_State *L)
{
    id answer = CFBridgingRelease(MGCopyAnswer(kMGBluetoothAddress, NULL));
    lua_pushNSValue(L, answer);
    return 1;
}

static int DeviceConfigurator_Device_BatteryLevel(lua_State *L)
{
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    lua_pushnumber(L, [[UIDevice currentDevice] batteryLevel]);
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
    return 1;
}

static int DeviceConfigurator_Device_BatteryState(lua_State *L)
{
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    switch ([[UIDevice currentDevice] batteryState]) {
        case UIDeviceBatteryStateUnknown:
            lua_pushstring(L, "Unknown");
            break;
        case UIDeviceBatteryStateUnplugged:
            lua_pushstring(L, "Unplugged");
            break;
        case UIDeviceBatteryStateCharging:
            lua_pushstring(L, "Charging");
            break;
        case UIDeviceBatteryStateFull:
            lua_pushstring(L, "Full");
            break;
    }
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
    return 1;
}

static int DeviceConfigurator_Device_InterfaceMACAddresses(lua_State *L)
{
    @autoreleasepool {
        NSMutableArray <NSArray <NSString *> *> *macAddresses = [NSMutableArray array];
        
        char mac_addr[32];
        struct ifaddrs *addrs;
        struct ifaddrs *cursor;
        const struct sockaddr_dl *dl_addr;
        const unsigned char *base;
        int i, success;
        
        success = getifaddrs(&addrs) == 0;
        if (success) {
            cursor = addrs;
            while (cursor != NULL) {
                if ((cursor->ifa_addr->sa_family == AF_LINK) && (((const struct sockaddr_dl *)cursor->ifa_addr)->sdl_type == IFT_ETHER)) {
                    dl_addr = (const struct sockaddr_dl *)cursor->ifa_addr;
                    base = (const unsigned char *)&dl_addr->sdl_data[dl_addr->sdl_nlen];
                    bzero(mac_addr, 32);
                    char *ptr = mac_addr;
                    for (i = 0; i < dl_addr->sdl_alen; i++) {
                        if (i != 0) {
                            *ptr++ = ':';
                        }
                        snprintf(ptr, 3, "%02x", base[i]);
                        ptr += 2;
                    }
                    
                    NSString *ifaName = [NSString stringWithUTF8String:cursor->ifa_name];
                    NSString *macAddr = [NSString stringWithUTF8String:mac_addr];
                    [macAddresses addObject:@[ ifaName, macAddr ]];
                }
                cursor = cursor->ifa_next;
            }
        }
        
        freeifaddrs(addrs);
        lua_pushNSDictionary(L, macAddresses);
        return 1;
    }
}

static int DeviceConfigurator_Device_InterfaceIPAddresses(lua_State *L)
{
    @autoreleasepool {
        NSMutableArray <NSArray <NSString *> *> *ipAddresses = [NSMutableArray array];
        
        char ip_addr[INET6_ADDRSTRLEN];
        struct ifaddrs *addrs;
        struct ifaddrs *cursor;
        int success;
        
        success = getifaddrs(&addrs) == 0;
        if (success) {
            cursor = addrs;
            while (cursor != NULL) {
                
                NSString *ifaName = nil;
                if (cursor->ifa_addr->sa_family == AF_INET) {
                    bzero(ip_addr, INET6_ADDRSTRLEN);
                    getnameinfo(cursor->ifa_addr, sizeof(struct sockaddr_in), ip_addr, sizeof(ip_addr), NULL, 0, NI_NUMERICHOST);
                    ifaName = [NSString stringWithUTF8String:cursor->ifa_name];
                }
                else if (cursor->ifa_addr->sa_family == AF_INET6) {
                    bzero(ip_addr, INET6_ADDRSTRLEN);
                    getnameinfo(cursor->ifa_addr, sizeof(struct sockaddr_in6), ip_addr, sizeof(ip_addr), NULL, 0, NI_NUMERICHOST);
                    ifaName = [NSString stringWithFormat:@"%@/v6", [NSString stringWithUTF8String:cursor->ifa_name]];
                }
                
                if (ifaName) {
                    NSString *ipAddr = [NSString stringWithUTF8String:ip_addr];
                    [ipAddresses addObject:@[ ifaName, ipAddr ]];
                }
                
                cursor = cursor->ifa_next;
            }
        }
        
        freeifaddrs(addrs);
        lua_pushNSArray(L, ipAddresses);
        return 1;
    }
}

static int DeviceConfigurator_Device_TurnOnWiFi(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnWiFi];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffWiFi(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffWiFi];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsWiFiEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isWiFiEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_ScanWiFi(lua_State *L)
{
    @autoreleasepool {
        lua_Number cTimeout = luaL_optnumber(L, 1, 5000);
        cTimeout /= 1e3;
        
        DCUtilNetworksManager *netMgr = [DCUtilNetworksManager sharedInstance];
        
        [netMgr scanWithTimeout:MAX(cTimeout, 5.0)];
        CHDebugLogSource(@"%@", [netMgr prettyPrintNetworks]);
        
        NSMutableArray <NSArray <NSString *> *> *netList = [NSMutableArray array];
        for (DCUtilNetwork *network in [netMgr networks]) {
            if (!network.SSID.length) {
                continue;
            }
            [netList addObject:@[ ([network SSID] ?: @""), ([network BSSID] ?: @"") ]];
        }
        
        lua_pushNSArray(L, netList);
        return 1;
    }
}

static int DeviceConfigurator_Device_JoinWiFi(lua_State *L)
{
    @autoreleasepool {
        const char *cSSID = luaL_checkstring(L, 1);
        const char *cPassword = luaL_checkstring(L, 2);
        lua_Integer cEncType = luaL_optinteger(L, 3, 0);
        lua_Number cTimeout = luaL_optnumber(L, 4, 5000);
        cTimeout /= 1e3;
        
        NSString *ssid = [NSString stringWithUTF8String:cSSID];
        NSString *password = [NSString stringWithUTF8String:cPassword];
        if (password.length > 0) {
            cEncType = 1;
        } else {
            cEncType = 0;
        }
        
        DCUtilNetworksManager *netMgr = [DCUtilNetworksManager sharedInstance];
        
        [netMgr scanWithTimeout:MAX(cTimeout, 5.0)];
        CHDebugLogSource(@"%@", [netMgr prettyPrintNetworks]);
        
        DCUtilNetwork *network = [netMgr getNetworkWithSSID:ssid];
        BOOL succeed;
        if (cEncType == 0) {
            succeed = [netMgr associateWithNetwork:network Timeout:MAX(cTimeout, 5.0)];
        } else {
            succeed = [netMgr associateWithEncNetwork:network Password:password Timeout:MAX(cTimeout, 5.0)];
        }
        
        lua_pushboolean(L, succeed);
        return 1;
    }
}

static int DeviceConfigurator_Device_LeaveWiFi(lua_State *L)
{
    @autoreleasepool {
        [[DCUtilNetworksManager sharedInstance] disassociate];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOnData(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnCellular];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffData(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffCellular];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsDataEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isCellularEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_TurnOnBluetooth(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnBluetooth];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffBluetooth(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffBluetooth];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsBluetoothEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isBluetoothEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_TurnOnAirplane(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnAirplane];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffAirplane(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffAirplane];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsAirplaneEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isAirplaneEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_GetAirDropMode(lua_State *L)
{
    @autoreleasepool {
        lua_pushinteger(L, (lua_Integer)[[DeviceConfigurator sharedConfigurator] airDropDiscoveryMode]);
        return 1;
    }
}

static int DeviceConfigurator_Device_SetAirDropMode(lua_State *L)
{
    @autoreleasepool {
        lua_Integer cMode = luaL_checkinteger(L, 1);
        [[DeviceConfigurator sharedConfigurator] setAirDropDiscoveryMode:(NSInteger)cMode];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOnVPN(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnVPN];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffVPN(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffVPN];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsVPNEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isVPNEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_TurnOnFlash(lua_State *L)
{
    @autoreleasepool {
        lua_Number cLevel = luaL_optnumber(L, 1, 1.0);
        [[DeviceConfigurator sharedConfigurator] turnOnFlashWithLevel:MIN(MAX(cLevel, 0.1), 1.0)];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffFlash(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffFlash];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsFlashEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isFlashEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_TurnOnMute(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnRingerMute];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffMute(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffRingerMute];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsMuteEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isRingerMuteEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_SetVolume(lua_State *L)
{
    @autoreleasepool {
        lua_Number cVolume = luaL_checknumber(L, 1);
        [[DeviceConfigurator sharedConfigurator] setCurrentVolume:MIN(MAX(cVolume, 0.0), 1.0)];
        return 0;
    }
}

static int DeviceConfigurator_Device_Brightness(lua_State *L)
{
    @autoreleasepool {
        lua_pushnumber(L, [[DeviceConfigurator sharedConfigurator] backlightLevel]);
        return 1;
    }
}

static int DeviceConfigurator_Device_SetBrightness(lua_State *L)
{
    @autoreleasepool {
        lua_Number cBrightness = luaL_checknumber(L, 1);
        [[DeviceConfigurator sharedConfigurator] setBacklightLevel:MIN(MAX(cBrightness, 0.0), 1.0)];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOnAssistiveTouch(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnAssistiveTouch];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffAssistiveTouch(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffAssistiveTouch];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsAssistiveTouchEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isAssistiveTouchEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_TurnOnReduceMotion(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnReduceMotion];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffReduceMotion(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffReduceMotion];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsReduceMotionEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isReduceMotionEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_TurnOnRemoteInspector(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOnRemoteInspector];
        return 0;
    }
}

static int DeviceConfigurator_Device_TurnOffRemoteInspector(lua_State *L)
{
    @autoreleasepool {
        [[DeviceConfigurator sharedConfigurator] turnOffRemoteInspector];
        return 0;
    }
}

static int DeviceConfigurator_Device_IsRemoteInspectorEnabled(lua_State *L)
{
    @autoreleasepool {
        lua_pushboolean(L, [[DeviceConfigurator sharedConfigurator] isRemoteInspectorEnabled]);
        return 1;
    }
}

static int DeviceConfigurator_Device_SetAutoLockInMinutes(lua_State *L)
{
    @autoreleasepool {
        lua_Number altMins = luaL_checknumber(L, 1);
        if (altMins < 1e-3) {
            [[DeviceConfigurator sharedConfigurator] setAutoLockTimeInSeconds:-1];
        } else {
            [[DeviceConfigurator sharedConfigurator] setAutoLockTimeInSeconds:(NSTimeInterval)round(altMins * 60.0)];
        }
        return 0;
    }
}

static int DeviceConfigurator_Device_AutoLockInMinutes(lua_State *L)
{
    @autoreleasepool {
        NSTimeInterval altSecs = [[DeviceConfigurator sharedConfigurator] autoLockTimeInSeconds];
        if (altSecs < 0) {
            lua_pushnumber(L, -1);
        } else {
            lua_pushnumber(L, altSecs / 60.0);
        }
        return 1;
    }
}


#pragma mark -

static const luaL_Reg DeviceConfigurator_System_AuxLib[] = {
    
    /* Toast APIs */
    {"toast", DeviceConfigurator_System_Toast},
    {"toast_activity", DeviceConfigurator_System_ToastActivity},
    
    /* Version APIs */
    {"version", DeviceConfigurator_System_Version},
    {"xtversion", DeviceConfigurator_System_XXTVersion},
    
    /* MobileGestalt */
    {"mgcopyanswer", DeviceConfigurator_System_MGCopyAnswer},
    
    /* Time Utilities */
    {"mtime", DeviceConfigurator_System_TimeInMilliseconds},
    {"net_time", DeviceConfigurator_System_NetworkTime},
    {"sleep", DeviceConfigurator_System_StreamSleepInSeconds},
    {"msleep", DeviceConfigurator_System_StreamSleepInMilliseconds},
    
    /* Random Utilities */
    {"rnd", DeviceConfigurator_System_RealRandom},
    
    /* Memory Utilities */
    {"available_memory", DeviceConfigurator_System_AvailableMemory},
    {"total_memory", DeviceConfigurator_System_TotalMemory},
    {"xtmemory", DeviceConfigurator_System_XXTUsedMemory},
    
    /* Disk Utilities */
    {"disks", DeviceConfigurator_System_MountedVolumes},
    {"free_disk_space", DeviceConfigurator_System_FreeDiskSpace},
    {"total_disk_space", DeviceConfigurator_System_TotalDiskSpace},
    
    /* State */
    {"respring", DeviceConfigurator_System_Respring},
    {"reboot", DeviceConfigurator_System_Reboot},
    {"halt", DeviceConfigurator_System_Halt},
    {"ldrestart",  DeviceConfigurator_System_LDRestart},
    
    /* SpringBoard Alerts */
    {"alert", DeviceConfigurator_System_Alert},
    {"input_box", DeviceConfigurator_System_InputBox},
    
    /* App Switcher */
    {"suspend", DeviceConfigurator_System_AppSuspend},
    
    /* Language & Region */
    {"language", DeviceConfigurator_System_GetLanguage},
    {"set_language", DeviceConfigurator_System_SetLanguage},
    {"locale", DeviceConfigurator_System_GetLocale},
    {"set_locale", DeviceConfigurator_System_SetLocale},
    {"timezone", DeviceConfigurator_System_GetTimeZone},
    {"set_timezone", DeviceConfigurator_System_SetTimeZone},
    
    /* Appearance */
    {"appearance", DeviceConfigurator_System_GetAppearance},
    {"set_appearance", DeviceConfigurator_System_SetAppearance},
    {"textsize", DeviceConfigurator_System_GetTextSize},
    {"set_textsize", DeviceConfigurator_System_SetTextSize},
    {"is_boldtext_on", DeviceConfigurator_System_IsBoldTextOn},
    {"boldtext_on", DeviceConfigurator_System_SetBoldTextOn},
    {"boldtext_off", DeviceConfigurator_System_SetBoldTextOff},
    {"is_zoom_on", DeviceConfigurator_System_IsZoomOn},
    {"zoom_on", DeviceConfigurator_System_SetZoomOn},
    {"zoom_off", DeviceConfigurator_System_SetZoomOff},
    
    {NULL, NULL},
};


#pragma mark -

static const luaL_Reg DeviceConfigurator_Device_AuxLib[] = {
    
    /* Idle */
    {"reset_idle", DeviceConfigurator_Device_ResetIdle},
    {"set_autolock_time", DeviceConfigurator_Device_SetAutoLockInMinutes},
    {"autolock_time", DeviceConfigurator_Device_AutoLockInMinutes},
    
    /* Lock & Unlock */
    {"lock_screen", DeviceConfigurator_Device_LockScreen},
    {"unlock_screen", DeviceConfigurator_Device_UnlockScreen},
    {"is_screen_locked", DeviceConfigurator_Device_IsScreenLocked},
    
    /* Orientation */
    {"front_orien", DeviceConfigurator_Device_FrontOrientation},
    {"lock_orien", DeviceConfigurator_Device_LockOrientation},
    {"unlock_orien", DeviceConfigurator_Device_UnlockOrientation},
    {"is_orien_locked", DeviceConfigurator_Device_IsOrientationLocked},
    
    /* Feedback */
    {"vibrator", DeviceConfigurator_Device_Vibrator},
    {"pop_banner", DeviceConfigurator_Device_PopBanner},  // app.pop_banner
    
    /* Device Properties */
    {"type", DeviceConfigurator_Device_Type},
    {"name", DeviceConfigurator_Device_Name},
    {"set_name", DeviceConfigurator_Device_SetName},
    {"udid", DeviceConfigurator_Device_UDID},
    {"serial_number", DeviceConfigurator_Device_SerialNumber},
    {"wifi_mac", DeviceConfigurator_Device_WifiMac},
    {"bluetooth_mac", DeviceConfigurator_Device_BluetoothMac},
    {"battery_level", DeviceConfigurator_Device_BatteryLevel},
    {"battery_state", DeviceConfigurator_Device_BatteryState},
    {"ifaddrs", DeviceConfigurator_Device_InterfaceIPAddresses},
    {"macaddrs", DeviceConfigurator_Device_InterfaceMACAddresses},
    
    /* Wi-Fi */
    {"turn_on_wifi", DeviceConfigurator_Device_TurnOnWiFi},
    {"turn_off_wifi", DeviceConfigurator_Device_TurnOffWiFi},
    {"is_wifi_on", DeviceConfigurator_Device_IsWiFiEnabled},
    {"scan_wifi", DeviceConfigurator_Device_ScanWiFi},
    {"join_wifi", DeviceConfigurator_Device_JoinWiFi},
    {"leave_wifi", DeviceConfigurator_Device_LeaveWiFi},
    
    /* Cellular */
    {"turn_on_data", DeviceConfigurator_Device_TurnOnData},
    {"turn_off_data", DeviceConfigurator_Device_TurnOffData},
    {"is_data_on", DeviceConfigurator_Device_IsDataEnabled},
    
    /* Bluetooth */
    {"turn_on_bluetooth", DeviceConfigurator_Device_TurnOnBluetooth},
    {"turn_off_bluetooth", DeviceConfigurator_Device_TurnOffBluetooth},
    {"is_bluetooth_on", DeviceConfigurator_Device_IsBluetoothEnabled},
    
    /* Airplane */
    {"turn_on_airplane", DeviceConfigurator_Device_TurnOnAirplane},
    {"turn_off_airplane", DeviceConfigurator_Device_TurnOffAirplane},
    {"is_airplane_on", DeviceConfigurator_Device_IsAirplaneEnabled},
    
    /* AirDrop */
    {"airdrop_mode", DeviceConfigurator_Device_GetAirDropMode},
    {"set_airdrop_mode", DeviceConfigurator_Device_SetAirDropMode},
    
    /* VPN */
    {"turn_on_vpn", DeviceConfigurator_Device_TurnOnVPN},
    {"turn_off_vpn", DeviceConfigurator_Device_TurnOffVPN},
    {"is_vpn_on", DeviceConfigurator_Device_IsVPNEnabled},
    
    /* Flash */
    {"flash_on", DeviceConfigurator_Device_TurnOnFlash},
    {"flash_off", DeviceConfigurator_Device_TurnOffFlash},
    {"is_flash_on", DeviceConfigurator_Device_IsFlashEnabled},
    
    /* Volume */
    /// TODO: get volume, play sound
    {"set_volume", DeviceConfigurator_Device_SetVolume},
    {"mute_on", DeviceConfigurator_Device_TurnOnMute},
    {"mute_off", DeviceConfigurator_Device_TurnOffMute},
    {"is_mute_on", DeviceConfigurator_Device_IsMuteEnabled},
    
    /* Backlight */
    {"brightness", DeviceConfigurator_Device_Brightness},
    {"set_brightness", DeviceConfigurator_Device_SetBrightness},
    
    /* Assistive Touch */
    {"assistive_touch_on", DeviceConfigurator_Device_TurnOnAssistiveTouch},
    {"assistive_touch_off", DeviceConfigurator_Device_TurnOffAssistiveTouch},
    {"is_assistive_touch_on", DeviceConfigurator_Device_IsAssistiveTouchEnabled},
    
    /* Reduce Motion */
    {"reduce_motion_on", DeviceConfigurator_Device_TurnOnReduceMotion},
    {"reduce_motion_off", DeviceConfigurator_Device_TurnOffReduceMotion},
    {"is_reduce_motion_on", DeviceConfigurator_Device_IsReduceMotionEnabled},
    
    /* Safari Remote Inspector */
    {"remote_inspector_on", DeviceConfigurator_Device_TurnOnRemoteInspector},        // monkey.remote_inspector_on
    {"remote_inspector_off", DeviceConfigurator_Device_TurnOffRemoteInspector},      // monkey.remote_inspector_off
    {"is_remote_inspector_on", DeviceConfigurator_Device_IsRemoteInspectorEnabled},  // monkey.is_remote_inspector_on
    
    {NULL, NULL},
};


#pragma mark -

XXTouchF_CAPI int luaopen_sys(lua_State *L)
{
    lua_createtable(L, 0, (sizeof(DeviceConfigurator_System_AuxLib) / sizeof((DeviceConfigurator_System_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, DeviceConfigurator_System_AuxLib, 0);
    
    return 1;
}

XXTouchF_CAPI int luaopen_device(lua_State *L)
{
    lua_createtable(L, 0, (sizeof(DeviceConfigurator_Device_AuxLib) / sizeof((DeviceConfigurator_Device_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, DeviceConfigurator_Device_AuxLib, 0);
    
    return 1;
}

XXTouchF_CAPI int luaopen_exsys(lua_State *L)
{
    return luaopen_sys(L);
}

XXTouchF_CAPI int luaopen_exdevice(lua_State *L)
{
    return luaopen_device(L);
}
