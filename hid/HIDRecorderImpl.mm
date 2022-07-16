/**
 * This is a HID event recorder only for UI debugging purpose,
 * for a more complicated example used in IDE, see hidrecorder.m
 */

#import "IOKitSPI.h"
#import "ProcQueue.h"
#import "Supervisor.h"
#import "DeviceConfigurator.h"

#import <notify.h>
#import <rocketbootstrap/rocketbootstrap.h>

#import "HIDRecorderEnums.h"


#pragma mark - Types

static HIDRecorderOperation _recorderClickVolumeUpOperation = HIDRecorderOperationNone;
static HIDRecorderOperation _recorderClickVolumeDownOperation = HIDRecorderOperationNone;
static HIDRecorderOperation _recorderHoldVolumeUpOperation = HIDRecorderOperationNone;
static HIDRecorderOperation _recorderHoldVolumeDownOperation = HIDRecorderOperationNone;
static BOOL __HIDRecorderIsPresentingAlert = NO;

static BOOL _recorderStartupScriptEnabled = NO;
static NSString *_recorderStartupScriptName = nil;
static __weak UIWindow *_recorderPresentingWindow = nil;

OBJC_EXTERN BOOL _recorderInsomniaModeEnabled = NO;


#pragma mark - Localizations

static NSString *HIDLocalizedString(NSString *string)
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray <NSString *> *languages = [defs objectForKey:@"AppleLanguages"];
    NSString *dLanguage = [languages objectAtIndex:0];
    
    if ([dLanguage isEqualToString:@"zh-Hans"] || [dLanguage isEqualToString:@"zh-Hans-CN"]) {
        if ([string isEqualToString:@"STATUS_NOT_RUNNING"]) {
            return @"状态：未运行任何任务\n";
        } else if ([string isEqualToString:@"STATUS_RUNNING"]) {
            return @"状态：运行脚本中…\n";
        } else if ([string isEqualToString:@"STATUS_RECORDING"]) {
            return @"状态：录制事件中…\n";
        } else if ([string isEqualToString:@"STATUS_SUSPENDED"]) {
            return @"状态：脚本暂停中…\n";
        } else if ([string isEqualToString:@"CONFIRM_WILL_LAUNCH_SELECTED_SCRIPT"]) {
            return @"即将运行选中的脚本：“%@”，是否继续？";
        } else if ([string isEqualToString:@"CONFIRM_WILL_BEGIN_EVENT_RECORDING"]) {
            return @"即将开始录制系统事件，是否继续？";
        } else if ([string isEqualToString:@"CHOOSE_AN_OPTION_BELOW_TO_CONTINUE"]) {
            return @"请选择一个选项以继续。";
        } else if ([string isEqualToString:@"CANCEL"]) {
            return @"取消";
        } else if ([string isEqualToString:@"DISMISS"]) {
            return @"忽略";
        } else if ([string isEqualToString:@"BTN_LAUNCH"]) {
            return @"▶️ 运行脚本";
        } else if ([string isEqualToString:@"BTN_RECORD"]) {
            return @"⏺ 开始录制";
        } else if ([string isEqualToString:@"BTN_CONTINUE"]) {
            return @"⏯ 继续运行";
        } else if ([string isEqualToString:@"BTN_STOP"]) {
            return @"⏹ 停止运行";
        } else if ([string isEqualToString:@"BTN_PAUSE"]) {
            return @"⏸ 暂停运行";
        } else if ([string isEqualToString:@"SHOW_IN_XXT"]) {
            return @"在 X.X.T. 中显示";
        } else if ([string isEqualToString:@"RUNTIME_ERROR"]) {
            return @"运行时错误";
        } else if ([string isEqualToString:@"SYNTAX_ERROR"]) {
            return @"语法错误";
        } else if ([string isEqualToString:@"INTERNAL_SERVER_ERROR"]) {
            return @"内部服务器错误";
        } else if ([string isEqualToString:@"SERVICE_UNAVAILABLE"]) {
            return @"服务不可用";
        } else if ([string isEqualToString:@"RECORDING_SAVED"]) {
            return @"录制结果保存于：%@";
        }
    }
    
    if ([string isEqualToString:@"STATUS_NOT_RUNNING"]) {
        return @"Status: Not Running\n";
    } else if ([string isEqualToString:@"STATUS_RUNNING"]) {
        return @"Status: Running…\n";
    } else if ([string isEqualToString:@"STATUS_RECORDING"]) {
        return @"Status: Recording…\n";
    } else if ([string isEqualToString:@"STATUS_SUSPENDED"]) {
        return @"Status: Suspended…\n";
    } else if ([string isEqualToString:@"CONFIRM_WILL_LAUNCH_SELECTED_SCRIPT"]) {
        return @"Will launch selected script: “%@”, continue?";
    } else if ([string isEqualToString:@"CONFIRM_WILL_BEGIN_EVENT_RECORDING"]) {
        return @"Will begin event recording, continue?";
    } else if ([string isEqualToString:@"CHOOSE_AN_OPTION_BELOW_TO_CONTINUE"]) {
        return @"Choose an option below to continue.";
    } else if ([string isEqualToString:@"CANCEL"]) {
        return @"Cancel";
    } else if ([string isEqualToString:@"DISMISS"]) {
        return @"Dismiss";
    } else if ([string isEqualToString:@"BTN_LAUNCH"]) {
        return @"▶️ Launch";
    } else if ([string isEqualToString:@"BTN_RECORD"]) {
        return @"⏺ Record";
    } else if ([string isEqualToString:@"BTN_CONTINUE"]) {
        return @"⏯ Continue";
    } else if ([string isEqualToString:@"BTN_STOP"]) {
        return @"⏹ Stop";
    } else if ([string isEqualToString:@"BTN_PAUSE"]) {
        return @"⏸ Pause";
    } else if ([string isEqualToString:@"SHOW_IN_XXT"]) {
        return @"Show in X.X.T.";
    } else if ([string isEqualToString:@"RUNTIME_ERROR"]) {
        return @"Runtime Error";
    } else if ([string isEqualToString:@"SYNTAX_ERROR"]) {
        return @"Syntax Error";
    } else if ([string isEqualToString:@"INTERNAL_SERVER_ERROR"]) {
        return @"Internal Server Error";
    } else if ([string isEqualToString:@"SERVICE_UNAVAILABLE"]) {
        return @"Service Unavailable";
    } else if ([string isEqualToString:@"RECORDING_SAVED"]) {
        return @"Recording saved at: %@";
    }
    
    return string;
}


