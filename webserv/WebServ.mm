/**
 * This is a compatibility layer of the legacy XXTouch OpenAPI.
 * Which also supports TouchSprite OpenAPI and TouchElf OpenAPI.
 */

#import <sys/stat.h>
#import <UIKit/UIKit.h>
#import <MobileGestalt/MobileGestalt.h>

#ifdef  __cplusplus
extern "C" {
#endif

#import "GCDAsyncUdpSocket.h"
#import "PSWebSocketServer.h"

#import "kern_memorystatus.h"

#ifdef  __cplusplus
}
#endif

#import "WebServ.h"
#import "ProcQueue.h"
#import "Supervisor.h"
#import "DeviceConfigurator.h"
#import "TFContainerManager.h"
#import "NSTask.h"
#import "TFShell.h"
#import "ScreenCapture.h"
#import "ScreenCaptureOpenCVWrapper.h"


BOOL _remoteAccessEnabled = NO;
dispatch_queue_t _serviceQueue = nil;
NSFileManager *_serviceFileManager = nil;


#pragma mark -

@interface ELFCloudClient : NSObject <PSWebSocketDelegate>
+ (nonnull GCDWebServerResponse *)responseByHandleMessageWithType:(NSString *)msgType body:(nullable id)msgBody;
@end


#pragma mark -

NS_INLINE NSString *file_type_from_st_mode(mode_t mode)
{
    if (S_ISREG(mode)) {
        return @"file";
    }
    else if (S_ISDIR(mode)) {
        return @"directory";
    }
    else if (S_ISLNK(mode)) {
        return @"symlink";
    }
    else if (S_ISSOCK(mode)) {
        return @"socket";
    }
    else if (S_ISFIFO(mode)) {
        return @"fifo";
    }
    else if (S_ISBLK(mode)) {
        return @"block";
    }
    else if (S_ISCHR(mode)) {
        return @"char";
    }
    return @"unknown";
}

NS_INLINE NSString *file_permissions_from_st_mode(mode_t mode)
{
    NSMutableString *perm = [NSMutableString string];
    [perm appendString:(mode & S_IRUSR) ? @"r" : @"-"];
    [perm appendString:(mode & S_IWUSR) ? @"w" : @"-"];
    [perm appendString:(mode & S_IXUSR) ? @"x" : @"-"];
    [perm appendString:(mode & S_IRGRP) ? @"r" : @"-"];
    [perm appendString:(mode & S_IWGRP) ? @"w" : @"-"];
    [perm appendString:(mode & S_IXGRP) ? @"x" : @"-"];
    [perm appendString:(mode & S_IROTH) ? @"r" : @"-"];
    [perm appendString:(mode & S_IWOTH) ? @"w" : @"-"];
    [perm appendString:(mode & S_IXOTH) ? @"x" : @"-"];
    return perm;
}

