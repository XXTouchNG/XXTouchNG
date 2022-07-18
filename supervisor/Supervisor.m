//
//  Supervisor.m
//  Supervisor
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "Supervisor.h"
#import "ProcQueue.h"
#import "TFShell.h"
#import "NSTask.h"  // Not documented on iOS in Foundation but still available

#import <rocketbootstrap/rocketbootstrap.h>
#import <notify.h>


@interface Supervisor (Private)

@property (nonatomic, strong) CPDistributedMessagingCenter *messagingCenter;

+ (instancetype)sharedInstanceWithRole:(SupervisorRole)role;
- (instancetype)initWithRole:(SupervisorRole)role;

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSDictionary *)receiveAndReplyMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;

@end


#pragma mark -

@implementation Supervisor {
    SupervisorRole _role;
    dispatch_queue_t _eventQueue;
    NSFileManager *_eventFileManager;
    
    SupervisorState _globalState;
    NSTask *_globalTask;
    NSString *_lastTargetPath;
    NSError *_lastError;
    int _lastExitCode;
    
    NSTimer *_schedulerTimer;
}

@synthesize messagingCenter = _messagingCenter;

+ (instancetype)sharedInstance {
    return [self sharedInstanceWithRole:SupervisorRoleClient];
}

+ (instancetype)sharedInstanceWithRole:(SupervisorRole)role {
    static Supervisor *_server = nil;
    NSAssert(_server == nil || role == _server.role, @"already initialized");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _server = [[Supervisor alloc] initWithRole:role];
    });
    return _server;
}

- (instancetype)initWithRole:(SupervisorRole)role {
    self = [super init];
    if (self) {
        _role = role;
        _eventQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.queue.events", @XPC_INSTANCE_NAME] UTF8String], DISPATCH_QUEUE_SERIAL);
        _eventFileManager = [[NSFileManager alloc] init];
    }
    return self;
}

- (SupervisorRole)role {
    return _role;
}


#pragma mark - Messaging

- (CPDistributedMessagingCenter *)messagingCenter {
    return _messagingCenter;
}

- (void)setMessagingCenter:(CPDistributedMessagingCenter *)messagingCenter {
    _messagingCenter = messagingCenter;
}

- (void)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == SupervisorRoleClient, @"invalid role");
    BOOL sendSucceed = [self.messagingCenter sendMessageName:messageName userInfo:userInfo];
    NSAssert(sendSucceed, @"cannot send message %@, userInfo = %@", messageName, userInfo);
}

- (NSDictionary *)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == SupervisorRoleClient, @"invalid role to send message");
    NSError *sendErr = nil;
    NSDictionary *replyInfo = [self.messagingCenter sendMessageAndReceiveReplyName:messageName userInfo:userInfo error:&sendErr];
    NSAssert(sendErr == nil, @"cannot send message %@, userInfo = %@, error = %@", messageName, userInfo, sendErr);
    return replyInfo;
}

- (void)receiveMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    NSAssert(_role == SupervisorRoleServer, @"invalid role");
    
    @autoreleasepool {
        NSString *selectorName = [userInfo objectForKey:@"selector"];
        SEL selector = NSSelectorFromString(selectorName);
        NSAssert([self respondsToSelector:selector], @"invalid selector");
        
        NSInvocation *forwardInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
        [forwardInvocation setSelector:selector];
        [forwardInvocation setTarget:self];
        
        NSInteger argumentIndex = 2;
        NSArray *arguments = [userInfo objectForKey:@"arguments"];
        for (NSObject *argument in arguments) {
            void *argumentPtr = (__bridge void *)(argument);
            [forwardInvocation setArgument:&argumentPtr atIndex:argumentIndex];
            argumentIndex += 1;
        }
        
        [forwardInvocation invoke];
    }
}

- (NSDictionary *)receiveAndReplyMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
    @autoreleasepool {
        NSAssert(_role == SupervisorRoleServer, @"invalid role to receive message");
        
        NSString *selectorName = [userInfo objectForKey:@"selector"];
        SEL selector = NSSelectorFromString(selectorName);
        NSAssert([self respondsToSelector:selector], @"invalid selector");
        
        NSInvocation *forwardInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
        [forwardInvocation setSelector:selector];
        [forwardInvocation setTarget:self];
        
        NSInteger argumentIndex = 2;
        NSArray *arguments = [userInfo objectForKey:@"arguments"];
        for (NSObject *argument in arguments) {
            void *argumentPtr = (__bridge void *)(argument);
            [forwardInvocation setArgument:&argumentPtr atIndex:argumentIndex];
            argumentIndex += 1;
        }
        
        [forwardInvocation invoke];
        
        NSDictionary * __weak returnVal = nil;
        [forwardInvocation getReturnValue:&returnVal];
        NSDictionary *safeReturnVal = returnVal;
        NSAssert([safeReturnVal isKindOfClass:[NSDictionary class]], @"invalid return value");
        
        return safeReturnVal;
    }
}


#pragma mark - Spawn

- (NSDictionary *)spawnCommand:(NSString *)command
{
    if (_role == SupervisorRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(spawnCommand:)),
                @"arguments": [NSArray arrayWithObjects:command, nil],
            }];
            
            CHDebugLog(@"spawnCommand %@ -> %@", command, replyObject);
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSTask *task = [[NSTask alloc] init];
        
        NSMutableData *stdoutData = [NSMutableData data];
        NSMutableData *stderrData = [NSMutableData data];
        
        [task setCurrentDirectoryPath:@MEDIA_ROOT];
        [task setLaunchPath:@"/bin/sh"];
        [task setArguments:[NSArray arrayWithObjects:@"-c", command, nil]];
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
        
        return @{
            @"status": @(status),
            @"stdout": stdoutString ?: [[NSString alloc] init],
            @"stderr": stderrString ?: [[NSString alloc] init],
        };
    }
}

- (NSDictionary *)spawnCommand:(NSString *)command timeout:(NSNumber *)timeout
{
    if (_role == SupervisorRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(spawnCommand:timeout:)),
                @"arguments": [NSArray arrayWithObjects:command, timeout, nil],
            }];
            
            CHDebugLog(@"spawnCommand %@ timeout %@ -> %@", command, timeout, replyObject);
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        NSTask *task = [[NSTask alloc] init];
        
        NSMutableData *stdoutData = [NSMutableData data];
        NSMutableData *stderrData = [NSMutableData data];
        
        [task setCurrentDirectoryPath:@MEDIA_ROOT];
        [task setLaunchPath:@"/bin/sh"];
        [task setArguments:[NSArray arrayWithObjects:@"-c", command, nil]];
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
        
        NSInvocation *timeoutInvocation = [NSInvocation invocationWithMethodSignature:[NSTask instanceMethodSignatureForSelector:@selector(terminate)]];
        [timeoutInvocation setTarget:task];
        [timeoutInvocation setSelector:@selector(terminate)];
        
        NSTimer *terminateTimer = [NSTimer scheduledTimerWithTimeInterval:[timeout doubleValue]
                                                               invocation:timeoutInvocation
                                                                  repeats:NO];
        
        [task launch];
        [task waitUntilExit];
        
        [terminateTimer invalidate];
        
        int status = [task terminationStatus];
        
        NSString *stdoutString = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding];
        NSString *stderrString = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
        
        return @{
            @"status": @(status),
            @"stdout": stdoutString ?: [[NSString alloc] init],
            @"stderr": stderrString ?: [[NSString alloc] init],
        };
    }
}