#pragma mark - C Interfaces

OBJC_EXTERN
void __HIDRecorderPerformAction(HIDRecorderAction action);

OBJC_EXTERN
void __HIDRecorderPerformOperation(HIDRecorderOperation operation);

OBJC_EXTERN
void __HIDRecorderPerformAlertConfirm(HIDRecorderOperation afterOperation, SupervisorState runningState);

OBJC_EXTERN
void __HIDRecorderDisplayAlertMessage(NSString *alertMessage, SupervisorState runningState);

OBJC_EXTERN
void __HIDRecorderDisplayErrorMessage(NSString *alertTitle, NSString *alertContent);

OBJC_EXTERN
void __HIDRecorderDismissAlertConfirm(void);

static
void __HIDRecorderDismissAlertConfirmInternal(UIWindow *presentWindow, SupervisorState runningState);

OBJC_EXTERN
BOOL HIDRecorderHandleHIDEvent(IOHIDEventRef event);

OBJC_EXTERN
int SBSOpenSensitiveURLAndUnlock(CFURLRef url, char flags);


#pragma mark - User Defaults

static NSTimer *_startupTimer = nil;

@interface ProcQueue (Notification)
- (void)remoteDefaultsChanged;
@end
@implementation ProcQueue (Notification)
- (void)remoteDefaultsChanged
{
    @autoreleasepool {
        
        NSDictionary *defaults = [self unsafeDefaultsDictionary];
        if (![defaults isKindOfClass:[NSDictionary class]]) {
            return;  // remote defaults not ready, abort.
        }
        
        BOOL shouldToggle = YES;
        {
            NSDictionary *userDefaults = [defaults objectForKey:@"ch.xxtou.defaults.user"];
            if ([userDefaults isKindOfClass:[NSDictionary class]]) {
                BOOL deviceControlToggle = [[userDefaults objectForKey:@"device_control_toggle"] boolValue];
                if (!deviceControlToggle) {
                    shouldToggle = NO;
                    
                    _recorderHoldVolumeUpOperation = HIDRecorderOperationNone;
                    _recorderHoldVolumeDownOperation = HIDRecorderOperationNone;
                    _recorderClickVolumeUpOperation = HIDRecorderOperationNone;
                    _recorderClickVolumeDownOperation = HIDRecorderOperationNone;
                }
                
                _recorderInsomniaModeEnabled = [[userDefaults objectForKey:@"no_idle"] boolValue];
            }
        }
        
        if (shouldToggle) {
            NSDictionary *playDefaults = [defaults objectForKey:@"ch.xxtou.defaults.action"];
            if ([playDefaults isKindOfClass:[NSDictionary class]])
            {
                int holdVolumeUp = [[playDefaults objectForKey:@"hold_volume_up"] intValue];
                int holdVolumeDown = [[playDefaults objectForKey:@"hold_volume_down"] intValue];
                int clickVolumeUp = [[playDefaults objectForKey:@"click_volume_up"] intValue];
                int clickVolumeDown = [[playDefaults objectForKey:@"click_volume_down"] intValue];
                
                if (holdVolumeUp == 0) {
                    _recorderHoldVolumeUpOperation = HIDRecorderOperationBothWithAlert;
                } else if (holdVolumeUp == 1) {
                    _recorderHoldVolumeUpOperation = HIDRecorderOperationPlay;
                } else if (holdVolumeUp == 2) {
                    _recorderHoldVolumeUpOperation = HIDRecorderOperationNone;
                }
                
                if (holdVolumeDown == 0) {
                    _recorderHoldVolumeDownOperation = HIDRecorderOperationBothWithAlert;
                } else if (holdVolumeDown == 1) {
                    _recorderHoldVolumeDownOperation = HIDRecorderOperationPlay;
                } else if (holdVolumeDown == 2) {
                    _recorderHoldVolumeDownOperation = HIDRecorderOperationNone;
                }
                
                if (clickVolumeUp == 0) {
                    _recorderClickVolumeUpOperation = HIDRecorderOperationBothWithAlert;
                } else if (clickVolumeUp == 1) {
                    _recorderClickVolumeUpOperation = HIDRecorderOperationPlay;
                } else if (clickVolumeUp == 2) {
                    _recorderClickVolumeUpOperation = HIDRecorderOperationNone;
                }
                
                if (clickVolumeDown == 0) {
                    _recorderClickVolumeDownOperation = HIDRecorderOperationBothWithAlert;
                } else if (clickVolumeDown == 1) {
                    _recorderClickVolumeDownOperation = HIDRecorderOperationPlay;
                } else if (clickVolumeDown == 2) {
                    _recorderClickVolumeDownOperation = HIDRecorderOperationNone;
                }
            }
        }
        
        {
            NSDictionary *startupDefaults = [defaults objectForKey:@"ch.xxtou.defaults.startup"];
            if ([startupDefaults isKindOfClass:[NSDictionary class]])
            {
                _recorderStartupScriptEnabled = [[startupDefaults objectForKey:@"startup_run"] boolValue];
                _recorderStartupScriptName = [startupDefaults objectForKey:@"startup_script"];
                if (![_recorderStartupScriptName isKindOfClass:[NSString class]]) {
                    _recorderStartupScriptName = nil;
                }
            }
        }
        
        CHDebugLogSource(@"defaults initialized %@", @{
            @"_recorderClickVolumeUpOperation": @(_recorderClickVolumeUpOperation),
            @"_recorderClickVolumeDownOperation": @(_recorderClickVolumeDownOperation),
            @"_recorderHoldVolumeUpOperation": @(_recorderHoldVolumeUpOperation),
            @"_recorderHoldVolumeDownOperation": @(_recorderHoldVolumeDownOperation),
            @"_recorderStartupScriptEnabled": @(_recorderStartupScriptEnabled),
            @"_recorderStartupScriptName": _recorderStartupScriptName ?: @"(null)",
            @"_recorderInsomniaModeEnabled": @(_recorderInsomniaModeEnabled),
        });
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            
            /// Startup Script
            if (_recorderStartupScriptEnabled && _recorderStartupScriptName.length > 0)
            {
                static NSString *startupFlagName = @"/private/var/tmp/ch.xxtou.flag.hid.first-launch";
                NSFileManager *fileMgr = [NSFileManager defaultManager];
                if (![fileMgr fileExistsAtPath:startupFlagName])
                {
                    BOOL created = [fileMgr createFileAtPath:startupFlagName
                                                    contents:[NSData data]
                                                  attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }];
                    if (created)
                    {
                        NSString *startupScriptName = _recorderStartupScriptName;
                        _startupTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
                            if ([[Supervisor sharedInstance] isIdle])
                            {
                                NSError *startupErr = nil;
                                BOOL started = [[Supervisor sharedInstance] launchScriptWithName:startupScriptName additionalEnvironmentVariables:@{
                                    @"XXT_ENTRYTYPE": @"startup",
                                } error:&startupErr];
                                if (!started)
                                {
                                    CHLog(@"startup error %@", startupErr);
                                }
                            }
                        }];
                    }
                }
            }
        });
    }
}
@end