static void register_file_manager_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/file_list", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *directoryName = request.jsonObject[@"directory"];
                if (![directoryName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"directory"));
                    return;
                }
                
                if (directoryName.length) {
                    directoryName = strip_unsafe_components(directoryName);
                    
                    if (!directoryName.length) {
                        completionBlock(resp_bad_request(@"directory"));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *directoryURL;
                if (directoryName.length)
                {
                    directoryURL = [NSURL fileURLWithPath:directoryName relativeToURL:rootURL];
                }
                else
                {
                    directoryURL = rootURL;
                }
                
                NSError *err = nil;
                NSArray <NSURL *> *childURLs = [_serviceFileManager contentsOfDirectoryAtURL:directoryURL includingPropertiesForKeys:nil options:(NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants) error:&err];
                
                if (!childURLs) {
                    completionBlock(resp_operation_failed(1, [err localizedDescription]));
                    return;
                }
                
                NSMutableArray <NSDictionary *> *childList = [NSMutableArray arrayWithCapacity:childURLs.count];
                struct stat childStat;
                for (NSURL *childURL in childURLs) {
                    if (lstat([[childURL path] UTF8String], &childStat))
                        continue;
                    NSString *fileType = file_type_from_st_mode(childStat.st_mode);
                    if (![fileType isEqualToString:@"file"] && ![fileType isEqualToString:@"directory"])
                        continue;
                    [childList addObject:@{
                        @"name": [childURL lastPathComponent],
                        @"change": @(childStat.st_ctimespec.tv_sec),
                        @"size": @(childStat.st_size),
                        @"access": @(childStat.st_atimespec.tv_sec),
                        @"gid": @(childStat.st_gid),
                        @"blksize": @(childStat.st_blksize),
                        @"uid": @(childStat.st_uid),
                        @"rdev": @(childStat.st_rdev),
                        @"blocks": @(childStat.st_blocks),
                        @"nlink": @(childStat.st_nlink),
                        @"permissions": file_permissions_from_st_mode(childStat.st_mode),
                        @"mode": fileType,
                        @"dev": @(childStat.st_dev),
                        @"ino": @(childStat.st_ino),
                        @"modification": @(childStat.st_mtimespec.tv_sec),
                    }];
                }
                
                completionBlock(resp_operation_succeed(@{ @"list": childList }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/select_script_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *scriptName = request.jsonObject[@"filename"];
                if (![scriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                if ([scriptName hasPrefix:@"/private/var/"])
                    scriptName = [scriptName substringFromIndex:8];
                if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                    scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                
                {
                    scriptName = strip_unsafe_components(scriptName);
                    
                    if (!scriptName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                    
                    NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                    if (![scriptExtension isEqualToString:@"lua"] &&
                        ![scriptExtension isEqualToString:@"luac"] &&
                        ![scriptExtension isEqualToString:@"xxt"])
                    {
                        completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    completionBlock(resp_operation_failed(4, [err localizedDescription]));
                    return;
                }
                
                [[ProcQueue sharedInstance] setObject:scriptName forKey:@"ch.xxtou.defaults.selected-script"];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/get_selected_script_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *scriptName = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.selected-script"];
                if (!scriptName) {
                    completionBlock(resp_operation_failed(1, @"No script selected"));
                    return;
                }
                
                completionBlock(resp_operation_succeed(@{ @"filename": scriptName }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/remove_script_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *scriptName = request.jsonObject[@"filename"];
                if (![scriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                {
                    scriptName = strip_unsafe_components(scriptName);
                    
                    if (!scriptName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                    
                    NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                    if (![scriptExtension isEqualToString:@"lua"] &&
                        ![scriptExtension isEqualToString:@"luac"] &&
                        ![scriptExtension isEqualToString:@"xxt"])
                    {
                        completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable) {
                    completionBlock(resp_operation_failed(4, [err localizedDescription]));
                    return;
                }
                
                BOOL deleted = [_serviceFileManager removeItemAtURL:scriptURL error:&err];
                if (!deleted) {
                    completionBlock(resp_operation_failed(4, [err localizedDescription]));
                    return;
                }
                
                [[ProcQueue sharedInstance] removeObjectForKey:@"ch.xxtou.defaults.selected-script"];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/new_script_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *scriptName = request.jsonObject[@"filename"];
                if (![scriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                NSString *scriptContent = request.jsonObject[@"data"];
                if (![scriptContent isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"data"));
                    return;
                }
                
                NSData *scriptData = [[NSData alloc] initWithBase64EncodedString:scriptContent options:NSDataBase64DecodingIgnoreUnknownCharacters];
                if (!scriptData) {
                    scriptData = [scriptContent dataUsingEncoding:NSUTF8StringEncoding];
                }
                if (!scriptData) {
                    completionBlock(resp_bad_request(@"data"));
                    return;
                }
                
                {
                    scriptName = strip_unsafe_components(scriptName);
                    
                    if (!scriptName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                    
                    NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                    if (![scriptExtension isEqualToString:@"lua"])
                    {
                        completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                BOOL exists = [_serviceFileManager fileExistsAtPath:scriptURL.path];
                if (exists) {
                    completionBlock(resp_operation_failed(11, @"File or directory exists"));
                    return;
                }
                
                BOOL created = [_serviceFileManager createFileAtPath:scriptURL.path
                                                            contents:scriptData
                                                          attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }];
                if (!created) {
                    completionBlock(resp_operation_failed(4, @"Failed to create script file"));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/write_script_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *scriptName = request.jsonObject[@"filename"];
                if (![scriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                NSString *scriptContent = request.jsonObject[@"data"];
                if (![scriptContent isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"data"));
                    return;
                }
                
                NSData *scriptData = [[NSData alloc] initWithBase64EncodedString:scriptContent options:NSDataBase64DecodingIgnoreUnknownCharacters];
                if (!scriptData) {
                    scriptData = [scriptContent dataUsingEncoding:NSUTF8StringEncoding];
                }
                if (!scriptData) {
                    completionBlock(resp_bad_request(@"data"));
                    return;
                }
                
                {
                    scriptName = strip_unsafe_components(scriptName);
                    
                    if (!scriptName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                    
                    NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                    if (![scriptExtension isEqualToString:@"lua"])
                    {
                        completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL exists = [_serviceFileManager fileExistsAtPath:scriptURL.path];
                if (exists) {
                    BOOL deleted = [_serviceFileManager removeItemAtPath:scriptURL.path error:&err];
                    if (!deleted) {
                        completionBlock(resp_operation_failed(4, [err localizedDescription]));
                        return;
                    }
                }
                
                BOOL created = [_serviceFileManager createFileAtPath:scriptURL.path
                                                            contents:scriptData
                                                          attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }];
                if (!created) {
                    completionBlock(resp_operation_failed(4, @"Failed to create script file"));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/mkdir", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *directoryName = request.jsonObject[@"directory"];
                if (![directoryName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"directory"));
                    return;
                }
                
                {
                    directoryName = strip_unsafe_components(directoryName);
                    
                    if (!directoryName.length) {
                        completionBlock(resp_bad_request(@"directory"));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *directoryURL = [NSURL fileURLWithPath:directoryName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL created = [_serviceFileManager createDirectoryAtURL:directoryURL
                                             withIntermediateDirectories:YES
                                                              attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }
                                                                   error:&err];
                if (!created) {
                    completionBlock(resp_operation_failed(1, [err localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/rmdir", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *directoryName = request.jsonObject[@"directory"];
                if (![directoryName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"directory"));
                    return;
                }
                
                {
                    directoryName = strip_unsafe_components(directoryName);
                    
                    if (!directoryName.length) {
                        completionBlock(resp_bad_request(@"directory"));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *directoryURL = [NSURL fileURLWithPath:directoryName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL deleted = [_serviceFileManager removeItemAtURL:directoryURL error:&err];
                if (!deleted) {
                    completionBlock(resp_operation_failed(1, [err localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/rename_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *fileName = request.jsonObject[@"filename"];
                if (![fileName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                {
                    fileName = strip_unsafe_components(fileName);
                    
                    if (!fileName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                }
                
                NSString *newFileName = request.jsonObject[@"newfilename"];
                if (![newFileName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"newfilename"));
                    return;
                }
                
                {
                    newFileName = strip_unsafe_components(newFileName);
                    
                    if (!newFileName.length) {
                        completionBlock(resp_bad_request(@"newfilename"));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *fileURL = [NSURL fileURLWithPath:fileName relativeToURL:rootURL];
                NSURL *newFileURL = [NSURL fileURLWithPath:newFileName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL moved = [_serviceFileManager moveItemAtURL:fileURL toURL:newFileURL error:&err];
                if (!moved) {
                    if (err.code == 516 || err.code == 11) {
                        completionBlock(resp_operation_failed(11, [err localizedDescription]));
                    } else if (err.code == 4) {
                        completionBlock(resp_operation_failed(4, [err localizedDescription]));
                    }
                    completionBlock(resp_operation_failed(1, [err localizedDescription]));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/read_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *fileName = request.jsonObject[@"filename"];
                if (![fileName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                {
                    fileName = strip_unsafe_components(fileName);
                    
                    if (!fileName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *fileURL = [NSURL fileURLWithPath:fileName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL reachable = [fileURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    completionBlock(resp_operation_failed(4, [err localizedDescription]));
                    return;
                }
                
                NSData *contents = [_serviceFileManager contentsAtPath:fileURL.path];
                if (!contents)
                {
                    completionBlock(resp_operation_failed(4, @"Failed read file"));
                    return;
                }
                
                completionBlock(resp_operation_succeed([contents base64EncodedStringWithOptions:kNilOptions]));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/write_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *fileName = request.jsonObject[@"filename"];
                if (![fileName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                NSString *fileContent = request.jsonObject[@"data"];
                if (![fileContent isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"data"));
                    return;
                }
                
                NSData *fileData = [[NSData alloc] initWithBase64EncodedString:fileContent options:NSDataBase64DecodingIgnoreUnknownCharacters];
                if (!fileData) {
                    fileData = [fileContent dataUsingEncoding:NSUTF8StringEncoding];
                }
                if (!fileData) {
                    completionBlock(resp_bad_request(@"data"));
                    return;
                }
                
                {
                    fileName = strip_unsafe_components(fileName);
                    
                    if (!fileName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *fileURL = [NSURL fileURLWithPath:fileName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL exists = [_serviceFileManager fileExistsAtPath:fileURL.path];
                if (exists) {
                    BOOL deleted = [_serviceFileManager removeItemAtPath:fileURL.path error:&err];
                    if (!deleted) {
                        completionBlock(resp_operation_failed(4, [err localizedDescription]));
                        return;
                    }
                }
                
                BOOL created = [_serviceFileManager createFileAtPath:fileURL.path
                                                            contents:fileData
                                                          attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                if (!created) {
                    completionBlock(resp_operation_failed(4, @"Failed to create file"));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET"], @"/download_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *fileName = request.query[@"filename"];
                if (![fileName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                NSURL *fileURL = nil;
                if (![fileName isAbsolutePath])
                {
                    fileName = strip_unsafe_components(fileName);
                    
                    if (!fileName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                    
                    NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                    fileURL = [NSURL fileURLWithPath:fileName relativeToURL:rootURL];
                }
                else
                {
                    fileURL = [NSURL fileURLWithPath:fileName];
                }
                
                NSError *err = nil;
                BOOL reachable = [fileURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    completionBlock(resp_operation_failed_400(4, [err localizedDescription]));
                    return;
                }
                
                NSString *fileType = nil;
                BOOL got = [fileURL getResourceValue:&fileType forKey:NSURLFileResourceTypeKey error:&err];
                if (!got || ![fileType isEqualToString:NSURLFileResourceTypeRegular])
                {
                    completionBlock(resp_operation_failed_400(4, [err localizedDescription]));
                    return;
                }
                
                completionBlock([GCDWebServerFileResponse responseWithFile:fileURL.path byteRange:request.byteRange isAttachment:YES]);
            }
        });
    });
}

static void register_device_configurator_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/device_front_orien", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                UIInterfaceOrientation orient = (UIInterfaceOrientation)[[DeviceConfigurator sharedConfigurator] frontMostAppOrientation];
                switch (orient) {
                    case UIInterfaceOrientationUnknown:
                        orient = (UIInterfaceOrientation)4;
                        break;
                    case UIInterfaceOrientationPortrait:
                        orient = (UIInterfaceOrientation)0;
                        break;
                    case UIInterfaceOrientationPortraitUpsideDown:
                        orient = (UIInterfaceOrientation)3;
                        break;
                    case UIInterfaceOrientationLandscapeLeft:
                        orient = (UIInterfaceOrientation)1;
                        break;
                    case UIInterfaceOrientationLandscapeRight:
                        orient = (UIInterfaceOrientation)2;
                        break;
                }
                completionBlock(resp_operation_succeed(@{ @"orien": @(orient) }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_device_name", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *deviceName = request.jsonObject[@"name"];
                if (![deviceName isKindOfClass:[NSString class]] || !deviceName.length) {
                    completionBlock(resp_bad_request(@"name"));
                    return;
                }
                
                int mgRet = MGSetAnswer(kMGUserAssignedDeviceName, (__bridge CFStringRef)deviceName);
                if (!mgRet) {
                    completionBlock(resp_operation_failed(1, nil));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_brightness", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSNumber *brightnessLevel = request.jsonObject[@"level"];
                if (![brightnessLevel isKindOfClass:[NSNumber class]]) {
                    completionBlock(resp_bad_request(@"level"));
                    return;
                }
                
                [[DeviceConfigurator sharedConfigurator] setBacklightLevel:MIN(MAX([brightnessLevel doubleValue], 0.0), 1.0)];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_volume", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSNumber *volumeLevel = request.jsonObject[@"level"];
                if (![volumeLevel isKindOfClass:[NSNumber class]]) {
                    completionBlock(resp_bad_request(@"level"));
                    return;
                }
                
                [[DeviceConfigurator sharedConfigurator] setCurrentVolume:MIN(MAX([volumeLevel doubleValue], 0.0), 1.0)];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/lock_screen", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                [[DeviceConfigurator sharedConfigurator] lockScreen];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/unlock_screen", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *passcode = request.jsonObject[@"password"];
                if (passcode != nil && ![passcode isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"password"));
                    return;
                }
                
                [[DeviceConfigurator sharedConfigurator] unlockScreenWithPasscode:passcode ?: @""];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/uicache", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                int code = ios_system("uicache");
                if (code) {
                    completionBlock(resp_operation_failed(1, nil));
                    return;
                }
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/respring", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                int code = ios_system("killall -9 SpringBoard backboardd");
                if (code) {
                    completionBlock(resp_operation_failed(1, nil));
                    return;
                }
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/reboot2", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                int code = ios_system("reboot");
                if (code) {
                    completionBlock(resp_operation_failed(1, nil));
                    return;
                }
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/halt", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                int code = ios_system("halt");
                if (code) {
                    completionBlock(resp_operation_failed(1, nil));
                    return;
                }
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/ldrestart", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                int code = ios_system("ldrestart");
                if (code) {
                    completionBlock(resp_operation_failed(1, nil));
                    return;
                }
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/update_deb", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                if (!request.data || !request.data.length)
                {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                if (strncmp((const char *)[request.data bytes], "!<arch>\n", 8))
                {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSError *err = nil;
                NSURL *tmpURL = [_serviceFileManager URLForDirectory:NSItemReplacementDirectory
                                                            inDomain:NSUserDomainMask
                                                   appropriateForURL:[NSURL fileURLWithPath:@"/private/var"]
                                                              create:YES
                                                               error:&err];
                if (!tmpURL) {
                    completionBlock(resp_operation_failed(1, [err localizedDescription]));
                    return;
                }
                
                tmpURL = [tmpURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.deb", [[NSUUID UUID] UUIDString]]];
                
                BOOL wrote = [request.data writeToFile:tmpURL.path options:NSDataWritingAtomic error:&err];
                if (!wrote) {
                    completionBlock(resp_operation_failed(1, [err localizedDescription]));
                    return;
                }
                
                int code = ios_system([[NSString stringWithFormat:@"nohup dpkg -i \"%@\" &", TFEscapeShellArg(tmpURL.path)] UTF8String]);
                if (code) {
                    completionBlock(resp_operation_failed(1, [NSString stringWithFormat:@"Program exited with code %d", code]));
                    return;
                }
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/deviceinfo", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSArray <NSString *> *localPeer = [request.localAddressString componentsSeparatedByString:@":"];
                NSString *localAddress = [localPeer firstObject];
                NSNumber *localPort = @([[localPeer lastObject] integerValue]);
                
                CFPropertyListRef plistObj = MGCopyMultipleAnswers((__bridge CFArrayRef)@[
                    (__bridge NSString *)kMGSerialNumber,
                    (__bridge NSString *)kMGProductType,
                    (__bridge NSString *)kMGProductVersion,
                    (__bridge NSString *)kMGHWModel,
                    (__bridge NSString *)kMGWifiAddress,
                    (__bridge NSString *)kMGUniqueDeviceID,
                    (__bridge NSString *)kMGUserAssignedDeviceName,
                ], nil);
                
                static NSDictionary <NSString *, NSString *> *keyMappings = @{
                    (__bridge NSString *)kMGSerialNumber: @"devsn",
                    (__bridge NSString *)kMGProductType: @"devtype",
                    (__bridge NSString *)kMGProductVersion: @"sysversion",
                    (__bridge NSString *)kMGHWModel: @"hwmodel",
                    (__bridge NSString *)kMGWifiAddress: @"devmac",
                    (__bridge NSString *)kMGUniqueDeviceID: @"deviceid",
                    (__bridge NSString *)kMGUserAssignedDeviceName: @"devname",
                };
                
                NSDictionary *oldDict = (__bridge NSDictionary *)plistObj;
                NSMutableDictionary <NSString *, id> *plistDict = [NSMutableDictionary dictionaryWithCapacity:oldDict.count];
                
                for (NSString *plistKey in oldDict) {
                    NSString *newPlistKey = [keyMappings objectForKey:plistKey];
                    if (!newPlistKey)
                        continue;
                    plistDict[newPlistKey] = oldDict[plistKey];
                }
                
                CFRelease(plistObj);
                
                if (localAddress)
                    plistDict[@"ipaddr"] = localAddress;
                
                if (localPort)
                    plistDict[@"port"] = localPort;
                
                plistDict[@"zeversion"] = @XXT_VERSION;
                
                NSString *primaryAddress = GCDWebServerGetPrimaryIPAddress(NO);
                if (primaryAddress)
                    plistDict[@"wifi_ip"] = primaryAddress;
                
                if (webServer.serverURL)
                    plistDict[@"webserver_url"] = [webServer.serverURL absoluteString];
                
                if (webServer.bonjourServerURL)
                    plistDict[@"bonjour_webserver_url"] = [webServer.bonjourServerURL absoluteString];
                
                completionBlock(resp_operation_succeed(plistDict));
            }
        });
    });
}

static void register_container_manager_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/applist", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                BOOL withoutIcon = NO;
                if (request.jsonObject) {
                    NSNumber *noIcon = request.jsonObject[@"no_icon"];
                    if (![noIcon isKindOfClass:[NSNumber class]]) {
                        completionBlock(resp_bad_request(@"no_icon"));
                        return;
                    }
                    withoutIcon = [noIcon boolValue];
                }
                
                TFContainerManagerFetchOptions opts = TFContainerManagerFetchWithSystemApplications;
                if (!withoutIcon) {
                    opts |= TFContainerManagerFetchWithIconData;
                }
                
                NSError *err = nil;
                NSArray <TFAppItem *> *appItems = [[TFContainerManager sharedManager] appItemsWithOptions:opts error:&err];
                if (!appItems) {
                    completionBlock(resp_operation_failed(1, [err localizedDescription]));
                    return;
                }
                
                NSMutableArray <NSDictionary *> *appList = [NSMutableArray arrayWithCapacity:appItems.count];
                for (TFAppItem *appItem in appItems) {
                    [appList addObject:[appItem toDictionaryWithIconData:!withoutIcon entitlements:NO legacy:YES]];
                }
                
                completionBlock(resp_operation_succeed(appList));
            }
        });
    });
}

static void register_screen_capture_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/image_to_album", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                if (!request.data || !request.data.length) {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSDictionary *replyObject = [[ScreenCapture sharedCapture] performSavePhotoToAlbumRequestWithData:request.data timeout:10.0];
                if (![replyObject[@"succeed"] boolValue]) {
                    completionBlock(resp_operation_failed(1, nil));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET"], @"/snapshot", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                completionBlock([ELFCloudClient responseByHandleMessageWithType:@"screen/snapshot" body:request.query]);
            }
        });
    });
}

static void register_proc_queue_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/proc_put", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *procKey = request.jsonObject[@"key"];
                if (![procKey isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"key"));
                    return;
                }
                
                NSString *procVal = request.jsonObject[@"value"];
                if (![procVal isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"value"));
                    return;
                }
                
                NSString *oldVal = [[ProcQueue sharedInstance] procPutObject:procVal forKey:procKey];
                completionBlock(resp_operation_succeed_flat(@{ @"key": procKey, @"value": procVal, @"old_value": oldVal }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/proc_get", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *procKey = request.jsonObject[@"key"];
                if (![procKey isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"key"));
                    return;
                }
                
                NSString *procVal = [[ProcQueue sharedInstance] procObjectForKey:procKey];
                completionBlock(resp_operation_succeed_flat(@{ @"key": procKey, @"value": procVal }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/proc_queue_push", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *procKey = request.jsonObject[@"key"];
                if (![procKey isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"key"));
                    return;
                }
                
                NSString *procVal = request.jsonObject[@"value"];
                if (![procVal isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"value"));
                    return;
                }
                
                NSUInteger queueSize = [[ProcQueue sharedInstance] procQueuePushTailObject:procVal forKey:procKey];
                completionBlock(resp_operation_succeed_flat(@{ @"key": procKey, @"value": procVal, @"size": @(queueSize) }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/proc_queue_pop", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *procKey = request.jsonObject[@"key"];
                if (![procKey isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"key"));
                    return;
                }
                
                // HINT: soze actually made an error: "pop" is always at the tail of a queue,
                //       we should use "shift" to describe this behavior.
                NSString *procVal = [[ProcQueue sharedInstance] procQueueShiftObjectForKey:procKey];
                completionBlock(resp_operation_succeed_flat(@{ @"key": procKey, @"value": procVal }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/proc_queue_clear", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *procKey = request.jsonObject[@"key"];
                if (![procKey isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"key"));
                    return;
                }
                
                NSArray <NSString *> *procVals = [[ProcQueue sharedInstance] procQueueClearObjectsForKey:procKey];
                completionBlock(resp_operation_succeed_flat(@{ @"key": procKey, @"values": procVals }));
            }
        });
    });
}

static void register_user_defaults_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/get_record_conf", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSDictionary <NSString *, id> *recordConf = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.recording"];
                completionBlock(resp_operation_succeed(@{
                    @"record_volume_up": recordConf[@"record_volume_up"] ?: @(NO),
                    @"record_volume_down": recordConf[@"record_volume_down"] ?: @(NO),
                }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_record_volume_up_on", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSMutableDictionary <NSString *, id> *recordConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.recording"] mutableCopy];
                if (!recordConf) {
                    recordConf = [NSMutableDictionary dictionaryWithCapacity:2];
                }
                recordConf[@"record_volume_up"] = @(YES);
                [[ProcQueue sharedInstance] setObject:recordConf forKey:@"ch.xxtou.defaults.recording"];
                completionBlock(resp_operation_succeed(recordConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_record_volume_up_off", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSMutableDictionary <NSString *, id> *recordConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.recording"] mutableCopy];
                if (!recordConf) {
                    recordConf = [NSMutableDictionary dictionaryWithCapacity:2];
                }
                recordConf[@"record_volume_up"] = @(NO);
                [[ProcQueue sharedInstance] setObject:recordConf forKey:@"ch.xxtou.defaults.recording"];
                completionBlock(resp_operation_succeed(recordConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_record_volume_down_on", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSMutableDictionary <NSString *, id> *recordConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.recording"] mutableCopy];
                if (!recordConf) {
                    recordConf = [NSMutableDictionary dictionaryWithCapacity:2];
                }
                recordConf[@"record_volume_down"] = @(YES);
                [[ProcQueue sharedInstance] setObject:recordConf forKey:@"ch.xxtou.defaults.recording"];
                completionBlock(resp_operation_succeed(recordConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_record_volume_down_off", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSMutableDictionary <NSString *, id> *recordConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.recording"] mutableCopy];
                if (!recordConf) {
                    recordConf = [NSMutableDictionary dictionaryWithCapacity:2];
                }
                recordConf[@"record_volume_down"] = @(NO);
                [[ProcQueue sharedInstance] setObject:recordConf forKey:@"ch.xxtou.defaults.recording"];
                completionBlock(resp_operation_succeed(recordConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/get_volume_action_conf", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSDictionary <NSString *, id> *actionConf = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.action"];
                completionBlock(resp_operation_succeed(@{
                    @"hold_volume_up": actionConf[@"hold_volume_up"] ?: @"0",
                    @"hold_volume_down": actionConf[@"hold_volume_down"] ?: @"0",
                    @"click_volume_up": actionConf[@"click_volume_up"] ?: @"0",
                    @"click_volume_down": actionConf[@"click_volume_down"] ?: @"0",
                    @"activator_installed": @(NO),  // sadly, libactivator is archived
                }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_hold_volume_up_action", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *dataValue = request.jsonObject[@"action"];
                if (!dataValue) {
                    dataValue = [[NSString alloc] initWithData:request.data encoding:NSUTF8StringEncoding];
                }
                if (!dataValue) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                int dataOption = [dataValue intValue];
                if (dataOption < 0 || dataOption > 2) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                NSMutableDictionary <NSString *, id> *actionConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.action"] mutableCopy];
                if (!actionConf) {
                    actionConf = [NSMutableDictionary dictionaryWithCapacity:4];
                }
                actionConf[@"hold_volume_up"] = [NSString stringWithFormat:@"%d", dataOption];
                [[ProcQueue sharedInstance] setObject:actionConf forKey:@"ch.xxtou.defaults.action"];
                completionBlock(resp_operation_succeed(actionConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_hold_volume_down_action", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *dataValue = request.jsonObject[@"action"];
                if (!dataValue) {
                    dataValue = [[NSString alloc] initWithData:request.data encoding:NSUTF8StringEncoding];
                }
                if (!dataValue) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                int dataOption = [dataValue intValue];
                if (dataOption < 0 || dataOption > 2) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                NSMutableDictionary <NSString *, id> *actionConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.action"] mutableCopy];
                if (!actionConf) {
                    actionConf = [NSMutableDictionary dictionaryWithCapacity:4];
                }
                actionConf[@"hold_volume_down"] = [NSString stringWithFormat:@"%d", dataOption];
                [[ProcQueue sharedInstance] setObject:actionConf forKey:@"ch.xxtou.defaults.action"];
                completionBlock(resp_operation_succeed(actionConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_click_volume_up_action", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *dataValue = request.jsonObject[@"action"];
                if (!dataValue) {
                    dataValue = [[NSString alloc] initWithData:request.data encoding:NSUTF8StringEncoding];
                }
                if (!dataValue) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                int dataOption = [dataValue intValue];
                if (dataOption < 0 || dataOption > 2) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                NSMutableDictionary <NSString *, id> *actionConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.action"] mutableCopy];
                if (!actionConf) {
                    actionConf = [NSMutableDictionary dictionaryWithCapacity:4];
                }
                actionConf[@"click_volume_up"] = [NSString stringWithFormat:@"%d", dataOption];
                [[ProcQueue sharedInstance] setObject:actionConf forKey:@"ch.xxtou.defaults.action"];
                completionBlock(resp_operation_succeed(actionConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_click_volume_down_action", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *dataValue = request.jsonObject[@"action"];
                if (!dataValue) {
                    dataValue = [[NSString alloc] initWithData:request.data encoding:NSUTF8StringEncoding];
                }
                if (!dataValue) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                int dataOption = [dataValue intValue];
                if (dataOption < 0 || dataOption > 2) {
                    completionBlock(resp_bad_request(@"action"));
                    return;
                }
                
                NSMutableDictionary <NSString *, id> *actionConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.action"] mutableCopy];
                if (!actionConf) {
                    actionConf = [NSMutableDictionary dictionaryWithCapacity:4];
                }
                actionConf[@"click_volume_down"] = [NSString stringWithFormat:@"%d", dataOption];
                [[ProcQueue sharedInstance] setObject:actionConf forKey:@"ch.xxtou.defaults.action"];
                completionBlock(resp_operation_succeed(actionConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/get_startup_conf", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSDictionary <NSString *, id> *startupConf = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.startup"];
                completionBlock(resp_operation_succeed(@{
                    @"startup_run": startupConf[@"startup_run"] ?: @(NO),
                    @"startup_script": startupConf[@"startup_script"] ?: @"bootstrap.lua",
                }));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_startup_run_on", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSMutableDictionary <NSString *, id> *startupConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.startup"] mutableCopy];
                if (!startupConf) {
                    startupConf = [NSMutableDictionary dictionaryWithCapacity:2];
                }
                startupConf[@"startup_run"] = @(YES);
                [[ProcQueue sharedInstance] setObject:startupConf forKey:@"ch.xxtou.defaults.startup"];
                completionBlock(resp_operation_succeed(startupConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_startup_run_off", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSMutableDictionary <NSString *, id> *startupConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.startup"] mutableCopy];
                if (!startupConf) {
                    startupConf = [NSMutableDictionary dictionaryWithCapacity:2];
                }
                startupConf[@"startup_run"] = @(NO);
                [[ProcQueue sharedInstance] setObject:startupConf forKey:@"ch.xxtou.defaults.startup"];
                completionBlock(resp_operation_succeed(startupConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/select_startup_script_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *scriptName = request.jsonObject[@"filename"];
                if (![scriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                if ([scriptName hasPrefix:@"/private/var/"])
                    scriptName = [scriptName substringFromIndex:8];
                if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                    scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                
                {
                    scriptName = strip_unsafe_components(scriptName);
                    
                    if (!scriptName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                    
                    NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                    if (![scriptExtension isEqualToString:@"lua"] && ![scriptExtension isEqualToString:@"luac"] && ![scriptExtension isEqualToString:@"xxt"])
                    {
                        completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    completionBlock(resp_operation_failed(4, [err localizedDescription]));
                    return;
                }
                
                NSMutableDictionary <NSString *, id> *startupConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.startup"] mutableCopy];
                if (!startupConf) {
                    startupConf = [NSMutableDictionary dictionaryWithCapacity:2];
                }
                startupConf[@"startup_script"] = scriptName;
                [[ProcQueue sharedInstance] setObject:startupConf forKey:@"ch.xxtou.defaults.startup"];
                completionBlock(resp_operation_succeed(startupConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/get_user_conf", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSMutableDictionary <NSString *, id> *userConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.user"] mutableCopy];
                if (!userConf) {
                    userConf = [NSMutableDictionary dictionaryWithCapacity:6];
                }
                if (![userConf[@"device_control_toggle"] isKindOfClass:[NSNumber class]])
                    userConf[@"device_control_toggle"] = @(YES);
                if (![userConf[@"no_nosim_alert"] isKindOfClass:[NSNumber class]])
                    userConf[@"no_nosim_alert"] = @(YES);
                if (![userConf[@"no_low_power_alert"] isKindOfClass:[NSNumber class]])
                    userConf[@"no_low_power_alert"] = @(YES);
                if (![userConf[@"no_idle"] isKindOfClass:[NSNumber class]])
                    userConf[@"no_idle"] = @(NO);
                if (![userConf[@"script_on_daemon"] isKindOfClass:[NSNumber class]])
                    userConf[@"script_on_daemon"] = @(NO);
                if (![userConf[@"script_end_hint"] isKindOfClass:[NSNumber class]])
                    userConf[@"script_end_hint"] = @(YES);
                completionBlock(resp_operation_succeed(userConf));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_user_conf", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSDictionary *jsonDict = request.jsonObject;
                if (![jsonDict isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                NSMutableDictionary <NSString *, id> *userConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.user"] mutableCopy];
                if (!userConf) {
                    userConf = [NSMutableDictionary dictionaryWithCapacity:5];
                }
                [userConf addEntriesFromDictionary:jsonDict];
                [[ProcQueue sharedInstance] setObject:userConf forKey:@"ch.xxtou.defaults.user"];
                completionBlock(resp_operation_succeed(userConf));
            }
        });
    });
}

static NSString * const kDWDefaultsDomainString = @"ch.xxtou.DebugWindow";
static NSString * const kDWDefaultsNotificationName = @"ch.xxtou.notification.debugwindow.defaults-changed";

static void register_debug_window_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/set_debug_window_on", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                [[DeviceConfigurator sharedConfigurator] setObject:@(YES) forKey:@"enabled" inDomain:kDWDefaultsDomainString];
                [[DeviceConfigurator sharedConfigurator] darwinNotifyPost:kDWDefaultsNotificationName];
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_debug_window_off", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                [[DeviceConfigurator sharedConfigurator] setObject:@(NO) forKey:@"enabled" inDomain:kDWDefaultsDomainString];
                [[DeviceConfigurator sharedConfigurator] darwinNotifyPost:kDWDefaultsNotificationName];
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/set_debug_window_color", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *hexColor = request.jsonObject[@"color"];
                if (![hexColor isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"color"));
                    return;
                }
                
                [[DeviceConfigurator sharedConfigurator] setObject:hexColor forKey:@"backgroundColor" inDomain:kDWDefaultsDomainString];
                [[DeviceConfigurator sharedConfigurator] darwinNotifyPost:kDWDefaultsNotificationName];
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
}

OBJC_EXTERN void register_alert_helper_handlers(GCDWebServer *webServer);
OBJC_EXTERN void register_tamper_monkey_handlers(GCDWebServer *webServer);

static void register_command_spawn_handler(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/command_spawn", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                time_t cTimeout = -1;
                NSString *timeout = request.query[@"timeout"];
                if (timeout.length) {
                    cTimeout = (long)[timeout integerValue];
                }
                
                NSString *commandText = request.text;
                if (![commandText isKindOfClass:[NSString class]] || !commandText.length)
                {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSTask *task = [[NSTask alloc] init];
                
                NSMutableData *stdoutData = [NSMutableData data];
                NSMutableData *stderrData = [NSMutableData data];
                
                [task setCurrentDirectoryPath:@MEDIA_ROOT];
                [task setLaunchPath:@"/bin/sh"];
                [task setArguments:[NSArray arrayWithObjects:@"-c", commandText, nil]];
                [task setEnvironment:[Supervisor sharedTaskEnvironment]];
                
                [task setStandardInput:[NSPipe pipe]];
                
                NSPipe *opipe = [NSPipe pipe];
                [task setStandardOutput:opipe];
                
                [[opipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
                    NSData *dataReceived = [file availableData];  // this will read to EOF, so call only once
                    
                    // if you're collecting the whole output of a task, you may store it on a property
                    [stdoutData appendData:dataReceived];
                }];
                
                NSPipe *erroPipe = [NSPipe pipe];
                [task setStandardError:erroPipe];
                
                [[erroPipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
                    NSData *dataReceived = [file availableData];  // this will read to EOF, so call only once
                    
                    // if you're collecting the whole output of a task, you may store it on a property
                    [stderrData appendData:dataReceived];
                }];
                
                [task setTerminationHandler:^(NSTask *task) {
                    // do your stuff on completion
                    [opipe fileHandleForReading].readabilityHandler = nil;
                    [erroPipe fileHandleForReading].readabilityHandler = nil;
                }];
                
                [task launch];
                [task waitUntilExit];
                
                int status = [task terminationStatus];
                
                NSString *stdoutString = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding];
                NSString *stderrString = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
                
                completionBlock(resp_operation_succeed_flat(@{
                    @"status": @(status),
                    @"stdout": stdoutString ?: [[NSString alloc] init],
                    @"stderr": stderrString ?: [[NSString alloc] init],
                }));
            }
        });
    });
}

static void register_restart_handler(GCDWebServer *webServer)
{
    static NSArray <NSString *> *availableServiceNames = @[
        @SERVICE_APP,
        @SERVICE_TOUCH,
        @SERVICE_SPRINGBOARD,
        @SERVICE_SUPERVISOR,
        @SERVICE_PROC,
        @SERVICE_WEBSERV,
    ];
    
    register_path_handler_async(webServer, @[@"POST"], @"/restart", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                for (NSString *serviceName in availableServiceNames) {
                    if ([serviceName isEqualToString:@SERVICE_WEBSERV]) {
                        break;
                    }
                    
                    pid_t processIdentifier = TFProcessIDOfApplicationXPC(serviceName, YES);
                    if (processIdentifier == 0) {
                        continue;
                    }
                    
                    CHLog(@"Job %@ pid %d stopped", serviceName, processIdentifier);
                    sleep(1);
                    if (kill(processIdentifier, 0) == 0) {
                        sleep(3);
                        int killed = kill(processIdentifier, SIGKILL);
                        if (killed == 0) {
                            CHLog(@"Job %@ pid %d killed after 3 seconds", serviceName, processIdentifier);
                        }
                    }
                }
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    kill(0, SIGTERM);
                });
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    kill(0, SIGKILL);
                    exit(EXIT_SUCCESS);
                });
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
}

static void register_supervisor_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/launch_script_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                
                NSString *scriptName = request.jsonObject[@"filename"];
                if (scriptName != nil && ![scriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"filename"));
                    return;
                }
                
                NSURL *scriptURL = nil;
                if (scriptName.length) {
                    if ([scriptName hasPrefix:@"/private/var/"])
                        scriptName = [scriptName substringFromIndex:8];
                    if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                        scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                    
                    {
                        scriptName = strip_unsafe_components(scriptName);
                        
                        if (!scriptName.length) {
                            completionBlock(resp_bad_request(@"filename"));
                            return;
                        }
                        
                        NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                        if (![scriptExtension isEqualToString:@"lua"] &&
                            ![scriptExtension isEqualToString:@"luac"] &&
                            ![scriptExtension isEqualToString:@"xxt"])
                        {
                            completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                            return;
                        }
                    }
                    
                    NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                    scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                }
                
                if (scriptURL) {
                    NSError *err = nil;
                    BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                    if (!reachable)
                    {
                        completionBlock(resp_operation_failed(4, [err localizedDescription]));
                        return;
                    }
                }
                
                NSMutableDictionary <NSString *, NSString *> *scriptEnvp = [request.jsonObject[@"envp"] mutableCopy];
                if (scriptEnvp != nil && ![scriptEnvp isKindOfClass:[NSDictionary class]]) {
                    completionBlock(resp_bad_request(@"envp"));
                    return;
                } else {
                    scriptEnvp = [NSMutableDictionary dictionary];
                }
                
                SupervisorState globalState = [[Supervisor sharedInstance] globalState];
                if (globalState == SupervisorStateRunning || globalState == SupervisorStateSuspend) {
                    completionBlock(resp_operation_failed(3, @"The system is currently running another script"));
                    return;
                } else if (globalState == SupervisorStateRecording) {
                    completionBlock(resp_operation_failed(9, @"The system is currently recording script events"));
                    return;
                }
                
                NSString *nextEntryType = nil;
                if ([[request.headers[@"user-agent"] uppercaseString] hasPrefix:@"X.X.T./"]) {
                    nextEntryType = @"application";
                } else {
                    nextEntryType = @"openapi";
                }
                [scriptEnvp setObject:nextEntryType forKey:@"XXT_ENTRYTYPE"];
                
                NSError *err = nil;
                BOOL launched = NO;
                if (scriptURL) {
                    launched = [[Supervisor sharedInstance] launchScriptAtPath:[scriptURL path] additionalEnvironmentVariables:scriptEnvp error:&err];
                } else {
                    launched = [[Supervisor sharedInstance] launchSelectedScriptWithAdditionalEnvironmentVariables:scriptEnvp error:&err];
                }
                
                if (!launched) {
                    NSString *failureReason = [err localizedFailureReason];
                    if (failureReason) {
                        completionBlock(resp_operation_failed_flat(err.code, [err localizedDescription], @{ @"detail": failureReason }));
                    } else {
                        completionBlock(resp_operation_failed(err.code, [err localizedDescription]));
                    }
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/spawn", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                SupervisorState globalState = [[Supervisor sharedInstance] globalState];
                if (globalState == SupervisorStateRunning || globalState == SupervisorStateSuspend) {
                    completionBlock(resp_operation_failed(3, @"The system is currently running another script"));
                    return;
                } else if (globalState == SupervisorStateRecording) {
                    completionBlock(resp_operation_failed(9, @"The system is currently recording script events"));
                    return;
                }
                
                NSString *argString = request.headers[@"spawn_args"];
                if (argString)
                {
                    // old value is simply ignored
                    [[ProcQueue sharedInstance] procPutObject:argString forKey:@"spawn_args"];
                }
                
                NSData *scriptData = request.data;
                if (![scriptData isKindOfClass:[NSData class]] || !scriptData.length)
                {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSString *nextEntryType = nil;
                if ([[request.headers[@"user-agent"] uppercaseString] hasPrefix:@"X.X.T./"]) {
                    nextEntryType = @"application";
                } else {
                    nextEntryType = @"openapi";
                }
                
                NSError *err = nil;
                BOOL launched = [[Supervisor sharedInstance] launchScriptData:scriptData additionalEnvironmentVariables:@{
                    @"XXT_ENTRYTYPE": nextEntryType,
                } error:&err];
                
                if (!launched) {
                    NSString *failureReason = [err localizedFailureReason];
                    if (failureReason) {
                        completionBlock(resp_operation_failed_flat(err.code, [err localizedDescription], @{ @"detail": failureReason }));
                    } else {
                        completionBlock(resp_operation_failed(err.code, [err localizedDescription]));
                    }
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/recycle", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                [[Supervisor sharedInstance] recycleGlobalProcess];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/pause_script", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                [[Supervisor sharedInstance] stopGlobalProcess];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/resume_script", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                [[Supervisor sharedInstance] continueGlobalProcess];
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/check_syntax", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSData *scriptData = request.data;
                if (![scriptData isKindOfClass:[NSData class]] || !scriptData.length)
                {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSString *errorMessage = [[Supervisor sharedInstance] checkLuaSyntaxWithData:scriptData];
                if (!errorMessage) {
                    completionBlock(resp_operation_failed(1, nil));
                    return;
                }
                
                if (errorMessage.length) {
                    completionBlock(resp_operation_failed_flat(2, nil, @{ @"detail": errorMessage }));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/is_running", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                SupervisorState globalState = [[Supervisor sharedInstance] globalState];
                if (globalState == SupervisorStateRunning || globalState == SupervisorStateSuspend) {
                    completionBlock(resp_operation_failed(3, @"The system is currently running another script"));
                    return;
                } else if (globalState == SupervisorStateRecording) {
                    completionBlock(resp_operation_failed(9, @"The system is currently recording script events"));
                    return;
                }
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/encript_file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                BOOL doNotStrip = [request.jsonObject[@"no_strip"] boolValue];
                
                NSString *inputScriptName = request.jsonObject[@"in_file"];
                if (![inputScriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"in_file"));
                    return;
                }
                
                if ([inputScriptName hasPrefix:@"/private/var/"])
                    inputScriptName = [inputScriptName substringFromIndex:8];
                if ([inputScriptName hasPrefix:@MEDIA_ROOT "/"])
                    inputScriptName = [inputScriptName substringFromIndex:sizeof(MEDIA_ROOT)];
                
                {
                    inputScriptName = strip_unsafe_components(inputScriptName);
                    
                    if (!inputScriptName.length) {
                        completionBlock(resp_bad_request(@"in_file"));
                        return;
                    }
                    
                    NSString *scriptExtension = [[inputScriptName pathExtension] lowercaseString] ?: @"";
                    if (![scriptExtension isEqualToString:@"lua"])
                    {
                        completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                        return;
                    }
                }
                
                NSString *outputScriptName = request.jsonObject[@"out_file"];
                if (![outputScriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_bad_request(@"out_file"));
                    return;
                }
                
                if ([outputScriptName hasPrefix:@"/private/var/"])
                    outputScriptName = [outputScriptName substringFromIndex:8];
                if ([outputScriptName hasPrefix:@MEDIA_ROOT "/"])
                    outputScriptName = [outputScriptName substringFromIndex:sizeof(MEDIA_ROOT)];
                
                {
                    outputScriptName = strip_unsafe_components(outputScriptName);
                    
                    if (!outputScriptName.length) {
                        completionBlock(resp_bad_request(@"out_file"));
                        return;
                    }
                    
                    NSString *scriptExtension = [[outputScriptName pathExtension] lowercaseString] ?: @"";
                    if (![scriptExtension isEqualToString:@"luac"] &&
                        ![scriptExtension isEqualToString:@"xxt"])
                    {
                        completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *inputScriptURL = [NSURL fileURLWithPath:inputScriptName relativeToURL:rootURL];
                NSURL *outputScriptURL = [NSURL fileURLWithPath:outputScriptName relativeToURL:rootURL];
                
                NSError *compileErr = nil;
                BOOL compiled = [[Supervisor sharedInstance] compileLuaAtPath:[inputScriptURL path]
                                                                       toPath:[outputScriptURL path]
                                                        stripDebugInformation:!doNotStrip
                                                                        error:&compileErr];
                if (!compiled) {
                    completionBlock(resp_operation_failed_flat(2, nil, @{ @"detail": [compileErr localizedDescription] ?: @"" }));
                    return;
                }
                
                completionBlock(resp_operation_succeed(nil));
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/encript", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                BOOL doNotStrip = NO;
                NSString *targetName = nil;
                
                NSString *argsString = request.headers[@"args"];
                if ([argsString isKindOfClass:[NSString class]])
                {
                    NSDictionary *argsDict = [NSJSONSerialization JSONObjectWithData:[request.headers[@"args"] dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
                    if ([argsDict isKindOfClass:[NSDictionary class]])
                    {
                        doNotStrip = [argsDict[@"no_strip"] boolValue];
                        targetName = [argsDict[@"filename"] stringByRemovingPercentEncoding];
                        if (![targetName isKindOfClass:[NSString class]] || !targetName.length)
                        {
                            completionBlock(resp_bad_request(@"filename"));
                            return;
                        }
                    }
                }
                
                if (targetName) {
                    targetName = strip_unsafe_components(targetName);
                    
                    if (!targetName.length) {
                        completionBlock(resp_bad_request(@"filename"));
                        return;
                    }
                    
                    NSString *scriptExtension = [[targetName pathExtension] lowercaseString] ?: @"";
                    if (!scriptExtension.length) {
                        scriptExtension = @"xxt";
                        targetName = [targetName stringByAppendingPathExtension:@"xxt"];
                    }
                    else if (![scriptExtension isEqualToString:@"luac"] &&
                             ![scriptExtension isEqualToString:@"xxt"])
                    {
                        completionBlock(resp_operation_failed(4, [NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension]));
                        return;
                    }
                }
                
                NSData *scriptData = request.data;
                if (![scriptData isKindOfClass:[NSData class]] || !scriptData.length)
                {
                    completionBlock(resp_bad_request(nil));
                    return;
                }
                
                NSError *compileErr = nil;
                NSData *compiledData = [[Supervisor sharedInstance] compileLuaWithData:scriptData
                                                                 stripDebugInformation:!doNotStrip
                                                                                 error:&compileErr];
                if (!compiledData) {
                    if (targetName) {
                        completionBlock(resp_operation_failed_flat_400(2, nil, @{ @"detail": [compileErr localizedDescription] ?: @"" }));
                    } else {
                        completionBlock(resp_operation_failed_flat(2, nil, @{ @"detail": [compileErr localizedDescription] ?: @"" }));
                    }
                    return;
                }
                
                if (targetName) {
                    NSString *randomUUID = [[NSUUID UUID] UUIDString];
                    NSString *outputDir = [@MEDIA_CACHES_DIR stringByAppendingPathComponent:randomUUID];
                    
                    NSError *createErr = nil;
                    BOOL created = [_serviceFileManager createDirectoryAtPath:outputDir
                                                  withIntermediateDirectories:YES
                                                                   attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }
                                                                        error:&createErr];
                    if (!created) {
                        completionBlock(resp_operation_failed(2, [createErr localizedDescription]));
                        return;
                    }
                    
                    NSString *outputPath = [outputDir stringByAppendingPathComponent:targetName];
                    NSError *writeErr = nil;
                    BOOL wrote = [compiledData writeToFile:outputPath options:NSDataWritingAtomic error:&writeErr];
                    if (!wrote) {
                        completionBlock(resp_operation_failed_400(2, [writeErr localizedDescription]));
                        return;
                    }
                    
                    NSString *downloadURI = [NSString stringWithFormat:@"/caches/%@/%@", randomUUID, targetName];
                    completionBlock(resp_operation_succeed_flat(@{ @"download_uri": downloadURI, @"data": @{ @"download_uri": downloadURI } }));
                } else {
                    completionBlock([GCDWebServerDataResponse responseWithData:compiledData contentType:@"application/octet-stream"]);
                }
            }
        });
    });
}

static void register_auth_manager_handlers(GCDWebServer *webServer)
{
    register_path_handler(webServer, @[@"POST"], @"/device_auth_info", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(@{
            @"nowDate": @([[NSDate date] timeIntervalSince1970]),
            @"expireDate": @([[NSDate distantFuture] timeIntervalSince1970])
        });
    });
    
    register_path_handler(webServer, @[@"POST"], @"/bind_code", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
}

static void register_deprecated_handlers(GCDWebServer *webServer)
{
    register_path_handler(webServer, @[@"POST"], @"/set_no_nosim_alert_on", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
    
    register_path_handler(webServer, @[@"POST"], @"/set_no_nosim_alert_off", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
    
    register_path_handler(webServer, @[@"POST"], @"/set_no_low_power_alert_on", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
    
    register_path_handler(webServer, @[@"POST"], @"/set_no_low_power_alert_off", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
    
    register_path_handler(webServer, @[@"POST"], @"/set_no_need_pushid_alert_on", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
    
    register_path_handler(webServer, @[@"POST"], @"/set_no_need_pushid_alert_off", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
    
    register_path_handler(webServer, @[@"POST"], @"/clear_gps", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
    
    register_path_handler(webServer, @[@"POST"], @"/clear_all", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
    
    register_path_handler(webServer, @[@"POST"], @"/clear_app_data", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return resp_operation_succeed(nil);
    });
}

static void register_touchelf_handlers(GCDWebServer *webServer)
{
    /* TouchElf Compatible OpenAPI */
    register_path_handler(webServer, @[@"GET"], @"/api", ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return [GCDWebServerDataResponse responseWithText:@"touchelf"];
    });
    
    register_path_handler_async(webServer, @[@"GET"], @"/api/app/state", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                completionBlock([ELFCloudClient responseByHandleMessageWithType:@"app/state" body:nil]);
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"PUT"], @"/api/config", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                
                NSDictionary *cloudDict = request.jsonObject[@"cloud"];
                if ([cloudDict isKindOfClass:[NSDictionary class]])
                {
                    NSMutableDictionary *cloudConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.cloud"] mutableCopy];
                    if (![cloudConf isKindOfClass:[NSDictionary class]])
                    {
                        cloudConf = [NSMutableDictionary dictionaryWithDictionary:cloudDict];
                    }
                    else
                    {
                        [cloudConf addEntriesFromDictionary:cloudDict];
                    }
                    
                    [[ProcQueue sharedInstance] setObject:cloudConf forKey:@"ch.xxtou.defaults.cloud"];
                    
                    if ([cloudDict[@"enabled"] isKindOfClass:[NSNumber class]] ||
                        [cloudDict[@"enable"] isKindOfClass:[NSNumber class]])
                    {
                        BOOL isEnabled = NO;
                        if ([cloudDict[@"enabled"] isKindOfClass:[NSNumber class]])
                        {
                            isEnabled = [cloudDict[@"enabled"] boolValue];
                        }
                        else
                        {
                            isEnabled = [cloudDict[@"enable"] boolValue];
                        }
                        
                        ios_system("/bin/launchctl kickstart -p -k system/ch.xxtou.elfclient");
                    }
                }
                
                {
                    BOOL notifyStop = [request.jsonObject[@"notify_stop"] boolValue];
                    NSMutableDictionary *userConf = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.user"] mutableCopy];
                    if (![userConf isKindOfClass:[NSDictionary class]]) {
                        userConf = [NSMutableDictionary dictionary];
                    }
                    [userConf setObject:@(notifyStop) forKey:@"script_end_hint"];
                    [[ProcQueue sharedInstance] setObject:[userConf copy] forKey:@"ch.xxtou.defaults.user"];
                }
                
                completionBlock(resp_v1_ok_204());
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/api/script/stop", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                completionBlock([ELFCloudClient responseByHandleMessageWithType:@"script/stop" body:nil]);
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET"], @"/api/script", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                completionBlock([ELFCloudClient responseByHandleMessageWithType:@"script/list" body:nil]);
            }
        });
    });
    
    {
        static NSRegularExpression *scriptNameRegex = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            scriptNameRegex = [NSRegularExpression regularExpressionWithPattern:@"^/api/script/([^/]+?)/(run|debug)/?$" options:kNilOptions error:nil];
        });
        register_regex_handler_async(webServer, @[@"POST"], scriptNameRegex.pattern, ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            if (!is_accessible(request)) {
                completionBlock(resp_v1_unauthorized());
                return;
            }
            dispatch_async(_serviceQueue, ^{
                @autoreleasepool {
                    
                    NSTextCheckingResult *nameMatch = [scriptNameRegex firstMatchInString:request.path options:kNilOptions range:NSMakeRange(0, request.path.length)];
                    if (nameMatch.numberOfRanges < 3)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSRange nameRange = [nameMatch rangeAtIndex:1];
                    if (nameRange.location == NSNotFound)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSString *scriptName = [request.path substringWithRange:nameRange];
                    if (!scriptName.length)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSRange actionRange = [nameMatch rangeAtIndex:2];
                    if (actionRange.location == NSNotFound)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSString *actionType = [request.path substringWithRange:actionRange];
                    if (![actionType isEqualToString:@"run"] && ![actionType isEqualToString:@"debug"])
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSString *msgType = [actionType isEqualToString:@"debug"] ? @"script/debug" : @"script/run";
                    
                    completionBlock([ELFCloudClient responseByHandleMessageWithType:msgType body:@{
                        @"name": scriptName,
                    }]);
                }
            });
        });
    }
    
    {
        static NSRegularExpression *scriptNameRegex = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            scriptNameRegex = [NSRegularExpression regularExpressionWithPattern:@"^/api/script/([^/]+?)/encrypt/?$" options:kNilOptions error:nil];
        });
        register_regex_handler_async(webServer, @[@"POST"], scriptNameRegex.pattern, ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            if (!is_accessible(request)) {
                completionBlock(resp_v1_unauthorized());
                return;
            }
            dispatch_async(_serviceQueue, ^{
                @autoreleasepool {
                    
                    NSTextCheckingResult *nameMatch = [scriptNameRegex firstMatchInString:request.path options:kNilOptions range:NSMakeRange(0, request.path.length)];
                    if (nameMatch.numberOfRanges < 2)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSRange nameRange = [nameMatch rangeAtIndex:1];
                    if (nameRange.location == NSNotFound)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSString *scriptName = [request.path substringWithRange:nameRange];
                    if (!scriptName.length)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    completionBlock([ELFCloudClient responseByHandleMessageWithType:@"script/encrypt" body:@{
                        @"name": scriptName,
                    }]);
                }
            });
        });
    }
    
    {
        static NSRegularExpression *scriptNameRegex = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            scriptNameRegex = [NSRegularExpression regularExpressionWithPattern:@"^/api/script/([^/]+?)/?$" options:kNilOptions error:nil];
        });
        register_regex_handler_async(webServer, @[@"GET", @"PUT", @"DELETE"], scriptNameRegex.pattern, ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            if (!is_accessible(request)) {
                completionBlock(resp_v1_unauthorized());
                return;
            }
            dispatch_async(_serviceQueue, ^{
                @autoreleasepool {
                    
                    NSTextCheckingResult *nameMatch = [scriptNameRegex firstMatchInString:request.path options:kNilOptions range:NSMakeRange(0, request.path.length)];
                    if (nameMatch.numberOfRanges < 2)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSRange nameRange = [nameMatch rangeAtIndex:1];
                    if (nameRange.location == NSNotFound)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSString *scriptName = [request.path substringWithRange:nameRange];
                    if (!scriptName.length)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    if ([scriptName hasPrefix:@"/private/var/"])
                        scriptName = [scriptName substringFromIndex:8];
                    if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                        scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                    
                    {
                        scriptName = strip_unsafe_components(scriptName);
                        
                        if (!scriptName.length) {
                            completionBlock(resp_v1_bad_request());
                            return;
                        }
                        
                        NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                        if (![scriptExtension isEqualToString:@"lua"] &&
                            ![scriptExtension isEqualToString:@"luac"] &&
                            ![scriptExtension isEqualToString:@"xxt"])
                        {
                            completionBlock(resp_v1_bad_request());
                            return;
                        }
                    }
                    
                    NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                    NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                    
                    if ([[request.method uppercaseString] isEqualToString:@"GET"] ||
                        [[request.method uppercaseString] isEqualToString:@"DELETE"])
                    {
                        NSError *err = nil;
                        BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                        if (!reachable)
                        {
                            completionBlock(resp_v1_not_found());
                            return;
                        }
                    }
                    else
                    {
                        if (!request.data)
                        {
                            completionBlock(resp_v1_bad_request());
                            return;
                        }
                    }
                    
                    if ([[request.method uppercaseString] isEqualToString:@"GET"])
                    {   // GET
                        completionBlock([GCDWebServerFileResponse responseWithFile:[scriptURL path]
                                                                         byteRange:request.byteRange
                                                                      isAttachment:YES]);
                    }
                    else if ([[request.method uppercaseString] isEqualToString:@"PUT"])
                    {   // PUT
                        BOOL created = [_serviceFileManager createFileAtPath:[scriptURL path]
                                                                    contents:request.data
                                                                  attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }];
                        if (!created)
                        {
                            completionBlock(resp_v1_internal_server_error(@"Failed to write script file"));
                            return;
                        }
                        
                        completionBlock(resp_v1_ok_204());
                    }
                    else
                    {   // DELETE
                        NSError *err = nil;
                        BOOL removed = [_serviceFileManager removeItemAtURL:scriptURL error:&err];
                        if (!removed)
                        {
                            completionBlock(resp_v1_internal_server_error([err localizedDescription]));
                            return;
                        }
                        
                        completionBlock(resp_v1_ok_204());
                    }
                }
            });
        });
    }
    
    register_path_handler_async(webServer, @[@"GET", @"DELETE"], @"/api/system/log", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                
                if ([[request.method uppercaseString] isEqualToString:@"DELETE"])
                {
                    completionBlock([ELFCloudClient responseByHandleMessageWithType:@"system/log/delete" body:nil]);
                    return;
                }
                
                NSInteger lastN = [request.query[@"last"] integerValue];
                if (lastN == 0)
                {
                    completionBlock(resp_v1_bad_request());
                    return;
                }
                
                lastN += 1;
                
                NSInteger foundN = 0;
                NSData *sepData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
                
                NSFileHandle *sysLogHandle = [NSFileHandle fileHandleForReadingAtPath:@LOG_SYS];
                unsigned long long offset = [sysLogHandle seekToEndOfFile];
                unsigned long long endOffset = offset;
                NSRange finalRange = NSMakeRange(NSNotFound, endOffset);
                
                NSData *blockData = nil;
                while (offset > 0)
                {
                    @autoreleasepool
                    {
                        if (offset >= BUFSIZ)
                        {
                            [sysLogHandle seekToFileOffset:(offset - BUFSIZ)];
                            blockData = [sysLogHandle readDataOfLength:BUFSIZ];
                            offset -= BUFSIZ;
                        }
                        else
                        {
                            [sysLogHandle seekToFileOffset:0];
                            blockData = [sysLogHandle readDataOfLength:offset];
                            offset = 0;
                        }
                        
                        NSRange sepRange = NSMakeRange(0, blockData.length);
                        while (YES)
                        {
                            NSRange sepFoundRange = [blockData rangeOfData:sepData options:NSDataSearchBackwards range:sepRange];
                            if (sepFoundRange.location == NSNotFound)
                                break;
                            
                            sepRange.length = sepFoundRange.location;
                            foundN += 1;
                            
                            if (foundN == lastN)
                            {
                                finalRange.location = offset + sepFoundRange.location + sepFoundRange.length;
                                break;
                            }
                        }
                        
                        if (finalRange.location != NSNotFound)
                            break;
                    }
                }
                
                if (finalRange.location == NSNotFound)
                    finalRange.location = 0;
                
                [sysLogHandle closeFile];
                
                if (!finalRange.length)
                {
                    completionBlock(resp_v1_ok_204());
                    return;
                }
                
                completionBlock([GCDWebServerFileResponse responseWithFile:@LOG_SYS
                                                                 byteRange:finalRange
                                                              isAttachment:NO]);
            }
        });
    });
    
    {
        static NSRegularExpression *logNameRegex = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            logNameRegex = [NSRegularExpression regularExpressionWithPattern:@"^/api/system/log/([^/]+?)/?$" options:kNilOptions error:nil];
        });
        register_regex_handler_async(webServer, @[@"GET", @"DELETE"], logNameRegex.pattern, ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            if (!is_accessible(request)) {
                completionBlock(resp_v1_unauthorized());
                return;
            }
            dispatch_async(_serviceQueue, ^{
                @autoreleasepool {
                    
                    NSTextCheckingResult *nameMatch = [logNameRegex firstMatchInString:request.path options:kNilOptions range:NSMakeRange(0, request.path.length)];
                    if (nameMatch.numberOfRanges < 2)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSRange nameRange = [nameMatch rangeAtIndex:1];
                    if (nameRange.location == NSNotFound)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSString *logName = [request.path substringWithRange:nameRange];
                    if (!logName.length)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    if ([logName hasPrefix:@"/private/var/"])
                        logName = [logName substringFromIndex:8];
                    if ([logName hasPrefix:@MEDIA_LOG_DIR])
                        logName = [logName substringFromIndex:sizeof(MEDIA_LOG_DIR)];
                    
                    {
                        logName = strip_unsafe_components(logName);
                        
                        if (!logName.length) {
                            completionBlock(resp_v1_bad_request());
                            return;
                        }
                        
                        NSString *scriptExtension = [[logName pathExtension] lowercaseString] ?: @"";
                        if (![scriptExtension isEqualToString:@"log"])
                        {
                            completionBlock(resp_v1_bad_request());
                            return;
                        }
                    }
                    
                    NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LOG_DIR];
                    NSURL *logURL = [NSURL fileURLWithPath:logName relativeToURL:rootURL];
                    NSString *logPath = [logURL path];
                    
                    if ([[request.method uppercaseString] isEqualToString:@"DELETE"])
                    {
                        if ([_serviceFileManager fileExistsAtPath:logPath])
                        {
                            NSError *err = nil;
                            BOOL removed = [_serviceFileManager removeItemAtPath:logPath error:&err];
                            if (!removed)
                            {
                                completionBlock(resp_v1_internal_server_error([err localizedDescription]));
                                return;
                            }
                        }
                        
                        BOOL created = [_serviceFileManager createFileAtPath:logPath
                                                                    contents:[NSData data]
                                                                  attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                        if (!created)
                        {
                            completionBlock(resp_v1_internal_server_error(@"Failed to create empty log file"));
                            return;
                        }
                        
                        completionBlock(resp_v1_ok_204());
                        return;
                    }
                    
                    NSInteger lastN = [request.query[@"last"] integerValue];
                    if (lastN == 0)
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    lastN += 1;
                    
                    NSInteger foundN = 0;
                    NSData *sepData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
                    
                    NSFileHandle *sysLogHandle = [NSFileHandle fileHandleForReadingAtPath:logPath];
                    unsigned long long offset = [sysLogHandle seekToEndOfFile];
                    unsigned long long endOffset = offset;
                    NSRange finalRange = NSMakeRange(NSNotFound, endOffset);
                    
                    NSData *blockData = nil;
                    while (offset > 0)
                    {
                        @autoreleasepool
                        {
                            if (offset >= BUFSIZ)
                            {
                                [sysLogHandle seekToFileOffset:(offset - BUFSIZ)];
                                blockData = [sysLogHandle readDataOfLength:BUFSIZ];
                                offset -= BUFSIZ;
                            }
                            else
                            {
                                [sysLogHandle seekToFileOffset:0];
                                blockData = [sysLogHandle readDataOfLength:offset];
                                offset = 0;
                            }
                            
                            NSRange sepRange = NSMakeRange(0, blockData.length);
                            while (YES)
                            {
                                NSRange sepFoundRange = [blockData rangeOfData:sepData options:NSDataSearchBackwards range:sepRange];
                                if (sepFoundRange.location == NSNotFound)
                                {
                                    break;
                                }
                                
                                sepRange.length = sepFoundRange.location;
                                foundN += 1;
                                
                                if (foundN == lastN)
                                {
                                    finalRange.location = offset + sepFoundRange.location + sepFoundRange.length;
                                    break;
                                }
                            }
                            
                            if (finalRange.location != NSNotFound)
                            {
                                break;
                            }
                        }
                    }
                    
                    if (finalRange.location == NSNotFound)
                    {
                        finalRange.location = 0;
                    }
                    
                    [sysLogHandle closeFile];
                    
                    if (!finalRange.length)
                    {
                        completionBlock(resp_v1_ok_204());
                        return;
                    }
                    
                    completionBlock([GCDWebServerFileResponse responseWithFile:logPath
                                                                     byteRange:finalRange
                                                                  isAttachment:NO]);
                }
            });
        });
    }
    
    register_path_handler_async(webServer, @[@"POST"], @"/api/system/reboot", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                int code = ios_system("reboot");
                
                if (code) {
                    completionBlock(resp_v1_service_unavailable());
                    return;
                }
                
                completionBlock(resp_v1_ok_204());
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/api/system/respring", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                int code = ios_system("killall -9 SpringBoard backboardd");
                
                if (code) {
                    completionBlock(resp_v1_service_unavailable());
                    return;
                }
                
                completionBlock(resp_v1_ok_204());
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET"], @"/api/screen/snapshot", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                completionBlock([ELFCloudClient responseByHandleMessageWithType:@"screen/snapshot" body:request.query]);
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"PUT", @"DELETE"], @"/api/file", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *fileName = request.query[@"path"];
                
                if ([fileName hasPrefix:@"/private/var/"])
                    fileName = [fileName substringFromIndex:8];
                if ([fileName hasPrefix:@MEDIA_ROOT])
                    fileName = [fileName substringFromIndex:sizeof(MEDIA_ROOT)];
                
                fileName = strip_unsafe_components(fileName);
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *fileURL;
                if (fileName.length)
                {
                    fileURL = [NSURL fileURLWithPath:fileName relativeToURL:rootURL];
                }
                else
                {
                    fileURL = rootURL;
                }
                
                NSString *filePath = [fileURL path];
                
                BOOL isDir = NO;
                BOOL exists = [_serviceFileManager fileExistsAtPath:filePath isDirectory:&isDir];
                
                if ([[request.method uppercaseString] isEqualToString:@"GET"])
                {
                    if (!exists)
                    {
                        completionBlock(resp_v1_not_found());
                        return;
                    }
                    
                    if (isDir)
                    {
                        NSError *err = nil;
                        NSArray <NSString *> *itemList = [_serviceFileManager contentsOfDirectoryAtPath:filePath error:&err];
                        if (!itemList)
                        {
                            completionBlock(resp_v1_internal_server_error([err localizedDescription]));
                            return;
                        }
                        
                        NSMutableArray <NSDictionary *> *retItemList = [NSMutableArray arrayWithCapacity:itemList.count];
                        for (NSString *itemName in itemList) {
                            NSString *itemPath = [filePath stringByAppendingPathComponent:itemName];
                            exists = [_serviceFileManager fileExistsAtPath:itemPath isDirectory:&isDir];
                            [retItemList addObject:@{
                                @"name": itemName,
                                @"type": isDir ? @"dir" : @"file",
                            }];
                        }
                        
                        completionBlock([GCDWebServerDataResponse responseWithJSONObject:[retItemList copy]]);
                        return;
                    }
                    else
                    {
                        completionBlock([GCDWebServerFileResponse responseWithFile:filePath byteRange:request.byteRange isAttachment:YES]);
                        return;
                    }
                }
                else if ([[request.method uppercaseString] isEqualToString:@"PUT"])
                {
                    BOOL isDir = request.query[@"directory"] != nil;
                    
                    if (!isDir) {
                        if (!request.data)
                        {
                            completionBlock(resp_v1_bad_request());
                            return;
                        }
                        
                        BOOL created = [_serviceFileManager createFileAtPath:filePath
                                                                    contents:request.data
                                                                  attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                        if (!created)
                        {
                            completionBlock(resp_v1_internal_server_error(@"Failed to create empty log file"));
                            return;
                        }
                    } else {
                        NSError *err = nil;
                        BOOL created = [_serviceFileManager createDirectoryAtPath:filePath
                                                      withIntermediateDirectories:YES
                                                                       attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }
                                                                            error:&err];
                        if (!created)
                        {
                            completionBlock(resp_v1_internal_server_error([err localizedDescription]));
                            return;
                        }
                    }
                    
                    completionBlock(resp_v1_ok_204());
                    return;
                }
                else if ([[request.method uppercaseString] isEqualToString:@"DELETE"])
                {
                    if (!exists)
                    {
                        completionBlock(resp_v1_not_found());
                        return;
                    }
                    
                    NSError *err = nil;
                    BOOL removed = [_serviceFileManager removeItemAtPath:filePath error:&err];
                    if (!removed)
                    {
                        completionBlock(resp_v1_internal_server_error([err localizedDescription]));
                        return;
                    }
                    
                    completionBlock(resp_v1_ok_204());
                }
            }
        });
    });
}

NS_INLINE NSURL *baseurl_openapi_v1(NSString *uploadRoot)
{
    NSURL *rootURL;
    if ([uploadRoot isEqualToString:@"lua"]) {
        rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
    } else if ([uploadRoot isEqualToString:@"res"]) {
        rootURL = [NSURL fileURLWithPath:@MEDIA_RES_DIR];
    } else if ([uploadRoot isEqualToString:@"log"]) {
        rootURL = [NSURL fileURLWithPath:@MEDIA_LOG_DIR];
    } else if ([uploadRoot isEqualToString:@"plugin"]) {
        rootURL = [NSURL fileURLWithPath:@MEDIA_LIB_DIR];
    } else if ([uploadRoot isEqualToString:@"config"]) {
        rootURL = [NSURL fileURLWithPath:@MEDIA_CONF_DIR];
    } else {
        rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
    }
    return rootURL;
}

#define MEDIA_LUA_SCRIPTS_DIR_V1 "/var/mobile/Media/TouchSprite/lua"

static void register_openapi_v1_handlers(GCDWebServer *webServer)
{
    /* TouchSprite Compatible OpenAPI */
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/deviceid", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *deviceID = CFBridgingRelease(MGCopyAnswer(kMGUniqueDeviceID, nil));
                completionBlock([GCDWebServerDataResponse responseWithText:deviceID]);
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/devicename", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *deviceName = CFBridgingRelease(MGCopyAnswer(kMGUserAssignedDeviceName, nil));
                completionBlock([GCDWebServerDataResponse responseWithText:deviceName]);
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/upload", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *scriptPath = request.headers[@"path"];
                if (![scriptPath isKindOfClass:[NSString class]] || !scriptPath.length) {
                    scriptPath = @"/";
                }
                
                NSString *scriptName = request.headers[@"filename"];
                if (![scriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_v1_bad_request());
                    return;
                }
                
                NSString *uploadRoot = [request.headers[@"root"] lowercaseString];
                if (![uploadRoot isKindOfClass:[NSString class]] || !uploadRoot.length) {
                    uploadRoot = @"lua";
                }
                
                scriptName = [scriptPath stringByAppendingPathComponent:scriptName];
                
                NSData *scriptData = request.data;
                if (![scriptData isKindOfClass:[NSData class]] || !scriptData.length) {
                    completionBlock(resp_v1_bad_request());
                    return;
                }
                
                {
                    scriptName = strip_unsafe_components(scriptName);
                    
                    if (!scriptName.length) {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                    NSArray <NSString *> *allowedExtension = @[
                        @"lua", @"luac", @"xxt",
                        @"png", @"jpg", @"jpeg",
                        @"zip", @"tar", @"gz",
                        @"conf", @"txt", @"ini",
                        @"html", @"xml", @"plist",
                        @"json", @"csv",
                    ];
                    if (![allowedExtension containsObject:scriptExtension])
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                }
                
                NSURL *rootURL = baseurl_openapi_v1(uploadRoot);
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL exists = [_serviceFileManager fileExistsAtPath:scriptURL.path];
                if (exists) {
                    BOOL deleted = [_serviceFileManager removeItemAtPath:scriptURL.path error:&err];
                    if (!deleted) {
                        completionBlock(resp_v1_fail());
                        return;
                    }
                }
                
                BOOL created = [_serviceFileManager createFileAtPath:scriptURL.path contents:scriptData attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                if (!created) {
                    completionBlock(resp_v1_fail());
                    return;
                }
                
                completionBlock(resp_v1_ok());
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/setLuaPath", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                CHDebugLogSource(@"%@ %@", request.headers, request.text);
                
                NSString *scriptName = request.jsonObject[@"path"];
                if (![scriptName isKindOfClass:[NSString class]]) {
                    completionBlock(resp_v1_bad_request());
                    return;
                }
                
                if ([scriptName hasPrefix:@"/private/var/"])
                    scriptName = [scriptName substringFromIndex:8];
                if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                    scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR_V1 "/"])
                    scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR_V1)];
                
                {
                    scriptName = strip_unsafe_components(scriptName);
                    
                    if (!scriptName.length) {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                    
                    NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                    if (![scriptExtension isEqualToString:@"lua"] &&
                        ![scriptExtension isEqualToString:@"luac"] &&
                        ![scriptExtension isEqualToString:@"xxt"])
                    {
                        completionBlock(resp_v1_bad_request());
                        return;
                    }
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    completionBlock(resp_v1_fail());
                    return;
                }
                
                [[ProcQueue sharedInstance] setObject:scriptName forKey:@"ch.xxtou.defaults.selected-script"];
                completionBlock(resp_v1_ok());
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/status", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                SupervisorState globalState = [[Supervisor sharedInstance] globalState];
                if (globalState == SupervisorStateRunning || globalState == SupervisorStateSuspend) {
                    completionBlock([GCDWebServerDataResponse responseWithText:@"f01"]);
                    return;
                } else if (globalState == SupervisorStateRecording) {
                    completionBlock([GCDWebServerDataResponse responseWithText:@"f02"]);
                    return;
                }
                completionBlock([GCDWebServerDataResponse responseWithText:@"f00"]);
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/getFileList", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *directoryName = request.headers[@"path"];
                if (![directoryName isKindOfClass:[NSString class]] || !directoryName.length) {
                    directoryName = @"/";
                }
                
                NSString *uploadRoot = [request.headers[@"root"] lowercaseString];
                if (![uploadRoot isKindOfClass:[NSString class]] || !uploadRoot.length) {
                    uploadRoot = @"lua";
                }
                
                directoryName = strip_unsafe_components(directoryName);
                
                NSURL *rootURL = baseurl_openapi_v1(uploadRoot);
                NSURL *directoryURL;
                if (directoryName.length) {
                    directoryURL = [NSURL fileURLWithPath:directoryName relativeToURL:rootURL];
                } else {
                    directoryURL = rootURL;
                }
                
                NSMutableArray <NSString *> *fileList = [NSMutableArray array];
                NSMutableArray <NSString *> *dirList = [NSMutableArray array];
                
                NSError *err = nil;
                NSArray <NSURL *> *childURLs = [_serviceFileManager contentsOfDirectoryAtURL:directoryURL includingPropertiesForKeys:nil options:(NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants) error:&err];
                
                if (!childURLs) {
                    completionBlock(resp_v1_fail());
                    return;
                }
                
                struct stat childStat;
                for (NSURL *childURL in childURLs) {
                    if (lstat([[childURL path] UTF8String], &childStat))
                        continue;
                    NSString *fileType = file_type_from_st_mode(childStat.st_mode);
                    NSString *childName = [childURL lastPathComponent];
                    if (!childName)
                        continue;
                    if ([fileType isEqualToString:@"file"]) {
                        [fileList addObject:childName];
                    } else if ([fileType isEqualToString:@"directory"]) {
                        [dirList addObject:childName];
                    }
                }
                
                completionBlock([GCDWebServerDataResponse responseWithJSONObject:@{
                    @"ret": @(YES),
                    @"Dirs": dirList,
                    @"Files": fileList,
                    @"Path": directoryName,
                    @"Root": uploadRoot,
                }]);
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/getFile", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *fileName = request.headers[@"file"];
                if (![fileName isKindOfClass:[NSString class]] || !fileName.length) {
                    completionBlock(resp_v1_bad_request());
                    return;
                }
                
                NSString *directoryName = request.headers[@"path"];
                if (![directoryName isKindOfClass:[NSString class]] || !directoryName.length) {
                    directoryName = @"/";
                }
                
                NSString *uploadRoot = [request.headers[@"root"] lowercaseString];
                if (![uploadRoot isKindOfClass:[NSString class]] || !uploadRoot.length) {
                    uploadRoot = @"lua";
                }
                
                directoryName = strip_unsafe_components(directoryName);
                
                NSURL *rootURL = baseurl_openapi_v1(uploadRoot);
                NSURL *directoryURL;
                if (directoryName.length) {
                    directoryURL = [NSURL fileURLWithPath:directoryName relativeToURL:rootURL];
                } else {
                    directoryURL = rootURL;
                }
                
                NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
                
                NSError *err = nil;
                BOOL reachable = [fileURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    completionBlock(resp_v1_fail());
                    return;
                }
                
                NSData *contents = [_serviceFileManager contentsAtPath:fileURL.path];
                if (!contents)
                {
                    completionBlock(resp_v1_fail());
                    return;
                }
                
                completionBlock([GCDWebServerDataResponse responseWithData:contents contentType:@"application/octet-stream"]);
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/rmFile", ^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                NSString *fileName = request.headers[@"file"];
                if (![fileName isKindOfClass:[NSString class]] || !fileName.length) {
                    completionBlock(resp_v1_bad_request());
                    return;
                }
                
                NSString *directoryName = request.headers[@"path"];
                if (![directoryName isKindOfClass:[NSString class]] || !directoryName.length) {
                    directoryName = @"/";
                }
                
                NSString *uploadRoot = [request.headers[@"root"] lowercaseString];
                if (![uploadRoot isKindOfClass:[NSString class]] || !uploadRoot.length) {
                    uploadRoot = @"lua";
                }
                
                directoryName = strip_unsafe_components(directoryName);
                
                NSURL *rootURL = baseurl_openapi_v1(uploadRoot);
                NSURL *directoryURL;
                if (directoryName.length) {
                    directoryURL = [NSURL fileURLWithPath:directoryName relativeToURL:rootURL];
                } else {
                    directoryURL = rootURL;
                }
                
                NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
                
                NSError *err = nil;
                BOOL reachable = [fileURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    completionBlock(resp_v1_fail());
                    return;
                }
                
                BOOL removed = [_serviceFileManager removeItemAtURL:fileURL error:&err];
                if (!removed)
                {
                    completionBlock(resp_v1_fail());
                    return;
                }
                
                completionBlock(resp_v1_ok());
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/reboot", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                int rebootType = [request.query[@"type"] intValue];
                
                int code;
                if (!rebootType) {
                    code = ios_system("killall -9 SpringBoard backboardd");
                } else {
                    code = ios_system("reboot");
                }
                
                if (code) {
                    completionBlock(resp_v1_fail());
                    return;
                }
                completionBlock(resp_v1_ok());
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/runLua", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                SupervisorState globalState = [[Supervisor sharedInstance] globalState];
                if (globalState == SupervisorStateRunning || globalState == SupervisorStateSuspend) {
                    completionBlock(resp_v1_service_unavailable());
                    return;
                } else if (globalState == SupervisorStateRecording) {
                    completionBlock(resp_v1_service_unavailable());
                    return;
                }
                
                NSString *nextEntryType = nil;
                if ([[request.headers[@"user-agent"] lowercaseString] hasPrefix:@"java/"]) {
                    nextEntryType = @"touchsprite";
                } else {
                    nextEntryType = @"openapi";
                }
                
                NSError *err = nil;
                BOOL launched = [[Supervisor sharedInstance] launchSelectedScriptWithAdditionalEnvironmentVariables:@{
                    @"XXT_ENTRYTYPE": nextEntryType,
                } error:&err];
                if (!launched) {
                    completionBlock(resp_v1_fail());
                    return;
                }
                
                completionBlock(resp_v1_ok());
            }
        });
    });
    
    register_path_handler_async(webServer, @[@"GET", @"POST"], @"/stopLua", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_v1_unauthorized());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            @autoreleasepool {
                [[Supervisor sharedInstance] recycleGlobalProcess];
                completionBlock(resp_v1_ok());
            }
        });
    });
}