- (nullable NSString *)simpleSpawnCommand:(NSString *)command
{
    return [self simpleSpawnCommand:command error:nil];
}

- (nullable NSString *)simpleSpawnCommand:(NSString *)command error:(NSError *__autoreleasing*)error
{
    NSDictionary *replyObject = [self spawnCommand:command];
    NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
    
    int status = [replyObject[@"status"] intValue];
    if (status != 0)
    {
        if (error) {
            *error = [NSError errorWithDomain:@SupervisorErrorDomain code:status userInfo:@{ NSLocalizedDescriptionKey: (replyObject[@"stderr"] ?: @"") }];
        }
        
        return nil;
    }
    
    return replyObject[@"stdout"] ?: @"";
}

- (nullable NSString *)simpleSpawnCommand:(NSString *)command timeout:(NSTimeInterval)timeout
{
    return [self simpleSpawnCommand:command timeout:timeout error:nil];
}

- (nullable NSString *)simpleSpawnCommand:(NSString *)command timeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing*)error
{
    NSDictionary *replyObject = [self spawnCommand:command timeout:@(timeout)];
    NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
    
    int status = [replyObject[@"status"] intValue];
    if (status != 0)
    {
        if (error) {
            *error = [NSError errorWithDomain:@SupervisorErrorDomain code:status userInfo:@{ NSLocalizedDescriptionKey: (replyObject[@"stderr"] ?: @"") }];
        }
        
        return nil;
    }
    
    return replyObject[@"stdout"] ?: @"";
}


#pragma mark - Version

- (NSString *)luaVersion
{
    static NSString *version = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        version = [[self simpleSpawnCommand:@BIN_LAUNCHER " -v"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    });
    return version;
}


#pragma mark - Lua Playground

