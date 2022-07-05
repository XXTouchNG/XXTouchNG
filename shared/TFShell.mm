#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <stdio.h>
#import <spawn.h>
#import <launch.h>
#import <sys/stat.h>
#import <sys/wait.h>
#import <Foundation/Foundation.h>
#import <CaptainHook/CaptainHook.h>

#import "TFShell.h"
#import "MenesFunction.hpp"

#if DEBUG
#define TFDebug CHDebugLog
#else
#define TFDebug(...)
#endif


typedef enum : int {
    TFProcessErrorNone             = 0,
    TFProcessErrorUnknown          = -1,
    TFProcessErrorInvalidArguments = -2,
    TFProcessErrorPosixspawn       = -101,
    TFProcessErrorWaitpid          = -102,
    TFProcessErrorPipe             = -103,
    TFProcessErrorFdopen           = -104,
    TFProcessErrorFclose           = -105,
    TFProcessErrorFcntl            = -106,
    TFProcessErrorKilled           = -200,
    TFProcessErrorStopped          = -300,
} TFProcessError;

#pragma mark - shell

extern char **environ;

int ios_system(const char *ctx) {
    const char *args[] = {
        "/bin/sh",
        "-c",
        ctx,
        NULL
    };
    pid_t pid;
    int posix_status = posix_spawn(&pid, "/bin/sh", NULL, NULL, (char **)args, environ);
    if (posix_status != 0) {
        errno = posix_status;
        TFDebug(@"posix_spawn, %s (%d)", strerror(errno), errno);
        return TFProcessErrorPosixspawn;
    } else {
        pid_t w; int status;
        do {
            w = waitpid(pid, &status, WUNTRACED | WCONTINUED);
            if (w == -1) {
                TFDebug(@"waitpid %d, %s (%d)", pid, strerror(errno), errno);
                return TFProcessErrorWaitpid;
            }
            
            if (WIFEXITED(status)) {
                TFDebug(@"pid %d exited, status=%d", pid, WEXITSTATUS(status));
            } else if (WIFSIGNALED(status)) {
                TFDebug(@"pid %d killed by signal %d", pid, WTERMSIG(status));
            } else if (WIFSTOPPED(status)) {
                TFDebug(@"pid %d stopped by signal %d", pid, WSTOPSIG(status));
            } else if (WIFCONTINUED(status)) {
                TFDebug(@"pid %d continued", pid);
            }
        } while (!WIFEXITED(status) && !WIFSIGNALED(status));
        if (WIFEXITED(status)) {
            return TFProcessErrorNone    + WEXITSTATUS(status);
        } else if (WIFSIGNALED(status)) {
            return TFProcessErrorKilled  - WTERMSIG(status);
        }
        return TFProcessErrorUnknown;
    }
}

