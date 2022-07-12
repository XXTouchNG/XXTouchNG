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

%group SafariXPC

%hook SFBrowserServiceViewController
- (void)_dismiss {
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        __xpcPauseFlag = YES;
        __xpcRemoteViewWrapper = nil;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
    %log;
    %orig;
}
- (void)_hostApplicationDidEnterBackground {
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        __xpcPauseFlag = YES;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
    %log;
    %orig;
}
- (void)_hostApplicationWillEnterForeground {
    %log;
    %orig;
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        __xpcPauseFlag = NO;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
}
- (void)_didLoadWebView {
    %log;
    %orig;
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        __xpcRemoteBundleIdentifier = [self _hostAppBundleId];
        __xpcRemoteViewWrapper = [[TMWeakViewWrapper alloc] initWithWeakView:[self _currentWebView] forUniqueIdentifier:[[NSUUID UUID] UUIDString]];
        __xpcPauseFlag = NO;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
}
%end


%hook SFSafariView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %log;
    %orig;
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
%end

%hook _UILayerHostView
- (id)initWithFrame:(CGRect)arg1 pid:(int)arg2 contextID:(unsigned)arg3 {
    %log; return %orig;
}
%end


#pragma GCC diagnostic warning "-Wdeprecated-declarations"
#pragma mark -
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"


%hook UIWebView

#define NSERROR_UIWEBVIEW_SCRIPT @"@@NSERROR_UIWEBVIEW_SCRIPT@@"
#define NSERROR_UIWEBVIEW_SCRIPT_CODE 1

%new
- (NSString *)_sf_stringByEvaluatingJavaScriptFromString:(NSString *)script error:(NSError * __autoreleasing *)error {
    
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

%end

%end  // SafariXPC


#pragma mark -

%group WKTesting

@interface WKFormSelectControl : NSObject
@end

%hook WKFormSelectControl
- (instancetype)initWithView:(UIView *)view {
    if (pthread_mutex_trylock(&__xpcRemoteControlLock) == 0) {
        TMWeakObjectWrapper *wrapper = [[TMWeakObjectWrapper alloc] initWithWeakObject:self];
        [__xpcRemoteControlWrappers addObject:wrapper];
        pthread_mutex_unlock(&__xpcRemoteControlLock);
    }
    %log; return %orig;
}
%end

@interface WKFormColorControl : NSObject
@end

%hook WKFormColorControl
- (instancetype)initWithView:(UIView *)view {
    if (pthread_mutex_trylock(&__xpcRemoteControlLock) == 0) {
        TMWeakObjectWrapper *wrapper = [[TMWeakObjectWrapper alloc] initWithWeakObject:self];
        [__xpcRemoteControlWrappers addObject:wrapper];
        pthread_mutex_unlock(&__xpcRemoteControlLock);
    }
    %log; return %orig;
}
%end

%hook WKDateTimePicker
%new
- (NSDate *)date {
    UIDatePicker *datePicker = MSHookIvar<UIDatePicker *>(self, "_datePicker");
    return [datePicker date];
}
%new
- (void)setDate:(NSDate *)date {
    UIDatePicker *datePicker = MSHookIvar<UIDatePicker *>(self, "_datePicker");
    [datePicker setDate:date];
}
%end

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

%hook WKDateTimeInputControl
- (instancetype)initWithView:(UIView *)view {
    if (pthread_mutex_trylock(&__xpcRemoteControlLock) == 0) {
        TMWeakObjectWrapper *wrapper = [[TMWeakObjectWrapper alloc] initWithWeakObject:self];
        [__xpcRemoteControlWrappers addObject:wrapper];
        pthread_mutex_unlock(&__xpcRemoteControlLock);
    }
    %log; return %orig;
}
%new
- (void)setTimePickerDate:(NSDate *)date {
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
%new
- (NSDate *)timePickerValueDate {
    if ([self.control isKindOfClass:NSClassFromString(@"WKDateTimePicker")]) {
        return [(WKDateTimePicker *)self.control date];
    }
    return nil;
}
%end

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

%hook WKSelectSinglePicker
- (void)selectRow:(NSInteger)rowIndex inComponent:(NSInteger)componentIndex extendingSelection:(BOOL)extendingSelection {
    %log; %orig;
    
    WKContentView *contentView = MSHookIvar<WKContentView *>(self, "_view");
    if ([contentView respondsToSelector:@selector(accessoryDone)]) {
        [contentView accessoryDone];
    }
}
%end

%hook WKMultipleSelectPicker
- (void)selectRow:(NSInteger)rowIndex inComponent:(NSInteger)componentIndex extendingSelection:(BOOL)extendingSelection {
    %log;
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

- (BOOL)selectFormAccessoryHasCheckedItemAtRow:(long)rowIndex {
    %log;
    UIPickerView *pickerView = (UIPickerView *)self;
    NSInteger numberOfRows = [pickerView.dataSource pickerView:pickerView numberOfRowsInComponent:0];
    if (rowIndex >= numberOfRows) return NO;
    return [(WKOptionPickerCell *)[pickerView.delegate pickerView:pickerView viewForRow:rowIndex forComponent:0 reusingView:nil] isChecked];
}
%end

%end  // WKTesting


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

%group MobileSafari

%hook BrowserWindowController

%new
- (void)monkeyCloseAllTabs {
    for (BrowserController *browserController in [self browserControllers]) {
        [browserController monkeyCloseAllTabs];
    }
}

%end

%hook BrowserController

%new
- (void)monkeyCloseAllTabs {
    [[self tabController] monkeyCloseAllTabs];
}

%end

%hook TabController

%new
- (void)monkeyCloseAllTabs {
    if ([self respondsToSelector:@selector(closeAllOpenTabsAnimated:)]) {
        [self closeAllOpenTabsAnimated:YES];
    } else if ([self respondsToSelector:@selector(closeAllOpenTabsAnimated:exitTabView:)]) {
        [self closeAllOpenTabsAnimated:YES exitTabView:YES];
    } else if ([self respondsToSelector:@selector(closeTabDocuments:)]) {
        [self closeTabDocuments:[[self currentTabDocuments] copy]];
    }
}

%end  // %hook TabController

%end  // %group MobileSafari


#pragma mark -

#pragma GCC diagnostic warning "-Wdeprecated-declarations"


%ctor {
    @autoreleasepool {
        __xpcPauseFlag = NO;
        pthread_mutex_init(&__xpcRemoteViewLock, NULL);
        __xpcRemoteViewWrapper = nil;
        
        pthread_mutex_init(&__xpcRemoteControlLock, NULL);
        __xpcRemoteControlWrappers = [[NSMutableArray alloc] init];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        %init(WKTesting);
        
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleIdentifier hasPrefix:@"com.apple."])
        {
            %init(SafariXPC);
            %init(MobileSafari);
        }
#pragma clang diagnostic pop
    }
}

