#import <Foundation/Foundation.h>
#import "TamperMonkey.h"
#import "TFLuaBridge.h"
#import "WebServ.h"


@interface TFLuaBridge (TamperMonkey)

DECLARE_XPC_HANDLER(ClientListWebViews);

DECLARE_XPC_HANDLER(ClientGetWebViewById);
DECLARE_XPC_HANDLER(ClientGetWebView);

DECLARE_XPC_HANDLER(ClientEvalById);
DECLARE_XPC_HANDLER(ClientEval);

DECLARE_XPC_HANDLER(ClientEnterTextById);
DECLARE_XPC_HANDLER(ClientEnterText);

DECLARE_XPC_HANDLER(ClientGetTopMostFormControl);
DECLARE_XPC_HANDLER(ClientUpdateTopMostFormControl);
DECLARE_XPC_HANDLER(ClientDismissTopMostFormControl);

DECLARE_XPC_HANDLER(ClientCloseAllTabs);
DECLARE_XPC_HANDLER(ClientSetPrivateBrowsingEnabled);
DECLARE_XPC_HANDLER(ClientSetPrivateBrowsingDisabled);

DECLARE_XPC_HANDLER(ClientListUserScriptMessages);
DECLARE_XPC_HANDLER(ClientClearUserScriptMessages);

@end

