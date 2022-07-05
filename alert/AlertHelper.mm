//
//  AlertHelper.m
//  AlertHelper
//
//  Created by Darwin on 2/16/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TFLuaBridge.h"
#import "AHWeakObjectWrapper.h"
#import "AHCommonPayload.json.h"
#import <pthread.h>
#import <AudioToolbox/AudioToolbox.h>


#pragma mark -


@interface UIAlertController (Private)
- (void)_dismissWithCancelAction;
- (void)_dismissWithAction:(id)action;
- (void)_dismissAnimated:(BOOL)arg1 triggeringAction:(id)arg2;
@end

@interface SFDialogAction : NSObject
@property (nonatomic, readonly) long long actionType;
@property (nonatomic, readonly) NSString *title;
@end

@interface SFDialogView : UIView
@end

@interface SFDialogContentView : UIView
@end

@interface SFDialogTextView : UIView
@end

@interface SFDialogTextField : UITextField
@end

@interface SFDialogController : NSObject
- (void)dialogView:(SFDialogView *)arg1 didSelectActionAtIndex:(NSUInteger)arg2 withInputText:(NSString *)arg3 passwordText:(NSString *)arg4;
@end

@interface UIKeyboardTaskQueue
/**
 *  Completes all pending or ongoing tasks in the task queue before returning. Must be called from
 *  the main thread.
 */
- (void)waitUntilAllTasksAreFinished;

- (void)performTask:(void (^)(id ctx))arg1;

@end

@interface UIKeyboardImpl
/**
 *  @return Shared instance of UIKeyboardImpl. It may be different from the active instance.
 */
+ (instancetype)sharedInstance;

/**
 *  @return The Active instance of UIKeyboardImpl, if one exists; otherwise returns @c nil. Active
 *          instance could exist even if the keyboard is not shown on the screen.
 */
+ (instancetype)activeInstance;

/**
 *  @return The current keyboard layout view, which contains accessibility elements for keyboard
 *          keys that are shown on the keyboard.
 */
- (UIView *)_layout;

/**
 *  @return The string shown on the return key on the keyboard.
 */
- (NSString *)returnKeyDisplayName;

/**
 *  @return The task queue keyboard is using to manage asynchronous tasks.
 */
- (UIKeyboardTaskQueue *)taskQueue;

/**
 *  Automatically hides the software keyboard if @c enabled is set to @c YES and hardware keyboard
 *  is available. Setting @c enabled to @c NO will always show software keyboard. This setting is
 *  global and applies to all instances of UIKeyboardImpl.
 *
 *  @param enabled A boolean that indicates automatic minimization (hiding) of the keyboard.
 */
- (void)setAutomaticMinimizationEnabled:(BOOL)enabled;

/**
 *  @return The delegate that the UIKeyboard is typing on.
 */
- (id)delegate;

/**
 *  Sets the current UIKeyboard's delegate.
 *
 *  @param delegate The element to set the UIKeyboard's delegate to.
 */
- (void)setDelegate:(id)delegate;
/**
 *  A method to hide the keyboard without resigning the first responder. This is used only
 *  in iOS 8.1 where we found that turning off the autocorrection type on the first responder
 *  using setAutomaticMinimizationEnabled: without toggling the keyboard caused keyboard touches
 *  to be ignored.
 */
- (void)hideKeyboard;

/**
 *  A method to show the keyboard without resigning the first responder. This is used only
 *  in iOS 8.1 where we found that turning off the autocorrection type on the first responder
 *  using setAutomaticMinimizationEnabled: without toggling the keyboard caused keyboard touches
 *  to be ignored.
 */
- (void)showKeyboard;

@property(readonly, nonatomic) UIKeyboardTaskQueue *taskQueue;
- (void)handleKeyWithString:(id)arg1 forKeyEvent:(id)arg2 executionContext:(id)arg3;
- (void)setShift:(_Bool)arg1 autoshift:(_Bool)arg2;
- (void)removeCandidateList;

@end

/**
 * Text Input preferences controller to modify the keyboard preferences for iOS 8+.
 */
@interface TIPreferencesController : NSObject

/** Whether the autocorrection is enabled. */
@property BOOL autocorrectionEnabled;

/** Whether the predication is enabled. */
@property BOOL predictionEnabled;

/** The shared singleton instance. */
+ (instancetype)sharedPreferencesController;

/** Synchronize the change to save it on disk. */
- (void)synchronizePreferences;

/** Modify the preference @c value by @c key. */
- (void)setValue:(NSValue *)value forPreferenceKey:(NSString *)key;
@end

/**
 *  Private class for representing internal touch events.
 *  @see
 *  https://github.com/nst/iOS-Runtime-Headers/blob/master/Frameworks/UIKit.framework/UIInternalEvent.h
 */
@interface UIInternalEvent : UIEvent
/**
 *  Sets HIDEvent property for the event.
 *
 *  @param event The event for HIDEvent property.
 */
- (void)_setHIDEvent:(id /* IOHIDEventRef */)event;
@end

/**
 *  A private class that represents touch related events. This is sent to UIApplication whenever a
 *  touch occurs.
 */
@interface UITouchesEvent : UIInternalEvent
/**
 *  Adds a @c touch to the event. It's unclear what @c delayedDelivery does.
 *
 *  @param touch           The touch object to be added.
 *  @param delayedDelivery Unknown private API param.
 */
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delayedDelivery;

/**
 *  Removes all touch objects from the event.
 */
- (void)_clearTouches;
@end

/**
 *  A private class that represents backboard services accelerometer.
 */
@interface BKSAccelerometer : NSObject
/**
 *  Enable or disable accelerometer events.
 */
@property(nonatomic) BOOL accelerometerEventsEnabled;
@end

/**
 *  A private class that represents motion related events. This is sent to UIApplication whenever a
 *  motion occurs.
 */
@interface UIMotionEvent : UIEvent
{
  // The motion accelerometer of the event.
  BKSAccelerometer *_motionAccelerometer;
}

/**
 *  Modify the _shakeState ivar inside motion event.
 *
 *  shakeState Set as true for 1 being passed. All other values set to false.
 */
- (void)setShakeState:(int)shakeState;

/**
 *  Sets the subtype for the motion event.
 *
 *  eventSubType The UIEventSubtype for the motion event.
 */
- (void)_setSubtype:(int)eventSubType;
@end

@interface UIApplication (Private)
- (void)terminateWithSuccess;
- (BOOL)_isSpringBoardShowingAnAlert;
- (UIWindow *)statusBarWindow;
/**
 *  Changes the main runloop to run in the specified mode, pushing it to the top of the stack of
 *  current modes.
 */
- (void)pushRunLoopMode:(NSString *)mode;
/**
 *  Changes the main runloop to run in the specified mode, pushing it to the top of the stack of
 *  current modes.
 */
- (void)pushRunLoopMode:(NSString *)mode requester:(id)requester;
/**
 *  Pops topmost mode from the runloop mode stack.
 */
- (void)popRunLoopMode:(NSString *)mode;
/**
 *  Pops topmost mode from the runloop mode stack.
 */
- (void)popRunLoopMode:(NSString *)mode requester:(id)requester;
/**
 *  @return The shared UITouchesEvent object of the application, which is used to keep track of
 *          UITouch objects, and the relevant touch interaction state.
 */
- (UITouchesEvent *)_touchesEvent;
/**
 *  @return The shared UIMotionEvent object of the application, used to force enable motion
 *          accelerometer events.
 */
- (UIMotionEvent *)_motionEvent;

/**
 *  Sends a motion began event for the specified subtype.
 */
- (void)_sendMotionBegan:(UIEventSubtype)subtype;

/**
 *  Sends a motion ended event for the specified subtype.
 */
- (void)_sendMotionEnded:(UIEventSubtype)subtype;
@end

@interface UIDevice (Orientation)
- (void)setOrientation:(UIDeviceOrientation)orientation animated:(BOOL)animated;
@end

@interface UIWindow (Responder)
- (id)firstResponder;
@end


#pragma mark -


static BOOL __option_AlertHelperDumpEnabled = NO;
static BOOL __option_AlertHelperAutoBypassEnabled = NO;
static NSTimeInterval __option_AlertHelperAutoBypassDelay = 1.0;

static NSMutableArray <NSSet *> *__local_AlertHelperRegisteredWrappers = nil;

static pthread_mutex_t __global_AlertHelperDialogNotificationLock;
static CFUserNotificationRef __global_AlertHelperDialogNotification = NULL;


#pragma mark -


@implementation TFLuaBridge (Actions)

+ (void)alertHelperLogDialogObject:(id)object {
#if DEBUG
    [[TFLuaBridge sharedInstance] logObject:object];
#else
    if (!__option_AlertHelperDumpEnabled) return;
    [[TFLuaBridge sharedInstance] logObject:object];
#endif
}

