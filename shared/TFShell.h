#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

    int                     ios_system                          (const char *cmd);

    int                     TFProcessOpen                       (const char *_Nonnull *_Nonnull arglist, pid_t *pidp, int *_Nonnull stdoutfdp, int *_Nonnull stderrfdp);
    int                     TFProcessClose                      (pid_t pid, int stdoutfd, int stderrfd);
    NSArray <NSString *>   *TFRunProcessWithOutputs             (const char *_Nonnull *_Nonnull arglist, int *statusp);
    NSArray <NSString *>   *TFDispatchProcessWithOutputs        (const char *_Nonnull *_Nonnull arglist, int *statusp, time_t timeout);
    NSArray <NSString *>   *TFSystemWithOutputs                 (const char *ctx, int *statusp);
    NSArray <NSString *>   *TFDispatchWithOutputs               (const char *ctx, int *statusp, time_t timeout);

    NSString               *TFEscapeShellArg                    (NSString *arg);

    BOOL                    TFFixPermission                     (NSString *path, uid_t owner, gid_t group, mode_t mode);
    BOOL                    TFEnsureExist                       (NSString *path);
    BOOL                    TFCreateDirectoryIfNotExist         (NSString *path, BOOL withIntermediateDirectories);

    void                    TFCopyProcessIDsOfApplicationGREP   (NSString *expr, BOOL killProcess, pid_t *_Nonnull *_Nonnull pidpp, int *pidc);
    pid_t                   TFProcessIDOfApplicationCLI         (NSString *bid, BOOL reloadFromShell, BOOL killProcess);
    pid_t                   TFProcessIDOfApplicationXPC         (NSString *bid, BOOL stopJobGracefully);

    NSArray <NSString *>   *TFCopyRunningUIKitApplications      (BOOL includesApple, pid_t *_Nonnull *_Nonnull pidpp, int *pidc);
    void                    TFStopRunningUIKitApplications      (BOOL includesApple);

#ifdef __cplusplus
}
#endif
NS_ASSUME_NONNULL_END