#pragma mark - HID Handler Implementations

void __HIDRecorderPerformAction(HIDRecorderAction action)
{
    @autoreleasepool {
        CHDebugLogSource(@"action %lu", (unsigned long)action);
        
        SupervisorState runningState = [[Supervisor sharedInstance] globalState];
        
        switch (action) {
            case HIDRecorderActionNone:
                break;
            case HIDRecorderActionLaunch:
            {
                if (runningState == SupervisorStateIdle)
                {
                    NSError *launchErr = nil;
                    BOOL launched = [[Supervisor sharedInstance] launchSelectedScriptWithAdditionalEnvironmentVariables:@{
                        @"XXT_ENTRYTYPE": @"volume",
                    } error:&launchErr];
                    if (!launched) {
                        __HIDRecorderDisplayErrorMessage([launchErr localizedDescription], [launchErr localizedFailureReason]);
                    }
                    break;
                }
            }
            case HIDRecorderActionRecord:
            {
                if (runningState == SupervisorStateIdle)
                {
                    NSError *recordErr = nil;
                    BOOL recorded = [[Supervisor sharedInstance] beginRecordingAtDefaultPathWithError:&recordErr];
                    if (!recorded) {
                        __HIDRecorderDisplayErrorMessage([recordErr localizedDescription], [recordErr localizedFailureReason]);
                    }
                    break;
                }
            }
            case HIDRecorderActionStop:
            {
                if (runningState != SupervisorStateIdle)
                {
                    NSString *replyPath = nil;
                    if (runningState == SupervisorStateRecording)
                        replyPath = [[Supervisor sharedInstance] endRecording];
                    else
                        replyPath = [[Supervisor sharedInstance] endPlaying];
                    
                    if (replyPath != nil && runningState == SupervisorStateRecording)
                    {
                        if ([replyPath hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"]) {
                            replyPath = [replyPath substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                        }
                        __HIDRecorderDisplayAlertMessage([NSString stringWithFormat:HIDLocalizedString(@"RECORDING_SAVED"), replyPath], runningState);
                    }
                    break;
                }
            }
            case HIDRecorderActionPause:
            {
                [[Supervisor sharedInstance] pausePlaying];
                break;
            }
            case HIDRecorderActionContinue:
            {
                [[Supervisor sharedInstance] continuePlaying];
                break;
            }
        }
    }
}

void __HIDRecorderPerformAlertConfirm(HIDRecorderOperation afterOperation, SupervisorState runningState)
{
    @autoreleasepool {
        NSCAssert([NSThread isMainThread], @"not main thread");
        NSCAssert(afterOperation != HIDRecorderOperationNone &&
                  afterOperation != HIDRecorderOperationPlayWithAlert &&
                  afterOperation != HIDRecorderOperationRecordWithAlert &&
                  afterOperation != HIDRecorderOperationBothWithAlert, @"invalid operation");
        
        // dismiss script message
        notify_post(NOTIFY_DISMISSAL_SYS_ALERT);
        
        // get selected script name
        NSString *selectedScript = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.selected-script"];
        
        // present alert
        dispatch_async(dispatch_get_main_queue(), ^{
            
            @autoreleasepool {
                
                if (__HIDRecorderIsPresentingAlert)
                    return;
                
                NSMutableString *alertMessage = [NSMutableString string];
                if (runningState == SupervisorStateIdle) {
                    [alertMessage appendString:HIDLocalizedString(@"STATUS_NOT_RUNNING")];
                    if (afterOperation == HIDRecorderOperationPlay) {
                        [alertMessage appendFormat:HIDLocalizedString(@"CONFIRM_WILL_LAUNCH_SELECTED_SCRIPT"), selectedScript];
                    } else if (afterOperation == HIDRecorderOperationRecord) {
                        [alertMessage appendString:HIDLocalizedString(@"CONFIRM_WILL_BEGIN_EVENT_RECORDING")];
                    } else {
                        [alertMessage appendString:HIDLocalizedString(@"CHOOSE_AN_OPTION_BELOW_TO_CONTINUE")];
                    }
                } else {
                    if (runningState == SupervisorStateRunning) {
                        [alertMessage appendString:HIDLocalizedString(@"STATUS_RUNNING")];
                    } else if (runningState == SupervisorStateRecording) {
                        [alertMessage appendString:HIDLocalizedString(@"STATUS_RECORDING")];
                    } else if (runningState == SupervisorStateSuspend) {
                        [alertMessage appendString:HIDLocalizedString(@"STATUS_SUSPENDED")];
                    }
                    [alertMessage appendString:HIDLocalizedString(@"CHOOSE_AN_OPTION_BELOW_TO_CONTINUE")];
                }
                
                UIViewController *presentController = [[UIViewController alloc] init];
                UIWindow *presentWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
                [presentWindow setRootViewController:presentController];
                [presentWindow setWindowLevel:UIWindowLevelStatusBar + 1];
                [presentWindow setHidden:NO];
                
                _recorderPresentingWindow = presentWindow;
                
                UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:HIDLocalizedString(@"XXTouch")
                                                                                   message:alertMessage
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                
                [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"CANCEL") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    CHDebugLogSource(@"Operation cancelled");
                    __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                }]];
                
                if (runningState == SupervisorStateIdle) {
                    if (afterOperation == HIDRecorderOperationBoth) {
                        [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"BTN_LAUNCH") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            __HIDRecorderPerformAction(HIDRecorderActionLaunch);
                            __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                        }]];
                        
                        [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"BTN_RECORD") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            __HIDRecorderPerformAction(HIDRecorderActionRecord);
                            __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                        }]];
                    } else {
                        [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"BTN_CONTINUE") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            
                            if (afterOperation == HIDRecorderOperationPlay) {
                                __HIDRecorderPerformAction(HIDRecorderActionLaunch);
                            } else {
                                __HIDRecorderPerformAction(HIDRecorderActionRecord);
                            }
                            
                            __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                        }]];
                    }
                } else {
                    if (runningState == SupervisorStateRecording) {
                        [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"BTN_STOP") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            __HIDRecorderPerformAction(HIDRecorderActionStop);
                            __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                        }]];
                    } else {
                        if (runningState == SupervisorStateRunning) {
                            [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"BTN_PAUSE") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                __HIDRecorderPerformAction(HIDRecorderActionPause);
                                __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                            }]];
                        } else if (runningState == SupervisorStateSuspend) {
                            [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"BTN_CONTINUE") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                __HIDRecorderPerformAction(HIDRecorderActionContinue);
                                __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                            }]];
                        }
                        
                        [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"BTN_STOP") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            __HIDRecorderPerformAction(HIDRecorderActionStop);
                            __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                        }]];
                    }
                }
                
                __HIDRecorderIsPresentingAlert = YES;
                if (runningState == SupervisorStateRecording)
                    [[Supervisor sharedInstance] sendSignalToGlobalProcess:SIGUSR1];
                
                [presentController presentViewController:alertCtrl animated:YES completion:nil];
            }
        });
    }
}