- (nullable NSString *)      evalString:(NSString *)string
             ignoreEnvironmentVariables:(BOOL)ignore
                                  error:(NSError *__autoreleasing *)error
{
    NSError *strongErr = nil;
    NSString *outputString = nil;
    
    @autoreleasepool {
        NSString *command;
        if (ignore) {
            command = [NSString stringWithFormat:@BIN_LAUNCHER " -E -e '%@'", TFEscapeShellArg(string)];
        } else {
            command = [NSString stringWithFormat:@BIN_LAUNCHER " -e '%@'", TFEscapeShellArg(string)];
        }
        
        outputString = [[self simpleSpawnCommand:command error:&strongErr] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    if (!outputString) {
        if (error) {
            if (*error == nil) {
                *error = strongErr;
            }
        }
        return nil;
    }
    
    return outputString;
}

- (nullable NSString *)      evalData:(NSData *)data
           ignoreEnvironmentVariables:(BOOL)ignore
                                error:(NSError *__autoreleasing *)error
{
    NSAssert(getuid() == 0, @"wrong privilege");
    
    NSURL *tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
                                                           inDomain:NSUserDomainMask
                                                  appropriateForURL:[NSURL fileURLWithPath:@"/private/var"]
                                                             create:YES
                                                              error:error];
    
    if (!tmpURL) {
        return nil;
    }
    
    NSString *inputPath = [[tmpURL path] stringByAppendingPathComponent:@"data"];
    BOOL writeSucceed = [data writeToFile:inputPath
                                  options:NSDataWritingAtomic
                                    error:error];
    
    if (!writeSucceed) {
        return nil;
    }
    
    return [self evalWithContentsOfFile:inputPath
             ignoreEnvironmentVariables:ignore
                                  error:error];
}

- (nullable NSString *)evalWithContentsOfFile:(NSString *)path
                   ignoreEnvironmentVariables:(BOOL)ignore
                                        error:(NSError *__autoreleasing *)error
{
    NSError *strongErr = nil;
    NSString *outputString = nil;
    
    @autoreleasepool {
        NSString *command;
        if (ignore) {
            command = [NSString stringWithFormat:@BIN_LAUNCHER " -E '%@'", TFEscapeShellArg(path)];
        } else {
            command = [NSString stringWithFormat:@BIN_LAUNCHER " '%@'", TFEscapeShellArg(path)];
        }
        
        outputString = [[self simpleSpawnCommand:command error:&strongErr] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    if (!outputString) {
        if (error) {
            if (*error == nil) {
                *error = strongErr;
            }
        }
        return nil;
    }
    
    return outputString;
}


#pragma mark - Lua Compiler

- (nullable NSString *)checkLuaSyntaxAtPath:(NSString *)path
{
    @autoreleasepool {
        NSAssert([path isAbsolutePath], @"absoulte path required");
        
        NSError *err = nil;
        NSString *stdOutput = [self simpleSpawnCommand:[NSString stringWithFormat:@BIN_COMPILER " -p '%@'", TFEscapeShellArg(path)] error:&err];
        if (!stdOutput) {
            NSString *plainErrorString = [[err localizedDescription] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([plainErrorString hasPrefix:@BIN_COMPILER])
                plainErrorString = [plainErrorString substringFromIndex:sizeof(BIN_COMPILER)];
            plainErrorString = [plainErrorString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([plainErrorString hasPrefix:@MEDIA_ROOT]) {
                plainErrorString = [plainErrorString substringFromIndex:sizeof(MEDIA_ROOT)];
                plainErrorString = [@"./" stringByAppendingString:plainErrorString];
            }
            return plainErrorString;
        }
        
        return [stdOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
}

- (nullable NSString *)checkLuaSyntaxWithData:(NSData *)data
{
    NSAssert(getuid() == 0, @"wrong privilege");
    
    @autoreleasepool {
        NSError *error = nil;
        NSURL *tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
                                                               inDomain:NSUserDomainMask
                                                      appropriateForURL:[NSURL fileURLWithPath:@"/private/var"]
                                                                 create:YES
                                                                  error:&error];
        
        if (!tmpURL) {
            CHDebugLogSource(@"%@", error);
            return nil;
        }
        
        NSString *inputPath = [[tmpURL path] stringByAppendingPathComponent:@"data"];
        BOOL writeSucceed = [data writeToFile:inputPath
                                      options:NSDataWritingAtomic
                                        error:&error];
        
        if (!writeSucceed) {
            CHDebugLogSource(@"%@", error);
            return nil;
        }
        
        return [self checkLuaSyntaxAtPath:inputPath];
    }
}

- (BOOL)compileLuaAtPath:(NSString *)path
                  toPath:(NSString *)outputPath
   stripDebugInformation:(BOOL)strip
                   error:(NSError *__autoreleasing *)error
{
    NSError *strongErr = nil;
    NSString *stdOutput = nil;
    
    @autoreleasepool {
        NSAssert([path isAbsolutePath], @"absoulte path required");
        NSAssert([outputPath isAbsolutePath], @"absoulte output path required");
        
        NSString *command;
        if (strip) {
            command = [NSString stringWithFormat:@BIN_COMPILER " -s -o '%@' '%@'", TFEscapeShellArg(outputPath), TFEscapeShellArg(path)];
        } else {
            command = [NSString stringWithFormat:@BIN_COMPILER " -o '%@' '%@'", TFEscapeShellArg(outputPath), TFEscapeShellArg(path)];
        }
        
        stdOutput = [self simpleSpawnCommand:command error:&strongErr];
    }
    
    if (!stdOutput) {
        if (error) {
            if (*error == nil) {
                *error = strongErr;
            }
        }
        return NO;
    }
    
    return YES;
}

- (nullable NSData *)compileLuaAtPath:(NSString *)path
                stripDebugInformation:(BOOL)strip
                                error:(NSError *__autoreleasing *)error
{
    NSAssert(getuid() == 0, @"wrong privilege");
    
    NSError *strongErr = nil;
    NSData *outputData = nil;
    
    @autoreleasepool {
        NSURL *tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
                                                               inDomain:NSUserDomainMask
                                                      appropriateForURL:[NSURL fileURLWithPath:@"/private/var"]
                                                                 create:YES
                                                                  error:&strongErr];
        
        if (tmpURL) {
            NSString *outputPath = [[tmpURL path] stringByAppendingPathComponent:[path lastPathComponent]];
            
            NSAssert([path isAbsolutePath], @"absoulte path required");
            NSAssert([outputPath isAbsolutePath], @"absoulte output path required");
            
            NSString *command;
            if (strip) {
                command = [NSString stringWithFormat:@BIN_COMPILER " -s -o '%@' '%@'", TFEscapeShellArg(outputPath), TFEscapeShellArg(path)];
            } else {
                command = [NSString stringWithFormat:@BIN_COMPILER " -o '%@' '%@'", TFEscapeShellArg(outputPath), TFEscapeShellArg(path)];
            }
            
            NSString *stdOutput = [self simpleSpawnCommand:command error:&strongErr];
            if (stdOutput) {
                outputData = [NSData dataWithContentsOfFile:outputPath
                                                    options:NSDataReadingUncached
                                                      error:&strongErr];
            }
        }
    }
    
    if (!outputData) {
        if (error) {
            if (*error == nil) {
                *error = strongErr;
            }
        }
        return nil;
    }
    
    return outputData;
}

- (nullable NSData *)compileLuaWithData:(NSData *)data
                  stripDebugInformation:(BOOL)strip
                                  error:(NSError *__autoreleasing *)error
{
    NSAssert(getuid() == 0, @"wrong privilege");
    
    NSURL *tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
                                                           inDomain:NSUserDomainMask
                                                  appropriateForURL:[NSURL fileURLWithPath:@"/private/var"]
                                                             create:YES
                                                              error:error];
    
    if (!tmpURL) {
        return nil;
    }
    
    NSString *inputPath = [[tmpURL path] stringByAppendingPathComponent:@"data"];
    BOOL writeSucceed = [data writeToFile:inputPath
                                  options:NSDataWritingAtomic
                                    error:error];
    
    if (!writeSucceed) {
        return nil;
    }
    
    return [self compileLuaAtPath:inputPath stripDebugInformation:strip error:error];
}

- (nullable NSString *)revealByteCodeOfLuaAtPath:(NSString *)path
                                           error:(NSError *__autoreleasing *)error
{
    NSError *strongErr = nil;
    NSString *outputString = nil;
    
    @autoreleasepool {
        NSAssert([path isAbsolutePath], @"absoulte path required");
        outputString = [self simpleSpawnCommand:[NSString stringWithFormat:@BIN_COMPILER " -l '%@'", TFEscapeShellArg(path)] error:&strongErr];
    }
    
    if (!outputString) {
        if (error) {
            if (*error == nil) {
                *error = strongErr;
            }
        }
        return nil;
    }
    
    return outputString;
}

- (nullable NSString *)revealByteCodeOfLuaWithData:(NSData *)data
                                             error:(NSError *__autoreleasing *)error
{
    NSAssert(getuid() == 0, @"wrong privilege");
    
    NSURL *tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
                                                           inDomain:NSUserDomainMask
                                                  appropriateForURL:[NSURL fileURLWithPath:@"/private/var"]
                                                             create:YES
                                                              error:error];
    
    if (!tmpURL) {
        return nil;
    }
    
    NSString *inputPath = [[tmpURL path] stringByAppendingPathComponent:@"data"];
    BOOL writeSucceed = [data writeToFile:inputPath
                                  options:NSDataWritingAtomic
                                    error:error];
    
    if (!writeSucceed) {
        return nil;
    }
    
    return [self revealByteCodeOfLuaAtPath:inputPath error:error];
}

- (SupervisorState)globalState
{
    return [[self _globalState][@"reply"] unsignedIntegerValue];
}

- (NSDictionary *)_globalState
{
    if (_role == SupervisorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_globalState)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"globalState -> %@", replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]] && [replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    __block SupervisorState state;
    dispatch_sync(_eventQueue, ^{
        state = _globalState;
    });
    return @{ @"reply": @(state) };
}

- (BOOL)isIdle
{
    return [self globalState] == SupervisorStateIdle;
}

- (BOOL)isRunning
{
    return [self globalState] == SupervisorStateRunning;
}

- (BOOL)isRecording
{
    return [self globalState] == SupervisorStateRecording;
}

- (BOOL)isSuspended
{
    return [self globalState] == SupervisorStateSuspend;
}

- (BOOL)isBusy
{
    return ![self isIdle];
}

- (NSString *)lastTargetPath
{
    return [self _lastTargetPath][@"reply"];
}

- (NSDictionary *)_lastTargetPath
{
    if (_role == SupervisorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_lastTargetPath)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"lastTargetPath -> %@", replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]] && [replyObject[@"reply"] isKindOfClass:[NSString class]], @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    __block NSString *targetPath = nil;
    dispatch_sync(_eventQueue, ^{
        targetPath = _lastTargetPath;
    });
    return @{ @"reply": (targetPath ?: @"") };
}

- (int)lastExitCode
{
    return [[self _lastExitCode][@"reply"] intValue];
}

- (NSDictionary *)_lastExitCode
{
    if (_role == SupervisorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_lastExitCode)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"lastExitCode -> %@", replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]] && [replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    __block int exitCode;
    dispatch_sync(_eventQueue, ^{
        exitCode = _lastExitCode;
    });
    return @{ @"reply": @(exitCode) };
}

- (nullable NSError *)lastError
{
    NSDictionary *replyObj = [self _lastError][@"reply"];
    if (![replyObj isKindOfClass:[NSDictionary class]] || [replyObj count] == 0) {
        return nil;
    }
    return [NSError errorWithDomain:@SupervisorErrorDomain code:[replyObj[@"code"] integerValue] userInfo:replyObj];
}

- (NSDictionary *)_lastError
{
    if (_role == SupervisorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_lastError)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"lastError -> %@", replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]], @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    __block NSDictionary *errorDict = nil;
    dispatch_sync(_eventQueue, ^{
        errorDict = @{
            @"code": @([_lastError code]),
            NSLocalizedDescriptionKey: [_lastError localizedDescription] ?: @"",
            NSLocalizedFailureReasonErrorKey: [_lastError localizedFailureReason] ?: @"",
        };
    });
    return @{ @"reply": errorDict ?: @{ } };
}

- (pid_t)globalProcessIdentifier
{
    return [[self _globalProcessIdentifier][@"reply"] intValue];
}

- (NSDictionary *)_globalProcessIdentifier
{
    if (_role == SupervisorRoleClient) {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_globalProcessIdentifier)),
                @"arguments": [NSArray array],
            }];
            
            CHDebugLog(@"globalProcessIdentifier -> %@", replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]] && [replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    __block pid_t processIdentifier;
    dispatch_sync(_eventQueue, ^{
        processIdentifier = _globalTask.processIdentifier;
    });
    return @{ @"reply": @(processIdentifier) };
}

