#line 1 "LogosTamperMonkey.xm"
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <pthread.h>
#import "TMWeakViewWrapper.h"
#import "TMWeakObjectWrapper.h"


#pragma mark -

#pragma GCC diagnostic ignored "-Wdeprecated-declarations"


@interface SFBrowserServiceViewController : UIViewController
- (id)_currentWebView;
- (void)_didLoadWebView;
- (void)_dismiss;
- (void)_hostApplicationDidEnterBackground;
- (void)_hostApplicationWillEnterForeground;
- (id)_hostAppBundleId;
@end

BOOL __xpcPauseFlag = NO;
TMWeakViewWrapper *__xpcRemoteViewWrapper = nil;
NSString *__xpcRemoteBundleIdentifier = nil;
pthread_mutex_t __xpcRemoteViewLock;

NSMutableArray <TMWeakObjectWrapper *> *__xpcRemoteControlWrappers = nil;
pthread_mutex_t __xpcRemoteControlLock;


#pragma mark -


#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

@class WKFormSelectControl; @class WKMultipleSelectPicker; @class TabController; @class SFSafariView; @class WKDateTimeInputControl; @class BrowserController; @class _UILayerHostView; @class BrowserWindowController; @class SFBrowserServiceViewController; @class WKDateTimePicker; @class WKFormColorControl; @class WKSelectSinglePicker; @class UIWebView; 


#line 35 "LogosTamperMonkey.xm"
static void (*_logos_orig$SafariXPC$SFBrowserServiceViewController$_dismiss)(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST, SEL); static void _logos_method$SafariXPC$SFBrowserServiceViewController$_dismiss(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$SafariXPC$SFBrowserServiceViewController$_hostApplicationDidEnterBackground)(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST, SEL); static void _logos_method$SafariXPC$SFBrowserServiceViewController$_hostApplicationDidEnterBackground(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$SafariXPC$SFBrowserServiceViewController$_hostApplicationWillEnterForeground)(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST, SEL); static void _logos_method$SafariXPC$SFBrowserServiceViewController$_hostApplicationWillEnterForeground(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$SafariXPC$SFBrowserServiceViewController$_didLoadWebView)(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST, SEL); static void _logos_method$SafariXPC$SFBrowserServiceViewController$_didLoadWebView(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$SafariXPC$SFSafariView$willMoveToWindow$)(_LOGOS_SELF_TYPE_NORMAL SFSafariView* _LOGOS_SELF_CONST, SEL, UIWindow *); static void _logos_method$SafariXPC$SFSafariView$willMoveToWindow$(_LOGOS_SELF_TYPE_NORMAL SFSafariView* _LOGOS_SELF_CONST, SEL, UIWindow *); static _UILayerHostView* (*_logos_orig$SafariXPC$_UILayerHostView$initWithFrame$pid$contextID$)(_LOGOS_SELF_TYPE_INIT _UILayerHostView*, SEL, CGRect, int, unsigned) _LOGOS_RETURN_RETAINED; static _UILayerHostView* _logos_method$SafariXPC$_UILayerHostView$initWithFrame$pid$contextID$(_LOGOS_SELF_TYPE_INIT _UILayerHostView*, SEL, CGRect, int, unsigned) _LOGOS_RETURN_RETAINED; static NSString * _logos_method$SafariXPC$UIWebView$_sf_stringByEvaluatingJavaScriptFromString$error$(_LOGOS_SELF_TYPE_NORMAL UIWebView* _LOGOS_SELF_CONST, SEL, NSString *, NSError * __autoreleasing *); 


