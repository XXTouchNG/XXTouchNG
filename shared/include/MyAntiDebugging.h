#ifndef MyAntiDebugging_h
#define MyAntiDebugging_h


// Secure EXIT
static
__attribute__((used))
__attribute__((always_inline))
void asm_exit() {
#ifdef __arm64__
    __asm__("mov X0, #0\n"
            "mov w16, #1\n"
            "svc #0x80\n"
            "mov x1, #0\n"
            "mov sp, x1\n"
            "mov x29, x1\n"
            "mov x30, x1\n"
            "ret");
#endif
}

#ifndef DEBUG
// For debugger_ptrace. Ref: https://www.theiphonewiki.com/wiki/Bugging_Debuggers
#import <dlfcn.h>
#import <sys/types.h>

// For debugger_sysctl
#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <sys/types.h>
#import <sys/sysctl.h>

// For ioctl
#import <termios.h>
#import <sys/ioctl.h>

// For task_get_exception_ports
#import <mach/task.h>
#import <mach/mach_init.h>

typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);

#if !defined(PT_DENY_ATTACH)
#define PT_DENY_ATTACH 31
#endif  // !defined(PT_DENY_ATTACH)

/*!
 @brief This is the basic ptrace functionality.
 @link http://www.coredump.gr/articles/ios-anti-debugging-protections-part-1/
 */
NS_INLINE
void debugger_ptrace()
{
    void* handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    ptrace_ptr_t ptrace_ptr = (ptrace_ptr_t)dlsym(handle, "ptrace");
    ptrace_ptr(PT_DENY_ATTACH, 0, 0, 0);
    dlclose(handle);
}

/*!
 @brief This function uses sysctl to check for attached debuggers.
 @link https://developer.apple.com/library/mac/qa/qa1361/_index.html
 @link http://www.coredump.gr/articles/ios-anti-debugging-protections-part-2/
 */
NS_INLINE
bool debugger_sysctl(void)
// Returns true if the current process is being debugged (either
// running under the debugger or has a debugger attached post facto).
{
    int mib[4];
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    
    // Initialize the flags so that, if sysctl fails for some bizarre
    // reason, we get a predictable result.
    
    info.kp_proc.p_flag = 0;
    
    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();
    
    // Call sysctl.
    
    if (sysctl(mib, 4, &info, &info_size, NULL, 0) == -1)
    {
        asm_exit();
    }
    
    // We're being debugged if the P_TRACED flag is set.
    
    return ((info.kp_proc.p_flag & P_TRACED) != 0);
}

/* Set platform binary flag */
#define FLAG_PLATFORMIZE (1 << 1)

/**
 * function for jailbroken iOS 11 by Electra
 *
 * @license GPL-3.0 (cydia) https://github.com/ElectraJailbreak/cydia/blob/master/COPYING
 * @see https://github.com/coolstar/electra/blob/master/docs/getting-started.md
 * @see https://github.com/ElectraJailbreak/cydia/blob/master/cydo.cpp
 */
NS_INLINE
void patch_setuidandplatformize()
{
    void* handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
    if (!handle) return;
    
    // Reset errors
    dlerror();
    
    typedef void (*fix_setuid_prt_t)(pid_t pid);
    fix_setuid_prt_t setuidptr = (fix_setuid_prt_t)dlsym(handle, "jb_oneshot_fix_setuid_now");
    
    typedef void (*fix_entitle_prt_t)(pid_t pid, uint32_t what);
    fix_entitle_prt_t entitleptr = (fix_entitle_prt_t)dlsym(handle, "jb_oneshot_entitle_now");
    
    setuidptr(getpid());
    
    setuid(0);
    
    const char *dlsym_error = dlerror();
    if (dlsym_error) {
        return;
    }
    
    entitleptr(getpid(), FLAG_PLATFORMIZE);
}

#endif  // if not DEBUG

NS_INLINE
void root_anti_debugging(BOOL asSessionLeader)
{
    
    {
#ifndef DEBUG
        if (@available(iOS 12.0, *)) {}
        else {
            patch_setuidandplatformize();
        }
#endif  // if not DEBUG
        setuid(0);
        setgid(0);
        if (asSessionLeader) {
            if (setsid() < 0) {
                CHDebugLogSource(@"%s", strerror(errno));
                asm_exit();
            }
        }
    }
    
#ifndef DEBUG
    
    // If enabled the program should exit with code 055 in GDB
    // Program exited with code 055.
    debugger_ptrace();
    
    // If enabled the program should exit with code 0377 in GDB
    // Program exited with code 0377.
    if (debugger_sysctl())
    {
        asm_exit();
    }
    
    // Another way of calling ptrace.
    // Ref: https://www.theiphonewiki.com/wiki/Kernel_Syscalls
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    syscall(26, 31, 0, 0);
#pragma clang diagnostic pop
    
    // Another way of figuring out if LLDB is attached.
    if (isatty(1)) {
        asm_exit();
    }
    
    // Yet another way of figuring out if LLDB is attached.
    if (!ioctl(1, TIOCGWINSZ)) {
        asm_exit();
    }
    
    // Everything above relies on libraries. It is easy enough to hook these libraries and return the required
    // result to bypass those checks. So here it is implemented in ARM assembly. Not very fun to bypass these.
#ifdef __arm__
    asm volatile (
                  "mov r0, #31\n"
                  "mov r1, #0\n"
                  "mov r2, #0\n"
                  "mov r12, #26\n"
                  "svc #80\n"
                  );
#endif
#ifdef __arm64__
    asm volatile (
                  "mov x0, #26\n"
                  "mov x1, #31\n"
                  "mov x2, #0\n"
                  "mov x3, #0\n"
                  "mov x16, #0\n"
                  "svc #128\n"
                  );
#endif
    
#endif  // if not DEBUG
}

static
__attribute__((used))
__attribute__((always_inline))
void check_svc_integrity() {
    int pid;
    static jmp_buf protectionJMP;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wasm-operand-widths"
#ifdef __arm64__
    __asm__("mov x0, #0\n"
            "mov w16, #20\n"
            "svc #0x80\n"
            "cmp x0, #0\n"
            "b.ne #24\n"
            
            "mov x1, #0\n"
            "mov sp, x1\n"
            "mov x29, x1\n"
            "mov x30, x1\n"
            "ret\n"
            
            "mov %[result], x0\n"
            : [result] "=r" (pid)
            :
            :
            );
    
    if (pid == 0) {
        longjmp(protectionJMP, 1);
    }
#endif
#pragma clang diagnostic pop
}

#if DEBUG
#define assert_safe assert
#else
#define assert_safe(cond) \
do { if (!(cond)) { asm_exit(); exit(EXIT_FAILURE); abort(); do { free(malloc(BUFSIZ)); } while (1); } } while (0)
#endif


#endif  /* MyAntiDebugging_h */