- (pid_t)sendSignalToGlobalProcess:(int)signal
{
    return [[self _sendSignalToGlobalProcess:@(signal)][@"reply"] intValue];
}

- (NSDictionary *)_sendSignalToGlobalProcess:(NSNumber *)signal
{
    if (_role == SupervisorRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_sendSignalToGlobalProcess:)),
                @"arguments": [NSArray arrayWithObjects:signal, nil],
            }];
            
            CHDebugLog(@"sendSignalToGlobalProcess %@ -> %@", signal, replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]] && [replyObject[@"reply"] isKindOfClass:[NSNumber class]], @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    __block pid_t processIdentifier;
    dispatch_sync(_eventQueue, ^{
        int cSignal = [signal intValue];
        if (_globalTask.processIdentifier != 0)
        {
            CHLog(@"Will send signal %d to global script task %@", cSignal, _globalTask);
            int killStatus = kill(_globalTask.processIdentifier, cSignal);
            if (killStatus == 0)
            {
                if (_globalState == SupervisorStateRunning && cSignal == SIGSTOP)
                {
                    _globalState = SupervisorStateSuspend;
                }
                else if (_globalState == SupervisorStateSuspend && cSignal == SIGCONT)
                {
                    _globalState = SupervisorStateRunning;
                }
            }
        }
        processIdentifier = _globalTask.processIdentifier;
    });
    return @{ @"reply": @(processIdentifier) };
}

- (void)sendSignal:(int)signal toProcessWithIdentifier:(pid_t)processIdentifier
{
    [self _sendSignal:@(signal) toProcessWithIdentifier:@(processIdentifier)];
}

- (void)_sendSignal:(NSNumber *)signal toProcessWithIdentifier:(NSNumber *)processIdentifier
{
    if (_role == SupervisorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_sendSignal:toProcessWithIdentifier:)),
                @"arguments": [NSArray arrayWithObjects:signal, processIdentifier, nil],
            }];
            return;
        }
    }
    
    dispatch_sync(_eventQueue, ^{
        pid_t processToKill = [processIdentifier intValue];
        if (processToKill != 0) {
            kill(processToKill, [signal intValue]);
        }
    });
}

- (void)killGlobalProcess
{
    [self sendSignalToGlobalProcess:SIGKILL];
}

- (pid_t)terminateGlobalProcess
{
    return [self sendSignalToGlobalProcess:SIGTERM];
}

- (pid_t)interruptGlobalProcess
{
    return [self sendSignalToGlobalProcess:SIGINT];
}

- (pid_t)stopGlobalProcess
{
    return [self sendSignalToGlobalProcess:SIGSTOP];
}

- (pid_t)continueGlobalProcess
{
    return [self sendSignalToGlobalProcess:SIGCONT];
}

- (void)recycleGlobalProcess
{
    pid_t processIdentifier = [self sendSignalToGlobalProcess:SIGINT];
    if (processIdentifier != 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sendSignal:SIGKILL toProcessWithIdentifier:processIdentifier];
        });
    }
}


#pragma mark - Lua Launcher

- (BOOL)launchScriptData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    return [self launchScriptData:data additionalEnvironmentVariables:@{} error:error];
}

- (BOOL)launchScriptData:(NSData *)data additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables error:(NSError *__autoreleasing *)error
{
    NSAssert(getuid() == 0, @"wrong privilege");
    
    NSURL *tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
                                                           inDomain:NSUserDomainMask
                                                  appropriateForURL:[NSURL fileURLWithPath:@"/private/var"]
                                                             create:YES
                                                              error:error];
    
    if (!tmpURL) {
        return nil;
    }
    
    NSString *inputPath = [[tmpURL path] stringByAppendingPathComponent:@"data"];
    BOOL writeSucceed = [data writeToFile:inputPath
                                  options:NSDataWritingAtomic
                                    error:error];
    
    if (!writeSucceed) {
        return nil;
    }
    
    return [self launchScriptAtPath:inputPath additionalEnvironmentVariables:environmentVariables error:error];
}

- (BOOL)launchSelectedScriptWithError:(NSError *__autoreleasing *)error
{
    return [self launchSelectedScriptWithAdditionalEnvironmentVariables:@{} error:error];
}

- (BOOL)launchSelectedScriptWithAdditionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables error:(NSError *__autoreleasing *)error
{
    NSString *scriptName = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.selected-script"];
    return [self launchScriptWithName:scriptName additionalEnvironmentVariables:environmentVariables error:error];
}

- (BOOL)launchScriptWithName:(NSString *)name error:(NSError *__autoreleasing *)error
{
    return [self launchScriptWithName:name additionalEnvironmentVariables:@{} error:error];
}

- (BOOL)launchScriptWithName:(NSString *)name additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables error:(NSError *__autoreleasing *)error
{
    NSString *scriptPath = [@MEDIA_LUA_SCRIPTS_DIR stringByAppendingPathComponent:name];
    return [self launchScriptAtPath:scriptPath additionalEnvironmentVariables:environmentVariables error:error];
}

- (BOOL)launchScriptAtPath:(NSString *)path error:(NSError *__autoreleasing *)error
{
    return [self launchScriptAtPath:path additionalEnvironmentVariables:@{} error:error];
}

- (BOOL)launchScriptAtPath:(NSString *)path additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables error:(NSError *__autoreleasing *)error
{
    BOOL remoteSucceed = NO;
    NSError *strongErr = nil;
    
    @autoreleasepool {
        NSDictionary *replyObject = [self _launchScriptAtPath:path additionalEnvironmentVariables:environmentVariables];
        remoteSucceed = [replyObject[@"reply"] boolValue];
        if (!remoteSucceed) {
            if ([replyObject[@"reason"] isKindOfClass:[NSString class]]) {
                strongErr = [NSError errorWithDomain:@SupervisorErrorDomain code:[replyObject[@"code"] integerValue] userInfo:@{
                    NSLocalizedDescriptionKey: replyObject[@"error"] ?: @"",
                    NSLocalizedFailureReasonErrorKey: replyObject[@"reason"] ?: @"",
                }];
            } else {
                strongErr = [NSError errorWithDomain:@SupervisorErrorDomain code:[replyObject[@"code"] integerValue] userInfo:@{
                    NSLocalizedDescriptionKey: replyObject[@"error"] ?: @"",
                }];
            }
        }
    }
    
    if (strongErr) {
        if (error) {
            if (*error == nil) {
                *error = strongErr;
            }
        }
        return NO;
    }
    
    return remoteSucceed;
}