int TFProcessOpen(const char **arglist, pid_t *pidp, int *stdoutfdp, int *stderrfdp) {
    if (!arglist || !pidp) {
        return TFProcessErrorInvalidArguments;
    }
    
    int pfd1[2];
    if (pipe(pfd1) < 0) {
        // perror("pipe");
        TFDebug(@"pipe, %s (%d)", strerror(errno), errno);
        return TFProcessErrorPipe;
    }
    
    int pfd2[2];
    if (pipe(pfd2) < 0) {
        // perror("pipe");
        TFDebug(@"pipe, %s (%d)", strerror(errno), errno);
        if (close(pfd1[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd1[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        return TFProcessErrorPipe;
    }
    
    int s;
    pid_t pid;
    
    posix_spawn_file_actions_t actions;
    s = posix_spawn_file_actions_init(&actions);
    if (s != 0) {
        errno = s; // perror("posix_spawn_file_actions_init");
        TFDebug(@"posix_spawn_file_actions_init, %s (%d)", strerror(errno), errno);
        if (close(pfd1[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd1[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        return TFProcessErrorPosixspawn;
    }
    s = posix_spawn_file_actions_adddup2(&actions, pfd1[1], STDOUT_FILENO);
    if (s != 0) {
        errno = s; // perror("posix_spawn_file_actions_adddup2");
        TFDebug(@"posix_spawn_file_actions_adddup2, %s (%d)", strerror(errno), errno);
        s = posix_spawn_file_actions_destroy(&actions);
        if (s != 0) { errno = s; /* perror("posix_spawn_file_actions_destroy"); */ TFDebug(@"posix_spawn_file_actions_destroy, %s (%d)", strerror(errno), errno); }
        if (close(pfd1[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd1[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        return TFProcessErrorPosixspawn;
    }
    s = posix_spawn_file_actions_addclose(&actions, pfd1[0]);
    if (s != 0) {
        errno = s; // perror("posix_spawn_file_actions_addclose");
        TFDebug(@"posix_spawn_file_actions_addclose, %s (%d)", strerror(errno), errno);
        s = posix_spawn_file_actions_destroy(&actions);
        if (s != 0) { errno = s; /* perror("posix_spawn_file_actions_destroy"); */ TFDebug(@"posix_spawn_file_actions_destroy, %s (%d)", strerror(errno), errno); }
        if (close(pfd1[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd1[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        return TFProcessErrorPosixspawn;
    }
    s = posix_spawn_file_actions_adddup2(&actions, pfd2[1], STDERR_FILENO);
    if (s != 0) {
        errno = s; // perror("posix_spawn_file_actions_adddup2");
        TFDebug(@"posix_spawn_file_actions_adddup2, %s (%d)", strerror(errno), errno);
        s = posix_spawn_file_actions_destroy(&actions);
        if (s != 0) { errno = s; /* perror("posix_spawn_file_actions_destroy"); */ TFDebug(@"posix_spawn_file_actions_destroy, %s (%d)", strerror(errno), errno); }
        if (close(pfd1[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd1[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        return TFProcessErrorPosixspawn;
    }
    s = posix_spawn_file_actions_addclose(&actions, pfd2[0]);
    if (s != 0) {
        errno = s; // perror("posix_spawn_file_actions_addclose");
        TFDebug(@"posix_spawn_file_actions_addclose, %s (%d)", strerror(errno), errno);
        s = posix_spawn_file_actions_destroy(&actions);
        if (s != 0) { errno = s; /* perror("posix_spawn_file_actions_destroy"); */ TFDebug(@"posix_spawn_file_actions_destroy, %s (%d)", strerror(errno), errno); }
        if (close(pfd1[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd1[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        return TFProcessErrorPosixspawn;
    }
    s = posix_spawn(&pid, arglist[0], &actions, NULL, (char **)arglist, environ);
    if (s != 0) {
        errno = s; // perror("posix_spawn");
        TFDebug(@"posix_spawn, %s (%d)", strerror(errno), errno);
        s = posix_spawn_file_actions_destroy(&actions);
        if (s != 0) { errno = s; /* perror("posix_spawn_file_actions_destroy"); */ TFDebug(@"posix_spawn_file_actions_destroy, %s (%d)", strerror(errno), errno); }
        if (close(pfd1[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd1[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        return TFProcessErrorPosixspawn;
    }
    s = posix_spawn_file_actions_destroy(&actions);
    if (s != 0) {
        errno = s; // perror("posix_spawn_file_actions_destroy");
        TFDebug(@"posix_spawn_file_actions_destroy, %s (%d)", strerror(errno), errno);
        if (close(pfd1[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd1[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        if (close(pfd2[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)", strerror(errno), errno);   }
        return TFProcessErrorPosixspawn;
    }
    
    if (close(pfd1[1]) == EOF)     { /* perror("close"); */  TFDebug(@"close, %s (%d)",  strerror(errno), errno);  }
    
    int fd1 = pfd1[0];
    if (fd1 == -1)                 { /* perror("fileno"); */ TFDebug(@"fileno, %s (%d)", strerror(errno), errno);  }
    int flags1 = fcntl(fd1, F_GETFL, 0); flags1 |= O_NONBLOCK;
    if (fcntl(fd1, F_SETFL, flags1) == -1) {
        // perror("fcntl");
        TFDebug(@"fcntl, %s (%d)", strerror(errno), errno);
        if (close(fd1) == EOF)     { /* perror("close"); */  TFDebug(@"close, %s (%d)",  strerror(errno), errno);  }
        // pfd1[0] already closed
        // pfd1[1] already closed
        if (close(pfd2[0]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)",  strerror(errno), errno);  }
        if (close(pfd2[1]) == EOF) { /* perror("close"); */  TFDebug(@"close, %s (%d)",  strerror(errno), errno);  }
        return TFProcessErrorFcntl;
    }
    
    if (close(pfd2[1]) == EOF)     { /* perror("close"); */  TFDebug(@"close, %s (%d)",  strerror(errno), errno);  }
    
    int fd2 = pfd2[0];
    if (fd2 == -1)                 { /* perror("fileno"); */ TFDebug(@"fileno, %s (%d)", strerror(errno), errno);  }
    int flags2 = fcntl(fd1, F_GETFL, 0); flags2 |= O_NONBLOCK;
    if (fcntl(fd2, F_SETFL, flags2) == -1) {
        // perror("fcntl");
        TFDebug(@"fcntl, %s (%d)", strerror(errno), errno);
        if (close(fd1) == EOF)     { /* perror("close"); */  TFDebug(@"close, %s (%d)",  strerror(errno), errno);  }
        // pfd1[0] already closed
        // pfd1[1] already closed
        if (close(fd2) == EOF)     { /* perror("close"); */  TFDebug(@"close, %s (%d)",  strerror(errno), errno);  }
        // pfd2[0] already closed
        // pfd2[1] already closed
        return TFProcessErrorFcntl;
    }
    
    if (pidp)
        *pidp = pid;
    if (stdoutfdp)
        *stdoutfdp = fd1;
    if (stderrfdp)
        *stderrfdp = fd2;
    
    return pid;
}

int TFProcessClose(pid_t pid, int stdoutfd, int stderrfd) {
    if (close(stdoutfd) == EOF) {
        // perror("fclose");
        TFDebug(@"close, %s (%d)", strerror(errno), errno);
        if (close(stderrfd) == EOF) { /* perror("close"); */ TFDebug(@"close, %s (%d)", strerror(errno), errno); }
        return TFProcessErrorFclose;
    }
    
    if (close(stderrfd) == EOF) {
        // perror("fclose");
        TFDebug(@"close, %s (%d)", strerror(errno), errno);
        return TFProcessErrorFclose;
    }
    
    pid_t w; int status;
    do {
        w = waitpid(pid, &status, WUNTRACED | WCONTINUED);
        if (w == -1) {
            // perror("waitpid");
            TFDebug(@"waitpid %d, %s (%d)", pid, strerror(errno), errno);
            return TFProcessErrorWaitpid;
        }
        
        if (WIFEXITED(status)) {
            TFDebug(@"pid %d exited, status=%d", pid, WEXITSTATUS(status));
        } else if (WIFSIGNALED(status)) {
            TFDebug(@"pid %d killed by signal %d", pid, WTERMSIG(status));
        } else if (WIFSTOPPED(status)) {
            TFDebug(@"pid %d stopped by signal %d", pid, WSTOPSIG(status));
        } else if (WIFCONTINUED(status)) {
            TFDebug(@"pid %d continued", pid);
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    if (WIFEXITED(status)) {
        return TFProcessErrorNone    + WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        return TFProcessErrorKilled  - WTERMSIG(status);
    }
    return TFProcessErrorUnknown;
}

NSArray <NSString *> *TFRunProcessWithOutputs(const char **arglist, int *statusp) {
    int fd1 = 0;
    int fd2 = 0;
    
    pid_t pid = TFProcessOpen(arglist, &pid, &fd1, &fd2);
    if (fd1 <= 0 || fd2 <= 0) {
        return nil;
    }
    
    @autoreleasepool {
        NSMutableData *standardOutputData = [NSMutableData data];
        NSMutableData *standardErrorData = [NSMutableData data];
        
        dispatch_queue_t queue = dispatch_queue_create("ch.xxtou.shell.data", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        dispatch_read(fd1, BUFSIZ, queue, ^(dispatch_data_t  _Nonnull data, int error) {
            NSData *nsData = (NSData *)data;
            if (nsData.length) {
                [standardOutputData appendData:nsData];
            } else if (nsData.length == 0 && error == 0) {
                dispatch_semaphore_signal(sema);
            }
        });
        
        dispatch_read(fd2, BUFSIZ, queue, ^(dispatch_data_t  _Nonnull data, int error) {
            NSData *nsData = (NSData *)data;
            if (nsData.length) {
                [standardErrorData appendData:nsData];
            } else if (nsData.length == 0 && error == 0) {
                dispatch_semaphore_signal(sema);
            }
        });
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        
        int status = TFProcessClose(pid, fd1, fd2);
        if (statusp) {
            *statusp = status;
        }
        
        NSString *standardOutput = [[NSString alloc] initWithData:standardOutputData encoding:NSUTF8StringEncoding] ?: [[NSString alloc] init];
        NSString *standardError = [[NSString alloc] initWithData:standardErrorData encoding:NSUTF8StringEncoding] ?: [[NSString alloc] init];
        
        return @[ [standardOutput copy], [standardError copy] ];
    }
}

NSArray <NSString *> *TFDispatchProcessWithOutputs(const char **arglist, int *statusp, time_t timeout) {
    int fd1 = 0;
    int fd2 = 0;
    
    pid_t pid = TFProcessOpen(arglist, &pid, &fd1, &fd2);
    if (fd1 <= 0 || fd2 <= 0) {
        return nil;
    }
    
    @autoreleasepool {
        NSMutableData *standardOutputData = [NSMutableData data];
        NSMutableData *standardErrorData = [NSMutableData data];
        
        dispatch_queue_t queue = dispatch_queue_create("ch.xxtou.shell.data", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        dispatch_read(fd1, BUFSIZ, queue, ^(dispatch_data_t  _Nonnull data, int error) {
            NSData *nsData = (NSData *)data;
            if (nsData.length) {
                [standardOutputData appendData:nsData];
            } else {
                dispatch_semaphore_signal(sema);
            }
        });
        
        dispatch_read(fd2, BUFSIZ, queue, ^(dispatch_data_t  _Nonnull data, int error) {
            NSData *nsData = (NSData *)data;
            if (nsData.length) {
                [standardErrorData appendData:nsData];
            } else {
                dispatch_semaphore_signal(sema);
            }
        });
        
        long ret;
        if (timeout > 0) {
            ret = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)));
        } else {
            ret = dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }
        
        if (ret != 0) {
            if (kill(pid, SIGKILL) != 0) {
                TFDebug(@"kill, %s (%d)", strerror(errno), errno);
            }
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }
        
        int status = TFProcessClose(pid, fd1, fd2);
        if (statusp) {
            *statusp = status;
        }
        
        NSString *standardOutput = [[NSString alloc] initWithData:standardOutputData encoding:NSUTF8StringEncoding] ?: [[NSString alloc] init];
        NSString *standardError = [[NSString alloc] initWithData:standardErrorData encoding:NSUTF8StringEncoding] ?: [[NSString alloc] init];
        
        return @[ [standardOutput copy], [standardError copy] ];
    }
}

NSArray <NSString *> *TFSystemWithOutputs(const char *ctx, int *statusp) {
    const char *args[] = {
        "/bin/sh",
        "-c",
        ctx,
        NULL
    };
    
    return TFRunProcessWithOutputs(args, statusp);
}

NSArray <NSString *> *TFDispatchWithOutputs(const char *ctx, int *statusp, time_t timeout) {
    const char *args[] = {
        "/bin/sh",
        "-c",
        ctx,
        NULL
    };
    
    return TFDispatchProcessWithOutputs(args, statusp, timeout);
}

NSString *TFEscapeShellArg(NSString *arg) {
    return [arg stringByReplacingOccurrencesOfString:@"\'" withString:@"'\\\''"];
}

BOOL TFFixPermission(NSString *path, uid_t owner, gid_t group, mode_t mode) {
    int status1 = chown(path.UTF8String, owner, group);
    if (status1 != 0) {
        TFDebug(@"fail to change owner: '%s'", TFEscapeShellArg(path).UTF8String);
        return NO;
    }
    int status2 = chmod(path.UTF8String, mode);
    if (status2 != 0) {
        TFDebug(@"fail to change mode: '%s'", TFEscapeShellArg(path).UTF8String);
        return NO;
    }
    return YES;
}

BOOL TFEnsureExist(NSString *path) {
    struct stat _stat;
    if (0 != stat(path.UTF8String, &_stat)) {
        TFDebug(@"fail to stat: '%s', %s", TFEscapeShellArg(path).UTF8String, strerror(errno));
        return NO;
    }
    return YES;
}

BOOL TFCreateDirectoryIfNotExist(NSString *path, BOOL withIntermediateDirectories) {
    struct stat _stat;
    if (0 != stat(path.UTF8String, &_stat)) {
        NSError *error = nil;
        BOOL createSucceed = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:withIntermediateDirectories attributes:@{NSFileOwnerAccountID:@(501),NSFileGroupOwnerAccountID:@(501)} error:&error];
        if (!createSucceed) {
            TFDebug(@"%s", error.localizedDescription.UTF8String);
            return NO;
        }
    }
    return YES;
}

pid_t TFProcessIDOfApplicationCLI(NSString *bid, BOOL reloadFromShell, BOOL killProcess) {
    @autoreleasepool {
        static NSString *cachedOutput = nil;
        if (reloadFromShell || cachedOutput == nil) {
            int status = 0;
            NSArray <NSString *> *outputs = TFSystemWithOutputs("/sbin/launchctl list", &status);
            if (status == 0) {
                cachedOutput = outputs[0];
            }
        }
        assert(cachedOutput != nil);
        
        NSRegularExpression *processRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^(\\d+)\\s*([\\d|\\-]+)\\s*\\S*(%@)\\S*$", [NSRegularExpression escapedPatternForString:bid]] options:NSRegularExpressionAnchorsMatchLines error:nil];
        assert(processRegex);
        
        NSTextCheckingResult *regexResult = [processRegex firstMatchInString:cachedOutput options:kNilOptions range:NSMakeRange(0, cachedOutput.length)];
        if (regexResult.numberOfRanges == 4) {
            NSRange pidRange = [regexResult rangeAtIndex:1];
            NSString *pidText = [cachedOutput substringWithRange:pidRange];
            pid_t pid = [pidText intValue];
            if (pid > 0 && killProcess) {
                kill(pid, SIGKILL);
            }
            return pid;  // OK
        }
        
        return 0;  // NO SUCH PROCESS
    }
}

void TFCopyProcessIDsOfApplicationGREP(NSString *expr, BOOL killProcess, pid_t *_Nonnull *_Nonnull pidpp, int *pidc) {
    @autoreleasepool {
        NSString *command = [NSString stringWithFormat:@"ps -ewwo 'uid,gid,pid,command' | grep '%@' | tr -s ' ' | cut -d' ' -f4", TFEscapeShellArg(expr)];
        
        int status = 0;
        NSArray <NSString *> *outputs = TFSystemWithOutputs(command.UTF8String, &status);
        assert(status == 0);
        
        NSString *standardOutput = outputs[0];
        NSArray <NSString *> *outputLines = [standardOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSMutableArray <NSNumber *> *pidValues = [NSMutableArray arrayWithCapacity:outputLines.count];
        for (NSString *outputLine in outputLines) {
            pid_t pid = [outputLine intValue];
            if (pid > 0) {
                [pidValues addObject:@(pid)];
                if (killProcess) {
                    kill(pid, SIGKILL);
                }
            }
        }
        [pidValues removeLastObject];  // drop the last object (grep itself)
        
        pid_t *pids = (pid_t *)malloc(sizeof(pid_t) * pidValues.count);
        for (NSNumber *pidValue in pidValues) {
            *pids++ = [pidValue intValue];
        }
        
        *pidc = (int)pidValues.count;
        *pidpp = pids;
    }
}

typedef Function<void, const char *, launch_data_t> LaunchDataIterator;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
NS_INLINE
void launch_data_dict_iterate_custom(launch_data_t data, LaunchDataIterator code) {
    launch_data_dict_iterate(data, [](launch_data_t value, const char *name, void *baton) {
        (*static_cast<LaunchDataIterator *>(baton))(name, value);
    }, &code);
}
#pragma clang diagnostic pop

pid_t TFProcessIDOfApplicationXPC(NSString *bid, BOOL stopJobGracefully) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    launch_data_t request = launch_data_new_string(LAUNCH_KEY_GETJOBS);
    launch_data_t response = launch_msg(request);
    launch_data_free(request);
    
    assert(response != NULL && launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY);
    
    pid_t pid = 0;
    launch_data_dict_iterate_custom(response, [=, &bid, &pid, &stopJobGracefully](const char *name, launch_data_t value) {
        
        if (pid != 0)
            return;
        
        if (launch_data_get_type(value) != LAUNCH_DATA_DICTIONARY)
            return;
        
        launch_data_t label = launch_data_dict_lookup(value, LAUNCH_JOBKEY_LABEL);
        if (label == NULL || launch_data_get_type(label) != LAUNCH_DATA_STRING)
            return;
        
        const char *identifier = launch_data_get_string(label);
        if (strncmp(identifier, "UIKitApplication:", 17) == 0) {
            
            const char *real = identifier + 17;
            const char *e = strchr(real, '[');
            
            if (!e)
                return;
            
            int len = (int)(e - real);
            if (strncmp(real, bid.UTF8String, len) != 0)
                return;
            
        } else if (strcmp(identifier, bid.UTF8String) != 0) {
            return;
        }
        
        launch_data_t integer = launch_data_dict_lookup(value, LAUNCH_JOBKEY_PID);
        if (integer == NULL || launch_data_get_type(integer) != LAUNCH_DATA_INTEGER)
            return;
        
        pid = (pid_t)launch_data_get_integer(integer);
        
        if (stopJobGracefully) {
            
            assert(kill(pid, 0) != -1);
            
            launch_data_t msg = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
            bool insert = launch_data_dict_insert(msg, label, LAUNCH_KEY_STOPJOB);
            assert(insert);
            
            launch_data_t ret = launch_msg(msg);
            launch_data_free(msg);
            
            if (ret == NULL)
                return;
            
            launch_data_free(ret);
            
        }
        
    });
    
    return pid;
    
#pragma clang diagnostic pop
}

NSArray <NSString *> *TFCopyRunningUIKitApplications(BOOL includesApple, pid_t *_Nonnull *_Nonnull pidpp, int *pidc)
{
    @autoreleasepool {
        NSMutableArray <NSString *> *bidValues = [NSMutableArray array];
        NSMutableArray <NSNumber *> *pidValues = [NSMutableArray array];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        
        launch_data_t request = launch_data_new_string(LAUNCH_KEY_GETJOBS);
        launch_data_t response = launch_msg(request);
        launch_data_free(request);
        
        assert(response != NULL && launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY);
        
        pid_t pid = 0;
        launch_data_dict_iterate_custom(response, [=](const char *name, launch_data_t value) {
            @autoreleasepool {
                if (pid != 0)
                    return;
                
                if (launch_data_get_type(value) != LAUNCH_DATA_DICTIONARY)
                    return;
                
                launch_data_t label = launch_data_dict_lookup(value, LAUNCH_JOBKEY_LABEL);
                if (label == NULL || launch_data_get_type(label) != LAUNCH_DATA_STRING)
                    return;
                
                const char *identifier = launch_data_get_string(label);
                char *begin = NULL;
                if (strncmp(identifier, "UIKitApplication:", 17) == 0) {
                    
                    const char *real = identifier + 17;
                    const char *e = strchr(real, '[');
                    
                    if (!e)
                        return;
                    
                    begin = strndup(real, e - real);
                    
                    if (!includesApple) {
                        int len = (int)(e - real);
                        if (strncmp(real, "com.apple.", MIN(len, 10)) == 0) {
                            if (begin)
                                free(begin);
                            return;
                        }
                    }
                    
                } else {
                    return;
                }
                
                launch_data_t integer = launch_data_dict_lookup(value, LAUNCH_JOBKEY_PID);
                if (integer == NULL || launch_data_get_type(integer) != LAUNCH_DATA_INTEGER) {
                    if (begin)
                        free(begin);
                    return;
                }
                
                pid_t pid = (pid_t)launch_data_get_integer(integer);
                if (pid == 0) {
                    if (begin)
                        free(begin);
                    return;
                }
                
                if (kill(pid, 0) == EOF) {
                    if (begin)
                        free(begin);
                    return;
                }
                
                if (begin) {
                    [pidValues addObject:@(pid)];
                    [bidValues addObject:[NSString stringWithUTF8String:begin]];
                    
                    free(begin);
                }
            }
        });
        
#pragma clang diagnostic pop
        
        pid_t *pids = (pid_t *)malloc(sizeof(pid_t) * pidValues.count);
        for (NSNumber *pidValue in pidValues) {
            *pids++ = [pidValue intValue];
        }
        
        *pidc = (int)pidValues.count;
        *pidpp = pids;
        
        return [bidValues copy];
    }
}

void TFStopRunningUIKitApplications(BOOL includesApple) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    launch_data_t request = launch_data_new_string(LAUNCH_KEY_GETJOBS);
    launch_data_t response = launch_msg(request);
    launch_data_free(request);
    
    assert(response != NULL && launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY);
    
    pid_t pid = 0;
    launch_data_dict_iterate_custom(response, [=](const char *name, launch_data_t value) {
        
        if (pid != 0)
            return;
        
        if (launch_data_get_type(value) != LAUNCH_DATA_DICTIONARY)
            return;
        
        launch_data_t label = launch_data_dict_lookup(value, LAUNCH_JOBKEY_LABEL);
        if (label == NULL || launch_data_get_type(label) != LAUNCH_DATA_STRING)
            return;
        
        const char *identifier = launch_data_get_string(label);
        if (strncmp(identifier, "UIKitApplication:", 17) == 0) {
            
            const char *real = identifier + 17;
            const char *e = strchr(real, '[');
            
            if (!e)
                return;
            
            if (!includesApple) {
                int len = (int)(e - real);
                if (strncmp(real, "com.apple.", MIN(len, 10)) == 0)
                    return;
            }
            
        } else {
            return;
        }
        
        launch_data_t integer = launch_data_dict_lookup(value, LAUNCH_JOBKEY_PID);
        if (integer == NULL || launch_data_get_type(integer) != LAUNCH_DATA_INTEGER)
            return;
        
        pid_t pid = (pid_t)launch_data_get_integer(integer);
        if (pid == 0)
            return;
        
        if (kill(pid, 0) == EOF)
            return;
        
        launch_data_t msg = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
        bool insert = launch_data_dict_insert(msg, label, LAUNCH_KEY_STOPJOB);
        assert(insert);
        
        launch_data_t ret = launch_msg(msg);
        launch_data_free(msg);
        
        if (ret == NULL)
            return;
        
        launch_data_free(ret);
        
    });
    
#pragma clang diagnostic pop
}
