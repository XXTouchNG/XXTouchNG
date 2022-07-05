//
//  Supervisor.h
//  Supervisor
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#ifndef Supervisor_h
#define Supervisor_h

#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

#define SupervisorErrorDomain   "ch.xxtou.error.supervisor"

typedef NS_ENUM(NSUInteger, SupervisorRole) {
    SupervisorRoleClient = 0,
    SupervisorRoleServer,
};

typedef NS_ENUM(NSUInteger, SupervisorState) {
    SupervisorStateIdle = 0,
    SupervisorStateRunning,
    SupervisorStateRecording,
    SupervisorStateSuspend,
};

NS_ASSUME_NONNULL_BEGIN

@interface Supervisor : NSObject

@property (nonatomic, strong, readonly) CPDistributedMessagingCenter *messagingCenter;
@property (nonatomic, assign, readonly) SupervisorRole role;

+ (instancetype)sharedInstance;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/* Command */
- (nullable NSString *)simpleSpawnCommand:(NSString *)command;
- (nullable NSString *)simpleSpawnCommand:(NSString *)command error:(NSError *__autoreleasing*)error;
- (nullable NSString *)simpleSpawnCommand:(NSString *)command timeout:(NSTimeInterval)timeout;
- (nullable NSString *)simpleSpawnCommand:(NSString *)command timeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing*)error;

/* Version */
- (NSString *)luaVersion;

/* Lua Playground */
- (nullable NSString *)      evalString:(NSString *)string
             ignoreEnvironmentVariables:(BOOL)ignore
                                  error:(NSError *__autoreleasing*)error;
- (nullable NSString *)        evalData:(NSData *)data
             ignoreEnvironmentVariables:(BOOL)ignore
                                  error:(NSError *__autoreleasing*)error;
- (nullable NSString *)evalWithContentsOfFile:(NSString *)path
                   ignoreEnvironmentVariables:(BOOL)ignore
                                        error:(NSError *__autoreleasing*)error;

/* Lua Compiler */
- (nullable NSString *)checkLuaSyntaxAtPath:(NSString *)path;
- (nullable NSString *)checkLuaSyntaxWithData:(NSData *)data;
- (BOOL)    compileLuaAtPath:(NSString *)path
                      toPath:(NSString *)outputPath
       stripDebugInformation:(BOOL)strip
                       error:(NSError *__autoreleasing*)error;
- (nullable NSData *)compileLuaAtPath:(NSString *)path
                stripDebugInformation:(BOOL)strip
                                error:(NSError *__autoreleasing*)error;
- (nullable NSData *)compileLuaWithData:(NSData *)data
                  stripDebugInformation:(BOOL)strip
                                  error:(NSError *__autoreleasing*)error;
- (nullable NSString *)revealByteCodeOfLuaAtPath:(NSString *)path
                                           error:(NSError *__autoreleasing*)error;
- (nullable NSString *)revealByteCodeOfLuaWithData:(NSData *)data
                                             error:(NSError *__autoreleasing*)error;

/* Lua Global State Machine */
- (SupervisorState)globalState;
- (nullable NSString *)lastTargetPath;
- (nullable NSError *)lastError;
- (int)lastExitCode;
- (BOOL)isIdle;
- (BOOL)isRunning;
- (BOOL)isRecording;
- (BOOL)isSuspended;
- (BOOL)isBusy;  // !isIdle

/* Lua Launcher */
+ (NSDictionary *)sharedTaskEnvironment;
- (BOOL)launchScriptData:(NSData *)data error:(NSError *__autoreleasing*)error;
- (BOOL)launchSelectedScriptWithError:(NSError *__autoreleasing*)error;
- (BOOL)launchScriptWithName:(NSString *)name error:(NSError *__autoreleasing*)error;
- (BOOL)launchScriptAtPath:(NSString *)path error:(NSError *__autoreleasing*)error;
- (BOOL)            launchScriptData:(NSData *)data
      additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                               error:(NSError *__autoreleasing*)error;
- (BOOL)launchSelectedScriptWithAdditionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                                                         error:(NSError *__autoreleasing*)error;
- (BOOL)        launchScriptWithName:(NSString *)name
      additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                               error:(NSError *__autoreleasing*)error;
- (BOOL)          launchScriptAtPath:(NSString *)path
      additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                               error:(NSError *__autoreleasing*)error;
- (void)pausePlaying;
- (void)continuePlaying;
- (NSString *)endPlaying;

/* Lua Scheduler (os.restart) */
- (BOOL)scheduleLaunchOfSelectedScriptWithTimeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing*)error;
- (BOOL)scheduleLaunchOfScriptWithName:(NSString *)name timeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing*)error;
- (BOOL)scheduleLaunchOfScriptAtPath:(NSString *)path timeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing*)error;
- (BOOL)scheduleLaunchOfSelectedScriptWithTimeout:(NSTimeInterval)timeout
                   additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                                            error:(NSError *__autoreleasing*)error;
- (BOOL)           scheduleLaunchOfScriptWithName:(NSString *)name
                   additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                                          timeout:(NSTimeInterval)timeout
                                            error:(NSError *__autoreleasing*)error;
- (BOOL)             scheduleLaunchOfScriptAtPath:(NSString *)path
                   additionalEnvironmentVariables:(NSDictionary <NSString *, NSString *> *)environmentVariables
                                          timeout:(NSTimeInterval)timeout
                                            error:(NSError *__autoreleasing*)error;
- (void)cancelPreviousScheduledLaunch;

/* Lua Recorder */
- (BOOL)beginRecordingAtDefaultPathWithError:(NSError *__autoreleasing*)error;
- (BOOL)beginRecordingAtPath:(NSString *)path error:(NSError *__autoreleasing*)error;
- (NSString *)endRecording;

/* Process Management */
- (pid_t)globalProcessIdentifier;
- (pid_t)sendSignalToGlobalProcess:(int)signal;
- (void)sendSignal:(int)signal toProcessWithIdentifier:(pid_t)processIdentifier;
- (void)killGlobalProcess;        // SIGKILL
- (pid_t)terminateGlobalProcess;  // SIGTERM
- (pid_t)interruptGlobalProcess;  // SIGINT
- (pid_t)stopGlobalProcess;       // SIGSTOP (pause script)
- (pid_t)continueGlobalProcess;   // SIGCONT (continue script)
- (void)recycleGlobalProcess;     // SIGINT + SIGKILL (kill in 3 seconds by default)

@end

NS_ASSUME_NONNULL_END

#endif  /* Supervisor_h */