+ (NSArray <NSDictionary *> *)alertHelperDialogRules {
    assert([NSThread isMainThread]);

    @autoreleasepool {
        NSError *defaultsError = nil;
        NSMutableDictionary *userDefaults = [[[TFLuaBridge sharedInstance] readDefaultsWithError:&defaultsError] mutableCopy];
        if (![userDefaults isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        
        NSDictionary *commonPayload = nil;
        NSData *commonPayloadData = __InlineData_AHCommonPayload_json();
        if (commonPayloadData) {
            NSError *commonError = nil;
            commonPayload = [NSJSONSerialization JSONObjectWithData:commonPayloadData options:kNilOptions error:&commonError];
            if (!commonPayload) {
                CHDebugLogSource(@"%@", commonError);
            }
        }
        if (commonPayload) {
            [userDefaults addEntriesFromDictionary:commonPayload];
        }

        __option_AlertHelperDumpEnabled = [userDefaults[@"loggingEnabled"] boolValue];
        __option_AlertHelperAutoBypassEnabled = [userDefaults[@"autoBypassEnabled"] boolValue];
        __option_AlertHelperAutoBypassDelay = [userDefaults[@"autoBypassDelay"] doubleValue];

        NSMutableArray <NSDictionary *> *dialogRules = [[NSMutableArray alloc] init];
        if ([userDefaults objectForKey:@"__GLOBAL__"] && [userDefaults[@"__GLOBAL__"] isKindOfClass:[NSArray class]]) {
            NSArray <NSDictionary *> *globalRules = userDefaults[@"__GLOBAL__"];
            [dialogRules addObjectsFromArray:globalRules];
        }

        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier && [userDefaults objectForKey:bundleIdentifier] && [userDefaults[bundleIdentifier] isKindOfClass:[NSArray class]]) {
            NSArray <NSDictionary *> *localRules = userDefaults[bundleIdentifier];
            [dialogRules addObjectsFromArray:localRules];
        }

        [self alertHelperLogDialogObject:[NSString stringWithFormat:@"rules loaded: %lu in total", [dialogRules count]]];
        return [dialogRules copy];
    }
}

+ (void)alertHelperRemoveOutdatedRegistration {
    assert([NSThread isMainThread]);

    @autoreleasepool {
        NSMutableArray <NSSet *> *wrapperSetsToRemove = [[NSMutableArray alloc] initWithCapacity:__local_AlertHelperRegisteredWrappers.count];
        for (NSSet *wrapperSet in __local_AlertHelperRegisteredWrappers) {
            if (((AHWeakObjectWrapper *)wrapperSet.anyObject).weakObject == nil) {
                [wrapperSetsToRemove addObject:wrapperSet];
            }
        }
        [__local_AlertHelperRegisteredWrappers removeObjectsInArray:wrapperSetsToRemove];
    }
}

+ (NSDictionary *)alertHelperGetDictionaryFromAlertController:(UIAlertController *)controller {
    @autoreleasepool {
        // title & message
        NSString *alertTitle = controller.title;
        NSString *alertMessage = controller.message;
        UIAlertControllerStyle alertStyleValue = controller.preferredStyle;
        NSString *alertStyle = nil;
        if (alertStyleValue == UIAlertControllerStyleActionSheet) {
            alertStyle = @"action-sheet";
        } else {
            alertStyle = @"alert";
        }

        // text fields
        NSArray <UITextField *> *alertTextFields = [controller textFields];
        NSMutableArray <NSDictionary *> *alertTextFieldInfo = [NSMutableArray arrayWithCapacity:alertTextFields.count];
        for (UITextField *textField in alertTextFields) {
            [alertTextFieldInfo addObject:@{
                 @"placeholder": textField.placeholder ?: @"",
                 @"text": textField.text ?: @"",
            }];
        }

        // actions
        NSArray <UIAlertAction *> *alertActions = [controller actions];
        NSMutableArray <NSDictionary *> *alertActionInfo = [NSMutableArray arrayWithCapacity:alertActions.count];
        for (UIAlertAction *alertAction in alertActions) {
            NSString *alertActionStyle = nil;
            if (alertAction.style == UIAlertActionStyleDestructive) {
                alertActionStyle = @"destructive";
            } else if (alertAction.style == UIAlertActionStyleCancel) {
                alertActionStyle = @"cancel";
            } else {
                // UIAlertActionStyleDefault
                alertActionStyle = @"default";
            }
            [alertActionInfo addObject:@{
                 @"enabled": @(alertAction.enabled),
                 @"title": alertAction.title ?: @"",
                 @"style": alertActionStyle,
            }];
        }

        return @{
            @"class": (NSStringFromClass(controller.class)),
            @"title": (alertTitle ? alertTitle : @""),
            @"message": (alertMessage ? alertMessage : @""),
            @"style": alertStyle,
            @"textfields": alertTextFieldInfo,
            @"actions": alertActionInfo,
        };
    }
}

+ (BOOL)alertHelperDismissAlertController:(UIAlertController *)controller withRule:(NSDictionary *)applyRule {
    assert([NSThread isMainThread]);

    @autoreleasepool {
        // fill textfields in order
        NSArray <NSDictionary *> *filterFields = applyRule[@"textfields"];
        if ([filterFields isKindOfClass:[NSArray class]]) {
            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[?] try to fill %lu textfields", filterFields.count]];
            NSArray <UITextField *> *alertFields = controller.textFields;
            for (NSUInteger idx = 0; idx < alertFields.count; idx++) {
                @autoreleasepool {
                    if (idx < filterFields.count) {
                        id filterField = filterFields[idx];
                        if ([filterField isKindOfClass:[NSString class]]) {
                            NSString *fillText = filterField;
                            UITextField *alertField = alertFields[idx];
                            [alertField setText:fillText];
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[-] textfield #%lu: filled with '%@'", idx, fillText]];
                        } else if ([filterField isKindOfClass:[NSDictionary class]]) {
                            if ([filterField[@"text"] isKindOfClass:[NSString class]]) {
                                NSString *fillText = filterField[@"text"];
                                UITextField *alertField = alertFields[idx];
                                [alertField setText:fillText];
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[-] textfield #%lu: filled with '%@'", idx, fillText]];
                            } else {
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] textfield #%lu: invalid `text`", idx]];
                            }
                        } else {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] textfield #%lu: invalid object", idx]];
                        }
                    }
                }
            }
        } else {
            [self alertHelperLogDialogObject:@"[-] `textfields` is not defined or invalid"];
        }

        // click matched action
        if ([applyRule[@"action"] isKindOfClass:[NSNumber class]]) {
            NSNumber *filterAction = applyRule[@"action"];
            NSUInteger targetActionIndex = [filterAction unsignedIntegerValue];
            
            if (targetActionIndex > 0) {
                targetActionIndex -= 1;  // adopt lua index
            }

            UIAlertAction *matchedAction = nil;
            NSArray <UIAlertAction *> *alertActions = controller.actions;
            if (targetActionIndex < alertActions.count) {
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[?] try to select action #%lu", targetActionIndex]];
                matchedAction = [alertActions objectAtIndex:targetActionIndex];
            } else {
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] action: index out of range 0..<%lu", alertActions.count]];
            }

            if (matchedAction != nil) {
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[!] matched: action '%@'", matchedAction.title]];

                [controller _dismissWithAction:matchedAction];
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[-] action '%@' performed immediately", matchedAction.title]];
                
                return YES;
            }
        } else if ([applyRule[@"action"] isKindOfClass:[NSDictionary class]] || [applyRule[@"action"] isKindOfClass:[NSString class]]) {
            NSString *filterActionTitleRegex = nil;
            NSDictionary *filterAction = nil;
            if ([applyRule[@"action"] isKindOfClass:[NSDictionary class]]) {
                filterAction = applyRule[@"action"];
                filterActionTitleRegex = filterAction[@"title"];
            } else {
                filterActionTitleRegex = applyRule[@"action"];
            }

            UIAlertAction *matchedAction = nil;

            if ([filterActionTitleRegex isKindOfClass:[NSString class]]) { // regex match action title
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[?] try to select action by matching its `title` like /%@/", filterActionTitleRegex]];

                if (filterActionTitleRegex.length > 0) {
                    for (NSUInteger actionIndex = 0; actionIndex < controller.actions.count; actionIndex++) {
                        UIAlertAction *alertAction = controller.actions[actionIndex];
                        if (alertAction.title) {
                            if ([alertAction.title rangeOfString:filterActionTitleRegex options:NSRegularExpressionSearch].location != NSNotFound) {
                                matchedAction = alertAction;
                                break;
                            }
                        }
                    }
                }
            } else {
                [self alertHelperLogDialogObject:@"\t[x] action: invalid `title`"];
            }

            if (matchedAction != nil) {
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[!] matched: action '%@'", matchedAction.title]];
                if ([filterAction[@"delay"] isKindOfClass:[NSNumber class]]) { // delay for a while
                    NSInteger delay_ms = [filterAction[@"delay"] integerValue];
                    NSTimeInterval delay = delay_ms / 1000.0;
                    [controller performSelector:@selector(_dismissWithAction:) withObject:matchedAction afterDelay:delay];
                    [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[-] action '%@' performed with delay %lu ms", matchedAction.title, delay_ms]];
                } else {
                    [controller _dismissWithAction:matchedAction];
                    [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[-] action '%@' performed immediately", matchedAction.title]];
                }

                return YES;
            }
        } else {
            [self alertHelperLogDialogObject:@"[-] `action` is not defined or invalid"];
        }

        return NO;
    }
}