static void register_static_website_handlers(GCDWebServer *webServer)
{
    [webServer addGETHandlerForBasePath:@"/"
                          directoryPath:@MEDIA_WEB_DIR
                          indexFilename:@"index.html"
                               cacheAge:7200
                     allowRangeRequests:YES];
    
    [webServer addGETHandlerForBasePath:@"/caches/"  // must ends with slash
                          directoryPath:@MEDIA_CACHES_DIR
                          indexFilename:@"index.html"
                               cacheAge:0            // no cache
                     allowRangeRequests:YES];
}


#pragma mark - Remote Access

@interface ProcQueue (Notification)
@end
@implementation ProcQueue (Notification)
- (void)remoteDefaultsChanged
{
    dispatch_async(_serviceQueue, ^{
        @autoreleasepool {
            _remoteAccessEnabled = [[self objectForKey:@"ch.xxtou.defaults.remote-access"] boolValue];
            CHDebugLog(@"remote access: %@", (_remoteAccessEnabled ? @"enabled" : @"disabled"));
        }
    });
}
@end

static void register_remote_access_handlers(GCDWebServer *webServer)
{
    register_path_handler_async(webServer, @[@"POST"], @"/open_remote_access", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_localhost(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            [[ProcQueue sharedInstance] setObject:@(YES) forKey:@"ch.xxtou.defaults.remote-access"];
            
            NSMutableDictionary *respDict = [NSMutableDictionary dictionaryWithDictionary:@{ @"opened": @(YES) }];
            
            if (webServer.serverURL)
                respDict[@"webserver_url"] = [webServer.serverURL absoluteString];
            
            if (webServer.bonjourServerURL)
                respDict[@"bonjour_webserver_url"] = [webServer.bonjourServerURL absoluteString];
            
            completionBlock(resp_operation_succeed(respDict));
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/close_remote_access", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            [[ProcQueue sharedInstance] setObject:@(NO) forKey:@"ch.xxtou.defaults.remote-access"];
            completionBlock(resp_operation_succeed(nil));
        });
    });
    
    register_path_handler_async(webServer, @[@"POST"], @"/is_remote_access_opened", ^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        if (!is_accessible(request)) {
            completionBlock(resp_remote_access_forbidden());
            return;
        }
        dispatch_async(_serviceQueue, ^{
            BOOL opened = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.remote-access"] boolValue];
            NSMutableDictionary *respDict = [NSMutableDictionary dictionaryWithDictionary:@{ @"opened": @(opened) }];
            
            if (webServer.serverURL)
                respDict[@"webserver_url"] = [webServer.serverURL absoluteString];
            
            if (webServer.bonjourServerURL)
                respDict[@"bonjour_webserver_url"] = [webServer.bonjourServerURL absoluteString];
            
            completionBlock(resp_operation_succeed(respDict));
        });
    });
}