- (NSDictionary *)_launchScriptAtPath:(NSString *)path additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
{
    if (_role == SupervisorRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_launchScriptAtPath:additionalEnvironmentVariables:)),
                @"arguments": [NSArray arrayWithObjects:path, environmentVariables, nil],
            }];
            
            CHDebugLog(@"_launchScriptAtPath %@ environmentVariables %@ -> %@", path, environmentVariables, replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]] && ([replyObject[@"reply"] isKindOfClass:[NSNumber class]] && ([replyObject[@"code"] isKindOfClass:[NSNumber class]] || [replyObject[@"error"] isKindOfClass:[NSString class]])), @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        
        __block BOOL succeed = NO;
        __block NSError *strongError = nil;
        
        NSMutableDictionary *defaultsEnvironment = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.env"] mutableCopy];
        if (![defaultsEnvironment isKindOfClass:[NSDictionary class]])
            defaultsEnvironment = [NSMutableDictionary dictionary];
        [defaultsEnvironment addEntriesFromDictionary:environmentVariables];
        
        NSMutableDictionary <NSString *, NSString *> *scriptEnvironment = [[Supervisor sharedTaskEnvironment] mutableCopy];
        [scriptEnvironment setObject:path forKey:@"XXT_ENTRYPOINT"];
        
        for (NSString *envKey in defaultsEnvironment) {
            NSString *envValue = defaultsEnvironment[envKey];
            if (![envKey isKindOfClass:[NSString class]] || ![envValue isKindOfClass:[NSString class]])
                continue;
            [scriptEnvironment setObject:envValue forKey:envKey];
        }
        
        dispatch_sync(_eventQueue, ^{
            @autoreleasepool {
                
                BOOL isDir = NO;
                BOOL exists = [_eventFileManager fileExistsAtPath:path isDirectory:&isDir];
                if (!exists || isDir)
                {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to read script file at %@", path] }];
                    return;
                }
                
                BOOL readable = [_eventFileManager isReadableFileAtPath:path];
                if (!readable)
                {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to read script file at %@", path] }];
                    return;
                }
                
                NSString *checkSyntaxResult = [self checkLuaSyntaxAtPath:path];
                if (checkSyntaxResult != nil && [checkSyntaxResult length] > 0)
                {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:2 userInfo:@{ NSLocalizedDescriptionKey: @"SYNTAX_ERROR", NSLocalizedFailureReasonErrorKey: checkSyntaxResult }];
                    return;
                }
                
                if (_globalState != SupervisorStateIdle)
                {
                    if (_globalState == SupervisorStateRunning || _globalState == SupervisorStateSuspend)
                    {
                        succeed = NO;
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:3 userInfo:@{ NSLocalizedDescriptionKey: @"SERVICE_UNAVAILABLE", NSLocalizedFailureReasonErrorKey: @"The system is currently running another script" }];
                        return;
                    }
                    else if (_globalState == SupervisorStateRecording)
                    {
                        succeed = NO;
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:3 userInfo:@{ NSLocalizedDescriptionKey: @"SERVICE_UNAVAILABLE", NSLocalizedFailureReasonErrorKey: @"The system is currently recording script events" }];
                        return;
                    }
                }
                
                if (![_eventFileManager fileExistsAtPath:@LOG_LAUNCHER_OUTPUT])
                {
                    succeed = [_eventFileManager createFileAtPath:@LOG_LAUNCHER_OUTPUT
                                                         contents:[NSData data]
                                                       attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to create script output log file at %@", @LOG_LAUNCHER_OUTPUT] }];
                    }
                }
                else
                {
                    NSError *attrErr = nil;
                    succeed = [_eventFileManager setAttributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }
                                                  ofItemAtPath:@LOG_LAUNCHER_OUTPUT
                                                         error:&attrErr];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to create script output log file: %@", [attrErr localizedDescription]] }];
                    }
                }
                
                if (!succeed)
                    return;
                
                if (![_eventFileManager fileExistsAtPath:@LOG_LAUNCHER_ERROR])
                {
                    succeed = [_eventFileManager createFileAtPath:@LOG_LAUNCHER_ERROR
                                                         contents:[NSData data]
                                                       attributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:5 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to create script error log file at %@", @LOG_LAUNCHER_ERROR] }];
                    }
                }
                else
                {
                    NSError *attrErr = nil;
                    succeed = [_eventFileManager setAttributes:@{ NSFileOwnerAccountID: @(0), NSFileGroupOwnerAccountID: @(0) }
                                                  ofItemAtPath:@LOG_LAUNCHER_ERROR
                                                         error:&attrErr];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:5 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to create script error log file: %@", [attrErr localizedDescription]] }];
                    }
                }
                
                if (!succeed)
                    return;
                
                NSFileHandle *outputHandle = [NSFileHandle fileHandleForWritingAtPath:@LOG_LAUNCHER_OUTPUT];
                if (outputHandle) {
                    NSError *seekErr = nil;
                    unsigned long long endOffset;
                    succeed = [outputHandle seekToEndReturningOffset:&endOffset error:&seekErr];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:6 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to open script output log handle: %@", [seekErr localizedDescription]] }];
                        [outputHandle closeFile];
                        outputHandle = nil;
                    }
                } else {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:6 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to open script output log handle at %@", @LOG_LAUNCHER_OUTPUT] }];
                }
                
                if (!succeed)
                    return;
                
                NSFileHandle *errorHandle = [NSFileHandle fileHandleForWritingAtPath:@LOG_LAUNCHER_ERROR];
                if (errorHandle) {
                    NSError *seekErr = nil;
                    unsigned long long endOffset;
                    succeed = [errorHandle seekToEndReturningOffset:&endOffset error:&seekErr];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:7 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to open script error log handle: %@", [seekErr localizedDescription]] }];
                        [outputHandle closeFile];
                        outputHandle = nil;
                        [errorHandle closeFile];
                        errorHandle = nil;
                    }
                } else {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:7 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to open script error log handle at %@", @LOG_LAUNCHER_ERROR] }];
                    [outputHandle closeFile];
                    outputHandle = nil;
                }
                
                if (!succeed)
                    return;
                
                NSTask *scriptTask = [[NSTask alloc] init];
                
                [scriptTask setCurrentDirectoryPath:@MEDIA_ROOT];
                [scriptTask setLaunchPath:@BIN_LAUNCHER];
                [scriptTask setArguments:[NSArray arrayWithObjects:path, nil]];
                [scriptTask setEnvironment:scriptEnvironment];
                
                [scriptTask setStandardInput:[NSPipe pipe]];
                [scriptTask setStandardOutput:outputHandle];
                [scriptTask setStandardError:errorHandle];
                
                CHLog(@"Will launch global script task: %@", @{
                    @"launchPath": [scriptTask launchPath],
                    @"arguments": [scriptTask arguments],
                    @"environment": [scriptTask environment],
                    @"currentDirectoryPath": [scriptTask currentDirectoryPath],
                });
                
                [scriptTask launch];
                
                succeed = YES;
                self->_globalState = SupervisorStateRunning;
                self->_globalTask = scriptTask;
                self->_lastTargetPath = path;
                
                notify_post(NOTIFY_TASK_DID_BEGIN);
            }
        });
        
        [self setupTaskNotification];
        
        return @{
            @"reply": @(succeed),
            @"code": @(strongError.code),
            @"error": [strongError localizedDescription] ?: @"",
            @"reason": [strongError localizedFailureReason] ?: @"",
        };
    }
}

- (void)pausePlaying
{
    [self stopGlobalProcess];
}

- (void)continuePlaying
{
    [self continueGlobalProcess];
}

- (NSString *)endPlaying
{
    [self recycleGlobalProcess];
    return [self lastTargetPath];
}

- (BOOL)beginRecordingAtDefaultPathWithError:(NSError *__autoreleasing *)error
{
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.timeZone = [NSTimeZone systemTimeZone];
        dateFormatter.dateFormat = @"yyyyMMddHHmmss";
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    
    NSString *recordingName = [NSString stringWithFormat:@"rec_%@.lua",
                               [dateFormatter stringFromDate:[NSDate date]]];
    NSString *recordingPath = [@MEDIA_LUA_SCRIPTS_DIR stringByAppendingPathComponent:recordingName];
    
    return [self beginRecordingAtPath:recordingPath error:error];
}

