#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <UIKit/UIKit.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <pthread.h>
#import <notify.h>
#import <Foundation/NSUserDefaults+Private.h>
#import <rocketbootstrap/rocketbootstrap.h>

#import "AMR_ANSIEscapeHelper.h"
#import "UIApplicationRotationFollowingWindow.h"
#import "PassWindow.h"
#import "GeneratedTouchesDebugWindow+Private.h"

#define LOG_FIFO "/private/var/tmp/ch.xxtou.DebugWindow.FIFO"


GeneratedTouchesDebugWindow *_touchesDebugWindow = nil;
PassWindow *_sharedDebugWindow = nil;
UILabel *_sharedDebugLabel = nil;

static AMR_ANSIEscapeHelper *_colorHelper = nil;
static void _createDebugWindow() {
    if (!_sharedDebugWindow) {

        CGSize screenSize = [[UIScreen mainScreen] bounds].size;
        CGSize windowSize = CGSizeMake(screenSize.width, screenSize.height);
        CGRect windowFrame = CGRectMake(0, 0, windowSize.width, windowSize.height);

        _sharedDebugWindow = [[PassWindow alloc] _initWithFrame:CGRectZero attached:NO];

        [_sharedDebugWindow commonInit];
        [_sharedDebugWindow setupOrientation:UIInterfaceOrientationPortrait];
        [_sharedDebugWindow setWindowLevel:UIWindowLevelStatusBar + 1];
        [_sharedDebugWindow setFrame:windowFrame];
        [_sharedDebugWindow setBackgroundColor:[UIColor clearColor]];
        [_sharedDebugWindow setUserInteractionEnabled:NO];

        CGFloat topMargin = MAX(_sharedDebugWindow.safeAreaInsets.top - 16.f, 0);
        CGRect firstLineRect = CGRectMake(0, topMargin, windowSize.width, CGFLOAT_MAX);
        UILabel *firstLineLabel = [[UILabel alloc] initWithFrame:firstLineRect];
        firstLineLabel.translatesAutoresizingMaskIntoConstraints = NO;
        firstLineLabel.userInteractionEnabled = NO;
        firstLineLabel.backgroundColor = [UIColor blackColor];
        firstLineLabel.textAlignment = NSTextAlignmentCenter;
        firstLineLabel.textColor = [UIColor whiteColor];
        firstLineLabel.font = [UIFont boldSystemFontOfSize:13.0];
        firstLineLabel.numberOfLines = 1;
        firstLineLabel.text = @"Import `exlog` module, and use `LOG` to print logs here.";
        firstLineLabel.lineBreakMode = NSLineBreakByTruncatingHead;
        [firstLineLabel sizeToFit];
        [_sharedDebugWindow addSubview:firstLineLabel];

        firstLineRect = CGRectMake(0, topMargin, windowSize.width, firstLineLabel.bounds.size.height);
        firstLineLabel.frame = firstLineRect;
        _sharedDebugLabel = firstLineLabel;

        _colorHelper = [AMR_ANSIEscapeHelper new];
        _colorHelper.defaultStringColor = [UIColor whiteColor];
        _colorHelper.font = [UIFont boldSystemFontOfSize:13.0];
    }
}

static NSString * const kDWDefaultsLocation = @"/private/var/mobile/Library/Preferences/ch.xxtou.DebugWindow.plist";
static NSString * const kDWDefaultsDomainString = @"ch.xxtou.DebugWindow";
static NSString * const kDWDefaultsNotificationName = @"ch.xxtou.notification.debugwindow.defaults-changed";

static BOOL enabled = YES;
static pthread_mutex_t _logLock;