static void _logos_method$SafariXPC$SFBrowserServiceViewController$_dismiss(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        __xpcPauseFlag = YES;
        __xpcRemoteViewWrapper = nil;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
    NSLog(@"-[<SFBrowserServiceViewController: %p> _dismiss]", self);
    _logos_orig$SafariXPC$SFBrowserServiceViewController$_dismiss(self, _cmd);
}
static void _logos_method$SafariXPC$SFBrowserServiceViewController$_hostApplicationDidEnterBackground(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        __xpcPauseFlag = YES;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
    NSLog(@"-[<SFBrowserServiceViewController: %p> _hostApplicationDidEnterBackground]", self);
    _logos_orig$SafariXPC$SFBrowserServiceViewController$_hostApplicationDidEnterBackground(self, _cmd);
}
static void _logos_method$SafariXPC$SFBrowserServiceViewController$_hostApplicationWillEnterForeground(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NSLog(@"-[<SFBrowserServiceViewController: %p> _hostApplicationWillEnterForeground]", self);
    _logos_orig$SafariXPC$SFBrowserServiceViewController$_hostApplicationWillEnterForeground(self, _cmd);
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        __xpcPauseFlag = NO;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
}
static void _logos_method$SafariXPC$SFBrowserServiceViewController$_didLoadWebView(_LOGOS_SELF_TYPE_NORMAL SFBrowserServiceViewController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NSLog(@"-[<SFBrowserServiceViewController: %p> _didLoadWebView]", self);
    _logos_orig$SafariXPC$SFBrowserServiceViewController$_didLoadWebView(self, _cmd);
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        __xpcRemoteBundleIdentifier = [self _hostAppBundleId];
        __xpcRemoteViewWrapper = [[TMWeakViewWrapper alloc] initWithWeakView:[self _currentWebView] forUniqueIdentifier:[[NSUUID UUID] UUIDString]];
        __xpcPauseFlag = NO;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
}




static void _logos_method$SafariXPC$SFSafariView$willMoveToWindow$(_LOGOS_SELF_TYPE_NORMAL SFSafariView* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, UIWindow * newWindow) {
    NSLog(@"-[<SFSafariView: %p> willMoveToWindow:%@]", self, newWindow);
    _logos_orig$SafariXPC$SFSafariView$willMoveToWindow$(self, _cmd, newWindow);
    if (newWindow) {
        if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
            __xpcPauseFlag = YES;
            pthread_mutex_unlock(&__xpcRemoteViewLock);
        }
    } else {
        if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
            __xpcPauseFlag = NO;
            pthread_mutex_unlock(&__xpcRemoteViewLock);
        }
    }
}



static _UILayerHostView* _logos_method$SafariXPC$_UILayerHostView$initWithFrame$pid$contextID$(_LOGOS_SELF_TYPE_INIT _UILayerHostView* __unused self, SEL __unused _cmd, CGRect arg1, int arg2, unsigned arg3) _LOGOS_RETURN_RETAINED {
    NSLog(@"-[<_UILayerHostView: %p> initWithFrame:{{%g, %g}, {%g, %g}} pid:%d contextID:%u]", self, arg1.origin.x, arg1.origin.y, arg1.size.width, arg1.size.height, arg2, arg3); return _logos_orig$SafariXPC$_UILayerHostView$initWithFrame$pid$contextID$(self, _cmd, arg1, arg2, arg3);
}



#pragma GCC diagnostic warning "-Wdeprecated-declarations"
#pragma mark -
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"




#define NSERROR_UIWEBVIEW_SCRIPT @"@@NSERROR_UIWEBVIEW_SCRIPT@@"
#define NSERROR_UIWEBVIEW_SCRIPT_CODE 1


static NSString * _logos_method$SafariXPC$UIWebView$_sf_stringByEvaluatingJavaScriptFromString$error$(_LOGOS_SELF_TYPE_NORMAL UIWebView* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSString * script, NSError * __autoreleasing * error) {
    
    NSString *errorPrefix = NSERROR_UIWEBVIEW_SCRIPT;
    NSString *ret = nil;
    
    @autoreleasepool {
        NSData *scriptData = [script dataUsingEncoding:NSUTF8StringEncoding];
        NSString *b64EncodedScript = [scriptData base64EncodedStringWithOptions:kNilOptions];
        NSString *exec = [NSString stringWithFormat:@"try { JSON.stringify(Function(window.atob('%@'))()); } catch (e) { '%@' + e + '%@' + e.stack; }", b64EncodedScript, errorPrefix, errorPrefix, nil];
        ret = [self stringByEvaluatingJavaScriptFromString:exec];
        
        if (![ret hasPrefix:errorPrefix]) {
            return ret;
        }
    }
    
    if (error && self.request.URL) {
        NSError *strongErr = nil;
        @autoreleasepool {
            NSMutableArray <NSString *> *msgList = [[ret componentsSeparatedByString:errorPrefix] mutableCopy];
            [msgList removeObject:@""];
            NSDictionary *userInfo
            = @{
                NSLocalizedDescriptionKey: [msgList firstObject],
                NSFilePathErrorKey:[self.request.URL absoluteString],
                NSURLErrorKey: self.request.URL,
                NSLocalizedFailureReasonErrorKey: [msgList lastObject],
                NSURLErrorFailingURLErrorKey: self.request.URL,
                NSURLErrorFailingURLStringErrorKey: self.request.URL,
            };
            strongErr = [NSError errorWithDomain:NSERROR_UIWEBVIEW_SCRIPT code:NSERROR_UIWEBVIEW_SCRIPT_CODE userInfo:userInfo];
        }
        *error = strongErr;
    }
    
    return nil;
}



  