+ (void)alertHelperProcessAlertController:(UIAlertController *)controller {
    assert([NSThread isMainThread]);

    @autoreleasepool {
        BOOL hasRegistration = NO;
        for (NSSet *wrapperSet in __local_AlertHelperRegisteredWrappers) {
            @autoreleasepool {
                AHWeakObjectWrapper *wrapper = [wrapperSet anyObject];
                if (wrapper.weakObject == controller) {
                    hasRegistration = YES;
                    break;
                }
            }
        }
        if (!hasRegistration) {
            AHWeakObjectWrapper *wrapper = [[AHWeakObjectWrapper alloc] initWithWeakObject:controller];
            [__local_AlertHelperRegisteredWrappers addObject:[NSSet setWithObject:wrapper]];
        }
        [self alertHelperRemoveOutdatedRegistration];

        // alert helper: dump dialog
        if (__option_AlertHelperDumpEnabled) {
            [self alertHelperLogDialogObject:[self alertHelperGetDictionaryFromAlertController:controller]];
        }

        // alert helper: auto bypass
        if (__option_AlertHelperAutoBypassEnabled) {
            UIAlertAction *autoAction = controller.preferredAction ?: controller.actions.firstObject;
            if (autoAction) {
                NSTimeInterval delay = __option_AlertHelperAutoBypassDelay;
                [controller performSelector:@selector(_dismissWithAction:) withObject:autoAction afterDelay:delay];
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[!] auto bypass after %.2f second: %@", delay, autoAction.title]];
            }
            return;
        }

        // alert helper: dialog rules
        NSArray <NSDictionary *> *dialogRules = [self alertHelperDialogRules];
        if (dialogRules.count > 0) {

            NSDictionary *applyRule = nil;
            for (NSUInteger ruleIndex = 0; ruleIndex < dialogRules.count; ruleIndex++) {
                @autoreleasepool {
                    NSDictionary *dialogRule = dialogRules[ruleIndex];
                    [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[?] try to match: rule #%lu", ruleIndex]];
                    if (![dialogRule[@"class"] isKindOfClass:[NSString class]] &&
                        ![dialogRule[@"title"] isKindOfClass:[NSString class]] &&
                        ![dialogRule[@"message"] isKindOfClass:[NSString class]] &&
                        ![dialogRule[@"style"] isKindOfClass:[NSString class]] &&
                        ![dialogRule[@"action"] isKindOfClass:[NSDictionary class]]
                        ) { // invalid rule
                        [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: invalid rule. `class`, `style`, `action`, `title` or `message` is required", ruleIndex]];
                        continue;
                    }
                    if ([dialogRule[@"class"] isKindOfClass:[NSString class]]) { // match class
                        NSString *filterClassName = dialogRule[@"class"];
                        NSString *realClassName = NSStringFromClass(controller.class);
                        NSString *targetClass = [NSString stringWithFormat:@"%@", realClassName];
                        if (![filterClassName isEqualToString:targetClass]) {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `class` == '%@', but '%@'", ruleIndex, filterClassName, targetClass]];
                            continue;
                        }
                    }
                    if ([dialogRule[@"style"] isKindOfClass:[NSString class]]) { // match style
                        NSString *filterStyleName = dialogRule[@"style"];
                        NSString *realStyleName = (controller.preferredStyle == UIAlertControllerStyleActionSheet) ? @"action-sheet" : @"alert";
                        if (![filterStyleName isEqualToString:realStyleName]) {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `style` == '%@', but '%@'", ruleIndex, filterStyleName, realStyleName]];
                            continue;
                        }
                    }
                    if ([dialogRule[@"title"] isKindOfClass:[NSString class]]) { // regex match title
                        NSString *filterTitleRegex = dialogRule[@"title"];
                        NSString *targetTitle = [NSString stringWithFormat:@"%@", controller.title];
                        if ([targetTitle rangeOfString:filterTitleRegex options:NSRegularExpressionSearch].location == NSNotFound) {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `title` satisfy '%@', but '%@'", ruleIndex, filterTitleRegex, targetTitle]];
                            continue;
                        }
                    }
                    if ([dialogRule[@"message"] isKindOfClass:[NSString class]]) { // regex match message
                        NSString *filterMessageRegex = dialogRule[@"message"];
                        NSString *targetMessage = [NSString stringWithFormat:@"%@", controller.message];
                        if ([targetMessage rangeOfString:filterMessageRegex options:NSRegularExpressionSearch].location == NSNotFound) {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `message` satisfy '%@', but '%@'", ruleIndex, filterMessageRegex, targetMessage]];
                            continue;
                        }
                    }
                    if ([dialogRule[@"action"] isKindOfClass:[NSDictionary class]] || [dialogRule[@"action"] isKindOfClass:[NSString class]]) { // regex find action
                        NSString *targetTitleRegex = nil;
                        if ([dialogRule[@"action"] isKindOfClass:[NSDictionary class]]) {
                            NSDictionary *filterAction = dialogRule[@"action"];
                            targetTitleRegex = filterAction[@"title"];
                        } else {
                            targetTitleRegex = dialogRule[@"action"];
                        }

                        NSMutableArray <NSString *> *actionNames = [NSMutableArray array];
                        UIAlertAction *matchedAction = nil;

                        if ([targetTitleRegex isKindOfClass:[NSString class]]) { // regex match action title
                            NSString *filterActionTitleRegex = targetTitleRegex;
                            if (filterActionTitleRegex.length > 0) {
                                for (NSUInteger actionIndex = 0; actionIndex < controller.actions.count; actionIndex++) {
                                    UIAlertAction *alertAction = controller.actions[actionIndex];
                                    if ([alertAction.title isKindOfClass:[NSString class]]) {
                                        if ([alertAction.title rangeOfString:filterActionTitleRegex options:NSRegularExpressionSearch].location != NSNotFound) {
                                            matchedAction = alertAction;
                                            break;
                                        }
                                        [actionNames addObject:alertAction.title];
                                    }
                                }
                            }
                        }

                        if (!matchedAction) {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `action`.`title` satisfy one of '%@', but '%@'", ruleIndex, actionNames, targetTitleRegex]];
                            continue;
                        }
                    }
                    if ([dialogRule[@"action"] isKindOfClass:[NSNumber class]]) { // locate action by its index
                        NSNumber *filterAction = dialogRule[@"action"];
                        NSUInteger targetActionIndex = [filterAction unsignedIntegerValue];
                        
                        if (targetActionIndex > 0) {
                            targetActionIndex -= 1;  // adopt lua index
                        }

                        UIAlertAction *matchedAction = nil;
                        NSArray <UIAlertAction *> *alertActions = controller.actions;
                        if (targetActionIndex < alertActions.count) {
                            matchedAction = [alertActions objectAtIndex:targetActionIndex];
                        }
                        if (!matchedAction) {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. index of `action` %lu out of range 0..<%lu", ruleIndex, targetActionIndex, alertActions.count]];
                            continue;
                        }
                    }
                    if ([dialogRule[@"textfields"] isKindOfClass:[NSArray class]]) { // match textfield count
                        NSArray *filterFields = dialogRule[@"textfields"];
                        NSArray <UITextField *> *alertFields = controller.textFields;
                        if (filterFields.count != alertFields.count) {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `textfields`.count equals '%lu', but '%lu'", ruleIndex, alertFields.count, filterFields.count]];
                            continue;
                        }
                    }
                    
                    [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[!] matched: rule #%lu", ruleIndex]];
                    applyRule = dialogRule;
                    break;
                }
            }

            if (applyRule) {
                [self alertHelperDismissAlertController:controller withRule:applyRule];
            }
        }
    }
}

+ (NSDictionary *)alertHelperGetDictionaryFromSafariDialogController:(SFDialogController *)dialogController withDialogView:(SFDialogView *)dialogView {
    @autoreleasepool {
        SFDialogContentView *contentView = [dialogView valueForKey:@"_contentView"];
        SFDialogTextView *messageTextView = [contentView valueForKey:@"_messageTextView"];
        NSString *alertTitle = [messageTextView valueForKey:@"_title"];
        NSString *alertMessage = [messageTextView valueForKey:@"_message"];
        NSArray <SFDialogAction *> *alertActions = [contentView valueForKey:@"_actions"];
        NSMutableArray <NSDictionary *> *alertTextFieldInfo = [NSMutableArray arrayWithCapacity:2];
        SFDialogTextField *inputTextField = [contentView valueForKey:@"_inputTextField"];
        if (inputTextField) {
            [alertTextFieldInfo addObject:@{
                 @"placeholder": inputTextField.placeholder ?: @"",
                 @"text": inputTextField.text ?: @"",
            }];
        }
        SFDialogTextField *passwordTextField = [contentView valueForKey:@"_passwordTextField"];
        if (passwordTextField) {
            [alertTextFieldInfo addObject:@{
                 @"placeholder": passwordTextField.placeholder ?: @"",
                 @"text": passwordTextField.text ?: @"",
            }];
        }
        NSMutableArray <NSDictionary *> *alertActionInfo = [NSMutableArray arrayWithCapacity:alertActions.count];
        for (NSUInteger actionIndex = 0; actionIndex < alertActions.count; actionIndex++) {
            SFDialogAction *dialogAction = alertActions[actionIndex];
            NSString *actionTitle = [dialogAction title];
            NSInteger actionType = [dialogAction actionType];
            NSString *alertActionStyle = nil;
            if (actionType == UIAlertActionStyleDestructive) {
                alertActionStyle = @"destructive";
            } else if (actionType == UIAlertActionStyleCancel) {
                alertActionStyle = @"cancel";
            } else {
                // UIAlertActionStyleDefault
                alertActionStyle = @"default";
            }
            [alertActionInfo addObject:@{
                 @"enabled": @(YES),
                 @"title": actionTitle ?: @"",
                 @"style": alertActionStyle,
            }];
        }

        return @{
            @"class": (NSStringFromClass(dialogController.class)),
            @"title": (alertTitle ? alertTitle : @""),
            @"message": (alertMessage ? alertMessage : @""),
            @"style": @"alert",
            @"textfields": alertTextFieldInfo,
            @"actions": alertActionInfo,
        };
    }
}

+ (BOOL)alertHelperDismissSafariDialogController:(SFDialogController *)dialogController withDialogView:(SFDialogView *)dialogView withRule:(NSDictionary *)applyRule {
    assert([NSThread isMainThread]);

    @autoreleasepool {
        SFDialogContentView *contentView = [dialogView valueForKey:@"_contentView"];
        NSString *newInputText = @"";
        NSString *newPasswordText = @"";
        NSArray <NSDictionary *> *filterFields = applyRule[@"textfields"];

        // fill textfields in order
        if ([filterFields isKindOfClass:[NSArray class]]) {
            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[?] try to fill %lu textfields", filterFields.count]];
            NSMutableArray <SFDialogTextField *> *alertFields = [NSMutableArray arrayWithCapacity:2];
            SFDialogTextField *inputTextField = [contentView valueForKey:@"_inputTextField"];
            if (inputTextField) {
                [alertFields addObject:inputTextField];
            }
            SFDialogTextField *passwordTextField = [contentView valueForKey:@"_passwordTextField"];
            if (passwordTextField) {
                [alertFields addObject:passwordTextField];
            }
            for (NSUInteger idx = 0; idx < alertFields.count; idx++) {
                @autoreleasepool {
                    if (idx < filterFields.count) {
                        id filterField = filterFields[idx];
                        if ([filterField isKindOfClass:[NSString class]]) {
                            NSString *fillText = filterField;
                            SFDialogTextField *alertField = alertFields[idx];
                            if (alertField == inputTextField) {
                                newInputText = fillText;
                            } else if (alertField == passwordTextField) {
                                newPasswordText = fillText;
                            }
                            [alertField setText:fillText];
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[-] textfield #%lu: filled with '%@'", idx, fillText]];
                        } else if ([filterField isKindOfClass:[NSDictionary class]]) {
                            if ([filterField[@"text"] isKindOfClass:[NSString class]]) {
                                NSString *fillText = filterField[@"text"];
                                SFDialogTextField *alertField = alertFields[idx];
                                if (alertField == inputTextField) {
                                    newInputText = fillText;
                                } else if (alertField == passwordTextField) {
                                    newPasswordText = fillText;
                                }
                                [alertField setText:fillText];
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[-] textfield #%lu: filled with '%@'", idx, fillText]];
                            } else {
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] textfield #%lu: invalid `text`", idx]];
                            }
                        } else {
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] textfield #%lu: invalid object", idx]];
                        }
                    }
                }
            }
        } else {
            [self alertHelperLogDialogObject:@"[-] `textfields` is not defined or invalid"];
        }

        // click matched action
        if ([applyRule[@"action"] isKindOfClass:[NSNumber class]]) {
            NSNumber *filterAction = applyRule[@"action"];
            NSUInteger targetActionIndex = [filterAction unsignedIntegerValue];
            
            if (targetActionIndex > 0) {
                targetActionIndex -= 1;  // adopt lua index
            }

            SFDialogAction *matchedAction = nil;
            NSUInteger matchedActionIndex = NSNotFound;
            NSArray <SFDialogAction *> *alertActions = [contentView valueForKey:@"_actions"];
            if (targetActionIndex < alertActions.count) {
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[?] try to select action #%lu", targetActionIndex]];
                matchedAction = [alertActions objectAtIndex:targetActionIndex];
                matchedActionIndex = targetActionIndex;
            } else {
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] action: index out of range 0..<%lu", alertActions.count]];
            }

            if (matchedActionIndex != NSNotFound) {
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[!] matched: action '%@'", matchedAction.title]];

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.33f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [dialogController dialogView:dialogView didSelectActionAtIndex:matchedActionIndex withInputText:newInputText passwordText:newPasswordText];
                });
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[-] action '%@' performed immediately", matchedAction.title]];
                
                return YES;
            }
        } else if ([applyRule[@"action"] isKindOfClass:[NSDictionary class]] || [applyRule[@"action"] isKindOfClass:[NSString class]]) {
            NSDictionary *filterAction = nil;
            NSString *filterActionTitleRegex = nil;
            if ([applyRule[@"action"] isKindOfClass:[NSDictionary class]]) {
                filterAction = applyRule[@"action"];
                filterActionTitleRegex = filterAction[@"title"];
            } else {
                filterActionTitleRegex = applyRule[@"action"];
            }
            SFDialogAction *matchedAction = nil;
            NSUInteger matchedActionIndex = NSNotFound;

            NSArray <SFDialogAction *> *alertActions = [contentView valueForKey:@"_actions"];
            if ([filterActionTitleRegex isKindOfClass:[NSString class]]) {     // regex match action title
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[?] try to select action by matching its `title` like /%@/", filterActionTitleRegex]];

                if (filterActionTitleRegex.length > 0) {
                    for (NSUInteger actionIndex = 0; actionIndex < alertActions.count; actionIndex++) {
                        SFDialogAction *alertAction = alertActions[actionIndex];
                        if (alertAction.title) {
                            if ([alertAction.title rangeOfString:filterActionTitleRegex options:NSRegularExpressionSearch].location != NSNotFound) {
                                matchedAction = alertAction;
                                matchedActionIndex = actionIndex;
                                break;
                            }
                        }
                    }
                }
            } else {
                [self alertHelperLogDialogObject:@"\t[x] action: invalid `title`"];
            }

            if (matchedActionIndex != NSNotFound) {
                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[!] matched: action '%@'", matchedAction.title]];
                if ([filterAction[@"delay"] isKindOfClass:[NSNumber class]]) {     // delay for a while
                    NSInteger delay_ms = [filterAction[@"delay"] integerValue];
                    NSTimeInterval delay = delay_ms / 1000.0;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [dialogController dialogView:dialogView didSelectActionAtIndex:matchedActionIndex withInputText:newInputText passwordText:newPasswordText];
                    });
                    [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[-] action '%@' performed with delay %lu ms", matchedAction.title, delay_ms]];
                } else {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.33f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [dialogController dialogView:dialogView didSelectActionAtIndex:matchedActionIndex withInputText:newInputText passwordText:newPasswordText];
                    });
                    [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[-] action '%@' performed immediately", matchedAction.title]];
                }

                return YES;
            }
        } else {
            [self alertHelperLogDialogObject:@"[-] `action` is not defined or invalid"];
        }

        return NO;
    }
}

