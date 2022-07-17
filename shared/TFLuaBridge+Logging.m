//
//  TFLuaBridge+Logging.m
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TFLuaBridge.h"
#import <pthread.h>

#if DEBUG
#import <mach/task.h>
#import <mach/mach.h>
#endif

OBJC_EXTERN NSString *kLuaBridgeInstanceName;

@implementation TFLuaBridge (Logging)

+ (dispatch_queue_t)sharedLoggingQueue {
    static dispatch_queue_t _sharedLoggingQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *queueName = [NSString stringWithFormat:@"%@.queue.logging", kLuaBridgeInstanceName];
        _sharedLoggingQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
    });
    return _sharedLoggingQueue;
}

+ (NSDateFormatter *)sharedLoggingDateFormatter {
    static NSDateFormatter *_sharedLoggingDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedLoggingDateFormatter = [[NSDateFormatter alloc] init];
        _sharedLoggingDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        _sharedLoggingDateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _sharedLoggingDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    });
    return _sharedLoggingDateFormatter;
}

+ (NSFileHandle *)sharedLoggingHandle {
    static NSFileHandle *_sharedLoggingHandle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        NSString *logPath = [cachesDirectory stringByAppendingPathComponent:kLuaBridgeInstanceName];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:logPath
                                  withIntermediateDirectories:YES
                                                   attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }
                                                        error:nil];
        
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        
        logPath = [[logPath stringByAppendingPathComponent:bundleIdentifier] stringByAppendingPathExtension:@"log"];
        
        [[NSFileManager defaultManager] createFileAtPath:logPath
                                                contents:[NSData data]
                                              attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }];
        
        _sharedLoggingHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];

        CHDebugLog(@"[%@] logging handle %@ located at %@", kLuaBridgeInstanceName, _sharedLoggingHandle, logPath);
    });
    return _sharedLoggingHandle;
}

- (void)logObject:(id)object {
    if ([object isKindOfClass:[NSString class]] ||
        [object isKindOfClass:[NSArray class]] ||
        [object isKindOfClass:[NSDictionary class]] ||
        [object isKindOfClass:[NSData class]]) {

        dispatch_async([TFLuaBridge sharedLoggingQueue], ^{
            @autoreleasepool {
                if ([TFLuaBridge sharedLoggingHandle]) {
                    NSData *logData = nil;
                    if ([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSDictionary class]]) {
                        NSError *jsonErr = nil;
                        logData = [NSJSONSerialization dataWithJSONObject:object options:(NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted) error:&jsonErr];
                    } else if ([object isKindOfClass:[NSString class]]) {
                        logData = [(NSString *)object dataUsingEncoding:NSUTF8StringEncoding];
                    } else {
                        logData = (NSData *)object;
                    }

                    if (logData) {
                        [[TFLuaBridge sharedLoggingHandle] seekToEndOfFile];
                        NSString *tagString = [NSString stringWithFormat:@"[%@] ", [[TFLuaBridge sharedLoggingDateFormatter] stringFromDate:[NSDate date]]];
                        [[TFLuaBridge sharedLoggingHandle] writeData:[tagString dataUsingEncoding:NSUTF8StringEncoding]];
                        [[TFLuaBridge sharedLoggingHandle] writeData:logData];
                        [[TFLuaBridge sharedLoggingHandle] writeData:[NSData dataWithBytes:"\r\n" length:2]];
                    }
                }

                CHDebugLog(@"[%@][%@] %@", kLuaBridgeInstanceName, self.instanceRoleName, object);
            }
        });
    }
}

#if DEBUG
+ (unsigned long)__getMemoryUsedInBytes
{
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.resident_size;
    } else {
        return 0;
    }
}
#endif

@end