#pragma mark -

static void ensure_base_structure(void)
{
    dispatch_async(_serviceQueue, ^{
        @autoreleasepool {
            BOOL exists = NO;
            BOOL isDirectory = NO;
            BOOL succeed = NO;
            NSError *error = nil;
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_ROOT isDirectory:&isDirectory];
                if (!exists) {
                    succeed = [_serviceFileManager createDirectoryAtPath:@MEDIA_ROOT withIntermediateDirectories:YES attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) } error:&error];
                    NSCAssert1(succeed, @"%@", error);
                } else {
                    NSDictionary <NSFileAttributeKey, id> *attrs = [_serviceFileManager attributesOfItemAtPath:@MEDIA_ROOT error:&error];
                    NSCAssert1(attrs, @"%@", error);
                    if ([attrs[NSFileCreationDate] timeIntervalSince1970] < 1655563797) {
                        CHLogSource(@"remove legacy base");
                        succeed = [_serviceFileManager removeItemAtPath:@MEDIA_ROOT error:&error];
                        NSCAssert1(succeed, @"%@", error);
                    }
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_LUA_SCRIPTS_DIR isDirectory:&isDirectory];
                if (!exists) {
                    succeed = [_serviceFileManager createDirectoryAtPath:@MEDIA_LUA_SCRIPTS_DIR withIntermediateDirectories:YES attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) } error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_BIN_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createSymbolicLinkAtPath:@MEDIA_BIN_DIR withDestinationPath:@"/usr/local/xxtouch/bin" error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_LIB_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createSymbolicLinkAtPath:@MEDIA_LIB_DIR withDestinationPath:@"/usr/local/xxtouch/lib" error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_LOG_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createSymbolicLinkAtPath:@MEDIA_LOG_DIR withDestinationPath:@"/usr/local/xxtouch/log" error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_LOG_DIR];
                if (exists) {
                    NSString *logPath;
                    {
                        logPath = @MEDIA_LOG_DIR "/sys.log";
                        exists = [_serviceFileManager fileExistsAtPath:logPath];
                        if (!exists) {
                            succeed = [_serviceFileManager createFileAtPath:logPath
                                                         contents:[NSData data]
                                                       attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                            NSCAssert(succeed, @"Failed to create empty log file");
                        } else {
                            succeed = [_serviceFileManager setAttributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) } ofItemAtPath:logPath error:&error];
                            NSCAssert1(succeed, @"%@", error);
                        }
                    }
                    {
                        logPath = @MEDIA_LOG_DIR "/script_output.log";
                        exists = [_serviceFileManager fileExistsAtPath:logPath];
                        if (!exists) {
                            succeed = [_serviceFileManager createFileAtPath:logPath
                                                         contents:[NSData data]
                                                       attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                            NSCAssert(succeed, @"Failed to create empty log file");
                        } else {
                            succeed = [_serviceFileManager setAttributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) } ofItemAtPath:logPath error:&error];
                            NSCAssert1(succeed, @"%@", error);
                        }
                    }
                    {
                        logPath = @MEDIA_LOG_DIR "/script_error.log";
                        exists = [_serviceFileManager fileExistsAtPath:logPath];
                        if (!exists) {
                            succeed = [_serviceFileManager createFileAtPath:logPath
                                                         contents:[NSData data]
                                                       attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                            NSCAssert(succeed, @"Failed to create empty log file");
                        } else {
                            succeed = [_serviceFileManager setAttributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) } ofItemAtPath:logPath error:&error];
                            NSCAssert1(succeed, @"%@", error);
                        }
                    }
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_CONF_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createSymbolicLinkAtPath:@MEDIA_CONF_DIR withDestinationPath:@"/usr/local/xxtouch/etc" error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_WEB_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createSymbolicLinkAtPath:@MEDIA_WEB_DIR withDestinationPath:@"/usr/local/xxtouch/web" error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_RES_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createDirectoryAtPath:@MEDIA_RES_DIR withIntermediateDirectories:YES attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) } error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_CACHES_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createDirectoryAtPath:@MEDIA_CACHES_DIR withIntermediateDirectories:YES attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) } error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_SNIPPETS_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createDirectoryAtPath:@MEDIA_SNIPPETS_DIR withIntermediateDirectories:YES attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) } error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_UICFG_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createDirectoryAtPath:@MEDIA_UICFG_DIR withIntermediateDirectories:YES attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) } error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            {
                exists = [_serviceFileManager fileExistsAtPath:@MEDIA_TESSDATA_DIR];
                if (!exists) {
                    succeed = [_serviceFileManager createDirectoryAtPath:@MEDIA_TESSDATA_DIR withIntermediateDirectories:YES attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) } error:&error];
                    NSCAssert1(succeed, @"%@", error);
                }
            }
            
            CHLogSource(@"base structure initialized");
        }
    });
}