+ (void)alertHelperProcessSafariDialogController:(SFDialogController *)dialogController withDialogView:(SFDialogView *)dialogView {
    assert([NSThread isMainThread]);

    @autoreleasepool {
        BOOL hasRegistration = NO;
        for (NSSet *wrapperSet in __local_AlertHelperRegisteredWrappers) {
            for (AHWeakObjectWrapper *wrapper in [wrapperSet objectEnumerator]) {
                if (wrapper.weakObject == dialogController || wrapper.weakObject == dialogView) {
                    hasRegistration = YES;
                    break;
                }
            }
        }
        if (!hasRegistration) {
            AHWeakObjectWrapper *wrapper1 = [[AHWeakObjectWrapper alloc] initWithWeakObject:dialogController];
            AHWeakObjectWrapper *wrapper2 = [[AHWeakObjectWrapper alloc] initWithWeakObject:dialogView];
            [__local_AlertHelperRegisteredWrappers addObject:[NSSet setWithObjects:wrapper1, wrapper2, nil]];
        }
        [self alertHelperRemoveOutdatedRegistration];

        // alert helper: dump dialog
        if (__option_AlertHelperDumpEnabled) {
            [self alertHelperLogDialogObject:[self alertHelperGetDictionaryFromSafariDialogController:dialogController withDialogView:dialogView]];
        } // end should dump

        // alert helper: auto bypass
        if (__option_AlertHelperAutoBypassEnabled) {

            SFDialogContentView *contentView = [dialogView valueForKey:@"_contentView"];
            NSArray <SFDialogAction *> *alertActions = [contentView valueForKey:@"_actions"];
            SFDialogAction *autoAction = alertActions.firstObject;

            if (autoAction) {
                NSUInteger autoActionIndex = [alertActions indexOfObject:autoAction];
                if (autoActionIndex != NSNotFound) {
                    NSTimeInterval delay = __option_AlertHelperAutoBypassDelay;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [dialogController dialogView:dialogView didSelectActionAtIndex:autoActionIndex withInputText:@"" passwordText:@""];
                    });
                    [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[!] auto bypass: %@", autoAction.title]];
                }
            }

            return;
        }

        // alert helper: dialog rules
        NSArray <NSDictionary *> *dialogRules = [self alertHelperDialogRules];
        if (dialogRules.count > 0) {
            NSDictionary *applyRule = nil;
            {
                SFDialogContentView *contentView = [dialogView valueForKey:@"_contentView"];
                SFDialogTextView *messageTextView = [contentView valueForKey:@"_messageTextView"];
                NSString *alertTitle = [messageTextView valueForKey:@"_title"];
                NSString *alertMessage = [messageTextView valueForKey:@"_message"];
                for (NSUInteger ruleIndex = 0; ruleIndex < dialogRules.count; ruleIndex++) {
                    @autoreleasepool {
                        NSDictionary *dialogRule = dialogRules[ruleIndex];
                        [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[?] try to match: rule #%lu", ruleIndex]];
                        if (![dialogRule[@"class"] isKindOfClass:[NSString class]] &&
                            ![dialogRule[@"title"] isKindOfClass:[NSString class]] &&
                            ![dialogRule[@"message"] isKindOfClass:[NSString class]] &&
                            ![dialogRule[@"style"] isKindOfClass:[NSString class]] &&
                            ![dialogRule[@"action"] isKindOfClass:[NSDictionary class]]
                            ) {     // invalid rule
                            [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: invalid rule. `class`, `style`, `action`, `title` or `message` is required", ruleIndex]];
                            continue;
                        }
                        if ([dialogRule[@"class"] isKindOfClass:[NSString class]]) {     // match class
                            NSString *filterClassName = dialogRule[@"class"];
                            NSString *realClassName = NSStringFromClass(dialogController.class);
                            if (![filterClassName isEqualToString:realClassName]) {
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `class` == '%@', but '%@'", ruleIndex, filterClassName, realClassName]];
                                continue;
                            }
                        }
                        if ([dialogRule[@"style"] isKindOfClass:[NSString class]]) {     // match style
                            NSString *filterStyleName = dialogRule[@"style"];
                            NSString *realStyleName = @"alert";
                            if (![filterStyleName isEqualToString:realStyleName]) {
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `style` == '%@', but '%@'", ruleIndex, filterStyleName, realStyleName]];
                                continue;
                            }
                        }
                        if ([dialogRule[@"title"] isKindOfClass:[NSString class]]) {     // regex match title
                            NSString *filterTitleRegex = dialogRule[@"title"];
                            NSString *targetTitle = [NSString stringWithFormat:@"%@", alertTitle];
                            if ([targetTitle rangeOfString:filterTitleRegex options:NSRegularExpressionSearch].location == NSNotFound) {
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `title` satisfy '%@', but '%@'", ruleIndex, filterTitleRegex, targetTitle]];
                                continue;
                            }
                        }
                        if ([dialogRule[@"message"] isKindOfClass:[NSString class]]) {     // regex match message
                            NSString *filterMessageRegex = dialogRule[@"message"];
                            NSString *targetMessage = [NSString stringWithFormat:@"%@", alertMessage];
                            if ([targetMessage rangeOfString:filterMessageRegex options:NSRegularExpressionSearch].location == NSNotFound) {
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `message` satisfy '%@', but '%@'", ruleIndex, filterMessageRegex, targetMessage]];
                                continue;
                            }
                        }
                        if ([dialogRule[@"action"] isKindOfClass:[NSDictionary class]] || [dialogRule[@"action"] isKindOfClass:[NSString class]]) {     // regex find action
                            NSString *targetTitleRegex = nil;
                            if ([dialogRule[@"action"] isKindOfClass:[NSDictionary class]]) {
                                NSDictionary *filterAction = dialogRule[@"action"];
                                targetTitleRegex = filterAction[@"title"];
                            } else {
                                targetTitleRegex = dialogRule[@"action"];
                            }

                            NSMutableArray <NSString *> *actionNames = [NSMutableArray array];
                            SFDialogAction *matchedAction = nil;
                            NSArray <SFDialogAction *> *alertActions = [contentView valueForKey:@"_actions"];
                            if ([targetTitleRegex isKindOfClass:[NSString class]]) {     // regex match action title
                                NSString *filterActionTitleRegex = targetTitleRegex;
                                if (filterActionTitleRegex.length > 0) {
                                    for (NSUInteger actionIndex = 0; actionIndex < alertActions.count; actionIndex++) {
                                        SFDialogAction *alertAction = alertActions[actionIndex];
                                        if ([alertAction.title isKindOfClass:[NSString class]]) {
                                            if ([alertAction.title rangeOfString:filterActionTitleRegex options:NSRegularExpressionSearch].location != NSNotFound) {
                                                matchedAction = alertAction;
                                                break;
                                            }
                                            [actionNames addObject:alertAction.title];
                                        }
                                    }
                                }
                            }
                            if (!matchedAction) {
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. expect `action`.`title` satisfy one of '%@', but '%@'", ruleIndex, actionNames, targetTitleRegex]];
                                continue;
                            }
                        }
                        if ([dialogRule[@"action"] isKindOfClass:[NSNumber class]]) {     // locate action by its index
                            NSNumber *filterAction = dialogRule[@"action"];
                            NSUInteger targetActionIndex = [filterAction unsignedIntegerValue];
                            
                            if (targetActionIndex > 0) {
                                targetActionIndex -= 1;  // adopt lua index
                            }

                            SFDialogAction *matchedAction = nil;
                            NSArray <SFDialogAction *> *alertActions = [contentView valueForKey:@"_actions"];
                            if (targetActionIndex < alertActions.count) {
                                matchedAction = [alertActions objectAtIndex:targetActionIndex];
                            }
                            if (!matchedAction) {
                                [self alertHelperLogDialogObject:[NSString stringWithFormat:@"\t[x] rule #%lu: not matched. index of `action` %lu out of range 0..<%lu", ruleIndex, targetActionIndex, alertActions.count]];
                                continue;
                            }
                        }
                        
                        [self alertHelperLogDialogObject:[NSString stringWithFormat:@"[!] matched: rule #%lu", ruleIndex]];
                        applyRule = dialogRule;
                        break;
                    }
                }     // end rule select loop
            }

            if (applyRule) {
                [self alertHelperDismissSafariDialogController:dialogController withDialogView:dialogView withRule:applyRule];
            }
        } // end has rule
    }
}

+ (void)alertHelperShowPromptWithTitle:(NSString *)title
                               Message:(NSString *)message
                    DefaultButtonTitle:(NSString *)defaultButtonTitle
                               Timeout:(NSTimeInterval)timeout
{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_mutex_init(&__global_AlertHelperDialogNotificationLock, NULL);
    });

    [self alertHelperHidePrompt];

    SInt32 error;
    CFMutableDictionaryRef dialogDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (title.length > 0) {
        CFDictionarySetValue(dialogDict, kCFUserNotificationAlertHeaderKey, (__bridge CFStringRef)(title));
    }
    if (message.length > 0) {
        CFDictionarySetValue(dialogDict, kCFUserNotificationAlertMessageKey, (__bridge CFStringRef)(message));
    }
    CFOptionFlags flags = kCFUserNotificationPlainAlertLevel | kCFUserNotificationNoDefaultButtonFlag;
    if (defaultButtonTitle.length > 0) {
        CFDictionarySetValue(dialogDict, kCFUserNotificationDefaultButtonTitleKey, (__bridge CFStringRef)(defaultButtonTitle));
        flags = kCFUserNotificationPlainAlertLevel;
    }

    /// TODO: other buttons / text fields / responses
    CFDictionarySetValue(dialogDict, kCFUserNotificationAlertTopMostKey, kCFBooleanFalse);
    // not a top level prompt: only available for middle man

    pthread_mutex_lock(&__global_AlertHelperDialogNotificationLock);
    __global_AlertHelperDialogNotification = CFUserNotificationCreate(kCFAllocatorSystemDefault, timeout < 0.1 ? 0 : timeout, flags, &error, dialogDict);
    pthread_mutex_unlock(&__global_AlertHelperDialogNotificationLock);

    CFRelease(dialogDict);
}