void __HIDRecorderDisplayAlertMessage(NSString *alertMessage, SupervisorState runningState)
{
    @autoreleasepool {
        NSCAssert([NSThread isMainThread], @"not main thread");
        NSCParameterAssert([alertMessage isKindOfClass:[NSString class]]);
        
        // dismiss script message
        notify_post(NOTIFY_DISMISSAL_SYS_ALERT);
        
        // present alert
        dispatch_async(dispatch_get_main_queue(), ^{

            @autoreleasepool {
                
                if (__HIDRecorderIsPresentingAlert)
                    return;
                
                UIViewController *presentController = [[UIViewController alloc] init];
                UIWindow *presentWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
                [presentWindow setRootViewController:presentController];
                [presentWindow setWindowLevel:UIWindowLevelStatusBar + 1];
                [presentWindow setHidden:NO];
                
                _recorderPresentingWindow = presentWindow;
                
                UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:HIDLocalizedString(@"XXTouch")
                                                                                   message:alertMessage
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                
                [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"DISMISS") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                }]];
                
                if (runningState != SupervisorStateIdle) {
                    [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"SHOW_IN_XXT") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"xxt://"] options:@{} completionHandler:^(BOOL success) {
                            __HIDRecorderDismissAlertConfirmInternal(presentWindow, runningState);
                        }];
                    }]];
                }
                
                __HIDRecorderIsPresentingAlert = YES;
                if (runningState == SupervisorStateRecording)
                    [[Supervisor sharedInstance] sendSignalToGlobalProcess:SIGUSR1];
                
                [presentController presentViewController:alertCtrl animated:YES completion:nil];
            }
        });
    }
}

