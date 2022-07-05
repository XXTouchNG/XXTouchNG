//
//  WebServ.h
//  XXTouch
//
//  Created by Lessica on 2022/6/22.
//

#ifndef WebServ_h
#define WebServ_h

#import <sys/socket.h>
#import <Foundation/Foundation.h>

#ifdef  __cplusplus
extern "C" {
#endif

#import "GCDWebServer.h"
#import "GCDWebDAVServer.h"
#import "GCDWebServerDataRequest.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerFileResponse.h"
#import "GCDWebServerErrorResponse.h"
#import "GCDWebServerFunctions.h"

#ifdef  __cplusplus
}
#endif


#define WEBSERV_PORT 46952
#define WEBSERV_PORT_V1 46059            /* TouchSprite / XXTouch Legacy IDE */
#define WEBSERV_BROADCAST_PORT 46953
#define WEBSERV_BROADCAST_PORT_V1 14099  /* TouchSprite & TouchElf */

#define WEBSERV_LOGGING_UDP_RECV_PORT 46956
#define WEBSERV_LOGGING_SERVER_PORT 46957

#define WEBSERV_BONJOUR_NAME @"XXTouch OpenAPI"


OBJC_EXTERN BOOL _remoteAccessEnabled;
OBJC_EXTERN dispatch_queue_t _serviceQueue;
OBJC_EXTERN NSFileManager *_serviceFileManager;

NS_INLINE NSString *strip_unsafe_components(NSString *path)
{
    @autoreleasepool {
        NSMutableArray <NSString *> *pathComponents = [[path componentsSeparatedByString:@"/"] mutableCopy];
        [pathComponents removeObject:@""];
        [pathComponents removeObject:@"."];
        [pathComponents removeObject:@".."];
        return [pathComponents componentsJoinedByString:@"/"];
    }
}

NS_INLINE BOOL is_localhost(GCDWebServerRequest *request)
{
    @autoreleasepool {
        NSString *remoteAddr = [request remoteAddressString];
        return [remoteAddr hasPrefix:@"127.0.0.1:"] || [remoteAddr hasPrefix:@"localhost:"];
    }
}

NS_INLINE BOOL is_accessible(GCDWebServerRequest *request)
{
    return is_localhost(request) || _remoteAccessEnabled;
}

OBJC_EXTERN NSString *GCDWebServerStringFromSockAddr(const struct sockaddr *addr, BOOL includeService);

NS_INLINE BOOL is_addr_localhost(NSData *addressData)
{
    @autoreleasepool {
        NSString *remoteAddr = GCDWebServerStringFromSockAddr((const struct sockaddr *)addressData.bytes, NO);
        return [remoteAddr isEqualToString:@"127.0.0.1"] || [remoteAddr isEqualToString:@"localhost"];
    }
}

NS_INLINE BOOL is_addr_accessible(NSData *addressData)
{
    return is_addr_localhost(addressData) || _remoteAccessEnabled;
}

NS_INLINE GCDWebServerResponse *resp_remote_access_forbidden(void)
{
    @autoreleasepool {
        return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"forbidden"];
    }
}

NS_INLINE GCDWebServerResponse *resp_v1_unauthorized(void)
{
    @autoreleasepool {
        GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithText:@"unauthorized"];
        resp.statusCode = kGCDWebServerHTTPStatusCode_Unauthorized;
        return resp;
    }
}

NS_INLINE GCDWebServerResponse *resp_bad_request(NSString *hintField)
{
    @autoreleasepool {
        GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithJSONObject:@{
            @"code": @(8), @"message": hintField != nil ? [NSString stringWithFormat:@"bad parameter: %@", hintField] : @"bad request" } contentType:@"application/json"];
        resp.statusCode = kGCDWebServerHTTPStatusCode_BadRequest;
        return resp;
    }
}

NS_INLINE GCDWebServerResponse *resp_v1_bad_request(void)
{
    @autoreleasepool {
        GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithText:@"bad request"];
        resp.statusCode = kGCDWebServerHTTPStatusCode_BadRequest;
        return resp;
    }
}