#pragma mark - UDP Broadcast

typedef NS_ENUM(NSUInteger, WSUdpBroadcastServerProtocol) {
    WSUdpBroadcastServerProtocolXXTouch = 0,
    WSUdpBroadcastServerProtocolLegacy,
};

@interface WSUdpBroadcastServer : NSObject <GCDAsyncUdpSocketDelegate>
@property (nonatomic, assign, readonly) WSUdpBroadcastServerProtocol protocol;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithProtocol:(WSUdpBroadcastServerProtocol)protocol;
@end
@implementation WSUdpBroadcastServer
- (instancetype)initWithProtocol:(WSUdpBroadcastServerProtocol)protocol
{
    self = [super init];
    if (self)
    {
        _protocol = protocol;
    }
    return self;
}
- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
    CHDebugLogSource(@"sock %@ data %@ address %@", sock, data, address);
    
    if (!is_addr_accessible(address))
        return;
    
    @autoreleasepool {
        if (self.protocol == WSUdpBroadcastServerProtocolLegacy && strncmp((const char *)[data bytes], "touchelf", 8) == 0)
        {  // TouchElf
            [sock sendData:[@"touchelf" dataUsingEncoding:NSUTF8StringEncoding] toAddress:address withTimeout:3.0 tag:0];
            return;
        }
        
        NSError *err = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&err];
        if (![jsonDict isKindOfClass:[NSDictionary class]]) {
            CHDebugLogSource(@"%@", err);
            return;
        }
        
        NSString *remoteDeclAddr = jsonDict[@"ip"];
        if (![remoteDeclAddr isKindOfClass:[NSString class]])
            return;
        
        NSNumber *remoteDeclPort = jsonDict[@"port"];
        if (![remoteDeclPort isKindOfClass:[NSNumber class]])
            return;
        
        int declPort = [remoteDeclPort intValue];
        
        if (self.protocol == WSUdpBroadcastServerProtocolXXTouch)
        {   // XXTouch
            CFPropertyListRef plistObj = MGCopyMultipleAnswers((__bridge CFArrayRef)@[
                (__bridge NSString *)kMGSerialNumber,
                (__bridge NSString *)kMGProductType,
                (__bridge NSString *)kMGProductVersion,
                (__bridge NSString *)kMGHWModel,
                (__bridge NSString *)kMGWifiAddress,
                (__bridge NSString *)kMGUniqueDeviceID,
                (__bridge NSString *)kMGUserAssignedDeviceName,
            ], nil);
            
            static NSDictionary <NSString *, NSString *> *keyMappings = @{
                (__bridge NSString *)kMGSerialNumber: @"devsn",
                (__bridge NSString *)kMGProductType: @"devtype",
                (__bridge NSString *)kMGProductVersion: @"sysversion",
                (__bridge NSString *)kMGHWModel: @"hwmodel",
                (__bridge NSString *)kMGWifiAddress: @"devmac",
                (__bridge NSString *)kMGUniqueDeviceID: @"deviceid",
                (__bridge NSString *)kMGUserAssignedDeviceName: @"devname",
            };
            
            NSDictionary *oldDict = (__bridge NSDictionary *)plistObj;
            NSMutableDictionary <NSString *, id> *plistDict = [NSMutableDictionary dictionaryWithCapacity:oldDict.count];
            
            for (NSString *plistKey in oldDict) {
                NSString *newPlistKey = [keyMappings objectForKey:plistKey];
                if (!newPlistKey)
                    continue;
                plistDict[newPlistKey] = oldDict[plistKey];
            }
            
            CFRelease(plistObj);
            
            plistDict[@"zeversion"] = @XXT_VERSION;
            
            NSString *primaryAddress = GCDWebServerGetPrimaryIPAddress(NO);
            if (primaryAddress)
                plistDict[@"ip"] = primaryAddress;
            
            plistDict[@"port"] = @(WEBSERV_PORT);
            
            NSData *respData = [NSJSONSerialization dataWithJSONObject:plistDict options:kNilOptions error:&err];
            if (!respData) {
                CHDebugLogSource(@"%@", err);
                return;
            }
            
            [sock sendData:respData toHost:remoteDeclAddr port:(uint16_t)declPort withTimeout:3.0 tag:0];
        }
        else
        {   // TouchSprite
            CFPropertyListRef plistObj = MGCopyMultipleAnswers((__bridge CFArrayRef)@[
                (__bridge NSString *)kMGUniqueDeviceID,
                (__bridge NSString *)kMGProductVersion,
                (__bridge NSString *)kMGUserAssignedDeviceName,
            ], nil);
            
            static NSDictionary <NSString *, NSString *> *keyMappings = @{
                (__bridge NSString *)kMGUniqueDeviceID: @"deviceid",
                (__bridge NSString *)kMGProductVersion: @"sysver",
                (__bridge NSString *)kMGUserAssignedDeviceName: @"devname",
            };
            
            NSDictionary *oldDict = (__bridge NSDictionary *)plistObj;
            NSMutableDictionary <NSString *, id> *plistDict = [NSMutableDictionary dictionaryWithCapacity:oldDict.count];
            
            for (NSString *plistKey in oldDict) {
                NSString *newPlistKey = [keyMappings objectForKey:plistKey];
                if (!newPlistKey)
                    continue;
                plistDict[newPlistKey] = oldDict[plistKey];
            }
            
            CFRelease(plistObj);
            
            plistDict[@"clientType"] = @1;
            plistDict[@"tsversion"] = @XXT_VERSION;
            
            NSString *primaryAddress = GCDWebServerGetPrimaryIPAddress(NO);
            if (primaryAddress)
                plistDict[@"ip"] = primaryAddress;
            
            plistDict[@"port"] = @(WEBSERV_PORT);
            
            NSData *respData = [NSJSONSerialization dataWithJSONObject:plistDict options:kNilOptions error:&err];
            if (!respData) {
                CHDebugLogSource(@"%@", err);
                return;
            }
            
            [sock sendData:respData toHost:remoteDeclAddr port:(uint16_t)declPort withTimeout:3.0 tag:0];
        }
    }
}
@end