void __HIDRecorderDisplayErrorMessage(NSString *alertTitle, NSString *alertContent)
{
    @autoreleasepool {
        NSCAssert([NSThread isMainThread], @"not main thread");
        NSCParameterAssert([alertTitle isKindOfClass:[NSString class]]);
        NSCParameterAssert([alertContent isKindOfClass:[NSString class]]);
        
        // dismiss script message
        notify_post(NOTIFY_DISMISSAL_SYS_ALERT);
        
        // present alert
        dispatch_async(dispatch_get_main_queue(), ^{

            @autoreleasepool {
                
                if (__HIDRecorderIsPresentingAlert)
                    return;
                
                UIViewController *presentController = [[UIViewController alloc] init];
                UIWindow *presentWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
                [presentWindow setRootViewController:presentController];
                [presentWindow setWindowLevel:UIWindowLevelStatusBar + 1];
                [presentWindow setHidden:NO];
                
                _recorderPresentingWindow = presentWindow;
                
                UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@", HIDLocalizedString(alertTitle)]
                                                                                   message:[NSString stringWithFormat:@"%@", HIDLocalizedString(alertContent)]
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                
                [alertCtrl addAction:[UIAlertAction actionWithTitle:HIDLocalizedString(@"DISMISS") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    __HIDRecorderDismissAlertConfirmInternal(presentWindow, SupervisorStateIdle);
                }]];
                
                __HIDRecorderIsPresentingAlert = YES;
                [presentController presentViewController:alertCtrl animated:YES completion:nil];
            }
        });
    }
}