- (BOOL)beginRecordingAtPath:(NSString *)path error:(NSError *__autoreleasing *)error
{
    BOOL remoteSucceed = NO;
    NSError *strongErr = nil;
    
    @autoreleasepool {
        NSDictionary *replyObject = [self _beginRecordingAtPath:path];
        remoteSucceed = [replyObject[@"reply"] boolValue];
        if (!remoteSucceed) {
            if ([replyObject[@"reason"] isKindOfClass:[NSString class]]) {
                strongErr = [NSError errorWithDomain:@SupervisorErrorDomain code:[replyObject[@"code"] integerValue] userInfo:@{
                    NSLocalizedDescriptionKey: replyObject[@"error"] ?: @"",
                    NSLocalizedFailureReasonErrorKey: replyObject[@"reason"] ?: @"",
                }];
            } else {
                strongErr = [NSError errorWithDomain:@SupervisorErrorDomain code:[replyObject[@"code"] integerValue] userInfo:@{
                    NSLocalizedDescriptionKey: replyObject[@"error"] ?: @"",
                }];
            }
        }
    }
    
    if (strongErr) {
        if (error) {
            if (*error == nil) {
                *error = strongErr;
            }
        }
        return NO;
    }
    
    return remoteSucceed;
}

- (NSDictionary *)_beginRecordingAtPath:(NSString *)path
{
    if (_role == SupervisorRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_beginRecordingAtPath:)),
                @"arguments": [NSArray arrayWithObjects:path, nil],
            }];
            
            CHDebugLog(@"_beginRecordingAtPath %@ -> %@", path, replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]] && ([replyObject[@"reply"] isKindOfClass:[NSNumber class]] && ([replyObject[@"code"] isKindOfClass:[NSNumber class]] || [replyObject[@"error"] isKindOfClass:[NSString class]])), @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        
        __block BOOL succeed = NO;
        __block NSError *strongError = nil;
        
        dispatch_sync(_eventQueue, ^{
            @autoreleasepool {
                
                if (_globalState != SupervisorStateIdle)
                {
                    if (_globalState == SupervisorStateRunning || _globalState == SupervisorStateSuspend)
                    {
                        succeed = NO;
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:3 userInfo:@{ NSLocalizedDescriptionKey: @"SERVICE_UNAVAILABLE", NSLocalizedFailureReasonErrorKey: @"The system is currently running another script." }];
                        return;
                    }
                    else if (_globalState == SupervisorStateRecording)
                    {
                        succeed = NO;
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:3 userInfo:@{ NSLocalizedDescriptionKey: @"SERVICE_UNAVAILABLE", NSLocalizedFailureReasonErrorKey: @"The system is currently recording script events." }];
                        return;
                    }
                }
                
                if (![_eventFileManager fileExistsAtPath:path])
                {
                    succeed = [_eventFileManager createFileAtPath:path
                                                         contents:[NSData data]
                                                       attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to create record lua file at %@", path] }];
                    }
                }
                else
                {
                    NSError *attrErr = nil;
                    succeed = [_eventFileManager setAttributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }
                                                  ofItemAtPath:path
                                                         error:&attrErr];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to create record lua file: %@", [attrErr localizedDescription]] }];
                    }
                }
                
                if (!succeed)
                    return;
                
                NSFileHandle *outputHandle = [NSFileHandle fileHandleForWritingAtPath:path];
                if (outputHandle) {
                    NSError *seekErr = nil;
                    unsigned long long endOffset;
                    succeed = [outputHandle seekToEndReturningOffset:&endOffset error:&seekErr];
                    if (!succeed) {
                        strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:6 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to open record lua handle: %@", [seekErr localizedDescription]] }];
                        [outputHandle closeFile];
                        outputHandle = nil;
                    }
                } else {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:6 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Failed to open record lua handle at %@", path] }];
                }
                
                if (!succeed)
                    return;
                
                NSFileHandle *errorHandle = [NSFileHandle fileHandleWithNullDevice];
                if (!errorHandle) {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:7 userInfo:@{ NSLocalizedDescriptionKey: @"INTERNAL_SERVER_ERROR", NSLocalizedFailureReasonErrorKey: @"Failed to open record error handle at /dev/null" }];
                    [outputHandle closeFile];
                    outputHandle = nil;
                }
                
                if (!succeed)
                    return;
                
                NSTask *recordTask = [[NSTask alloc] init];
                
                [recordTask setCurrentDirectoryPath:@MEDIA_ROOT];
                [recordTask setLaunchPath:@BIN_RECORDER];
                [recordTask setArguments:[NSArray array]];
                [recordTask setEnvironment:[Supervisor sharedTaskEnvironment]];
                
                [recordTask setStandardInput:[NSPipe pipe]];
                [recordTask setStandardOutput:outputHandle];
                [recordTask setStandardError:errorHandle];
                
                CHLog(@"Will launch global record task: %@", @{
                    @"launchPath": [recordTask launchPath],
                    @"arguments": [recordTask arguments],
                    @"environment": [recordTask environment],
                    @"currentDirectoryPath": [recordTask currentDirectoryPath],
                });
                
                [recordTask launch];
                
                succeed = YES;
                self->_globalState = SupervisorStateRecording;
                self->_globalTask = recordTask;
                self->_lastTargetPath = path;
                
                notify_post(NOTIFY_TASK_DID_BEGIN);
            }
        });
        
        [self setupTaskNotification];
        
        return @{
            @"reply": @(succeed),
            @"code": @(strongError.code),
            @"error": [strongError localizedDescription] ?: @"",
            @"reason": [strongError localizedFailureReason] ?: @"",
        };
    }
}

- (NSString *)endRecording
{
    [self recycleGlobalProcess];
    return [self lastTargetPath];
}


#pragma mark - Process Monitor

+ (NSDictionary <NSString *, NSString *> *)sharedTaskEnvironment {
    static NSDictionary <NSString *, NSString *> *environmentDictionary = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        environmentDictionary = @{
            @"PATH"            : @"/usr/local/xxtouch/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            @"LUA_PATH"        : @
            MEDIA_LUA_SCRIPTS_DIR "/?.lua;"
            MEDIA_LUA_SCRIPTS_DIR "/?.luac;"
            MEDIA_LUA_SCRIPTS_DIR "/?.xxt;"
            MEDIA_LUA_SCRIPTS_DIR "/?/init.lua;"
            MEDIA_LUA_SCRIPTS_DIR "/?/init.luac;"
            MEDIA_LUA_SCRIPTS_DIR "/?/init.xxt;"
            "/usr/local/xxtouch/lib/?.lua;"
            "/usr/local/xxtouch/lib/?.luac;"
            "/usr/local/xxtouch/lib/?.xxt;"
            "/usr/local/xxtouch/lib/?/init.lua;"
            "/usr/local/xxtouch/lib/?/init.luac;"
            "/usr/local/xxtouch/lib/?/init.xxt",
            @"LUA_CPATH"       : @"/usr/local/xxtouch/lib/?.so;;",
            @"LUA_INIT"        : @"@/usr/local/xxtouch/lib/xxtouch/init.lua",
            @"CURL_CA_BUNDLE"  : @"/usr/local/xxtouch/lib/ssl/curl-ca-bundle.crt",
        };
    });
    return environmentDictionary;
}

