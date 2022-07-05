//
//  TMScriptNetworkingProxy.m
//  TamperMonkey
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TMScriptNetworkingProxy.h"


OBJC_EXTERN NSString *kLuaBridgeInstanceName;

@implementation TMScriptNetworkingProxy

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    @autoreleasepool {
        id messageBody = message.body;
        if (![messageBody isKindOfClass:[NSDictionary class]]) return;
        
        NSDictionary *messageBodyDict = (NSDictionary *)messageBody;
        if (![messageBodyDict[@"data"] isKindOfClass:[NSDictionary class]] || ![messageBodyDict[@"id"] isKindOfClass:[NSString class]]) return;
        
        NSString *messageHandle = messageBodyDict[@"id"];
        messageBodyDict = messageBodyDict[@"data"];
        NSString *reqMethod = [messageBodyDict[@"method"] isKindOfClass:[NSString class]] ? messageBodyDict[@"method"] : @"GET";
        NSString *reqURLString = [messageBodyDict[@"url"] isKindOfClass:[NSString class]] ? messageBodyDict[@"url"] : @"about:blank";
        NSString *reqData = [messageBodyDict[@"data"] isKindOfClass:[NSString class]] ? messageBodyDict[@"data"] : nil;
        NSDictionary *reqHeaders = [messageBodyDict[@"headers"] isKindOfClass:[NSDictionary class]] ? messageBodyDict[@"headers"] : nil;
        
        NSURL *reqURL = [NSURL URLWithString:reqURLString];
        if (!reqURL) return;  // invalid url
        
        __strong WKWebView *wkWebView = message.webView;  // Use webView instance HERE!
        if (!wkWebView) return;
        
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:reqURL];
        urlRequest.HTTPMethod = reqMethod;
        urlRequest.allHTTPHeaderFields = reqHeaders;
        urlRequest.HTTPBody = [reqData dataUsingEncoding:NSUTF8StringEncoding];
        
        CHDebugLog(@"[%@][Client #2] xmlHttpRequest initialized %@ url %@ method %@ headers %@ body %@", kLuaBridgeInstanceName, urlRequest, reqURL, reqMethod, reqHeaders, reqData);
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool {
                NSHTTPURLResponse *response = nil;
                NSError *error = nil;
                
                NSData *respData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
                if (respData) {
                    
                    NSString *respEncodedStr = [respData base64EncodedStringWithOptions:kNilOptions];
                    NSString *respUTF8Str = [[NSString alloc] initWithData:respData encoding:NSUTF8StringEncoding];
                    NSDictionary *respDict = @{
                        @"data": respEncodedStr,
                        @"responseHeaders": response.allHeaderFields,
                        @"responseText": respUTF8Str ?: [NSNull null],
                        @"status": @(response.statusCode),
                        @"statusText": [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode] ?: [NSNull null],
                    };
                    
                    NSData *respDumpedData = [NSJSONSerialization dataWithJSONObject:respDict options:kNilOptions error:&error];
                    if (respDumpedData) {
                        NSString *respStr = [respDumpedData base64EncodedStringWithOptions:kNilOptions];
                        NSString *respCallbackStr = [NSString stringWithFormat:@"window.$_TM_WKHandlerOnMessageReceive({ id: '%@', data: '%@', error: null });", messageHandle, respStr];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            @autoreleasepool {
                                CHDebugLog(@"[%@][Client #2] xmlHttpRequest %@ finished %@ url %@ resp code %ld headers %@ body %@", kLuaBridgeInstanceName, wkWebView, urlRequest, reqURL, response.statusCode, response.allHeaderFields, respCallbackStr);
                                [wkWebView evaluateJavaScript:respCallbackStr completionHandler:^(id _Nullable ret, NSError * _Nullable error1) {
                                    CHDebugLog(@"[%@][Client #2] xmlHttpRequest %@ finished %@ url %@ callback %@ error %@", kLuaBridgeInstanceName, wkWebView, urlRequest, reqURL, ret, error1);
                                }];
                            }
                        });
                        
                        return;
                    }
                }
                
                if (error) {
                    
                    NSString *errStr = [[error.localizedDescription dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:kNilOptions];
                    NSString *errCallbackStr = [NSString stringWithFormat:@"window.$_TM_WKHandlerOnMessageReceive({ id: '%@', data: null, error: '%@' });", messageHandle, errStr];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        @autoreleasepool {
                            CHDebugLog(@"[%@][Client #2] xmlHttpRequest %@ failed %@ url %@ error %@", kLuaBridgeInstanceName, wkWebView, urlRequest, reqURL, errCallbackStr);
                            [wkWebView evaluateJavaScript:errCallbackStr completionHandler:^(id _Nullable ret, NSError * _Nullable error) {
                                CHDebugLog(@"[%@][Client #2] xmlHttpRequest %@ failed %@ url %@ callback %@ error %@", kLuaBridgeInstanceName, wkWebView, urlRequest, reqURL, ret, error);
                            }];
                        }
                    });
                    
                    return;
                }
            }
        });
    }
}

- (void)dealloc {
    CHDebugLog(@"[%@][Client #2] <%@ dealloc>", kLuaBridgeInstanceName, NSStringFromClass([self class]));
}

@end