void __HIDRecorderDismissAlertConfirm(void)
{
    NSCAssert([NSThread isMainThread], @"not main thread");
    @autoreleasepool {
        [[[_recorderPresentingWindow rootViewController] view] removeFromSuperview];
        [_recorderPresentingWindow setRootViewController:nil];
        [_recorderPresentingWindow setHidden:YES];
        [_recorderPresentingWindow setWindowScene:nil];
        
        __HIDRecorderIsPresentingAlert = NO;
        if ([[Supervisor sharedInstance] globalState] == SupervisorStateRecording)
            [[Supervisor sharedInstance] sendSignalToGlobalProcess:SIGUSR2];
    }
}

void __HIDRecorderDismissAlertConfirmInternal(UIWindow *presentWindow, SupervisorState runningState)
{
    NSCAssert([NSThread isMainThread], @"not main thread");
    @autoreleasepool {
        [[[presentWindow rootViewController] view] removeFromSuperview];
        [presentWindow setRootViewController:nil];
        [presentWindow setHidden:YES];
        [presentWindow setWindowScene:nil];
        
        __HIDRecorderIsPresentingAlert = NO;
        if (runningState == SupervisorStateRecording)
            [[Supervisor sharedInstance] sendSignalToGlobalProcess:SIGUSR2];
    }
}

void __HIDRecorderPerformOperation(HIDRecorderOperation operation)
{
    @autoreleasepool {
        NSCAssert([NSThread isMainThread], @"not main thread");
        NSCAssert(operation != HIDRecorderOperationBoth, @"invalid operation");
        
        if (__HIDRecorderIsPresentingAlert)
            return;
        
        SupervisorState runningState = [[Supervisor sharedInstance] globalState];
        
        switch (operation) {
            case HIDRecorderOperationPlay:
            {
                if (runningState == SupervisorStateIdle)
                    __HIDRecorderPerformAction(HIDRecorderActionLaunch);
                else
                    __HIDRecorderPerformAction(HIDRecorderActionStop);
                break;
            }
            case HIDRecorderOperationRecord:
            {
                if (runningState == SupervisorStateIdle)
                    __HIDRecorderPerformAction(HIDRecorderActionRecord);
                else
                    __HIDRecorderPerformAction(HIDRecorderActionStop);
                break;
            }
            case HIDRecorderOperationPlayWithAlert:
            {
                __HIDRecorderPerformAlertConfirm(HIDRecorderOperationPlay, runningState);
                break;
            }
            case HIDRecorderOperationRecordWithAlert:
            {
                __HIDRecorderPerformAlertConfirm(HIDRecorderOperationRecord, runningState);
                break;
            }
            case HIDRecorderOperationBothWithAlert:
            {
                __HIDRecorderPerformAlertConfirm(HIDRecorderOperationBoth, runningState);
                break;
            }
            case HIDRecorderOperationNone:
                break;
            case HIDRecorderOperationBoth:
                break;
        }
    }
}