NS_INLINE GCDWebServerResponse *resp_v1_not_found(void)
{
    @autoreleasepool {
        GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithText:@"not found"];
        resp.statusCode = kGCDWebServerHTTPStatusCode_NotFound;
        return resp;
    }
}

NS_INLINE GCDWebServerResponse *resp_v1_internal_server_error(NSString *reason)
{
    @autoreleasepool {
        GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithText:reason ?: @"internal server error"];
        resp.statusCode = kGCDWebServerHTTPStatusCode_InternalServerError;
        return resp;
    }
}

NS_INLINE GCDWebServerResponse *resp_v1_service_unavailable(void)
{
    @autoreleasepool {
        GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithText:@"service unavailable"];
        resp.statusCode = kGCDWebServerHTTPStatusCode_ServiceUnavailable;
        return resp;
    }
}

NS_INLINE GCDWebServerResponse *resp_operation_succeed(id dataObject)
{
    @autoreleasepool {
        if (!dataObject) {
            return [GCDWebServerDataResponse responseWithJSONObject:@{
                @"code": @(0), @"message": @"Operation succeed" } contentType:@"application/json"];
        } else {
            return [GCDWebServerDataResponse responseWithJSONObject:@{
                @"code": @(0), @"message": @"Operation succeed", @"data": dataObject } contentType:@"application/json"];
        }
    }
}

NS_INLINE GCDWebServerResponse *resp_v1_ok_204(void)
{
    @autoreleasepool {
        GCDWebServerResponse *resp = [GCDWebServerDataResponse response];
        resp.statusCode = kGCDWebServerHTTPStatusCode_NoContent;
        return resp;
    }
}

NS_INLINE GCDWebServerResponse *resp_v1_ok(void)
{
    @autoreleasepool {
        return [GCDWebServerDataResponse responseWithText:@"ok"];
    }
}

NS_INLINE GCDWebServerResponse *resp_operation_succeed_flat(NSDictionary *dataDictionary)
{
    @autoreleasepool {
        if (!dataDictionary) {
            return [GCDWebServerDataResponse responseWithJSONObject:@{
                @"code": @(0), @"message": @"Operation succeed" } contentType:@"application/json"];
        } else {
            NSMutableDictionary *respDict = [NSMutableDictionary dictionaryWithDictionary:@{ @"code": @(0), @"message": @"Operation succeed" }];
            [respDict addEntriesFromDictionary:dataDictionary];
            return [GCDWebServerDataResponse responseWithJSONObject:respDict contentType:@"application/json"];
        }
    }
}

NS_INLINE GCDWebServerResponse *resp_operation_failed(NSInteger code, id errorMessage)
{
    @autoreleasepool {
        return [GCDWebServerDataResponse responseWithJSONObject:@{
            @"code": @(code),
            @"message": [errorMessage isKindOfClass:[NSString class]] ? errorMessage : @"Operation failed",
            @"details": [errorMessage isKindOfClass:[NSDictionary class]] ? errorMessage : @{}
        } contentType:@"application/json"];
    }
}

NS_INLINE GCDWebServerResponse *resp_v1_fail(void)
{
    @autoreleasepool {
        return [GCDWebServerDataResponse responseWithText:@"fail"];
    }
}

NS_INLINE GCDWebServerResponse *resp_operation_failed_400(NSInteger code, id errorMessage)
{
    @autoreleasepool {
        GCDWebServerDataResponse *resp = [GCDWebServerDataResponse responseWithJSONObject:@{
            @"code": @(code),
            @"message": [errorMessage isKindOfClass:[NSString class]] ? errorMessage : @"Operation failed",
            @"details": [errorMessage isKindOfClass:[NSDictionary class]] ? errorMessage : @{}
        } contentType:@"application/json"];
        resp.statusCode = kGCDWebServerHTTPStatusCode_BadRequest;
        return resp;
    }
}