+ (void)alertHelperHidePrompt {
    pthread_mutex_lock(&__global_AlertHelperDialogNotificationLock);
    if (__global_AlertHelperDialogNotification) {
        CFUserNotificationCancel(__global_AlertHelperDialogNotification);
        CFRelease(__global_AlertHelperDialogNotification);
        __global_AlertHelperDialogNotification = NULL;
    }
    pthread_mutex_unlock(&__global_AlertHelperDialogNotificationLock);
}

+ (NSDictionary *)alertHelperGetDictionaryFromWrapperSet:(NSSet *)wrapperSet {
    @autoreleasepool {
        if (wrapperSet.count == 1) {
            AHWeakObjectWrapper *wrapper = [wrapperSet anyObject];
            if ([wrapper.weakObject isKindOfClass:[UIAlertController class]]) {
                return [self alertHelperGetDictionaryFromAlertController:(UIAlertController *)wrapper.weakObject];
            }
        } else if (wrapperSet.count == 2) {
            SFDialogController *dialogController = nil;
            SFDialogView *dialogView = nil;
            for (AHWeakObjectWrapper *wrapper in [wrapperSet objectEnumerator]) {
                @autoreleasepool {
                    if ([wrapper.weakObject isKindOfClass:NSClassFromString(@"SFDialogController")]) {
                        dialogController = (SFDialogController *)wrapper.weakObject;
                    } else if ([wrapper.weakObject isKindOfClass:NSClassFromString(@"SFDialogView")]) {
                        dialogView = (SFDialogView *)wrapper.weakObject;
                    }
                }
            }
            if (dialogController != nil && dialogView != nil) {
                return [self alertHelperGetDictionaryFromSafariDialogController:dialogController withDialogView:dialogView];
            }
        }
        return nil;
    }
}

+ (BOOL)alertHelperFulfillWrapperSet:(NSSet *)wrapperSet withRule:(NSDictionary *)applyRule {
    @autoreleasepool {
        if (wrapperSet.count == 1) {
            AHWeakObjectWrapper *wrapper = [wrapperSet anyObject];
            if ([wrapper.weakObject isKindOfClass:[UIAlertController class]]) {
                return [self alertHelperDismissAlertController:(UIAlertController *)wrapper.weakObject withRule:applyRule];
            }
        } else if (wrapperSet.count == 2) {
            SFDialogController *dialogController = nil;
            SFDialogView *dialogView = nil;
            for (AHWeakObjectWrapper *wrapper in [wrapperSet objectEnumerator]) {
                @autoreleasepool {
                    if ([wrapper.weakObject isKindOfClass:NSClassFromString(@"SFDialogController")]) {
                        dialogController = (SFDialogController *)wrapper.weakObject;
                    } else if ([wrapper.weakObject isKindOfClass:NSClassFromString(@"SFDialogView")]) {
                        dialogView = (SFDialogView *)wrapper.weakObject;
                    }
                }
            }
            if (dialogController != nil && dialogView != nil) {
                return [self alertHelperDismissSafariDialogController:dialogController withDialogView:dialogView withRule:applyRule];
            }
        }
        return NO;
    }
}