#pragma mark -

NS_INLINE NSTimeInterval IOHIDAbsoluteTimeToTimeInterval(uint64_t abs) {
    static mach_timebase_info_data_t timebase;
    if (!timebase.denom) {
        mach_timebase_info(&timebase);
    }
    return (abs * timebase.numer) / (double)(timebase.denom) / 1e9;
}

static uint64_t _recorderVolumeIncrementLastTimeStamp = 0;
static uint64_t _recorderVolumeDecrementLastTimeStamp = 0;

static boolean_t _recorderVolumeIncrementButtonIsDown = false;
static boolean_t _recorderVolumeDecrementButtonIsDown = false;
static boolean_t _recorderPowerButtonIsDown = false;
static boolean_t _recorderPowerButtonWasDown = false;

static boolean_t _recorderAlertModeIsOn = false;

BOOL HIDRecorderHandleHIDEvent(IOHIDEventRef event)
{
    /* Only keyboard events will be handled */
    if (IOHIDEventGetType(event) != kIOHIDEventTypeKeyboard)
    {
        return NO;  /* Default */
    }
    
    /* Only events in consumer usage page will be handled */
    CFIndex keyboardUsagePage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsagePage);
    if (keyboardUsagePage != kHIDPage_Consumer)
    {
        return NO;  /* Default */
    }
    
    /* Only volume or power button events will be handled */
    CFIndex keyboardUsage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage);
    if (keyboardUsage != kHIDUsage_Csmr_VolumeIncrement &&
        keyboardUsage != kHIDUsage_Csmr_VolumeDecrement &&
        keyboardUsage != kHIDUsage_Csmr_Power)
    {
        return NO;  /* Default */
    }
    
    boolean_t keyboardIsLongPress = false;
    boolean_t keyboardIsDown = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardDown) != 0;
    if (keyboardUsage == kHIDUsage_Csmr_VolumeIncrement)
    {
        _recorderVolumeIncrementButtonIsDown = keyboardIsDown;
        if (keyboardIsDown)
        {
            _recorderVolumeIncrementLastTimeStamp = IOHIDEventGetTimeStamp(event);
        }
        else
        {   /* To check if it is a long press of volume increment button */
            uint64_t delta = IOHIDEventGetTimeStamp(event) - _recorderVolumeIncrementLastTimeStamp;
            NSTimeInterval uDelta = IOHIDAbsoluteTimeToTimeInterval(delta);
            if (uDelta > 0.6)
            {
                keyboardIsLongPress = true;
            }
        }
    }
    else if (keyboardUsage == kHIDUsage_Csmr_VolumeDecrement)
    {
        _recorderVolumeDecrementButtonIsDown = keyboardIsDown;
        if (keyboardIsDown)
        {
            _recorderVolumeDecrementLastTimeStamp = IOHIDEventGetTimeStamp(event);
        }
        else
        {   /* To check if it is a long press of volume decrement button */
            uint64_t delta = IOHIDEventGetTimeStamp(event) - _recorderVolumeDecrementLastTimeStamp;
            NSTimeInterval uDelta = IOHIDAbsoluteTimeToTimeInterval(delta);
            if (uDelta > 0.6)
            {
                keyboardIsLongPress = true;
            }
        }
    }
    else if (keyboardUsage == kHIDUsage_Csmr_Power)
    {
        _recorderPowerButtonIsDown = keyboardIsDown;
        if (keyboardIsDown)
        {
            _recorderPowerButtonWasDown = true;
        }
    }
    
    /* To check if there is no button pressed down */
    boolean_t didAllButtonReleased = false;
    boolean_t didPowerInterruptionRecovered = false;
    if (!_recorderVolumeIncrementButtonIsDown &&
        !_recorderVolumeDecrementButtonIsDown &&
        !_recorderPowerButtonIsDown)
    {
        /* Reset Power Button State */
        if (_recorderPowerButtonWasDown) {
            _recorderPowerButtonWasDown = false;
            didPowerInterruptionRecovered = true;
        }
        
        didAllButtonReleased = true;
    }
    
    if (__HIDRecorderIsPresentingAlert)
    {
        /* Enter Alert Mode:
           If a hardware button event is triggered during alert presentation,
           all following events will be redirected to it original handler until
           no hardware button is pressed down.
         */
        _recorderAlertModeIsOn = true;
        return NO;  /* Default */
    }
    else if (_recorderAlertModeIsOn)
    {
        /* To check if there is no button pressed down */
        if (didAllButtonReleased)
        {   /* Exit Alert Mode */
            _recorderAlertModeIsOn = false;
        }
        
        return NO;  /* Default */
    }
    
    /* Power Button Interruption:
       If any power button event is triggered before or after volume button events,
       these volume events will be ignored until no hardware button is pressed down.
     */
    if (keyboardUsage == kHIDUsage_Csmr_Power)
    {
        return NO;
    }
    else if (keyboardIsDown || didPowerInterruptionRecovered || _recorderPowerButtonIsDown || _recorderPowerButtonWasDown)
    {   /* FIXME: Snapshot will not work as expected */
        return YES;  /* Block */
    }
    
    /* Perform Real Operations */
    if (keyboardIsLongPress)
    {
        if (keyboardUsage == kHIDUsage_Csmr_VolumeIncrement)
        {
            if (_recorderHoldVolumeUpOperation != HIDRecorderOperationNone)
            {
                CHDebugLogSource(@"");
                __HIDRecorderPerformOperation(_recorderHoldVolumeUpOperation);
            }
        }
        else if (keyboardUsage == kHIDUsage_Csmr_VolumeDecrement)
        {
            if (_recorderHoldVolumeDownOperation != HIDRecorderOperationNone)
            {
                CHDebugLogSource(@"");
                __HIDRecorderPerformOperation(_recorderHoldVolumeDownOperation);
            }
        }
    }
    else
    {
        if (keyboardUsage == kHIDUsage_Csmr_VolumeIncrement)
        {
            if (_recorderClickVolumeUpOperation != HIDRecorderOperationNone)
            {
                CHDebugLogSource(@"");
                __HIDRecorderPerformOperation(_recorderClickVolumeUpOperation);
            }
            else
            {
                /* FIXME: User actually wants to increase the volume */
            }
        }
        else if (keyboardUsage == kHIDUsage_Csmr_VolumeDecrement)
        {
            if (_recorderClickVolumeDownOperation != HIDRecorderOperationNone)
            {
                CHDebugLogSource(@"");
                __HIDRecorderPerformOperation(_recorderClickVolumeDownOperation);
            }
            else
            {
                /* FIXME: User actually wants to decrease the volume */
            }
        }
    }
    
    return YES;  /* Block */
}