#pragma mark -

static WKFormSelectControl* (*_logos_orig$WKTesting$WKFormSelectControl$initWithView$)(_LOGOS_SELF_TYPE_INIT WKFormSelectControl*, SEL, UIView *) _LOGOS_RETURN_RETAINED; static WKFormSelectControl* _logos_method$WKTesting$WKFormSelectControl$initWithView$(_LOGOS_SELF_TYPE_INIT WKFormSelectControl*, SEL, UIView *) _LOGOS_RETURN_RETAINED; static WKFormColorControl* (*_logos_orig$WKTesting$WKFormColorControl$initWithView$)(_LOGOS_SELF_TYPE_INIT WKFormColorControl*, SEL, UIView *) _LOGOS_RETURN_RETAINED; static WKFormColorControl* _logos_method$WKTesting$WKFormColorControl$initWithView$(_LOGOS_SELF_TYPE_INIT WKFormColorControl*, SEL, UIView *) _LOGOS_RETURN_RETAINED; static NSDate * _logos_method$WKTesting$WKDateTimePicker$date(_LOGOS_SELF_TYPE_NORMAL WKDateTimePicker* _LOGOS_SELF_CONST, SEL); static void _logos_method$WKTesting$WKDateTimePicker$setDate$(_LOGOS_SELF_TYPE_NORMAL WKDateTimePicker* _LOGOS_SELF_CONST, SEL, NSDate *); static WKDateTimeInputControl* (*_logos_orig$WKTesting$WKDateTimeInputControl$initWithView$)(_LOGOS_SELF_TYPE_INIT WKDateTimeInputControl*, SEL, UIView *) _LOGOS_RETURN_RETAINED; static WKDateTimeInputControl* _logos_method$WKTesting$WKDateTimeInputControl$initWithView$(_LOGOS_SELF_TYPE_INIT WKDateTimeInputControl*, SEL, UIView *) _LOGOS_RETURN_RETAINED; static void _logos_method$WKTesting$WKDateTimeInputControl$setTimePickerDate$(_LOGOS_SELF_TYPE_NORMAL WKDateTimeInputControl* _LOGOS_SELF_CONST, SEL, NSDate *); static NSDate * _logos_method$WKTesting$WKDateTimeInputControl$timePickerValueDate(_LOGOS_SELF_TYPE_NORMAL WKDateTimeInputControl* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$WKTesting$WKSelectSinglePicker$selectRow$inComponent$extendingSelection$)(_LOGOS_SELF_TYPE_NORMAL WKSelectSinglePicker* _LOGOS_SELF_CONST, SEL, NSInteger, NSInteger, BOOL); static void _logos_method$WKTesting$WKSelectSinglePicker$selectRow$inComponent$extendingSelection$(_LOGOS_SELF_TYPE_NORMAL WKSelectSinglePicker* _LOGOS_SELF_CONST, SEL, NSInteger, NSInteger, BOOL); static void (*_logos_orig$WKTesting$WKMultipleSelectPicker$selectRow$inComponent$extendingSelection$)(_LOGOS_SELF_TYPE_NORMAL WKMultipleSelectPicker* _LOGOS_SELF_CONST, SEL, NSInteger, NSInteger, BOOL); static void _logos_method$WKTesting$WKMultipleSelectPicker$selectRow$inComponent$extendingSelection$(_LOGOS_SELF_TYPE_NORMAL WKMultipleSelectPicker* _LOGOS_SELF_CONST, SEL, NSInteger, NSInteger, BOOL); static BOOL (*_logos_orig$WKTesting$WKMultipleSelectPicker$selectFormAccessoryHasCheckedItemAtRow$)(_LOGOS_SELF_TYPE_NORMAL WKMultipleSelectPicker* _LOGOS_SELF_CONST, SEL, long); static BOOL _logos_method$WKTesting$WKMultipleSelectPicker$selectFormAccessoryHasCheckedItemAtRow$(_LOGOS_SELF_TYPE_NORMAL WKMultipleSelectPicker* _LOGOS_SELF_CONST, SEL, long); 