static void register_udp_broadcast_handlers(WSUdpBroadcastServer *broadcastServer)
{
    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:broadcastServer delegateQueue:_serviceQueue];
    
    NSError *err = nil;
    BOOL binded = [udpSocket bindToPort:WEBSERV_BROADCAST_PORT error:&err];
    NSCAssert1(binded, @"%@", [err localizedDescription]);
    
    BOOL began = [udpSocket beginReceiving:&err];
    NSCAssert1(began, @"%@", [err localizedDescription]);
    
    CHLog(@"UDP Broadcast server started on %d", WEBSERV_BROADCAST_PORT);
}

static void register_udp_broadcast_handlers_legacy(WSUdpBroadcastServer *broadcastServer)
{
    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:broadcastServer delegateQueue:_serviceQueue];
    
    NSError *err = nil;
    BOOL binded = [udpSocket bindToPort:WEBSERV_BROADCAST_PORT_V1 error:&err];
    NSCAssert1(binded, @"%@", [err localizedDescription]);
    
    BOOL began = [udpSocket beginReceiving:&err];
    NSCAssert1(began, @"%@", [err localizedDescription]);
    
    CHLog(@"UDP Broadcast server v1 started on %d", WEBSERV_BROADCAST_PORT);
}


#pragma mark - UDP Logging

@interface WSUdpLoggingServer : NSObject <GCDAsyncUdpSocketDelegate>
@property (nonatomic, strong) NSPipe *pipe;
@end
@implementation WSUdpLoggingServer
- (instancetype)init
{
    self = [super init];
    self.pipe = [NSPipe pipe];
    return self;
}
- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
    CHDebugLogSource(@"sock %@ data %@ address %@", sock, data, address);
    
    if (!is_addr_localhost(address))
        return;
    
    @autoreleasepool {
        NSError *writeErr = nil;
        BOOL writeSucceed = [self.pipe.fileHandleForWriting writeData:data error:&writeErr];
        if (!writeSucceed) {
            CHLog(@"sock %@ pipe %@ write failed error %@", sock, self.pipe, writeErr);
        }
    }
}
@end

static void register_udp_logging_handlers(WSUdpLoggingServer *loggingServer)
{
    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:loggingServer delegateQueue:_serviceQueue];
    
    NSError *err = nil;
    BOOL binded = [udpSocket bindToPort:WEBSERV_LOGGING_UDP_RECV_PORT error:&err];
    NSCAssert1(binded, @"%@", [err localizedDescription]);
    
    BOOL began = [udpSocket beginReceiving:&err];
    NSCAssert1(began, @"%@", [err localizedDescription]);
    
    CHLog(@"UDP Logging server started on %d", WEBSERV_LOGGING_UDP_RECV_PORT);
}


#pragma mark - Logging Server

@interface WSWebSocketLoggingProxy : NSObject <PSWebSocketServerDelegate>
@property (nonatomic, strong) WSUdpLoggingServer *loggingProvider;
@property (nonatomic, copy, nullable) NSString *host;
@property (nonatomic, assign) NSUInteger port;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithProvider:(WSUdpLoggingServer *)provider NS_DESIGNATED_INITIALIZER;
@end
@implementation WSWebSocketLoggingProxy {
    NSMutableArray <PSWebSocket *> *_availableSockets;
}
- (instancetype)initWithProvider:(WSUdpLoggingServer *)provider
{
    self = [super init];
    _availableSockets = [[NSMutableArray alloc] init];
    self.loggingProvider = provider;
    [provider.pipe.fileHandleForReading readInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkAvailableDataAndRedirectToConnectedClients:) name:NSFileHandleReadCompletionNotification object:provider.pipe.fileHandleForReading];
    return self;
}
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)serverDidStart:(PSWebSocketServer *)server
{
    dispatch_async(_serviceQueue, ^{
        CHLog(@"Logging receiver %@ started at %@:%lu", server, self.host ?: @"0.0.0.0", self.port);
    });
}
- (void)serverDidStop:(PSWebSocketServer *)server
{
    dispatch_async(_serviceQueue, ^{
        CHLog(@"Logging receiver %@ stopped", server);
    });
}
- (void)server:(PSWebSocketServer *)server didFailWithError:(NSError *)error
{
    dispatch_async(_serviceQueue, ^{
        [self->_availableSockets removeAllObjects];
        NSAssert2(NO, @"Logging receiver %@ failed to start %@", server, error);
        exit(EXIT_FAILURE);
    });
}
- (void)server:(PSWebSocketServer *)server webSocketDidOpen:(PSWebSocket *)webSocket
{
    dispatch_async(_serviceQueue, ^{
        CHDebugLogSource(@"client enter %@", webSocket);
        [self->_availableSockets addObject:webSocket];
    });
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didReceiveMessage:(id)message
{
    // does nothing
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didFailWithError:(NSError *)error
{
    dispatch_async(_serviceQueue, ^{
        @autoreleasepool {
            CHDebugLogSource(@"client %@ error %@", webSocket, error);
            [webSocket closeWithCode:500 reason:[NSString stringWithFormat:@"error occurred %@", error.localizedDescription]];
        }
    });
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    dispatch_async(_serviceQueue, ^{
        @autoreleasepool {
            CHDebugLogSource(@"client leave %@ code %ld reason %@", webSocket, code, reason);
            [self->_availableSockets removeObject:webSocket];
        }
    });
}
- (void)checkAvailableDataAndRedirectToConnectedClients:(NSNotification *)noti
{
    dispatch_async(_serviceQueue, ^{
        @autoreleasepool {
            NSData *recvData = noti.userInfo[NSFileHandleNotificationDataItem];
            CHDebugLogSource(@"log data %lu bytes arrived", recvData.length);
            if ([recvData isKindOfClass:[NSData class]]) {
                NSString *decodedString = [[NSString alloc] initWithData:recvData encoding:NSUTF8StringEncoding];
                if (decodedString) {
                    for (PSWebSocket *clientSocket in self->_availableSockets) {
                        [clientSocket send:decodedString];
                        CHDebugLogSource(@"log text %@ redirected to %@", decodedString, clientSocket);
                    }
                } else {
                    for (PSWebSocket *clientSocket in self->_availableSockets) {
                        [clientSocket send:recvData];
                        CHDebugLogSource(@"log data %lu bytes redirected to %@", recvData.length, clientSocket);
                    }
                }
            }
        }
    });
    [self.loggingProvider.pipe.fileHandleForReading readInBackgroundAndNotify];
}
@end


#pragma mark - ELF Cloud Client

@implementation ELFCloudClient

- (void)webSocket:(PSWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    dispatch_async(_serviceQueue, ^{
        CHLog(@"The websocket %@ closed with code: %@, reason: %@, wasClean: %@", webSocket, @(code), reason, (wasClean) ? @"YES" : @"NO");
        exit(wasClean ? EXIT_SUCCESS : EXIT_FAILURE);
    });
}

- (void)webSocket:(PSWebSocket *)webSocket didFailWithError:(NSError *)error {
    dispatch_async(_serviceQueue, ^{
        CHLog(@"The websocket %@ handshake/connection failed with an error: %@", webSocket, error);
        exit(EXIT_FAILURE);
    });
}

- (void)webSocket:(PSWebSocket *)webSocket didReceiveMessage:(id)message {
    dispatch_async(_serviceQueue, ^{
        @autoreleasepool {
            CHLog(@"The websocket %@ received a message: %@", webSocket, message);
            
            NSData *messageData = nil;
            if ([message isKindOfClass:[NSString class]])
            {
                messageData = [(NSString *)message dataUsingEncoding:NSUTF8StringEncoding];
            }
            else if ([message isKindOfClass:[NSData class]])
            {
                messageData = message;
            }
            else
            {
                return;
            }
            
            NSError *err = nil;
            NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:messageData options:kNilOptions error:&err];
            if (!jsonObject)
            {
                CHDebugLogSource(@"%@", err);
                return;
            }
            else if (![jsonObject isKindOfClass:[NSDictionary class]])
            {
                return;
            }
            
            NSString *msgType = jsonObject[@"type"];
            if (![msgType isKindOfClass:[NSString class]] || !msgType.length)
            {
                return;
            }
            
            id msgBody = jsonObject[@"body"];
            NSMutableDictionary <NSString *, id> *replyObject = [[ELFCloudClient handleMessageWithSourceURL:[[webSocket request] URL] type:msgType body:msgBody] mutableCopy];
            if (!replyObject)
            {
                return;
            }
            
            if (![replyObject[@"type"] isEqualToString:msgType])
            {
                return;
            }
            
            if (![replyObject[@"error"] isKindOfClass:[NSString class]])
            {
                replyObject[@"error"] = @"";
            }
            
            if (!replyObject[@"body"])
            {
                replyObject[@"body"] = @{};
            }
            else if ([replyObject[@"body"] isKindOfClass:[NSData class]])
            {
                [replyObject setObject:[(NSData *)replyObject[@"body"] base64EncodedStringWithOptions:kNilOptions] forKey:@"body"];
            }
            
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:replyObject options:kNilOptions error:&err];
            if (!jsonData)
            {
                CHDebugLogSource(@"%@", err);
                return;
            }
            
            [webSocket send:jsonData];
            CHLog(@"The websocket %@ sent a message: %@", webSocket, replyObject);
        }
    });
}

+ (nonnull GCDWebServerResponse *)responseByHandleMessageWithType:(NSString *)msgType body:(nullable id)msgBody
{
    @autoreleasepool {
        GCDWebServerDataResponse *response = nil;
        NSDictionary *replyObject = [self handleMessageWithSourceURL:nil type:msgType body:msgBody];
        
        NSString *replyError = replyObject[@"error"];
        if (replyError.length) {
            response = [GCDWebServerDataResponse responseWithText:replyError];
        } else {
            id replyBody = replyObject[@"body"];
            if ([replyBody isKindOfClass:[NSData class]])
            {
                response = [GCDWebServerDataResponse responseWithData:replyBody
                                                          contentType:(replyObject[@"contentType"] ?: @"application/octet-stream")];
            }
            else if ([replyBody isKindOfClass:[NSString class]])
            {
                response = [GCDWebServerDataResponse responseWithText:replyBody];
            }
            else if ([replyBody isKindOfClass:[NSDictionary class]])
            {
                response = [GCDWebServerDataResponse responseWithJSONObject:replyBody];
            }
            else if ([replyBody isKindOfClass:[NSArray class]])
            {
                response = [GCDWebServerDataResponse responseWithJSONObject:replyBody];
            }
            else
            {
                response = [GCDWebServerDataResponse response];
            }
        }
        
        response.statusCode = replyObject[@"code"] != nil ? [replyObject[@"code"] integerValue] : kGCDWebServerHTTPStatusCode_OK;
        return response;
    }
}