#pragma mark - Server Initializers

CHDeclareClass(SpringBoard);

CHOptimizedMethod(1, self, void, SpringBoard, applicationDidFinishLaunching, UIApplication *, application)
{
    @autoreleasepool
    {
        CHSuper(1, SpringBoard, applicationDidFinishLaunching, application);
        [[ProcQueue sharedInstance] remoteDefaultsChanged];
        
        {
            NSFileManager *defaultManager = [NSFileManager defaultManager];
            BOOL exists = [defaultManager fileExistsAtPath:@"/private/var/tmp/1ferver_need_respring"];
            if (exists) {
                NSError *error = nil;
                BOOL succeed = [defaultManager removeItemAtPath:@"/private/var/tmp/1ferver_need_respring" error:&error];
#if DEBUG
                NSCAssert1(succeed, @"%@", error);
#endif
            }
        }
        
        {
            int errorAlertToken;
            notify_register_dispatch(NOTIFY_TASK_DID_END, &errorAlertToken, dispatch_get_main_queue(), ^(int token) {
                @autoreleasepool {
                    if (__HIDRecorderIsPresentingAlert)
                        return;
                    
                    NSError *lastError = [[Supervisor sharedInstance] lastError];
                    if (!lastError ||
                        ![[lastError localizedDescription] length] ||
                        ![[lastError localizedFailureReason] length])
                    {
                        return;
                    }
                    
                    __HIDRecorderDisplayErrorMessage([lastError localizedDescription], [lastError localizedFailureReason]);
                }
            });
        }
    }
}


#pragma mark - Initializers

CHConstructor
{
    @autoreleasepool
    {
        CHLoadLateClass(SpringBoard);
        CHHook(1, SpringBoard, applicationDidFinishLaunching);
    }
}