@interface WKFormSelectControl : NSObject
@end


static WKFormSelectControl* _logos_method$WKTesting$WKFormSelectControl$initWithView$(_LOGOS_SELF_TYPE_INIT WKFormSelectControl* __unused self, SEL __unused _cmd, UIView * view) _LOGOS_RETURN_RETAINED {
    if (pthread_mutex_trylock(&__xpcRemoteControlLock) == 0) {
        TMWeakObjectWrapper *wrapper = [[TMWeakObjectWrapper alloc] initWithWeakObject:self];
        [__xpcRemoteControlWrappers addObject:wrapper];
        pthread_mutex_unlock(&__xpcRemoteControlLock);
    }
    NSLog(@"-[<WKFormSelectControl: %p> initWithView:%@]", self, view); return _logos_orig$WKTesting$WKFormSelectControl$initWithView$(self, _cmd, view);
}


@interface WKFormColorControl : NSObject
@end


static WKFormColorControl* _logos_method$WKTesting$WKFormColorControl$initWithView$(_LOGOS_SELF_TYPE_INIT WKFormColorControl* __unused self, SEL __unused _cmd, UIView * view) _LOGOS_RETURN_RETAINED {
    if (pthread_mutex_trylock(&__xpcRemoteControlLock) == 0) {
        TMWeakObjectWrapper *wrapper = [[TMWeakObjectWrapper alloc] initWithWeakObject:self];
        [__xpcRemoteControlWrappers addObject:wrapper];
        pthread_mutex_unlock(&__xpcRemoteControlLock);
    }
    NSLog(@"-[<WKFormColorControl: %p> initWithView:%@]", self, view); return _logos_orig$WKTesting$WKFormColorControl$initWithView$(self, _cmd, view);
}




static NSDate * _logos_method$WKTesting$WKDateTimePicker$date(_LOGOS_SELF_TYPE_NORMAL WKDateTimePicker* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    UIDatePicker *datePicker = MSHookIvar<UIDatePicker *>(self, "_datePicker");
    return [datePicker date];
}

static void _logos_method$WKTesting$WKDateTimePicker$setDate$(_LOGOS_SELF_TYPE_NORMAL WKDateTimePicker* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSDate * date) {
    UIDatePicker *datePicker = MSHookIvar<UIDatePicker *>(self, "_datePicker");
    [datePicker setDate:date];
}


@interface WKDateTimePicker : NSObject
- (NSDate *)date;
- (void)setDate:(NSDate *)date;
- (void)_dateChanged;
@end

@interface WKDateTimeInputControl : NSObject
@property WKDateTimePicker *control;
@end

@interface WKContentView : NSObject
- (void)accessoryDone;
@end


static WKDateTimeInputControl* _logos_method$WKTesting$WKDateTimeInputControl$initWithView$(_LOGOS_SELF_TYPE_INIT WKDateTimeInputControl* __unused self, SEL __unused _cmd, UIView * view) _LOGOS_RETURN_RETAINED {
    if (pthread_mutex_trylock(&__xpcRemoteControlLock) == 0) {
        TMWeakObjectWrapper *wrapper = [[TMWeakObjectWrapper alloc] initWithWeakObject:self];
        [__xpcRemoteControlWrappers addObject:wrapper];
        pthread_mutex_unlock(&__xpcRemoteControlLock);
    }
    NSLog(@"-[<WKDateTimeInputControl: %p> initWithView:%@]", self, view); return _logos_orig$WKTesting$WKDateTimeInputControl$initWithView$(self, _cmd, view);
}