- (void)setupTaskNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTaskTermination:)
                                                 name:NSTaskDidTerminateNotification
                                               object:self->_globalTask];
}

- (void)removeTaskNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSTaskDidTerminateNotification
                                                  object:self->_globalTask];
}

+ (NSString *)tailLogAtPath:(NSString *)logPath forLastLineCount:(NSInteger)lastN
{
    @autoreleasepool {
        if (lastN <= 0)
            return @"";
        
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
        NSData *truncatedData = [sysLogHandle readDataOfLength:finalRange.length];
        
        [sysLogHandle closeFile];
        
        if (truncatedData.length == 0)
            return @"";
        
        return [[NSString alloc] initWithData:truncatedData encoding:NSUTF8StringEncoding];
    }
}

- (void)handleTaskTermination:(NSNotification *)aNotification
{
    @autoreleasepool {
        BOOL endWithHint = NO;
        BOOL scriptOnDaemon = NO;
        
        NSDictionary *userConf = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.user"];
        if ([userConf isKindOfClass:[NSDictionary class]]) {
            endWithHint = [userConf[@"script_end_hint"] boolValue];
            scriptOnDaemon = [userConf[@"script_on_daemon"] boolValue];
        }
        
        NSTask *task = aNotification.object;
        [self removeTaskNotification];
        
        dispatch_async(_eventQueue, ^{
            @autoreleasepool {
                CHLog(@"Global script task %@ did terminated with status %d", task, task.terminationStatus);
                
                BOOL isRecording = (self->_globalState == SupervisorStateRecording);
                
                self->_globalState = SupervisorStateIdle;
                self->_globalTask = nil;
                self->_lastExitCode = task.terminationStatus;
                self->_lastError = nil;
                
                if (task.terminationStatus != 0 && !isRecording)
                {
                    NSString *launcherErrorString = [Supervisor tailLogAtPath:@LOG_LAUNCHER_ERROR forLastLineCount:20];
                    NSRange errorLineRange = [launcherErrorString rangeOfString:@BIN_LAUNCHER ":" options:NSBackwardsSearch range:NSMakeRange(0, launcherErrorString.length)];
                    if (errorLineRange.location != NSNotFound)
                    {
                        NSRange sepRange = [launcherErrorString rangeOfString:@"\n" options:kNilOptions range:NSMakeRange(errorLineRange.location, launcherErrorString.length - errorLineRange.location)];
                        if (sepRange.location != NSNotFound)
                        {
                            if (sepRange.location > errorLineRange.location) {
                                errorLineRange = NSMakeRange(errorLineRange.location, sepRange.location - errorLineRange.location);
                                NSString *errorLine = [[launcherErrorString substringWithRange:errorLineRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                CHDebugLogSource(@"Task error occurred %@", errorLine);
                                
                                if ([errorLine hasPrefix:@BIN_LAUNCHER])
                                    errorLine = [errorLine substringFromIndex:sizeof(BIN_LAUNCHER)];
                                errorLine = [errorLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                
                                if ([errorLine hasPrefix:@MEDIA_ROOT]) {
                                    errorLine = [errorLine substringFromIndex:sizeof(MEDIA_ROOT)];
                                    errorLine = [@"./" stringByAppendingString:errorLine];
                                }
                                
                                self->_lastError = [NSError errorWithDomain:@SupervisorErrorDomain code:7 userInfo:@{
                                    NSLocalizedDescriptionKey: @"RUNTIME_ERROR",
                                    NSLocalizedFailureReasonErrorKey: errorLine,
                                }];
                            }
                        }
                    }
                }
                
                notify_post(NOTIFY_DISMISSAL_SYS_ALERT);
                notify_post(NOTIFY_DISMISSAL_SYS_TOAST);
                notify_post(NOTIFY_DISMISSAL_TOUCH_POSE);
                
                if (endWithHint && !self->_lastError)
                    notify_post(NOTIFY_TASK_DID_END_HINT);
                
                notify_post(NOTIFY_TASK_DID_END);
                
                if (scriptOnDaemon && task.terminationStatus != 0 && self->_lastTargetPath)
                {
                    CHLog(@"Daemon mode is ON, schedule next launch of terminated script %@", self->_lastTargetPath);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self _scheduleLaunchOfScriptAtPath:self->_lastTargetPath
                             additionalEnvironmentVariables:@{}
                                                     reason:@"daemon"
                                                    timeout:@3.0];
                    });
                }
            }
        });
    }
}

#pragma mark - Lua Scheduler

- (BOOL)scheduleLaunchOfSelectedScriptWithTimeout:(NSTimeInterval)timeout
                                            error:(NSError *__autoreleasing *)error
{
    return [self scheduleLaunchOfSelectedScriptWithTimeout:timeout additionalEnvironmentVariables:@{} error:error];
}

- (BOOL)scheduleLaunchOfSelectedScriptWithTimeout:(NSTimeInterval)timeout
                   additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                                            error:(NSError *__autoreleasing *)error
{
    NSString *scriptName = [[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.selected-script"];
    return [self scheduleLaunchOfScriptWithName:scriptName additionalEnvironmentVariables:environmentVariables timeout:timeout error:error];
}

- (BOOL)scheduleLaunchOfScriptWithName:(NSString *)name
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError *__autoreleasing *)error
{
    return [self scheduleLaunchOfScriptWithName:name additionalEnvironmentVariables:@{} timeout:timeout error:error];
}

- (BOOL)scheduleLaunchOfScriptWithName:(NSString *)name
        additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError *__autoreleasing *)error
{
    NSString *scriptPath = [@MEDIA_LUA_SCRIPTS_DIR stringByAppendingPathComponent:name];
    return [self scheduleLaunchOfScriptAtPath:scriptPath additionalEnvironmentVariables:environmentVariables timeout:timeout error:error];
}

- (BOOL)scheduleLaunchOfScriptAtPath:(NSString *)path
                             timeout:(NSTimeInterval)timeout
                               error:(NSError *__autoreleasing *)error
{
    return [self scheduleLaunchOfScriptAtPath:path additionalEnvironmentVariables:@{} timeout:timeout error:error];
}

- (BOOL)scheduleLaunchOfScriptAtPath:(NSString *)path
      additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                             timeout:(NSTimeInterval)timeout
                               error:(NSError *__autoreleasing *)error
{
    BOOL remoteSucceed = NO;
    NSError *strongErr = nil;
    
    @autoreleasepool {
        NSDictionary *replyObject = [self _scheduleLaunchOfScriptAtPath:path additionalEnvironmentVariables:environmentVariables timeout:@(timeout)];
        remoteSucceed = [replyObject[@"reply"] boolValue];
        if (!remoteSucceed) {
            if ([replyObject[@"reason"] isKindOfClass:[NSString class]]) {
                strongErr = [NSError errorWithDomain:@SupervisorErrorDomain code:[replyObject[@"code"] integerValue] userInfo:@{
                    NSLocalizedDescriptionKey: replyObject[@"error"] ?: @"",
                    NSLocalizedFailureReasonErrorKey: replyObject[@"reason"] ?: @"",
                }];
            } else {
                strongErr = [NSError errorWithDomain:@SupervisorErrorDomain code:[replyObject[@"code"] integerValue] userInfo:@{
                    NSLocalizedDescriptionKey: replyObject[@"error"] ?: @"",
                }];
            }
        }
    }
    
    if (strongErr) {
        if (error) {
            if (*error == nil) {
                *error = strongErr;
            }
        }
        return NO;
    }
    
    return remoteSucceed;
}