IMP_XPC_HANDLER(ClientInputText);
IMP_XPC_HANDLER_TIMEOUT(ClientShake, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientSetOrientation, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientShowPrompt, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientHidePrompt, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientSuspend, 3.0);

IMP_XPC_HANDLER_TIMEOUT(ClientGetTopMostDialog, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientDismissTopMostDialog, 3.0);

NS_INLINE double _DTXRandomNumber(double minValue, double maxValue)
{
    return minValue + arc4random_uniform(maxValue - minValue + 1);
}

NS_INLINE void _DTXTypeSentence(NSString *sentence, NSTimeInterval maxInterval)
{
    UIKeyboardImpl *impl = [objc_getClass("UIKeyboardImpl") activeInstance];
    NSUInteger rangeIdx = 0;
    while (rangeIdx < sentence.length)
    {
        @autoreleasepool {
            NSRange range = [sentence rangeOfComposedCharacterSequenceAtIndex:rangeIdx];
            NSString *grapheme = [sentence substringWithRange:range];
            
            [impl setShift:NO autoshift:NO];
            [impl.taskQueue performTask:^(id ctx) {
                [impl handleKeyWithString:grapheme forKeyEvent:nil executionContext:ctx];
                
                NSArray <NSNumber *> *sounds = @[@1104, @1155, @1156];
                AudioServicesPlaySystemSound([sounds[grapheme.hash % 3] unsignedIntValue]);
            }];

            [impl.taskQueue waitUntilAllTasksAreFinished];
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:_DTXRandomNumber(0.05, MAX(MIN(maxInterval, 0.5), 0.1))]];
            [impl removeCandidateList];
            
            rangeIdx += range.length;
        }
    }
}

NS_INLINE void _DTXTypeParagraph(NSString *paragraph, NSTimeInterval maxInterval)
{
    CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (__bridge CFStringRef)paragraph, CFRangeMake(0, paragraph.length), kCFStringTokenizerUnitWord, nil);
    CFStringTokenizerTokenType tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
    if (tokenType == kCFStringTokenizerTokenNone) {
        CFRelease(tokenizer);
        return;
    }
    
    CFRange sentenceRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
    while (sentenceRange.length > 0) {
        @autoreleasepool {
            NSString *sentence;
            NSUInteger lastLocation;
            
            sentence = [paragraph substringWithRange:NSMakeRange(sentenceRange.location, sentenceRange.length)];
            lastLocation = sentenceRange.location + sentenceRange.length;
            _DTXTypeSentence(sentence, maxInterval);
            
            // move to next sentence
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
            if (tokenType != kCFStringTokenizerTokenNone) {
                sentenceRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
                
                // input characters between words
                sentence = [paragraph substringWithRange:NSMakeRange(lastLocation, sentenceRange.location - lastLocation)];
                _DTXTypeSentence(sentence, maxInterval);
                
            } else {
                
                // input characters left
                sentence = [paragraph substringWithRange:NSMakeRange(lastLocation, paragraph.length - lastLocation)];
                _DTXTypeSentence(sentence, maxInterval);
                
                break;
            }
            
            // have a rest between sentence
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:_DTXRandomNumber(0.2, 0.5)]];
        }
    }
    
    CFRelease(tokenizer);
}

- (NSDictionary *)handleRemoteActionWithRequest:(NSDictionary *)request {
    if (![UIApplication sharedApplication]) { return nil; }
    
    NSString *actionName = request[@"action"];

    if ([actionName isEqualToString:@"ClientShowPrompt"]) {
        @autoreleasepool {
            [TFLuaBridge alertHelperShowPromptWithTitle:request[@"data"][@"promptTitle"] ?: @""
                                                Message:request[@"data"][@"promptMessage"] ?: @""
                                     DefaultButtonTitle:request[@"data"][@"promptDefaultButtonTitle"] ?: @""
                                                Timeout:[(NSNumber *)request[@"data"][@"promptTimeout"] doubleValue]
            ];

            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    } else if ([actionName isEqualToString:@"ClientHidePrompt"]) {
        @autoreleasepool {
            [TFLuaBridge alertHelperHidePrompt];

            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    } else if ([actionName isEqualToString:@"ClientInputText"]) {
        @autoreleasepool {
            UIWindow *foundWindow = nil;
            NSArray <UIWindow *> *windows = [[UIApplication sharedApplication] windows];
            for (UIWindow *window in windows) {
                if (window.isKeyWindow) {
                    foundWindow = window;
                    break;
                }
            }
            
            id firstResponder = foundWindow.firstResponder;
            if (![firstResponder conformsToProtocol:@protocol(UITextInput)])
            {
                return @{
                    @"code": @(404),
                    @"msg": [NSString stringWithFormat:@"First responder “%@” does not conform to “UITextInput” protocol", firstResponder],
                    @"data": @{},
                };
            }
            
            NSString *inputString = request[@"data"][@"inputString"] ?: @"";
            NSTimeInterval inputInterval = [request[@"data"][@"inputInterval"] doubleValue];
            
            CHDebugLogSource(@"ClientInputText: %@ @ %.2fs", inputString, inputInterval);
            
            _DTXTypeParagraph(inputString, inputInterval);
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    } else if ([actionName isEqualToString:@"ClientSetOrientation"]) {
        @autoreleasepool {
            UIDeviceOrientation deviceOrientation = (UIDeviceOrientation)[request[@"data"][@"deviceOrientation"] integerValue];
            
            if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone && [[NSBundle.mainBundle objectForInfoDictionaryKey:@"UIRequiresFullScreen"] boolValue] == NO)
            {
                return @{
                    @"code": @(404),
                    @"msg": @"Setting device orientation is only supported for iPhone devices, or for apps declared as requiring full screen on iPad.",
                    @"data": @{},
                };
            }
            
            [[UIDevice currentDevice] setOrientation:deviceOrientation animated:YES];
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    } else if ([actionName isEqualToString:@"ClientShake"]) {
        @autoreleasepool {
            UIApplication *application = UIApplication.sharedApplication;
            UIMotionEvent *motionEvent = [application _motionEvent];
            
            [motionEvent setShakeState:1];
            [motionEvent _setSubtype:UIEventSubtypeMotionShake];
            [application sendEvent:motionEvent];
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    } else if ([actionName isEqualToString:@"ClientGetTopMostDialog"]) {
        @autoreleasepool {
            [TFLuaBridge alertHelperRemoveOutdatedRegistration];

            assert([NSThread isMainThread]);

            NSSet *lastWrapperSet = [__local_AlertHelperRegisteredWrappers lastObject];
            if (!lastWrapperSet) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }

            NSDictionary *retVal = [TFLuaBridge alertHelperGetDictionaryFromWrapperSet:lastWrapperSet];
            if (!retVal) {
                return @{
                    @"code": @(500),
                    @"msg": @"Internal Server Error",
                    @"data": @{},
                };
            }

            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": retVal,
            };
        }
    } else if ([actionName isEqualToString:@"ClientDismissTopMostDialog"]) {
        @autoreleasepool {
            [TFLuaBridge alertHelperRemoveOutdatedRegistration];

            assert([NSThread isMainThread]);
            NSDictionary *applyRule = request[@"data"][@"applyRule"];
            
            NSSet *lastWrapperSet = [__local_AlertHelperRegisteredWrappers lastObject];
            if (!lastWrapperSet) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            BOOL retVal = [TFLuaBridge alertHelperFulfillWrapperSet:lastWrapperSet withRule:applyRule];
            if (!retVal) {
                return @{
                    @"code": @(500),
                    @"msg": @"Internal Server Error",
                    @"data": @{},
                };
            }

            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    } else if ([actionName isEqualToString:@"ClientSuspend"]) {
        @autoreleasepool {
            [[UIApplication sharedApplication] performSelector:@selector(suspend)];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] performSelector:@selector(terminateWithSuccess)];
            });
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    }

    return nil;
}

@end


#pragma mark -


IMP_LUA_HANDLER(enable_logging) {
    @autoreleasepool {
        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"loggingEnabled": @(YES) } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}

IMP_LUA_HANDLER(disable_logging) {
    @autoreleasepool {
        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"loggingEnabled": @(NO) } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}

IMP_LUA_HANDLER(enable_auto_bypass) {
    @autoreleasepool {
        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"autoBypassEnabled": @(YES) } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}

IMP_LUA_HANDLER(disable_auto_bypass) {
    @autoreleasepool {
        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"autoBypassEnabled": @(NO) } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}

IMP_LUA_HANDLER(set_auto_bypass_delay) {
    @autoreleasepool {
        lua_Number cDelay = luaL_checknumber(L, 1);
        
        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"autoBypassDelay": @(cDelay < 100.0 ? 1.0 : cDelay / 1000.0) } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}

IMP_LUA_HANDLER(get_local_dialog_rules) {
    @autoreleasepool {
        const char *objectId = luaL_checkstring(L, 1);
        NSString *bundleIdentifier = [NSString stringWithUTF8String:objectId];

        NSError *error = nil;
        NSDictionary *userDefaults = [[TFLuaBridge sharedInstance] readDefaultsWithError:&error];
        if (![userDefaults isKindOfClass:[NSDictionary class]]) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        NSArray <NSDictionary *> *dialogRules = [userDefaults objectForKey:bundleIdentifier] ?: @[];
        lua_pushNSValuex(L, dialogRules, 0);
        return 1;
    }
}

