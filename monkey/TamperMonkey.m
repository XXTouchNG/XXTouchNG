//
//  TamperMonkey.m
//  TamperMonkey
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TFLuaBridge.h"
#import "TMWeakViewWrapper.h"
#import "TMWeakUserContentControllerWrapper.h"
#import "TMScriptMessageProxy.h"
#import "TMScriptNetworkingProxy.h"

#import <WebKit/WebKit.h>
#import <pthread.h>
#import "embedded.js.h"
#import "WKWebViewIOS.h"
#import "WKWebViewPrivateForTestingIOS.h"


/* MARK: ----------------------------------------------------------------------- */


@interface SFSafariViewController : UIViewController
@property (nonatomic, readonly) NSURL *initialURL;
@end

@interface UIWebView (JavaScriptNSError)
- (NSString *)_sf_stringByEvaluatingJavaScriptFromString:(NSString *)script error:(NSError * __autoreleasing *)error;
@end

@interface WKContentView : UIView
- (void)accessoryDone;
@end

@interface WKContentView (WKTesting)
- (BOOL)_hasFocusedElement;
@end

@interface WKFormSelectControl : NSObject
@property id <UIPickerViewDataSource, UIPickerViewDelegate> control;
@property WKContentView *contentView;
@end

@interface WKFormSelectControl (WKTesting)
- (void)selectRow:(NSInteger)rowIndex inComponent:(NSInteger)componentIndex extendingSelection:(BOOL)extendingSelection;
- (BOOL)selectFormAccessoryHasCheckedItemAtRow:(long)rowIndex;
@end

@interface WKOptionPickerCell : NSObject
@property UILabel *titleLabel;
@property (nonatomic) BOOL disabled;
- (BOOL)isChecked;
@end

@interface WKFormColorControl : NSObject
@property WKContentView *contentView;
@end

@interface WKFormColorControl (WKTesting)
- (void)selectColor:(UIColor *)color;
@end

@interface WKDateTimeInputControl : NSObject
@property WKContentView *contentView;
@end

@interface WKDateTimeInputControl (WKTesting)
@property (nonatomic, readonly) NSString *dateTimePickerCalendarType;
- (NSDate *)timePickerValueDate;
- (void)setTimePickerDate:(NSDate *)date;
@end

@interface UIPickerView (UIPickerViewInternal)
- (BOOL)allowsMultipleSelection;
- (void)setAllowsMultipleSelection:(BOOL)aFlag;
@end

@interface UIWindow (Private)
+ (NSArray <UIWindow *> *)allWindowsIncludingInternalWindows:(BOOL)arg1 onlyVisibleWindows:(BOOL)arg2;
@end

@interface BrowserController : NSObject
- (void)setPrivateBrowsingEnabled:(BOOL)enabled;
- (BOOL)isPrivateBrowsingEnabled;
@end

@interface BrowserWindowController : NSObject
@property (readonly, strong, nonatomic) NSArray <BrowserController *> *browserControllers;
- (void)monkeyCloseAllTabs;
@end


/* MARK: ----------------------------------------------------------------------- */


OBJC_EXTERN BOOL __xpcPauseFlag;
OBJC_EXTERN TMWeakViewWrapper *__xpcRemoteViewWrapper;
OBJC_EXTERN NSString *__xpcRemoteBundleIdentifier;
OBJC_EXTERN pthread_mutex_t __xpcRemoteViewLock;

OBJC_EXTERN NSMutableArray <TMWeakObjectWrapper *> *__xpcRemoteControlWrappers;
OBJC_EXTERN pthread_mutex_t __xpcRemoteControlLock;

static NSArray <TMWeakViewWrapper *> *__localViewCache = nil;
static pthread_mutex_t __localViewCacheLock;

static NSArray <NSString *> *__localBlackURLComponents = nil;

static NSMutableArray <TMWeakUserContentControllerWrapper *> *__localRegisteredWrappers = nil;
static pthread_rwlock_t __localRegisteredWrappersLock;


/* MARK: ----------------------------------------------------------------------- */


@implementation TFLuaBridge (Actions)

#if DEBUG
+ (NSArray <TMWeakUserContentControllerWrapper *> *)tamperMonkeyLocalRegisteredWrappers {
    @autoreleasepool {
        NSArray <TMWeakUserContentControllerWrapper *> *wrappers = nil;
        pthread_rwlock_rdlock(&__localRegisteredWrappersLock);
        wrappers = [__localRegisteredWrappers copy];
        pthread_rwlock_unlock(&__localRegisteredWrappersLock);
        return wrappers;
    }
}
#endif

+ (BOOL)tamperMonkeyXPCPaused {
    BOOL isPaused = YES;
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        isPaused = __xpcPauseFlag;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
    return isPaused;
}

+ (id)tamperMonkeyXPCRemoteView {
    id remoteView = nil;
    if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
        remoteView = __xpcRemoteViewWrapper.weakView;
        pthread_mutex_unlock(&__xpcRemoteViewLock);
    }
    return remoteView;
}

+ (NSString *)tamperMonkeyXPCRemoteBundleIdentifier {
    static NSString *remoteIdentifier = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (pthread_mutex_trylock(&__xpcRemoteViewLock) == 0) {
            remoteIdentifier = __xpcRemoteBundleIdentifier;
            pthread_mutex_unlock(&__xpcRemoteViewLock);
        }
    });
    return remoteIdentifier;
}

+ (id)tamperMonkeyXPCTopMostFormControl {
    @autoreleasepool {
        id formControl = nil;
        if (pthread_mutex_trylock(&__xpcRemoteControlLock) == 0) {
            NSMutableArray <TMWeakObjectWrapper *> *wrappersToRemove = [[NSMutableArray alloc] initWithCapacity:__xpcRemoteControlWrappers.count];
            for (TMWeakObjectWrapper *wrapper in __xpcRemoteControlWrappers) {
                if (wrapper.weakObject == nil) {
                    [wrappersToRemove addObject:wrapper];
                }
            }
            [__xpcRemoteControlWrappers removeObjectsInArray:wrappersToRemove];
            TMWeakObjectWrapper *lastWrapper = [__xpcRemoteControlWrappers lastObject];
            formControl = lastWrapper.weakObject;
            pthread_mutex_unlock(&__xpcRemoteControlLock);
        }
        return formControl;
    }
}

+ (void)tamperMonkeyListWebViewsFrom:(UIView *)view To:(NSMutableArray <UIView *> *)views Stop:(BOOL *)stopFlag {
    @autoreleasepool {
        NSArray *subviews = [view subviews];
        if (subviews.count == 0) return;
        for (UIView *subview in subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"WKWebView")] || [subview isKindOfClass:NSClassFromString(@"UIWebView")]) {
                [views addObject:subview];
                continue;
            }
            
            if ([subview isKindOfClass:NSClassFromString(@"SFSafariView")]) {
                if (stopFlag) {
                    *stopFlag = YES;
                }
                break;
            }
            
            // get subviews recursively
            [self tamperMonkeyListWebViewsFrom:subview To:views Stop:stopFlag];
        }
    }
}

+ (NSArray <UIView *> *)tamperMonkeyGetAllWebViews {
    @autoreleasepool {
        BOOL shouldStop = NO;
        NSMutableArray <UIWindow *> *activeWindows =
        [[[UIWindow allWindowsIncludingInternalWindows:YES onlyVisibleWindows:NO]
          filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"hidden == NO"]] mutableCopy];
        NSMutableArray <UIView *> *activeWebViews = [NSMutableArray arrayWithCapacity:activeWindows.count];
        for (UIWindow *window in activeWindows) {
            [self tamperMonkeyListWebViewsFrom:window To:activeWebViews Stop:&shouldStop];
            if (shouldStop) {
                return nil;
            }
        }
        return [activeWebViews copy];
    }
}

+ (NSURL *)tamperMonkeyGetURLFromWebView:(UIView *)view {
    @autoreleasepool {
        if ([view isKindOfClass:NSClassFromString(@"WKWebView")]) {
            return [(id)view URL];
        }
        else if ([view isKindOfClass:NSClassFromString(@"UIWebView")]) {
            return [[(id)view request] URL];
        }
        return nil;
    }
}

+ (NSDictionary *)tamperMonkeyGetDictionaryFromURL:(NSURL *)url {
    @autoreleasepool {
        if (!url) { return nil; }
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:4];
        if ([url isFileURL]) {
            if (url.path)           { dict[@"path"]           = url.path;           }
        } else {
            if (url.absoluteString) { dict[@"absoluteString"] = url.absoluteString; }
            if (url.scheme)         { dict[@"scheme"]         = url.scheme;         }
            if (url.host)           { dict[@"host"]           = url.host;           }
            if (url.path)           { dict[@"path"]           = url.path;           }
            return dict;
        }
        return dict;
    }
}