NS_INLINE GCDWebServerResponse *resp_operation_failed_flat(NSInteger code, NSString *errorMessage, NSDictionary *errorDictionary)
{
    @autoreleasepool {
        if (!errorDictionary) {
            return resp_operation_failed(code, errorDictionary);
        } else {
            NSMutableDictionary *respDict = [NSMutableDictionary dictionaryWithDictionary:@{ @"code": @(code), @"message": errorMessage ?: @"Operation failed" }];
            [respDict addEntriesFromDictionary:errorDictionary];
            return [GCDWebServerDataResponse responseWithJSONObject:respDict contentType:@"application/json"];
        }
    }
}

NS_INLINE GCDWebServerResponse *resp_operation_failed_flat_400(NSInteger code, NSString *errorMessage, NSDictionary *errorDictionary)
{
    @autoreleasepool {
        GCDWebServerResponse *resp = nil;
        if (!errorDictionary) {
            resp = resp_operation_failed(code, errorDictionary);
        } else {
            NSMutableDictionary *respDict = [NSMutableDictionary dictionaryWithDictionary:@{ @"code": @(code), @"message": errorMessage ?: @"Operation failed" }];
            [respDict addEntriesFromDictionary:errorDictionary];
            resp = [GCDWebServerDataResponse responseWithJSONObject:respDict contentType:@"application/json"];
        }
        resp.statusCode = kGCDWebServerHTTPStatusCode_BadRequest;
        return resp;
    }
}

NS_INLINE
void register_path_handler(GCDWebServer *webServer, NSArray <NSString *> *allowedMethods, NSString *path, GCDWebServerProcessBlock handler)
{
    @autoreleasepool {
        NSMutableArray <NSString *> *methodsMod = [NSMutableArray arrayWithArray:allowedMethods];
        [methodsMod removeObject:@"OPTIONS"];
        NSMutableString *allowedHeaders = [NSMutableString string];
        for (NSString *method in methodsMod) {
            [webServer addHandlerForMethod:method
                                      path:path
                              requestClass:[GCDWebServerDataRequest class]
                              processBlock:handler];
            [allowedHeaders appendString:method];
            [allowedHeaders appendString:@", "];
        }
        [allowedHeaders appendString:@"OPTIONS"];
        [webServer addHandlerForMethod:@"OPTIONS"
                                  path:path
                          requestClass:[GCDWebServerDataRequest class]
                          processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request)
         {
            @autoreleasepool {
                GCDWebServerResponse *resp = [GCDWebServerResponse responseWithStatusCode:200];
                [resp setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
                [resp setValue:allowedHeaders forAdditionalHeader:@"Access-Control-Allow-Methods"];
                [resp setValue:allowedHeaders forAdditionalHeader:@"Allow"];
                [resp setValue:@"DNT, X-Mx-ReqToken, Keep-Alive, User-Agent, X-Requested-With, If-Modified-Since, Cache-Control, Content-Type, Authorization" forAdditionalHeader:@"Access-Control-Allow-Headers"];
                return resp;
            }
        }];
    }
}

NS_INLINE
void register_regex_handler(GCDWebServer *webServer, NSArray <NSString *> *allowedMethods, NSString *pathRegex, GCDWebServerProcessBlock handler)
{
    @autoreleasepool {
        NSMutableArray <NSString *> *methodsMod = [NSMutableArray arrayWithArray:allowedMethods];
        [methodsMod removeObject:@"OPTIONS"];
        NSMutableString *allowedHeaders = [NSMutableString string];
        for (NSString *method in methodsMod) {
            [webServer addHandlerForMethod:method
                                 pathRegex:pathRegex
                              requestClass:[GCDWebServerDataRequest class]
                              processBlock:handler];
            [allowedHeaders appendString:method];
            [allowedHeaders appendString:@", "];
        }
        [allowedHeaders appendString:@"OPTIONS"];
        [webServer addHandlerForMethod:@"OPTIONS"
                             pathRegex:pathRegex
                          requestClass:[GCDWebServerDataRequest class]
                          processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request)
         {
            @autoreleasepool {
                GCDWebServerResponse *resp = [GCDWebServerResponse responseWithStatusCode:200];
                [resp setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
                [resp setValue:allowedHeaders forAdditionalHeader:@"Access-Control-Allow-Methods"];
                [resp setValue:allowedHeaders forAdditionalHeader:@"Allow"];
                [resp setValue:@"DNT, X-Mx-ReqToken, Keep-Alive, User-Agent, X-Requested-With, If-Modified-Since, Cache-Control, Content-Type, Authorization" forAdditionalHeader:@"Access-Control-Allow-Headers"];
                return resp;
            }
        }];
    }
}