OBJC_EXTERN void register_tamper_monkey_handlers(GCDWebServer *webServer);
void register_tamper_monkey_handlers(GCDWebServer *webServer)
{
    SetupTamperMonkey();
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/list_webviews", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientListWebViews:@{} error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/get_webview_id", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *objectId = request.jsonObject[@"objectIdentifier"];
                if (![objectId isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"objectIdentifier"));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientGetWebViewById:@{ @"objectIdentifier": objectId } error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/get_webview", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSDictionary *matchingTable = request.jsonObject;
                if (![matchingTable isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientGetWebView:@{ @"matchingRequest": matchingTable } error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/eval_id", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *objectId = request.jsonObject[@"objectIdentifier"];
                if (![objectId isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"objectIdentifier"));
                    return;
                }
                
                NSString *cContent = request.jsonObject[@"evalContent"];
                if (![cContent isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"evalContent"));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientEvalById:@{ @"objectIdentifier": objectId, @"evalContent": cContent } error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                if ([ret[@"error"] isKindOfClass:[NSString class]] || [ret[@"error"] isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(1, ret[@"error"]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret[@"result"]));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/eval", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSDictionary *matchingTable = request.jsonObject;
                if (![matchingTable isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSString *cContent = request.jsonObject[@"evalContent"];
                if (![cContent isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"evalContent"));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientEval:@{ @"matchingRequest": matchingTable, @"evalContent": cContent } error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                if ([ret[@"error"] isKindOfClass:[NSString class]] || [ret[@"error"] isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(1, ret[@"error"]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret[@"result"]));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/input_id", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *objectId = request.jsonObject[@"objectIdentifier"];
                if (![objectId isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"objectIdentifier"));
                    return;
                }
                
                NSString *cContent = request.jsonObject[@"enterText"];
                if (![cContent isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"enterText"));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientEnterTextById:@{ @"objectIdentifier": objectId, @"enterText": cContent } error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                if ([ret[@"error"] isKindOfClass:[NSString class]] || [ret[@"error"] isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(1, ret[@"error"]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret[@"result"]));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/input", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSDictionary *matchingTable = request.jsonObject;
                if (![matchingTable isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSString *cContent = request.jsonObject[@"enterText"];
                if (![cContent isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"enterText"));
                    return;
                }
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientEnterText:@{ @"matchingTable": matchingTable, @"enterText": cContent } error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                if ([ret[@"error"] isKindOfClass:[NSString class]] || [ret[@"error"] isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(1, ret[@"error"]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret[@"result"]));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/get_topmost_formcontrol", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientGetTopMostFormControl:@{} error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/update_topmost_formcontrol", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                id objValue = request.jsonObject[@"value"];
                if (!objValue) {
                    completionBlock(resp_bad_request(@"value"));
                    return;
                }
                
                NSNumber *shouldExtend = request.jsonObject[@"extend"];
                if (shouldExtend != nil && ![shouldExtend isKindOfClass:[NSNumber class]]) {
                    completionBlock(resp_bad_request(@"extend"));
                    return;
                }
                
                BOOL cExtend = [shouldExtend boolValue];
                
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientUpdateTopMostFormControl:@{
                    @"matchingRequest": objValue,
                    @"shouldExtend": @(cExtend),
                } error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/dismiss_topmost_formcontrol", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientDismissTopMostFormControl:@{} error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/close_all_tabs", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientCloseAllTabs:@{} error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/private_browsing_on", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientSetPrivateBrowsingEnabled:@{} error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/private_browsing_off", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                NSDictionary *ret = [TFLuaBridge ClientSetPrivateBrowsingDisabled:@{} error:&error];
                if (![ret isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(ret));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/add_userscript", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSDictionary *userScriptDict = request.jsonObject;
                if (![userScriptDict isKindOfClass:[NSDictionary class]])
                {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSString *evalContent = request.jsonObject[@"evalContent"];
                if (![evalContent isKindOfClass:[NSString class]])
                {
                    completionBlock(resp_bad_request(@"evalContent"));
                    return;
                }
                
                id injectionTime = request.jsonObject[@"injectionTime"];
                if (injectionTime != nil && ![injectionTime isKindOfClass:[NSString class]] && ![injectionTime isKindOfClass:[NSNumber class]])
                {
                    completionBlock(resp_bad_request(@"injectionTime"));
                    return;
                }
                
                int cWhere = 0;
                if ([injectionTime isKindOfClass:[NSString class]])
                {
                    cWhere = [injectionTime isEqualToString:@"document-start"] ? 0 : 1;
                }
                else if ([injectionTime isKindOfClass:[NSNumber class]])
                {
                    cWhere = [injectionTime intValue];
                }
                
                NSNumber *forMainFrameOnly = request.jsonObject[@"forMainFrameOnly"];
                if (forMainFrameOnly != nil && ![forMainFrameOnly isKindOfClass:[NSNumber class]])
                {
                    completionBlock(resp_bad_request(@"forMainFrameOnly"));
                    return;
                }
                
                BOOL cMainFrameOnly = [forMainFrameOnly boolValue];
                
                NSDictionary *req = @{
                    @"matchingRequest": userScriptDict,
                    @"evalContent": evalContent,
                    @"injectionTime": cWhere == 0 ? @"document-start" : @"document-end",
                    @"forMainFrameOnly": @(cMainFrameOnly),
                };
                
                NSError *error = nil;
                NSMutableDictionary *userDefaults = [[[TFLuaBridge sharedInstance] readDefaultsWithError:&error] mutableCopy];
                if (![userDefaults isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                NSMutableArray <NSDictionary *> *userScripts = [([userDefaults objectForKey:@"userScripts"] ?: @[]) mutableCopy];
                [userScripts addObject:req];
                
                [userDefaults setObject:userScripts forKey:@"userScripts"];
                BOOL retVal = [[TFLuaBridge sharedInstance] writeDefaults:userDefaults withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/list_userscripts", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
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
                
                NSArray <NSDictionary *> *userScripts = [userDefaults objectForKey:@"userScripts"] ?: @[];
                completionBlock(resp_operation_succeed(userScripts));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/monkey/clear_userscripts", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSError *error = nil;
                BOOL retVal = [[TFLuaBridge sharedInstance] addEnteriesToDefaults:@{ @"userScripts": @[] } withError:&error];
                if (!retVal) {
                    completionBlock(resp_operation_failed(error.code, [error localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
}
