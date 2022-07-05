//
//  TMScriptMessageProxy.m
//  TamperMonkey
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TMScriptMessageProxy.h"


OBJC_EXTERN NSString *kLuaBridgeInstanceName;

@implementation TMScriptMessageProxy {
    NSMutableArray <NSDictionary *> *_receivedMessages;
    dispatch_queue_t _messageQueue;
}

+ (NSDictionary *)dictionaryRepresentationOfFrameInfo:(WKFrameInfo *)frameInfo {
    @autoreleasepool {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
            @"isMainFrame": @(frameInfo.mainFrame),
            @"securityOrigin": @{
                @"protocol": frameInfo.securityOrigin.protocol,
                @"host": frameInfo.securityOrigin.host,
                @"port": @(frameInfo.securityOrigin.port),
            },
        }];
        if (frameInfo.request.URL) {
            [dict setObject:frameInfo.request.URL forKey:@"requestURL"];
        }
        if (frameInfo.request.mainDocumentURL) {
            [dict setObject:frameInfo.request.mainDocumentURL forKey:@"requestMainDocumentURL"];
        }
        return [dict copy];
    }
}

- (instancetype)init {
    if (self = [super init]) {
        _receivedMessages = [[NSMutableArray alloc] init];
        _messageQueue = dispatch_queue_create("ch.xxtou.queue.monkey.messaging", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSArray <NSDictionary *> *)receivedMessages {
    @autoreleasepool {
        __block NSArray <NSDictionary *> *messages = nil;
        dispatch_sync(_messageQueue, ^{
            messages = [_receivedMessages copy];
        });
        return messages;
    }
}

- (void)removeAllReceivedMessages {
    dispatch_sync(_messageQueue, ^{
        [_receivedMessages removeAllObjects];
    });
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
    static NSDateFormatter *isoDateFormatter = nil;
    static NSFileHandle *proxyLogHandle = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        
        isoDateFormatter = [[NSDateFormatter alloc] init];
        isoDateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        isoDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'+00:00'";
        isoDateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

        NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        NSString *logPath = [cachesDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.log", kLuaBridgeInstanceName]];
        [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
        
        proxyLogHandle = [[NSFileHandle fileHandleForWritingAtPath:logPath] copy];
        
#if DEBUG
        NSLog(@"[%@][Client #2] message log file handle %@ created at %@", kLuaBridgeInstanceName, proxyLogHandle, logPath);
#endif
    });

    if (proxyLogHandle) {
        
        dispatch_sync(_messageQueue, ^{
            @autoreleasepool {
                NSFileHandle *handle = proxyLogHandle;
                id object = [TMScriptMessageProxy preprocessScriptMessage:message];
                if (object) {
                    // Allowed types are NSNumber, NSString, NSDate, NSArray, NSDictionary, and NSNull.
                    [_receivedMessages addObject:@{
                        @"frameInfo": [TMScriptMessageProxy dictionaryRepresentationOfFrameInfo:message.frameInfo],
                        @"name": message.name,
                        @"body": object,
                    }];
                }

                NSData *logData = nil;
                if ([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSDictionary class]]) {
                    NSError *jsonErr = nil;
                    logData = [NSJSONSerialization dataWithJSONObject:object options:(NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted) error:&jsonErr];
                } else {  // NSString, NSNumber, NSDate or NSNull
                    logData = [[NSString stringWithFormat:@"%@", object] dataUsingEncoding:NSUTF8StringEncoding];
                }

                if (logData) {
                    [handle seekToEndOfFile];
                    NSString *tagString = [NSString stringWithFormat:@"[%@] ", [isoDateFormatter stringFromDate:[NSDate date]]];
                    [handle writeData:[tagString dataUsingEncoding:NSUTF8StringEncoding]];
                    [handle writeData:logData];
                    [handle writeData:[NSData dataWithBytes:"\r\n" length:2]];
                }

#if DEBUG
                NSLog(@"[%@][Client #2] message received %@ from %@ has been written to %@", kLuaBridgeInstanceName, message, userContentController, handle);
#endif
            }
        });
        
    }
}

+ (id)preprocessScriptMessage:(WKScriptMessage *)message {
    @autoreleasepool {
        id messageBody = message.body;
        if (![messageBody isKindOfClass:[NSDictionary class]]) {
            
#if DEBUG
        NSLog(@"[%@][Client #2] message %@ parsed body %@", kLuaBridgeInstanceName, message, messageBody);
#endif
            return messageBody;
        }

        NSDictionary *messageBodyDict = (NSDictionary *)messageBody;
        if (![messageBodyDict[@"name"] isKindOfClass:[NSString class]] || ![messageBodyDict[@"stack"] isKindOfClass:[NSString class]]) {
            
#if DEBUG
        NSLog(@"[%@][Client #2] message %@ parsed body %@", kLuaBridgeInstanceName, message, messageBody);
#endif
            return messageBody;
        }
        
#if DEBUG
        NSString *messageName = (NSString *)messageBodyDict[@"name"];
        NSLog(@"[%@][Client #2] message %@ parsed name %@ body %@", kLuaBridgeInstanceName, message, messageName, messageBody);
#endif
        return messageBody;
    }
}

- (void)dealloc {
#if DEBUG
    NSLog(@"[%@][Client #2] <%@ dealloc>", kLuaBridgeInstanceName, NSStringFromClass([self class]));
#endif
}

@end