NS_INLINE
void register_path_handler_async(GCDWebServer *webServer, NSArray <NSString *> *allowedMethods, NSString *path, GCDWebServerAsyncProcessBlock asyncHandler)
{
    @autoreleasepool {
        NSMutableArray <NSString *> *methodsMod = [NSMutableArray arrayWithArray:allowedMethods];
        [methodsMod removeObject:@"OPTIONS"];
        NSMutableString *allowedHeaders = [NSMutableString string];
        for (NSString *method in methodsMod) {
            [webServer addHandlerForMethod:method
                                      path:path
                              requestClass:[GCDWebServerDataRequest class]
                         asyncProcessBlock:asyncHandler];
            [allowedHeaders appendString:method];
            [allowedHeaders appendString:@", "];
        }
        [allowedHeaders appendString:@"OPTIONS"];
        [webServer addHandlerForMethod:@"OPTIONS"
                                  path:path
                          requestClass:[GCDWebServerDataRequest class]
                          processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request)
         {
            @autoreleasepool {
                GCDWebServerResponse *resp = [GCDWebServerResponse responseWithStatusCode:200];
                [resp setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
                [resp setValue:allowedHeaders forAdditionalHeader:@"Access-Control-Allow-Methods"];
                [resp setValue:allowedHeaders forAdditionalHeader:@"Allow"];
                [resp setValue:@"DNT, X-Mx-ReqToken, Keep-Alive, User-Agent, X-Requested-With, If-Modified-Since, Cache-Control, Content-Type, Authorization" forAdditionalHeader:@"Access-Control-Allow-Headers"];
                return resp;
            }
        }];
    }
}

NS_INLINE
void register_regex_handler_async(GCDWebServer *webServer, NSArray <NSString *> *allowedMethods, NSString *pathRegex, GCDWebServerAsyncProcessBlock asyncHandler)
{
    @autoreleasepool {
        NSMutableArray <NSString *> *methodsMod = [NSMutableArray arrayWithArray:allowedMethods];
        [methodsMod removeObject:@"OPTIONS"];
        NSMutableString *allowedHeaders = [NSMutableString string];
        for (NSString *method in methodsMod) {
            [webServer addHandlerForMethod:method
                                 pathRegex:pathRegex
                              requestClass:[GCDWebServerDataRequest class]
                         asyncProcessBlock:asyncHandler];
            [allowedHeaders appendString:method];
            [allowedHeaders appendString:@", "];
        }
        [allowedHeaders appendString:@"OPTIONS"];
        [webServer addHandlerForMethod:@"OPTIONS"
                             pathRegex:pathRegex
                          requestClass:[GCDWebServerDataRequest class]
                          processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request)
         {
            @autoreleasepool {
                GCDWebServerResponse *resp = [GCDWebServerResponse responseWithStatusCode:200];
                [resp setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
                [resp setValue:allowedHeaders forAdditionalHeader:@"Access-Control-Allow-Methods"];
                [resp setValue:allowedHeaders forAdditionalHeader:@"Allow"];
                [resp setValue:@"DNT, X-Mx-ReqToken, Keep-Alive, User-Agent, X-Requested-With, If-Modified-Since, Cache-Control, Content-Type, Authorization" forAdditionalHeader:@"Access-Control-Allow-Headers"];
                return resp;
            }
        }];
    }
}

#endif /* WebServ_h */