+ (NSDateFormatter *)tamperMonkeyFormControlISODateFormatter {
    static NSDateFormatter *_formControlDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _formControlDateFormatter = [[NSDateFormatter alloc] init];
        _formControlDateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        _formControlDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'+00:00'";
        _formControlDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return _formControlDateFormatter;
}

+ (NSDateFormatter *)tamperMonkeyFormControlLocalDateFormatter {
    static NSDateFormatter *_formControlDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _formControlDateFormatter = [[NSDateFormatter alloc] init];
        _formControlDateFormatter.timeZone = [NSTimeZone systemTimeZone];
        _formControlDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        _formControlDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return _formControlDateFormatter;
}

+ (NSDictionary *)tamperMonkeyGetDictionaryFromFormControl:(id)formControl {
    @autoreleasepool {
        NSMutableDictionary *dict = nil;
        if ([formControl isKindOfClass:NSClassFromString(@"WKFormSelectControl")]) {
            NSAssert([NSThread isMainThread], @"main thread only");
            
            WKFormSelectControl *control = (WKFormSelectControl *)formControl;
            dict = [NSMutableDictionary dictionaryWithCapacity:8];
            [dict setObject:@"select" forKey:@"type"];
            
            if ([control.control isKindOfClass:[UIPickerView class]] &&
                [control.control respondsToSelector:@selector(numberOfComponentsInPickerView:)] &&
                [control.control respondsToSelector:@selector(pickerView:numberOfRowsInComponent:)] &&
                ([control.control respondsToSelector:@selector(pickerView:viewForRow:forComponent:reusingView:)] ||
                 [control.control respondsToSelector:@selector(pickerView:attributedTitleForRow:forComponent:)]
                 ))
            {
                id <UIPickerViewDataSource, UIPickerViewDelegate> dataSource = control.control;
                UIPickerView *pickerView = (UIPickerView *)dataSource;
                [pickerView reloadAllComponents];
                
                NSInteger selectedIndex = NSNotFound;
                if (CHIvarRef(pickerView, _selectedIndex, NSInteger)) {
                    selectedIndex = CHIvar(pickerView, _selectedIndex, NSInteger);
                }
                
                [dict setObject:@(pickerView.allowsMultipleSelection) forKey:@"allowsMultipleSelection"];
                
                NSMutableArray <NSDictionary *> *selectedItems = [[NSMutableArray alloc] init];
                NSMutableArray <NSString *> *selectedItemValues = [[NSMutableArray alloc] init];
                NSMutableArray <NSNumber *> *selectedItemIndexes = [[NSMutableArray alloc] init];
                
                NSMutableArray <NSDictionary *> *items = [[NSMutableArray alloc] init];
                NSMutableArray <NSString *> *flattenedItems = [[NSMutableArray alloc] init];
                NSInteger groupCount = [dataSource numberOfComponentsInPickerView:pickerView];
                for (NSInteger groupIdx = 0; groupIdx < groupCount; groupIdx++) {
                    NSInteger itemCount = [dataSource pickerView:pickerView numberOfRowsInComponent:groupIdx];
                    for (NSInteger itemIdx = 0; itemIdx < itemCount; itemIdx++) {
                        @autoreleasepool {
                            if ([dataSource respondsToSelector:@selector(pickerView:viewForRow:forComponent:reusingView:)]) {
                                WKOptionPickerCell *cell = (WKOptionPickerCell *)[dataSource pickerView:pickerView viewForRow:itemIdx forComponent:groupIdx reusingView:nil];
                                BOOL isGroupCell = [NSStringFromClass([cell class]) containsString:@"Group"];
                                BOOL isSelected = cell.isChecked;
                                if ([cell respondsToSelector:@selector(titleLabel)]) {
                                    UILabel *titleLabel = cell.titleLabel;
                                    if ([titleLabel isKindOfClass:[UILabel class]] && [titleLabel.text isKindOfClass:[NSString class]]) {
                                        NSString *titleText = [titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                        if (isGroupCell) {
                                            
                                            NSDictionary *itemDict = @{
                                                @"index": @(itemIdx + 1),
                                                @"isGroup": @(YES),
                                                @"isEnabled": @(NO),
                                                @"isSelected": @(isSelected),
                                                @"value": [NSString stringWithFormat:@"%@", titleText],
                                            };
                                            [items addObject:itemDict];
                                            
                                            NSString *formattedTitleText = [NSString stringWithFormat:@"^%@", titleText];
                                            [flattenedItems addObject:formattedTitleText];
                                        } else {
                                            BOOL isDisabled = cell.disabled;
                                            if (isDisabled) {
                                                
                                                NSDictionary *itemDict = @{
                                                    @"index": @(itemIdx + 1),
                                                    @"isGroup": @(NO),
                                                    @"isEnabled": @(NO),
                                                    @"isSelected": @(isSelected),
                                                    @"value": [NSString stringWithFormat:@"%@", titleText],
                                                };
                                                [items addObject:itemDict];
                                                
                                                NSString *formattedTitleText = [NSString stringWithFormat:@"!%@", titleText];
                                                [flattenedItems addObject:formattedTitleText];
                                            } else {
                                                
                                                NSDictionary *itemDict = @{
                                                    @"index": @(itemIdx + 1),
                                                    @"isGroup": @(NO),
                                                    @"isEnabled": @(YES),
                                                    @"isSelected": @(isSelected),
                                                    @"value": [NSString stringWithFormat:@"%@", titleText],
                                                };
                                                [items addObject:itemDict];
                                                
                                                NSString *formattedTitleText = [NSString stringWithFormat:@"%@", titleText];
                                                [flattenedItems addObject:formattedTitleText];
                                                
                                                if (isSelected) {
                                                    [selectedItems addObject:itemDict];
                                                    [selectedItemValues addObject:formattedTitleText];
                                                    [selectedItemIndexes addObject:@(itemIdx)];
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                [dict setObject:selectedItems forKey:@"selectedItems"];
                                [dict setObject:selectedItemValues forKey:@"selectedItemValues"];
                                [dict setObject:selectedItemIndexes forKey:@"selectedItemIndexes"];
                                [dict setObject:@(selectedItemIndexes.count) forKey:@"selectedItemCount"];
                            } else {
                                NSAttributedString *titleAttributedText = [dataSource pickerView:pickerView attributedTitleForRow:itemIdx forComponent:groupIdx];
                                
                                BOOL isEnabled = YES;
                                NSRange titleEffectiveRange;
                                NSDictionary *titleAttributes = [titleAttributedText attributesAtIndex:0 effectiveRange:&titleEffectiveRange];
                                if ([[titleAttributes objectForKey:NSForegroundColorAttributeName] isKindOfClass:[UIColor class]]) {
                                    UIColor *titleColor = [titleAttributes objectForKey:NSForegroundColorAttributeName];
                                    
                                    CGFloat whiteValue = 0;
                                    CGFloat alphaValue = 1;
                                    
                                    BOOL isWhite = [titleColor getWhite:&whiteValue alpha:&alphaValue];
                                    if (isWhite && alphaValue < 0.5) {
                                        isEnabled = NO;
                                    }
                                }
                                
                                BOOL isSelected = selectedIndex != NSNotFound && selectedIndex == itemIdx;
                                NSString *titleText = [[titleAttributedText string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                
                                NSString *formattedTitleText = [NSString stringWithFormat:@"%@", titleText];
                                NSDictionary *itemDict = @{
                                    @"index": @(itemIdx + 1),
                                    @"isGroup": @(NO),
                                    @"isEnabled": @(isEnabled),
                                    @"isSelected": @(isSelected),
                                    @"value": formattedTitleText,
                                };
                                [items addObject:itemDict];
                                
                                [flattenedItems addObject:formattedTitleText];
                                
                                if (isSelected) {
                                    [dict setObject:itemDict forKey:@"selectedItem"];
                                    [dict setObject:formattedTitleText forKey:@"selectedItemValue"];
                                    [dict setObject:@(itemIdx + 1) forKey:@"selectedItemIndex"];
                                }
                            }
                        }
                    }
                    
                    if (groupIdx > 0) {
                        break;
                    }
                }
                
                [dict setObject:items forKey:@"items"];
                [dict setObject:flattenedItems forKey:@"flattenedItems"];
            }
        } else if ([formControl isKindOfClass:NSClassFromString(@"WKDateTimeInputControl")]) {
            NSAssert([NSThread isMainThread], @"main thread only");
            
            WKDateTimeInputControl *control = (WKDateTimeInputControl *)formControl;
            dict = [NSMutableDictionary dictionaryWithCapacity:4];
            [dict setObject:@"datetime" forKey:@"type"];
            NSDate *controlDate = [control timePickerValueDate];
            if (controlDate) {
                [dict setObject:[[TFLuaBridge tamperMonkeyFormControlISODateFormatter] stringFromDate:controlDate] forKey:@"value"];
                [dict setObject:[[TFLuaBridge tamperMonkeyFormControlLocalDateFormatter] stringFromDate:controlDate] forKey:@"localizedValue"];
                [dict setObject:@([controlDate timeIntervalSince1970]) forKey:@"timestamp"];
            }
        } else if ([formControl isKindOfClass:NSClassFromString(@"WKFormColorControl")]) {
            /// TODO: not supported yet
        }
        return dict;
    }
}

+ (UIView *)tamperMonkeyGetWebContentViewFromWebView:(UIView *)view {
    @autoreleasepool {
        if ([view isKindOfClass:NSClassFromString(@"WKWebView")]) {
            id wkWebView = view;
            if ([wkWebView window] == nil) { return nil; }
            for (UIView *subview in [[wkWebView scrollView] subviews]) {
                if ([NSStringFromClass([subview class]) hasSuffix:@"ContentView"]) { return subview; }
            }
        }
        else if ([view isKindOfClass:NSClassFromString(@"UIWebView")]) {
            id uiWebView = view;
            if ([uiWebView window] == nil) { return nil; }
            for (UIView *subview in [[uiWebView scrollView] subviews]) {
                if ([NSStringFromClass([subview class]) hasSuffix:@"ContentView"]) { return subview; }
            }
        }
        return nil;
    }
}

+ (NSDictionary *)tamperMonkeyGetWrapperAttributes:(TMWeakViewWrapper *)wrapper {
    @autoreleasepool {
        NSString *viewID = wrapper.uniqueIdentifier;
        UIView *view = wrapper.weakView;
        if (!view || !viewID) {
            return nil;
        }
        
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        [attrs setObject:viewID forKey:@"objectIdentifier"];
        if ([bundleId isKindOfClass:[NSString class]]) {
            [attrs setObject:bundleId forKey:@"responder"];
        }

        CGFloat contentScale = 1.0;
        UIView *contentView = nil;

        // Basic WKWebView
        if ([view isKindOfClass:NSClassFromString(@"WKWebView")]) {
            id wkWebView = view;

            [attrs addEntriesFromDictionary:@{
                 @"targetClass": @"WKWebView",
                 @"class": NSStringFromClass([view class]),
                 @"loading": @([wkWebView isLoading]),
                 @"estimatedProgress": @([wkWebView estimatedProgress]),
                 @"isInjectable": @(YES),
            }];

            NSString *wkTitle = [wkWebView title];
            if (wkTitle) {
                [attrs setObject:wkTitle forKey:@"title"];
            }

            contentScale = [[wkWebView scrollView] zoomScale];
            contentView = [self tamperMonkeyGetWebContentViewFromWebView:wkWebView] ?: wkWebView;
        }
        
        // Basic UIWebView
        else if ([view isKindOfClass:NSClassFromString(@"UIWebView")]) {
            id uiWebView = view;
            
            [attrs addEntriesFromDictionary:@{
                @"targetClass": @"UIWebView",
                @"class": NSStringFromClass([view class]),
                @"loading": @([uiWebView isLoading]),
                @"isInjectable": @(YES),
            }];
            
            contentScale = [[uiWebView scrollView] zoomScale];
            contentView = [self tamperMonkeyGetWebContentViewFromWebView:uiWebView] ?: uiWebView;
        }

        // URL
        [attrs addEntriesFromDictionary:([self tamperMonkeyGetDictionaryFromURL:[self tamperMonkeyGetURLFromWebView:view]] ?: @{})];

        // Coordinates
        if (contentView.window != nil) {
            CGRect contentRect = [contentView convertRect:[contentView bounds]
                                  toCoordinateSpace:[[[contentView window] screen] fixedCoordinateSpace]];
            [attrs addEntriesFromDictionary:@{
                 @"contentFrame": @[
                     @(contentRect.origin.x),
                     @(contentRect.origin.y),
                     @(contentRect.size.width),
                     @(contentRect.size.height),
                 ],
                 @"contentScale": @(contentScale),
            }];
        }

        return [attrs copy];
    }
}

+ (NSArray <TMWeakViewWrapper *> *)tamperMonkeyReloadWrappers {
    @autoreleasepool {
        NSMutableArray <UIView *> *webViews = [[TFLuaBridge tamperMonkeyGetAllWebViews] mutableCopy];
        if (!webViews) {
            return nil;
        }
        
        id xpcRemoteView = [TFLuaBridge tamperMonkeyXPCRemoteView];
        if (xpcRemoteView) {
            [webViews addObject:xpcRemoteView];
        }
        
        NSMutableArray <TMWeakViewWrapper *> *localWrappers = [[NSMutableArray alloc] initWithCapacity:webViews.count];
        for (UIView *view in webViews) {
            @autoreleasepool {
                TMWeakViewWrapper *wrapper = [[TMWeakViewWrapper alloc] initWithWeakView:view forUniqueIdentifier:[[NSUUID UUID] UUIDString]];
                [localWrappers addObject:wrapper];
            }
        }
        
        pthread_mutex_lock(&__localViewCacheLock);
        __localViewCache = [localWrappers copy];
        pthread_mutex_unlock(&__localViewCacheLock);
        
        return [localWrappers copy];
    }
}

+ (BOOL)tamperMonkeyCheckURL:(NSURL *)url forLegacyDictionary:(NSDictionary *)meta {
    @autoreleasepool {
        if (!url) {
            return NO;
        }
        
        NSMutableArray <NSString *> *hostComponents = [[url.host componentsSeparatedByString:@"."] mutableCopy];
        [hostComponents removeLastObject];
        if ([__localBlackURLComponents containsObject:[hostComponents lastObject]]) {
            return NO;
        }
        BOOL validPass = YES;
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([meta[@"responder"] isKindOfClass:[NSString class]] && [bundleId isKindOfClass:[NSString class]]) {
            validPass = [bundleId isEqualToString:meta[@"responder"]];
            if (!validPass) { return NO; }
        }
        if ([meta[@"scheme"] isKindOfClass:[NSString class]])
        {
            validPass = [url.scheme isEqualToString:meta[@"scheme"]];
            if (!validPass) { return NO; }
        }
        if ([meta[@"host"] isKindOfClass:[NSString class]])
        {
            validPass = [url.host isEqualToString:meta[@"host"]];
            if (!validPass) { return NO; }
        }
        if ([meta[@"path"] isKindOfClass:[NSString class]])
        {
            validPass = [url.path isEqualToString:meta[@"path"]];
            if (!validPass) { return NO; }
        }
        if ([meta[@"absoluteString"] isKindOfClass:[NSString class]])
        {
            validPass = [url.absoluteString isEqualToString:meta[@"absoluteString"]];
            if (!validPass) { return NO; }
        }
        if ([meta[@"url"] isKindOfClass:[NSString class]])
        {
            NSRegularExpression *urlRegex = [NSRegularExpression regularExpressionWithPattern:meta[@"url"] options:kNilOptions error:nil];
            if (urlRegex) {
                NSString *urlStr = url.absoluteString;
                NSTextCheckingResult *urlRes = [urlRegex firstMatchInString:urlStr options:kNilOptions range:NSMakeRange(0, urlStr.length)];
                validPass = (urlRes != nil);
                if (!validPass) { return NO; }
            }
        }
        return validPass;
    }
}

+ (NSString *)tamperMonkeyGeneratePayloadWithTags:(NSArray <NSString *> *)jsTags fromJavascriptContents:(NSArray <NSString *> *)jsContents {
    static NSString *jsTemplate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jsTemplate = [[NSString alloc] initWithData:__InlineData_embedded_js() encoding:NSUTF8StringEncoding];
    });
    
    @autoreleasepool {
        NSMutableString *jsPayload = [jsTemplate mutableCopy];
        
        for (NSInteger idx = 0; idx < MIN(jsTags.count, jsContents.count); idx++) {
            NSString *jsTag = jsTags[idx];
            NSString *jsContent = jsContents[idx];
            
            NSData *jsContentData = [jsContent dataUsingEncoding:NSUTF8StringEncoding];
            NSString *b64ContentString = [jsContentData base64EncodedStringWithOptions:kNilOptions];
            NSString *jsContentWrapper = [NSString stringWithFormat:@"return eval(window.atob(\"%@\"));", b64ContentString];
            
            NSRange placeholderRange = [jsPayload rangeOfString:[NSString stringWithFormat:@"//* ${%@} *//", jsTag]];
            if (placeholderRange.location == NSNotFound) {
                continue;
            }
            [jsPayload replaceCharactersInRange:placeholderRange withString:jsContentWrapper];
        }
        
        return [jsPayload copy];
    }
}

+ (NSString *)tamperMonkeyEvaluateJavascript:(NSString *)jsContent inWebView:(UIView *)view withError:(NSError *__autoreleasing*)error {
    
    NSError *strongErr = nil;
    if ([view isKindOfClass:NSClassFromString(@"UIWebView")]) {
        NSString *result = nil;
        @autoreleasepool {
            result = [(id)view _sf_stringByEvaluatingJavaScriptFromString:jsContent error:&strongErr];
        }
        if (!result) {
            if (error) {
                *error = strongErr;
            }
        }
        return result;
    }
    else if ([view isKindOfClass:NSClassFromString(@"WKWebView")]) {
        __block id evalResult = nil;
        __block NSError *evalError = nil;
        
        [(id)view evaluateJavaScript:[self tamperMonkeyGeneratePayloadWithTags:@[@"PAYLOAD"] fromJavascriptContents:@[jsContent]]
                   completionHandler:^(id _Nullable result, NSError * _Nullable error1) {
            evalResult = result;
            evalError = error1;
        }];
        
        NSTimeInterval beginAt = [[NSDate date] timeIntervalSinceReferenceDate];
        while (!evalResult && !evalError) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            NSTimeInterval endAt = [[NSDate date] timeIntervalSinceReferenceDate];
            if (endAt - beginAt > 3.0) {
                break;
            }
        }
        CHDebugLogSource(@"TamperMonkey eval result = %@, error = %@", evalResult, evalError);
        
        if (!evalResult) {
            if (error && evalError) {
                *error = evalError;
            }
            return nil;
        }
        
        NSString *evalObject = nil;
        if ([evalResult isKindOfClass:[NSDictionary class]] || [evalResult isKindOfClass:[NSArray class]]) {
            evalObject = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:evalResult options:kNilOptions error:error] encoding:NSUTF8StringEncoding];
        } else {
            evalObject = [NSString stringWithFormat:@"%@", evalResult];
        }
        
        evalResult = nil;
        evalError = nil;
        
        CHDebugLogSource(@"TamperMonkey eval object = %@", evalObject);
        return evalObject;
    }
    
    return nil;
}


+ (NSDictionary *)tamperMonkeyGetSafeDictionaryOfError:(NSError *)error {
    @autoreleasepool {
        NSMutableDictionary *safeDict = [NSMutableDictionary dictionary];
        for (id errKey in error.userInfo) {
            id errVal = error.userInfo[errKey];
            if ([errKey isKindOfClass:[NSString class]] && ([errVal isKindOfClass:[NSString class]] || [errVal isKindOfClass:[NSNumber class]]))
            {
                [safeDict setObject:errVal forKey:errKey];
            }
        }
        return safeDict;
    }
}


IMP_XPC_HANDLER_TIMEOUT(ClientListWebViews, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientGetWebViewById, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientGetWebView, 3.0);

IMP_XPC_HANDLER_TIMEOUT(ClientGetTopMostFormControl, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientUpdateTopMostFormControl, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientDismissTopMostFormControl, 3.0);

IMP_XPC_HANDLER_TIMEOUT(ClientCloseAllTabs, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientIsPrivateBrowsingEnabled, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientSetPrivateBrowsingEnabled, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientSetPrivateBrowsingDisabled, 3.0);

IMP_XPC_HANDLER_TIMEOUT(ClientEvalById, 10.0);
IMP_XPC_HANDLER_TIMEOUT(ClientEval, 10.0);

IMP_XPC_HANDLER_TIMEOUT(ClientEnterTextById, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientEnterText, 3.0);

IMP_XPC_HANDLER_TIMEOUT(ClientListUserScriptMessages, 3.0);
IMP_XPC_HANDLER_TIMEOUT(ClientClearUserScriptMessages, 3.0);


- (nullable NSDictionary *)handleRemoteActionWithRequest:(NSDictionary *)request {
    if ([TFLuaBridge tamperMonkeyXPCPaused]) {
        return nil;
    }
    
    NSString *actionName = request[@"action"];

    if ([actionName isEqualToString:@"ClientListWebViews"]) {
        @autoreleasepool {
            NSArray <TMWeakViewWrapper *> *localWrappers = [TFLuaBridge tamperMonkeyReloadWrappers];
            
            NSMutableArray <NSDictionary *> *webStatusList = [NSMutableArray arrayWithCapacity:localWrappers.count];
            for (TMWeakViewWrapper *wrapper in localWrappers) {
                NSDictionary *wrapperAttrs = [TFLuaBridge tamperMonkeyGetWrapperAttributes:wrapper];
                if (!wrapperAttrs) {
                    continue;
                }
                [webStatusList addObject:wrapperAttrs];
            }

            NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
            NSMutableDictionary *data = [NSMutableDictionary dictionaryWithCapacity:2];
            if ([bundleId isKindOfClass:[NSString class]]) {
                [data setObject:bundleId forKey:@"responder"];
            }
            [data setObject:[webStatusList copy] forKey:@"views"];

            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": data,
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientGetWebViewById"]) {
        @autoreleasepool {
            NSString *objectIdentifier = request[@"data"][@"objectIdentifier"];
            
            TMWeakViewWrapper *targetWrapper = nil;
            if (pthread_mutex_trylock(&__localViewCacheLock) == 0) {
                for (TMWeakViewWrapper *wrapper in __localViewCache) {
                    if ([[wrapper uniqueIdentifier] isEqualToString:objectIdentifier]) {
                        targetWrapper = wrapper;
                    }
                }
                pthread_mutex_unlock(&__localViewCacheLock);
            }
            
            NSDictionary *wrapperAttrs = [TFLuaBridge tamperMonkeyGetWrapperAttributes:targetWrapper];
            if (!wrapperAttrs) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": wrapperAttrs,
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientGetWebView"]) {
        @autoreleasepool {
            NSDictionary *matchingRequest = request[@"data"][@"matchingRequest"];
            if ([matchingRequest[@"objectIdentifier"] isKindOfClass:[NSString class]]) {
                return [self handleRemoteActionWithRequest:@{ @"action": @"ClientGetWebViewById", @"data": @{ @"objectIdentifier": matchingRequest[@"objectIdentifier"] } }];
            }
            
            NSArray <TMWeakViewWrapper *> *localWrappers = [TFLuaBridge tamperMonkeyReloadWrappers];
            
            TMWeakViewWrapper *matchedWrapper = nil;
            for (TMWeakViewWrapper *wrapper in localWrappers) {
                NSURL *viewURL = [TFLuaBridge tamperMonkeyGetURLFromWebView:wrapper.weakView];
                if ([TFLuaBridge tamperMonkeyCheckURL:viewURL forLegacyDictionary:matchingRequest]) {
                    matchedWrapper = wrapper;
                    break;
                }
            }
            
            NSDictionary *wrapperAttrs = [TFLuaBridge tamperMonkeyGetWrapperAttributes:matchedWrapper];
            if (!wrapperAttrs) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": wrapperAttrs,
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientEvalById"]) {
        @autoreleasepool {
            NSString *evalContent = request[@"data"][@"evalContent"];
            NSString *objectIdentifier = request[@"data"][@"objectIdentifier"];
            
            TMWeakViewWrapper *targetWrapper = nil;
            if (pthread_mutex_trylock(&__localViewCacheLock) == 0) {
                for (TMWeakViewWrapper *wrapper in __localViewCache) {
                    if ([[wrapper uniqueIdentifier] isEqualToString:objectIdentifier]) {
                        targetWrapper = wrapper;
                    }
                }
                pthread_mutex_unlock(&__localViewCacheLock);
            }
            
            NSDictionary *wrapperAttrs = [TFLuaBridge tamperMonkeyGetWrapperAttributes:targetWrapper];
            if (!wrapperAttrs) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            NSError *evalError = nil;
            NSString *evalResult = [TFLuaBridge tamperMonkeyEvaluateJavascript:evalContent inWebView:targetWrapper.weakView withError:&evalError];
            if (!evalResult) {
                return @{
                    @"code": @(200),
                    @"msg": @"JavaScript Error",
                    @"data": @{
                        @"error": [TFLuaBridge tamperMonkeyGetSafeDictionaryOfError:evalError],
                    },
                };
            }
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                    @"result": evalResult,
                },
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientEnterTextById"]) {
        @autoreleasepool {
            NSString *enterText = request[@"data"][@"enterText"];
            NSString *objectIdentifier = request[@"data"][@"objectIdentifier"];
            
            TMWeakViewWrapper *targetWrapper = nil;
            if (pthread_mutex_trylock(&__localViewCacheLock) == 0) {
                for (TMWeakViewWrapper *wrapper in __localViewCache) {
                    if ([[wrapper uniqueIdentifier] isEqualToString:objectIdentifier]) {
                        targetWrapper = wrapper;
                    }
                }
                pthread_mutex_unlock(&__localViewCacheLock);
            }
            
            NSDictionary *wrapperAttrs = [TFLuaBridge tamperMonkeyGetWrapperAttributes:targetWrapper];
            if (!wrapperAttrs) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            WKWebView *wkWebView = (WKWebView *)targetWrapper.weakView;
            WKContentView *wkContentView = CHIvar(wkWebView, _contentView, __strong WKContentView *);
            if (
                ![wkWebView isKindOfClass:NSClassFromString(@"WKWebView")] ||
                ![wkContentView respondsToSelector:@selector(_hasFocusedElement)] ||
                ![wkWebView respondsToSelector:@selector(_simulateTextEntered:)]
                )
            {
                return @{
                    @"code": @(422),
                    @"msg": @"Unprocessable Entity",
                    @"data": @{},
                };
            }
            
            if (![wkContentView _hasFocusedElement]) {
                return @{
                    @"code": @(418),
                    @"msg": @"I'm a teapot. You must focus an element.",
                    @"data": @{},
                };
            }
            
            [wkWebView _simulateTextEntered:enterText];
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientEval"]) {
        @autoreleasepool {
            NSString *evalContent = request[@"data"][@"evalContent"];
            
            NSDictionary *matchingRequest = request[@"data"][@"matchingRequest"];
            if ([matchingRequest[@"objectIdentifier"] isKindOfClass:[NSString class]]) {
                return [self handleRemoteActionWithRequest:@{ @"action": @"ClientEvalById", @"data": @{ @"objectIdentifier": matchingRequest[@"objectIdentifier"], @"evalContent": evalContent } }];
            }
            
            NSArray <TMWeakViewWrapper *> *localWrappers = [TFLuaBridge tamperMonkeyReloadWrappers];
            
            TMWeakViewWrapper *matchedWrapper = nil;
            for (TMWeakViewWrapper *wrapper in localWrappers) {
                NSURL *viewURL = [TFLuaBridge tamperMonkeyGetURLFromWebView:wrapper.weakView];
                if ([TFLuaBridge tamperMonkeyCheckURL:viewURL forLegacyDictionary:matchingRequest]) {
                    matchedWrapper = wrapper;
                    break;
                }
            }
            
            NSDictionary *wrapperAttrs = [TFLuaBridge tamperMonkeyGetWrapperAttributes:matchedWrapper];
            if (!wrapperAttrs) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            NSError *evalError = nil;
            NSString *evalResult = [TFLuaBridge tamperMonkeyEvaluateJavascript:evalContent inWebView:matchedWrapper.weakView withError:&evalError];
            if (!evalResult) {
                return @{
                    @"code": @(200),
                    @"msg": @"JavaScript Error",
                    @"data": @{
                        @"error": [TFLuaBridge tamperMonkeyGetSafeDictionaryOfError:evalError],
                    },
                };
            }
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                    @"result": evalResult,
                },
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientEnterText"]) {
        @autoreleasepool {
            NSString *enterText = request[@"data"][@"enterText"];
            
            NSDictionary *matchingRequest = request[@"data"][@"matchingRequest"];
            if ([matchingRequest[@"objectIdentifier"] isKindOfClass:[NSString class]]) {
                return [self handleRemoteActionWithRequest:@{ @"action": @"ClientEnterTextById", @"data": @{ @"objectIdentifier": matchingRequest[@"objectIdentifier"], @"enterText": enterText } }];
            }
            
            NSArray <TMWeakViewWrapper *> *localWrappers = [TFLuaBridge tamperMonkeyReloadWrappers];
            
            TMWeakViewWrapper *matchedWrapper = nil;
            for (TMWeakViewWrapper *wrapper in localWrappers) {
                NSURL *viewURL = [TFLuaBridge tamperMonkeyGetURLFromWebView:wrapper.weakView];
                if ([TFLuaBridge tamperMonkeyCheckURL:viewURL forLegacyDictionary:matchingRequest]) {
                    matchedWrapper = wrapper;
                    break;
                }
            }
            
            NSDictionary *wrapperAttrs = [TFLuaBridge tamperMonkeyGetWrapperAttributes:matchedWrapper];
            if (!wrapperAttrs) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            WKWebView *wkWebView = (WKWebView *)matchedWrapper.weakView;
            WKContentView *wkContentView = CHIvar(wkWebView, _contentView, __strong WKContentView *);
            if (
                ![wkWebView isKindOfClass:NSClassFromString(@"WKWebView")] ||
                ![wkContentView respondsToSelector:@selector(_hasFocusedElement)] ||
                ![wkWebView respondsToSelector:@selector(_simulateTextEntered:)]
                )
            {
                return @{
                    @"code": @(422),
                    @"msg": @"Unprocessable Entity",
                    @"data": @{},
                };
            }
            
            if (![wkContentView _hasFocusedElement]) {
                return @{
                    @"code": @(418),
                    @"msg": @"I'm a teapot.",
                    @"data": @{},
                };
            }
            
            [wkWebView _simulateTextEntered:enterText];
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientClearUserScriptMessages"]) {
        @autoreleasepool {
            if (0 != pthread_rwlock_tryrdlock(&__localRegisteredWrappersLock)) {
                return @{
                    @"code": @(502),
                    @"msg": @"Bad Gateway",
                    @"data": @{},
                };
            }
            
            for (TMWeakUserContentControllerWrapper *userContentControllerWrapper in __localRegisteredWrappers) {
                [userContentControllerWrapper removeNilProxies];
                
                for (TMWeakObjectWrapper *wrapper in userContentControllerWrapper.weakProxies) {
                    if ([wrapper.weakObject isKindOfClass:[TMScriptMessageProxy class]]) {
                        TMScriptMessageProxy *messageProxy = (TMScriptMessageProxy *)wrapper.weakObject;
                        
                        [messageProxy removeAllReceivedMessages];
                    }
                }
            }
            
            pthread_rwlock_unlock(&__localRegisteredWrappersLock);
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientListUserScriptMessages"]) {
        @autoreleasepool {
            NSMutableArray <NSDictionary *> *filteredMessages = [[NSMutableArray alloc] init];
            
            if (0 != pthread_rwlock_tryrdlock(&__localRegisteredWrappersLock)) {
                return @{
                    @"code": @(502),
                    @"msg": @"Bad Gateway",
                    @"data": @{},
                };
            }
            
            NSDictionary *matchingRequest = request[@"data"][@"matchingRequest"];
            for (TMWeakUserContentControllerWrapper *userContentControllerWrapper in __localRegisteredWrappers) {
                [userContentControllerWrapper removeNilProxies];
                
                for (TMWeakObjectWrapper *wrapper in userContentControllerWrapper.weakProxies) {
                    if ([wrapper.weakObject isKindOfClass:[TMScriptMessageProxy class]]) {
                        TMScriptMessageProxy *messageProxy = (TMScriptMessageProxy *)wrapper.weakObject;
                        for (NSDictionary *message in messageProxy.receivedMessages) {
                            NSMutableDictionary *mMessage = [message mutableCopy];
                            
                            BOOL validated = NO;
                            NSMutableDictionary *mFrameInfo = [[message objectForKey:@"frameInfo"] mutableCopy];
                            
                            NSURL *requestURL = message[@"frameInfo"][@"requestURL"];
                            if ([requestURL isKindOfClass:[NSURL class]]) {
                                if ([TFLuaBridge tamperMonkeyCheckURL:requestURL forLegacyDictionary:matchingRequest]) {
                                    validated = YES;
                                    [mFrameInfo setObject:[requestURL absoluteString] forKey:@"requestURL"];
                                    [mMessage addEntriesFromDictionary:[TFLuaBridge tamperMonkeyGetDictionaryFromURL:requestURL]];
                                }
                            }
                            
                            NSURL *requestMainDocumentURL = message[@"frameInfo"][@"requestMainDocumentURL"];
                            if ([requestMainDocumentURL isKindOfClass:[NSURL class]]) {
                                if ([TFLuaBridge tamperMonkeyCheckURL:requestMainDocumentURL forLegacyDictionary:matchingRequest]) {
                                    validated = YES;
                                    [mFrameInfo setObject:[requestMainDocumentURL absoluteString] forKey:@"requestMainDocumentURL"];
                                    [mMessage addEntriesFromDictionary:[TFLuaBridge tamperMonkeyGetDictionaryFromURL:requestMainDocumentURL]];
                                }
                            }
                            
                            if (validated) {
                                [mMessage setObject:mFrameInfo forKey:@"frameInfo"];
                                [filteredMessages addObject:mMessage];
                            }
                        }
                    }
                }
            }
            
            pthread_rwlock_unlock(&__localRegisteredWrappersLock);
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": filteredMessages,
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientGetTopMostFormControl"]) {
        @autoreleasepool {
            NSDictionary *formControlDictionary = [TFLuaBridge tamperMonkeyGetDictionaryFromFormControl:[TFLuaBridge tamperMonkeyXPCTopMostFormControl]];
            
            if (!formControlDictionary) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": formControlDictionary,
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientUpdateTopMostFormControl"]) {
        @autoreleasepool {
            id formControl = [TFLuaBridge tamperMonkeyXPCTopMostFormControl];
            NSDictionary *formControlDictionary = [TFLuaBridge tamperMonkeyGetDictionaryFromFormControl:formControl];
            
            if (!formControlDictionary) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            if ([formControl isKindOfClass:NSClassFromString(@"WKFormSelectControl")]) {
                NSAssert([NSThread isMainThread], @"main thread only");
                
                NSArray <NSDictionary *> *items = formControlDictionary[@"items"];
                NSUInteger rowIndexToOperate = NSNotFound;
                id matchingRequest = request[@"data"][@"matchingRequest"];
                if ([matchingRequest isKindOfClass:[NSString class]]) {
                    NSArray <NSString *> *flattenedItems = formControlDictionary[@"flattenedItems"];
                    rowIndexToOperate = [flattenedItems indexOfObject:(NSString *)matchingRequest];
                } else if ([matchingRequest isKindOfClass:[NSNumber class]]) {
                    rowIndexToOperate = [(NSNumber *)matchingRequest unsignedIntegerValue];
                    if (rowIndexToOperate == 0 || rowIndexToOperate > items.count) {
                        rowIndexToOperate = NSNotFound;
                    } else {
                        rowIndexToOperate -= 1;  // convert lua index to c index
                    }
                } else if ([matchingRequest isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *matchingDict = (NSDictionary *)matchingRequest;
                    if ([[matchingDict objectForKey:@"value"] isKindOfClass:[NSString class]]) {
                        for (NSUInteger itemIdx = 0; itemIdx < items.count; itemIdx++) {
                            NSDictionary *anItem = items[itemIdx];
                            if ([[anItem objectForKey:@"value"] isEqualToString:[matchingDict objectForKey:@"value"]]) {
                                rowIndexToOperate = itemIdx;
                                break;
                            }
                        }
                    }
                } else {
                    return @{
                        @"code": @(400),
                        @"msg": @"Bad Request",
                        @"data": @{},
                    };
                }
                
                if (rowIndexToOperate == NSNotFound) {
                    return @{
                        @"code": @(404),
                        @"msg": @"Item Not Found",
                        @"data": @{},
                    };
                }
                
                BOOL shouldExtend = [request[@"data"][@"shouldExtend"] boolValue];
                WKFormSelectControl *control = (WKFormSelectControl *)formControl;
                [control selectRow:rowIndexToOperate inComponent:0 extendingSelection:shouldExtend];
                
                return @{
                    @"code": @(200),
                    @"msg": @"OK",
                    @"data": @{},
                };
            }
            else if ([formControl isKindOfClass:NSClassFromString(@"WKDateTimeInputControl")]) {
                NSAssert([NSThread isMainThread], @"main thread only");
                
                id matchingRequest = request[@"data"][@"matchingRequest"];
                if (![matchingRequest isKindOfClass:[NSNumber class]]) {
                    return @{
                        @"code": @(400),
                        @"msg": @"Bad Request",
                        @"data": @{},
                    };
                }
                
                NSTimeInterval targetInterval = [(NSNumber *)matchingRequest doubleValue];
                NSDate *targetDate = [NSDate dateWithTimeIntervalSince1970:targetInterval];
                
                WKDateTimeInputControl *control = (WKDateTimeInputControl *)formControl;
                [control setTimePickerDate:targetDate];
                
                return @{
                    @"code": @(200),
                    @"msg": @"OK",
                    @"data": @{},
                };
            }
        }
    }
    
    else if ([actionName isEqualToString:@"ClientDismissTopMostFormControl"]) {
        @autoreleasepool {
            id formControl = [TFLuaBridge tamperMonkeyXPCTopMostFormControl];
            
            if (!formControl) {
                return @{
                    @"code": @(404),
                    @"msg": @"Page Not Found",
                    @"data": @{},
                };
            }
            
            WKContentView *contentView = CHIvar(formControl, _view, __strong WKContentView *);
            [contentView accessoryDone];
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientCloseAllTabs"]) {
        @autoreleasepool {
            UIApplication *app = [UIApplication sharedApplication];
            BrowserWindowController *browserWindowController = CHIvar(app, _browserWindowController, __strong BrowserWindowController *);
            [browserWindowController monkeyCloseAllTabs];
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientIsPrivateBrowsingEnabled"]) {
        @autoreleasepool {
            UIApplication *app = [UIApplication sharedApplication];
            BrowserWindowController *browserWindowController = CHIvar(app, _browserWindowController, __strong BrowserWindowController *);
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @([[[browserWindowController browserControllers] firstObject] isPrivateBrowsingEnabled]),
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientSetPrivateBrowsingEnabled"]) {
        @autoreleasepool {
            UIApplication *app = [UIApplication sharedApplication];
            BrowserWindowController *browserWindowController = CHIvar(app, _browserWindowController, __strong BrowserWindowController *);
            [[[browserWindowController browserControllers] firstObject] setPrivateBrowsingEnabled:YES];
            
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ClientSetPrivateBrowsingDisabled"]) {
        @autoreleasepool {
            UIApplication *app = [UIApplication sharedApplication];
            BrowserWindowController *browserWindowController = CHIvar(app, _browserWindowController, __strong BrowserWindowController *);
            [[[browserWindowController browserControllers] firstObject] setPrivateBrowsingEnabled:NO];
            
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


/* MARK: ----------------------------------------------------------------------- */


IMP_LUA_HANDLER(list_webviews) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientListWebViews:@{} error:&error];
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

IMP_LUA_HANDLER(get_webview_id) {
    @autoreleasepool {
        const char *objectId = luaL_checkstring(L, 1);
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientGetWebViewById:@{ @"objectIdentifier": [NSString stringWithUTF8String:objectId] } error:&error];
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

IMP_LUA_HANDLER(get_webview) {
    @autoreleasepool {
        luaL_checktype(L, 1, LUA_TTABLE);
        id matchingTable = lua_toNSValuex(L, 1, 0);
        if (![matchingTable isKindOfClass:[NSDictionary class]]) {
            return luaL_argerror(L, 1, "dictionary expected");
        }
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientGetWebView:@{ @"matchingRequest": matchingTable } error:&error];
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

IMP_LUA_HANDLER(eval_id) {
    @autoreleasepool {
        const char *objectId = luaL_checkstring(L, 1);
        const char *cContent = luaL_checkstring(L, 2);
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientEvalById:@{ @"objectIdentifier": [NSString stringWithUTF8String:objectId], @"evalContent": [NSString stringWithUTF8String:cContent] } error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushnil(L);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
        }
        
        lua_pushNSValuex(L, ret[@"result"], 0);
        lua_pushNSValuex(L, ret[@"error"], 0);
        return 2;
    }
}

IMP_LUA_HANDLER(enter_text_id) {
    @autoreleasepool {
        const char *objectId = luaL_checkstring(L, 1);
        const char *cContent = luaL_checkstring(L, 2);
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientEnterTextById:@{ @"objectIdentifier": [NSString stringWithUTF8String:objectId], @"enterText": [NSString stringWithUTF8String:cContent] } error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushnil(L);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
        }
        
        lua_pushNSValuex(L, ret[@"result"], 0);
        lua_pushNSValuex(L, ret[@"error"], 0);
        return 2;
    }
}

IMP_LUA_HANDLER(eval) {
    @autoreleasepool {
        luaL_checktype(L, 1, LUA_TTABLE);
        
        id matchingTable = lua_toNSValuex(L, 1, 0);
        if (![matchingTable isKindOfClass:[NSDictionary class]]) {
            return luaL_argerror(L, 1, "dictionary expected");
        }
        
        const char *cContent = luaL_checkstring(L, 2);
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientEval:@{ @"matchingRequest": matchingTable, @"evalContent": [NSString stringWithUTF8String:cContent] } error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushnil(L);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
        }
        
        lua_pushNSValuex(L, ret[@"result"], 0);
        lua_pushNSValuex(L, ret[@"error"], 0);
        return 2;
    }
}

IMP_LUA_HANDLER(enter_text) {
    @autoreleasepool {
        luaL_checktype(L, 1, LUA_TTABLE);
        
        id matchingTable = lua_toNSValuex(L, 1, 0);
        if (![matchingTable isKindOfClass:[NSDictionary class]]) {
            return luaL_argerror(L, 1, "dictionary expected");
        }
        
        const char *cContent = luaL_checkstring(L, 2);
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientEnterText:@{ @"matchingRequest": matchingTable, @"enterText": [NSString stringWithUTF8String:cContent] } error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushnil(L);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
                return 2;
            }
            return luaL_error(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
        }
        
        lua_pushNSValuex(L, ret[@"result"], 0);
        lua_pushNSValuex(L, ret[@"error"], 0);
        return 2;
    }
}

#define lua_optboolean(L, i, d) (lua_isnoneornil(L, i) ? d : lua_toboolean(L, i))

IMP_LUA_HANDLER(add_userscript) {
    @autoreleasepool {
        luaL_checktype(L, 1, LUA_TTABLE);
        id value = lua_toNSValuex(L, 1, 0);
        if (![value isKindOfClass:[NSDictionary class]]) {
            return luaL_argerror(L, 1, "dictionary expected");
        }
        
        const char *cContent = luaL_checkstring(L, 2);
        
        int cWhere = lua_optboolean(L, 3, false);  // document start false end true
        int cMainFrameOnly = lua_optboolean(L, 4, false);  // if main frame only true
        
        NSDictionary *req = @{
            @"matchingRequest": value,
            @"evalContent": [NSString stringWithUTF8String:cContent],
            @"injectionTime": cWhere == 0 ? @"document-start" : @"document-end",
            @"forMainFrameOnly": cMainFrameOnly != 0 ? @(YES) : @(NO),
        };
        
        NSError *error = nil;
        NSMutableDictionary *userDefaults = [[[TFLuaBridge sharedInstance] readDefaultsWithError:&error] mutableCopy];
        if (![userDefaults isKindOfClass:[NSDictionary class]]) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }
        
        NSMutableArray <NSDictionary *> *userScripts = [([userDefaults objectForKey:@"userScripts"] ?: @[]) mutableCopy];
        [userScripts addObject:req];
        
        [userDefaults setObject:userScripts forKey:@"userScripts"];
        BOOL retVal = [[TFLuaBridge sharedInstance] writeDefaults:userDefaults withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }
        
        return 0;
    }
}

IMP_LUA_HANDLER(remove_all_userscripts) {
    @autoreleasepool {
        NSError *error = nil;
        BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"userScripts": @[] } withError:&error];
        if (!retVal) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }
        
        return 0;
    }
}

IMP_LUA_HANDLER(list_userscripts) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *userDefaults = [[TFLuaBridge sharedInstance] readDefaultsWithError:&error];
        if (![userDefaults isKindOfClass:[NSDictionary class]]) {
            return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
        }
        
        NSArray <NSDictionary *> *userScripts = [userDefaults objectForKey:@"userScripts"] ?: @[];
        lua_pushNSValuex(L, userScripts, 0);
        return 1;
    }
}

IMP_LUA_HANDLER(list_userscript_messages) {
    @autoreleasepool {
        luaL_checktype(L, 1, LUA_TTABLE);
        id value = lua_toNSValuex(L, 1, 0);
        if (![value isKindOfClass:[NSDictionary class]]) {
            return luaL_argerror(L, 1, "dictionary expected");
        }
        
        NSError *error = nil;
        NSArray <NSDictionary *> *ret = [TFLuaBridge ClientListUserScriptMessages:@{ @"matchingRequest": value } error:&error];
        if (![ret isKindOfClass:[NSArray class]]) {
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

IMP_LUA_HANDLER(clear_userscript_messages) {
    @autoreleasepool {
        NSError *error = nil;
        NSArray <NSDictionary *> *ret = [TFLuaBridge ClientClearUserScriptMessages:@{} error:&error];
        if (![ret isKindOfClass:[NSDictionary class]]) {
            if ([[error domain] hasSuffix:@".RecoverableError"]) {
                lua_pushnil(L);
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

IMP_LUA_HANDLER(get_topmost_formcontrol) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientGetTopMostFormControl:@{} error:&error];
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

IMP_LUA_HANDLER(update_topmost_formcontrol) {
    @autoreleasepool {
        id objValue = nil;

        int valueType = lua_type(L, 1);
        if (valueType != LUA_TTABLE && valueType != LUA_TSTRING && valueType != LUA_TNUMBER) {
            luaL_checktype(L, 1, LUA_TTABLE);
            return 0;
        }
        
        if (valueType == LUA_TTABLE) {
            objValue = lua_toNSValuex(L, 1, 0);
            if (![objValue isKindOfClass:[NSDictionary class]]) {
                return luaL_argerror(L, 1, "dictionary expected");
            }
        }
        else if (valueType == LUA_TSTRING) {
            const char *cValue = luaL_checkstring(L, 1);
            objValue = [NSString stringWithUTF8String:cValue];
        }
        else if (valueType == LUA_TNUMBER) {
            lua_Integer cValue = luaL_checkinteger(L, 1);
            objValue = @(cValue);
        }
        else {
            objValue = @(0);
        }
        
        int cExtend = lua_optboolean(L, 2, false);
        
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientUpdateTopMostFormControl:@{
            @"matchingRequest": objValue,
            @"shouldExtend": cExtend != 0 ? @(YES) : @(NO),
        } error:&error];
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

IMP_LUA_HANDLER(dismiss_topmost_formcontrol) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientDismissTopMostFormControl:@{} error:&error];
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

IMP_LUA_HANDLER(close_all_tabs) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientCloseAllTabs:@{} error:&error];
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

IMP_LUA_HANDLER(private_browsing_on) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientSetPrivateBrowsingEnabled:@{} error:&error];
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

IMP_LUA_HANDLER(private_browsing_off) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *ret = [TFLuaBridge ClientSetPrivateBrowsingDisabled:@{} error:&error];
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

IMP_LUA_HANDLER_MAP[] = {
    
    /* legacy */
    DECLARE_LUA_HANDLER(list_webviews),
    DECLARE_LUA_HANDLER(get_webview_id),
    DECLARE_LUA_HANDLER(get_webview),
    DECLARE_LUA_HANDLER(eval_id),
    DECLARE_LUA_HANDLER(eval),
    DECLARE_LUA_HANDLER(enter_text_id),
    DECLARE_LUA_HANDLER(enter_text),
    
    /* user scripts */
    DECLARE_LUA_HANDLER(add_userscript),
    DECLARE_LUA_HANDLER(remove_all_userscripts),
    DECLARE_LUA_HANDLER(list_userscripts),
    
    /* user script messages */
    DECLARE_LUA_HANDLER(list_userscript_messages),
    DECLARE_LUA_HANDLER(clear_userscript_messages),
    
    /* form control */
    DECLARE_LUA_HANDLER(get_topmost_formcontrol),
    DECLARE_LUA_HANDLER(update_topmost_formcontrol),
    DECLARE_LUA_HANDLER(dismiss_topmost_formcontrol),
    
    /* tab control */
    DECLARE_LUA_HANDLER(close_all_tabs),
    
    /* private browsing */
    DECLARE_LUA_HANDLER(private_browsing_on),
    DECLARE_LUA_HANDLER(private_browsing_off),
    
    DECLARE_NULL
};


/* MARK: ----------------------------------------------------------------------- */


static void RegisterWKWebViewConfiguration(WKWebView *webView, WKWebViewConfiguration *configuration)
{
    @autoreleasepool {
        if (!configuration.userContentController) return;
        MyLog(@"configuration initialized %@ configuration %@", webView, configuration);
        
        WKUserContentController *userContentController = configuration.userContentController;
        
        static NSArray <NSDictionary *> *payloadsToAttach = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __localRegisteredWrappers = [[NSMutableArray alloc] init];
            
            NSError *defaultsError = nil;
            NSDictionary *userDefaults = [[TFLuaBridge sharedInstance] readDefaultsWithError:&defaultsError];
            if (![userDefaults isKindOfClass:[NSDictionary class]]) {
                return;
            }
            
            NSArray <NSDictionary *> *userScripts = [userDefaults objectForKey:@"userScripts"] ?: @[];
            NSMutableArray <NSDictionary *> *filteredUserScripts = [userScripts mutableCopy];
            NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
            if ([bundleId isKindOfClass:[NSString class]]) {
                for (NSDictionary *userScript in userScripts) {
                    NSString *restrictedResponder = userScript[@"matchingRequest"][@"responder"];
                    if ([restrictedResponder isKindOfClass:[NSString class]] && ![bundleId isEqualToString:restrictedResponder]) {
                        [filteredUserScripts removeObject:userScript];
                    }
                }
            }
            
            payloadsToAttach = [filteredUserScripts copy];
            
    #if DEBUG
            NSLog(@"[%@][Client #2] payloads prepared %@", @XPC_INSTANCE_NAME, payloadsToAttach);
    #endif
        });
        
        pthread_rwlock_wrlock(&__localRegisteredWrappersLock);
        
        // add new wrapper
        TMWeakUserContentControllerWrapper *newWrapper = [[TMWeakUserContentControllerWrapper alloc] initWithUserContentController:userContentController];
        BOOL hasConfiguration = NO;
        for (TMWeakUserContentControllerWrapper *wrapper in __localRegisteredWrappers) {
            if (wrapper.userContentController == userContentController) {
                hasConfiguration = YES;
                break;
            }
        }
        if (!hasConfiguration) {
            
            // add message handler
            TMScriptMessageProxy *msgProxy = [[TMScriptMessageProxy alloc] init];
            [userContentController removeScriptMessageHandlerForName:@"$_TM_WKNativeLog"];
            [userContentController addScriptMessageHandler:msgProxy name:@"$_TM_WKNativeLog"];
            TMWeakObjectWrapper *msgProxyWrapper = [[TMWeakObjectWrapper alloc] initWithWeakObject:msgProxy];
            [newWrapper addWeakProxy:msgProxyWrapper];
            
            // add networking handler
            TMScriptNetworkingProxy *netProxy = [[TMScriptNetworkingProxy alloc] init];
            [userContentController removeScriptMessageHandlerForName:@"$_TM_WKNativeRequestSync"];
            [userContentController addScriptMessageHandler:netProxy name:@"$_TM_WKNativeRequestSync"];
            TMWeakObjectWrapper *netProxyWrapper = [[TMWeakObjectWrapper alloc] initWithWeakObject:netProxy];
            [newWrapper addWeakProxy:netProxyWrapper];
            
            // add user scripts
            for (NSDictionary *payloadToAttach in payloadsToAttach) {
                @autoreleasepool {
                    WKUserScriptInjectionTime injectionTime = [[payloadToAttach objectForKey:@"injectionTime"] isEqualToString:@"document-end"] ? WKUserScriptInjectionTimeAtDocumentEnd : WKUserScriptInjectionTimeAtDocumentStart;
                    BOOL forMainFrameOnly = [[payloadToAttach objectForKey:@"forMainFrameOnly"] boolValue];
                    
                    NSString *evalContent = [payloadToAttach objectForKey:@"evalContent"];
                    if (![evalContent isKindOfClass:[NSString class]]) {
                        continue;
                    }
                    
                    NSString *matchingString = nil;
                    NSDictionary *matchingRequest = [payloadToAttach objectForKey:@"matchingRequest"];
                    if ([matchingRequest isKindOfClass:[NSDictionary class]]) {
                        NSError *jsonError = nil;
                        NSData *matchingJSONData = [NSJSONSerialization dataWithJSONObject:matchingRequest options:kNilOptions error:&jsonError];
                        if (matchingJSONData) {
                            NSString *matchingJSONEncodedString = [matchingJSONData base64EncodedStringWithOptions:kNilOptions];
                            matchingString = [NSString stringWithFormat:@"JSON.parse(window.atob(\"%@\"))", matchingJSONEncodedString];
                        }
                    }
                    
                    NSString *jsSource = nil;
                    if (matchingString) {
                        jsSource = [TFLuaBridge tamperMonkeyGeneratePayloadWithTags:@[
                            @"MATCHING", @"PAYLOAD",
                        ] fromJavascriptContents:@[
                            matchingString, evalContent,
                        ]];
                    } else {
                        jsSource = [TFLuaBridge tamperMonkeyGeneratePayloadWithTags:@[
                            @"PAYLOAD",
                        ] fromJavascriptContents:@[
                            evalContent,
                        ]];
                    }
                    
                    Class wkUserScriptClass = NSClassFromString(@"WKUserScript");  // undefined linkage
                    WKUserScript *userScript = [[wkUserScriptClass alloc] initWithSource:jsSource
                                                                           injectionTime:injectionTime
                                                                        forMainFrameOnly:forMainFrameOnly];
                    [userContentController addUserScript:userScript];
                    
                    CHDebugLog(@"[%@][Client #2] user script %@ will be injected to %@ at %@ for %@", @XPC_INSTANCE_NAME, userScript, userContentController, injectionTime == WKUserScriptInjectionTimeAtDocumentStart ? @"document start" : @"document end", forMainFrameOnly ? @"for main frame only" : @"for all frames");
                }
            }
            
            [__localRegisteredWrappers addObject:newWrapper];
        }
        
        // remove outdated wrappers
        NSMutableArray <TMWeakUserContentControllerWrapper *> *outdatedWrappers = [[NSMutableArray alloc] initWithCapacity:__localRegisteredWrappers.count];
        for (TMWeakUserContentControllerWrapper *wrapper in __localRegisteredWrappers) {
            if (wrapper.userContentController == nil) {
                [outdatedWrappers addObject:wrapper];
            }
        }
        [__localRegisteredWrappers removeObjectsInArray:outdatedWrappers];
        
        pthread_rwlock_unlock(&__localRegisteredWrappersLock);
    }
}

static WKWebView *(*original_WKWebView_initWithCoder_)(WKWebView *, SEL, NSCoder *);
static WKWebView *replaced_WKWebView_initWithCoder_(WKWebView *self, SEL _cmd, NSCoder *coder)
{
    WKWebView *originalWebView = original_WKWebView_initWithCoder_(self, _cmd, coder);
    if (originalWebView) {
        // do it here
        RegisterWKWebViewConfiguration(self, originalWebView.configuration);
    }
    return originalWebView;
}

static WKWebView *(*original_WKWebView_initWithFrame_configuration_)(WKWebView *, SEL, CGRect, WKWebViewConfiguration *);
static WKWebView *replaced_WKWebView_initWithFrame_configuration_(WKWebView *self, SEL _cmd, CGRect frame, WKWebViewConfiguration *configuration)
{
    // do it here
    RegisterWKWebViewConfiguration(self, configuration);
    WKWebView *originalWebView = original_WKWebView_initWithFrame_configuration_(self, _cmd, frame, configuration);
    if (originalWebView) {
        // nothing to do
    }
    return originalWebView;
}


#pragma mark -

OBJC_EXTERN void SetupTamperMonkey(void);
void SetupTamperMonkey() {
    [TFLuaBridge setSharedInstanceName:@XPC_INSTANCE_NAME];
    TFLuaBridge *bridge = [TFLuaBridge sharedInstance];
    if (bridge.instanceRole == TFLuaBridgeRoleClient) {
        MyHookMessage(
            _cc(WKWebView),
            @selector(initWithCoder:),
            (IMP)replaced_WKWebView_initWithCoder_,
            (IMP *)&original_WKWebView_initWithCoder_
        );
        MyHookMessage(
            _cc(WKWebView),
            @selector(initWithFrame:configuration:),
            (IMP)replaced_WKWebView_initWithFrame_configuration_,
            (IMP *)&original_WKWebView_initWithFrame_configuration_
        );
        
#if DEBUG
        NSLog(@"[%@][Client #2] Objective-C message hooks initialized for WKWebView", @XPC_INSTANCE_NAME);
#endif
    }
}

CHConstructor {
    @autoreleasepool {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            pthread_mutex_init(&__localViewCacheLock, NULL);
            pthread_rwlock_init(&__localRegisteredWrappersLock, NULL);
            
#if DEBUG
            __localBlackURLComponents = @[
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
#endif
        });
        
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
            NSArray <NSString *> *bundleIdentifierComponents = [bundleIdentifier componentsSeparatedByString:@"."];
            BOOL isInBlacklist = NO;
            for (NSString *bundleIdentifierComponent in bundleIdentifierComponents) {
                if ([__localBlackURLComponents containsObject:bundleIdentifierComponent]) {
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
            SetupTamperMonkey();
        } while (NO);
    }
}

LuaConstructor {
    SetupTamperMonkey();
    lua_createtable(L, 0, (sizeof(DECLARE_LUA_HANDLER_MAP) / sizeof((DECLARE_LUA_HANDLER_MAP)[0]) - 1) + 2);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, DECLARE_LUA_HANDLER_MAP, 0);
    return 1;
}


/* MARK: ----------------------------------------------------------------------- */

