#import <Foundation/Foundation.h>
#import "TFCookiesManager.h"
#import "WebServ.h"


OBJC_EXTERN void register_cookies_manager_handlers(GCDWebServer *webServer);
void register_cookies_manager_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"GET", @"POST", @"PUT", @"DELETE"], @"/cookies", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *anyId = request.query[@"id"];
                NSString *appId = request.query[@"app"];
                NSString *groupId = request.query[@"group"];
                NSString *pluginId = request.query[@"plugin"];
                
                TFCookiesManager *cookiesManager = nil;
                if (!anyId.length && !appId.length)
                {
                    cookiesManager = [TFCookiesManager sharedSafariManager];
                }
                else if (anyId.length)
                {
                    cookiesManager = [TFCookiesManager managerWithAnyIdentifier:anyId];
                }
                else
                {
                    if (groupId.length)
                    {
                        cookiesManager = [TFCookiesManager managerWithBundleIdentifier:appId groupIdentifier:groupId];
                    }
                    else if (pluginId.length)
                    {
                        cookiesManager = [TFCookiesManager managerWithBundleIdentifier:appId pluginIdentifier:pluginId];
                    }
                    else
                    {
                        cookiesManager = [TFCookiesManager managerWithBundleIdentifier:appId];
                    }
                }
                
                if (!cookiesManager)
                {
                    completionBlock(resp_bad_request(@"id"));
                    return;
                }
                
                NSError *err = nil;
                if ([[request.method uppercaseString] isEqualToString:@"GET"])
                {
                    NSString *domain = request.query[@"domain"] ?: request.query[@"Domain"];
                    NSString *path = request.query[@"path"] ?: request.query[@"Path"];
                    NSString *name = request.query[@"name"] ?: request.query[@"Name"];
                    
                    if (domain.length && name.length)
                    {
                        NSDictionary <NSHTTPCookiePropertyKey, id> *cookies = [cookiesManager getCookiesWithDomain:domain path:path name:name error:&err];
                        if (!cookies)
                        {
                            completionBlock(resp_operation_failed(err.code, [err localizedDescription]));
                            return;
                        }
                        
                        completionBlock(resp_operation_succeed(cookies));
                    }
                    else if (domain.length)
                    {
                        NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *cookies = [cookiesManager filterCookiesWithDomain:domain path:path error:&err];
                        if (!cookies)
                        {
                            completionBlock(resp_operation_failed(err.code, [err localizedDescription]));
                            return;
                        }
                        
                        completionBlock(resp_operation_succeed(cookies));
                    }
                    else
                    {
                        NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *cookies = [cookiesManager readCookiesWithError:&err];
                        if (!cookies)
                        {
                            completionBlock(resp_operation_failed(err.code, [err localizedDescription]));
                            return;
                        }
                        
                        completionBlock(resp_operation_succeed(cookies));
                    }
                    
                    return;
                }
                else if ([[request.method uppercaseString] isEqualToString:@"POST"])
                {
                    NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *cookies = request.jsonObject;
                    if (![cookies isKindOfClass:[NSArray class]])
                    {
                        completionBlock(resp_bad_request(nil));
                        return;
                    }
                    
                    BOOL added = [cookiesManager setCookies:cookies error:&err];
                    if (!added)
                    {
                        completionBlock(resp_operation_failed(err.code, [err localizedDescription]));
                        return;
                    }
                    
                    completionBlock(resp_operation_succeed(nil));
                    return;
                }
                else if ([[request.method uppercaseString] isEqualToString:@"PUT"])
                {
                    NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *cookies = request.jsonObject;
                    if (![cookies isKindOfClass:[NSArray class]])
                    {
                        completionBlock(resp_bad_request(nil));
                        return;
                    }
                    
                    BOOL wrote = [cookiesManager writeCookies:cookies error:&err];
                    if (!wrote)
                    {
                        completionBlock(resp_operation_failed(err.code, [err localizedDescription]));
                        return;
                    }
                    
                    completionBlock(resp_operation_succeed(nil));
                    return;
                }
                else if ([[request.method uppercaseString] isEqualToString:@"DELETE"])
                {
                    NSString *expiration = request.query[@"expiration"];
                    NSDate *expirationDate = nil;
                    if (expiration.length)
                    {
                        expirationDate = [[TFCookiesManager sharedCookiesDateFormatter] dateFromString:expiration];
                        if (!expirationDate)
                        {
                            expirationDate = [NSDate dateWithTimeIntervalSince1970:[expiration doubleValue]];
                        }
                    }
                    
                    BOOL cleared;
                    if (expirationDate)
                    {
                        cleared = [cookiesManager removeCookiesExpiredBeforeDate:expirationDate error:&err];
                    }
                    else
                    {
                        cleared = [cookiesManager clearCookiesWithError:&err];
                    }
                    
                    if (!cleared)
                    {
                        completionBlock(resp_operation_failed(err.code, [err localizedDescription]));
                        return;
                    }
                    
                    completionBlock(resp_operation_succeed(nil));
                    return;
                }
                
                completionBlock(resp_bad_request(nil));
            }
        });
    });
}