- (NSDictionary *)_scheduleLaunchOfScriptAtPath:(NSString *)path
                 additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                                        timeout:(NSNumber /* NSTimeInterval */ *)timeout
{
    return [self _scheduleLaunchOfScriptAtPath:path additionalEnvironmentVariables:environmentVariables reason:@"scheduler" timeout:timeout];
}

- (NSDictionary *)_scheduleLaunchOfScriptAtPath:(NSString *)path
                 additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                                         reason:(NSString *)reason
                                        timeout:(NSNumber /* NSTimeInterval */ *)timeout
{
    if (_role == SupervisorRoleClient)
    {
        @autoreleasepool {
            NSDictionary *replyObject = [self sendMessageAndReceiveReplyName:@XPC_TWOWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(_scheduleLaunchOfScriptAtPath:additionalEnvironmentVariables:reason:timeout:)),
                @"arguments": [NSArray arrayWithObjects:path, environmentVariables, reason, timeout, nil],
            }];
            
            CHDebugLog(@"_scheduleLaunchOfScriptAtPath %@ environmentVariables %@ reason %@ timeout %@ -> %@", path, environmentVariables, reason, timeout, replyObject);
            NSAssert([replyObject isKindOfClass:[NSDictionary class]] && ([replyObject[@"reply"] isKindOfClass:[NSNumber class]] && ([replyObject[@"code"] isKindOfClass:[NSNumber class]] || [replyObject[@"error"] isKindOfClass:[NSString class]])), @"invalid xpc response");
            
            return replyObject;
        }
    }
    
    @autoreleasepool {
        
        __block BOOL succeed = NO;
        __block NSError *strongError = nil;
        
        NSMutableDictionary <NSString *, NSString *> *scriptEnvironment = [environmentVariables mutableCopy];
        if (![scriptEnvironment isKindOfClass:[NSDictionary class]])
            scriptEnvironment = [NSMutableDictionary dictionary];
        [scriptEnvironment setObject:(reason ?: @"scheduler") forKey:@"XXT_ENTRYTYPE"];
        
        dispatch_sync(_eventQueue, ^{
            @autoreleasepool {
                
                if (self->_schedulerTimer)
                {
                    [self->_schedulerTimer invalidate];
                    self->_schedulerTimer = nil;
                }
                
                BOOL isDir = NO;
                BOOL exists = [_eventFileManager fileExistsAtPath:path isDirectory:&isDir];
                if (!exists || isDir)
                {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"Failed to read script file", NSLocalizedFailureReasonErrorKey: path }];
                    return;
                }
                
                BOOL readable = [_eventFileManager isReadableFileAtPath:path];
                if (!readable)
                {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"Failed to read script file", NSLocalizedFailureReasonErrorKey: path }];
                    return;
                }
                
                NSString *checkSyntaxResult = [self checkLuaSyntaxAtPath:path];
                if (checkSyntaxResult != nil && [checkSyntaxResult length] > 0)
                {
                    succeed = NO;
                    strongError = [NSError errorWithDomain:@SupervisorErrorDomain code:2 userInfo:@{ NSLocalizedDescriptionKey: @"SYNTAX_ERROR", NSLocalizedFailureReasonErrorKey: checkSyntaxResult }];
                    return;
                }
                
                void *launchPathPtr = (__bridge void *)(path);
                void *environmentPtr = (__bridge void *)(scriptEnvironment);
                
                SEL launchSelector = @selector(_launchScriptAtPath:additionalEnvironmentVariables:);
                NSInvocation *launchInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:launchSelector]];
                
                [launchInvocation setSelector:launchSelector];
                [launchInvocation setTarget:self];
                [launchInvocation setArgument:&launchPathPtr atIndex:2];
                [launchInvocation setArgument:&environmentPtr atIndex:3];
                
                succeed = YES;
                self->_schedulerTimer = [NSTimer scheduledTimerWithTimeInterval:[timeout doubleValue]
                                                                     invocation:launchInvocation
                                                                        repeats:NO];
            }
        });
        
        return @{
            @"reply": @(succeed),
            @"code": @(strongError.code),
            @"error": [strongError localizedDescription] ?: @"",
            @"reason": [strongError localizedFailureReason] ?: @"",
        };
    }
}

- (void)cancelPreviousScheduledLaunch
{
    if (_role == SupervisorRoleClient)
    {
        @autoreleasepool {
            [self sendMessageName:@XPC_ONEWAY_MSG_NAME userInfo:@{
                @"selector": NSStringFromSelector(@selector(cancelPreviousScheduledLaunch)),
                @"arguments": [NSArray array],
            }];
            return;
        }
    }
    
    @autoreleasepool {
        dispatch_sync(_eventQueue, ^{
            @autoreleasepool {
                [self->_schedulerTimer invalidate];
                self->_schedulerTimer = nil;
            }
        });
    }
}

@end


#pragma mark - Constructor

CHConstructor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] arguments][0];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        BOOL forceClient = [[[NSProcessInfo processInfo] environment][@"CLIENT"] boolValue];
        
        if (!forceClient && ([processName isEqualToString:@"supervisord"] || [processName hasSuffix:@"/supervisord"]))
        {   /* Server Process - supervisord */
            
            do {
                
                /// do inject to protected executable only
                if (!dlsym(RTLD_MAIN_ONLY, "plugin_i_love_xxtouch")) {
                    break;
                }
                
                rocketbootstrap_unlock(XPC_INSTANCE_NAME);
                
                CPDistributedMessagingCenter *serverMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
                rocketbootstrap_distributedmessagingcenter_apply(serverMessagingCenter);
                [serverMessagingCenter runServerOnCurrentThread];
                
                Supervisor *serverInstance = [Supervisor sharedInstanceWithRole:SupervisorRoleServer];
                [serverMessagingCenter registerForMessageName:@XPC_ONEWAY_MSG_NAME target:serverInstance selector:@selector(receiveMessageName:userInfo:)];
                [serverMessagingCenter registerForMessageName:@XPC_TWOWAY_MSG_NAME target:serverInstance selector:@selector(receiveAndReplyMessageName:userInfo:)];
                [serverInstance setMessagingCenter:serverMessagingCenter];
                
                CHDebugLogSource(@"server %@ initialized %@ %@, pid = %d", serverMessagingCenter, bundleIdentifier, processName, getpid());
                
            } while (NO);
        }
        else
        {   /* Client Process */
            
            do {
                
                CPDistributedMessagingCenter *clientMessagingCenter = [CPDistributedMessagingCenter centerNamed:@XPC_INSTANCE_NAME];
                rocketbootstrap_distributedmessagingcenter_apply(clientMessagingCenter);
                
                Supervisor *clientInstance = [Supervisor sharedInstanceWithRole:SupervisorRoleClient];
                [clientInstance setMessagingCenter:clientMessagingCenter];
                
                CHDebugLogSource(@"client %@ initialized %@ %@, pid = %d", clientMessagingCenter, bundleIdentifier, processName, getpid());
                
            } while (NO);
        }
    }
}