IMP_LUA_HANDLER(set_local_dialog_rules) {
    @autoreleasepool {
        const char *objectId = luaL_checkstring(L, 1);
        NSString *bundleIdentifier = [NSString stringWithUTF8String:objectId];

        NSArray <NSDictionary *> *dialogRules = lua_toNSValuex(L, 2, 0);
        if (
            (![dialogRules isKindOfClass:[NSArray class]] && ![dialogRules isKindOfClass:[NSDictionary class]]) ||
            ([dialogRules isKindOfClass:[NSDictionary class]] && [dialogRules count] > 0)
            ) {
            return luaL_argerror(L, 2, "array expected");
        }

        if ([dialogRules count] == 0) {
            dialogRules = @[];
        }

        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ bundleIdentifier: dialogRules } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}

IMP_LUA_HANDLER(clear_local_dialog_rules) {
    @autoreleasepool {
        const char *objectId = luaL_checkstring(L, 1);
        NSString *bundleIdentifier = [NSString stringWithUTF8String:objectId];
        
        if ([bundleIdentifier isEqualToString:@"*"]) {
            NSError *error = nil;
            NSMutableDictionary *mUserDefaults = [[[TFLuaBridge sharedInstance] readDefaultsWithError:&error] mutableCopy] ?: [[NSMutableDictionary alloc] init];
            NSArray <NSString *> *preservedKeys = @[
                @"__GLOBAL__", @"loggingEnabled", @"autoBypassEnabled", @"autoBypassDelay",
            ];
            NSMutableArray <NSString *> *keysToRemove = [NSMutableArray arrayWithCapacity:mUserDefaults.count];
            for (NSString *userDefaultKey in mUserDefaults) {
                if (![preservedKeys containsObject:userDefaultKey]) {
                    [keysToRemove addObject:userDefaultKey];
                }
            }
            [mUserDefaults removeObjectsForKeys:keysToRemove];
            BOOL retVal = [[TFLuaBridge sharedInstance] writeDefaults:mUserDefaults withError:&error];
            if (!retVal) {
                return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
            }
        } else {
            NSError *error = nil;
            BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ bundleIdentifier: @[] } withError:&error];
            if (!retVal) {
                return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
            }
        }

        return 0;
    }
}

IMP_LUA_HANDLER(get_global_dialog_rules) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *userDefaults = [[TFLuaBridge sharedInstance] readDefaultsWithError:&error];
        if (![userDefaults isKindOfClass:[NSDictionary class]]) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        NSArray <NSDictionary *> *dialogRules = [userDefaults objectForKey:@"__GLOBAL__"] ?: @[];
        lua_pushNSValuex(L, dialogRules, 0);
        return 1;
    }
}

IMP_LUA_HANDLER(set_global_dialog_rules) {
    @autoreleasepool {
        NSArray <NSDictionary *> *dialogRules = lua_toNSValuex(L, 1, 0);
        if (
            (![dialogRules isKindOfClass:[NSArray class]] && ![dialogRules isKindOfClass:[NSDictionary class]]) ||
            ([dialogRules isKindOfClass:[NSDictionary class]] && [dialogRules count] > 0)
            ) {
            return luaL_argerror(L, 1, "array expected");
        }

        if ([dialogRules count] == 0) {
            dialogRules = @[];
        }

        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"__GLOBAL__": dialogRules } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}

IMP_LUA_HANDLER(clear_global_dialog_rules) {
    @autoreleasepool {
        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"__GLOBAL__": @[] } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}


#pragma mark -

#define AHERR_INVALID_ORIENTATION \
    "Invalid orientation %I, available values are:" "\n" \
    "  * Home on bottom = 0" "\n" \
    "  * Home on right = 1" "\n" \
    "  * Home on left = 2" "\n" \
    "  * Home on top = 3"

IMP_LUA_HANDLER(input_text) {
    @autoreleasepool {
        
        const char *cInput = luaL_checkstring(L, 1);
        NSString *inputString = [NSString stringWithUTF8String:cInput];
        
        if (!inputString.length) {
            lua_pushboolean(L, true);
            lua_pushnil(L);
            return 2;
        }

        lua_Number cInterval = luaL_optnumber(L, 2, 0);
        cInterval /= 1e3;
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientInputText:@{ @"inputString": inputString, @"inputInterval": @(cInterval) } error:&error];
        
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushboolean(L, false);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

IMP_LUA_HANDLER(shake) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientShake:@{} error:&error];
        
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushboolean(L, false);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

IMP_LUA_HANDLER(set_orientation) {
    @autoreleasepool {
        lua_Integer lOrientation = luaL_checkinteger(L, 1);
        
        if (lOrientation < 0 || lOrientation > 5) {
            return luaL_error(L, AHERR_INVALID_ORIENTATION, lOrientation);
        }
        
        UIDeviceOrientation dOrientation;
        if (lOrientation == 1) {
            dOrientation = UIDeviceOrientationLandscapeLeft;
        } else if (lOrientation == 2) {
            dOrientation = UIDeviceOrientationLandscapeRight;
        } else if (lOrientation == 3) {
            dOrientation = UIDeviceOrientationPortraitUpsideDown;
        } else if (lOrientation == 4) {
            dOrientation = UIDeviceOrientationFaceUp;
        } else if (lOrientation == 5) {
            dOrientation = UIDeviceOrientationFaceDown;
        } else {
            dOrientation = UIDeviceOrientationPortrait;
        }
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientSetOrientation:@{
            @"deviceOrientation": @(dOrientation),
        } error:&error];
        
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushboolean(L, false);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

#if DEBUG
IMP_LUA_HANDLER(show_prompt) {
    @autoreleasepool {
        NSMutableDictionary *mPayload = [NSMutableDictionary dictionaryWithCapacity:4];

        const char *cHead = luaL_checkstring(L, 1);
        const char *cBody = luaL_optstring(L, 2, NULL);
        const char *cBtn = luaL_optstring(L, 3, NULL);
        lua_Number cInterval = luaL_optnumber(L, 4, 0);

        NSString *msgHead = [NSString stringWithUTF8String:cHead];
        [mPayload setObject:msgHead forKey:@"promptTitle"];

        if (cBody) {
            NSString *msgBody = [NSString stringWithUTF8String:cBody];
            [mPayload setObject:msgBody forKey:@"promptMessage"];
        }

        if (cBtn) {
            NSString *msgBtn = [NSString stringWithUTF8String:cBtn];
            [mPayload setObject:msgBtn forKey:@"promptDefaultButtonTitle"];
        }

        [mPayload setObject:@(cInterval < 100.0 ? 0 : cInterval / 1000.0) forKey:@"promptTimeout"];

        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientShowPrompt:mPayload error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}
#endif

#if DEBUG
IMP_LUA_HANDLER(hide_prompt) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientHidePrompt:@{} error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        return 0;
    }
}
#endif

IMP_LUA_HANDLER(get_top_most_dialog) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientGetTopMostDialog:@{} error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushnil(L);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
        }

        lua_pushNSValuex(L, ret, 0);
        lua_pushnil(L);
        return 2;
    }
}

IMP_LUA_HANDLER(dismiss_top_most_dialog) {
    @autoreleasepool {
        NSDictionary *dictValue = nil;

        int valueType = lua_type(L, 1);
        if (valueType != LUA_TTABLE && valueType != LUA_TSTRING && valueType != LUA_TNUMBER && valueType != LUA_TNONE) {
            luaL_checktype(L, 1, LUA_TTABLE);
            return 0;
        }
        
        if (valueType == LUA_TTABLE) {
            dictValue = lua_toNSValuex(L, 1, 0);
            if (![dictValue isKindOfClass:[NSDictionary class]]) {
                return luaL_argerror(L, 1, "dictionary expected");
            }
            
            if (![dictValue objectForKey:@"action"]) {
                dictValue = @{ @"action": dictValue };
            }
        }
        else if (valueType == LUA_TSTRING) {
            const char *cValue = luaL_checkstring(L, 1);
            dictValue = @{ @"action": [NSString stringWithUTF8String:cValue] };
        }
        else if (valueType == LUA_TNUMBER) {
            lua_Integer cValue = luaL_checkinteger(L, 1);
            dictValue = @{ @"action": @(cValue) };  // already adopted lua syntax
        }
        
        if (!dictValue) {
            dictValue = @{ @"action": @(0) };  // 0 has the same effect to 1
        }

        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientDismissTopMostDialog:@{ @"applyRule": dictValue } error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushboolean(L, false);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
        }

        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

IMP_LUA_HANDLER(suspend) {
    @autoreleasepool {
        const char *cBundleIdentifier = luaL_checkstring(L, 1);
        NSString *bundleIdentifier = [NSString stringWithUTF8String:cBundleIdentifier];

        if (![bundleIdentifier isEqualToString:@"*"]) {
            if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:bundleIdentifier]) {
                lua_pushboolean(L, false);
                lua_pushstring(L, "bundle identifier mismatch");
                return 2;
            }
        }

        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientSuspend:@{} error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushboolean(L, false);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }

        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