+ (NSDictionary *)handleMessageWithSourceURL:(nullable NSURL *)sourceURL type:(NSString *)msgType body:(nullable id)msgBody
{
    @autoreleasepool {
        NSMutableDictionary <NSString *, id> *replyObject = [NSMutableDictionary dictionaryWithCapacity:5];
        
        [replyObject setObject:msgType forKey:@"type"];
        [replyObject setObject:@"" forKey:@"error"];
        
        if ([msgType isEqualToString:@"app/state"])
        {
            static NSDateFormatter *dateFormatter = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                dateFormatter = [[NSDateFormatter alloc] init];
                
                NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                [dateFormatter setLocale:enUSPOSIXLocale];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
                [dateFormatter setCalendar:[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]];
            });
            
            NSMutableDictionary <NSString *, id> *respDict = [NSMutableDictionary dictionaryWithCapacity:3];
            [respDict setObject:@{
                @"version": @XXT_VERSION,
                @"license": [dateFormatter stringFromDate:[NSDate distantFuture]],
            } forKey:@"app"];
            
            BOOL isBusy = [[Supervisor sharedInstance] isBusy];
            NSString *scriptName = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.selected-script"];
            [respDict setObject:@{
                @"select": [scriptName isKindOfClass:[NSString class]] ? scriptName : @"",
                @"running": @(isBusy),
            } forKey:@"script"];
            
            NSDictionary <NSString *, id> *cloudConf = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.cloud"];
            if ([cloudConf isKindOfClass:[NSDictionary class]])
            {
                [respDict setObject:cloudConf forKey:@"cloud"];
            }
            else
            {
                [respDict setObject:@{
                    @"enabled": @(NO),
                    @"address": @"",
                } forKey:@"cloud"];
            }
            
            CFPropertyListRef plistObj = MGCopyMultipleAnswers((__bridge CFArrayRef)@[
                (__bridge NSString *)kMGUserAssignedDeviceName,
                (__bridge NSString *)kMGUniqueDeviceID,
            ], nil);
            
            static NSDictionary <NSString *, NSString *> *keyMappings = @{
                (__bridge NSString *)kMGUserAssignedDeviceName: @"name",
                (__bridge NSString *)kMGUniqueDeviceID: @"sn",
            };
            
            NSDictionary *oldDict = (__bridge NSDictionary *)plistObj;
            NSMutableDictionary <NSString *, id> *plistDict = [NSMutableDictionary dictionaryWithCapacity:oldDict.count];
            
            for (NSString *plistKey in oldDict) {
                NSString *newPlistKey = [keyMappings objectForKey:plistKey];
                if (!newPlistKey)
                    continue;
                plistDict[newPlistKey] = oldDict[plistKey];
            }
            
            CFRelease(plistObj);
            
            [plistDict setObject:@"ios" forKey:@"os"];
            NSString *primaryAddress = GCDWebServerGetPrimaryIPAddress(NO);
            if (primaryAddress)
                plistDict[@"ip"] = primaryAddress;
            
            [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
            plistDict[@"battery"] = [NSString stringWithFormat:@"%.2f%%", [[UIDevice currentDevice] batteryLevel] * 100.f];
            [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
            
            NSFileHandle *sysLogHandle = [NSFileHandle fileHandleForReadingAtPath:@LOG_SYS];
            if (sysLogHandle)
            {
                unsigned long long endOffset = [sysLogHandle seekToEndOfFile];
                [sysLogHandle seekToFileOffset:(endOffset >= BUFSIZ ? endOffset - BUFSIZ : 0)];
                NSData *blockData = [sysLogHandle readDataToEndOfFile];
                [sysLogHandle closeFile];
                if (blockData.length > 1)
                {
                    NSData *sepData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
                    NSRange sepRange = [blockData rangeOfData:sepData options:NSDataSearchBackwards range:NSMakeRange(0, blockData.length - 1)];
                    if (sepRange.location != NSNotFound)
                    {
                        NSUInteger beginIdx = sepRange.location + sepRange.length;
                        blockData = [blockData subdataWithRange:NSMakeRange(beginIdx, blockData.length - beginIdx - 1)];
                    }
                    NSString *lastLine = [[NSString alloc] initWithData:blockData encoding:NSUTF8StringEncoding];
                    if (lastLine.length)
                    {
                        plistDict[@"log"] = lastLine;
                    }
                }
            }
            
            if (![plistDict[@"log"] length])
                plistDict[@"log"] = @"";
            
            [respDict setObject:plistDict forKey:@"system"];
            
            [replyObject setObject:respDict forKey:@"body"];
        }
        else if ([msgType isEqualToString:@"app/register"])
        {
            [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
        }
        else if ([msgType isEqualToString:@"script/list"])
        {
            NSError *err = nil;
            NSArray <NSString *> *itemList = [_serviceFileManager contentsOfDirectoryAtPath:@MEDIA_LUA_SCRIPTS_DIR error:&err];
            NSMutableArray <NSString *> *mItemList = [NSMutableArray arrayWithCapacity:itemList.count];
            for (NSString *itemName in itemList) {
                NSString *itemPath = [@MEDIA_LUA_SCRIPTS_DIR stringByAppendingPathComponent:itemName];
                BOOL isDir = NO;
                BOOL exists = [_serviceFileManager fileExistsAtPath:itemPath isDirectory:&isDir];
                if (!exists || isDir)
                {
                    continue;
                }
                NSString *itemExtension = [[itemName pathExtension] lowercaseString];
                if (![itemExtension isEqualToString:@"lua"] &&
                    ![itemExtension isEqualToString:@"luac"] &&
                    ![itemExtension isEqualToString:@"xxt"])
                {
                    continue;
                }
                [mItemList addObject:itemName];
            }
            
            [replyObject setObject:mItemList forKey:@"body"];
        }
        else if (([msgType isEqualToString:@"script/run"] || [msgType isEqualToString:@"script/debug"]) && [msgBody isKindOfClass:[NSDictionary class]])
        {
            do {
                BOOL isDebuggingMode = [msgType isEqualToString:@"script/debug"];
                
                NSString *scriptName = [msgBody objectForKey:@"name"];
                if (![scriptName isKindOfClass:[NSString class]] || !scriptName.length)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"name"] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                if ([scriptName hasPrefix:@"/private/var/"])
                    scriptName = [scriptName substringFromIndex:8];
                if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                    scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                
                scriptName = strip_unsafe_components(scriptName);
                
                if (!scriptName.length) {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"name"] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                if (![scriptExtension isEqualToString:@"lua"] &&
                    ![scriptExtension isEqualToString:@"luac"] &&
                    ![scriptExtension isEqualToString:@"xxt"])
                {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@, unsupported extension: %@", @"name", scriptExtension] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"not found: %@", scriptURL.path] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NotFound) forKey:@"code"];
                    break;
                }
                
                SupervisorState globalState = [[Supervisor sharedInstance] globalState];
                if (globalState == SupervisorStateRunning || globalState == SupervisorStateSuspend)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"service unavailable: %@", @"the system is currently running another script."] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_ServiceUnavailable) forKey:@"code"];
                    break;
                }
                else if (globalState == SupervisorStateRecording)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"service unavailable: %@", @"the system is currently recording script events."] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_ServiceUnavailable) forKey:@"code"];
                    break;
                }
                
                NSMutableDictionary <NSString *, NSString *> *scriptEnvp = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"touchelf", @"XXT_ENTRYTYPE", nil];
                
                if (isDebuggingMode)
                {
                    NSString *remoteAddr = [sourceURL host];
                    if (!remoteAddr.length)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"not found: %@", scriptURL.path] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                        break;
                    }
                    
                    [scriptEnvp setObject:remoteAddr forKey:@"XXT_DEBUG_IP"];
                }
                
                BOOL launched = NO;
                if (scriptURL) {
                    launched = [[Supervisor sharedInstance] launchScriptAtPath:[scriptURL path] additionalEnvironmentVariables:scriptEnvp error:&err];
                } else {
                    launched = [[Supervisor sharedInstance] launchSelectedScriptWithAdditionalEnvironmentVariables:scriptEnvp error:&err];
                }
                
                if (!launched) {
                    [replyObject setObject:[NSString stringWithFormat:@"internal server error: %@", [err localizedDescription]] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                    break;
                }
                
                [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
            } while (NO);
        }
        else if ([msgType isEqualToString:@"script/stop"])
        {
            [[Supervisor sharedInstance] recycleGlobalProcess];
            [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
        }
        else if ([msgType isEqualToString:@"script/encrypt"] && [msgBody isKindOfClass:[NSDictionary class]])
        {
            do {
                NSString *scriptName = [msgBody objectForKey:@"name"];
                if (![scriptName isKindOfClass:[NSString class]] || !scriptName.length)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"name"] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                if ([scriptName hasPrefix:@"/private/var/"])
                    scriptName = [scriptName substringFromIndex:8];
                if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                    scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                
                scriptName = strip_unsafe_components(scriptName);
                
                if (!scriptName.length) {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"name"] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                if (![scriptExtension isEqualToString:@"lua"])
                {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@, unsupported extension: %@", @"name", scriptExtension] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                NSError *err = nil;
                BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                if (!reachable)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"not found: %@", scriptURL.path] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NotFound) forKey:@"code"];
                    break;
                }
                
                NSURL *outScriptURL = [[scriptURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"xxt"];
                
                BOOL compiled = [[Supervisor sharedInstance] compileLuaAtPath:[scriptURL path]
                                                                       toPath:[outScriptURL path]
                                                        stripDebugInformation:YES
                                                                        error:&err];
                if (!compiled) {
                    [replyObject setObject:[NSString stringWithFormat:@"internal server error: %@", [err localizedDescription]] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                    break;
                }
                
                BOOL succeed = [_serviceFileManager setAttributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }
                                                     ofItemAtPath:[outScriptURL path]
                                                            error:&err];
                if (!succeed) {
                    [replyObject setObject:[NSString stringWithFormat:@"internal server error: %@", [err localizedDescription]] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                    break;
                }
                
                [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
            } while (NO);
        }
        else if (([msgType isEqualToString:@"script/get"] || [msgType isEqualToString:@"script/put"] || [msgType isEqualToString:@"script/delete"]) && [msgBody isKindOfClass:[NSDictionary class]])
        {
            do {
                NSString *scriptName = [msgBody objectForKey:@"name"];
                if (![scriptName isKindOfClass:[NSString class]] || !scriptName.length)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"name"] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                if ([scriptName hasPrefix:@"/private/var/"])
                    scriptName = [scriptName substringFromIndex:8];
                if ([scriptName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                    scriptName = [scriptName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
                
                scriptName = strip_unsafe_components(scriptName);
                
                if (!scriptName.length) {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"name"] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                NSString *scriptExtension = [[scriptName pathExtension] lowercaseString] ?: @"";
                if (![scriptExtension isEqualToString:@"lua"] &&
                    ![scriptExtension isEqualToString:@"luac"] &&
                    ![scriptExtension isEqualToString:@"xxt"])
                {
                    [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@, unsupported extension: %@", @"name", scriptExtension] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                    break;
                }
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
                NSURL *scriptURL = [NSURL fileURLWithPath:scriptName relativeToURL:rootURL];
                
                if ([msgType isEqualToString:@"script/get"] || [msgType isEqualToString:@"script/delete"])
                {   // GET or DELETE
                    NSError *err = nil;
                    BOOL reachable = [scriptURL checkResourceIsReachableAndReturnError:&err];
                    if (!reachable)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"not accessible: %@", scriptURL.path] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NotFound) forKey:@"code"];
                        break;
                    }
                    
                    if ([msgType isEqualToString:@"script/get"])
                    {   // GET
                        NSData *scriptData = [_serviceFileManager contentsAtPath:scriptURL.path];
                        if (!scriptData)
                        {
                            [replyObject setObject:[NSString stringWithFormat:@"internal server error: fail to read script file at %@", scriptURL.path] forKey:@"error"];
                            [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                            break;
                        }
                        
                        [replyObject setObject:[scriptData base64EncodedStringWithOptions:kNilOptions] forKey:@"body"];
                    }
                    else
                    {   // DELETE
                        NSError *err = nil;
                        BOOL removed = [_serviceFileManager removeItemAtURL:scriptURL error:&err];
                        if (!removed)
                        {
                            [replyObject setObject:[NSString stringWithFormat:@"internal server error: %@", [err localizedDescription]] forKey:@"error"];
                            [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                            break;
                        }
                        
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
                    }
                }
                else
                {   // PUT
                    NSString *dataString = [msgBody objectForKey:@"data"];
                    if (![dataString isKindOfClass:[NSString class]])
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"data"] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                        break;
                    }
                    
                    NSData *scriptData = [[NSData alloc] initWithBase64EncodedString:dataString options:kNilOptions];
                    if (![scriptData isKindOfClass:[NSData class]])
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"data"] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                        break;
                    }
                    
                    BOOL created = [_serviceFileManager createFileAtPath:[scriptURL path]
                                                                contents:scriptData
                                                              attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }];
                    if (!created)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"internal server error: fail to write script file at %@", scriptURL.path] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                        break;
                    }
                    
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
                }
            } while (NO);
        }
        else if (([msgType isEqualToString:@"system/log/get"] && [msgBody isKindOfClass:[NSDictionary class]]) || [msgType isEqualToString:@"system/log/delete"])
        {
            BOOL isDelete = [msgType isEqualToString:@"system/log/delete"];
            
            if (isDelete)
            {   // DELETE
                do {
                    if ([_serviceFileManager fileExistsAtPath:@LOG_SYS])
                    {
                        NSError *err = nil;
                        BOOL removed = [_serviceFileManager removeItemAtPath:@LOG_SYS error:&err];
                        if (!removed)
                        {
                            [replyObject setObject:[NSString stringWithFormat:@"internal server error: %@", [err localizedDescription]] forKey:@"error"];
                            [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                            break;
                        }
                    }
                    
                    BOOL created = [_serviceFileManager createFileAtPath:@LOG_SYS
                                                                contents:[NSData data]
                                                              attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                    if (!created)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"internal server error: fail to write empty log file at %@", @LOG_SYS] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                        break;
                    }
                    
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
                } while (NO);
            }
            else
            {   // GET
                do {
                    NSInteger lastN = [[msgBody objectForKey:@"last"] integerValue];
                    if (lastN == 0)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"last"] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                        break;
                    }
                    
                    lastN += 1;
                    
                    NSInteger foundN = 0;
                    NSData *sepData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
                    
                    NSFileHandle *sysLogHandle = [NSFileHandle fileHandleForReadingAtPath:@LOG_SYS];
                    unsigned long long offset = [sysLogHandle seekToEndOfFile];
                    unsigned long long endOffset = offset;
                    NSRange finalRange = NSMakeRange(NSNotFound, endOffset);
                    
                    NSData *blockData = nil;
                    while (offset > 0)
                    {
                        @autoreleasepool
                        {
                            if (offset >= BUFSIZ)
                            {
                                [sysLogHandle seekToFileOffset:(offset - BUFSIZ)];
                                blockData = [sysLogHandle readDataOfLength:BUFSIZ];
                                offset -= BUFSIZ;
                            }
                            else
                            {
                                [sysLogHandle seekToFileOffset:0];
                                blockData = [sysLogHandle readDataOfLength:offset];
                                offset = 0;
                            }
                            
                            NSRange sepRange = NSMakeRange(0, blockData.length);
                            while (YES)
                            {
                                NSRange sepFoundRange = [blockData rangeOfData:sepData options:NSDataSearchBackwards range:sepRange];
                                if (sepFoundRange.location == NSNotFound)
                                    break;
                                
                                sepRange.length = sepFoundRange.location;
                                foundN += 1;
                                
                                if (foundN == lastN)
                                {
                                    finalRange.location = offset + sepFoundRange.location + sepFoundRange.length;
                                    break;
                                }
                            }
                            
                            if (finalRange.location != NSNotFound)
                                break;
                        }
                    }
                    
                    if (finalRange.location == NSNotFound)
                        finalRange.location = 0;
                    
                    [sysLogHandle seekToFileOffset:finalRange.location];
                    NSData *logData = [sysLogHandle readDataOfLength:finalRange.length];
                    
                    [sysLogHandle closeFile];
                    
                    if (!logData.length)
                    {
                        [replyObject setObject:@"" forKey:@"body"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
                        break;
                    }
                    
                    NSString *logText = [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding];
                    if (!logText)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"internal server error: fail to decode log file at %@", @LOG_SYS] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                        break;
                    }
                    
                    [replyObject setObject:logText forKey:@"body"];
                } while (NO);
            }
        }
        else if ([msgType isEqualToString:@"system/reboot"] || [msgType isEqualToString:@"system/respring"])
        {
            do {
                int code;
                if ([msgType isEqualToString:@"system/reboot"])
                {
                    code = ios_system("reboot");
                }
                else
                {
                    code = ios_system("killall -9 SpringBoard backboardd");
                }
                
                if (code)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"internal server error: program exited with code %d", code] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                    break;
                }
                
                [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
            } while (NO);
        }
        else if ([msgType isEqualToString:@"screen/snapshot"] && [msgBody isKindOfClass:[NSDictionary class]])
        {
            do {
                NSString *format;
                if (msgBody[@"format"])
                {
                    format = [([msgBody[@"format"] isKindOfClass:[NSString class]] ? msgBody[@"format"] : @"png") lowercaseString];
                }
                else
                {
                    format = [([msgBody[@"ext"] isKindOfClass:[NSString class]] ? msgBody[@"ext"] : @"png") lowercaseString];
                }
                if ([format isEqualToString:@"jpg"])
                    format = @"jpeg";
                
                CGFloat compressVal = MIN(MAX([msgBody[@"compress"] isKindOfClass:[NSNumber class]] || [msgBody[@"compress"] isKindOfClass:[NSString class]] ? [msgBody[@"compress"] doubleValue] : 1.0, 0.1), 1.0);
                
                CGFloat zoomVal;
                if (msgBody[@"scale"])
                {
                    zoomVal = MIN(MAX([msgBody[@"scale"] isKindOfClass:[NSNumber class]] || [msgBody[@"scale"] isKindOfClass:[NSString class]] ? [msgBody[@"scale"] doubleValue] : 100, 10), 300) / 1e2;
                }
                else
                {
                    zoomVal = MIN(MAX([msgBody[@"zoom"] isKindOfClass:[NSNumber class]] || [msgBody[@"zoom"] isKindOfClass:[NSString class]] ? [msgBody[@"zoom"] doubleValue] : 1.0, 0.1), 3.0);
                }
                
                
                uint8_t orientVal = MIN(MAX([msgBody[@"orient"] isKindOfClass:[NSNumber class]] || [msgBody[@"orient"] isKindOfClass:[NSString class]] ? (uint8_t)[msgBody[@"orient"] intValue] : 0, 0), 3);
                
                NSNumber *left = msgBody[@"ltx"] ?: msgBody[@"left"];
                NSNumber *top = msgBody[@"lty"] ?: msgBody[@"top"];
                NSNumber *right = msgBody[@"rbx"] ?: msgBody[@"right"];
                NSNumber *bottom = msgBody[@"rby"] ?: msgBody[@"bottom"];
                
                CGRect cropRegion = CGRectNull;
                if (
                    ([left isKindOfClass:[NSNumber class]] ||
                     [left isKindOfClass:[NSString class]]) &&
                    ([top isKindOfClass:[NSNumber class]] ||
                     [top isKindOfClass:[NSString class]]) &&
                    ([right isKindOfClass:[NSNumber class]] ||
                     [right isKindOfClass:[NSString class]]) &&
                    ([bottom isKindOfClass:[NSNumber class]] ||
                     [bottom isKindOfClass:[NSString class]])
                    )
                {
                    CGFloat leftVal = [left doubleValue];
                    CGFloat topVal = [top doubleValue];
                    CGFloat rightVal = [right doubleValue];
                    CGFloat bottomVal = [bottom doubleValue];
                    
                    if (rightVal <= leftVal || bottomVal <= topVal)
                    {
                        [replyObject setObject:@"invalid crop region" forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                        break;
                    }
                    
                    cropRegion = CGRectMake(leftVal, topVal, rightVal - leftVal, bottomVal - topVal);
                }
                
                [[ScreenCapture sharedCapture] updateDisplay];
                JSTPixelImage *pixelImage = [[ScreenCapture sharedCapture] pixelImage];
                
                // perform rotate with pixel image
                [pixelImage setOrientation:orientVal];
                
                if (!CGRectIsNull(cropRegion))
                {   // perform crop with pixel image
                    pixelImage = [pixelImage crop:cropRegion];
                }
                
                if (fabs(1.0 - zoomVal) > 1e-3)
                {   // resize image with OpenCV
                    CGSize zoomedSize = CGSizeMake(pixelImage.orientedSize.width * zoomVal, pixelImage.orientedSize.height * zoomVal);
                    pixelImage = [ScreenCaptureOpenCVWrapper resizeImage:pixelImage toSize:zoomedSize];
                }
                
                NSData *imageData = nil;
                NSString *contentType = nil;
                if ([format isEqualToString:@"jpeg"] || fabs(1.0 - compressVal) > 1e-3) {
                    imageData = [pixelImage jpegRepresentationWithCompressionQuality:compressVal];
                    contentType = @"image/jpeg";
                } else {
                    imageData = [pixelImage pngRepresentation];
                    contentType = @"image/png";
                }
                
                [replyObject setObject:imageData forKey:@"body"];
                [replyObject setObject:contentType forKey:@"contentType"];
            } while (NO);
        }
        else if (([msgType isEqualToString:@"file/list"] || [msgType isEqualToString:@"file/get"]) && [msgBody isKindOfClass:[NSDictionary class]])
        {
            do {
                BOOL shouldList = [msgType isEqualToString:@"file/list"];
                NSString *fileName = [msgBody objectForKey:@"path"];
                
                if ([fileName hasPrefix:@"/private/var/"])
                    fileName = [fileName substringFromIndex:8];
                if ([fileName hasPrefix:@MEDIA_ROOT])
                    fileName = [fileName substringFromIndex:sizeof(MEDIA_ROOT)];
                
                fileName = strip_unsafe_components(fileName);
                
                NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
                NSURL *fileURL;
                if (fileName.length)
                {
                    fileURL = [NSURL fileURLWithPath:fileName relativeToURL:rootURL];
                }
                else
                {
                    fileURL = rootURL;
                }
                
                NSString *filePath = [fileURL path];
                
                BOOL isDir = NO;
                BOOL exists = [_serviceFileManager fileExistsAtPath:filePath isDirectory:&isDir];
                
                if (!exists)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"not found: %@", filePath] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NotFound) forKey:@"code"];
                    break;
                }
                
                if (shouldList && !isDir)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"not a directory: %@", filePath] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_Forbidden) forKey:@"code"];
                    break;
                }
                
                if (!shouldList && isDir)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"not a file: %@", filePath] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_Forbidden) forKey:@"code"];
                    break;
                }
                
                NSError *err = nil;
                if (shouldList)
                {
                    NSArray <NSString *> *itemList = [_serviceFileManager contentsOfDirectoryAtPath:filePath error:&err];
                    if (!itemList)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"internal server error: %@", [err localizedDescription]] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                        break;
                    }
                    
                    NSMutableArray <NSDictionary *> *mItemList = [NSMutableArray arrayWithCapacity:itemList.count];
                    for (NSString *itemName in itemList) {
                        NSString *itemPath = [filePath stringByAppendingPathComponent:itemName];
                        exists = [_serviceFileManager fileExistsAtPath:itemPath isDirectory:&isDir];
                        [mItemList addObject:@{
                            @"name": itemName,
                            @"type": isDir ? @"dir" : @"file",
                        }];
                    }
                    
                    [replyObject setObject:mItemList forKey:@"body"];
                }
                else
                {
                    BOOL reachable = [fileURL checkResourceIsReachableAndReturnError:&err];
                    if (!reachable)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"not accessible: %@", filePath] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NotFound) forKey:@"code"];
                        break;
                    }
                    
                    NSData *fileData = [_serviceFileManager contentsAtPath:filePath];
                    if (!fileData)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"internal server error: fail to read script file at %@", filePath] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                        break;
                    }
                    
                    [replyObject setObject:[fileData base64EncodedStringWithOptions:kNilOptions] forKey:@"body"];
                }
            } while (NO);
        }
        else if ([msgType isEqualToString:@"file/put"] && [msgBody isKindOfClass:[NSDictionary class]])
        {
            NSString *fileName = [msgBody objectForKey:@"path"];
            
            if ([fileName hasPrefix:@"/private/var/"])
                fileName = [fileName substringFromIndex:8];
            if ([fileName hasPrefix:@MEDIA_ROOT])
                fileName = [fileName substringFromIndex:sizeof(MEDIA_ROOT)];
            
            fileName = strip_unsafe_components(fileName);
            
            NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
            NSURL *fileURL;
            if (fileName.length)
            {
                fileURL = [NSURL fileURLWithPath:fileName relativeToURL:rootURL];
            }
            else
            {
                fileURL = rootURL;
            }
            
            NSString *filePath = [fileURL path];
            BOOL createDirectory = [[msgBody objectForKey:@"directory"] boolValue];
            if (createDirectory)
            {
                do {
                    NSError *err = nil;
                    BOOL created = [_serviceFileManager createDirectoryAtPath:filePath
                                                  withIntermediateDirectories:YES
                                                                   attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }
                                                                        error:&err];
                    if (!created)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"internal server error: %@", [err localizedDescription]] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                        break;
                    }
                    
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
                } while (NO);
            }
            else
            {
                do {
                    NSString *dataString = [msgBody objectForKey:@"data"];
                    if (![dataString isKindOfClass:[NSString class]])
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"data"] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                        break;
                    }
                    
                    NSData *fileData = [[NSData alloc] initWithBase64EncodedString:dataString options:kNilOptions];
                    if (![fileData isKindOfClass:[NSData class]])
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"bad parameter: %@", @"data"] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_BadRequest) forKey:@"code"];
                        break;
                    }
                    
                    BOOL created = [_serviceFileManager createFileAtPath:filePath
                                                                contents:fileData
                                                              attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                    if (!created)
                    {
                        [replyObject setObject:[NSString stringWithFormat:@"internal server error: fail to write script file at %@", filePath] forKey:@"error"];
                        [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                        break;
                    }
                    
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
                } while (NO);
            }
        }
        else if ([msgType isEqualToString:@"file/delete"] && [msgBody isKindOfClass:[NSDictionary class]])
        {
            NSString *fileName = [msgBody objectForKey:@"path"];
            
            if ([fileName hasPrefix:@"/private/var/"])
                fileName = [fileName substringFromIndex:8];
            if ([fileName hasPrefix:@MEDIA_ROOT])
                fileName = [fileName substringFromIndex:sizeof(MEDIA_ROOT)];
            
            fileName = strip_unsafe_components(fileName);
            
            NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_ROOT];
            NSURL *fileURL;
            if (fileName.length)
            {
                fileURL = [NSURL fileURLWithPath:fileName relativeToURL:rootURL];
            }
            else
            {
                fileURL = rootURL;
            }
            
            NSString *filePath = [fileURL path];
            
            do {
                BOOL isDir = NO;
                BOOL exists = [_serviceFileManager fileExistsAtPath:filePath isDirectory:&isDir];
                if (!exists)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"not found: %@", filePath] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NotFound) forKey:@"code"];
                    break;
                }
                
                NSError *err = nil;
                BOOL removed = [_serviceFileManager removeItemAtPath:filePath error:&err];
                if (!removed)
                {
                    [replyObject setObject:[NSString stringWithFormat:@"internal server error: %@", [err localizedDescription]] forKey:@"error"];
                    [replyObject setObject:@(kGCDWebServerHTTPStatusCode_InternalServerError) forKey:@"code"];
                    break;
                }
                
                [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NoContent) forKey:@"code"];
            } while (NO);
        }
        else
        {
            [replyObject setObject:[NSString stringWithFormat:@"not implemented: %@", msgType] forKey:@"error"];
            [replyObject setObject:@(kGCDWebServerHTTPStatusCode_NotImplemented) forKey:@"code"];
        }
        
        return replyObject;
    }
}