static void _logos_method$WKTesting$WKDateTimeInputControl$setTimePickerDate$(_LOGOS_SELF_TYPE_NORMAL WKDateTimeInputControl* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSDate * date) {
    if ([self.control isKindOfClass:NSClassFromString(@"WKDateTimePicker")]) {
        WKDateTimePicker *picker = (WKDateTimePicker *)self.control;
        [picker setDate:date];
        UIDatePicker *datePicker = MSHookIvar<UIDatePicker *>(picker, "_datePicker");
        [datePicker setDate:date];
        if ([picker respondsToSelector:@selector(_dateChanged)]) {
            [picker _dateChanged];
        }
    }
}

static NSDate * _logos_method$WKTesting$WKDateTimeInputControl$timePickerValueDate(_LOGOS_SELF_TYPE_NORMAL WKDateTimeInputControl* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if ([self.control isKindOfClass:NSClassFromString(@"WKDateTimePicker")]) {
        return [(WKDateTimePicker *)self.control date];
    }
    return nil;
}


@interface WKMultipleSelectPicker : NSObject
- (void)pickerView:(UIPickerView *)pickerView row:(NSInteger)rowIndex column:(NSInteger)columnIndex checked:(BOOL)isChecked;
- (BOOL)selectFormAccessoryHasCheckedItemAtRow:(long)rowIndex;
- (NSInteger)findItemIndexAt:(NSInteger)rowIndex;
- (BOOL)allowsMultipleSelection;
- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection;
@end

@interface WKOptionPickerCell : NSObject
- (BOOL)isChecked;
@end


static void _logos_method$WKTesting$WKSelectSinglePicker$selectRow$inComponent$extendingSelection$(_LOGOS_SELF_TYPE_NORMAL WKSelectSinglePicker* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSInteger rowIndex, NSInteger componentIndex, BOOL extendingSelection) {
    NSLog(@"-[<WKSelectSinglePicker: %p> selectRow:%ld inComponent:%ld extendingSelection:%d]", self, (long)rowIndex, (long)componentIndex, extendingSelection); _logos_orig$WKTesting$WKSelectSinglePicker$selectRow$inComponent$extendingSelection$(self, _cmd, rowIndex, componentIndex, extendingSelection);
    
    WKContentView *contentView = MSHookIvar<WKContentView *>(self, "_view");
    if ([contentView respondsToSelector:@selector(accessoryDone)]) {
        [contentView accessoryDone];
    }
}



static void _logos_method$WKTesting$WKMultipleSelectPicker$selectRow$inComponent$extendingSelection$(_LOGOS_SELF_TYPE_NORMAL WKMultipleSelectPicker* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSInteger rowIndex, NSInteger componentIndex, BOOL extendingSelection) {
    NSLog(@"-[<WKMultipleSelectPicker: %p> selectRow:%ld inComponent:%ld extendingSelection:%d]", self, (long)rowIndex, (long)componentIndex, extendingSelection);
    UIPickerView *pickerView = (UIPickerView *)self;
    NSInteger numberOfRows = [pickerView.dataSource pickerView:pickerView numberOfRowsInComponent:componentIndex];
    if (rowIndex >= numberOfRows) return;
    if (extendingSelection) {
        for (NSInteger itemIndex = 0; itemIndex < numberOfRows; itemIndex++) {
            BOOL testChecked = [self selectFormAccessoryHasCheckedItemAtRow:itemIndex];
            if ((itemIndex == rowIndex && !testChecked) || (!extendingSelection && itemIndex != rowIndex && testChecked)) {
                BOOL shouldCheck = (extendingSelection || itemIndex == rowIndex);
                if (shouldCheck) {
                    [self pickerView:pickerView row:rowIndex column:componentIndex checked:shouldCheck];
                }
            }
        }
        
    } else {
        BOOL allowsMultipleSelection = [self allowsMultipleSelection];
        if (allowsMultipleSelection)
            [self setAllowsMultipleSelection:NO];
        [pickerView selectRow:rowIndex inComponent:componentIndex animated:NO];
        [self setAllowsMultipleSelection:allowsMultipleSelection];
        
        WKContentView *contentView = MSHookIvar<WKContentView *>(self, "_view");
        if ([contentView respondsToSelector:@selector(accessoryDone)]) {
            [contentView accessoryDone];
        }
    }
}

