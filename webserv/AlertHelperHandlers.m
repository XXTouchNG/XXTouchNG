//
//  AlertHelperHandlers.m
//  webserv
//
//  Created by Lessica on 2022/6/22.
//

#import <Foundation/Foundation.h>
#import "AlertHelper.h"
#import "TFLuaBridge.h"
#import "WebServ.h"


@interface TFLuaBridge (AlertHelper)
DECLARE_XPC_HANDLER(ClientInputText);
DECLARE_XPC_HANDLER(ClientShake);
DECLARE_XPC_HANDLER(ClientSetOrientation);

DECLARE_XPC_HANDLER(ClientGetTopMostDialog);
DECLARE_XPC_HANDLER(ClientDismissTopMostDialog);
@end

OBJC_EXTERN void register_alert_helper_handlers(GCDWebServer *webServer);
void register_alert_helper_handlers(GCDWebServer *webServer)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SetupAlertHelper();
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/enable_logging", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"loggingEnabled": @(YES) } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/disable_logging", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"loggingEnabled": @(NO) } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/enable_autopass", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"autoBypassEnabled": @(YES) } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/disable_autopass", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"autoBypassEnabled": @(NO) } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/set_autopass_delay", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSNumber *delay = request.jsonObject[@"delay"];
                if (![delay isKindOfClass:[NSNumber class]])
                {
                    completionBlock(resp_bad_request(@"delay"));
                    return;
                }
                
                NSTimeInterval cDelay = [delay doubleValue];
                
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"autoBypassDelay": @(cDelay < 100.0 ? 1.0 : cDelay / 1000.0) } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/get_local_rules", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *bundleIdentifier = request.jsonObject[@"bid"];
                if (![bundleIdentifier isKindOfClass:[NSString class]])
                {
                    completionBlock(resp_bad_request(@"bid"));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *userDefaults = [[TFLuaBridge sharedInstance] readDefaultsWithError:&error];
                if (![userDefaults isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                NSArray <NSDictionary *> *dialogRules = [userDefaults objectForKey:bundleIdentifier] ?: @[];
                completionBlock(resp_operation_succeed(dialogRules));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/set_local_rules", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *bundleIdentifier = request.jsonObject[@"bid"];
                if (![bundleIdentifier isKindOfClass:[NSString class]])
                {
                    completionBlock(resp_bad_request(@"bid"));
                    return;
                }
                
                NSArray <NSDictionary *> *dialogRules = request.jsonObject[@"data"];
                if (![dialogRules isKindOfClass:[NSArray class]])
                {
                    completionBlock(resp_bad_request(@"data"));
                    return;
                }
                
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ bundleIdentifier: dialogRules } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/clear_local_rules", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *bundleIdentifier = request.jsonObject[@"bid"];
                if (![bundleIdentifier isKindOfClass:[NSString class]])
                {
                    completionBlock(resp_bad_request(@"bid"));
                    return;
                }
                
                if ([bundleIdentifier isEqualToString:@"*"])
                {
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
                        completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                        return;
                    }
                }
                else
                {
                    NSError *error = nil;
                    BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ bundleIdentifier: @[] } withError:&error];
                    if (!retVal) {
                        completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                        return;
                    }
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/get_global_rules", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *userDefaults = [[TFLuaBridge sharedInstance] readDefaultsWithError:&error];
                if (![userDefaults isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                NSArray <NSDictionary *> *dialogRules = [userDefaults objectForKey:@"__GLOBAL__"] ?: @[];
                completionBlock(resp_operation_succeed(dialogRules));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/set_global_rules", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSArray <NSDictionary *> *dialogRules = request.jsonObject[@"data"];
                if (![dialogRules isKindOfClass:[NSArray class]])
                {
                    completionBlock(resp_bad_request(@"data"));
                    return;
                }
                
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"__GLOBAL__": dialogRules } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/clear_global_rules", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"__GLOBAL__": @[] } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/app/input_text", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *inputString = request.text;
                if (!inputString) {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientInputText:@{ @"inputString": inputString, @"inputInterval": @(0) } error:&error];
                
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/app/set_orientation", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *inputString = request.text;
                if (!inputString) {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSInteger lOrientation = [inputString integerValue];
                
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
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/app/shake", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientShake:@{} error:&error];
                
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/get_top_most_dialog", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientGetTopMostDialog:@{} error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/alert/dismiss_top_most_dialog", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                id dictValue = request.jsonObject;
                if (!dictValue) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientDismissTopMostDialog:@{ @"applyRule": dictValue } error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
}