- (void)webSocketDidOpen:(PSWebSocket *)webSocket {
    dispatch_async(_serviceQueue, ^{
        CHLog(@"The websocket %@ handshake completed and is now open!", webSocket);
    });
}

@end

static
int __elf_cloud_client_main(int argc, const char *argv[], const char *envp[])
{
    @autoreleasepool {
        
        NSString *wsString = nil;
        if (argc > 2)
        {
            fprintf(stderr, "usage: %s [ws://...]\n", argv[0]);
            return EXIT_FAILURE;
        }
        else if (argc < 2)
        {
            NSDictionary *cloudConf = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.cloud"];
            if ([cloudConf isKindOfClass:[NSDictionary class]])
            {
                BOOL enabled = NO;
                if ([cloudConf[@"enabled"] isKindOfClass:[NSNumber class]])
                {
                    enabled = [cloudConf[@"enabled"] boolValue];
                }
                else if ([cloudConf[@"enable"] isKindOfClass:[NSNumber class]])
                {
                    enabled = [cloudConf[@"enable"] boolValue];
                }
                if (enabled)
                {
                    if ([cloudConf[@"address"] isKindOfClass:[NSString class]])
                    {
                        wsString = cloudConf[@"address"];
                    }
                }
                else
                {
                    fprintf(stderr, "elfclient: disabled\n");
                    return EXIT_SUCCESS;
                }
            }
        }
        else
        {
            wsString = [NSString stringWithUTF8String:argv[1]];
        }
        
        if (![wsString hasPrefix:@"ws://"])
        {
            fprintf(stderr, "usage: %s [ws://...]\n", argv[0]);
            return EXIT_FAILURE;
        }
        
        NSURL *wsURL = [NSURL URLWithString:wsString];
        NSMutableURLRequest *wsRequest = [NSMutableURLRequest requestWithURL:wsURL];
        [wsRequest setTimeoutInterval:30.0];
        
        static ELFCloudClient *client = [[ELFCloudClient alloc] init];
        static PSWebSocket *clientSocket = [PSWebSocket clientSocketWithRequest:wsRequest];
        
        [clientSocket setDelegate:client];
        [clientSocket open];
        
        CFRunLoopRun();
        return EXIT_SUCCESS;
    }
}


#pragma mark -

OBJC_EXTERN
void plugin_i_love_xxtouch(void);
void plugin_i_love_xxtouch(void) {}


#pragma mark -

int main(int argc, const char *argv[], const char *envp[])
{
    // Increase memory usage.
    int rc;
    
    memorystatus_priority_properties_t props = {0, JETSAM_PRIORITY_CRITICAL};
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, getpid(), 0, &props, sizeof(props));
    if (rc < 0) { perror ("memorystatus_control"); exit(rc);}
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, getpid(), -1, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc);}
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED, getpid(), 0, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc);}
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE, getpid(), 0, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }

	@autoreleasepool {
        _serviceQueue = dispatch_queue_create("ch.xxtou.queue.webserv.service", DISPATCH_QUEUE_SERIAL);
        _serviceFileManager = [[NSFileManager alloc] init];
        
        ensure_base_structure();
        [[ProcQueue sharedInstance] remoteDefaultsChanged];
        
        if (strcmp(argv[0], "elfclient") == 0 ||
            strcmp(argv[0] + strlen(argv[0]) - (sizeof("/elfclient") - 1), "/elfclient") == 0)
        {
            return __elf_cloud_client_main(argc, argv, envp);
        }
        
        static GCDWebServer *webServer;
        webServer = [[GCDWebServer alloc] init];
        
        {
            static GCDWebServerAsyncProcessBlock defaultCallback;
            defaultCallback = ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
                if (!is_localhost(request))
                {
                    completionBlock(resp_remote_access_forbidden());
                    return;
                }
                @autoreleasepool {
                    NSDictionary *returnObj = @{ @"msg": @"bad endpoint" };
                    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:returnObj
                                                                       options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                                                         error:nil];
                    GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithData:jsonData contentType:@"application/json"];
                    [resp setStatusCode:404];
                    completionBlock(resp);
                }
            };
            
            static GCDWebServerProcessBlock optionsCallback;
            optionsCallback = ^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
                @autoreleasepool {
                    GCDWebServerResponse *resp = [GCDWebServerResponse responseWithStatusCode:200];
                    [resp setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
                    [resp setValue:@"GET, POST, OPTIONS" forAdditionalHeader:@"Access-Control-Allow-Methods"];
                    [resp setValue:@"GET, POST, OPTIONS" forAdditionalHeader:@"Allow"];
                    [resp setValue:@"DNT, X-Mx-ReqToken, Keep-Alive, User-Agent, X-Requested-With, If-Modified-Since, Cache-Control, Content-Type, Authorization" forAdditionalHeader:@"Access-Control-Allow-Headers"];
                    return resp;
                }
            };
            
            [webServer addDefaultHandlerForMethod:@"OPTIONS"
                                     requestClass:[GCDWebServerRequest class]
                                     processBlock:optionsCallback];
            [webServer addDefaultHandlerForMethod:@"GET"
                                     requestClass:[GCDWebServerRequest class]
                                asyncProcessBlock:defaultCallback];
            [webServer addDefaultHandlerForMethod:@"POST"
                                     requestClass:[GCDWebServerRequest class]
                                asyncProcessBlock:defaultCallback];
            [webServer addDefaultHandlerForMethod:@"PUT"
                                     requestClass:[GCDWebServerRequest class]
                                asyncProcessBlock:defaultCallback];
            [webServer addDefaultHandlerForMethod:@"DELETE"
                                     requestClass:[GCDWebServerRequest class]
                                asyncProcessBlock:defaultCallback];
        }
        
        {
            register_static_website_handlers(webServer);
            register_deprecated_handlers(webServer);
            register_openapi_v1_handlers(webServer);
            register_debug_window_handlers(webServer);
            register_alert_helper_handlers(webServer);
            register_tamper_monkey_handlers(webServer);
            register_remote_access_handlers(webServer);
            register_file_manager_handlers(webServer);
            register_device_configurator_handlers(webServer);
            register_container_manager_handlers(webServer);
            register_screen_capture_handlers(webServer);
            register_proc_queue_handlers(webServer);
            register_user_defaults_handlers(webServer);
            register_auth_manager_handlers(webServer);
            register_supervisor_handlers(webServer);
            register_command_spawn_handler(webServer);
            register_restart_handler(webServer);
            register_touchelf_handlers(webServer);
        }
        
        /* -------------- */
        /* OpenAPI Server */
        BOOL started;
        NSString *deviceName = CFBridgingRelease(MGCopyAnswer(kMGUserAssignedDeviceName, nil));
        NSString *deviceUDID = CFBridgingRelease(MGCopyAnswer(kMGUniqueDeviceID, nil));
        started = [webServer startWithPort:WEBSERV_PORT
                               bonjourName:[NSString stringWithFormat:@"%@ (%@)", deviceName, deviceUDID]];
        if (!started) {
            return EXIT_FAILURE;
        }
        /* -------------- */
        
        /* ------------------------------ */
        /* UDP Broadcast Server (XXTouch) */
        static WSUdpBroadcastServer *broadcastServer;
        broadcastServer = [[WSUdpBroadcastServer alloc] initWithProtocol:WSUdpBroadcastServerProtocolXXTouch];
        register_udp_broadcast_handlers(broadcastServer);
        /* ------------------------------ */
        
        /* --------------------------------------------- */
        /* UDP Broadcast Server (TouchSprite / TouchElf) */
        static WSUdpBroadcastServer *broadcastServerLegacy;
        broadcastServerLegacy = [[WSUdpBroadcastServer alloc] initWithProtocol:WSUdpBroadcastServerProtocolLegacy];
        register_udp_broadcast_handlers_legacy(broadcastServerLegacy);
        /* --------------------------------------------- */
        
        /* ----------------------- */
        /* WebSocket Logging Proxy */
        static WSUdpLoggingServer *loggingServer;
        loggingServer = [[WSUdpLoggingServer alloc] init];
        register_udp_logging_handlers(loggingServer);

        static WSWebSocketLoggingProxy *loggingProxy;
        loggingProxy = [[WSWebSocketLoggingProxy alloc] initWithProvider:loggingServer];
        loggingProxy.host = nil;
        loggingProxy.port = WEBSERV_LOGGING_SERVER_PORT;

        static PSWebSocketServer *logServer;
        logServer = [PSWebSocketServer serverWithHost:loggingProxy.host port:loggingProxy.port];
        logServer.delegate = loggingProxy;
        [logServer start];
        /* ----------------------- */
        
        /* ------------- */
        /* WebDAV Server */
        static GCDWebDAVServer *davServer;
        davServer = [[GCDWebDAVServer alloc] initWithUploadDirectory:@MEDIA_ROOT];
        started = [davServer start];
        if (!started) {
            return EXIT_FAILURE;
        }
        CHLog(@"Visit %@ in your WebDAV client", davServer.serverURL);
        /* ------------- */
        
        CFRunLoopRun();
        return EXIT_SUCCESS;
	}
}