static BOOL _logos_method$WKTesting$WKMultipleSelectPicker$selectFormAccessoryHasCheckedItemAtRow$(_LOGOS_SELF_TYPE_NORMAL WKMultipleSelectPicker* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, long rowIndex) {
    NSLog(@"-[<WKMultipleSelectPicker: %p> selectFormAccessoryHasCheckedItemAtRow:%ld]", self, rowIndex);
    UIPickerView *pickerView = (UIPickerView *)self;
    NSInteger numberOfRows = [pickerView.dataSource pickerView:pickerView numberOfRowsInComponent:0];
    if (rowIndex >= numberOfRows) return NO;
    return [(WKOptionPickerCell *)[pickerView.delegate pickerView:pickerView viewForRow:rowIndex forComponent:0 reusingView:nil] isChecked];
}


  


#pragma mark -

@interface TabController : NSObject
@property (readonly, copy, nonatomic) NSArray *currentTabDocuments;
- (id)initWithBrowserController:(id)arg1;
- (void)closeAllOpenTabsAnimated:(BOOL)arg1;
- (void)closeAllOpenTabsAnimated:(BOOL)arg1 exitTabView:(BOOL)arg2;
- (void)closeTabDocuments:(id)arg1;
- (void)closeTabDocument:(id)arg1 animated:(BOOL)arg2;
- (void)monkeyCloseAllTabs;
@end

@interface BrowserController : NSObject
@property (readonly, strong, nonatomic) TabController *tabController;
- (void)setPrivateBrowsingEnabled:(BOOL)arg2;
- (BOOL)isPrivateBrowsingEnabled;
- (void)monkeyCloseAllTabs;
@end

@interface BrowserWindowController : NSObject
@property (readonly, strong, nonatomic) NSArray <BrowserController *> *browserControllers;
- (void)monkeyCloseAllTabs;
@end

static void _logos_method$MobileSafari$BrowserWindowController$monkeyCloseAllTabs(_LOGOS_SELF_TYPE_NORMAL BrowserWindowController* _LOGOS_SELF_CONST, SEL); static void _logos_method$MobileSafari$BrowserController$monkeyCloseAllTabs(_LOGOS_SELF_TYPE_NORMAL BrowserController* _LOGOS_SELF_CONST, SEL); static void _logos_method$MobileSafari$TabController$monkeyCloseAllTabs(_LOGOS_SELF_TYPE_NORMAL TabController* _LOGOS_SELF_CONST, SEL); 




static void _logos_method$MobileSafari$BrowserWindowController$monkeyCloseAllTabs(_LOGOS_SELF_TYPE_NORMAL BrowserWindowController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    for (BrowserController *browserController in [self browserControllers]) {
        [browserController monkeyCloseAllTabs];
    }
}






static void _logos_method$MobileSafari$BrowserController$monkeyCloseAllTabs(_LOGOS_SELF_TYPE_NORMAL BrowserController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    [[self tabController] monkeyCloseAllTabs];
}






static void _logos_method$MobileSafari$TabController$monkeyCloseAllTabs(_LOGOS_SELF_TYPE_NORMAL TabController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if ([self respondsToSelector:@selector(closeAllOpenTabsAnimated:)]) {
        [self closeAllOpenTabsAnimated:YES];
    } else if ([self respondsToSelector:@selector(closeAllOpenTabsAnimated:exitTabView:)]) {
        [self closeAllOpenTabsAnimated:YES exitTabView:YES];
    } else if ([self respondsToSelector:@selector(closeTabDocuments:)]) {
        [self closeTabDocuments:[[self currentTabDocuments] copy]];
    }
}

  

  


#pragma mark -

#pragma GCC diagnostic warning "-Wdeprecated-declarations"