IMP_LUA_HANDLER_MAP[] = {

    /* logging */
    DECLARE_LUA_HANDLER(enable_logging),
    DECLARE_LUA_HANDLER(disable_logging),

    /* auto bypass */
    DECLARE_LUA_HANDLER(enable_auto_bypass),
    DECLARE_LUA_HANDLER(disable_auto_bypass),
    DECLARE_LUA_HANDLER(set_auto_bypass_delay),

    /* local dialog rules */
    DECLARE_LUA_HANDLER(get_local_dialog_rules),
    DECLARE_LUA_HANDLER(set_local_dialog_rules),
    DECLARE_LUA_HANDLER(clear_local_dialog_rules),

    /* global dialog rules */
    DECLARE_LUA_HANDLER(get_global_dialog_rules),
    DECLARE_LUA_HANDLER(set_global_dialog_rules),
    DECLARE_LUA_HANDLER(clear_global_dialog_rules),

    /* app.input_text */
    DECLARE_LUA_HANDLER(input_text),
    
    /* app.shake */
    DECLARE_LUA_HANDLER(shake),
    
    /* app.set_orientation */
    DECLARE_LUA_HANDLER(set_orientation),
    
    /* app.suspend */
    DECLARE_LUA_HANDLER(suspend),

    /* real-time handler */
    DECLARE_LUA_HANDLER(get_top_most_dialog),
    DECLARE_LUA_HANDLER(dismiss_top_most_dialog),

#if DEBUG
    /* global prompt */
    DECLARE_LUA_HANDLER(show_prompt),
    DECLARE_LUA_HANDLER(hide_prompt),
#endif

    DECLARE_NULL
};


#pragma mark -


static void (*original_UIAlertController_viewDidAppear_)(id self, SEL _cmd, BOOL animated);
static void replaced_UIAlertController_viewDidAppear_(id self, SEL _cmd, BOOL animated) {
    original_UIAlertController_viewDidAppear_(self, _cmd, animated);
    [TFLuaBridge alertHelperProcessAlertController:self];
}

static void (*original_UIAlertController_viewDidDisappear_)(id self, SEL _cmd, BOOL animated);
static void replaced_UIAlertController_viewDidDisappear_(id self, SEL _cmd, BOOL animated) {
    original_UIAlertController_viewDidDisappear_(self, _cmd, animated);

    assert([NSThread isMainThread]);
    @autoreleasepool {
        NSMutableArray <NSSet *> *identicalSets = [NSMutableArray arrayWithCapacity:__local_AlertHelperRegisteredWrappers.count];
        for (NSUInteger idx = 0; idx < __local_AlertHelperRegisteredWrappers.count; idx++) {
            NSSet *wrapperSet = __local_AlertHelperRegisteredWrappers[idx];
            AHWeakObjectWrapper *wrapper = [wrapperSet anyObject];
            if (wrapper.weakObject == self) {
                [identicalSets addObject:wrapperSet];
            }
        }
        [__local_AlertHelperRegisteredWrappers removeObjectsInArray:identicalSets];
    }
}

static void (*original__SFWebView_presentDialogView_withAdditionalAnimations_forDialogController_)(id self, SEL _cmd, SFDialogView *arg1, id arg2, SFDialogController *arg3);
static void replaced__SFWebView_presentDialogView_withAdditionalAnimations_forDialogController_(id self, SEL _cmd, SFDialogView *arg1, id arg2, SFDialogController *arg3) {
    original__SFWebView_presentDialogView_withAdditionalAnimations_forDialogController_(self, _cmd, arg1, arg2, arg3);
    [TFLuaBridge alertHelperProcessSafariDialogController:arg3 withDialogView:arg1];
}


#pragma mark -

OBJC_EXTERN void SetupAlertHelper(void);
void SetupAlertHelper() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __local_AlertHelperRegisteredWrappers = [[NSMutableArray alloc] init];
    });

    [TFLuaBridge setSharedInstanceName:@XPC_INSTANCE_NAME];

    TFLuaBridge *bridge = [TFLuaBridge sharedInstance];
    if (bridge.instanceRole == TFLuaBridgeRoleClient || bridge.instanceRole == TFLuaBridgeRoleMiddleMan) {
        MyHookMessage(
            _cc(UIAlertController),
            @selector(viewDidAppear:),
            (IMP)replaced_UIAlertController_viewDidAppear_,
            (IMP *)&original_UIAlertController_viewDidAppear_
            );
        MyHookMessage(
            _cc(UIAlertController),
            @selector(viewDidDisappear:),
            (IMP)replaced_UIAlertController_viewDidDisappear_,
            (IMP *)&original_UIAlertController_viewDidDisappear_
            );

#if DEBUG
        NSLog(@"[%@][Client #2] Objective-C message hooks initialized for UIAlertController", @XPC_INSTANCE_NAME);
#endif

        if (_cc(_SFWebView)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            MyHookMessage(
                _cc(_SFWebView),
                @selector(presentDialogView:withAdditionalAnimations:forDialogController:),
                (IMP)replaced__SFWebView_presentDialogView_withAdditionalAnimations_forDialogController_,
                (IMP *)&original__SFWebView_presentDialogView_withAdditionalAnimations_forDialogController_
                );
#pragma clang diagnostic pop

#if DEBUG
            NSLog(@"[%@][Client #2] Objective-C message hooks initialized for _SFWebView", @XPC_INSTANCE_NAME);
#endif
        }

        {
            NSError *defaultsError = nil;
            NSDictionary *userDefaults = [bridge readDefaultsWithError:&defaultsError];
            if ([userDefaults isKindOfClass:[NSDictionary class]]) {
                __option_AlertHelperDumpEnabled = [userDefaults[@"loggingEnabled"] boolValue];
                __option_AlertHelperAutoBypassEnabled = [userDefaults[@"autoBypassEnabled"] boolValue];
                __option_AlertHelperAutoBypassDelay = [userDefaults objectForKey:@"autoBypassDelay"] ? [userDefaults[@"autoBypassDelay"] doubleValue] : 1.0;
            }
        }
    }
}

static void _DTXFixupKeyboard(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static char const *const controllerPrefBundlePath = "/System/Library/PrivateFrameworks/TextInput.framework/TextInput";
        __unused void *handle = dlopen(controllerPrefBundlePath, RTLD_LAZY);
        
        TIPreferencesController *controller = [objc_getClass("TIPreferencesController") sharedPreferencesController];
        if ([controller respondsToSelector:@selector(setAutocorrectionEnabled:)] == YES) {
            controller.autocorrectionEnabled = NO;
        }
        else {
            [controller setValue:@NO forPreferenceKey:@"KeyboardAutocorrection"];
        }
        
        if ([controller respondsToSelector:@selector(setPredictionEnabled:)]) {
            controller.predictionEnabled = NO;
        }
        else {
            [controller setValue:@NO forPreferenceKey:@"KeyboardPrediction"];
        }
        
        [controller setValue:@YES forPreferenceKey:@"DidShowGestureKeyboardIntroduction"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            [controller setValue:@YES forPreferenceKey:@"DidShowContinuousPathIntroduction"];
        }
        
        [controller synchronizePreferences];
    });
}

CHConstructor {
    @autoreleasepool {
        do {
            
            /// do not inject protected executable
            if (dlsym(NULL, "plugin_i_love_xxtouch")) {
                break;
            }
            
            /// do not inject executable without bundle
            NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
            if (!bundleIdentifier) {
                break;
            }

            /// do not inject CN products
#if DEBUG
            NSArray <NSString *> *blacklistCNProducts
                = @[
                      @"tmall", @"baidu", @"qq", @"sohu", @"taobao",
                      @"360", @"jd", @"weibo", @"sina", @"alipay",
                      @"csdn", @"1688", @"bilibili", @"cnblogs",
                      @"aliyun", @"iqiyi", @"163", @"zhihu", @"douban",
                      @"10086", @"189", @"toutiao", @"youku",
                      @"pinduoduo", @"alibaba", @"tencent",
                      @"kuaishou", @"huoshan", @"douyin", @"tiktok",
                      @"so", @"chinaz", @"jianshu",
                      @"darwindev", @"xxtou", @"darwindev",
                ];
            NSArray <NSString *> *bundleIdentifierComponents = [bundleIdentifier componentsSeparatedByString:@"."];
            BOOL isInBlacklist = NO;
            for (NSString *bundleIdentifierComponent in bundleIdentifierComponents) {
                if ([blacklistCNProducts containsObject:bundleIdentifierComponent]) {
                    isInBlacklist = YES;
                    break;
                }
            }
            if (isInBlacklist) {
                break;
            }
#endif

            /// do not inject apple products
            BOOL isAppleProduct = [bundleIdentifier hasPrefix:@"com.apple."];
            if (isAppleProduct && ![[TFLuaBridge allowedAppleProductBundleIDs] containsObject:bundleIdentifier]) {
                break;
            }

            /// just do it
            SetupAlertHelper();

            /// fix up keyboard
            _DTXFixupKeyboard();
        } while (NO);
    }
}

LuaConstructor {
    SetupAlertHelper();
    lua_createtable(L, 0, (sizeof(DECLARE_LUA_HANDLER_MAP) / sizeof((DECLARE_LUA_HANDLER_MAP)[0]) - 1) + 6);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    lua_pushinteger(L, 0);
    lua_setfield(L, -2, "ORIENTATION_HOME_ON_BOTTOM");
    lua_pushinteger(L, 1);
    lua_setfield(L, -2, "ORIENTATION_HOME_ON_RIGHT");
    lua_pushinteger(L, 2);
    lua_setfield(L, -2, "ORIENTATION_HOME_ON_LEFT");
    lua_pushinteger(L, 3);
    lua_setfield(L, -2, "ORIENTATION_HOME_ON_UP");
    luaL_setfuncs(L, DECLARE_LUA_HANDLER_MAP, 0);
    return 1;
}