static void _notificationCallback(NSNumber *enabledValue, NSString *backgroundColorValue)
{
    @autoreleasepool {
        CHDebugLogSource(@"enabled = %@, backgroundColor = %@", enabledValue, backgroundColorValue);

        if (!enabledValue) {
            NSDictionary *debugConf = [NSDictionary dictionaryWithContentsOfFile:kDWDefaultsLocation];
            if ([debugConf[@"enabled"] isKindOfClass:[NSNumber class]]) {
                enabledValue = debugConf[@"enabled"];
            }
            if ([debugConf[@"backgroundColor"] isKindOfClass:[NSString class]]) {
                backgroundColorValue = debugConf[@"backgroundColor"];
            }
        }

        enabled = [enabledValue boolValue];

        if (enabled) {
            [_sharedDebugWindow setHidden:NO];
        } else {
            [_sharedDebugWindow setHidden:YES];
        }

        [_touchesDebugWindow setShouldShowTouches:enabled];

        if ([backgroundColorValue hasPrefix:@"#"]) {
            [_touchesDebugWindow setLogBarColorInHexString:backgroundColorValue];
        }

        static NSFileHandle *readHandle = nil;
        if (enabled) {
            [readHandle closeFile];
            readHandle = nil;
            
            unlink(LOG_FIFO);
            if (0 == mkfifo(LOG_FIFO, 0644))
            {
                int logfd = open(LOG_FIFO, O_RDONLY | O_NONBLOCK);
                if (logfd != -1)
                {
                    readHandle = [[NSFileHandle alloc] initWithFileDescriptor:logfd closeOnDealloc:YES];
                    [readHandle setReadabilityHandler:^(NSFileHandle *file) {
                        @autoreleasepool {
                            NSData *receivedData = [file availableData];
                            NSString *receivedString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
                            if (receivedString) {
                                dispatch_sync(dispatch_get_main_queue(), ^{
                                    [_sharedDebugLabel setAttributedText:[_colorHelper attributedStringWithANSIEscapedString:receivedString]];
                                });
                            }
                        }
                    }];
                }
            }
        } else {
            [readHandle closeFile];
            readHandle = nil;
        }
    }
}

static void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    @autoreleasepool {
        NSNumber *enabledValue = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:kDWDefaultsDomainString];
        NSString *backgroundColorValue = (NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"backgroundColor" inDomain:kDWDefaultsDomainString];
        _notificationCallback(enabledValue, backgroundColorValue);
    }
}

%group DebugWindow

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    _createDebugWindow();
    notificationCallback(NULL, NULL, NULL, NULL, NULL);
    %orig;
}

%end

%end


%ctor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] arguments][0];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];

        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"])
        {   /* Server Process - DebugWindow */

            rocketbootstrap_unlock(XPC_INSTANCE_NAME);
            
            CPDistributedMessagingCenter *serverMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(serverMessagingCenter);
            [serverMessagingCenter runServerOnCurrentThread];
            
            GeneratedTouchesDebugWindow *serverInstance = [GeneratedTouchesDebugWindow sharedGeneratedTouchesDebugWindowWithRole:GeneratedTouchesDebugWindowRoleServer];
            [serverMessagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
            [serverInstance setMessagingCenter:serverMessagingCenter];
            
            CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", serverMessagingCenter, bundleIdentifier, processName, getpid());
            _touchesDebugWindow = serverInstance;

            pthread_mutex_init(&_logLock, NULL);
            notificationCallback(NULL, NULL, NULL, NULL, NULL);
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, notificationCallback, (CFStringRef)kDWDefaultsNotificationName, NULL, CFNotificationSuspensionBehaviorCoalesce);

            %init(DebugWindow);
        }
        else if (
            [processName isEqualToString:@"simulatetouchd"] || [processName hasSuffix:@"/simulatetouchd"]
            || [processName isEqualToString:@"lua"] || [processName hasSuffix:@"/lua"]
        ) {   /* Client Process - DebugWindow */

            CPDistributedMessagingCenter *debugMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
            rocketbootstrap_distributedmessagingcenter_apply(debugMessagingCenter);
            
            GeneratedTouchesDebugWindow *clientInstance = [GeneratedTouchesDebugWindow sharedGeneratedTouchesDebugWindow];
            [clientInstance setMessagingCenter:debugMessagingCenter];
            
            CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", debugMessagingCenter, bundleIdentifier, processName, getpid());
            _touchesDebugWindow = clientInstance;
        }
    }
}