static __attribute__((constructor)) void _logosLocalCtor_c2a53aed(int __unused argc, char __unused **argv, char __unused **envp) {
    @autoreleasepool {
        __xpcPauseFlag = NO;
        pthread_mutex_init(&__xpcRemoteViewLock, NULL);
        __xpcRemoteViewWrapper = nil;
        
        pthread_mutex_init(&__xpcRemoteControlLock, NULL);
        __xpcRemoteControlWrappers = [[NSMutableArray alloc] init];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        {Class _logos_class$WKTesting$WKFormSelectControl = objc_getClass("WKFormSelectControl"); { MSHookMessageEx(_logos_class$WKTesting$WKFormSelectControl, @selector(initWithView:), (IMP)&_logos_method$WKTesting$WKFormSelectControl$initWithView$, (IMP*)&_logos_orig$WKTesting$WKFormSelectControl$initWithView$);}Class _logos_class$WKTesting$WKFormColorControl = objc_getClass("WKFormColorControl"); { MSHookMessageEx(_logos_class$WKTesting$WKFormColorControl, @selector(initWithView:), (IMP)&_logos_method$WKTesting$WKFormColorControl$initWithView$, (IMP*)&_logos_orig$WKTesting$WKFormColorControl$initWithView$);}Class _logos_class$WKTesting$WKDateTimePicker = objc_getClass("WKDateTimePicker"); { char _typeEncoding[1024]; unsigned int i = 0; memcpy(_typeEncoding + i, @encode(NSDate *), strlen(@encode(NSDate *))); i += strlen(@encode(NSDate *)); _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$WKTesting$WKDateTimePicker, @selector(date), (IMP)&_logos_method$WKTesting$WKDateTimePicker$date, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(NSDate *), strlen(@encode(NSDate *))); i += strlen(@encode(NSDate *)); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$WKTesting$WKDateTimePicker, @selector(setDate:), (IMP)&_logos_method$WKTesting$WKDateTimePicker$setDate$, _typeEncoding); }Class _logos_class$WKTesting$WKDateTimeInputControl = objc_getClass("WKDateTimeInputControl"); { MSHookMessageEx(_logos_class$WKTesting$WKDateTimeInputControl, @selector(initWithView:), (IMP)&_logos_method$WKTesting$WKDateTimeInputControl$initWithView$, (IMP*)&_logos_orig$WKTesting$WKDateTimeInputControl$initWithView$);}{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(NSDate *), strlen(@encode(NSDate *))); i += strlen(@encode(NSDate *)); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$WKTesting$WKDateTimeInputControl, @selector(setTimePickerDate:), (IMP)&_logos_method$WKTesting$WKDateTimeInputControl$setTimePickerDate$, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; memcpy(_typeEncoding + i, @encode(NSDate *), strlen(@encode(NSDate *))); i += strlen(@encode(NSDate *)); _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$WKTesting$WKDateTimeInputControl, @selector(timePickerValueDate), (IMP)&_logos_method$WKTesting$WKDateTimeInputControl$timePickerValueDate, _typeEncoding); }Class _logos_class$WKTesting$WKSelectSinglePicker = objc_getClass("WKSelectSinglePicker"); { MSHookMessageEx(_logos_class$WKTesting$WKSelectSinglePicker, @selector(selectRow:inComponent:extendingSelection:), (IMP)&_logos_method$WKTesting$WKSelectSinglePicker$selectRow$inComponent$extendingSelection$, (IMP*)&_logos_orig$WKTesting$WKSelectSinglePicker$selectRow$inComponent$extendingSelection$);}Class _logos_class$WKTesting$WKMultipleSelectPicker = objc_getClass("WKMultipleSelectPicker"); { MSHookMessageEx(_logos_class$WKTesting$WKMultipleSelectPicker, @selector(selectRow:inComponent:extendingSelection:), (IMP)&_logos_method$WKTesting$WKMultipleSelectPicker$selectRow$inComponent$extendingSelection$, (IMP*)&_logos_orig$WKTesting$WKMultipleSelectPicker$selectRow$inComponent$extendingSelection$);}{ MSHookMessageEx(_logos_class$WKTesting$WKMultipleSelectPicker, @selector(selectFormAccessoryHasCheckedItemAtRow:), (IMP)&_logos_method$WKTesting$WKMultipleSelectPicker$selectFormAccessoryHasCheckedItemAtRow$, (IMP*)&_logos_orig$WKTesting$WKMultipleSelectPicker$selectFormAccessoryHasCheckedItemAtRow$);}}
        
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleIdentifier hasPrefix:@"com.apple."])
        {
            {Class _logos_class$SafariXPC$SFBrowserServiceViewController = objc_getClass("SFBrowserServiceViewController"); { MSHookMessageEx(_logos_class$SafariXPC$SFBrowserServiceViewController, @selector(_dismiss), (IMP)&_logos_method$SafariXPC$SFBrowserServiceViewController$_dismiss, (IMP*)&_logos_orig$SafariXPC$SFBrowserServiceViewController$_dismiss);}{ MSHookMessageEx(_logos_class$SafariXPC$SFBrowserServiceViewController, @selector(_hostApplicationDidEnterBackground), (IMP)&_logos_method$SafariXPC$SFBrowserServiceViewController$_hostApplicationDidEnterBackground, (IMP*)&_logos_orig$SafariXPC$SFBrowserServiceViewController$_hostApplicationDidEnterBackground);}{ MSHookMessageEx(_logos_class$SafariXPC$SFBrowserServiceViewController, @selector(_hostApplicationWillEnterForeground), (IMP)&_logos_method$SafariXPC$SFBrowserServiceViewController$_hostApplicationWillEnterForeground, (IMP*)&_logos_orig$SafariXPC$SFBrowserServiceViewController$_hostApplicationWillEnterForeground);}{ MSHookMessageEx(_logos_class$SafariXPC$SFBrowserServiceViewController, @selector(_didLoadWebView), (IMP)&_logos_method$SafariXPC$SFBrowserServiceViewController$_didLoadWebView, (IMP*)&_logos_orig$SafariXPC$SFBrowserServiceViewController$_didLoadWebView);}Class _logos_class$SafariXPC$SFSafariView = objc_getClass("SFSafariView"); { MSHookMessageEx(_logos_class$SafariXPC$SFSafariView, @selector(willMoveToWindow:), (IMP)&_logos_method$SafariXPC$SFSafariView$willMoveToWindow$, (IMP*)&_logos_orig$SafariXPC$SFSafariView$willMoveToWindow$);}Class _logos_class$SafariXPC$_UILayerHostView = objc_getClass("_UILayerHostView"); { MSHookMessageEx(_logos_class$SafariXPC$_UILayerHostView, @selector(initWithFrame:pid:contextID:), (IMP)&_logos_method$SafariXPC$_UILayerHostView$initWithFrame$pid$contextID$, (IMP*)&_logos_orig$SafariXPC$_UILayerHostView$initWithFrame$pid$contextID$);}Class _logos_class$SafariXPC$UIWebView = objc_getClass("UIWebView"); { char _typeEncoding[1024]; unsigned int i = 0; memcpy(_typeEncoding + i, @encode(NSString *), strlen(@encode(NSString *))); i += strlen(@encode(NSString *)); _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(NSString *), strlen(@encode(NSString *))); i += strlen(@encode(NSString *)); memcpy(_typeEncoding + i, @encode(NSError * __autoreleasing *), strlen(@encode(NSError * __autoreleasing *))); i += strlen(@encode(NSError * __autoreleasing *)); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$SafariXPC$UIWebView, @selector(_sf_stringByEvaluatingJavaScriptFromString:error:), (IMP)&_logos_method$SafariXPC$UIWebView$_sf_stringByEvaluatingJavaScriptFromString$error$, _typeEncoding); }}
            {Class _logos_class$MobileSafari$BrowserWindowController = objc_getClass("BrowserWindowController"); { char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$MobileSafari$BrowserWindowController, @selector(monkeyCloseAllTabs), (IMP)&_logos_method$MobileSafari$BrowserWindowController$monkeyCloseAllTabs, _typeEncoding); }Class _logos_class$MobileSafari$BrowserController = objc_getClass("BrowserController"); { char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$MobileSafari$BrowserController, @selector(monkeyCloseAllTabs), (IMP)&_logos_method$MobileSafari$BrowserController$monkeyCloseAllTabs, _typeEncoding); }Class _logos_class$MobileSafari$TabController = objc_getClass("TabController"); { char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$MobileSafari$TabController, @selector(monkeyCloseAllTabs), (IMP)&_logos_method$MobileSafari$TabController$monkeyCloseAllTabs, _typeEncoding); }}
        }
#pragma clang diagnostic pop
    }
}

