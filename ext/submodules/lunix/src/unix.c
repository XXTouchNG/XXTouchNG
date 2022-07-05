#if HAVE_CONFIG_H
#include "config.h"
#endif

/*
 * P O R T A B L E  S Y S T E M  I N C L U D E S
 *
 * Try to include as much as we can here for documentation purposes.
 * Includes which are spread around makes it difficult to determine which
 * headers are being used, and can make dependency ordering issues more
 * troublesome. (Localized includes makes it easier to determine why they're
 * being used, so it's a trade off.)
 *
 * Non-portable headers are included after the feature detection section.
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
#include <limits.h>       /* INT_MAX INT_MIN NL_TEXTMAX */
#include <stdarg.h>       /* va_list va_start va_arg va_end */
#include <stdint.h>       /* INTPTR_MIN INTPTR_MAX SIZE_MAX intmax_t uintmax_t */
#include <stdlib.h>       /* arc4random(3) calloc(3) _exit(2) exit(3) free(3) getenv(3) getenv_r(3) getexecname(3) getprogname(3) grantpt(3) posix_openpt(3) ptsname(3) realloc(3) setenv(3) strtoul(3) unlockpt(3) unsetenv(3) */
#include <stdio.h>        /* fileno(3) flockfile(3) ftrylockfile(3) funlockfile(3) snprintf(3) */
#include <string.h>       /* memset(3) strcmp(3) strerror_r(3) strsignal(3) strspn(3) strcspn(3) */
#include <signal.h>       /* NSIG struct sigaction sigset_t sigaction(3) sigfillset(3) sigemptyset(3) sigprocmask(2) */
#include <ctype.h>        /* isspace(3) */
#include <time.h>         /* struct tm struct timespec gmtime_r(3) clock_gettime(3) tzset(3) */
#include <errno.h>        /* E* errno program_invocation_short_name */
#include <assert.h>       /* assert(3) static_assert */
#include <math.h>         /* INFINITY NAN ceil(3) fpclassify(3) modf(3) signbit(3) */
#include <float.h>        /* DBL_HUGE DBL_MANT_DIG FLT_HUGE FLT_MANT_DIG FLT_RADIX LDBL_HUGE LDBL_MANT_DIG */
#include <locale.h>       /* LC_* setlocale(3) */

#include <sys/mman.h>     /* MAP_* MCL_* PROT_* mlock(2) mlockall(2) mmap(2) munlock(2) munlockall(2) munmap(2) */
#include <sys/types.h>    /* gid_t mode_t off_t pid_t uid_t */
#include <sys/resource.h> /* RLIMIT_* RUSAGE_SELF struct rlimit struct rusage getrlimit(2) getrusage(2) setrlimit(2) */
#include <sys/socket.h>   /* AF_* SOCK_* struct sockaddr socket(2) */
#include <sys/stat.h>     /* S_ISDIR() */
#include <sys/time.h>     /* struct timeval gettimeofday(2) */
#include <sys/un.h>       /* struct sockaddr_un */
#include <sys/utsname.h>  /* uname(2) */
#include <sys/wait.h>     /* WNOHANG waitpid(2) */
#include <sys/ioctl.h>    /* SIOCGIFCONF SIOCGIFFLAGS SIOCGIFNETMASK SIOCGIFDSTADDR SIOCGIFBRDADDR SIOCGLIFADDR TIOCNOTTY TIOCSCTTY ioctl(2) */
#include <syslog.h>       /* LOG_* closelog(3) openlog(3) setlogmask(3) syslog(3) */
#include <termios.h>      /* tcgetsid(3) */
#include <net/if.h>       /* IF_NAMESIZE struct ifconf struct ifreq */
#include <unistd.h>       /* _PC_NAME_MAX alarm(3) chdir(2) chroot(2) close(2) chdir(2) chown(2) chroot(2) dup2(2) execve(2) execl(2) execlp(2) execvp(2) fork(2) fpathconf(3) getegid(2) geteuid(2) getgid(2) getgroups(2) gethostname(3) getpgid(2) getpgrp(2) getpid(2) getppid(2) getuid(2) isatty(3) issetugid(2) lchown(2) lockf(3) link(2) pathconf(3) pread(2) pwrite(2) rename(2) rmdir(2) setegid(2) seteuid(2) setgid(2) setgroups(2) setpgid(2) setuid(2) setsid(2) symlink(2) sysconf(3) tcgetpgrp(3) tcsetpgrp(3) truncate(2) umask(2) unlink(2) unlinkat(2) */
#include <fcntl.h>        /* AT_* F_* O_* fcntl(2) open(2) openat(2) */
#include <fnmatch.h>      /* FNM_* fnmatch(3) */
#include <pwd.h>          /* struct passwd getpwnam_r(3) */
#include <grp.h>          /* struct group getgrnam_r(3) */
#include <dirent.h>       /* closedir(3) fdopendir(3) opendir(3) readdir_r(3) rewinddir(3) */
#include <arpa/inet.h>    /* inet_ntop(3) ntohs(3) ntohl(3) */
#include <netinet/in.h>   /* __KAME__ IPPROTO_* */
#include <netdb.h>        /* NI_* AI_* gai_strerror(3) getaddrinfo(3) getnameinfo(3) freeaddrinfo(3) */
#include <poll.h>         /* struct pollfd poll(2) */
#include <regex.h>        /* REG_* regex_t regcomp(3) regerror(3) regexec(3) regfree(3) */

#define LUA_COMPAT_5_2 1
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>


/*
 * F E A T U R E  D E T E C T I O N
 *
 * In lieu of external detection do our best to detect features using the
 * preprocessor environment.
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
#ifndef __has_feature
#define __has_feature(...) 0
#endif

#ifndef __has_extension
#define __has_extension(...) 0
#endif

#ifndef __has_warning
#define __has_warning(...) 0
#endif

#ifndef __NetBSD_Prereq__
#define __NetBSD_Prereq__(M, m, p) 0
#endif

#define GNUC_PREREQ(M, m) (__GNUC__ && ((__GNUC__ > M) || (__GNUC__ == M && __GNUC_MINOR__ >= m)))

#if defined __GLIBC_PREREQ
#define GLIBC_PREREQ(M, m) (__GLIBC__ && __GLIBC_PREREQ(M, m) && !__UCLIBC__)
#else
#define GLIBC_PREREQ(M, m) 0
#endif

#define UCLIBC_PREREQ(M, m, p) (__UCLIBC__ && (__UCLIBC_MAJOR__ > M || (__UCLIBC_MAJOR__ == M && __UCLIBC_MINOR__ > m) || (__UCLIBC_MAJOR__ == M && __UCLIBC_MINOR__ == m && __UCLIBC_SUBLEVEL__ >= p)))

/* NB: uClibc defines __GLIBC__ */
#define MUSL_MAYBE (__linux && !__BIONIC__ && !__GLIBC__ && !__UCLIBC__)

#define NETBSD_PREREQ(M, m) __NetBSD_Prereq__(M, m, 0)

#define FREEBSD_PREREQ(M, m) (__FreeBSD_version && __FreeBSD_version >= ((M) * 100000) + ((m) * 1000))

#define SUNOS_PREREQ_5_10 (__sun && _DTRACE_VERSION)
#define SUNOS_PREREQ_5_11 (__sun && F_DUPFD_CLOEXEC)
#define SUNOS_PREREQ(M, m) SUNOS_PREREQ_ ## M ## _ ## m

#define IPHONE_2VER(M, m) (((M) * 10000) + ((m) * 100))
#if defined __IPHONE_OS_VERSION_MIN_REQUIRED
#define IPHONE_PREREQ(M, m) (IPHONE_2VER((M), (m)) <= __IPHONE_OS_VERSION_MIN_REQUIRED)
#else
#define IPHONE_PREREQ(M, m) 0
#endif

#define MACOS_2VER_10_9(M, m, p) (((M) * 100) + ((m) * 10))
#define MACOS_2VER_10_10(M, m, p) (((M) * 10000) + ((m) * 100) + (p))
#define MACOS_PREREQ_10_10(M, m, p) (((M) > 10 || ((M) == 10 && (m) >= 10)) && MACOS_2VER_10_10((M), (m), (p)) <= __MAC_OS_X_VERSION_MIN_REQUIRED)
#define MACOS_PREREQ_10_9(M, m, p) (((M) == 10 && (m) < 10) && MACOS_2VER_10_9((M), (m), (p)) <= __MAC_OS_X_VERSION_MIN_REQUIRED)
#if defined __MAC_OS_X_VERSION_MIN_REQUIRED
#define MACOS_PREREQ(M, m, p) (MACOS_PREREQ_10_10((M), (m), (p)) || MACOS_PREREQ_10_9((M), (m), (p)))
#else
#define MACOS_PREREQ(M, m, p) 0
#endif

#if !HAVE_CONFIG_H

#ifndef HAVE_C___EXTENSION__
#define HAVE_C___EXTENSION__ GNUC_PREREQ(1, 0)
#endif

#ifndef HAVE_C__GENERIC
#define HAVE_C__GENERIC (GNUC_PREREQ(4, 9) || __has_feature(c_generic_selections) || __has_extension(c_generic_selections))
#endif

#ifndef HAVE__STATIC_ASSERT
#define HAVE__STATIC_ASSERT (GNUC_PREREQ(4, 6) || __has_feature(c_static_assert) || __has_extension(c_static_assert))
#endif

#ifndef HAVE_C_FLEXIBLE_ARRAY_MEMBER
#define HAVE_C_FLEXIBLE_ARRAY_MEMBER (__STDC_VERSION__ >= 199901L || __GNUC__)
#endif

#ifndef HAVE_C_STATEMENT_EXPRESSION
#define HAVE_C_STATEMENT_EXPRESSION GNUC_PREREQ(1, 0)
#endif

/* __KAME__ often defined to empty string */
#ifndef HAVE_DECL___KAME__
#if defined __KAME__
#define HAVE_DECL___KAME__ 1
#else
#define HAVE_DECL___KAME__ 0
#endif
#endif

/* NOTE: <sys/stat.h> MUST already be included */
#ifndef HAVE_DECL_ST_ATIME
#if defined st_atime
#define HAVE_DECL_ST_ATIME 1
#else
#define HAVE_DECL_ST_ATIME 0
#endif
#endif

#ifndef HAVE_DECL_ST_ATIMENSEC
#if defined st_atimensec
#define HAVE_DECL_ST_ATIMENSEC 1
#else
#define HAVE_DECL_ST_ATIMENSEC 0
#endif
#endif

#ifndef HAVE_DECL_ST_ATIMESPEC
#if defined st_atimespec
#define HAVE_DECL_ST_ATIMESPEC 1
#else
#define HAVE_DECL_ST_ATIMESPEC 0
#endif
#endif

#ifndef HAVE_DECL_STATIC_ASSERT
#if defined static_assert
#define HAVE_DECL_STATIC_ASSERT 1
#else
#define HAVE_DECL_STATIC_ASSERT 0
#endif
#endif

#ifndef HAVE_MACH_MACH_H
#define HAVE_MACH_MACH_H (__APPLE__)
#endif

#ifndef HAVE_MACH_CLOCK_H
#define HAVE_MACH_CLOCK_H (__APPLE__)
#endif

#ifndef HAVE_MACH_MACH_TIME_H
#define HAVE_MACH_MACH_TIME_H (__APPLE__)
#endif

#ifndef HAVE_SYS_FEATURE_TESTS_H
#define HAVE_SYS_FEATURE_TESTS_H (__sun)
#endif

#ifndef HAVE_SYS_PARAM_H
#define HAVE_SYS_PARAM_H (__OpenBSD__ || __NetBSD__ || __FreeBSD__ || __APPLE__)
#endif

#ifndef HAVE_SYS_PROCFS_H
#define HAVE_SYS_PROCFS_H (_AIX)
#endif

#ifndef HAVE_SYS_SOCKIO_H
#define HAVE_SYS_SOCKIO_H (__sun)
#endif

#ifndef HAVE_SYS_SYSCALL_H
#define HAVE_SYS_SYSCALL_H (BSD || __linux__ || __sun)
#endif

#ifndef HAVE_SYS_SYSCTL_H /* missing on musl libc */
#define HAVE_SYS_SYSCTL_H (BSD || GLIBC_PREREQ(0,0) || UCLIBC_PREREQ(0,0,0))
#endif

#ifndef HAVE_STRUCT_IN_PKTINFO
#define HAVE_STRUCT_IN_PKTINFO HAVE_DECL_IP_PKTINFO
#endif

#ifndef HAVE_STRUCT_IN_PKTINFO_IPI_SPEC_DST
#define HAVE_STRUCT_IN_PKTINFO_IPI_SPEC_DST (HAVE_DECL_IP_PKTINFO && !__NetBSD__)
#endif

#ifndef HAVE_STRUCT_IN6_PKTINFO
#define HAVE_STRUCT_IN6_PKTINFO HAVE_DECL_IPV6_PKTINFO
#endif

#ifndef HAVE_STRUCT_PSINFO
#define HAVE_STRUCT_PSINFO (_AIX)
#endif

#ifndef HAVE_STRUCT_PSINFO_PR_FNAME
#define HAVE_STRUCT_PSINFO_PR_FNAME (HAVE_STRUCT_PSINFO)
#endif

#ifndef HAVE_STRUCT_PSINFO_PR_NLWP
#define HAVE_STRUCT_PSINFO_PR_NLWP (HAVE_STRUCT_PSINFO)
#endif

#ifndef HAVE_STRUCT_STAT_ST_RDEV
#define HAVE_STRUCT_STAT_ST_RDEV 1
#endif

#ifndef HAVE_STRUCT_STAT_ST_BLKSIZE
#define HAVE_STRUCT_STAT_ST_BLKSIZE 1
#endif

#ifndef HAVE_STRUCT_STAT_ST_BLOCKS
#define HAVE_STRUCT_STAT_ST_BLOCKS 1
#endif

#ifndef HAVE_STRUCT_STAT_ST_ATIM
#define HAVE_STRUCT_STAT_ST_ATIM HAVE_DECL_ST_ATIME
#endif

#ifndef HAVE_STRUCT_STAT_ST_MTIM
#define HAVE_STRUCT_STAT_ST_MTIM HAVE_STRUCT_STAT_ST_ATIM
#endif

#ifndef HAVE_STRUCT_STAT_ST_CTIM
#define HAVE_STRUCT_STAT_ST_CTIM HAVE_STRUCT_STAT_ST_ATIM
#endif

#ifndef HAVE_STRUCT_STAT_ST_ATIMESPEC
#define HAVE_STRUCT_STAT_ST_ATIMESPEC (__APPLE__ || HAVE_DECL_ST_ATIMESPEC || HAVE_DECL_ST_ATIMENSEC)
#endif

#ifndef HAVE_STRUCT_STAT_ST_MTIMESPEC
#define HAVE_STRUCT_STAT_ST_MTIMESPEC HAVE_STRUCT_STAT_ST_ATIMESPEC
#endif

#ifndef HAVE_STRUCT_STAT_ST_CTIMESPEC
#define HAVE_STRUCT_STAT_ST_CTIMESPEC HAVE_STRUCT_STAT_ST_ATIMESPEC
#endif

#ifndef HAVE_DECL_CTL_KERN
#define HAVE_DECL_CTL_KERN (HAVE_SYS_SYSCTL_H && __linux)
#endif

#ifndef HAVE_DECL_KERN_RANDOM
#define HAVE_DECL_KERN_RANDOM (HAVE_SYS_SYSCTL_H && __linux)
#endif

#ifndef HAVE_DECL_IP_PKTINFO
#if defined IP_PKTINFO
#define HAVE_DECL_IP_PKTINFO 1
#else
#define HAVE_DECL_IP_PKTINFO 0
#endif
#endif

#ifndef HAVE_DECL_IP_RECVDSTADDR
#if defined IP_RECVDSTADDR
#define HAVE_DECL_IP_RECVDSTADDR 1
#else
#define HAVE_DECL_IP_RECVDSTADDR 0
#endif
#endif

#ifndef HAVE_DECL_IP_SENDSRCADDR
#if defined IP_SENDSRCADDR
#define HAVE_DECL_IP_SENDSRCADDR 1
#else
#define HAVE_DECL_IP_SENDSRCADDR 0
#endif
#endif

#ifndef HAVE_DECL_IPV6_PKTINFO
#if defined IPV6_PKTINFO
#define HAVE_DECL_IPV6_PKTINFO 1
#else
#define HAVE_DECL_IPV6_PKTINFO 0
#endif
#endif

#ifndef HAVE_DECL_IPV6_RECVPKTINFO
#if defined IPV6_RECVPKTINFO
#define HAVE_DECL_IPV6_RECVPKTINFO 1
#else
#define HAVE_DECL_IPV6_RECVPKTINFO 0
#endif
#endif

#ifndef HAVE_DECL_RANDOM_UUID
#define HAVE_DECL_RANDOM_UUID (HAVE_SYS_SYSCTL_H && __linux)
#endif

#ifndef HAVE_DECL_RLIM_SAVED_CUR
#if defined RLIM_SAVED_CUR
#define HAVE_DECL_RLIM_SAVED_CUR 1
#else
#define HAVE_DECL_RLIM_SAVED_CUR 0
#endif
#endif

#ifndef HAVE_DECL_RLIM_SAVED_MAX
#if defined RLIM_SAVED_MAX
#define HAVE_DECL_RLIM_SAVED_MAX 1
#else
#define HAVE_DECL_RLIM_SAVED_MAX 0
#endif
#endif

#ifndef HAVE_DECL_RLIM_AS
#if defined RLIM_AS
#define HAVE_DECL_RLIM_AS 1
#else
#define HAVE_DECL_RLIM_AS 0
#endif
#endif

#ifndef HAVE_DECL_SOCK_CLOEXEC
#if defined SOCK_CLOEXEC
#define HAVE_DECL_SOCK_CLOEXEC 1
#else
#define HAVE_DECL_SOCK_CLOEXEC 0
#endif
#endif

#ifndef HAVE_ACCEPT4
#define HAVE_ACCEPT4 (HAVE_DECL_SOCK_CLOEXEC && (!__NetBSD__ || NETBSD_PREREQ(8,0)))
#endif

#ifndef HAVE_ARC4RANDOM
#define HAVE_ARC4RANDOM (__OpenBSD__ || __FreeBSD__ || __NetBSD__ || __MirBSD__ || __APPLE__)
#endif

#ifndef HAVE_ARC4RANDOM_STIR
#define HAVE_ARC4RANDOM_STIR (HAVE_ARC4RANDOM && (!OpenBSD || OpenBSD < 201405) && !FREEBSD_PREREQ(12,0))
#endif

#ifndef HAVE_ARC4RANDOM_ADDRANDOM
#define HAVE_ARC4RANDOM_ADDRANDOM HAVE_ARC4RANDOM_STIR
#endif

#ifndef HAVE_GETEXECNAME
#define HAVE_GETEXECNAME (__sun)
#endif

#ifndef HAVE_GETPROGNAME
#define HAVE_GETPROGNAME (__OpenBSD__ || __FreeBSD__ || __NetBSD__ || __MirBSD__ || __APPLE__)
#endif

#ifndef HAVE_PIPE2
#define HAVE_PIPE2 (GLIBC_PREREQ(2,9) || FREEBSD_PREREQ(10,0) || NETBSD_PREREQ(6,0) || UCLIBC_PREREQ(0,9,32))
#endif

#ifndef HAVE_DUP3
#define HAVE_DUP3 (GLIBC_PREREQ(2,9) || FREEBSD_PREREQ(10,0) || NETBSD_PREREQ(6,0) || UCLIBC_PREREQ(0,9,34))
#endif

#ifndef HAVE_FDATASYNC
#define HAVE_FDATASYNC (!__APPLE__ && !__FreeBSD__)
#endif

#ifndef HAVE_FDOPENDIR
#define HAVE_FDOPENDIR ((!__APPLE__ || MACOS_PREREQ(10,10,0) || IPHONE_PREREQ(8,0)) && (!__NetBSD__ || NETBSD_PREREQ(6,0)))
#endif

#ifndef HAVE_FMEMOPEN
#define HAVE_FMEMOPEN (!_AIX && !__sun && (!__NetBSD__ || NETBSD_PREREQ(6,0)))
#endif

#ifndef HAVE_FSTATAT
#define HAVE_FSTATAT HAVE_OPENAT
#endif

#ifndef HAVE_ISSETUGID
#define HAVE_ISSETUGID (!__linux && !_AIX)
#endif

#ifndef HAVE_GETAUXVAL
#define HAVE_GETAUXVAL GLIBC_PREREQ(2,16)
#endif

#ifndef HAVE__LIBC_ENABLE_SECURE
#define HAVE__LIBC_ENABLE_SECURE GLIBC_PREREQ(2,1) /* added to glibc between 2.0.98 and 2.0.99 */
#endif

#ifndef HAVE_IFADDRS_H
#define HAVE_IFADDRS_H (!_AIX && (!__sun || SUNOS_PREREQ(5,11)))
#endif

#ifndef HAVE_GETIFADDRS
#define HAVE_GETIFADDRS HAVE_IFADDRS_H
#endif

#ifndef HAVE_SOCKADDR_SA_LEN
#define HAVE_SOCKADDR_SA_LEN (!__linux && !__sun)
#endif

#ifndef HAVE_NETINET_IN6_VAR_H
#define HAVE_NETINET_IN6_VAR_H (_AIX)
#endif

/*
 * Only if we lack <ifaddrs.h>. FreeBSD requires <net/if_var.h> and many
 * other dependencies.
 */
#ifndef HAVE_NETINET6_IN6_VAR_H
#define HAVE_NETINET6_IN6_VAR_H (HAVE_DECL___KAME__ && !HAVE_IFADDRS_H)
#endif

#ifndef HAVE_GETENV_R
#define HAVE_GETENV_R NETBSD_PREREQ(5,0)
#endif

#ifndef HAVE_MKDIRAT
#define HAVE_MKDIRAT HAVE_OPENAT
#endif

#ifndef HAVE_MKFIFOAT
#define HAVE_MKFIFOAT (!__APPLE__ && (!__NetBSD__ || NETBSD_PREREQ(7,0)))
#endif

#ifndef HAVE_OPENAT
#define HAVE_OPENAT ((!__APPLE__ || MACOS_PREREQ(10,10,0) || IPHONE_PREREQ(8,0)) && (!__NetBSD__ || NETBSD_PREREQ(7,0)))
#endif

#ifndef HAVE_PACCEPT
#define HAVE_PACCEPT NETBSD_PREREQ(6,0)
#endif

#ifndef HAVE_POSIX_FADVISE
#define HAVE_POSIX_FADVISE GLIBC_PREREQ(2,2)
#endif

#ifndef HAVE_POSIX_FALLOCATE
#define HAVE_POSIX_FALLOCATE GLIBC_PREREQ(2,2)
#endif

#ifndef HAVE_PROGRAM_INVOCATION_SHORT_NAME
#define HAVE_PROGRAM_INVOCATION_SHORT_NAME (__linux)
#endif

#ifndef HAVE_PTSNAME_R
#define HAVE_PTSNAME_R (GLIBC_PREREQ(2,1) || (MUSL_MAYBE && _GNU_SOURCE))
#endif

#ifndef HAVE_P_XARGV
#define HAVE_P_XARGV (_AIX)
#endif

#ifndef HAVE_DECL_P_XARGV
#define HAVE_DECL_P_XARGV 0
#endif

#ifndef HAVE_READLINKAT
#define HAVE_READLINKAT HAVE_OPENAT
#endif

#ifndef HAVE_RENAMEAT
#define HAVE_RENAMEAT HAVE_OPENAT
#endif

#ifndef HAVE_SIGTIMEDWAIT
#define HAVE_SIGTIMEDWAIT (!__APPLE__ && !__OpenBSD__)
#endif

#ifndef HAVE_SIGWAIT
#define HAVE_SIGWAIT (!__minix)
#endif

#ifndef HAVE_STATIC_ASSERT
#define HAVE_STATIC_ASSERT_ (!GLIBC_PREREQ(0,0) || HAVE__STATIC_ASSERT) /* glibc doesn't check GCC version */
#define HAVE_STATIC_ASSERT (HAVE_DECL_STATIC_ASSERT && HAVE_STATIC_ASSERT_)
#endif

#ifndef HAVE_SYSCALL
#define HAVE_SYSCALL HAVE_SYS_SYSCALL_H
#endif

#ifndef HAVE_SYSCTL
#define HAVE_SYSCTL HAVE_SYS_SYSCTL_H
#endif

#ifndef HAVE_STRSIGNAL
#define HAVE_STRSIGNAL 1
#endif

#ifndef HAVE_SYMLINKAT
#define HAVE_SYMLINKAT HAVE_OPENAT
#endif

#ifndef HAVE_SYS_SIGLIST
#define HAVE_SYS_SIGLIST (!MUSL_MAYBE && !__sun && !_AIX)
#endif

#ifndef HAVE_UNLINKAT
#define HAVE_UNLINKAT HAVE_OPENAT
#endif

#ifndef HAVE_DECL_SYS_SIGLIST
#define HAVE_DECL_SYS_SIGLIST HAVE_SYS_SIGLIST
#endif

#ifndef STRERROR_R_CHAR_P
#define STRERROR_R_CHAR_P ((GLIBC_PREREQ(0,0) || UCLIBC_PREREQ(0,0,0)) && (_GNU_SOURCE || !(_POSIX_C_SOURCE >= 200112L || _XOPEN_SOURCE >= 600)))
#endif

#endif /* !HAVE_CONFIG_H */


/*
 * N O N - P O R T A B L E  S Y S T E M  I N C L U D E S
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
#if HAVE_SYS_FEATURE_TESTS_H
#include <sys/feature_tests.h> /* _DTRACE_VERSION */
#endif

#if HAVE_SYS_PARAM_H
#include <sys/param.h> /* __NetBSD_Version__ OpenBSD __FreeBSD_version */
#endif

#if HAVE_SYS_PROCFS_H && !defined __sun
#include <sys/procfs.h> /* struct psinfo */
#endif

#if HAVE_SYS_SOCKIO_H
#include <sys/sockio.h> /* SIOCGIFCONF SIOCGIFFLAGS SIOCGIFNETMASK SIOCGIFDSTADDR SIOCGIFBRDADDR */
#endif

#if HAVE_SYS_SYSCALL_H
#include <sys/syscall.h> /* SYS_getrandom syscall(2) */
#endif

#if HAVE_SYS_SYSCTL_H
#include <sys/sysctl.h> /* CTL_KERN KERN_RANDOM RANDOM_UUID sysctl(2) */
#endif

#if HAVE_IFADDRS_H
#include <ifaddrs.h> /* struct ifaddrs getifaddrs(3) freeifaddrs(3) */
#endif

#if HAVE_NETINET_IN6_VAR_H
#include <netinet/in6_var.h> /* SIOCGIFADDR6 SIOCGIFNETMASK6 SIOCGIFDSTADDR6 struct in6_ifreq */
#endif

#if HAVE_NETINET6_IN6_VAR_H
#include <netinet6/in6_var.h> /* SIOCGIFADDR_IN6 SIOCGIFNETMASK_IN6 SIOCGIFDSTADDR_IN6 struct in6_ifreq */
#endif

#if HAVE_MACH_MACH_H
#include <mach/mach.h> /* MACH_PORT_NULL KERN_SUCCESS host_name_port_t mach_host_self() mach_task_self() mach_port_deallocate() */
#endif

#if HAVE_MACH_CLOCK_H
#include <mach/clock.h> /* SYSTEM_CLOCK clock_serv_t host_get_block_service() clock_get_time() */
#endif

#if HAVE_MACH_MACH_TIME_H
#include <mach/mach_time.h> /* mach_timebase_info() mach_absolute_time() */
#endif

/*
 * F E A T U R E  D E T E C T I O N  (S T A G E  2)
 *
 * Macros which may require non-portable headers to be pre-included and
 * cannot dely on lazy evluation (e.g. cannot utilize defined statement
 * in macro expansion).
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef HAVE_DECL_SYS_GETRANDOM
#if defined SYS_getrandom
#define HAVE_DECL_SYS_GETRANDOM 1
#else
#define HAVE_DECL_SYS_GETRANDOM 0
#endif
#endif

/*
 * L U A  C O M P A T A B I L I T Y
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
#if LUA_VERSION_NUM < 502

#ifndef LUA_FILEHANDLE
#define LUA_FILEHANDLE "FILE*"
#endif

/*
 * Lua 5.1 userdata is a simple FILE *, while LuaJIT is a struct with the
 * first member a FILE *, similar to Lua 5.2.
 */
typedef struct luaL_Stream {
	FILE *f;
} luaL_Stream;

static int lua_absindex(lua_State *L, int index) {
	return (index > 0 || index <= LUA_REGISTRYINDEX)? index : lua_gettop(L) + index + 1;
} /* lua_absindex() */

#define lua_rawlen lua_objlen

#define lua_rawsetp(...) compatL_rawsetp(__VA_ARGS__)
static void compatL_rawsetp(lua_State *L, int index, const void *p) {
	index = lua_absindex(L, index);
	lua_pushlightuserdata(L, (void *)p);
	lua_pushvalue(L, -2);
	lua_rawset(L, index);
	lua_pop(L, 1);
} /* compatL_rawsetp() */

#define luaL_testudata(...) compatL_testudata(__VA_ARGS__)
static void *compatL_testudata(lua_State *L, int index, const char *tname) {
	void *p = lua_touserdata(L, index);
	int eq;

	if (!p || !lua_getmetatable(L, index))
		return 0;

	luaL_getmetatable(L, tname);
	eq = lua_rawequal(L, -2, -1);
	lua_pop(L, 2);

	return (eq)? p : 0;
}

#define luaL_setmetatable(...) compatL_setmetatable(__VA_ARGS__)
static void compatL_setmetatable(lua_State *L, const char *tname) {
	luaL_getmetatable(L, tname);
	lua_setmetatable(L, -2);
}

#define luaL_setfuncs(...) compatL_setfuncs(__VA_ARGS__)
static void compatL_setfuncs(lua_State *L, const luaL_Reg *l, int nup) {
	int i, t = lua_absindex(L, -1 - nup);

	for (; l->name; l++) {
		for (i = 0; i < nup; i++)
			lua_pushvalue(L, -nup);
		lua_pushcclosure(L, l->func, nup);
		lua_setfield(L, t, l->name);
	}

	lua_pop(L, nup);
}

#ifndef luaL_newlibtable
#define luaL_newlibtable(L, l) \
	lua_createtable(L, 0, (sizeof (l) / sizeof *(l)) - 1)
#endif

#ifndef luaL_newlib
#define luaL_newlib(L, l) \
	(luaL_newlibtable((L), (l)), luaL_setfuncs((L), (l), 0))
#endif

#endif /* LUA_VERSION_NUM < 502 */

#if LUA_VERSION_NUM < 503

#define lua_isinteger(L, index) 0

#define lua_geti(...) compatL_geti(__VA_ARGS__)
static int compatL_geti(lua_State *L, int index, lua_Integer i) {
	index = lua_absindex(L, index);
	lua_pushinteger(L, i);
	lua_gettable(L, index);
	return lua_type(L, -1);
}

#define lua_seti(...) compatL_seti(__VA_ARGS__)
static void compatL_seti(lua_State *L, int index, lua_Integer i) {
	index = lua_absindex(L, index);
	lua_pushinteger(L, i);
	lua_insert(L, -2);
	lua_settable(L, index);
}

#define lua_rawget(...) compatL_rawget(__VA_ARGS__)
static int compatL_rawget(lua_State *L, int index) {
	(lua_rawget)(L, index);
	return lua_type(L, -1);
} /* compatL_rawget() */

#define lua_rawgetp(...) compatL_rawgetp(__VA_ARGS__)
static int compatL_rawgetp(lua_State *L, int index, const void *p) {
	index = lua_absindex(L, index);
	lua_pushlightuserdata(L, (void *)p);
	return lua_rawget(L, index);
} /* compatL_rawgetp() */

#endif /* LUA_VERSION_NUM < 503 */


/*
 * C O M P I L E R  A N N O T A T I O N S  &  C O N S T R U C T S
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef NOTUSED
#if __GNUC__
#define NOTUSED __attribute__((unused))
#else
#define NOTUSED
#endif
#endif

#define MAYBEUSED NOTUSED

#if HAVE_C___EXTENSION__
#define u___extension__ __extension__
#else
#define u___extension__
#endif

#if __clang__ || GNUC_PREREQ(4, 6)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-braces"
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#endif

#if __clang__ || GNUC_PREREQ(4, 6)
#define U_WARN_PUSH _Pragma("GCC diagnostic push")
#define U_WARN_NO_DEPRECATED_DECLARATIONS _Pragma("GCC diagnostic ignored \"-Wdeprecated-declarations\"")
#define U_WARN_NO_SIGN_COMPARE _Pragma("GCC diagnostic ignored \"-Wsign-compare\"")
#define U_WARN_POP _Pragma("GCC diagnostic pop")
#else
#define U_WARN_PUSH
#define U_WARN_NO_DEPRECATED_DECLARATIONS
#define U_WARN_NO_SIGN_COMPARE
#define U_WARN_POP
#endif

#if __has_warning("-Walloc-size-larger-than=") || GNUC_PREREQ(7, 0)
#define U_WARN_NO_ALLOC_SIZE_LARGER_THAN _Pragma("GCC diagnostic ignored \"-Walloc-size-larger-than=\"")
#else
#define U_WARN_NO_ALLOC_SIZE_LARGER_THAN
#endif


/*
 * I N T E G E R  R A N G E  D E T E C T I O N
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#define U_UTPREC(T) (sizeof (T) * CHAR_BIT) /* assumes no padding bits */
#define U_STPREC(T) (U_UTPREC(T) - 1)
#define U_STMAX(T) (((((T)1 << (U_STPREC(T) - 1)) - 1) << 1) + 1)
#define U_STMIN(T) (-U_STMAX(T) - 1) /* assumes two's complement */
#define U_UTMAX(T) (((((T)1 << (U_UTPREC(T) - 1)) - 1) << 1) + 1)

#define U_TMAX(T) (U_ISTSIGNED(T)? U_STMAX(T) : U_UTMAX(T))
#define U_TMIN(T) (U_ISTSIGNED(T)? U_STMIN(T) : (T)0)

#define U_ISTSIGNED(T) ((T)-1 < (T)1)
#define U_ISTFLOAT(T) ((_Bool)(T)0.1 == 1) /* see C11 6.3.1.2 (N1570) */


/*
 * M I S C  &  C O M P A T  R O U T I N E S
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef howmany
#define howmany(x, y) (((x) + ((y) - 1)) / (y))
#endif

#ifndef countof
#define countof(a) (sizeof (a) / sizeof *(a))
#endif

#ifndef endof
#define endof(a) (&(a)[countof(a)])
#endif

#ifndef MIN
#define MIN(a, b) (((a) < (b))? (a) : (b))
#endif

#ifndef MAX
#define MAX(a, b) (((a) > (b))? (a) : (b))
#endif

#ifndef CLAMP
#define CLAMP(i, m, n) (((i) < (m))? (m) : ((i) > (n))? (n) : (i))
#endif

#ifndef XPASTE
#undef PASTE
#define PASTE(x, y) x##y
#define XPASTE(x, y) PASTE(x, y)
#endif

#ifndef STRINGIFY
#define STRINGIFY_(x) #x
#define STRINGIFY(x) STRINGIFY_(x)
#endif

#if HAVE_STATIC_ASSERT
#define u_static_assert(cond, msg) static_assert(cond, msg)
#elif HAVE__STATIC_ASSERT
#define u_static_assert(cond, msg) _Static_assert(cond, msg)
#else
#define u_static_assert(cond, msg) extern char XPASTE(assert_, __LINE__)[u_inline_assert(cond)]
#endif

/* like static_assert but used as an expression instead of declaration */
#define u_inline_assert(cond) (sizeof (int[1 - 2*!(cond)]))

#if defined __GNUC__ && (defined _AIX || (defined __NetBSD__ && !NETBSD_PREREQ(6,0)))
#define U_NAN __builtin_nan("") /* avoid type punning warning */
#else
#define U_NAN NAN
#endif

#define u_ispower2(i) (((i) != 0) && (0 == (((i) - 1) & (i))))

static size_t u_power2(size_t i) {
#if defined SIZE_MAX
	i--;
	i |= i >> 1;
	i |= i >> 2;
	i |= i >> 4;
	i |= i >> 8;
	i |= i >> 16;
#if SIZE_MAX != 0xffffffffu
	i |= i >> 32;
#endif
	return ++i;
#else
#error No SIZE_MAX defined
#endif
} /* u_power2() */


#define u_error_t int

/* this function will always grow the array even if minsiz < *size */
static u_error_t u_realloc(char **buf, size_t *size, size_t minsiz) {
	void *tmp;
	size_t tmpsiz;

	if (*size == (size_t)-1)
		return ENOMEM;

	if (*size > ~((size_t)-1 >> 1)) {
		tmpsiz = (size_t)-1;
	} else {
		tmpsiz = u_power2(*size + 1);
		tmpsiz = MAX(tmpsiz, minsiz);
	}

	if (!(tmp = realloc(*buf, tmpsiz)))
		return errno;

	*buf = tmp;
	*size = tmpsiz;

	return 0;
} /* u_realloc() */


static u_error_t u_growby(char **buf, size_t *size, size_t n) {
	if (~n < *size)
		return ENOMEM;

	return u_realloc(buf, size, *size + n);
} /* u_growby() */


static u_error_t u_appendc(char **buf, size_t *size, size_t *p, int c) {
	int error;

	if (*p < *size) {
		(*buf)[(*p)++] = c;
	} else {
		if ((error = u_growby(buf, size, (*p - *size) + 1)))
			return error;

		(*buf)[(*p)++] = c;
	}

	return 0;
} /* u_appendc() */


static u_error_t u_reallocarray(void **arr, size_t *arrsiz, size_t count, size_t size) {
	void *tmp;
	size_t tmpsiz;

	if (size && count > (size_t)-1 / size)
		return ENOMEM;

	tmpsiz = count * size;

	if (tmpsiz <= *arrsiz)
		return 0;

	if (tmpsiz == (size_t)-1)
		return ENOMEM;

	if (tmpsiz > ~((size_t)-1 >> 1)) {
		tmpsiz = (size_t)-1;
	} else {
		tmpsiz = u_power2(tmpsiz);
	}

	/*
	 * NOTE: -Walloc-size-larger-than diagnostic complains because
	 * u_power2 will saturate to SIZE_MAX on overflow (a path it can
	 * statically trace) and it triggers on anything over SSIZE_MAX.
	 */
	U_WARN_PUSH
	U_WARN_NO_ALLOC_SIZE_LARGER_THAN
	if (!(tmp = realloc(*arr, tmpsiz)))
		return (tmpsiz)? errno : 0;
	U_WARN_POP

	*arr = tmp;
	*arrsiz = tmpsiz;

	return 0;
} /* u_reallocarray() */

#define U_REALLOCARRAY_GENERATE(type, name) \
static u_error_t name(type *arr, size_t *arrsiz, size_t count) { \
	void *tmp = *arr; \
	int error; \
	if ((error = u_reallocarray(&tmp, arrsiz, count, sizeof **arr))) \
		return error; \
	*arr = tmp; \
	return 0; \
}

U_REALLOCARRAY_GENERATE(char **, u_reallocarray_char_pp)
U_REALLOCARRAY_GENERATE(struct pollfd *, u_reallocarray_pollfd)


static void *u_memjunk(void *buf, size_t bufsiz) {
	struct {
		pid_t pid;
		struct timeval tv;
		struct rusage ru;
#if __APPLE__
		uint64_t mt;
#else
		struct timespec mt;
#endif
		struct utsname un;
		uintptr_t aslr;
	} junk;
	struct { const unsigned char *const buf; size_t size, p; } src = { (void *)&junk, sizeof junk, 0 };
	struct { unsigned char *const buf; size_t size, p; } dst = { buf, bufsiz, 0 };

	junk.pid = getpid();
	gettimeofday(&junk.tv, NULL);
	getrusage(RUSAGE_SELF, &junk.ru);
#if __APPLE__
	junk.mt = mach_absolute_time();
#else
	clock_gettime(CLOCK_MONOTONIC, &junk.mt);
#endif
	uname(&junk.un);
	junk.aslr = (uintptr_t)&strcpy ^ (uintptr_t)&u_memjunk;

	while (src.p < src.size || dst.p < dst.size) {
		dst.buf[dst.p % dst.size] ^= src.buf[src.p % src.size];
		++src.p;
		++dst.p;
	}

	return buf;
} /* u_memjunk() */


static socklen_t u_sa_len(const struct sockaddr *sa) {
#if defined SA_LEN
	return SA_LEN(sa);
#elif HAVE_SOCKADDR_SA_LEN
	return sa->sa_len;
#else
	switch (sa->sa_family) {
	case AF_INET:
		return sizeof (struct sockaddr_in);
	case AF_INET6:
		return sizeof (struct sockaddr_in6);
	default:
		return sizeof (struct sockaddr);
	}
#endif
} /* u_sa_len() */


/* derived from KAME source */
MAYBEUSED static void u_in6_prefixlen2mask(struct in6_addr *mask, unsigned prefixlen) {
	unsigned octets, bits;

	if (prefixlen > 128)
		return;

	memset(mask, 0, sizeof *mask);

	octets = prefixlen / 8;
	bits = prefixlen % 8;

	u_static_assert(sizeof mask->s6_addr == 16, "strange s6_addr data type");
	memset(mask, 0xff, octets);

	if (bits)
		mask->s6_addr[octets] = (0xff00 >> bits) & 0xff;
} /* u_in6_prefixlen2mask() */


/* derived from KAME source */
static int u_in6_mask2prefixlen(const struct in6_addr *mask) {
	int i, j;

	u_static_assert(sizeof mask->s6_addr == 16, "strange s6_addr data type");

	for (i = 0; i < 16; i++) {
		for (j = 0; j < 8; j++) {
			if (!((0x80 >> j) & mask->s6_addr[i]))
				return 8 * i + j;
		}
	}

	return 8 * i;
} /* u_in6_mask2prefixlen() */


static int u_in_mask2prefixlen(const struct in_addr *mask) {
	unsigned long addr = ntohl(mask->s_addr);
	int i;

	for (i = 0; i < 32; i++) {
		if (addr & (1UL << i))
			break;
	}

	return 32 - i;
} /* u_in_mask2prefixlen() */


static int u_sa_mask2prefixlen(const struct sockaddr *mask) {
	switch (mask->sa_family) {
	case AF_INET6:
		return u_in6_mask2prefixlen(&((const struct sockaddr_in6 *)mask)->sin6_addr);
	case AF_INET:
		return u_in_mask2prefixlen(&((const struct sockaddr_in *)mask)->sin_addr);
	default:
		return 0;
	}
} /* u_sa_mask2prefixlen() */


#ifndef IN6_IS_SCOPE_LINKLOCAL
#define IN6_IS_SCOPE_LINKLOCAL(in6) (IN6_IS_ADDR_LINKLOCAL(in6) || IN6_IS_ADDR_MC_LINKLOCAL(in6))
#endif

#ifndef IPV6_ADDR_MC_SCOPE
#define IPV6_ADDR_MC_SCOPE(in6) ((in6)->s6_addr[1] & 0x0f)
#endif

#ifndef IPV6_ADDR_SCOPE_INTFACELOCAL
#define IPV6_ADDR_SCOPE_INTFACELOCAL 0x01
#endif

#ifndef IN6_IS_ADDR_MC_INTFACELOCAL
#define IN6_IS_ADDR_MC_INTFACELOCAL(in6) (IN6_IS_ADDR_MULTICAST(in6) || IPV6_ADDR_MC_SCOPE(in6) == IPV6_ADDR_SCOPE_INTFACELOCAL)
#endif

MAYBEUSED static int u_in6_clearscope(struct in6_addr *in6) {
	int modified = 0;

	if (IN6_IS_SCOPE_LINKLOCAL(in6) || IN6_IS_ADDR_MC_INTFACELOCAL(in6)) {
		modified = (in6->s6_addr[2] || in6->s6_addr[3]);
		in6->s6_addr[2] = 0;
		in6->s6_addr[3] = 0;
	}

	return modified;
} /* u_in6_clearscope() */


static _Bool u_isatfd(int fd) {
#if defined AT_FDCWD
	if (fd == AT_FDCWD)
		return 1;
#endif
	return 0;
} /* u_isatfd() */


static int u_f2ms(const double f) {
	double ms;

	switch (fpclassify(f)) {
	case FP_NORMAL:
		/* if negative, assume arithmetic underflow occured */
		if (signbit(f))
			return 0;

		ms = ceil(f * 1000); /* round up so we don't busy poll */

		/* check that INT_MAX + 1 precisely representable by double */
		u_static_assert(FLT_RADIX == 2, "FLT_RADIX value unsupported");
		u_static_assert(u_ispower2((unsigned)INT_MAX + 1), "INT_MAX + 1 not a power of 2");

		if (ms >= (unsigned)INT_MAX + 1)
			return INT_MAX;

		return ms;
	case FP_SUBNORMAL:
		return 1;
	case FP_ZERO:
		return 0;
	case FP_INFINITE:
	case FP_NAN:
	default:
		return -1;
	}
} /* u_f2ms() */

static struct timespec *u_f2ts(struct timespec *ts, const double f) {
	double s, ns;

	switch (fpclassify(f)) {
	case FP_NORMAL:
		/* if negative, assume arithmetic underflow occured */
		if (signbit(f))
			return ts;

		ns = modf(f, &s);
		ns = ceil(ns * 1000000000);

		if (ns >= 1000000000) {
			s++;
			ns = 0;
		}

		/* check that LONG_MAX + 1 precisely representable by double */
		u_static_assert(FLT_RADIX == 2, "FLT_RADIX value unsupported");
		u_static_assert(u_ispower2((unsigned long)LONG_MAX + 1), "LONG_MAX + 1 not a power of 2");

		if (s >= (unsigned long)LONG_MAX + 1) {
			ts->tv_sec = LONG_MAX;
			ts->tv_nsec = 0;
		} else {
			ts->tv_sec = s;
			ts->tv_nsec = ns;
		}

		return ts;
	case FP_SUBNORMAL:
		ts->tv_sec = 0;
		ts->tv_nsec = 1;

		return ts;
	case FP_ZERO:
		ts->tv_sec = 0;
		ts->tv_nsec = 0;

		return ts;
	case FP_INFINITE:
	case FP_NAN:
	default:
		return NULL;
	}
} /* u_f2ts() */

static double u_ts2f(const struct timespec *ts) {
	return ts->tv_sec + (ts->tv_nsec / 1000000000.0);
} /* u_ts2f() */


static double u_tv2f(const struct timeval *tv) {
	return tv->tv_sec + (tv->tv_usec / 1000000.0);
} /* u_tv2f() */


#define ts_timercmp(a, b, cmp) \
	(((a).tv_sec == (b).tv_sec) \
	 ? ((a).tv_nsec cmp (b).tv_nsec) \
	 : ((a).tv_sec cmp (b).tv_sec))

MAYBEUSED static void ts_timeradd(struct timespec *r, struct timespec a, struct timespec b) {
	r->tv_sec = a.tv_sec + b.tv_sec;
	r->tv_nsec = a.tv_nsec + b.tv_nsec;

	if (r->tv_nsec >= 1000000000) {
		r->tv_sec++;
		r->tv_nsec -= 1000000000;
	}
} /* ts_timeradd() */

MAYBEUSED static void ts_timersub(struct timespec *r, struct timespec a, struct timespec b) {
	r->tv_sec = a.tv_sec - b.tv_sec;
	r->tv_nsec = a.tv_nsec - b.tv_nsec;

	if (r->tv_nsec < 0) {
		r->tv_sec--;
		r->tv_nsec += 1000000000;
	}
} /* ts_timersub() */


/*
 * glibc defines sighandler_t as type pointer-to-function, while FreeBSD
 * defines sighandler_t as type function. Which to choose?
 *
 * The sizeof operator cannot be applied to an expression with function
 * type. C99 6.5.3.4p1 (N1256). To be able to do `sizeof (u_sighandler_t)',
 * u_sighandler_t needs to be a pointer type. Furthermore, an expression of
 * type function usually decays to pointer-to-function. C99 6.3.2.1p4. The
 * exceptions are the sizeof and & operators.
 *
 * The upshot of the above notes is that the type of a function in an
 * expression, whether the unary & operator was applied or not, and
 * including when passed as a parameter, is almost always type
 * pointer-to-function. Defining sighandler_t as type pointer-to-function as
 * Linux does makes declarations more concise and is perhaps more
 * convenient.
 *
 * However, I've chosen the FreeBSD method because in the context of casting
 * Lua userdata pointers it more clearly documents that what is being stored
 * and manipulated is a pointer-to-function, not a function. It's possible
 * to load an actual function into a Lua userdata object using methods
 * outside the purview of C, in which case lua_touserdata would return
 * pointer-to-function. But that's not what is expected by our sigaction
 * binding. SIG_DFL, SIG_IGN, and user-defined C handlers can only be
 * manipulated in C as type pointer-to-function. Accordingly, our code
 * expects lua_touserdata to return pointer-to-pointer-to-function.
 */
typedef void u_sighandler_t();

MAYBEUSED static void sa_discard(int signo NOTUSED) {
	return;
} /* sa_discard() */

static u_error_t u_sigtimedwait(int *_signo, const sigset_t *set, siginfo_t *_info, const struct timespec *timeout) {
#if HAVE_SIGTIMEDWAIT
	siginfo_t info;
	int signo;

	*_signo = -1;
	memset(&info, 0, sizeof info);

	if (-1 == (signo = sigtimedwait(set, &info, timeout)))
		return errno;

#if defined __NetBSD__
	/* Some NetBSD versions (5.1, but not 6.1) return 0 on success */
	*_signo = info.si_signo;
#else
	*_signo = signo;
#endif

	if (_info)
		*_info = info;

	return 0;
#elif defined __OpenBSD__
	/*
	 * OpenBSD implements sigwait in libpthread. OpenBSD also requires
	 * libpthread to be loaded at process initialization. But stock Lua
	 * will not have been linked against libpthread. So we use
	 * an alternative sigtimedwait implementation on OpenBSD.
	 *
	 * TODO: Use dlsym to detect if sigwait is available.
	 */
	struct timespec elapsed = { 0, 0 }, req, rem;
	sigset_t pending, unblock, omask;
	struct sigaction act, oact;
	int signo, error;

	*_signo = -1;

	do {
		sigemptyset(&pending);
		sigpending(&pending);

		for (signo = 1; signo < NSIG; signo++) {
			if (!sigismember(set, signo) || !sigismember(&pending, signo))
				continue;

			/*
			 * sigtimedwait and sigwait will atomically clear a
			 * pending signal without delivering the signal.
			 * Emulate that behavior by allowing the signal to
			 * be delivered to our noop signal handler.
			 *
			 * Note that this is definitely not thread-safe.
			 * But OpenBSD leaves us little choice.
			 */
			act.sa_handler = &sa_discard;
			sigfillset(&act.sa_mask);
			act.sa_flags = 0;
			sigaction(signo, &act, &oact);

			sigemptyset(&unblock);
			sigaddset(&unblock, signo);
			sigprocmask(SIG_UNBLOCK, &unblock, &omask);
			sigprocmask(SIG_SETMASK, &omask, NULL);

			sigaction(signo, &oact, NULL);

			if (_info) {
				memset(_info, 0, sizeof *_info);
				_info->si_signo = signo;
			}

			*_signo = signo;

			return 0;
		}

		req.tv_sec = 0;
		req.tv_nsec = 200000000L; /* 2/10ths second */
		rem = req;

		if (0 == nanosleep(&req, &rem)) {
			ts_timeradd(&elapsed, elapsed, req);
		} else if (errno == EINTR) {
			ts_timersub(&req, req, rem);
			ts_timeradd(&elapsed, elapsed, req);
		} else {
			return errno;
		}
	} while (!timeout || ts_timercmp(elapsed, *timeout, <));

	return EAGAIN;
#elif HAVE_SIGWAIT
	struct timespec elapsed = { 0, 0 }, req, rem;
	sigset_t pending;
	int signo, error;

	*_signo = -1;

	do {
		sigemptyset(&pending);
		sigpending(&pending); /* doesn't clear pending queue */

		for (signo = 1; signo < NSIG; signo++) {
			if (!sigismember(set, signo) || !sigismember(&pending, signo))
				continue;

			/*
			 * WARNING: If the signal is in the process's
			 * pending set and another thread clears it, we
			 * could hang forever.
			 *
			 * One possible solution is to raise the signal
			 * here. Raise will add the signal to the thread's
			 * pending set. However, POSIX leaves undefined what
			 * sigwait does when a signal is both in the
			 * thread's and the process's pending set. If the
			 * kernel doesn't clear the signal from both pending
			 * sets, then calling raise won't work.
			 *
			 * Also, calling raise won't work for queued
			 * signals.
			 */
			//raise(signo);

			if ((error = sigwait(set, &signo)))
				return error;

			if (_info) {
				memset(_info, 0, sizeof *_info);
				_info->si_signo = signo;
			}

			*_signo = signo;

			return 0;
		}

		req.tv_sec = 0;
		req.tv_nsec = 200000000L; /* 2/10ths second */
		rem = req;

		if (0 == nanosleep(&req, &rem)) {
			ts_timeradd(&elapsed, elapsed, req);
		} else if (errno == EINTR) {
			ts_timersub(&req, req, rem);
			ts_timeradd(&elapsed, elapsed, req);
		} else {
			return errno;
		}
	} while (!timeout || ts_timercmp(elapsed, *timeout, <));

	return EAGAIN;
#else
	(void)_signo;
	(void)set;
	(void)_info;
	(void)timeout;

	return ENOTSUP;
#endif
} /* u_sigtimedwait() */


static u_error_t u_sigwait(const sigset_t *set, int *signo) {
#if defined __OpenBSD__
	/*
	 * OpenBSD implements sigwait in libpthread, which might not be
	 * loaded. Use our u_sigtimedwait implementation.
	 */
	return u_sigtimedwait(signo, set, NULL, NULL);
#elif HAVE_SIGWAIT
	return sigwait(set, signo);
#else
	return u_sigtimedwait(signo, set, NULL, NULL);
#endif
} /* u_sigwait() */


static size_t u_strlcpy(char *dst, const char *src, size_t lim) {
	size_t len, n;

	len = strlen(src);

	if (lim > 0) {
		n = MIN(lim - 1, len);
		memcpy(dst, src, n);
		dst[n] = '\0';
	}

	return len;
} /* u_strlcpy() */


static u_error_t u_strcpy(char *dst, const char *src, size_t lim) {
	if (u_strlcpy(dst, src, lim) >= lim)
		return EOVERFLOW;

	return 0;
} /* u_strcpy() */


static u_error_t u_snprintf(void *dst, size_t lim, const char *fmt, ...) {
	va_list ap;
	int n, error;

	va_start(ap, fmt);

	if (0 > (n = vsnprintf(dst, lim, fmt, ap))) {
		error = errno;
	} else if ((size_t)n >= lim) {
		error = EOVERFLOW;
	} else {
		error = 0;
	}

	va_end(ap);

	return error;
} /* u_snprintf() */


static u_error_t u_strerror_r(int error, char *dst, size_t lim) {
#if STRERROR_R_CHAR_P
	char *src;

	if (!(src = strerror_r(error, dst, lim)))
		return EINVAL;

	if (src != dst && lim > 0) {
		size_t n = strnlen(src, lim - 1);
		memcpy(dst, src, n);
		dst[n] = '\0';
	}

	return 0;
#else
	/* glibc between 2.3.4 and 2.13 returns -1 on error */
	if (-1 == (error = strerror_r(error, dst, lim)))
		return errno;
	else
		return error;
#endif
} /* u_strerror_r() */


/*
 * T H R E A D - S A F E  I / O  O P E R A T I O N S
 *
 * Principally we're concerned with atomically setting the
 * FD_CLOEXEC/O_CLOEXEC flag. O_CLOEXEC was added to POSIX 2008 and the BSDs
 * took awhile to catch up. But POSIX only defined it for open(2). Some
 * systems have non-portable extensions to support O_CLOEXEC for pipe
 * and socket creation.
 *
 * Also, very old systems do not support modern O_NONBLOCK semantics on
 * open. As it's easy to cover this case we do, otherwise such old systems
 * are beyond our purview.
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef O_CLOEXEC
#define U_CLOEXEC (1LL << 32)
#else
#define U_CLOEXEC (O_CLOEXEC)
#endif

#define U_SYSFLAGS ((1LL << 32) - 1)
#define U_FIXFLAGS (U_CLOEXEC|O_NONBLOCK)
#define U_FDFLAGS  (U_CLOEXEC)  /* file descriptor flags */
#define U_FLFLAGS  (~U_FDFLAGS) /* file status flags */

#define U_FLAGS_MIN LLONG_MIN
#define U_FLAGS_MAX LLONG_MAX
#define u_flags_t long long


/* u_close_nocancel(fd:int)
 *
 * Deterministic close(2) wrapper which safely handles signal
 * interruption[1] and pthread cancellations[2]
 *
 * [1] http://austingroupbugs.net/view.php?id=529
 * [2] https://bugs.chromium.org/p/chromium/issues/detail?id=269623
 */
static u_error_t u_close_nocancel(int fd) {
	int _errno, error;

	_errno = errno;
#if __APPLE__
	extern int close$NOCANCEL(int);
	error = (0 == close$NOCANCEL(fd))? 0 : errno;
#elif __hpux__
	do {
		error = (0 == close(fd))? 0 : errno;
	} while (error == EINTR);
#else
	error = (0 == close(fd))? 0 : errno;
#endif
	errno = _errno;

	return (error == EINTR)? 0 : error;
} /* u_close_nocancel() */


/*
 * NB: This is an awkward function written before settling on a consistent
 * naming scheme; it should have been named something else.
 */
static u_error_t u_close(int *fd) {
	int error;

	if (*fd == -1)
		return errno;

	error = errno;

	(void)u_close_nocancel(*fd);
	*fd = -1;

	errno = error;

	return error;
} /* u_close() */


static u_error_t u_setflag(int fd, u_flags_t flag, int enable) {
	int flags;

	if (flag & U_CLOEXEC) {
		if (-1 == (flags = fcntl(fd, F_GETFD)))
			return errno;

		if (enable)
			flags |= FD_CLOEXEC;
		else
			flags &= ~FD_CLOEXEC;

		if (0 != fcntl(fd, F_SETFD, flags))
			return errno;
	} else {
		if (-1 == (flags = fcntl(fd, F_GETFL)))
			return errno;

		if (enable)
			flags |= flag;
		else
			flags &= ~flag;

		if (0 != fcntl(fd, F_SETFL, flags))
			return errno;
	}

	return 0;
} /* u_setflag() */


static u_error_t u_getflags(int fd, u_flags_t *flags) {
	int _flags;

	if (-1 == (_flags = fcntl(fd, F_GETFL)))
		return errno;

	*flags = _flags;

	/* F_GETFL isn't defined to return O_CLOEXEC */
	if (!(*flags & U_CLOEXEC)) {
		if (-1 == (_flags = fcntl(fd, F_GETFD)))
			return errno;

		if (_flags & FD_CLOEXEC)
			*flags |= U_CLOEXEC;
	}

	return 0;
} /* u_getflags() */


static u_error_t u_getaccmode(int fd, u_flags_t *oflags, u_flags_t flags) {
	u_flags_t _flags;

	if (O_ACCMODE & (*oflags = flags))
		return 0;

	if (-1 == (_flags = fcntl(fd, F_GETFL)))
		return errno;

	*oflags |= _flags & (O_ACCMODE|O_APPEND);

	return 0;
} /* u_getaccmode() */


static u_error_t u_fixflags(int fd, u_flags_t flags) {
	u_flags_t _flags = 0;
	int error;

	if (flags & U_FIXFLAGS) {
		if ((error = u_getflags(fd, &_flags)))
			return error;

		if ((flags & U_CLOEXEC) && !(_flags & U_CLOEXEC)) {
			if ((error = u_setflag(fd, U_CLOEXEC, 1)))
				return error;
		}

		if ((flags & O_NONBLOCK) && !(_flags & O_NONBLOCK)) {
			if ((error = u_setflag(fd, O_NONBLOCK, 1)))
				return error;
		}
	}

	return 0;
} /* u_fixflags() */


static void u_freeaddrinfo(struct addrinfo **res) {
	if (*res) {
		freeaddrinfo(*res);
		*res = NULL;
	}
} /* u_freeaddrinfo() */


static u_error_t u_open(int *fd, const char *path, u_flags_t flags, mode_t mode) {
	int error;

	if (-1 == (*fd = open(path, (U_SYSFLAGS & flags), mode)))
		goto syerr;

	/*
	 * NB: O_NONBLOCK on open is only relevant for named FIFOs. It means
	 * don't block waiting for a reader or writer on the other end. It
	 * doesn't mean put the descriptor into non-blocking mode for any
	 * I/O operations.
	 */
	flags &= ~O_NONBLOCK;

	/*
	 * These should already be set, but if this assumption is proven
	 * wrong in the future, keep this case separate from O_NONBLOCK.
	 */
	flags &= ~U_SYSFLAGS;

	if ((error = u_fixflags(*fd, flags)))
		goto error;

	return 0;
syerr:
	error = errno;
error:
	u_close(fd);

	return error;
} /* u_open() */


static u_error_t u_pipe(int *fd, u_flags_t flags) {
	int ok, i, error;

#if HAVE_PIPE2
	ok = (0 == pipe2(fd, flags));
	flags &= ~(U_CLOEXEC|O_NONBLOCK);
#else
	ok = (0 == pipe(fd));
#endif

	if (!ok) {
		fd[0] = -1;
		fd[1] = -1;

		return errno;
	}

	for (i = 0; i < 2; i++) {
		if ((error = u_fixflags(fd[i], flags))) {
			u_close(&fd[0]);
			u_close(&fd[1]);

			return error;
		}
	}

	return 0;
} /* u_pipe() */


static u_error_t u_dup2(int fd, int fd2, u_flags_t flags) {
	int error;

	/*
	 * NB: Set the file status flags first because we won't be able
	 * roll-back state after dup'ing the descriptor.
	 *
	 * Why? On error we would want to close the new descriptor to avoid
	 * a descriptor leak. But we wouldn't want to close the descriptor
	 * if it was already open. (That would be unsafe for countless
	 * reasons.) But there's no thread-safe way to know whether the
	 * descriptor number was open or not at the time of the dup--that's
	 * a classic TOCTTOU problem.
	 *
	 * Because the new descriptor will share the same file status flags,
	 * the most robust thing to do is to try to set them first. Then
	 * we'll set the file descriptor flags last and ignore any errors.
	 * It would be odd if any implementation had a failure mode setting
	 * descriptor flags, anyhow. (By contrast, status flags could easily
	 * fail--O_NONBLOCK might be rejected for certain file types.)
	 */
	if ((error = u_fixflags(fd, U_FLFLAGS & flags)))
		return error;

	flags &= ~U_FLFLAGS;

#if HAVE_DUP3
	if (-1 == dup3(fd, fd2, U_SYSFLAGS & flags))
		return errno;

	flags &= ~U_CLOEXEC; /* dup3 might not handle any other flags */
#elif defined F_DUP2FD && defined F_DUP2FD_CLOEXEC
	if (-1 == fcntl(fd, (flags & U_CLOEXEC)? F_DUP2FD_CLOEXEC : F_DUP2FD, fd2))
		return errno;

	flags &= ~U_CLOEXEC;
#else
	if (-1 == dup2(fd, fd2))
		return errno;
#endif

	(void)u_fixflags(fd2, flags);

	return 0;
} /* u_dup2() */


/*
 * NB: There aren't any systems with dup3(2) but not F_DUPFD_CLOEXEC, so we
 * don't bother trying to duplicate F_DUPFD_CLOEXEC using dup3(2).
 */
static u_error_t u_dup(int *fd, int ofd, u_flags_t flags) {
	int cmd, error;

#if defined F_DUPFD_CLOEXEC
	cmd = (flags & U_CLOEXEC)? F_DUPFD_CLOEXEC : F_DUPFD;
	flags &= ~U_CLOEXEC;
#else
	cmd = F_DUPFD;
#endif

	if (-1 == (*fd = fcntl(ofd, cmd, 0)))
		goto syerr;

	if ((error = u_fixflags(*fd, flags)))
		goto error;

	return 0;
syerr:
	error = errno;
error:
	u_close(fd);

	return error;
} /* u_dup() */


MAYBEUSED static u_error_t u_socket(int *fd, int family, int type, int proto, u_flags_t flags) {
	int error;

#if defined SOCK_CLOEXEC
	if (flags & U_CLOEXEC)
		type |= SOCK_CLOEXEC;

	if (type & SOCK_CLOEXEC) /* may have been set by caller */
		flags &= ~U_CLOEXEC;
#endif

#if defined SOCK_NONBLOCK
	if (flags & O_NONBLOCK)
		type |= SOCK_NONBLOCK;

	if (type & SOCK_NONBLOCK)
		flags &= ~O_NONBLOCK;
#endif

	if (-1 == (*fd = socket(family, type, proto)))
		return errno;

	if ((error = u_fixflags(*fd, flags))) {
		u_close(fd);

		return error;
	}

	return 0;
} /* u_socket() */


static u_error_t u_fdopendir(DIR **dp, int *fd, _Bool nodup MAYBEUSED) {
#if HAVE_FDOPENDIR
	int error;

	*dp = NULL;

	if ((error = u_setflag(*fd, U_CLOEXEC, 1)))
		return error;

	if (!(*dp = fdopendir(*fd)))
		return errno;

	*fd = -1;

	return 0;
#else
	static const char *const local[] = { ".", "/tmp", "/dev" };
	const char *const *path;
	struct stat st;
	int fd2, error;

	*dp = NULL;

	if (nodup)
		return ENOTSUP;

	if (0 != fstat(*fd, &st))
		goto syerr;

	if (!S_ISDIR(st.st_mode)) {
		error = ENOTDIR;

		goto error;
	}

	for (path = local; path < endof(local); path++) {
		if ((*dp = opendir(*path)))
			break;
	}

	if (!*dp)
		goto syerr;

	if (-1 == (fd2 = dirfd(*dp)))
		goto syerr;

	if ((error = u_dup2(*fd, fd2, U_CLOEXEC)))
		goto error;

	if (-1 == lseek(fd2, 0, SEEK_SET))
		goto syerr;

	u_close(fd);

	return 0;
syerr:
	error = errno;
error:
	if (*dp) {
		closedir(*dp);
		*dp = NULL;
	}

	return error;
#endif
} /* u_fdopendir() */


/* convert fcntl flags to fopen/fdopen mode string */
#define U_MODESTRLEN 8

#define u_strmode_(flags, dst, lim, ...) u_strmode((flags), (dst), (lim))
#define u_strmode(...) u_strmode_(__VA_ARGS__, &(char[U_MODESTRLEN]){ 0 }, U_MODESTRLEN)

static const char *(u_strmode)(u_flags_t flags, void *dst, size_t lim) {
	char mode[U_MODESTRLEN], *p = mode;

	if (flags & O_APPEND) {
		*p++ = 'a';

		if (O_WRONLY != (flags & O_ACCMODE))
			*p++ = '+';
	} else if (O_RDONLY == (flags & O_ACCMODE)) {
		*p++ = 'r';
	} else if (O_WRONLY == (flags & O_ACCMODE)) {
		*p++ = 'w';
	} else if (O_RDWR == (flags & O_ACCMODE)) {
		*p++ = 'r';
		*p++ = '+';
	}

	if (flags & O_EXCL)
		*p++ = 'x';

	*p = '\0';

	assert(lim >= sizeof mode);
	u_strlcpy(dst, mode, lim);

	return dst;
} /* u_strmode() */


static u_flags_t u_toflags(const char *mode) {
	u_flags_t accmode = 0;
	u_flags_t flags = 0;
	int ch;

	while ((ch = *mode++)) {
		switch (ch) {
		case 'a':
			accmode = O_APPEND|O_WRONLY;

			if (*mode == '+') {
				accmode |= O_CREAT;
				mode++;
			}

			break;
		case 'b':
			break;
		case 'e':
			flags |= U_CLOEXEC;

			break;
		case 'r':
			if (*mode == '+') {
				accmode = O_RDWR;
				mode++;
			} else {
				accmode = O_RDONLY;
			}

			break;
		case 'w':
			accmode = O_CREAT|O_TRUNC;

			if (*mode == '+') {
				accmode |= O_RDWR;
				mode++;
			} else {
				accmode |= O_WRONLY;
			}

			break;
		case 'x':
			flags |= O_EXCL;

			break;
		default:
			if (!isalpha((unsigned char)ch))
				goto done;

			break;
		}
	}
done:
	return accmode | flags;
} /* u_toflags() */


static int u_fdopen(FILE **fp, int *fd, const char *mode, u_flags_t flags) {
	char mbuf[U_MODESTRLEN];
	int error;

	if (!mode) {
		if ((error = u_getaccmode(*fd, &flags, flags)))
			return error;

		mode = u_strmode(flags, mbuf, sizeof mbuf);
	}

	if ((error = u_fixflags(*fd, flags)))
		return error;

	if (!(*fp = fdopen(*fd, mode)))
		return errno;

	*fd = -1;

	return 0;
} /* u_fdopen() */


#if HAVE_GETIFADDRS

#define u_ifaddrs ifaddrs

static u_error_t u_getifaddrs(struct u_ifaddrs **ifs) {
	return (0 == getifaddrs(ifs))? 0 : errno;
} /* u_getifaddrs() */

static void u_freeifaddrs(struct u_ifaddrs *ifs) {
	freeifaddrs(ifs);
} /* u_freeifaddrs() */

#else

#undef ifa_dstaddr

struct u_ifaddrs {
	struct u_ifaddrs *ifa_next;
	char ifa_name[MAX(IF_NAMESIZE, sizeof ((struct ifreq *)0)->ifr_name)];
	unsigned int ifa_flags;
	struct sockaddr *ifa_addr;
	struct sockaddr *ifa_netmask;
	struct sockaddr *ifa_dstaddr;

	struct sockaddr_storage ifa_ss[3];
}; /* struct u_ifaddrs */


static void u_freeifaddrs(struct u_ifaddrs *ifs) {
	struct u_ifaddrs *ifa, *nxt;

	for (ifa = ifs; ifa; ifa = nxt) {
		nxt = ifa->ifa_next;
		free(ifa);
	}
} /* if_freeifaddrs() */


#define U_IFREQ_MAXSIZE (sizeof (struct ifreq) - sizeof (struct sockaddr) + sizeof (struct sockaddr_storage))

static u_error_t u_getifconf(struct ifconf *ifc, int fd) {
	char *buf = NULL;
	size_t bufsiz;
	int error;

	ifc->ifc_buf = NULL;
	ifc->ifc_len = 0;

	do {
		bufsiz = (size_t)ifc->ifc_len + U_IFREQ_MAXSIZE;

		/* check for arithmetic overflow when adding sizeof sockaddr_storage */
		if (bufsiz < U_IFREQ_MAXSIZE)
			goto range;

		if ((error = u_realloc(&buf, &bufsiz, MAX(256, bufsiz))))
			goto error;

		/* ifc->ifc_len is usually an int; be careful of undefined conversion */
		if (bufsiz > INT_MAX)
			goto range;

		memset(buf, 0, bufsiz);

		ifc->ifc_buf = (void *)buf;
		ifc->ifc_len = bufsiz;

		if (-1 == ioctl(fd, SIOCGIFCONF, (void *)ifc))
			goto syerr;
	} while (bufsiz - U_IFREQ_MAXSIZE < (size_t)ifc->ifc_len);

	return 0;
range:
	error = ERANGE;
	goto error;
syerr:
	error = errno;
error:
	free(buf);
	ifc->ifc_buf = NULL;
	ifc->ifc_len = 0;

	return error;
} /* u_getifconf() */


#if HAVE_SOCKADDR_SA_LEN && !defined __NetBSD__
/*
 * On most systems with sa_len struct ifreq objects are variable length.
 */
#define U_SIZEOF_ADDR_IFREQ(ifr) /* from OS X <net/if.h> */ \
	(((ifr)->ifr_addr.sa_len > sizeof (struct sockaddr)) \
		? (sizeof (struct ifreq) - sizeof (struct sockaddr) + (ifr)->ifr_addr.sa_len) \
		: (sizeof (struct ifreq)))
#else
/*
 * On systems without sa_len ioctl(SIOCGIFCONF) only returns AF_INET
 * addresses, which always fits within a struct sockaddr.
 *
 * On NetBSD struct ifreq can fit addresses of any type and isn't variable
 * length.
 */
#define U_SIZEOF_ADDR_IFREQ(ifr) (sizeof (struct ifreq))
#endif


static void *u_sa_copy(struct sockaddr_storage *ss, const struct sockaddr *sa) {
	size_t salen = u_sa_len(sa);
	return memcpy(ss, sa, MIN(sizeof *ss, salen));
} /* u_sa_copy() */


#if defined SIOCGIFADDR6 && !defined u_getif6

#define u_getif6 u_getif6_aix

static u_error_t u_getif6_aix(struct u_ifaddrs *ifa, int fd, const struct ifreq *ifr) {
	struct in6_ifreq ifr6 = { 0 };

	u_static_assert(sizeof ifr6.ifr_name >= sizeof ifr->ifr_name, "sizeof ifr6_name < sizeof ifr_name");
	memcpy(ifr6.ifr_name, ifr->ifr_name, MIN(sizeof ifr6.ifr_name, sizeof ifr->ifr_name));
	memcpy(&ifr6.ifr_Addr, ifa->ifa_addr, sizeof ifr6.ifr_Addr);

	if (-1 != ioctl(fd, SIOCGIFNETMASK6, &ifr6)) {
		ifr6.ifr_Addr.sin6_family = AF_INET6; /* not set on AIX */
		ifa->ifa_netmask = u_sa_copy(&ifa->ifa_ss[1], (struct sockaddr *)&ifr6.ifr_Addr);
	}

	if (-1 != ioctl(fd, SIOCGIFDSTADDR6, &ifr6)) {
		ifr6.ifr_Addr.sin6_family = AF_INET6; /* unable to test if AIX sets family; see above */
		ifa->ifa_dstaddr = u_sa_copy(&ifa->ifa_ss[2], (struct sockaddr *)&ifr6.ifr_Addr);
	}

	return 0;
} /* u_getif6_aix() */

#endif


#if defined SIOCGIFADDR_IN6 && !defined u_getif6

#define u_getif6 u_getif6_kame_in6

static u_error_t u_getif6_kame_in6(struct u_ifaddrs *ifa, int fd, const struct ifreq *ifr) {
	struct in6_ifreq ifr6 = { 0 };

	u_static_assert(sizeof ifr6.ifr_name >= sizeof ifr->ifr_name, "sizeof ifr6_name < sizeof ifr_name");
	memcpy(ifr6.ifr_name, ifr->ifr_name, MIN(sizeof ifr6.ifr_name, sizeof ifr->ifr_name));
	memcpy(&ifr6.ifr_addr, ifa->ifa_addr, sizeof ifr6.ifr_addr);

	if (-1 != ioctl(fd, SIOCGIFNETMASK_IN6, &ifr6))
		ifa->ifa_netmask = u_sa_copy(&ifa->ifa_ss[1], (struct sockaddr *)&ifr6.ifr_addr);

	if (-1 != ioctl(fd, SIOCGIFDSTADDR_IN6, &ifr6))
		ifa->ifa_dstaddr = u_sa_copy(&ifa->ifa_ss[2], (struct sockaddr *)&ifr6.ifr_addr);

	return 0;
} /* u_getif6_kame_in6() */

#endif


/*
 * Solaris uses struct lifreq with SIOCGLIFADDR. See u_getif6_sun_glif.
 */
#if defined SIOCGLIFADDR && !defined __sun && !defined u_getif6

#define u_getif6 u_getif6_kame_glif

static u_error_t u_getif6_kame_glif(struct u_ifaddrs *ifa, int fd, const struct ifreq *ifr) {
	struct if_laddrreq iflr = { 0 };

	u_static_assert(sizeof iflr.iflr_name >= sizeof ifr->ifr_name, "sizeof iflr_name < sizeof ifr_name");
	memcpy(iflr.iflr_name, ifr->ifr_name, MIN(sizeof iflr.iflr_name, sizeof ifr->ifr_name));
	u_sa_copy(&iflr.addr, ifa->ifa_addr);

	/*
	 * NOTE: To get the same [shortest] prefixlen as SIOCGIFNETMASK_IN6
	 * or ifconfig(1) for link-local addresses we must request a prefix
	 * match.
	 *
	 * See SIOCGLIFADDR cases in KAME netinet6/in6.c:in6_lifaddr_ioctl.
	 */
#if defined IFLR_PREFIX
	iflr.flags = IFLR_PREFIX;
	iflr.prefixlen = 128;
	u_in6_clearscope(&((struct sockaddr_in6 *)&iflr.addr)->sin6_addr);
#endif

	if (-1 != ioctl(fd, SIOCGLIFADDR, &iflr)) {
		struct sockaddr_in6 *mask = (struct sockaddr_in6 *)&ifa->ifa_ss[1];
#if HAVE_SOCKADDR_SA_LEN
		mask->sin6_len = sizeof *mask;
#endif
		mask->sin6_family = AF_INET6;
		u_in6_prefixlen2mask(&mask->sin6_addr, iflr.prefixlen);
		ifa->ifa_netmask = (struct sockaddr *)mask;

		if (iflr.dstaddr.ss_family == AF_INET6)
			ifa->ifa_dstaddr = u_sa_copy(&ifa->ifa_ss[2], (struct sockaddr *)&iflr.dstaddr);
	}

	return 0;
} /* u_getif6_kame_glif() */
#endif


#if defined SIOCGLIFADDR && defined __sun && !defined u_getif6

#define u_getif6 u_getif6_sun_glif

static u_error_t u_getif6_sun_glif(struct u_ifaddrs *ifa, int fd, const struct ifreq *ifr) {
	struct lifreq lifr = { 0 };

	u_static_assert(sizeof lifr.lifr_name >= sizeof ifr->ifr_name, "sizeof iflr_name < sizeof ifr_name");
	memcpy(lifr.lifr_name, ifr->ifr_name, MIN(sizeof lifr.lifr_name, sizeof ifr->ifr_name));
	u_sa_copy(&lifr.lifr_addr, ifa->ifa_addr);

	if (-1 != ioctl(fd, SIOCGLIFNETMASK, &lifr)) {
		ifa->ifa_netmask = u_sa_copy(&ifa->ifa_ss[1], (struct sockaddr *)&lifr.lifr_dstaddr);
	}

	if (-1 != ioctl(fd, SIOCGLIFDSTADDR, &lifr)) {
		ifa->ifa_dstaddr = u_sa_copy(&ifa->ifa_ss[2], (struct sockaddr *)&lifr.lifr_dstaddr);
	}

	if (-1 != ioctl(fd, SIOCGLIFBRDADDR, &lifr)) {
		ifa->ifa_dstaddr = u_sa_copy(&ifa->ifa_ss[2], (struct sockaddr *)&lifr.lifr_broadaddr);
	}

	return 0;
} /* u_getif6_sun_glif() */
#endif


static u_error_t u_getifaddrs(struct u_ifaddrs **ifs) {
	int fd = -1, fd6 = -1;
	struct ifconf ifc = { 0 };
	struct ifreq *ifr, *end;
	struct u_ifaddrs *ifa, *prv;
	size_t ifrsiz;
	int error;

	*ifs = NULL;

	if ((error = u_socket(&fd, AF_INET, SOCK_DGRAM, PF_UNSPEC, U_CLOEXEC)))
		goto error;

	if ((error = u_getifconf(&ifc, fd)))
		goto error;

	ifr = (struct ifreq *)ifc.ifc_buf;
	end = (struct ifreq *)((char *)ifc.ifc_buf + ifc.ifc_len);

	prv = NULL;

	while (ifr < end) {
		ifrsiz = U_SIZEOF_ADDR_IFREQ(ifr);

		if (!(ifa = calloc(1, sizeof *ifa)))
			goto syerr;

		u_static_assert(sizeof ifa->ifa_name >= sizeof ifr->ifr_name, "sizeof ifa_name < sizeof ifr_name");
		memcpy(ifa->ifa_name, ifr->ifr_name, MIN(sizeof ifa->ifa_name, sizeof ifr->ifr_name));

		ifa->ifa_addr = u_sa_copy(&ifa->ifa_ss[0], &ifr->ifr_addr);

		if (-1 != ioctl(fd, SIOCGIFFLAGS, ifr))
			ifa->ifa_flags = ifr->ifr_flags;

		if (ifa->ifa_addr->sa_family == AF_INET6) {
#if defined u_getif6
			//fprintf(stderr, "u_getif6:%s\n", STRINGIFY(u_getif6));
			if (fd6 == -1 && (error = u_socket(&fd6, AF_INET6, SOCK_DGRAM, PF_UNSPEC, U_CLOEXEC)))
				goto error;

			if ((error = u_getif6(ifa, fd6, ifr)))
				goto error;
#endif
		} else {
			if (-1 != ioctl(fd, SIOCGIFNETMASK, ifr) && ifr->ifr_addr.sa_family == ifa->ifa_addr->sa_family)
				ifa->ifa_netmask = u_sa_copy(&ifa->ifa_ss[1], &ifr->ifr_addr);

			if (-1 != ioctl(fd, SIOCGIFDSTADDR, ifr) && ifr->ifr_addr.sa_family == ifa->ifa_addr->sa_family)
				ifa->ifa_dstaddr = u_sa_copy(&ifa->ifa_ss[2], &ifr->ifr_addr);
			else if (-1 != ioctl(fd, SIOCGIFBRDADDR, ifr) && ifr->ifr_addr.sa_family == ifa->ifa_addr->sa_family)
				ifa->ifa_dstaddr = u_sa_copy(&ifa->ifa_ss[2], &ifr->ifr_addr);
		}

		*((prv)? &prv->ifa_next : ifs) = ifa;
		prv = ifa;

		ifr = (struct ifreq *)((char *)ifr + ifrsiz);
	}

	u_close(&fd6);
	u_close(&fd);

	return 0;
syerr:
	error = errno;
error:
	u_close(&fd6);
	u_close(&fd);

	free(ifc.ifc_buf);

	u_freeifaddrs(*ifs);
	*ifs = NULL;

	return error;
} /* u_getifaddrs() */

#endif /* if !HAVE_GETIFADDRS */


#ifndef READDIR_R_AIX
#define READDIR_R_AIX _AIX
#endif

static int u_readdir_r(DIR *dp, struct dirent *ent, struct dirent **res) {
#if READDIR_R_AIX
	/*
	 * AIX uses global errno to return error codes. On error it returns
	 * 9, which [probably not coincidentally] is EBADF. But that's
	 * misleading, as the real error code is in errno. For example, if
	 * you revoke read permissions errno will be set to EACCESS but the
	 * return code is still 9. If you dup2 the descriptor to a
	 * non-directory, it sets errno to EBADF as expected.
	 *
	 * On end-of-directory it fails with 9 but sets errno to 0. Some
	 * people check whether *res is NULL, but in my tests *res is always
	 * NULL on failure. If you only check for failure and *res == NULL,
	 * you'll treat real errors as simply an end-of-directory condition.
	 * The AIX 7.1 manual page is misleading in this regard.
	 *
	 * Saner implementations return an error code directly on failure.
	 * On end-of-directory they return 0 (success) and set *res to NULL.
	 */
	struct dirent tmp;
	int error;

	/*
	 * The following tries to be conservative. AIX isn't to be trusted.
	 */
	*res = &tmp;
	errno = 0;

	if ((error = readdir_r(dp, ent, res))) {
		if (errno == 0 && *res == NULL) {
			error = 0;
		} else if (errno) {
			error = errno;
		}
	}

	return error;
#else
	/*
	 * NOTE: glibc deprecated readdir_r but not worth refactoring our
	 * code unless and until the next POSIX specification is released
	 * which makes readdir_r thread-safe.
	 */
	U_WARN_PUSH;
	U_WARN_NO_DEPRECATED_DECLARATIONS;
	return readdir_r(dp, ent, res);
	U_WARN_POP;
#endif
} /* u_readdir_r() */


#ifndef GETGRGID_R_AIX
#define GETGRGID_R_AIX _AIX
#endif

#ifndef GETGRGID_R_NETBSD
#define GETGRGID_R_NETBSD __NetBSD__
#endif

static int u_getgrgid_r(gid_t gid, struct group *grp, char *buf, size_t bufsiz, struct group **res) {
#if GETGRGID_R_AIX
	if (bufsiz == 0)
		return ERANGE;

	errno = 0;
	return getgrgid_r(gid, grp, buf, bufsiz, res)? ((errno != ESRCH)? errno : 0) : 0;
#elif GETGRGID_R_NETBSD
	int error;
	errno = 0;
	return (error = getgrgid_r(gid, grp, buf, bufsiz, res))? error : errno;
#else
	return getgrgid_r(gid, grp, buf, bufsiz, res);
#endif
} /* u_getgrgid_r() */

#ifndef GETGRNAM_R_AIX
#define GETGRNAM_R_AIX GETGRGID_R_AIX
#endif

#ifndef GETGRNAM_R_NETBSD
#define GETGRNAM_R_NETBSD GETGRGID_R_NETBSD
#endif

static int u_getgrnam_r(const char *nam, struct group *grp, char *buf, size_t bufsiz, struct group **res) {
#if GETGRNAM_R_AIX
	if (bufsiz == 0)
		return ERANGE;

	errno = 0;
	return getgrnam_r(nam, grp, buf, bufsiz, res)? ((errno != ESRCH)? errno : 0) : 0;
#elif GETGRNAM_R_NETBSD
	int error;
	errno = 0;
	return (error = getgrnam_r(nam, grp, buf, bufsiz, res))? error : errno;
#else
	return getgrnam_r(nam, grp, buf, bufsiz, res);
#endif
} /* u_getgrnam_r() */

#ifndef GETPWUID_R_AIX
#define GETPWUID_R_AIX GETGRGID_R_AIX
#endif

#ifndef GETPWUID_R_NETBSD
#define GETPWUID_R_NETBSD GETGRGID_R_NETBSD
#endif

static int u_getpwuid_r(uid_t uid, struct passwd *pwd, char *buf, size_t bufsiz, struct passwd **res) {
#if GETPWUID_R_AIX
	if (bufsiz == 0)
		return ERANGE;

	errno = 0;
	return getpwuid_r(uid, pwd, buf, bufsiz, res)? ((errno != ESRCH)? errno : 0) : 0;
#elif GETPWUID_R_NETBSD
	int error;
	errno = 0;
	return (error = getpwuid_r(uid, pwd, buf, bufsiz, res))? error : errno;
#else
	return getpwuid_r(uid, pwd, buf, bufsiz, res);
#endif
} /* u_getpwuid_r() */

#ifndef GETPWNAM_R_AIX
#define GETPWNAM_R_AIX GETGRGID_R_AIX
#endif

#ifndef GETPWNAM_R_NETBSD
#define GETPWNAM_R_NETBSD GETGRGID_R_NETBSD
#endif

static int u_getpwnam_r(const char *nam, struct passwd *pwd, char *buf, size_t bufsiz, struct passwd **res) {
#if GETPWNAM_R_AIX
	if (bufsiz == 0)
		return ERANGE;

	errno = 0;
	return getpwnam_r(nam, pwd, buf, bufsiz, res)? ((errno != ESRCH)? errno : 0) : 0;
#elif GETPWNAM_R_NETBSD
	int error;
	errno = 0;
	return (error = getpwnam_r(nam, pwd, buf, bufsiz, res))? error : errno;
#else
	return getpwnam_r(nam, pwd, buf, bufsiz, res);
#endif
} /* u_getpwnam_r() */


static u_error_t u_ptsname_r(int fd, char *buf, size_t buflen) {
#if HAVE_PTSNAME_R
	if (!buf || buflen == 0)
		return ERANGE;
	if (0 != ptsname_r(fd, buf, buflen))
		return errno;

	return 0;
#else
	const char *path;

	/*
	 * NB: POSIX doesn't require that errno be set on error. We'll just
	 * return whatever non-0 errno value we see, EINVAL if 0.
	 */
	errno = 0;
	if (!(path = ptsname(fd)))
		return (errno)? errno : EINVAL;

	if (u_strlcpy(buf, path, buflen) >= buflen)
		return ERANGE;

	return 0;
#endif
} /* u_ptsname_r() */


/*
 * References for recvfromto and sendtofrom.
 *
 *   - IPv6 API
 *     - https://www.ietf.org/rfc/rfc3542.txt
 *   - macOS <= 10.10 kernel panic with IP_SENDSRCADDR unless socket bound
 *     - https://www.irif.fr/~boutier/mac-crash.html
 *     - https://www.irif.fr/~boutier/progs/kernel-panic.c
 *   - OpenIKED sendtofrom implementation
 *     - http://cvsweb.openbsd.org/cgi-bin/cvsweb/src/sbin/iked/util.c?rev=1.32
 *   - FreeRADIUS recvfromto, sendfromto implementations
 *     - https://github.com/FreeRADIUS/freeradius-server/blob/release_3_0_12/src/lib/udpfromto.c
 *   - @ryo recvfromto, sendfromto implementations
 *     - http://www.nerv.org/~ryo/files/netbsd/sendfromto/sockfromto.c
 */
#if HAVE_DECL_IP_RECVDSTADDR || HAVE_DECL_IP_PKTINFO || HAVE_DECL_IPV6_PKTINFO

static u_error_t u_getsockport(int fd, in_port_t *port, int (*getname)(int, struct sockaddr *, socklen_t *)) {
	union {
		struct sockaddr_in in;
		struct sockaddr_in6 in6;
	} addr;
	socklen_t addrlen = sizeof addr;

	if (0 != getname(fd, (struct sockaddr *)&addr, &addrlen))
		return errno;

	switch (addr.in.sin_family) {
	case AF_INET:
		*port = addr.in.sin_port;
		return 0;
	case AF_INET6:
		*port = addr.in6.sin6_port;
		return 0;
	default:
		return EAFNOSUPPORT;
	}
} /* u_getsockport() */

/*
 * NOTE: Initialization is better done by the application code, because
 *
 *   1) setsockopt should happen before binding. On FreeBSD (confirmed 10.1)
 *      packets received in the kernel before the option has been set will
 *      not be tagged with the reception address when dequeued with recvmsg.
 *
 *   2) For sendtofrom to work on FreeBSD (confirmed 10.1) the sending
 *      socket must also be explicitly bound to INADDR_ANY. This means that
 *      we cannot make recvfromto/sendtofrom magically work without the
 *      caller performing some initializations peculiar to this API.
 *
 *   3) macOS <= 10.10 (confirmed 10.10) has a bug that causes a kernel panic
 *      when using IP_SENDSRCADDR on an unbound socket. Handling this issue
 *      is too messy and brittle to do outside the caller's control.
 *
 *   4) It invokes a superfluous setsockopt for every call. We still do a
 *      getsockname on every call, but this can be optimized in the future
 *      by allowing the Lua caller to provide a preinitialized structure.
 */
#if 0
static u_error_t u_recvfromto_init(int fd, in_port_t *port) {
	union {
		struct sockaddr_in in;
		struct sockaddr_in6 in6;
	} addr;
	socklen_t addrlen = sizeof addr;
	int level = 0, type = 0;

	memset(&addr, 0, sizeof addr);

	if (0 != getsockname(fd, (struct sockaddr *)&addr, &addrlen))
		return errno;

	switch (addr.in.sin_family) {
	case AF_INET:
		*port = addr.in.sin_port;
#if HAVE_DECL_IP_RECVDSTADDR
		level = IPPROTO_IP;
		type = IP_RECVDSTADDR;
#elif HAVE_DECL_IP_PKTINFO
		level = IPPROTO_IP;
		type = IP_PKTINFO;
#endif
		break;
	case AF_INET6:
		*port = addr.in6.sin6_port;
#if HAVE_DECL_IPV6_RECVPKTINFO
		level = IPPROTO_IPV6;
		type = IPV6_RECVPKTINFO;
#elif HAVE_DECL_IPV6_PKTINFO
		level = IPPROTO_IPV6;
		type = IPV6_PKTINFO;
#endif
		break;
	}

	if (0 != setsockopt(fd, level, type, &(int){ 1 }, sizeof (int)))
		return errno;

	return 0;
}
#endif

static ssize_t u_recvfromto(int fd, void *buf, size_t lim, int flags, struct sockaddr *from, size_t *fromlen, struct sockaddr *to, size_t *tolen, u_error_t *error) {
	in_port_t to_port = 0;
	struct iovec iov;
	struct msghdr msg;
	struct cmsghdr *cmsg;
	struct sockaddr_in *in;
#if HAVE_STRUCT_IN_PKTINFO
	struct in_pktinfo pkt;
#endif
#if HAVE_STRUCT_IN6_PKTINFO
	struct sockaddr_in6 *in6;
	struct in6_pktinfo pkt6;
#endif
	union {
		struct cmsghdr hdr;
#if HAVE_STRUCT_IN_PKTINFO
		char inbuf[CMSG_SPACE(sizeof pkt)];
#else
		char inbuf[CMSG_SPACE(sizeof in->sin_addr)];
#endif
#if HAVE_STRUCT_IN6_PKTINFO
		char in6buf[CMSG_SPACE(sizeof pkt6)];
#endif
	} cmsgbuf;
	ssize_t n;

	if ((*error = u_getsockport(fd, &to_port, &getsockname)))
		return -1;

	memset(&msg, 0, sizeof msg);
	memset(&cmsgbuf, 0, sizeof cmsgbuf);
	memset(from, 0, *fromlen);
	memset(to, 0, *tolen);

	iov.iov_base = buf;
	iov.iov_len = lim;
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;
	msg.msg_name = (void *)from;
	msg.msg_namelen = *fromlen;
	msg.msg_control = &cmsgbuf;
	msg.msg_controllen = sizeof cmsgbuf;

	if (-1 == (n = recvmsg(fd, &msg, flags))) {
		*error = errno;
		return -1;
	}

	*fromlen = msg.msg_namelen;

	for (cmsg = CMSG_FIRSTHDR(&msg); cmsg != NULL; cmsg = CMSG_NXTHDR(&msg, cmsg)) {
#if HAVE_DECL_IP_RECVDSTADDR
		if (cmsg->cmsg_level == IPPROTO_IP && cmsg->cmsg_type == IP_RECVDSTADDR) {
			if (*tolen < sizeof *in)
				goto inval;
			in = (struct sockaddr_in *)to;
			in->sin_family = AF_INET;
#if HAVE_SOCKADDR_SA_LEN
			in->sin_len = sizeof *in;
#endif
			in->sin_port = to_port;
			memcpy(&in->sin_addr, CMSG_DATA(cmsg), sizeof in->sin_addr);
			*tolen = sizeof *in;
			break;
		}
#endif

#if HAVE_DECL_IP_PKTINFO && HAVE_STRUCT_IN_PKTINFO
		if (cmsg->cmsg_level == IPPROTO_IP && cmsg->cmsg_type == IP_PKTINFO) {
			memcpy(&pkt, CMSG_DATA(cmsg), sizeof pkt);
			if (*tolen < sizeof *in)
				goto inval;
			in = (struct sockaddr_in *)to;
			in->sin_family = AF_INET;
#if HAVE_SOCKADDR_SA_LEN
			in->sin_len = sizeof *in;
#endif
			in->sin_port = to_port;
			in->sin_addr = pkt.ipi_addr;
			*tolen = sizeof *in;
			break;
		}
#endif

#if HAVE_DECL_IPV6_PKTINFO && HAVE_STRUCT_IN6_PKTINFO
		if (cmsg->cmsg_level == IPPROTO_IPV6 && cmsg->cmsg_type == IPV6_PKTINFO) {
			memcpy(&pkt6, CMSG_DATA(cmsg), sizeof pkt6);
			if (*tolen < sizeof *in6)
				goto inval;
			in6 = (struct sockaddr_in6 *)to;
			in6->sin6_family = AF_INET6;
#if HAVE_SOCKADDR_SA_LEN
			in6->sin6_len = sizeof *in6;
#endif
			in6->sin6_port = to_port;
			in6->sin6_addr = pkt6.ipi6_addr;
			if (IN6_IS_SCOPE_LINKLOCAL(&pkt6.ipi6_addr))
				in6->sin6_scope_id = pkt6.ipi6_ifindex;
			*tolen = sizeof *in6;
			break;
		}
#endif
	}

	return n;
inval:
	*error = EINVAL;
	return -1;
} /* u_recvfromto() */

#else

static ssize_t u_recvfromto(int fd, const void *src, size_t len, int flags, const struct sockaddr *from, size_t *fromlen, const struct sockaddr *to, size_t *tolen, u_error_t *error) {
	(void)fd;
	(void)src;
	(void)len;
	(void)flags;
	(void)from;
	(void)fromlen;
	(void)to;
	(void)tolen;

	*error = ENOTSUP;
	return -1;
} /* u_recvfromto() */

#endif

#if HAVE_DECL_IP_SENDSRCADDR || HAVE_DECL_IP_PKTINFO || HAVE_DECL_IPV6_PKTINFO

static ssize_t u_sendtofrom(int fd, const void *buf, size_t len, int flags, const struct sockaddr *to, size_t tolen, const struct sockaddr *from, size_t fromlen, u_error_t *error) {
	struct iovec iov;
	struct msghdr msg;
	struct cmsghdr *cmsg;
	struct sockaddr_in *in;
#if HAVE_STRUCT_IN_PKTINFO
	struct in_pktinfo pkt;
#endif
#if HAVE_STRUCT_IN6_PKTINFO
	struct sockaddr_in6 *in6;
	struct in6_pktinfo pkt6;
#endif
	union {
		struct cmsghdr hdr;
#if HAVE_STRUCT_IN_PKTINFO
		char inbuf[CMSG_SPACE(sizeof pkt)];
#else
		char inbuf[CMSG_SPACE(sizeof (struct in_addr))];
#endif
#if HAVE_STRUCT_IN6_PKTINFO
		char in6buf[CMSG_SPACE(sizeof pkt6)];
#endif
	} cmsgbuf;
	ssize_t n;

	memset(&msg, 0, sizeof msg);
	memset(&cmsgbuf, 0, sizeof cmsgbuf);

	iov.iov_base = (void *)buf;
	iov.iov_len = len;
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;
	msg.msg_name = (void *)to;
	msg.msg_namelen = tolen;
	msg.msg_control = &cmsgbuf;
	msg.msg_controllen = sizeof cmsgbuf;

	cmsg = CMSG_FIRSTHDR(&msg);

	switch (from->sa_family) {
#if HAVE_DECL_IP_SENDSRCADDR
	case AF_INET:
		msg.msg_controllen = sizeof cmsgbuf.inbuf;
		cmsg->cmsg_len = CMSG_LEN(sizeof in->sin_addr);
		cmsg->cmsg_level = IPPROTO_IP;
		cmsg->cmsg_type = IP_SENDSRCADDR;
		if (sizeof *in < fromlen)
			goto inval;
		in = (struct sockaddr_in *)from;
		memcpy(CMSG_DATA(cmsg), &in->sin_addr, sizeof in->sin_addr);

		break;
#elif HAVE_DECL_IP_PKTINFO && HAVE_STRUCT_IN_PKTINFO_IPI_SPEC_DST
	case AF_INET:
		msg.msg_controllen = sizeof cmsgbuf.inbuf;
		cmsg->cmsg_len = CMSG_LEN(sizeof pkt);
		cmsg->cmsg_level = IPPROTO_IP;
		cmsg->cmsg_type = IP_PKTINFO;
		if (sizeof *in < fromlen)
			goto inval;
		in = (struct sockaddr_in *)from;
		memset(&pkt, 0, sizeof pkt);
		pkt.ipi_spec_dst = in->sin_addr;
		memcpy(CMSG_DATA(cmsg), &pkt, sizeof pkt);

		break;
#endif
#if HAVE_DECL_IPV6_PKTINFO && HAVE_STRUCT_IN6_PKTINFO
	case AF_INET6:
		msg.msg_controllen = sizeof cmsgbuf.in6buf;
		cmsg->cmsg_len = CMSG_LEN(sizeof pkt6);
		cmsg->cmsg_level = IPPROTO_IPV6;
		cmsg->cmsg_type = IPV6_PKTINFO;
		if (sizeof *in6 < fromlen)
			goto inval;
		in6 = (struct sockaddr_in6 *)from;
		memset(&pkt6, 0, sizeof pkt6);
		pkt6.ipi6_addr = in6->sin6_addr;
		if (IN6_IS_SCOPE_LINKLOCAL(&in6->sin6_addr))
			pkt6.ipi6_ifindex = in6->sin6_scope_id;
		memcpy(CMSG_DATA(cmsg), &pkt6, sizeof pkt6);

		break;
#endif
	default:
		*error = EAFNOSUPPORT;
		return -1;
	}

	if (-1 == (n = sendmsg(fd, &msg, flags)))
		*error = errno;

	return n;
inval:
	*error = EINVAL;
	return -1;
} /* u_sendtofrom() */

#else

static ssize_t u_sendtofrom(int fd, const void *src, size_t len, int flags, const struct sockaddr *to, size_t tolen, const struct sockaddr *from, size_t fromlen, u_error_t *error) {
	(void)fd;
	(void)src;
	(void)len;
	(void)flags;
	(void)to;
	(void)tolen;
	(void)from;
	(void)fromlen;

	*error = ENOTSUP;
	return -1;
} /* u_sendtofrom() */

#endif


#if !HAVE_ARC4RANDOM

#define UNIXL_RANDOM_INITIALIZER { .fd = -1, }

typedef struct unixL_Random {
	int fd;

	unsigned char s[256];
	unsigned char i, j;
	int count;

	pid_t pid;
} unixL_Random;


static void arc4_init(unixL_Random *R) {
	unsigned i;

	memset(R, 0, sizeof *R);

	R->fd = -1;

	for (i = 0; i < sizeof R->s; i++) {
		R->s[i] = i;
	}
} /* arc4_init() */


static void arc4_destroy(unixL_Random *R) {
	u_close(&R->fd);
} /* arc4_destroy() */


static void arc4_addrandom(unixL_Random *R, unsigned char *src, size_t len) {
	unsigned char si;
	int n;

	--R->i;

	for (n = 0; n < 256; n++) {
		++R->i;
		si = R->s[R->i];
		R->j += si + src[n % len];
		R->s[R->i] = R->s[R->j];
		R->s[R->j] = si;
	}

	R->j = R->i;
} /* arc4_addrandom() */


static int arc4_getbyte(unixL_Random *R) {
	unsigned char si, sj;

	++R->i;
	si = R->s[R->i];
	R->j += si;
	sj = R->s[R->j];
	R->s[R->i] = sj;
	R->s[R->j] = si;

	return R->s[(si + sj) & 0xff];
} /* arc4_getbyte() */


static void arc4_stir(unixL_Random *R, int force) {
	unsigned char bytes[128];
	size_t count = 0, n;

	if (R->count > 0 && R->pid == getpid() && !force)
		return;

#if HAVE_SYSCALL && HAVE_DECL_SYS_GETRANDOM
	while (count < sizeof bytes) {
		int n = syscall(SYS_getrandom, &bytes[count], sizeof bytes - count, 0);

		if (n == -1)
			break;

		count += n;
	}
#endif

#if HAVE_SYSCTL && HAVE_DECL_CTL_KERN && HAVE_DECL_KERN_RANDOM && HAVE_DECL_RANDOM_UUID
	while (count < sizeof bytes) {
		int mib[] = { CTL_KERN, KERN_RANDOM, RANDOM_UUID };
		size_t n = sizeof bytes - count;

		if (0 != sysctl(mib, countof(mib), &bytes[count], &n, (void *)0, 0))
			break;

		count += n;
	}
#endif

	if (count < sizeof bytes) {
		if (R->fd == -1 && 0 != u_open(&R->fd, "/dev/urandom", O_RDONLY|U_CLOEXEC, 0))
			goto stir;

		while (count < sizeof bytes) {
			ssize_t n = read(R->fd, &bytes[count], sizeof bytes - count);

			if (n == -1) {
				if (errno == EINTR)
					continue;
				break;
			} else if (n == 0) {
				u_close(&R->fd);

				break;
			}

			count += n;
		}
	}

stir:
	arc4_addrandom(R, bytes, sizeof bytes);

	if (count < sizeof bytes) {
		arc4_addrandom(R, u_memjunk(bytes, sizeof bytes), sizeof bytes);
	}

	for (n = 0; n < 1024; n++)
		arc4_getbyte(R);

	R->count = 1600000 / 10; /* reseed sooner than original construct */
	R->pid = getpid();
} /* arc4_stir() */


static uint32_t arc4_getword(unixL_Random *R) {
	uint32_t r;

	R->count -= 4;

	arc4_stir(R, 0);

	r = (uint32_t)arc4_getbyte(R) << 24;
	r |= (uint32_t)arc4_getbyte(R) << 16;
	r |= (uint32_t)arc4_getbyte(R) << 8;
	r |= (uint32_t)arc4_getbyte(R);

	return r;
} /* arc4_getword() */

#endif /* !HAVE_ARC4RANDOM */


/*
 * E X T E R N A L  C O M P A T  R O U T I N E S
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#include "unix-getopt.c"


/*
 * Extends luaL_newmetatable by adding all the relevant fields to the
 * metatable using the standard pattern (placing all the methods in the
 * __index metafield). Leaves the metatable on the stack.
 */
static int unixL_newmetatable(lua_State *L, const char *name, const luaL_Reg *methods, const luaL_Reg *metamethods, int nup) {
	int i, n;

	if (!luaL_newmetatable(L, name))
		return 0;

	/* add metamethods */
	for (i = 0; i < nup; i++)
		lua_pushvalue(L, -1 - nup);
	luaL_setfuncs(L, metamethods, nup);

	/* add methods */
	if (methods) {
		for (n = 0; methods[n].name; n++)
			;;
		lua_createtable(L, 0, n);

		for (i = 0; i < nup; i++)
			lua_pushvalue(L, -2 - nup);
		luaL_setfuncs(L, methods, nup);

		lua_setfield(L, -2, "__index");
	}

	return 1;
} /* unixL_newmetatable() */


typedef struct unixL_State {
	struct {
		_Bool jit;
		int openf; /* LuaJIT io.open reference */
		int opene; /* PUC Lua 5.1 file handle environment */
	} lua;

	int error; /* errno value from last failed syscall */

	char text[MIN(NL_TEXTMAX, 256)]; /* NL_TEXTMAX == INT_MAX for glibc */

	char *buf;
	size_t bufsiz;

	struct {
		struct passwd ent;
		char *buf;
		size_t bufsiz;
	} pw;

	struct {
		struct group ent;
		char *buf;
		size_t bufsiz;
	} gr;

	struct {
		int fd[2];
		pid_t pid;
	} ts;

	struct {
		DIR *dp;
		struct dirent *ent;
		size_t bufsiz;
	} dir;

	struct {
		char **arr;
		size_t arrsiz;
	} exec;

#if !HAVE_ARC4RANDOM
	unixL_Random random;
#endif

#if __APPLE__
	struct {
#if USE_CLOCK_GET_TIME
		host_name_port_t host;
		clock_serv_t clock;
#else
		mach_timebase_info_data_t timebase;
#endif
	} tm;
#endif

	struct {
		char path[64];
		int error;
	} fd;

	struct {
		int opterr, optind, optopt, arg0;
	} opt;

	struct {
		int fd;
		struct addrinfo *res;
		struct {
			struct pollfd *buf;
			size_t bufsiz;
		} fds;
		size_t nfds;
	} net;

	struct {
		int ident; /* registry reference to ident string */
	} log;
} unixL_State;

static const unixL_State unixL_initializer = {
	.lua = { 0, LUA_NOREF, LUA_NOREF },
	.ts = { { -1, -1 } },
#if !HAVE_ARC4RANDOM
	.random = UNIXL_RANDOM_INITIALIZER,
#endif
#if USE_CLOCK_GET_TIME
	.tm = { MACH_PORT_NULL, MACH_PORT_NULL },
#endif
	.net = { -1, NULL },
	.log = { .ident = LUA_NOREF },
};

#define UNIXL_MAGIC_INITIALIZER { 0, { 0 } }

typedef struct unixL_Magic {
	int state;
	unsigned char magic[4];
} unixL_Magic;

static int unixL_magicf(lua_State *L, const void *src, size_t len, void *ud) {
	unixL_Magic *M = ud;
	const unsigned char *p, *pe;

	(void)L;
	p = src;
	pe = p + len;

	while (p < pe) {
		switch (M->state) {
		case 0: case 1: case 2: case 3:
			M->magic[M->state++] = *p++;
			break;
		default:
			return 0;
		}
	}

	return 0;
} /* unixL_magicf() */

static int unixL_closef(lua_State *);

static int unixL_init(lua_State *L, unixL_State *U) {
	unixL_Magic M = UNIXL_MAGIC_INITIALIZER;
	int error;

	luaL_loadstring(L, "return 42");
#if LUA_VERSION_NUM >= 503
	lua_dump(L, &unixL_magicf, &M, 1);
#else
	lua_dump(L, &unixL_magicf, &M);
#endif
	lua_pop(L, 1);

	/* LuaJIT magic begins \033LJ; PUC Lua 5.1 magic is \033Lua. */
	if (M.magic[0] == 0x1b && M.magic[1] == 0x4c && M.magic[2] == 0x4a)
		U->lua.jit = 1;

	if (U->lua.jit) {
		lua_getglobal(L, "io");

		if (!lua_isnil(L, -1)) {
			lua_getfield(L, -1, "open");
			U->lua.openf = luaL_ref(L, LUA_REGISTRYINDEX);
		}

		lua_pop(L, 1);
	}

#if LUA_VERSION_NUM == 501
	if (!U->lua.jit) {
		lua_createtable(L, 0, 1);
		lua_pushcfunction(L, &unixL_closef);
		lua_setfield(L, -2, "__close");
		U->lua.opene = luaL_ref(L, LUA_REGISTRYINDEX);
	}
#endif

	if ((error = u_pipe(U->ts.fd, O_NONBLOCK|U_CLOEXEC)))
		return error;

	U->ts.pid = getpid();

#if !HAVE_ARC4RANDOM
	arc4_init(&U->random);
#endif

#if __APPLE__
#if USE_CLOCK_GET_TIME
	if (MACH_PORT_NULL == (U->tm.host = mach_host_self()))
		return EMFILE; /* unable to allocate port */

	if (KERN_SUCCESS != host_get_clock_service(U->tm.host, SYSTEM_CLOCK, &U->tm.clock))
		return ENOTSUP;
#else
	if (KERN_SUCCESS != mach_timebase_info(&U->tm.timebase))
		return ENOTSUP;
#endif
#endif

	U->opt.opterr = 1;
	U->opt.optind = 1;

	return 0;
} /* unixL_init() */


static void unixL_destroy(unixL_State *U) {
	free(U->net.fds.buf);
	U->net.fds.buf = NULL;
	U->net.fds.bufsiz = 0;
	u_close(&U->net.fd);
	u_freeaddrinfo(&U->net.res);

#if USE_CLOCK_GET_TIME
	/* NOTE: no need to deallocate mach_task_self() port */
	if (MACH_PORT_NULL != U->tm.clock) {
		mach_port_deallocate(mach_task_self(), U->tm.clock);
		U->tm.clock = MACH_PORT_NULL;
	}

	if (MACH_PORT_NULL != U->tm.host) {
		mach_port_deallocate(mach_task_self(), U->tm.host);
		U->tm.host = MACH_PORT_NULL;
	}
#endif

#if !HAVE_ARC4RANDOM
	arc4_destroy(&U->random);
#endif

	free(U->exec.arr);
	U->exec.arr = NULL;
	U->exec.arrsiz = 0;

	free(U->dir.ent);
	U->dir.ent = NULL;
	U->dir.bufsiz = 0;
	U->dir.dp = NULL;

	free(U->gr.buf);
	U->gr.buf = NULL;
	U->gr.bufsiz = 0;

	free(U->pw.buf);
	U->pw.buf = NULL;
	U->pw.bufsiz = 0;

	u_close(&U->ts.fd[0]);
	u_close(&U->ts.fd[1]);

	free(U->buf);
	U->buf = NULL;
	U->bufsiz = 0;
} /* unixL_destroy() */


static unixL_State *unixL_getstate(lua_State *L) {
	return lua_touserdata(L, lua_upvalueindex(1));
} /* unixL_getstate() */

static int state__gc(lua_State *L) {
	unixL_destroy(lua_touserdata(L, 1));

	return 0;
} /* state__gc() */

static const char *unixL_strerror3(lua_State *, unixL_State *, int);

static unixL_State *unixL_newstate(lua_State *L) {
	unixL_State *U;
	int error;

	U = lua_newuserdata(L, sizeof *U);
	*U = unixL_initializer;

	lua_newtable(L);
	lua_pushcfunction(L, &state__gc);
	lua_setfield(L, -2, "__gc");

	lua_setmetatable(L, -2);

	if ((error = unixL_init(L, U)))
		return luaL_error(L, "%s", unixL_strerror3(L, U, error)), (void *)NULL;

	return U;
} /* unixL_newstate() */

static unixL_State *unixL_loadstate(lua_State *L) {
	static int cachekey;
	unixL_State *U;

	if (LUA_TNIL == lua_rawgetp(L, LUA_REGISTRYINDEX, &cachekey)) {
		lua_pop(L, 1);
		U = unixL_newstate(L);
		lua_pushvalue(L, -1);
		lua_rawsetp(L, LUA_REGISTRYINDEX, &cachekey);
	} else {
		if (lua_type(L, -1) != LUA_TUSERDATA)
			return luaL_error(L, "bad cached unix state context (expected userdata, got %s)", luaL_typename(L, -1)), (void *)NULL;
		U = lua_touserdata(L, -1);
	}

	return U;
} /* unixL_loadstate() */


static struct sockaddr *unixL_newsockaddr(lua_State *, const void *, size_t);

static u_error_t unixL_getsockname(lua_State *L, int fd, int (*getname)(int, struct sockaddr *, socklen_t *)) {
	unixL_State *U = unixL_getstate(L);
	socklen_t salen = sizeof (struct sockaddr);
	int error;

	do {
		if (U->bufsiz < salen && (error = u_realloc(&U->buf, &U->bufsiz, salen)))
			return error;
		salen = MAX(INT_MAX, U->bufsiz);
		if (0 != getname(fd, (struct sockaddr *)U->buf, &salen))
			return errno;
	} while (salen > U->bufsiz);

	unixL_newsockaddr(L, U->buf, salen);

	return 1;
} /* unixL_getsockname() */


#if !HAVE_ARC4RANDOM
static uint32_t unixL_random(lua_State *L) {
	return arc4_getword(&(unixL_getstate(L))->random);
}
#else
static uint32_t unixL_random(lua_State *L NOTUSED) {
	return arc4random();
}
#endif

#define r_char(charmap, maplen, r) \
	((charmap)? (charmap)[(0xff & (r)) % (maplen)]: (0xff & (r)))

static void unixL_random_buf(lua_State *L, void *buf, size_t bufsiz, const unsigned char *charmap, size_t mapsiz) {
	unsigned char *p = buf, *pe = p + bufsiz;
	uint32_t r;

	while (p < pe) {
		r = unixL_random(L);

		switch ((size_t)(pe - p)) {
		default:
			*p++ = r_char(charmap, mapsiz, (r >> 0));
			/* FALL THROUGH */
		case 3:
			*p++ = r_char(charmap, mapsiz, (r >> 8));
			/* FALL THROUGH */
		case 2:
			*p++ = r_char(charmap, mapsiz, (r >> 16));
			/* FALL THROUGH */
		case 1:
			*p++ = r_char(charmap, mapsiz, (r >> 24));
		}
	}
} /* unixL_random_buf() */


/*
 * Thread-safety of strsignal(3) varies.
 *
 * 	    Solaris : safe; static buffer; not localized on 12.1;
 * 	              returns NULL on bad signo
 * 	Linux/glibc : safe'ish since 1998; TLS buffer for bad signo;
 * 	              gettext for good signo (is gettext thread-safe?)
 * 	 Linux/musl : safe; localized; locale structures never deallocated
 * 	    FreeBSD : safe since 8.1; TLS buffer
 * 	     NetBSD : not safe as of 6.1; static buffer
 * 	    OpenBSD : not safe as of 5.6; static buffer
 * 	       OS X : safe on 10.9.4; TLS buffer
 * 	        AIX : safe; static buffer; not localized on AIX 7.1;
 * 	              segfaults on bad signo
 *
 * Use of sys_siglist isn't necessarily thread-safe either, but
 * implementations would have to work hard to make it unsafe.
 *
 * Note that AIX requires explicit declaration of sys_siglist, and Solaris
 * has _sys_siglistp instead of sys_siglist. But we use strsignal on those
 * platforms.
 */
#ifndef HAVE_MTSAFE_STRSIGNAL
#define HAVE_MTSAFE_STRSIGNAL_ \
	(__sun || GLIBC_PREREQ(0,0) || MUSL_MAYBE || \
	 FREEBSD_PREREQ(8,1) || __APPLE__ || _AIX)
#define HAVE_MTSAFE_STRSIGNAL (HAVE_STRSIGNAL && HAVE_MTSAFE_STRSIGNAL_)
#endif

static const char *unixL_strsignal(lua_State *L, int signo) {
	const char *info;
	unixL_State *U;

#if HAVE_MTSAFE_STRSIGNAL
	/* AIX strsignal(3) cannot handle bad signo */
	if (signo >= 0 && signo < NSIG && (info = strsignal(signo)))
		return info;
#elif HAVE_SYS_SIGLIST
#if !HAVE_DECL_SYS_SIGLIST
	extern const char *sys_siglist[];
#endif
	if (signo >= 0 && signo < NSIG && (info = sys_siglist[signo]))
		return info;
#endif

	U = unixL_getstate(L);

	if (0 > snprintf(U->text, sizeof U->text, "Unknown signal: %d", signo))
		luaL_error(L, "snprintf failure");

	return U->text;
} /* unixL_strsignal() */


static const char *unixL_strerror3(lua_State *L, unixL_State *U, int error) {
	if (0 != u_strerror_r(error, U->text, sizeof U->text) || U->text[0] == '\0') {
		if (0 > snprintf(U->text, sizeof U->text, "%s: %d", ((error)? "Unknown error" : "Undefined error"), error))
			luaL_error(L, "snprintf failure");
	}

	return U->text;
} /* unixL_strerror3() */


static const char *unixL_strerror(lua_State *L, int error) {
	unixL_State *U = unixL_getstate(L);

	return unixL_strerror3(L, U, error);
} /* unixL_strerror() */


#define unixL_Integer intmax_t
#define UNIXL_INTEGER_MAX INTMAX_MAX
#define UNIXL_INTEGER_MIN INTMAX_MIN
#define UNIXL_INTEGER_PREC ((sizeof (unixL_Integer) * CHAR_BIT) - 1)

#define unixL_Unsigned uintmax_t
#define UNIXL_UNSIGNED_MAX UINTMAX_MAX
#define UNIXL_UNSIGNED_PREC (sizeof (unixL_Unsigned) * CHAR_BIT)

#define UNIXL_INTNUM_MAX ((((INTMAX_C(1) << (sizeof (lua_Number) - 2)) - 1) << 1) + 1)
#define UNIXL_INTNUM_MIN (-UNIXL_INTNUM_MAX - 1)

#if !defined LUA_NUMBER_MAX_EXP
#if HAVE_C__GENERIC
#define LUA_NUMBER_MAX_EXP _Generic((lua_Number)0.0, \
	default: 0, \
	float: FLT_MAX_EXP, \
	double: DBL_MAX_EXP, \
	long double: LDBL_MAX_EXP)
#else
#define LUA_NUMBER_MAX_EXP \
	((sizeof (lua_Number) == sizeof (long double))? LDBL_MAX_EXP : \
	 (sizeof (lua_Number) == sizeof (double))? DBL_MAX_EXP : \
	 (sizeof (lua_Number) == sizeof (float))? FLT_MAX_EXP : 0)
#endif
#endif

static _Bool unixL_integertonumber(unixL_Integer i, lua_Number *p) {
	if (U_ISTFLOAT(lua_Number)) {
		u_static_assert(FLT_RADIX == 2, "FLT_RADIX value unsupported");
		u_static_assert(LUA_NUMBER_MAX_EXP == 0 || UNIXL_INTEGER_PREC < LUA_NUMBER_MAX_EXP, "LUA_NUMBER_MAX_EXP too small");

		if (i != (unixL_Integer)(lua_Number)i)
			return 0;
	} else {
		if (i > UNIXL_INTNUM_MAX || i < UNIXL_INTNUM_MIN)
			return 0;
	}

	*p = i;

	return 1;
} /* unixL_integertonumber() */

static _Bool unixL_unsignedtonumber(unixL_Unsigned i, lua_Number *p) {
	if (U_ISTFLOAT(lua_Number)) {
		u_static_assert(FLT_RADIX == 2, "FLT_RADIX value unsupported");
		u_static_assert(LUA_NUMBER_MAX_EXP == 0 || UNIXL_UNSIGNED_PREC < LUA_NUMBER_MAX_EXP, "LUA_NUMBER_MAX_EXP too small");

		if (i != (unixL_Unsigned)(lua_Number)i)
			return 0;
	} else {
		if (i > UNIXL_INTNUM_MAX)
			return 0;
	}

	*p = i;

	return 1;
} /* unixL_unsignedtonumber() */

static _Bool unixL_numbertointeger(lua_Number n, unixL_Integer *p) {
	if (U_ISTFLOAT(lua_Number)) {
		u_static_assert(FLT_RADIX == 2, "FLT_RADIX value unsupported");
		u_static_assert(LUA_NUMBER_MAX_EXP == 0 || UNIXL_INTEGER_PREC < LUA_NUMBER_MAX_EXP, "LUA_NUMBER_MAX_EXP too small");
		/*
		 * Require two's complement, guaranteeing UNIXL_INTEGER_MIN
		 * to be a power of 2 and representable as float.
		 */
		u_static_assert(-UNIXL_INTEGER_MAX > UNIXL_INTEGER_MIN, "unixL_Integer type not two's complement");

		if (n < (lua_Number)UNIXL_INTEGER_MIN)
			return 0;
		if (n >= -(lua_Number)UNIXL_INTEGER_MIN)
			return 0;
	} else {
		if (n < UNIXL_INTEGER_MIN)
			return 0;
		if (n > UNIXL_INTEGER_MAX)
			return 0;
	}

	*p = n;

	return 1;
} /* unixL_numbertointeger() */

static _Bool unixL_numbertounsigned(lua_Number n, unixL_Unsigned *p) {
	if (U_ISTFLOAT(lua_Number)) {
		if (n < 0)
			return 0;

		u_static_assert(FLT_RADIX == 2, "FLT_RADIX value unsupported");
		u_static_assert(UNIXL_UNSIGNED_PREC < DBL_MAX_EXP, "DBL_MAX_EXP too small");

		if (n >= ldexp(1.0, UNIXL_UNSIGNED_PREC))
			return 0;
	} else {
		if (n < 0)
			return 0;
		if (n > UNIXL_UNSIGNED_MAX)
			return 0;
	}

	*p = n;

	return 1;
} /* unixL_numbertounsigned() */

static void unixL_pushinteger(lua_State *L, unixL_Integer i) {
	lua_Number n;

#if LUA_VERSION_NUM >= 503
	if (i >= LUA_MININTEGER && i <= LUA_MAXINTEGER) {
		lua_pushinteger(L, i);

		return;
	}
#endif
	if (unixL_integertonumber(i, &n)) {
		lua_pushnumber(L, n);
	} else {
		luaL_error(L, "integer value not representable as lua_Integer or lua_Number");
	}
} /* unixL_pushinteger() */

static void unixL_pushunsigned(lua_State *L, unixL_Unsigned i) {
	lua_Number n;

#if LUA_VERSION_NUM >= 503
	if (i <= LUA_MAXINTEGER) {
		lua_pushinteger(L, i);

		return;
	}
#endif
	if (unixL_unsignedtonumber(i, &n)) {
		lua_pushnumber(L, n);
	} else {
		luaL_error(L, "unsigned integer value not representable as lua_Integer or lua_Number");
	}
} /* unixL_pushunsigned() */

#define unixL_checkinteger_(L, index, min, max, ...) unixL_checkinteger((L), (index), (min), (max))
#define unixL_checkinteger(...) unixL_checkinteger_(__VA_ARGS__, UNIXL_INTEGER_MIN, UNIXL_INTEGER_MAX, 0)

static unixL_Integer (unixL_checkinteger)(lua_State *L, int index, unixL_Integer min, unixL_Integer max) {
	if (lua_isinteger(L, index)) {
		lua_Integer i = lua_tointeger(L, index);

		if (i < min || i > max)
			goto erange;

		return i;
	} else {
		unixL_Integer i;

		if (!unixL_numbertointeger(luaL_checknumber(L, index), &i))
			goto erange;

		if (i < min || i > max)
			goto erange;

		return i;
	}
erange:
	luaL_argerror(L, index, "numeric value not representable as integer");

	return 0;
} /* unixL_checkinteger() */

#define unixL_checkunsigned_(L, index, min, max, ...) unixL_checkunsigned((L), (index), (min), (max))
#define unixL_checkunsigned(...) unixL_checkunsigned_(__VA_ARGS__, 0, UNIXL_UNSIGNED_MAX, 0)

static unixL_Unsigned (unixL_checkunsigned)(lua_State *L, int index, unixL_Unsigned min, unixL_Unsigned max) {
	if (lua_isinteger(L, index)) {
		lua_Integer i = lua_tointeger(L, index);

		U_WARN_PUSH;
		U_WARN_NO_SIGN_COMPARE;

		if (i < 0 || i > UNIXL_UNSIGNED_MAX)
			goto erange;

		U_WARN_POP;

		if ((unixL_Unsigned)i < min || (unixL_Unsigned)i > max)
			goto erange;

		return i;
	} else {
		unixL_Unsigned i;

		if (!unixL_numbertounsigned(luaL_checknumber(L, index), &i))
			goto erange;

		if (i < min || i > max)
			goto erange;

		return i;
	}
erange:
	luaL_argerror(L, index, "numeric value not representable as unsigned");

	return 0;
} /* unixL_checkunsigned() */

static unixL_Integer unixL_optinteger(lua_State *L, int index, unixL_Integer def, unixL_Integer min, unixL_Integer max) {
	if (lua_isnoneornil(L, index))
		return def;

	return unixL_checkinteger(L, index, min, max);
} /* unixL_optinteger() */

static int unixL_checkint(lua_State *L, int index) {
	return unixL_checkinteger(L, index, INT_MIN, INT_MAX);
} /* unixL_checkint() */

static int unixL_optint(lua_State *L, int index, int def) {
	return unixL_optinteger(L, index, def, INT_MIN, INT_MAX);
} /* unixL_optint() */

static int unixL_optfint(lua_State *L, int index, const char *name, int def) {
	int i;

	lua_getfield(L, index, name);
	i = unixL_optint(L, -1, def);
	lua_pop(L, 1);

	return i;
} /* unixL_optfint() */

static size_t unixL_checksize(lua_State *L, int index) {
	return unixL_checkunsigned(L, index, 0, MIN(UNIXL_UNSIGNED_MAX, SIZE_MAX));
} /* unixL_checksize() */

static void unixL_pushsize(lua_State *L, size_t size) {
	if (size > UNIXL_UNSIGNED_MAX)
		luaL_error(L, "size_t value not representable as unsigned");

	unixL_pushunsigned(L, size);
} /* unixL_pushsize() */

static off_t unixL_checkoff(lua_State *L, int index) {
	return unixL_checkinteger(L, index, MAX(UNIXL_INTEGER_MIN, U_TMIN(off_t)), MIN(UNIXL_INTEGER_MAX, U_TMAX(off_t)));
} /* unixL_checkoff() */

static off_t unixL_optoff(lua_State *L, int index, off_t def) {
	if (lua_isnoneornil(L, index))
		return def;

	return unixL_checkoff(L, index);
} /* unixL_optoff() */

static void unixL_pushoff(lua_State *L, off_t off) {
	if (off < UNIXL_INTEGER_MIN || off > UNIXL_INTEGER_MAX)
		luaL_error(L, "off_t value not representable as integer");

	unixL_pushunsigned(L, off);
} /* unixL_pushoff() */


static void *unixL_checklightuserdata(lua_State *L, int index) {
	luaL_checktype(L, index, LUA_TLIGHTUSERDATA);
	return lua_touserdata(L, index);
} /* unixL_checklightuserdata() */

static void *unixL_optlightuserdata(lua_State *L, int index) {
	if (lua_isnoneornil(L, index))
		return NULL;
	return unixL_checklightuserdata(L, index);
} /* unixL_optlightuserdata */


static struct iovec unixL_checkstring(lua_State *L, int index, size_t min, size_t max) {
	struct iovec iov;

	iov.iov_base = (void *)luaL_checklstring(L, index, &iov.iov_len);

	luaL_argcheck(L, iov.iov_len >= min, index, "string too short");
	luaL_argcheck(L, iov.iov_len <= max, index, "string too long");

	return iov;
} /* unixL_checkstring() */


static struct sockaddr *unixL_newsockaddr(lua_State *L, const void *addr, size_t addrlen) {
	void *ud;

	ud = lua_newuserdata(L, addrlen);
	memcpy(ud, addr, addrlen);
	luaL_setmetatable(L, "struct sockaddr");

	return ud;
} /* unixL_newsockaddr() */

static struct sockaddr *unixL_tosockaddr(lua_State *L, int index, size_t *len) {
	if (luaL_testudata(L, index, "struct sockaddr")) {
		*len = lua_rawlen(L, index);
		return lua_touserdata(L, index);
	} else if (lua_istable(L, index)) {
		unixL_State *U = unixL_getstate(L);
		int otop = lua_gettop(L);
		struct addrinfo hints = { 0 };
		struct sockaddr *addr;
		int error;

		index = lua_absindex(L, index);

		hints.ai_family = unixL_optfint(L, index, "family", AF_UNSPEC);
		/* Solaris errors with EAI_SERVICE unless we specify a socktype */
		hints.ai_socktype = unixL_optfint(L, index, "socktype", SOCK_STREAM);
		hints.ai_protocol = unixL_optfint(L, index, "protocol", 0);

		lua_getfield(L, index, "addr");
		lua_getfield(L, index, "port");

		u_freeaddrinfo(&U->net.res);
		error = getaddrinfo(lua_tostring(L, -2), lua_tostring(L, -1), &hints, &U->net.res);
		if (error) {
			U->net.res = NULL;
			goto null;
		}
		addr = unixL_newsockaddr(L, U->net.res->ai_addr, U->net.res->ai_addrlen);
		*len = U->net.res->ai_addrlen;
		u_freeaddrinfo(&U->net.res);

		lua_replace(L, index);
		lua_settop(L, otop);

		return addr;
	} else {
null:
		*len = 0;
		return NULL;
	}
} /* unixL_tosockaddr() */

static struct sockaddr *unixL_checksockaddr(lua_State *L, int index, size_t *len) {
	struct sockaddr *sa;

	if (!(sa = unixL_tosockaddr(L, index, len)))
		luaL_error(L, "expected struct sockaddr, got %s", lua_typename(L, lua_type(L, index)));

	return sa;
} /* unixL_checksockaddr() */

static int unixL_pusherror(lua_State *L, int error, const char *fun NOTUSED, const char *fmt) {
	int top = lua_gettop(L), fc;
	unixL_State *U = unixL_getstate(L);

	U->error = error;

	while ((fc = *fmt++)) {
		switch (fc) {
		case '~':
			lua_pushnil(L);

			break;
		case '#':
			unixL_pushinteger(L, error);

			break;
		case '$':
			lua_pushstring(L, unixL_strerror(L, error));

			break;
		case '0':
			lua_pushboolean(L, 0);

			break;
		default:
			break;
		}
	}

	return lua_gettop(L) - top;
} /* unixL_pusherror() */


/*
 * unixL_reopen: Support /proc/PID/fd/FD if available and if it provides the
 * proper semantics. The proper semantics are a new open file table entry
 * with separate status flags and cursors. In practice this means Linux,
 * NetBSD procfs, and Solaris (for regular files and directories only).
 * Whereas descriptors opened via BSD /dev/fd usually share status flags and
 * file position cursors.
 */
#define FD_PRIpid "1$ld"
#define FD_PRIfd  "2$d"
#define FD_PRIdev "3$lld"
#define FD_PRIino "4$lld"
#define FD_PRInul "5$c"

static u_error_t fd_reopen(int *fd, int ofd, const char *fspath, u_flags_t flags) {
	char path[sizeof ((unixL_State *)0)->fd.path];
	const char *dev, *ino, *nul;
	struct stat st = { 0 };
	int error;

	dev = strstr(fspath, "%"FD_PRIdev);
	ino = strstr(fspath, "%"FD_PRIino);
	nul = strstr(fspath, "%"FD_PRInul);

	if ((dev && (!nul || dev < nul)) || (ino && (!nul || ino < nul))) {
		if (0 != fstat(ofd, &st))
			return errno;
	}

	if ((error = u_snprintf(path, sizeof path, fspath, (long)getpid(), ofd, (long long)st.st_dev, (long long)st.st_ino, '\0')))
		return error;

	if ((error = u_getaccmode(ofd, &flags, flags)))
		return error;

	if (-1 == (*fd = open(path, U_SYSFLAGS & flags)))
		return errno;

	flags &= ~(U_CLOEXEC & U_SYSFLAGS);

	if ((error = u_fixflags(*fd, flags))) {
		u_close(fd);
		return error;
	}

	return 0;
} /* fd_reopen() */

static u_error_t fd_reopendir(int *fd, int ofd, u_flags_t flags) {
#if HAVE_OPENAT
	struct stat st = { 0 };
	int error;

	if ((error = u_getaccmode(ofd, &flags, flags)))
		return error;

	if (-1 == (*fd = openat(ofd, ".", U_SYSFLAGS & flags)))
		return errno;

	flags &= ~(U_CLOEXEC & U_SYSFLAGS);

	if ((error = u_fixflags(*fd, flags))) {
		u_close(fd);
		return error;
	}

	return 0;
#else
	(void)fd;
	(void)ofd;
	(void)flags;
	return ENOTSUP;
#endif
} /* fd_reopendir() */

static u_error_t fd_isdiff(int *diff, int fd1, int fd2, int flag) {
	int flags1, flags2;

	*diff = 0;

	/*
	 * Check first before trying to set. OS X is inconsistent when
	 * setting O_APPEND. It worked on fd2 (the tmpfd) but not fd1.
	 * Instead we open one of the files with O_APPEND.
	 */
	if (-1 == (flags1 = fcntl(fd1, F_GETFL)))
		return errno;
	if (-1 == (flags2 = fcntl(fd2, F_GETFL)))
		return errno;

	if ((*diff = (flags1 & flag) ^ (flags2 & flag)))
		return 0;

	if (0 != fcntl(fd1, F_SETFL, flags1 | flag))
		return errno;

	if (-1 == (flags1 = fcntl(fd1, F_GETFL)))
		return errno;
	if (-1 == (flags2 = fcntl(fd2, F_GETFL)))
		return errno;

	*diff = (flags1 & flag) ^ (flags2 & flag);

	return 0;
} /* fd_isdiff() */

static u_error_t fd_mktemp(lua_State *L, int *fd, char *tmpnam, size_t tmpsiz, u_flags_t flags, mode_t mode) {
	static const unsigned char base32[32] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
	static const char *tmpdir[] = { P_tmpdir, NULL, "/tmp", "/var/tmp" };
	char tmpext[17];
	size_t i, j;
	int error = 0;

	unixL_random_buf(L, tmpext, sizeof tmpext - 1, base32, sizeof base32);
	tmpext[sizeof tmpext - 1] = '\0';

	for (i = 0; i < countof(tmpdir); i++) {
		if (!tmpdir[i] && !(tmpdir[i] = getenv("TMPDIR")))
			continue;

		for (j = 0; j < i; j++) {
			if (tmpdir[j] && 0 == strcmp(tmpdir[i], tmpdir[j]))
				goto next;
		}

		if ((error = u_snprintf(tmpnam, tmpsiz, "%s/luaunix.%s", tmpdir[i], tmpext)))
			continue;

		if ((error = u_open(fd, tmpnam, flags|O_CREAT|O_EXCL, mode)))
			continue;

		return 0;
next:
		(void)0;
	}

	return (error)? error : ENOENT;
} /* fd_mktemp() */

static void fd_rmtemp(int *fd, const char *tmpnam) {
	if (*fd != -1) {
		(void)unlink(tmpnam);
		u_close(fd);
	}
} /* fd_rmtemp() */

static u_error_t fd_init(lua_State *L, unixL_State *U) {
	static const char *const paths[] = {
		"/proc/%"FD_PRIpid"/fd/%"FD_PRIfd"%"FD_PRInul"%"FD_PRIdev"%"FD_PRIino,
		"/dev/fd/%"FD_PRIfd"%"FD_PRInul"%"FD_PRIpid"%"FD_PRIdev"%"FD_PRIino,
		"/.vol/%"FD_PRIdev"/%"FD_PRIino"%"FD_PRInul"%"FD_PRIfd"%"FD_PRIpid
	};
	const char *const *path;
	int pipefd[2] = { -1, -1 }, tmpfd = -1, fd = -1, diff, error;
	char tmpnam[256];

	if (*U->fd.path)
		return 0;
	if (U->fd.error)
		return U->fd.error;

	/*
	 * Try pipe first because it doesn't require touching the file
	 * system.
	 */
	if ((error = u_pipe(pipefd, U_CLOEXEC)))
		goto error;

	for (path = paths; path < endof(paths); u_close(&fd), path++) {
		if ((error = fd_reopen(&fd, pipefd[0], *path, O_RDONLY|U_CLOEXEC)))
			continue;
		if ((error = fd_isdiff(&diff, fd, pipefd[0], O_NONBLOCK)))
			goto error;
		if (!diff)
			continue;

		if ((error = u_strcpy(U->fd.path, *path, sizeof U->fd.path)))
			goto error;

		error = 0;
		goto error;
	}

	/*
	 * Solaris /proc/PID/fd/FD only supports regular files and
	 * directories. Likewise for OS X /.vol/DEVICE/INODE, except
	 * that the file must still be linked.
	 */
	if ((error = fd_mktemp(L, &tmpfd, tmpnam, sizeof tmpnam, O_WRONLY|O_APPEND|U_CLOEXEC, 0600)))
		goto error;

	for (path = paths; path < endof(paths); u_close(&fd), path++) {
		if ((error = fd_reopen(&fd, tmpfd, *path, O_WRONLY|U_CLOEXEC)))
			continue;
		if ((error = fd_isdiff(&diff, fd, tmpfd, O_APPEND)))
			goto error;
		if (!diff)
			continue;

		if ((error = u_strcpy(U->fd.path, *path, sizeof U->fd.path)))
			goto error;

		error = 0;
		goto error;
	}

	error = ENOTSUP;
	goto error;
error:
	u_close(&pipefd[0]);
	u_close(&pipefd[1]);
	fd_rmtemp(&tmpfd, tmpnam);
	u_close(&fd);

	return U->fd.error = error;
} /* fd_init() */

static u_error_t unixL_reopen(lua_State *L, int *fd, int ofd, u_flags_t flags) {
	unixL_State *U = unixL_getstate(L);
	int error;

	*fd = -1;

	if ((error = fd_init(L, U)))
		goto error;

	if ((error = fd_reopen(fd, ofd, U->fd.path, flags)))
		goto error;

	return 0;
error:
	if (0 == fd_reopendir(fd, ofd, flags))
		return 0;

	return error;
} /* unixL_reopen() */


static u_error_t unixL_readdir(lua_State *L, DIR *dp, struct dirent **ent) {
	unixL_State *U = unixL_getstate(L);

	if (U->dir.dp != dp) {
		long namemax = fpathconf(dirfd(dp), _PC_NAME_MAX);
		size_t bufsiz;

		if (namemax == -1)
			return errno;

		bufsiz = sizeof (struct dirent) + namemax + 1;

		if (bufsiz > U->dir.bufsiz) {
			void *entbuf = realloc(U->dir.ent, bufsiz);

			if (!entbuf)
				return errno;

			U->dir.ent = entbuf;
			U->dir.bufsiz = bufsiz;
		}

		U->dir.dp = dp;
	}

	return u_readdir_r(dp, U->dir.ent, ent);
} /* unixL_readdir() */


static u_error_t unixL_closedir(lua_State *L, DIR **dp) {
	unixL_State *U = unixL_getstate(L);
	int error = 0;

	if (*dp) {
		if (U->dir.dp == *dp)
			U->dir.dp = NULL;

		if (0 != closedir(*dp))
			error = errno;

		*dp = NULL;
	}

	return error;
} /* unixL_closedir() */


static int unixL_getpwnam(lua_State *L, const char *user, struct passwd **ent) {
	unixL_State *U = unixL_getstate(L);
	int error;

	*ent = NULL;

	while ((error = u_getpwnam_r(user, &U->pw.ent, U->pw.buf, U->pw.bufsiz, ent))) {
		if (error != ERANGE)
			return error;

		if ((error = u_realloc(&U->pw.buf, &U->pw.bufsiz, 128)))
			return error;

		*ent = NULL;
	}

	return 0;
} /* unixL_getpwnam() */


static int unixL_getpwuid(lua_State *L, uid_t uid, struct passwd **ent) {
	unixL_State *U = unixL_getstate(L);
	int error;

	*ent = NULL;

	while ((error = u_getpwuid_r(uid, &U->pw.ent, U->pw.buf, U->pw.bufsiz, ent))) {
		if (error != ERANGE)
			return error;

		if ((error = u_realloc(&U->pw.buf, &U->pw.bufsiz, 128)))
			return error;

		*ent = NULL;
	}

	return 0;
} /* unixL_getpwuid() */


static int unixL_getgrnam(lua_State *L, const char *group, struct group **ent) {
	unixL_State *U = unixL_getstate(L);
	int error;

	*ent = NULL;

	while ((error = u_getgrnam_r(group, &U->gr.ent, U->gr.buf, U->gr.bufsiz, ent))) {
		if (error != ERANGE)
			return error;

		if ((error = u_realloc(&U->gr.buf, &U->gr.bufsiz, 128)))
			return error;

		*ent = NULL;
	}

	return 0;
} /* unixL_getgrnam() */


static int unixL_getgrgid(lua_State *L, gid_t gid, struct group **ent) {
	unixL_State *U = unixL_getstate(L);
	int error;

	*ent = NULL;

	while ((error = u_getgrgid_r(gid, &U->gr.ent, U->gr.buf, U->gr.bufsiz, ent))) {
		if (error != ERANGE)
			return error;

		if ((error = u_realloc(&U->gr.buf, &U->gr.bufsiz, 128)))
			return error;

		*ent = NULL;
	}

	return 0;
} /* unixL_getgrgid() */


static uid_t unixL_optuid(lua_State *L, int index, uid_t def) {
	const char *user;
	struct passwd *pw;
	int error;

	if (lua_isnoneornil(L, index))
		return def;

	if (lua_isnumber(L, index))
		return lua_tonumber(L, index);

	user = luaL_checkstring(L, index);

	if ((error = unixL_getpwnam(L, user, &pw)))
		return luaL_error(L, "%s: %s", user, unixL_strerror(L, error));

	if (!pw)
		return luaL_error(L, "%s: no such user", user);

	return pw->pw_uid;
} /* unixL_optuid() */


static uid_t unixL_checkuid(lua_State *L, int index) {
	luaL_checkany(L, index);

	return unixL_optuid(L, index, -1);
} /* unixL_checkuid() */


static gid_t unixL_optgid(lua_State *L, int index, gid_t def) {
	const char *group;
	struct group *gr;
	int error;

	if (lua_isnoneornil(L, index))
		return def;

	if (lua_isnumber(L, index))
		return lua_tonumber(L, index);

	group = luaL_checkstring(L, index);

	if ((error = unixL_getgrnam(L, group, &gr)))
		return luaL_error(L, "%s: %s", group, unixL_strerror(L, error));

	if (!gr)
		return luaL_error(L, "%s: no such group", group);

	return gr->gr_gid;
} /* unixL_optgid() */


static gid_t unixL_checkgid(lua_State *L, int index) {
	luaL_checkany(L, index);

	return unixL_optgid(L, index, -1);
} /* unixL_checkgid() */


static pid_t unixL_checkpid(lua_State *L, int index) {
	return unixL_checkinteger(L, index, U_TMIN(pid_t), U_TMAX(pid_t));
} /* unixL_checkpid() */


#if HAVE_STRUCT_PSINFO
MAYBEUSED static int pr_psinfo(struct psinfo *pr) {
	char path[64];
	int fd = -1, error;
	ssize_t n;

	if ((error = u_snprintf(path, sizeof path, "/proc/%ld/psinfo", (long)getpid())))
		goto error;

	if ((error = u_open(&fd, path, O_RDONLY|U_CLOEXEC, 0)))
		goto error;

	if (-1 == (n = read(fd, pr, sizeof *pr))) {
		error = errno;
		goto error;
	} else if ((size_t)n != sizeof *pr) {
		error = EIO;
		goto error;
	}

	u_close(&fd);

	return 0;
error:
	u_close(&fd);

	return error;
} /* pr_psinfo() */
#endif

static int ts_nthreads_psinfo(void) {
#if HAVE_STRUCT_PSINFO_PR_NLWP
	struct psinfo pr;
	int error;

	if ((error = pr_psinfo(&pr)))
		return -1;

	if (pr.pr_nlwp > INT_MAX)
		return -1;

	return pr.pr_nlwp;
#else
	return -1;
#endif
} /* ts_nthreads_psinfo() */

static int ts_nthreads_pstatus(void) {
#if SIZEOF_STRUCT_PSTATUS_PR_NLWP > 0 && OFFSETOF_STRUCT_PSTATUS_PR_NLWP >= 0
	char data[OFFSETOF_STRUCT_PSTATUS_PR_NLWP + SIZEOF_STRUCT_PSTATUS_PR_NLWP];
	char path[64];
	int fd = -1, pr_nlwp;

	if (SIZEOF_STRUCT_PSTATUS_PR_NLWP != sizeof pr_nlwp)
		goto oops;

	if (0 > snprintf(path, sizeof path, "/proc/%ld/status", (long)getpid()))
		goto oops;

	if (0 != u_open(&fd, path, O_RDONLY|U_CLOEXEC, 0))
		goto oops;

	if (sizeof data != read(fd, data, sizeof data))
		goto oops;

	u_close(&fd);

	memcpy(&pr_nlwp, &data[OFFSETOF_STRUCT_PSTATUS_PR_NLWP], SIZEOF_STRUCT_PSTATUS_PR_NLWP);

	return pr_nlwp;
oops:
	u_close(&fd);

	return -1;
#elif defined __linux
	/*
	 * TODO: Add support for Linux /proc/self/status or /proc/self/stat
	 * (Only one of them properly supports newlines in path name.)
	 */
	return -1;
#else
	return -1;
#endif
} /* ts_nthreads_pstatus() */

MAYBEUSED static int ts_nthreads(void) {
	int n;

	if ((n = ts_nthreads_psinfo()) > 0)
		return n;
	if ((n = ts_nthreads_pstatus()) > 0)
		return n;

	return -1;
} /* ts_nthreads() */

static int ts_reset(unixL_State *U) {
	if (!U->ts.pid || U->ts.pid != getpid()) {
		int error;

		u_close(&U->ts.fd[0]);
		u_close(&U->ts.fd[1]);
		U->ts.pid = 0;

		if ((error = u_pipe(U->ts.fd, O_NONBLOCK|U_CLOEXEC)))
			return error;

		U->ts.pid = getpid();
	} else {
		mode_t mask;

		while (read(U->ts.fd[0], &mask, sizeof mask) > 0)
			;;
	}

	return 0;
} /* ts_reset() */

static mode_t unixL_getumask(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	pid_t pid;
	mode_t mask;
	int error, status;
	ssize_t n;

#if 0
	if (ts_nthreads() == 1) {
		mask = umask(0);
		umask(mask);

		return mask;
	}
#endif

	if ((error = ts_reset(U)))
		return luaL_error(L, "getumask: %s", unixL_strerror(L, error));

	switch ((pid = fork())) {
	case -1:
		return luaL_error(L, "getumask: %s", unixL_strerror(L, errno));
	case 0:
		mask = umask(0777);

		if (sizeof mask != write(U->ts.fd[1], &mask, sizeof mask))
			_Exit(1);

		_Exit(0);

		break;
	default:
		while (-1 == waitpid(pid, &status, 0)) {
			if (errno == ECHILD)
				break; /* somebody else caught it */
			else if (errno == EINTR)
				continue;

			return luaL_error(L, "getumask: %s", unixL_strerror(L, errno));
		}

		if (sizeof mask != (n = read(U->ts.fd[0], &mask, sizeof mask)))
			return luaL_error(L, "getumask: %s", (n == -1)? unixL_strerror(L, errno) : "short read");

		return mask;
	}

	return 0;
} /* unixL_getumask() */


/*
 * Rough attempt to match POSIX chmod(1) utility semantics.
 */
static mode_t unixL_optmode(lua_State *L, int index, mode_t def, mode_t omode) {
	const char *fmt;
	char *end;
	mode_t svtx, cmask, omask, mask, perm, mode;
	int op;

	if (lua_isnoneornil(L, index))
		return def;

	fmt = luaL_checkstring(L, index);

	mode = 07777 & strtoul(fmt, &end, 0);

	if (*end == '\0' && end != fmt)
		return mode;

	svtx = (S_ISDIR(omode))? 01000 : 0000;
	cmask = 0;
	mode = 0;
	mask = 0;

	while (*fmt) {
		omask = ~01000 & mask;
		mask = 0;
		op = 0;
		perm = 0;

		for (; *fmt; ++fmt) {
			switch (*fmt) {
			case 'u':
				mask |= 04700;

				continue;
			case 'g':
				mask |= 02070;

				continue;
			case 'o':
				mask |= 00007; /* no svtx/sticky bit */

				continue;
			case 'a':
				mask |= 06777 | svtx;

				continue;
			case '+':
			case '-':
			case '=':
				op = *fmt++;

				goto perms;
			case ',':
				omask = 0;

				continue;
			default:
				continue;
			} /* switch() */
		} /* for() */

perms:
		for (; *fmt; ++fmt) {
			switch (*fmt) {
			case 'r':
				perm |= 00444;

				continue;
			case 'w':
				perm |= 00222;

				continue;
			case 'x':
				perm |= 00111;

				continue;
			case 'X':
				if (S_ISDIR(omode) || (omode & 00111))
					perm |= 00111;

				continue;
			case 's':
				perm |= 06000;

				continue;
			case 't':
				perm |= 01000;

				continue;
			case 'u':
				perm |= (00700 & omode);
				perm |= (00700 & omode) >> 3;
				perm |= (00700 & omode) >> 6;

				continue;
			case 'g':
				perm |= (00070 & omode) << 3;
				perm |= (00070 & omode);
				perm |= (00070 & omode) >> 3;

				continue;
			case 'o':
				perm |= (00007 & omode);
				perm |= (00007 & omode) << 3;
				perm |= (00007 & omode) << 6;

				continue;
			default:
				if (isspace((unsigned char)*fmt))
					continue;

				goto apply;
			} /* switch() */
		} /* for() */

apply:
		if (!mask) {
			if (!omask) {
				if (!cmask) {
					/* only query once */
					cmask = 01000 | (0777 & unixL_getumask(L));
				}

				omask = 0777 & ~(~01000 & cmask);
			}

			mask = svtx | omask;
		}

		switch (op) {
		case '+':
			mode |= mask & perm;

			break;
		case '-':
			mode &= ~(mask & perm);

			break;
		case '=':
			mode = mask & perm;

			break;
		default:
			break;
		}
	} /* while() */

	return mode;
} /* unixL_optmode() */


static mode_t unixL_checkmode(lua_State *L, int index, mode_t omode) {
	luaL_argcheck(L, !lua_isnoneornil(L, index), index, "mode not specified");

	return unixL_optmode(L, index, 0, omode);
} /* unixL_checkmode() */


static FILE *unixL_checkfile(lua_State *L, int index) {
	luaL_Stream *fh = luaL_checkudata(L, index, LUA_FILEHANDLE);

	luaL_argcheck(L, fh->f != NULL, index, "attempt to use a closed file");

	return fh->f;
} /* unixL_checkfile() */


static int unixL_xoptfileno(lua_State *L, int index, int def, _Bool atok) {
	luaL_Stream *fh;
	DIR **dp;
	int fd;

	if ((fh = luaL_testudata(L, index, LUA_FILEHANDLE))) {
		luaL_argcheck(L, fh->f != NULL, index, "attempt to use a closed file");

		fd = fileno(fh->f);

		luaL_argcheck(L, fd >= 0, index, "attempt to use irregular file (no descriptor)");

		return fd;
	}

	if ((dp = luaL_testudata(L, index, "DIR*"))) {
		luaL_argcheck(L, *dp != NULL, index, "attempt to use a closed directory");

		fd = dirfd(*dp);

		luaL_argcheck(L, fd >= 0, index, "attempt to use irregular directory (no descriptor)");

		return fd;
	}

	/* bindings like chdir accept string paths, so don't coerce */
	if (lua_type(L, index) == LUA_TNUMBER) {
		fd = lua_tointeger(L, index);

		if (fd < 0 && !(atok && u_isatfd(fd)))
			luaL_argcheck(L, 0, index, lua_pushfstring(L, "bad file descriptor (%d)", fd));

		return fd;
	}

	return def;
} /* unixL_xoptfileno() */


static int unixL_optfileno(lua_State *L, int index, int def) {
	return unixL_xoptfileno(L, index, def, 0);
} /* unixL_optfileno() */


static int unixL_optatfileno(lua_State *L, int index, int def) {
	return unixL_xoptfileno(L, index, def, 1);
} /* unixL_optatfileno() */


static int unixL_checkfileno(lua_State *L, int index) {
	int fd = unixL_optfileno(L, index, -1);

	luaL_argcheck(L, fd >= 0, index, "no file descriptor specified");

	return fd;
} /* unixL_checkfileno() */


static int unixL_checkatfileno(lua_State *L, int index) {
	int fd = unixL_optatfileno(L, index, -1);

	luaL_argcheck(L, fd >= 0 || u_isatfd(fd), index, "no file descriptor specified");

	return fd;
} /* unixL_checkatfileno() */


static int unixL_closef(lua_State *L) {
	luaL_Stream *fh = lua_touserdata(L, 1);

	if (fh && fh->f) {
		fclose(fh->f);
		fh->f = NULL;
#if LUA_VERSION_NUM >= 502
		fh->closef = NULL;
#endif
	}

	return 0;
} /* unixL_closef() */

static struct luaL_Stream *unixL_prepfile(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	luaL_Stream *fh;

	if (U->lua.jit) {
		static const char *const local[] = { ".", "/dev/null" };
		const char *const *path, *const *ppath = NULL;

		if (U->lua.openf == LUA_NOREF || U->lua.openf == LUA_REFNIL)
			luaL_error(L, "unable to create new file handle: LuaJIT io.open function not available");

		for (path = &local[0]; path < endof(local); ppath = path++) {
			lua_rawgeti(L, LUA_REGISTRYINDEX, U->lua.openf);
			lua_pushstring(L, *path);
			lua_pushstring(L, "r");
			lua_call(L, 2, 2);

			if (!lua_isnil(L, -2))
				break;

			lua_pop(L, 2);
		}

		if (lua_isnil(L, -2))
			luaL_error(L, "unable to create a new file handle: %s: %s", *ppath, luaL_checkstring(L, -1));

		lua_pop(L, 1);

		fh = luaL_checkudata(L, -1, LUA_FILEHANDLE);

		if (fh->f) {
			fclose(fh->f);
			fh->f = NULL;
		}
	} else {
		fh = lua_newuserdata(L, sizeof *fh);
		memset(fh, 0, sizeof *fh);
		luaL_getmetatable(L, LUA_FILEHANDLE);
		lua_setmetatable(L, -2);

#if LUA_VERSION_NUM == 501
		lua_rawgeti(L, LUA_REGISTRYINDEX, U->lua.opene);
		lua_setfenv(L, -2);
#elif LUA_VERSION_NUM >= 502
		fh->closef = &unixL_closef;
#endif
	}

	return fh;
} /* unixL_prepfile() */


static void unixL_checkflags(lua_State *L, int index, const char **mode, u_flags_t *flags, mode_t *perm) {
	index = lua_absindex(L, index);

	if (lua_isnoneornil(L, index) || lua_isnumber(L, index)) {
		*flags = unixL_optinteger(L, index, 0, 0, U_TMAX(u_flags_t));
		*mode = NULL;
	} else {
		*mode = luaL_checkstring(L, index);
		*flags = u_toflags(*mode);
	}

	if (perm) {
		*perm = (*flags & O_CREAT)? unixL_optmode(L, index + 1, 0666, 0666) : 0;
	}
} /* unixL_checkflags() */


static struct tm *unixL_checktm(lua_State *L, int index, struct tm *tm) {
	luaL_checktype(L, 1, LUA_TTABLE);

	tm->tm_year = unixL_optfint(L, index, "year", tm->tm_year + 1900) - 1900;
	tm->tm_mon = unixL_optfint(L, index, "month", tm->tm_mon + 1) - 1;
	tm->tm_mday = unixL_optfint(L, index, "day", tm->tm_mday);
	tm->tm_hour = unixL_optfint(L, index, "hour", tm->tm_hour);
	tm->tm_min = unixL_optfint(L, index, "min", tm->tm_min);
	tm->tm_sec = unixL_optfint(L, index, "sec", tm->tm_sec);
	tm->tm_wday = unixL_optfint(L, index, "wday", tm->tm_wday + 1) - 1;
	tm->tm_yday = unixL_optfint(L, index, "yday", tm->tm_yday + 1) - 1;

	lua_getfield(L, 1, "isdst");
	if (!lua_isnil(L, -1)) {
		tm->tm_isdst = lua_toboolean(L, -1);
	}
	lua_pop(L, 1);

	return tm;
} /* unixL_checktm() */


static struct tm *unixL_opttm(lua_State *L, int index, const struct tm *def, struct tm *tm) {
	if (lua_isnoneornil(L, index)) {
		if (def) {
			*tm = *def;
		} else {
			time_t now = time(NULL);

			gmtime_r(&now, tm);
		}

		return tm;
	} else {
		return unixL_checktm(L, index, tm);
	}
} /* unixL_opttm() */


#if __APPLE__
#define U_CLOCK_REALTIME  1
#define U_CLOCK_MONOTONIC 2
#else
#define U_CLOCK_REALTIME  CLOCK_REALTIME
#define U_CLOCK_MONOTONIC CLOCK_MONOTONIC
#endif

static int unixL_optclockid(lua_State *L, int index, int def) {
	const char *id;

	if (lua_isnoneornil(L, index))
		return def;
	if (lua_isnumber(L, index))
		return luaL_checkint(L, index);

	id = luaL_checkstring(L, index);

	switch (*((*id == '*')? id+1 : id)) {
	case 'r':
		return U_CLOCK_REALTIME;
	case 'm':
		return U_CLOCK_MONOTONIC;
	default:
		return luaL_argerror(L, index, lua_pushfstring(L, "%s: invalid clock", id));
	}
} /* unixL_optclockid() */


/*
 * The thread-safety of getenv varies widely.
 *
 * Solaris is completely thread-safe, even including traversal of environ.
 * It's "solution" is to leak memory all over the place, though.
 *
 * Linux/glibc is thread-tolerant in that it will not free variables, but it
 * might scribble over existing ones. It uses locking internally, but direct
 * use of environ is not safe.
 *
 * NetBSD uses locking internally but doesn't attempt to make getenv
 * thread-safe. NetBSD provides getenv_r.
 *
 * Neither FreeBSD nor OpenBSD even implement locking internally. I assume
 * that neither does OS X.
 */
static int unixL_getenv(lua_State *L, int index) {
#if HAVE_GETENV_R
	const char *name = luaL_checkstring(L, index);
	luaL_Buffer B;
	char *dst;

	luaL_buffinit(L, &B);
	dst = luaL_prepbuffer(&B);

	if (0 != getenv_r(name, dst, LUAL_BUFFERSIZE)) {
		if (errno == ENOENT)
			return 0;

		return luaL_error(L, "%s: %s", name, unixL_strerror(L, errno));
	}

	luaL_addsize(&B, strlen(dst));
	luaL_pushresult(&B);

	return 1;
#else
	const char *value;

	if (!(value = getenv(luaL_checkstring(L, index))))
		return 0;

	lua_pushstring(L, value);

	return 1;
#endif
} /* unixL_getenv() */


static int unixL_setenv(lua_State *L, int nameindex, int valueindex, int chgindex) {
	const char *name = luaL_checkstring(L, nameindex);
	const char *value = luaL_checkstring(L, valueindex);
	int change = (lua_isnone(L, chgindex))? 1 : lua_toboolean(L, chgindex);

	if (0 != setenv(name, value, change))
		return unixL_pusherror(L, errno, "setenv", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unixL_setenv() */


static int unixL_unsetenv(lua_State *L, int index) {
	if (0 != unsetenv(luaL_checkstring(L, index)))
		return unixL_pusherror(L, errno, "unsetenv", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unixL_unsetenv() */


static int env__index(lua_State *L) {
	return unixL_getenv(L, 2);
} /* env__index() */


static int env__newindex(lua_State *L) {
	lua_settop(L, 3); /* ensure index 4 is LUA_TNONE */
	return unixL_setenv(L, 2, 3, 4);
} /* env__newindex() */


static int env_nextipair(lua_State *L) {
	const char *src;
	size_t end, p;
	luaL_Buffer B;
	int ch;

	src = lua_tolstring(L, lua_upvalueindex(2), &end);
	p = lua_tointeger(L, lua_upvalueindex(3));

	luaL_buffinit(L, &B);

	lua_pushinteger(L, lua_tointeger(L, 2) + 1);

	while (p < end) {
		switch ((ch = src[p++])) {
		case '\0':
			luaL_pushresult(&B);

			/* save state */
			lua_pushinteger(L, p);
			lua_replace(L, lua_upvalueindex(3));

			return 2;
		default:
			luaL_addchar(&B, ch);

			break;
		}
	}

	return 0;
} /* env_nextipair() */


static int env_nextpair(lua_State *L) {
	const char *src;
	size_t end, p;
	luaL_Buffer B;
	int goteq, ch;

	src = lua_tolstring(L, lua_upvalueindex(2), &end);
	p = lua_tointeger(L, lua_upvalueindex(3));

next:
	lua_settop(L, 0);
	luaL_buffinit(L, &B);
	goteq = 0;

	while (p < end) {
		switch ((ch = src[p++])) {
		case '\0':
			if (!goteq)
				goto next;

			luaL_pushresult(&B);

			/* save state */
			lua_pushinteger(L, p);
			lua_replace(L, lua_upvalueindex(3));

			return 2;
		case '=':
			if (!goteq) {
				luaL_pushresult(&B);
				luaL_buffinit(L, &B);
				goteq = 1;

				break;
			}

			/* FALL THROUGH */
		default:
			luaL_addchar(&B, ch);

			break;
		}
	}

	return 0;
} /* env_nextpair() */


/*
 * TODO: Try to do this in a thread-safe manner which doesn't also create
 * additional thread-safety issues in unsuspecting application code. The
 * safest approach is to fork before we serialize environ, and then send it
 * over a pipe. Although that's not entirely safe either because some
 * implementations use realloc to resize environ, or otherwise free it
 * before updating the global pointer or ensuring its visible using a memory
 * barrier.
 */
static int env_getitr(lua_State *L, int ipairs) {
	extern char **environ;
	unixL_State *U = unixL_getstate(L);
	char **ep = environ, *cp;
	size_t p = 0;
	int error;

	/* take snapshot of environ */
	for (; ep && *ep; ep++) {
		for (cp = *ep; *cp; cp++) {
			if ((error = u_appendc(&U->buf, &U->bufsiz, &p, *cp)))
				return luaL_error(L, "%s", unixL_strerror(L, error));
		}

		if ((error = u_appendc(&U->buf, &U->bufsiz, &p, '\0')))
			return luaL_error(L, "%s", unixL_strerror(L, error));
	}

	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushlstring(L, U->buf, p);
	lua_pushinteger(L, 0);
	lua_pushcclosure(L, (ipairs)? &env_nextipair : &env_nextpair, 3);

	return 1;
} /* env_getitr() */


static int env__pairs(lua_State *L) {
	return env_getitr(L, 0);
} /* env__pairs() */


static int env__ipairs(lua_State *L) {
	return env_getitr(L, 1);
} /* env__ipairs() */


static const luaL_Reg env_metamethods[] = {
	{ "__index",    &env__index },
	{ "__newindex", &env__newindex },
	{ "__pairs",    &env__pairs },
	{ "__call",     &env__pairs }, /* Lua 5.1 doesn't have __pairs */
	{ "__ipairs",   &env__ipairs },
	{ NULL,         NULL },
}; /* env_metamethods[] */


/* from ipairsaux in Lua source */
static int unixL_nextipair(lua_State *L) {
	int i = luaL_checkint(L, 2);
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_pushinteger(L, ++i);
	lua_rawgeti(L, 1, i);
	return (lua_isnil(L, -1))? 1 : 2;
} /* unixL_nextipair() */


/* emulate ipairs because missing from Lua 5.1 */
static void unixL_ipairs(lua_State *L, int index) {
	if (luaL_getmetafield(L, index, "__ipairs")) {
		lua_pushvalue(L, index);
		lua_call(L, 1, 3);
	} else {
		lua_pushcfunction(L, &unixL_nextipair);
		lua_pushvalue(L, index);
		lua_pushinteger(L, 0);
	}
} /* unixL_ipairs() */

#define IPAIRS_BEGIN(L, index) \
	do { \
	unixL_ipairs((L), (index)); \
	for (;;) { \
		lua_pushvalue(L, -3); /* iterator */ \
		lua_pushvalue(L, -3); /* table */ \
		lua_pushvalue(L, -3); /* index */ \
		lua_call(L, 2, 2); \
		if (lua_isnil(L, -1)) { \
			lua_pop(L, 5); \
			break; \
		} else { \
			lua_pushvalue(L, -2); \
			lua_replace(L, -4); /* update index */ \
		}

#define IPAIRS_END(L) \
	lua_pop(L, 2); } } while (0)

#define IPAIRS_STOP(L) if (1) { lua_pop(L, 5); break; }


static sigset_t *unixL_tosigset(lua_State *L, int index, sigset_t *buf) {
	sigset_t tmp, *set;

	if ((set = luaL_testudata(L, index, "sigset_t")))
		return set;

	sigemptyset(&tmp);

	if (lua_istable(L, index)) {
		IPAIRS_BEGIN(L, index);
		sigaddset(&tmp, luaL_checkint(L, -1));
		IPAIRS_END(L);
	} else if (lua_isnumber(L, index)) {
		sigaddset(&tmp, luaL_checkint(L, index));
	} else {
		static const char *opts[] = { "*", "", NULL };

		switch (luaL_checkoption(L, index, "", opts)) {
		case 0:
			sigfillset(&tmp);

			break;
		default:
			break;
		}
	}

	if (!buf) {
		index = lua_absindex(L, index);
		buf = lua_newuserdata(L, sizeof *buf);
		luaL_setmetatable(L, "sigset_t");
		lua_replace(L, index);
	}

	*buf = tmp;

	return buf;
} /* unixL_tosigset() */


static const luaL_Reg sigset_methods[] = {
	{ NULL, NULL }
}; /* sigset_methods[] */


static const luaL_Reg sigset_metamethods[] = {
	{ NULL, NULL }
}; /* sigset_metamethods[] */


static u_sighandler_t *unixL_tosighandler(lua_State *L, int index) {
	return *(u_sighandler_t **)luaL_checkudata(L, index, "sighandler_t*");
} /* unixL_tosighandler() */


static const luaL_Reg sighandler_methods[] = {
	{ NULL, NULL }
}; /* sighandler_methods[] */


static int sighandler__eq(lua_State *L) {
	/*
	 * NOTE: All versions of Lua up to and including Lua 5.3.0 don't
	 * appear to check whether two userdata objects share the same __eq
	 * metamethod. The 5.1-5.3 manuals, however, document that a
	 * comparison metamethod is only selected and executed if both
	 * objects share it for the operation.
	 */
	u_sighandler_t **op1 = luaL_testudata(L, 1, "sighandler_t*");
	u_sighandler_t **op2 = luaL_testudata(L, 2, "sighandler_t*");

	lua_pushboolean(L, op1 && op2 && (*op1 == *op2));

	return 1;
} /* sighandler__eq() */

static const luaL_Reg sighandler_metamethods[] = {
	{ "__eq", &sighandler__eq },
	{ NULL,   NULL }
}; /* sighandler_metamethods[] */


static int unix_accept(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkfileno(L, 1);
	int flags = unixL_optint(L, 2, 0);
	socklen_t salen;
	int error;

	u_close(&U->net.fd);

	if (U->bufsiz < sizeof (struct sockaddr) && (error = u_realloc(&U->buf, &U->bufsiz, sizeof (struct sockaddr))))
		return unixL_pusherror(L, error, "accept", "~$#");

	salen = MAX(INT_MAX, U->bufsiz);
#if HAVE_ACCEPT4
	U->net.fd = accept4(fd, (struct sockaddr *)U->buf, &salen, flags);
#elif HAVE_PACCEPT
	U->net.fd = paccept(fd, (struct sockaddr *)U->buf, &salen, NULL, flags);
#else
	U->net.fd = accept(fd, (struct sockaddr *)U->buf, &salen);
#endif
	if (U->net.fd == -1)
		goto syerr;

	lua_pushinteger(L, U->net.fd);
	if (salen <= U->bufsiz) {
		unixL_newsockaddr(L, U->buf, salen);
	} else {
		if ((error = unixL_getsockname(L, U->net.fd, &getpeername)))
			goto error;
	}
	U->net.fd = -1;

	return 2;
syerr:
	error = errno;
error:
	u_close(&U->net.fd);
	return unixL_pusherror(L, error, "accept", "~$#");
} /* unix_accept() */


static int unix_alarm(lua_State *L) {
	unsigned n = unixL_checkunsigned(L, 1, 0, U_TMAX(unsigned));

	unixL_pushunsigned(L, alarm(n));

	return 1;
} /* unix_alarm() */


static int unix_arc4random(lua_State *L) {
	unixL_pushunsigned(L, unixL_random(L));

	return 1;
} /* unix_arc4random() */


static int unix_arc4random_buf(lua_State *L) {
	size_t count = luaL_checkinteger(L, 1), n = 0;
	union {
		uint32_t r[16];
		unsigned char c[16 * sizeof (uint32_t)];
	} tmp;
	luaL_Buffer B;

	luaL_buffinit(L, &B);

	while (n < count) {
		size_t m = MIN((size_t)(count - n), sizeof tmp.c);
		size_t i = howmany(m, sizeof tmp.r[0]);

		while (i-- > 0) {
			tmp.r[i] = unixL_random(L);
		}

		luaL_addlstring(&B, (char *)tmp.c, m);
		n += m;
	}

	luaL_pushresult(&B);

	return 1;
} /* unix_arc4random_buf() */


static int unix_arc4random_stir(lua_State *L) {
#if HAVE_ARC4RANDOM
#if ((__APPLE__ && !MACOS_PREREQ(10,12,0)) || (__FreeBSD__ && !FREEBSD_PREREQ(10,0))) && HAVE_ARC4RANDOM_ADDRANDOM
	/*
	 * Apple's arc4random uses /dev/urandom before 10.12, whereas the BSDs
	 * support a chroot-safe sysctl method.
	 */
	char junk[128];
	arc4random_addrandom(u_memjunk(junk, sizeof junk), sizeof junk);
#endif
#if HAVE_ARC4RANDOM_STIR
	arc4random_stir();
#endif
#else
	arc4_stir(&(unixL_getstate(L))->random, 1);
#endif

	lua_pushboolean(L, 1);

	return 1;
} /* unix_arc4random_stir() */


static int unix_arc4random_uniform(lua_State *L) {
	lua_Number modn = luaL_optnumber(L, 1, 4294967296.0);

	if (modn >= 4294967296.0) {
		unixL_pushunsigned(L, unixL_random(L));
	} else {
		uint32_t n = (uint32_t)modn;
		uint32_t r, min;

		min = -n % n;

		for (;;) {
			r = unixL_random(L);

			if (r >= min)
				break;
		}

		unixL_pushunsigned(L, r % n);
	}

	return 1;
} /* unix_arc4random_uniform() */


static int unix_bind(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	size_t addrlen;
	struct sockaddr *addr = unixL_checksockaddr(L, 2, &addrlen);

	if (0 != bind(fd, addr, addrlen))
		return unixL_pusherror(L, errno, "bind", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_bind() */


static int unix_bitand(lua_State *L) {
	unixL_pushinteger(L, unixL_checkinteger(L, 1) & unixL_checkinteger(L, 2));

	return 1;
} /* unix_bitand() */


static int unix_bitor(lua_State *L) {
	unixL_pushinteger(L, unixL_checkinteger(L, 1) | unixL_checkinteger(L, 2));

	return 1;
} /* unix_bitor() */


static int unsafe_calloc(lua_State *L) {
	size_t count = unixL_checksize(L, 1);
	size_t size = unixL_checksize(L, 2);
	void *addr;

	if (!(addr = calloc(count, size)) && count > 0 && size > 0)
		return unixL_pusherror(L, errno, "calloc", "~$#");

	lua_pushlightuserdata(L, addr);
	return 1;
} /* unsafe_calloc() */


static int unix_chdir(lua_State *L) {
	int fd;

	if (-1 != (fd = unixL_optfileno(L, 1, -1))) {
		if (0 != fchdir(fd))
			return unixL_pusherror(L, errno, "chdir", "0$#");
	} else {
		const char *path = luaL_checkstring(L, 1);

		if (0 != chdir(path))
			return unixL_pusherror(L, errno, "chdir", "0$#");
	}

	lua_pushboolean(L, 1);

	return 1;
} /* unix_chdir() */


static int unix_chmod(lua_State *L) {
	mode_t omode = 0777, mode;
	_Bool octal;
	struct stat st;
	int fd;

	luaL_checkany(L, 2);
	lua_pushvalue(L, 2);
	octal = lua_isnumber(L, -1); /* octal notation or literal number */
	lua_pop(L, 1);

	if (-1 != (fd = unixL_optfileno(L, 1, -1))) {
		if (!octal) {
			if (0 != fstat(fd, &st))
				return unixL_pusherror(L, errno, "chmod", "0$#");

			omode = st.st_mode;
		}

		mode = unixL_checkmode(L, 2, omode);

		if (0 != fchmod(fd, mode))
			return unixL_pusherror(L, errno, "chmod", "0$#");
	} else {
		const char *path = luaL_checkstring(L, 1);

		if (!octal) {
			if (0 != stat(path, &st))
				return unixL_pusherror(L, errno, "chmod", "0$#");

			omode = st.st_mode;
		}

		mode = unixL_checkmode(L, 2, omode);

		if (0 != chmod(path, mode))
			return unixL_pusherror(L, errno, "chmod", "0$#");
	}

	lua_pushboolean(L, 1);

	return 1;
} /* unix_chmod() */


static int unix_chown(lua_State *L) {
	uid_t uid = unixL_optuid(L, 2, -1);
	gid_t gid = unixL_optgid(L, 3, -1);
	int fd;

	if (-1 != (fd = unixL_optfileno(L, 1, -1))) {
		if (0 != fchown(fd, uid, gid))
			return unixL_pusherror(L, errno, "chown", "0$#");
	} else {
		const char *path = luaL_checkstring(L, 1);

		if (0 != chown(path, uid, gid))
			return unixL_pusherror(L, errno, "chown", "0$#");
	}

	lua_pushboolean(L, 1);

	return 1;
} /* unix_chown() */


static int unix_chroot(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);

	if (0 != chroot(path))
		return unixL_pusherror(L, errno, "chroot", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_chroot() */


static int unix_clearerr(lua_State *L) {
	clearerr(unixL_checkfile(L, 1));

	lua_pushvalue(L, 1);

	return 1;
} /* unix_clearerr() */


static int unix_clock_gettime(lua_State *L) {
#if __APPLE__
	unixL_State *U = unixL_getstate(L);
	int id = unixL_optclockid(L, 1, U_CLOCK_REALTIME);
	struct timeval tv;
	struct timespec ts;
#if USE_CLOCK_GET_TIME
	mach_timespec_t abt;
#else
	uint64_t abt;
#endif

	switch (id) {
	case U_CLOCK_REALTIME:
		if (0 != gettimeofday(&tv, NULL))
			return unixL_pusherror(L, errno, "clock_gettime", "~$#");

		TIMEVAL_TO_TIMESPEC(&tv, &ts);

		break;
	case U_CLOCK_MONOTONIC:
#if USE_CLOCK_GET_TIME
		if (KERN_SUCCESS != clock_get_time(U->tm.clock, &abt))
			return unixL_pusherror(L, ENOTSUP, "clock_gettime", "~$#");

		ts.tv_sec = abt.tv_sec;
		ts.tv_nsec = abt.tv_nsec;
#else
		/*
		 * NOTE: On some platforms mach_absolute_time uses the CPU
		 * TSC, on some architectures the TSC is not invariant
		 * across cores or processor packages, and Apple does not
		 * document that mach_absolute_time will account for such
		 * invariance. By contrast, Linux clock_gettime() will use
		 * the TSC as an optimization but still guarantees monotonic
		 * behavior even when the TSC is not invariant.
		 *
		 * If mach_absolute_time isn't invariant then clock_get_time
		 * should be used. However, clock_get_time isn't used by
		 * default because
		 *
		 * 1) clock_get_time is ~15x slower than mach_absolute_time
		 * on x86;
		 *
		 * 2) on all x86 platforms that Apple ships the TSC is
		 * invariant across both cores and packages, has been
		 * invariant for several generations, and will continue to
		 * be invariant in the future according to Intel;
		 *
		 * 3) on some platforms mach_absolute_time appears to be
		 * implemented as a read of a Mach commpage (shared data
		 * between userspace and kernel), which is probably updated
		 * by an HPET, in which case it would be simple to make the
		 * timestamp monotonic.
		 *
		 * In other words, mach_absolute_time is and probably will
		 * continue to be invariant across cores and packages,
		 * notwithstanding that it might use a CPU TSC.
		 *
		 * NOTE: While monotonic, mach_absolute_time is not steady,
		 * according to my Google research. If the device enters a
		 * sleep mode than the kernel does not seem to jump
		 * mach_absolute_time forward.
		 */
		abt = mach_absolute_time();
		abt = abt * U->tm.timebase.numer / U->tm.timebase.denom;

		ts.tv_sec = abt / 1000000000L;
		ts.tv_nsec = abt % 1000000000L;
#endif
		break;
	default:
		return luaL_argerror(L, 1, "invalid clock");
	}
#else
	int id = unixL_optclockid(L, 1, U_CLOCK_REALTIME);
	struct timespec ts;

	if (0 != clock_gettime(id, &ts))
		return unixL_pusherror(L, errno, "clock_gettime", "~$#");
#endif

	if (lua_isnoneornil(L, 2) || !lua_toboolean(L, 2)) {
		lua_pushnumber(L, u_ts2f(&ts));

		return 1;
	} else {
		unixL_pushinteger(L, ts.tv_sec);
		unixL_pushinteger(L, ts.tv_nsec);

		return 2;
	}
} /* unix_clock_gettime() */


static int unix_compl(lua_State *L) {
	unixL_pushinteger(L, ~unixL_checkinteger(L, 1));

	return 1;
} /* unix_compl() */


static int unix_connect(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	size_t addrlen;
	struct sockaddr *addr = unixL_checksockaddr(L, 2, &addrlen);

	if (0 != connect(fd, addr, addrlen))
		return unixL_pusherror(L, errno, "connect", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_connect() */


static int unix_close(lua_State *L) {
	if (lua_isuserdata(L, 1) || lua_istable(L, 1)) {
		int nret;

		lua_settop(L, 1);

		lua_getfield(L, 1, "close");
		lua_pushvalue(L, 1);
		lua_call(L, 1, LUA_MULTRET);

		if ((nret = lua_gettop(L) - 1)) {
			return nret;
		} else {
			/*
			 * Lua 5.1's closef handler only returns value on
			 * failure.
			 */
			lua_pushboolean(L, 1);
			return 1;
		}
	} else {
		int fd = unixL_checkinteger(L, 1, U_TMIN(int), U_TMAX(int));
		int error;

		if ((error = u_close_nocancel(fd)))
			return unixL_pusherror(L, error, "close", "0$#");

		lua_pushboolean(L, 1);

		return 1;
	}
} /* unix_close() */


static int dir_close(lua_State *);

static int unix_closedir(lua_State *L) {
	return dir_close(L);
} /* unix_closedir() */


static int unix_closelog(lua_State *L) {
	(void)L;
	closelog();
	return 0;
} /* unix_closelog() */


static int unix_dup(lua_State *L) {
	int ofd = unixL_checkfileno(L, 1);
	u_flags_t flags = luaL_optinteger(L, 2, 0);
	int nfd, error;

	if ((error = u_dup(&nfd, ofd, flags)))
		return unixL_pusherror(L, error, "dup", "~$#");

	lua_pushinteger(L, nfd);

	return 1;
} /* unix_dup() */


static int unix_dup2(lua_State *L) {
	int ofd = unixL_checkfileno(L, 1);
	int nfd = unixL_checkfileno(L, 2);
	u_flags_t flags = luaL_optinteger(L, 3, 0);
	int error;

	if ((error = u_dup2(ofd, nfd, flags)))
		return unixL_pusherror(L, error, "dup2", "~$#");

	lua_pushinteger(L, nfd);

	return 1;
} /* unix_dup2() */


#if HAVE_DUP3
static int unix_dup3(lua_State *L) {
	int ofd = unixL_checkfileno(L, 1);
	int nfd = unixL_checkfileno(L, 2);
	u_flags_t flags = unixL_checkinteger(L, 3, U_FLAGS_MIN, U_FLAGS_MAX);
	int error;

	if ((error = u_dup2(ofd, nfd, flags)))
		return unixL_pusherror(L, error, "dup2", "~$#");

	lua_pushinteger(L, nfd);

	return 1;
} /* unix_dup3() */
#endif


static u_error_t exec_addarg(unixL_State *U, size_t *arrp, const char *s) {
	int error;

	if ((error = u_reallocarray_char_pp(&U->exec.arr, &U->exec.arrsiz, (*arrp)+1)))
		return error;

	U->exec.arr[(*arrp)++] = (char *)(s);

	return 0;
} /* exec_addarg() */


static u_error_t exec_addtable(lua_State *L, unixL_State *U, size_t *arrp, int index, int anchorindex) {
	size_t i = 0;
	int error = 0;

	IPAIRS_BEGIN(L, index);

	if (i++ >= INT_MAX)
		IPAIRS_STOP(L);

	if ((error = exec_addarg(U, arrp, luaL_checkstring(L, -1))))
		IPAIRS_STOP(L);

	lua_pushvalue(L, -1);
	lua_rawseti(L, anchorindex, *arrp); /* anchor value */

	IPAIRS_END(L);

	return error;
} /* exec_addtable() */


static int unix_execve(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	const char *path = luaL_checkstring(L, 1);
	size_t arrp = 0, argc = 0;
	int error;

	lua_settop(L, 3); /* path, argv, env */
	lua_newtable(L); /* string anchor */

	if (!lua_isnil(L, 2)) {
		if ((error = exec_addtable(L, U, &arrp, 2, 4)))
			goto error;
	}

	argc = arrp;

	if ((error = exec_addarg(U, &arrp, NULL)))
		goto error;

	if (!lua_isnil(L, 3)) {
		if ((error = exec_addtable(L, U, &arrp, 3, 4)))
			goto error;
	}

	if ((error = exec_addarg(U, &arrp, NULL)))
		goto error;

	execve(path, U->exec.arr, &U->exec.arr[argc + 1]);
	error = errno;
error:
	return unixL_pusherror(L, error, "execve", "0$#");
} /* unix_execve() */


static int unix_execl(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	const char *path = luaL_checkstring(L, 1);
	size_t arrp = 0;
	int top, i, error;

	top = lua_gettop(L);

	for (i = 2; i <= top; i++) {
		if ((error = exec_addarg(U, &arrp, luaL_checkstring(L, i))))
			goto error;
	}

	if ((error = exec_addarg(U, &arrp, NULL)))
		goto error;

	execv(path, U->exec.arr);
	error = errno;
error:
	return unixL_pusherror(L, error, "execl", "0$#");
} /* unix_execl() */


static int unix_execlp(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	const char *file = luaL_checkstring(L, 1);
	size_t arrp = 0;
	int top, i, error;

	top = lua_gettop(L);

	for (i = 2; i <= top; i++) {
		if ((error = exec_addarg(U, &arrp, luaL_checkstring(L, i))))
			goto error;
	}

	if ((error = exec_addarg(U, &arrp, NULL)))
		goto error;

	execvp(file, U->exec.arr);
	error = errno;
error:
	return unixL_pusherror(L, error, "execlp", "0$#");
} /* unix_execlp() */


static int unix_execvp(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	const char *file = luaL_checkstring(L, 1);
	size_t arrp = 0;
	int error;

	lua_settop(L, 2); /* file, argv */
	lua_newtable(L); /* string anchor */

	if (!lua_isnil(L, 2)) {
		if ((error = exec_addtable(L, U, &arrp, 2, 3)))
			goto error;
	}

	if ((error = exec_addarg(U, &arrp, NULL)))
		goto error;

	execvp(file, U->exec.arr);
	error = errno;
error:
	return unixL_pusherror(L, error, "execvp", "0$#");
} /* unix_execvp() */


static int unix__exit(lua_State *L) {
	int status;

	if (lua_isboolean(L, 1))
		status = (lua_toboolean(L, 1))? EXIT_SUCCESS : EXIT_FAILURE;
	else
		status = luaL_optint(L, 1, EXIT_SUCCESS);

	if (L) /* quiet statement not reached warning */
		_exit(status);

	return 0;
} /* unix__exit() */


static int unix_exit(lua_State *L) {
	int status;
	if (lua_isboolean(L, 1))
		status = (lua_toboolean(L, 1))? EXIT_SUCCESS : EXIT_FAILURE;
	else
		status = luaL_optint(L, 1, EXIT_SUCCESS);

	if (L) /* quiet statement not reached warning */
		exit(status);

	return 0;
} /* unix_exit() */


static int fcntl_flock(lua_State *L, int fd, int cmd, int index) {
	struct flock l = { 0 };

	l.l_type = F_WRLCK;
	l.l_whence = SEEK_SET;

	if (!lua_isnoneornil(L, index)) {
		luaL_checktype(L, index, LUA_TTABLE);

		lua_getfield(L, index, "type");
		l.l_type = luaL_optint(L, -1, l.l_type);
		lua_pop(L, 1);

		lua_getfield(L, index, "whence");
		l.l_whence = luaL_optint(L, -1, l.l_whence);
		lua_pop(L, 1);

		lua_getfield(L, index, "start");
		l.l_start = luaL_optint(L, -1, l.l_start);
		lua_pop(L, 1);

		lua_getfield(L, index, "len");
		l.l_len = luaL_optint(L, -1, l.l_len);
		lua_pop(L, 1);
	}

	if (-1 == fcntl(fd, cmd, &l))
		return unixL_pusherror(L, errno, "fcntl", "~$#");

	if (cmd == F_GETLK) {
		lua_createtable(L, 0, 5);

		lua_pushinteger(L, l.l_type);
		lua_setfield(L, -2, "type");

		lua_pushinteger(L, l.l_whence);
		lua_setfield(L, -2, "whence");

		lua_pushinteger(L, l.l_start);
		lua_setfield(L, -2, "start");

		lua_pushinteger(L, l.l_len);
		lua_setfield(L, -2, "len");

		lua_pushinteger(L, l.l_pid);
		lua_setfield(L, -2, "pid");

		return 1;
	} else {
		lua_pushboolean(L, 1);

		return 1;
	}
} /* fcntl_flock() */


static int unix_fcntl(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int cmd = luaL_checkint(L, 2);
	u_flags_t flags;
	int dupfd, pid, error;

	switch (cmd) {
#if defined F_DUPFD_CLOEXEC
	case F_DUPFD_CLOEXEC:
		/* FALL THROUGH */
#endif
#if defined F_DUP2FD_CLOEXEC
	case F_DUP2FD_CLOEXEC:
		/* FALL THROUGH */
#endif
#if defined F_DUP2FD
	case F_DUP2FD:
		/* FALL THROUGH */
#endif
	case F_DUPFD:
		if (-1 == (dupfd = fcntl(fd, cmd, unixL_checkfileno(L, 3))))
			goto syerr;

		unixL_pushinteger(L, dupfd);

		return 1;
	case F_GETFD:
		if ((flags = fcntl(fd, cmd)) < 0)
			goto syerr;

		unixL_pushinteger(L, flags);

		return 1;
	case F_GETFL:
		if ((error = u_getflags(fd, &flags)))
			goto error;

		unixL_pushinteger(L, flags);

		return 1;
	case F_SETFD:
		if (-1 == fcntl(fd, cmd, (int)luaL_checkint(L, 3)))
			goto syerr;

		lua_pushboolean(L, 1);

		return 1;
	case F_SETFL:
		flags = luaL_checknumber(L, 3);

		if (-1 == fcntl(fd, cmd, (int)(U_SYSFLAGS & flags)))
			goto syerr;

		if (flags & U_CLOEXEC) {
			if (-1 == fcntl(fd, F_SETFD, FD_CLOEXEC))
				goto syerr;
		}

		lua_pushboolean(L, 1);

		return 1;
	case F_GETOWN:
		if (-1 == (pid = fcntl(fd, cmd)))
			goto syerr;

		lua_pushinteger(L, pid);

		return 1;
	case F_SETOWN:
		pid = luaL_checkint(L, 3);

		if (-1 == fcntl(fd, cmd, pid))
			goto syerr;

		lua_pushboolean(L, 1);

		return 1;
	case F_GETLK:
	case F_SETLK:
	case F_SETLKW:
		return fcntl_flock(L, fd, cmd, 3);
#if defined F_CLOSEM
	case F_CLOSEM:
		if (-1 == fcntl(fd, cmd))
			goto syerr;

		lua_pushboolean(L, 1);

		return 1;
#endif
#if defined F_MAXFD
	case F_MAXFD: {
		int maxfd;

		if (-1 == (maxfd = fcntl(fd, cmd)))
			goto syerr;

		lua_pushinteger(L, maxfd);

		return 1;
	}
#endif
#if defined F_GETPATH
	case F_GETPATH: {
		unixL_State *U = unixL_getstate(L);

		if (U->bufsiz < MAXPATHLEN + 1) {
			if ((error = u_realloc(&U->buf, &U->bufsiz, MAXPATHLEN + 1)))
				goto error;
		}

		if (-1 == fcntl(fd, cmd, U->buf))
			goto syerr;

		lua_pushstring(L, U->buf);

		return 1;
	}
#endif
	default:
		/*
		 * NOTE: We don't allow unsupported operations because we
		 * cannot know the argument type that fcntl expects. If it's
		 * a pointer then this interface becomes a vector for
		 * reading or writing random process memory.
		 */
		return luaL_error(L, "%d: unsupported fcntl operation", cmd);
	} /* switch () */
syerr:
	error = errno;
error:
	return unixL_pusherror(L, error, "fcntl", "~$#");
} /* unix_fcntl() */


static int unsafe_fcntl(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int cmd = luaL_checkint(L, 2);
	int n, r, error;

	n = lua_gettop(L);
	luaL_argcheck(L, n <= 3, 4, lua_pushfstring(L, "expected 3 arguments, got %d", n));

	switch (lua_type(L, 3)) {
	case LUA_TNONE: {
		if (-1 == (r = fcntl(fd, cmd, (intptr_t)0)))
			goto syerr;

		lua_pushinteger(L, r);
		return 1;
	}
	case LUA_TNUMBER: {
		intptr_t arg = unixL_checkinteger(L, 3, INTPTR_MIN, INTPTR_MAX);

		if (-1 == (r = fcntl(fd, cmd, arg)))
			goto syerr;

		lua_pushinteger(L, r);
		return 1;
	}
	case LUA_TSTRING: {
		const struct iovec iov = unixL_checkstring(L, 3, 0, SIZE_MAX);
		unixL_State *U = unixL_getstate(L);

		if (U->bufsiz < iov.iov_len && (error = u_realloc(&U->buf, &U->bufsiz, iov.iov_len)))
			goto error;
		memcpy(U->buf, iov.iov_base, iov.iov_len);

		if (-1 == (r = fcntl(fd, cmd, U->buf)))
			goto syerr;

		lua_pushinteger(L, r);
		lua_pushlstring(L, U->buf, iov.iov_len);
		return 2;
	}
	}

	return luaL_argerror(L, 3, lua_pushfstring(L, "expected integer or string, got %s", luaL_typename(L, 3)));
syerr:
	error = errno;
error:
	return unixL_pusherror(L, error, "fcntl", "~$#");
} /* unsafe_fcntl() */


#if HAVE_FDATASYNC
static int unix_fdatasync(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);

	if (0 != fdatasync(fd))
		return unixL_pusherror(L, errno, "fdatasync", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_fdatasync() */
#endif


static int unix_fdopen(lua_State *L) {
	u_flags_t flags;
	const char *mode;
	int fd, error;
	luaL_Stream *fh;

	lua_settop(L, 2);
	luaL_argcheck(L, lua_type(L, 1) != LUA_TUSERDATA, 1, "cannot steal descriptor from existing handle");
	fd = unixL_checkfileno(L, 1);
	unixL_checkflags(L, 2, &mode, &flags, NULL);

	fh = unixL_prepfile(L);

	if ((error = u_fdopen(&fh->f, &fd, mode, flags)))
		return unixL_pusherror(L, error, "fdopen", "~$#");

	return 1;
} /* unix_fdopen() */


#if HAVE_FDOPENDIR
static int unix_fdopendir(lua_State *L) {
	DIR **dp;
	int fd, error;

	lua_settop(L, 1);
	luaL_argcheck(L, lua_type(L, 1) != LUA_TUSERDATA, 1, "cannot steal descriptor from existing handle");
	fd = unixL_checkfileno(L, 1);

	dp = lua_newuserdata(L, sizeof *dp);
	*dp = NULL;
	luaL_setmetatable(L, "DIR*");

	if ((error = u_fdopendir(dp, &fd, 0)))
		return unixL_pusherror(L, error, "fdopendir", "~$#");

	return 1;
} /* unix_fdopendir() */
#endif /* HAVE_FDOPENDIR */


static int unix_fdup(lua_State *L) {
	int fd = -1, ofd, error;
	u_flags_t flags;
	const char *mode;
	luaL_Stream *fh;

	lua_settop(L, 2);
	ofd = unixL_checkfileno(L, 1);
	unixL_checkflags(L, 2, &mode, &flags, NULL);

	fh = unixL_prepfile(L);

	if ((error = u_dup(&fd, ofd, flags)))
		goto error;

	if ((error = u_fdopen(&fh->f, &fd, mode, flags)))
		goto error;

	return 1;
error:
	u_close(&fd);

	return unixL_pusherror(L, error, "fopen", "~$#");
} /* unix_fdup() */


static int unix_feof(lua_State *L) {
	lua_pushboolean(L, feof(unixL_checkfile(L, 1)));
	return 1;
} /* unix_feof() */


static int unix_ferror(lua_State *L) {
	lua_pushboolean(L, ferror(unixL_checkfile(L, 1)));
	return 1;
} /* unix_ferror() */


static int unix_fgetc(lua_State *L) {
	FILE *fp = unixL_checkfile(L, 1);
	int c;

	if (EOF == (c = fgetc(fp))) {
		if (ferror(fp))
			return unixL_pusherror(L, errno, "fgetc", "~$#");

		return 0;
	}

	lua_pushinteger(L, c);

	return 1;
} /* unix_fgetc() */


static int unix_fileno(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);

	lua_pushinteger(L, fd);

	return 1;
} /* unix_fileno() */


static int unix_flockfile(lua_State *L) {
	flockfile(unixL_checkfile(L, 1));

	lua_pushboolean(L, 1);

	return 1;
} /* unix_flockfile() */


#if HAVE_FMEMOPEN
static int unsafe_fmemopen(lua_State *L) {
	void *addr = unixL_checklightuserdata(L, 1);
	size_t size = unixL_checksize(L, 2);
	const char *mode = luaL_checkstring(L, 3);
	luaL_Stream *fh;

	fh = unixL_prepfile(L);
	if (!(fh->f = fmemopen(addr, size, mode)))
		return unixL_pusherror(L, errno, "fmemopen", "~$#");

	return 1;
} /* unsafe_fmemopen() */
#endif


static int unix_fnmatch(lua_State *L) {
	const char *patt = luaL_checkstring(L, 1);
	const char *subject = luaL_checkstring(L, 2);
	int flags = luaL_optint(L, 3, 0);

	switch (fnmatch(patt, subject, flags)) {
	case 0:
		lua_pushboolean(L, 1);
		lua_pushboolean(L, 1);
		return 2;
	case FNM_NOMATCH:
		lua_pushboolean(L, 1);
		lua_pushboolean(L, 0);
		return 2;
	default:
		return unixL_pusherror(L, errno, "fnmatch", "~$#");
	}
} /* unix_fnmatch() */


static int unsafe_free(lua_State *L) {
	free(unixL_checklightuserdata(L, 1));
	return 0;
} /* unsafe_free() */


#if HAVE_FSTATAT
static int st_pushstat(lua_State *L, const struct stat *, int);

static int unix_fstatat(lua_State *L) {
	int at = unixL_checkatfileno(L, 1);
	const char *path = luaL_checkstring(L, 2);
	int flags = unixL_optint(L, 3, 0);
	struct stat st;

	if (0 != fstatat(at, path, &st, flags))
		return unixL_pusherror(L, errno, "fstatat", "~$#");

	return st_pushstat(L, &st, 4);
} /* unix_fstatat() */
#endif


static int unix_fsync(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);

	if (0 != fsync(fd))
		return unixL_pusherror(L, errno, "fsync", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_fsync() */


static int unix_ftrylockfile(lua_State *L) {
	lua_pushboolean(L, 0 == ftrylockfile(unixL_checkfile(L, 1)));

	return 1;
} /* unix_ftrylockfile() */


static int unix_funlockfile(lua_State *L) {
	funlockfile(unixL_checkfile(L, 1));

	lua_pushboolean(L, 1);

	return 1;
} /* unix_funlockfile() */


static int unix_fopen(lua_State *L) {
	int fd = -1, ofd, error;
	u_flags_t flags;
	const char *mode;
	mode_t perm;
	luaL_Stream *fh;

	lua_settop(L, 3);
	unixL_checkflags(L, 2, &mode, &flags, &perm);

	fh = unixL_prepfile(L);

	if (-1 != (ofd = unixL_optfileno(L, 1, -1))) {
		if ((error = unixL_reopen(L, &fd, ofd, flags)))
			goto error;

		if ((error = u_fdopen(&fh->f, &fd, mode, flags)))
			goto error;
	} else {
		const char *path = luaL_checkstring(L, 1);

		if (mode) {
			if (!(fh->f = fopen(path, mode)))
				goto syerr;
		} else {
			if ((error = u_open(&fd, path, flags, perm)))
				goto error;

			if (!(fh->f = fdopen(fd, u_strmode(flags))))
				goto syerr;

			fd = -1;
		}
	}

	return 1;
syerr:
	error = errno;
error:
	u_close(&fd);

	return unixL_pusherror(L, error, "fopen", "~$#");
} /* unix_fopen() */


#if HAVE_OPENAT
static int unix_fopenat(lua_State *L) {
	int fd = -1, at, error;
	const char *path, *mode;
	u_flags_t flags;
	mode_t perm;
	luaL_Stream *fh;

	lua_settop(L, 4);
	at = unixL_checkatfileno(L, 1);
	path = luaL_checkstring(L, 2);
	unixL_checkflags(L, 3, &mode, &flags, &perm);

	fh = unixL_prepfile(L);
	if (-1 == (fd = openat(at, path, flags, perm)))
		goto syerr;
	/* should we use string mode if specified? */
	if (!(fh->f = fdopen(fd, u_strmode(flags))))
		goto syerr;
	fd = -1;

	return 1;
syerr:
	error = errno;
	u_close(&fd);

	return unixL_pusherror(L, error, "fopenat", "~$#");
} /* unix_fopenat() */
#endif


static int unix_fpipe(lua_State *L) {
	int fd[2] = { -1, -1 }, error;
	luaL_Stream *fh[2] = { NULL, NULL };
	u_flags_t flags;
	const char *mode;

	lua_settop(L, 1);
	unixL_checkflags(L, 1, &mode, &flags, NULL);

	mode = NULL;
	flags &= ~(O_ACCMODE|O_APPEND);

	fh[0] = unixL_prepfile(L);
	fh[1] = unixL_prepfile(L);

	if ((error = u_pipe(fd, flags)))
		goto error;

	if ((error = u_fdopen(&fh[0]->f, &fd[0], mode, flags|O_RDONLY)))
		goto error;
	if ((error = u_fdopen(&fh[1]->f, &fd[1], mode, flags|O_WRONLY)))
		goto error;

	return 2;
error:
	u_close(&fd[0]);
	u_close(&fd[1]);

	return unixL_pusherror(L, error, "pipe", "~$#");
} /* unix_fpipe() */


static int unix_fork(lua_State *L) {
	pid_t pid;

	if (-1 == (pid = fork()))
		return unixL_pusherror(L, errno, "fork", "~$#");

	lua_pushinteger(L, pid);

	return 1;
} /* unix_fork() */


static int unix_gai_strerror(lua_State *L) {
	lua_pushstring(L, gai_strerror(luaL_checkint(L, 1)));

	return 1;
} /* unix_gai_strerror() */


enum gai_field {
	GAI_FAMILY,
	GAI_SOCKTYPE,
	GAI_PROTOCOL,
	GAI_ADDR,
	GAI_CANONNAME,
	GAI_PORT,
}; /* enum gai_field */

static const char *gai_field[] = {
	"family", "socktype", "protocol", "addr", "canonname", "port", NULL
};

static int gai_pushaddr(lua_State *L, struct sockaddr *addr, socklen_t addrlen) {
	char host[NI_MAXHOST + 1];
	int error;

	if ((error = getnameinfo(addr, addrlen, host, sizeof host, NULL, 0, NI_NUMERICHOST))) {
		lua_pushnil(L);
	} else {
		lua_pushstring(L, host);
	}

	return 1;
} /* gai_pushaddr() */

static int gai_pushport(lua_State *L, struct sockaddr *addr) {
	switch (addr->sa_family) {
	case AF_INET:
		lua_pushinteger(L, ntohs(((struct sockaddr_in *)addr)->sin_port));
		break;
	case AF_INET6:
		lua_pushinteger(L, ntohs(((struct sockaddr_in6 *)addr)->sin6_port));
		break;
	default:
		lua_pushnil(L);
		break;
	}

	return 1;
} /* gai_pushport() */

static void gai_pushfield(lua_State *L, const struct addrinfo *res, enum gai_field type) {
	switch (type) {
	case GAI_FAMILY:
		lua_pushinteger(L, res->ai_family);
		break;
	case GAI_SOCKTYPE:
		lua_pushinteger(L, res->ai_socktype);
		break;
	case GAI_PROTOCOL:
		lua_pushinteger(L, res->ai_protocol);
		break;
	case GAI_ADDR:
		gai_pushaddr(L, res->ai_addr, res->ai_addrlen);
		break;
	case GAI_CANONNAME:
		if (res->ai_canonname) {
			lua_pushstring(L, res->ai_canonname);
		} else {
			lua_pushnil(L);
		}
		break;
	case GAI_PORT:
		gai_pushport(L, res->ai_addr);
		break;
	default:
		lua_pushnil(L);
		break;
	}
} /* gai_pushfield() */

static void gai_pushtable(lua_State *L, const struct addrinfo *res) {
	lua_createtable(L, 0, 6);

	gai_pushfield(L, res, GAI_FAMILY);
	lua_setfield(L, -2, "family");

	gai_pushfield(L, res, GAI_SOCKTYPE);
	lua_setfield(L, -2, "socktype");

	gai_pushfield(L, res, GAI_PROTOCOL);
	lua_setfield(L, -2, "protocol");

	gai_pushfield(L, res, GAI_ADDR);
	lua_setfield(L, -2, "addr");

	gai_pushfield(L, res, GAI_CANONNAME);
	lua_setfield(L, -2, "canonname");

	gai_pushfield(L, res, GAI_PORT);
	lua_setfield(L, -2, "port");
} /* gai_pushtable() */

static int gai_nextai(lua_State *L) {
	struct addrinfo *res = lua_touserdata(L, lua_upvalueindex(2));

	if (!res)
		return 0;

	lua_pushlightuserdata(L, res->ai_next);
	lua_replace(L, lua_upvalueindex(2));

	if (lua_isnone(L, lua_upvalueindex(4))) {
		gai_pushtable(L, res);

		return 1;
	} else {
		int i;

		for (i = 4; !lua_isnone(L, lua_upvalueindex(i)); i++) {
			gai_pushfield(L, res, luaL_checkoption(L, lua_upvalueindex(i), NULL, gai_field));
		}

		return i - 4;
	}
} /* gai_nextai() */

static int gai_pusherror(lua_State *L, int error) {
	if (error == EAI_SYSTEM) {
		int syerr = errno;

		lua_pushnil(L);
		lua_pushstring(L, unixL_strerror(L, syerr));
		lua_pushinteger(L, error);
		lua_pushinteger(L, syerr);

		return 4;
	} else {
		lua_pushnil(L);
		lua_pushstring(L, gai_strerror(error));
		lua_pushinteger(L, error);

		return 3;
	}
} /* gai_pusherror() */

static int unix_getaddrinfo(lua_State *L) {
	const char *host = luaL_optstring(L, 1, NULL);
	const char *serv = luaL_optstring(L, 2, NULL);
	/*
	 * POSIX 2013: "If hints is a null pointer, the behavior shall be as
	 * if it referred to a structure containing the value zero for the
	 * ai_flags, ai_socktype, and ai_protocol fields, and AF_UNSPEC for
	 * the ai_family field."
	 */
	struct addrinfo hints = { .ai_family = AF_UNSPEC }, **res;
	int error;

	if (!lua_isnoneornil(L, 3)) {
		luaL_checktype(L, 3, LUA_TTABLE);

		hints.ai_flags = unixL_optfint(L, 3, "flags", hints.ai_flags);
		hints.ai_family = unixL_optfint(L, 3, "family", hints.ai_family);
		hints.ai_socktype = unixL_optfint(L, 3, "socktype", hints.ai_socktype);
		hints.ai_protocol = unixL_optfint(L, 3, "protocol", hints.ai_protocol);
	}

	res = lua_newuserdata(L, sizeof *res);
	*res = NULL;
	luaL_setmetatable(L, "struct addrinfo*");

	if ((error = getaddrinfo(host, serv, &hints, res)))
		return gai_pusherror(L, error);

	lua_replace(L, 1);

	lua_pushlightuserdata(L, *res);
	lua_replace(L, 2);

	lua_pushcclosure(L, &gai_nextai, lua_gettop(L));

	return 1;
} /* unix_getaddrinfo() */


static int gai__gc(lua_State *L) {
	struct addrinfo **res = luaL_checkudata(L, 1, "struct addrinfo*");

	u_freeaddrinfo(res);

	return 0;
} /* gai__gc() */

static const luaL_Reg gai_methods[] = {
	{ NULL, NULL }
}; /* gai_methods[] */

static const luaL_Reg gai_metamethods[] = {
	{ "__gc", &gai__gc },
	{ NULL,   NULL }
}; /* gai_metamethods[] */


static int unix_getegid(lua_State *L) {
	lua_pushinteger(L, getegid());

	return 1;
} /* unix_getegid() */


static int unix_getenv(lua_State *L) {
	return unixL_getenv(L, 1);
} /* unix_getenv() */


static int unix_geteuid(lua_State *L) {
	lua_pushinteger(L, geteuid());

	return 1;
} /* unix_geteuid() */


static int unix_getmode(lua_State *L) {
	const char *fmt;
	char *end;
	mode_t omode;

	fmt = luaL_optstring(L, 2, "0777");
	omode = 07777 & strtoul(fmt, &end, 0);

	lua_pushinteger(L, unixL_optmode(L, 1, 0777, omode));

	return 1;
} /* unix_getmode() */


static int unix_getgid(lua_State *L) {
	lua_pushinteger(L, getgid());

	return 1;
} /* unix_getgid() */


static void gr_pushmem(lua_State *L, char **list, int create) {
	if (list) {
		int i;

		for (i = 0; list[i]; i++)
			;;

		if (create)
			lua_createtable(L, i, 0);

		for (i = 0; list[i]; i++) {
			lua_pushstring(L, list[i]);
			lua_rawseti(L, -2, i + 1);
		}
	} else {
		if (create)
			lua_createtable(L, 0, 0);
	}
} /* gr_pushmem() */

static int unix_getgrnam(lua_State *L) {
	struct group *ent;
	int error;

	if (lua_isnumber(L, 1)) {
		error = unixL_getgrgid(L, luaL_checkint(L, 1), &ent);
	} else {
		error = unixL_getgrnam(L, luaL_checkstring(L, 1), &ent);
	}

	if (error) {
		return unixL_pusherror(L, error, "getgrnam", "~$#");
	} else if (!ent) {
		lua_pushnil(L);
		lua_pushstring(L, "no such group");

		return 2;
	}

	if (lua_isnoneornil(L, 2)) {
		lua_createtable(L, 0, 4);

		if (ent->gr_name) {
			lua_pushstring(L, ent->gr_name);
			lua_setfield(L, -2, "name");
		}

		if (ent->gr_passwd) {
			lua_pushstring(L, ent->gr_passwd);
			lua_setfield(L, -2, "passwd");
		}

		lua_pushinteger(L, ent->gr_gid);
		lua_setfield(L, -2, "gid");

		gr_pushmem(L, ent->gr_mem, 0);

		return 1;
	} else {
		static const char *opts[] = {
			"name", "passwd", "gid", "mem", "members", NULL,
		};
		int i, n = 0, top = lua_gettop(L);

		for (i = 2; i <= top; i++) {
			switch (luaL_checkoption(L, i, NULL, opts)) {
			case 0: /* name */
				if (ent->gr_name)
					lua_pushstring(L, ent->gr_name);
				else
					lua_pushnil(L);
				++n;

				break;
			case 1: /* passwd */
				if (ent->gr_passwd)
					lua_pushstring(L, ent->gr_passwd);
				else
					lua_pushnil(L);
				++n;

				break;
			case 2: /* gid */
				lua_pushinteger(L, ent->gr_gid);
				++n;

				break;
			case 3: /* mem */
			case 4: /* members */
				gr_pushmem(L, ent->gr_mem, 1);
				++n;

				break;
			}
		}

		return n;
	}
} /* unix_getgrnam() */


static int unix_getgroups(lua_State *L) {
	gid_t *group;
	int n, count, i;

	/* avoid TOCTTOU bug by looping if getgroups fills extra slot */
	do {
		lua_settop(L, 0);

		if (-1 == (n = getgroups(0, NULL)))
			return unixL_pusherror(L, errno, "getgroups", "~$#");

		if (n == INT_MAX || (size_t)n + 1 > (size_t)-1 / sizeof *group)
			return unixL_pusherror(L, ENOMEM, "getgroups", "~$#");

		group = lua_newuserdata(L, (n + 1) * sizeof *group);

		if (-1 == (count = getgroups(n + 1, group)))
			return unixL_pusherror(L, errno, "getgroups", "~$#");
	} while (count > n);

	lua_createtable(L, count, 0);

	for (i = 0; i < count; i++) {
		lua_pushinteger(L, group[i]);
		lua_rawseti(L, -2, i + 1);
	}

	return 1;
} /* unix_getgroups() */


static int unix_gethostname(lua_State *L) {
	luaL_Buffer B;
	char *host;

	luaL_buffinit(L, &B);

	if (0 != gethostname((host = luaL_prepbuffer(&B)), LUAL_BUFFERSIZE))
		return unixL_pusherror(L, errno, "gethostname", "~$#");

	luaL_addsize(&B, strlen(host));
	luaL_pushresult(&B);

	return 1;
} /* unix_gethostname() */


enum ifs_field {
	IF_NAME,
	IF_FLAGS,
	IF_ADDR,
	IF_NETMASK,
	IF_DSTADDR,
	IF_BROADADDR,
	IF_DATA,
	IF_FAMILY,
	IF_PREFIXLEN,
}; /* enum ifs_field */

static const char *ifs_field[] = {
	"name", "flags", "addr", "netmask", "dstaddr", "broadaddr", "data",
	"family", "prefixlen", NULL
};

static int ifs_pushaddr(lua_State *L, struct sockaddr *sa) {
	char host[NI_MAXHOST + 1];
	int error;

	if ((error = getnameinfo(sa, u_sa_len(sa), host, sizeof host, NULL, 0, NI_NUMERICHOST))) {
		//return luaL_error(L, "getnameinfo: %s", gai_strerror(error));
		lua_pushnil(L);
	} else {
		lua_pushstring(L, host);
	}

	return 1;
} /* ifs_pushaddr() */

static void ifs_pushfield(lua_State *L, const struct u_ifaddrs *ifa, enum ifs_field type) {
	switch (type) {
	case IF_NAME:
		lua_pushstring(L, ifa->ifa_name);
		break;
	case IF_FLAGS:
		lua_pushinteger(L, ifa->ifa_flags);
		break;
	case IF_ADDR:
		if (ifa->ifa_addr) {
			ifs_pushaddr(L, ifa->ifa_addr);
		} else {
			lua_pushnil(L);
		}
		break;
	case IF_NETMASK:
		if (ifa->ifa_netmask) {
			ifs_pushaddr(L, ifa->ifa_netmask);
		} else {
			lua_pushnil(L);
		}
		break;
	case IF_BROADADDR:
		/* FALL THROUGH */
	case IF_DSTADDR:
		if (ifa->ifa_dstaddr) {
			ifs_pushaddr(L, ifa->ifa_dstaddr);
		} else {
			lua_pushnil(L);
		}
		break;
	case IF_DATA:
		lua_pushnil(L);
		break;
	case IF_FAMILY:
		if (ifa->ifa_addr) {
			lua_pushinteger(L, ifa->ifa_addr->sa_family);
		} else {
			lua_pushnil(L);
		}
		break;
	case IF_PREFIXLEN:
		if (ifa->ifa_netmask) {
			lua_pushinteger(L, u_sa_mask2prefixlen(ifa->ifa_netmask));
		} else {
			lua_pushnil(L);
		}
		break;
	default:
		lua_pushnil(L);
		break;
	}
} /* ifs_pushfield() */

static void ifs_pushtable(lua_State *L, const struct u_ifaddrs *ifa) {
	lua_createtable(L, 0, 7);

	ifs_pushfield(L, ifa, IF_NAME);
	lua_setfield(L, -2, "name");

	ifs_pushfield(L, ifa, IF_FLAGS);
	lua_setfield(L, -2, "flags");

	ifs_pushfield(L, ifa, IF_ADDR);
	lua_setfield(L, -2, "addr");

	ifs_pushfield(L, ifa, IF_NETMASK);
	lua_setfield(L, -2, "netmask");

#if defined IFF_BROADCAST
	if (ifa->ifa_flags & IFF_BROADCAST) {
		ifs_pushfield(L, ifa, IF_BROADADDR);
		lua_setfield(L, -2, "broadaddr");
	} else {
		ifs_pushfield(L, ifa, IF_DSTADDR);
		lua_setfield(L, -2, "dstaddr");
	}
#else
	ifs_pushfield(L, ifa, IF_DSTADDR);
	lua_setfield(L, -2, "dstaddr");
#endif

	ifs_pushfield(L, ifa, IF_DATA);
	lua_setfield(L, -2, "data");

	ifs_pushfield(L, ifa, IF_FAMILY);
	lua_setfield(L, -2, "family");

	ifs_pushfield(L, ifa, IF_PREFIXLEN);
	lua_setfield(L, -2, "prefixlen");
} /* ifs_pushtable() */

static int ifs_nextif(lua_State *L) {
	struct u_ifaddrs *ifa = lua_touserdata(L, lua_upvalueindex(2));

	if (!ifa)
		return 0;

	lua_pushlightuserdata(L, ifa->ifa_next);
	lua_replace(L, lua_upvalueindex(2));

	if (lua_isnone(L, lua_upvalueindex(3))) {
		ifs_pushtable(L, ifa);

		return 1;
	} else {
		int i;

		for (i = 3; !lua_isnone(L, lua_upvalueindex(i)); i++) {
			ifs_pushfield(L, ifa, luaL_checkoption(L, lua_upvalueindex(i), NULL, ifs_field));
		}

		return i - 3;
	}
} /* ifs_nextif() */

static int unix_getifaddrs(lua_State *L) {
	struct u_ifaddrs **ifs;
	int error;

	ifs = lua_newuserdata(L, sizeof *ifs);
	*ifs = NULL;
	luaL_setmetatable(L, "struct ifaddrs*");

	if ((error = u_getifaddrs(ifs)))
		return unixL_pusherror(L, error, "getifaddrs", "~$#");

	lua_insert(L, 1);

	lua_pushlightuserdata(L, *ifs);
	lua_insert(L, 2);

	lua_pushcclosure(L, &ifs_nextif, lua_gettop(L));

	return 1;
} /* unix_getifaddrs() */


static int ifs__gc(lua_State *L) {
	struct u_ifaddrs **ifs = luaL_checkudata(L, 1, "struct ifaddrs*");

	if (*ifs) {
		u_freeifaddrs(*ifs);
		*ifs = NULL;
	}

	return 0;
} /* ifs__gc() */


static const luaL_Reg ifs_methods[] = {
	{ NULL, NULL }
}; /* ifs_methods[] */


static const luaL_Reg ifs_metamethods[] = {
	{ "__gc", &ifs__gc },
	{ NULL,   NULL }
}; /* ifs_metamethods[] */


static int unix_getnameinfo(lua_State *L) {
	size_t salen;
	const struct sockaddr *sa = unixL_checksockaddr(L, 1, &salen);
	int flags = luaL_optint(L, 2, 0);
	char host[NI_MAXHOST];
	char serv[NI_MAXSERV];
	int error;

	if ((error = getnameinfo(sa, salen, host, sizeof host, serv, sizeof serv, flags)))
		return gai_pusherror(L, error);

	lua_pushstring(L, host);
	lua_pushstring(L, serv);

	return 2;
} /* unix_getnameinfo() */


static void getopt_pushoptc(lua_State *L, int optc) {
	char ch = (char)(unsigned char)optc;
	lua_pushlstring(L, &ch, 1);
} /* getopt_pushoptc() */

static int getopt_nextopt(lua_State *L) {
	unixL_State *U = lua_touserdata(L, lua_upvalueindex(1));
	struct u_getopt_r *opts = lua_touserdata(L, lua_upvalueindex(2));
	/* NB: upvalue 3 is our string anchoring table */
	char **argv = lua_touserdata(L, lua_upvalueindex(4));
	int argc = lua_tointeger(L, lua_upvalueindex(5));
	const char *shortopts = lua_tostring(L, lua_upvalueindex(6));
	int optc;

	optc = u_getopt_r(argc, argv, shortopts, opts);
	U->opt.optind = opts->optind;
	U->opt.optopt = opts->optopt;

	if (optc == -1)
		return 0;

	getopt_pushoptc(L, optc);

	if (optc == ':' || optc == '?') {
		getopt_pushoptc(L, U->opt.optopt);
	} else if (opts->optarg) {
		lua_pushstring(L, opts->optarg);
	} else {
		lua_pushnil(L);
	}

	/*
	 * NB: If returning optind in the future then adjust by arg0 to
	 * adhere to Lua indexing semantics if U->opt.arg0. See unix__index
	 * for unix.optint indexing.
	 */

	return 2;
} /* getopt_nextopt() */

static int getopt_pushargs(lua_State *L, int index) {
	unixL_State *U = unixL_getstate(L);
	const char **argv;
	size_t arg0, argc, i;
	int isnil;

	index = lua_absindex(L, index);
	luaL_checktype(L, index, LUA_TTABLE);

	/* determine whether table is 0-indexed or 1-indexed */
	lua_rawgeti(L, index, 0);
	U->opt.arg0 = arg0 = lua_isnil(L, -1)? 1 : 0;
	lua_pop(L, 1);

	/* count number of arguments */
	for (i = arg0, argc = 0, isnil = 0; i < SIZE_MAX && !isnil; i++, argc += !isnil) {
		lua_rawgeti(L, index, i);
		isnil = lua_isnil(L, -1);
		lua_pop(L, 1);
	}
	if (argc >= INT_MAX || argc >= (size_t)-1 / sizeof *argv)
		return unixL_pusherror(L, ENOMEM, "getopt", "~$#");

	/* duplicate argument table to guarantee strings remained anchored */
	lua_createtable(L, argc, 0);
	argv = lua_newuserdata(L, (argc + 1) * sizeof *argv);
	for (i = 0; i < argc; i++) {
		lua_rawgeti(L, index, i + arg0);
		argv[i] = lua_tostring(L, -1); /* coerce to string */
		lua_rawseti(L, -3, i + arg0); /* anchor coerced string */
	}
	argv[argc] = NULL;

	lua_pushinteger(L, argc);

	return 3;
} /* getopt_pushargs() */

static int unix_getopt(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	struct u_getopt_r *opts;

	lua_settop(L, 2);
	luaL_checktype(L, 1, LUA_TTABLE);
	luaL_checkstring(L, 2);

	/* push unixL_State */
	lua_pushvalue(L, lua_upvalueindex(1));

	/* push getopt_r state */
	opts = lua_newuserdata(L, sizeof *opts);
	U_GETOPT_R_INIT(opts);
	opts->opterr = U->opt.opterr;

	/* push arguments as 3 values: local table, argv array, argc int */
	getopt_pushargs(L, 1); /* pushes 3 values */

	/* push shortopts */
	lua_pushvalue(L, 2);

	lua_pushcclosure(L, &getopt_nextopt, 6);

	return 1;
} /* unix_getopt() */


static int unix_getpeername(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int error;

	if ((error = unixL_getsockname(L, fd, &getpeername)))
		return unixL_pusherror(L, error, "getpeername", "~$#");

	return 1;
} /* unix_getpeername() */


static int unix_getpgid(lua_State *L) {
	pid_t pid = unixL_checkpid(L, 1);
	pid_t pgid;

	if (-1 == (pgid = getpgid(pid)))
		return unixL_pusherror(L, errno, "getpgid", "~$#");

	lua_pushinteger(L, pgid);

	return 1;
} /* unix_getpgid() */


static int unix_getpgrp(lua_State *L) {
	lua_pushinteger(L, getpgrp());

	return 1;
} /* unix_getpgrp() */


static int unix_getpid(lua_State *L) {
	lua_pushinteger(L, getpid());

	return 1;
} /* unix_getpid() */


static int unix_getppid(lua_State *L) {
	lua_pushinteger(L, getppid());

	return 1;
} /* unix_getppid() */


MAYBEUSED static const char *getprogname_basename(const char *path) {
	const char *name;
	return ((name = strrchr(path, '/')))? ++name : path;
}

static int unix_getprogname(lua_State *L) {
	const char *name = NULL;

#if HAVE_GETPROGNAME
	name = getprogname();
#elif HAVE_GETEXECNAME
	const char *path;

	if (!(path = getexecname()))
		goto notsup;

	name = getprogname_basename(path);
#elif HAVE_PROGRAM_INVOCATION_SHORT_NAME
	name = program_invocation_short_name;
#elif HAVE_STRUCT_PSINFO_PR_FNAME
	struct psinfo pr;
	int error;

	if ((error = pr_psinfo(&pr)))
		return unixL_pusherror(L, error, "getprogname", "~$#");

	name = pr.pr_fname;
#elif HAVE_P_XARGV
#if !HAVE_DECL_P_XARGV
	extern char **p_xargv;
#endif
	if (!*p_xargv)
		goto notsup;

	name = getprogname_basename(*p_xargv);
#endif

	if (!name || !*name)
		goto notsup;

	lua_pushstring(L, name);

	return 1;
notsup:
	return unixL_pusherror(L, ENOTSUP, "getprogname", "~$#");
} /* unix_getprogname() */


static int unix_getpwnam(lua_State *L) {
	struct passwd *ent;
	int error;

	if (lua_isnumber(L, 1)) {
		error = unixL_getpwuid(L, luaL_checkint(L, 1), &ent);
	} else {
		error = unixL_getpwnam(L, luaL_checkstring(L, 1), &ent);
	}

	if (error) {
		return unixL_pusherror(L, error, "getpwnam", "~$#");
	} else if (!ent) {
		lua_pushnil(L);
		lua_pushstring(L, "no such user");

		return 2;
	}

	if (lua_isnoneornil(L, 2)) {
		lua_createtable(L, 0, 7);

		if (ent->pw_name) {
			lua_pushstring(L, ent->pw_name);
			lua_setfield(L, -2, "name");
		}

		if (ent->pw_passwd) {
			lua_pushstring(L, ent->pw_passwd);
			lua_setfield(L, -2, "passwd");
		}

		lua_pushinteger(L, ent->pw_uid);
		lua_setfield(L, -2, "uid");

		lua_pushinteger(L, ent->pw_gid);
		lua_setfield(L, -2, "gid");

		if (ent->pw_dir) {
			lua_pushstring(L, ent->pw_dir);
			lua_setfield(L, -2, "dir");
		}

		if (ent->pw_shell) {
			lua_pushstring(L, ent->pw_shell);
			lua_setfield(L, -2, "shell");
		}

		if (ent->pw_gecos) {
			lua_pushstring(L, ent->pw_gecos);
			lua_setfield(L, -2, "gecos");
		}

		return 1;
	} else {
		static const char *opts[] = {
			"name", "passwd", "uid", "gid", "dir", "shell", "gecos", NULL,
		};
		int i, n = 0, top = lua_gettop(L);

		for (i = 2; i <= top; i++) {
			switch (luaL_checkoption(L, i, NULL, opts)) {
			case 0:
				if (ent->pw_name)
					lua_pushstring(L, ent->pw_name);
				else
					lua_pushnil(L);
				++n;

				break;
			case 1:
				if (ent->pw_passwd)
					lua_pushstring(L, ent->pw_passwd);
				else
					lua_pushnil(L);
				++n;

				break;
			case 2:
				lua_pushinteger(L, ent->pw_uid);
				++n;

				break;
			case 3:
				lua_pushinteger(L, ent->pw_gid);
				++n;

				break;
			case 4:
				if (ent->pw_dir)
					lua_pushstring(L, ent->pw_dir);
				else
					lua_pushnil(L);
				++n;

				break;
			case 5:
				if (ent->pw_shell)
					lua_pushstring(L, ent->pw_shell);
				else
					lua_pushnil(L);
				++n;

				break;
			case 6:
				if (ent->pw_gecos)
					lua_pushstring(L, ent->pw_gecos);
				else
					lua_pushnil(L);
				++n;

				break;
			}
		}

		return n;
	}
} /* unix_getpwnam() */


static int rl_checkrlimit(lua_State *L, int index) {
	static const char *const what_s[] = {
		"core", "cpu", "data", "fsize", "nofile", "stack",
#if HAVE_DECL_RLIMIT_AS
		"as",
#endif
		NULL
	};
	static const int what_i[countof(what_s) - 1] = {
		RLIMIT_CORE, RLIMIT_CPU, RLIMIT_DATA, RLIMIT_FSIZE,
		RLIMIT_NOFILE, RLIMIT_STACK,
#if HAVE_DECL_RLIMIT_AS
		RLIMIT_AS,
#endif
	};
	int i;

	if (lua_isnumber(L, index))
		return unixL_checkint(L, index);

	i = luaL_checkoption(L, index, NULL, what_s);
	luaL_argcheck(L, i >= 0 && i < (int)countof(what_i), index, lua_pushfstring(L, "unexpected rlimit (%s)", lua_tostring(L, index)));

	return what_i[i];
} /* rl_checkrlimit() */

#define RL_RLIM_INFINITY INFINITY
#define RL_RLIM_SAVED_CUR -1.0
#define RL_RLIM_SAVED_MAX -2.0

#define U_RLIM_INFINITY RLIM_INFINITY

#if HAVE_DECL_RLIM_SAVED_CUR
#define U_RLIM_SAVED_CUR RLIM_SAVED_CUR
#else
#define U_RLIM_SAVED_CUR U_RLIM_INFINITY
#endif

#if HAVE_DECL_RLIM_SAVED_MAX
#define U_RLIM_SAVED_MAX RLIM_SAVED_MAX
#else
#define U_RLIM_SAVED_MAX U_RLIM_INFINITY
#endif

static _Bool rl_isequal(lua_State *L, int index, lua_Number n) {
	_Bool eq;

	index = lua_absindex(L, index);
	lua_pushnumber(L, n);
#if LUA_VERSION_NUM == 501
	eq = lua_equal(L, index, -1);
#else
	eq = lua_compare(L, index, -1, LUA_OPEQ);
#endif
	lua_pop(L, 1);

	return eq;
} /* rl_isequal() */

static rlim_t rl_checkrlim(lua_State *L, int index) {
	luaL_checktype(L, index, LUA_TNUMBER);

	if (!lua_isinteger(L, index)) {
		/*
		 * NB: On some systems RLIM_INFINITY, RLIM_SAVED_CUR, and
		 * RLIM_SAVED_MAX are equal. The semantics work because
		 * applications are expected to only echo the RLIM_SAVED_CUR
		 * and RLIM_SAVED_MAX values; not specify them de novo.
		 * However, we could call getrlimit() for
		 * RL_RLIM_SAVED_{CUR,MAX} and use that value.
		 */
		if (rl_isequal(L, index, RL_RLIM_INFINITY))
			return U_RLIM_INFINITY;
		if (rl_isequal(L, index, RL_RLIM_SAVED_CUR))
			return U_RLIM_SAVED_CUR;
		if (rl_isequal(L, index, RL_RLIM_SAVED_MAX))
			return U_RLIM_SAVED_MAX;
	}

	return unixL_checkunsigned(L, index, 0, (rlim_t)-1);
} /* rl_checkrlim() */

static rlim_t rl_optrlim(lua_State *L, int index, rlim_t def) {
	if (lua_isnoneornil(L, index))
		return def;

	return rl_checkrlim(L, index);
} /* rl_optrlim() */

static void rl_pushrlim(lua_State *L, rlim_t rlim) {
	if (rlim == U_RLIM_SAVED_MAX) {
		lua_pushnumber(L, RL_RLIM_SAVED_MAX);
	} else if (rlim == U_RLIM_SAVED_CUR) {
		lua_pushnumber(L, RL_RLIM_SAVED_CUR);
	} else {
		unixL_pushunsigned(L, rlim);
	}
} /* rl_pushrlim() */

static int unix_getrlimit(lua_State *L) {
	struct rlimit rl;

	if (0 != getrlimit(rl_checkrlimit(L, 1), &rl))
		return unixL_pusherror(L, errno, "getrlimit", "~$#");

	rl_pushrlim(L, rl.rlim_cur);
	rl_pushrlim(L, rl.rlim_max);

	return 2;
} /* unix_getrlimit() */


static int ru_checkrusage(lua_State *L, int index) {
	static const char *const what_s[] = { "children", "self", NULL };
	static const int what_i[countof(what_s) - 1] = {
		RUSAGE_CHILDREN, RUSAGE_SELF,
	};
	int i;

	if (lua_isnumber(L, index))
		return unixL_checkint(L, index);

	i = luaL_checkoption(L, index, NULL, what_s);
	luaL_argcheck(L, i >= 0 && i < (int)countof(what_i), index, lua_pushfstring(L, "unexpected resource (%s)", lua_tostring(L, index)));

	return what_i[i];
} /* ru_checkrusage() */

static int unix_getrusage(lua_State *L) {
	struct rusage ru;

	if (0 != getrusage(ru_checkrusage(L, 1), &ru))
		return unixL_pusherror(L, errno, "getrusage", "~$#");

	lua_newtable(L);
	lua_pushnumber(L, u_tv2f(&ru.ru_utime));
	lua_setfield(L, -2, "utime");
	lua_pushnumber(L, u_tv2f(&ru.ru_stime));
	lua_setfield(L, -2, "stime");

	return 1;
} /* unix_getrusage() */


static int unix_gettimeofday(lua_State *L) {
	struct timeval tv;

	if (0 != gettimeofday(&tv, NULL))
		return unixL_pusherror(L, errno, "gettimeofday", "~$#");

	if (lua_isnoneornil(L, 1) || !lua_toboolean(L, 1)) {
		lua_pushnumber(L, u_tv2f(&tv));

		return 1;
	} else {
		lua_pushinteger(L, tv.tv_sec);
		lua_pushinteger(L, tv.tv_usec);

		return 2;
	}
} /* unix_gettimeofday() */


static int unix_getsockname(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int error;

	if ((error = unixL_getsockname(L, fd, &getsockname)))
		return unixL_pusherror(L, error, "getsockname", "~$#");

	return 1;
} /* unix_getsockname() */


static int unsafe_getsockopt(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkfileno(L, 1);
	int level = unixL_checkint(L, 2);
	int type = unixL_checkint(L, 3);
	const struct iovec iov = unixL_checkstring(L, 4, 0, INT_MAX); /* length must fit socklen_t */
	socklen_t bufsiz;
	int n, error;

	n = lua_gettop(L);
	luaL_argcheck(L, n <= 4, 5, lua_pushfstring(L, "expected 4 arguments, got %d", n));

	if (U->bufsiz < iov.iov_len && (error = u_realloc(&U->buf, &U->bufsiz, iov.iov_len)))
		goto error;
	memcpy(U->buf, iov.iov_base, iov.iov_len);
	bufsiz = iov.iov_len;

	if (0 != getsockopt(fd, level, type, U->buf, &bufsiz))
		goto syerr;

	lua_pushlstring(L, U->buf, bufsiz);
	return 1;
syerr:
	error = errno;
error:
	return unixL_pusherror(L, error, "getsockopt", "~$#");
} /* unsafe_getsockopt() */


static int unix_getuid(lua_State *L) {
	lua_pushinteger(L, getuid());

	return 1;
} /* unix_getuid() */


static int unix_grantpt(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);

	if (0 != grantpt(fd))
		return unixL_pusherror(L, errno, "grantpt", "~$#");

	lua_pushvalue(L, 1);

	return 1;
} /* unix_grantpt() */


static int unix_ioctl(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int cmd = luaL_checkint(L, 2);
	int val, error;

	switch (cmd) {
#if defined SIOCATMARK
	case SIOCATMARK:
		if (-1 == ioctl(fd, cmd, &val))
			goto syerr;

		lua_pushboolean(L, val != 0);

		return 1;
#endif
#if defined TIOCNOTTY
	case TIOCNOTTY:
		if (-1 == ioctl(fd, cmd, (char *)NULL))
			goto syerr;

		lua_pushvalue(L, 1);

		return 1;
#endif
#if defined TIOCSCTTY
	case TIOCSCTTY:
		if (-1 == ioctl(fd, cmd, (char *)NULL))
			goto syerr;

		lua_pushvalue(L, 1);

		return 1;
#endif
	default:
		/*
		 * NOTE: We don't allow unsupported operations because we
		 * cannot know the argument type that ioctl expects. If it's
		 * a pointer then this interface becomes a vector for
		 * reading or writing random process memory.
		 *
		 * But see unsafe_ioctl, below.
		 */
		return luaL_error(L, "%d: unsupported ioctl operation", cmd);
	} /* switch () */
syerr:
	error = errno;
	return unixL_pusherror(L, error, "ioctl", "~$#");
} /* unix_ioctl() */


static int unsafe_ioctl(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int cmd = luaL_checkint(L, 2);
	int n, r, error;

	n = lua_gettop(L);
	luaL_argcheck(L, n <= 3, 4, lua_pushfstring(L, "expected 3 arguments, got %d", n));

	switch (lua_type(L, 3)) {
	case LUA_TNONE: {
		if (-1 == (r = ioctl(fd, cmd, (intptr_t)0)))
			goto syerr;

		lua_pushinteger(L, r);
		return 1;
	}
	case LUA_TNUMBER: {
		intptr_t arg = unixL_checkinteger(L, 3, INTPTR_MIN, INTPTR_MAX);

		if (-1 == (r = ioctl(fd, cmd, arg)))
			goto syerr;

		lua_pushinteger(L, r);
		return 1;
	}
	case LUA_TSTRING: {
		const struct iovec iov = unixL_checkstring(L, 3, 0, SIZE_MAX);
		unixL_State *U = unixL_getstate(L);

		if (U->bufsiz < iov.iov_len && (error = u_realloc(&U->buf, &U->bufsiz, iov.iov_len)))
			goto error;
		memcpy(U->buf, iov.iov_base, iov.iov_len);

		if (-1 == (r = ioctl(fd, cmd, U->buf)))
			goto syerr;

		lua_pushinteger(L, r);
		lua_pushlstring(L, U->buf, iov.iov_len);
		return 2;
	}
	}

	return luaL_argerror(L, 3, lua_pushfstring(L, "expected integer or string, got %s", luaL_typename(L, 3)));
syerr:
	error = errno;
error:
	return unixL_pusherror(L, error, "ioctl", "~$#");
} /* unsafe_ioctl() */


static int unix_isatty(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);

	/* NB: POSIX doesn't require implementations to set errno */
	errno = 0;
	if (isatty(fd)) {
		return lua_pushboolean(L, 1), 1;
	} else if (errno == EBADF) {
		return unixL_pusherror(L, errno, "isatty", "0$#");
	} else {
		return lua_pushboolean(L, 0), 1;
	}
} /* unix_isatty() */


#if HAVE_GETAUXVAL
#include <sys/auxv.h>
#endif

MAYBEUSED static int unix_issetugid_other(lua_State *L) {
	lua_pushboolean(L, (geteuid() != getuid()) || (getegid() != getgid()));

	return 0;
} /* unix_issetugid_other() */

MAYBEUSED static int unix_issetugid_linux(lua_State *L) {
#if HAVE_GETAUXVAL && defined AT_SECURE
	unsigned long auxval;

	errno = 0;
	auxval = getauxval(AT_SECURE);

	if (auxval != 0 || errno != ENOENT) {
		lua_pushboolean(L, !auxval);

		return 1;
	}
#endif

#if HAVE__LIBC_ENABLE_SECURE
	extern int __libc_enable_secure;

	lua_pushboolean(L, __libc_enable_secure);

	return 1;
#else
	return unix_issetugid_other(L);
#endif
} /* unix_issetugid_linux() */

MAYBEUSED static int unix_issetugid(lua_State *L) {
#if HAVE_ISSETUGID
	lua_pushboolean(L, issetugid());

	return 1;
#elif __linux
	return unix_issetugid_linux(L);
#else
	return unix_issetugid_other(L);
#endif
} /* unix_issetugid() */


static int unix_kill(lua_State *L) {
	if (0 != kill(luaL_checkint(L, 1), luaL_checkint(L, 2)))
		return unixL_pusherror(L, errno, "kill", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_kill() */


static int unix_lchown(lua_State *L) {
	uid_t uid = unixL_optuid(L, 2, -1);
	gid_t gid = unixL_optgid(L, 3, -1);

	if (0 != lchown(luaL_checkstring(L, 1), uid, gid))
		return unixL_pusherror(L, errno, "lchown", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_lchown() */


static int unix_link(lua_State *L) {
	const char *src = luaL_checkstring(L, 1);
	const char *dst = luaL_checkstring(L, 2);

	if (0 != link(src, dst))
		return unixL_pusherror(L, errno, "link", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_link() */


#if defined SOMAXCONN
#define U_SOMAXCONN SOMAXCONN
#else
#define U_SOMAXCONN 128
#endif

static int unix_listen(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int backlog = unixL_optint(L, 2, U_SOMAXCONN);

	if (0 != listen(fd, backlog))
		return unixL_pusherror(L, errno, "listen", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_listen() */


static int unix_lockf(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int cmd = unixL_checkint(L, 2);
	off_t size = unixL_optoff(L, 3, 0);

	if (0 != lockf(fd, cmd, size))
		return unixL_pusherror(L, errno, "lockf", "~$#");

	lua_pushvalue(L, 1);

	return 1;
} /* unix_lockf() */


static int unix_LOG_MASK(lua_State *L) {
	int priority = unixL_checkint(L, 1);
	lua_pushinteger(L, LOG_MASK(priority));
	return 1;
} /* unix_LOG_MASK() */


static int unix_LOG_UPTO(lua_State *L) {
	int priority = unixL_checkint(L, 1);
	lua_pushinteger(L, LOG_UPTO(priority));
	return 1;
} /* unix_LOG_UPTO() */


static int unix_lseek(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	off_t offset = unixL_checkoff(L, 2);
	int whence = unixL_checkint(L, 3);
	off_t pos;

	if (-1 == (pos = lseek(fd, offset, whence)))
		return unixL_pusherror(L, errno, "lseek", "0$#");

	unixL_pushoff(L, pos);

	return 1;
} /* unix_lseek() */


static int st_pushstat(lua_State *, const struct stat *, int);

static int unix_lstat(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);
	struct stat st;

	if (0 != lstat(path, &st))
		return unixL_pusherror(L, errno, "lstat", "0$#");

	return st_pushstat(L, &st, 2);
} /* unix_lstat() */


static int unsafe_malloc(lua_State *L) {
	size_t size = unixL_checksize(L, 1);
	void *addr;

	if (!(addr = malloc(size)) && size > 0)
		return unixL_pusherror(L, errno, "malloc", "~$#");

	lua_pushlightuserdata(L, addr);
	return 1;
} /* unsafe_malloc() */


static int unsafe_memcpy(lua_State *L) {
	void *dst = unixL_checklightuserdata(L, 1);

	if (lua_type(L, 2) == LUA_TSTRING) {
		struct iovec src = unixL_checkstring(L, 2, 0, SIZE_MAX);
		size_t len = (lua_isnoneornil(L, 3))? src.iov_len : unixL_checksize(L, 3);

		luaL_argcheck(L, len <= src.iov_len, 3, "string too short");

		memcpy(dst, src.iov_base, len);
	} else {
		void *src = unixL_checklightuserdata(L, 2);
		size_t len = unixL_checksize(L, 3);

		memcpy(dst, src, len);
	}

	lua_pushlightuserdata(L, dst);
	return 1;
} /* unsafe_memcpy() */


static int unsafe_memset(lua_State *L) {
	void *addr = (luaL_checktype(L, 1, LUA_TLIGHTUSERDATA), lua_touserdata(L, 1));
	int c = unixL_checkint(L, 2);
	size_t len = unixL_checksize(L, 3);

	lua_pushlightuserdata(L, memset(addr, c, len));
	return 1;
} /* unsafe_memset() */


/*
 * Emulate mkdir except with well-defined SUID, SGID, SVTIX behavior. If you
 * want to set bits restricted by the umask you must manually use chmod.
 *
 * FIXME: Remove mode magic. See unix_mkdirat(), below.
 */
static int unix_mkdir(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);
	mode_t cmask, mode;

	cmask = unixL_getumask(L);
	mode = 0777 & ~cmask;
	mode = unixL_optmode(L, 2, mode, mode) & ~cmask;

	if (0 != mkdir(path, 0700 & mode) || 0 != chmod(path, mode))
		return unixL_pusherror(L, errno, "mkdir", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_mkdir() */


#if HAVE_MKDIRAT
/*
 * XXX: Intentionally excluding the supression of SUID, SGID, and SVTIX bits
 * as done by unix_mkdir() above. Forking might fail in sandboxed processes
 * (seccomp, pledge) and the mkdir() + chmod() sequence is not atomic.
 */
static int unix_mkdirat(lua_State *L) {
	int at = unixL_checkatfileno(L, 1);
	const char *path = luaL_checkstring(L, 2);
	mode_t mode = unixL_optmode(L, 3, 0777, 0777);

	if (0 != mkdirat(at, path, mode))
		return unixL_pusherror(L, errno, "mkdirat", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_mkdirat() */
#endif


static int unix_mkfifo(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);
	mode_t mode = unixL_optmode(L, 2, 0666, 0666);

	if (0 != mkfifo(path, mode))
		return unixL_pusherror(L, errno, "mkfifo", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_mkfifo() */


#if HAVE_MKFIFOAT
static int unix_mkfifoat(lua_State *L) {
	int at = unixL_checkatfileno(L, 1);
	const char *path = luaL_checkstring(L, 2);
	mode_t mode = unixL_optmode(L, 3, 0666, 0666);

	if (0 != mkfifoat(at, path, mode))
		return unixL_pusherror(L, errno, "mkfifoat", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_mkfifoat() */
#endif


/*
 * Patterned after the mkpath routine from BSD mkdir implementations for
 * POSIX mkdir(1). The basic idea is to mimic a recursive mkdir(2) call.
 *
 * Differences from BSD mkpath:
 *
 * 1) On BSD intermediate permissions are always (0300 | (0777 & ~umask())).
 *    But see #2. Whereas here we obey any specified intermediate mode
 *    value.
 *
 * 2) On BSD if the SUID, SGID, or SVTIX bit is set in the target mode
 *    value, the target directory is chmod'd using that mode value,
 *    unaltered by the umask. On OpenBSD intermediate directories are also
 *    chmod'd with that mode value.
 */
static int unix_mkpath(lua_State *L) {
	size_t len;
	const char *path = luaL_checklstring(L, 1, &len);
	mode_t cmask, mode, imode, _mode;
	char *dir, *slash;
	int lc;

	cmask = unixL_getumask(L);
	mode = 0777 & ~cmask;
	imode = 0300 | mode;

	mode = unixL_optmode(L, 2, mode, mode) & ~cmask;
	imode = unixL_optmode(L, 3, imode, imode) & ~cmask;

	dir = lua_newuserdata(L, len + 1);
	memcpy(dir, path, len + 1);

	slash = dir + len;
	while (--slash > dir && *slash == '/')
		*slash = '\0';

	slash = dir;

	while (*slash) {
		slash += strspn(slash, "/");
		slash += strcspn(slash, "/");

		lc = *slash;
		*slash = '\0';

		_mode = (lc == '\0')? mode : imode;

		if (0 == mkdir(dir, 0700 & _mode)) {
			if (0 != chmod(dir, _mode))
				return unixL_pusherror(L, errno, "mkpath", "0$#");
		} else {
			int error = errno;
			struct stat st;

			if (0 != stat(dir, &st))
				return unixL_pusherror(L, error, "mkpath", "0$#");

			if (!S_ISDIR(st.st_mode))
				return unixL_pusherror(L, ENOTDIR, "mkpath", "0$#");
		}

		*slash = lc;
	}

	lua_pushboolean(L, 1);

	return 1;
} /* unix_mkpath() */


static int unsafe_mlock(lua_State *L) {
	void *addr = unixL_optlightuserdata(L, 1);
	size_t len = unixL_checksize(L, 2);

	if (0 != mlock(addr, len))
		return unixL_pusherror(L, errno, "mlock", "0$#");

	lua_pushboolean(L, 1);
	return 1;
} /* unsafe_mlock() */


static int unsafe_mlockall(lua_State *L) {
	int flags = unixL_checkint(L, 1);

	if (0 != mlockall(flags))
		return unixL_pusherror(L, errno, "mlockall", "0$#");

	lua_pushboolean(L, 1);
	return 1;
} /* unsafe_mlockall() */


static int mman_optfileno(lua_State *L, int index, int def) {
	if (lua_type(L, index) == LUA_TNUMBER)
		return unixL_checkint(L, index);
	return unixL_optfileno(L, index, def);
}

static int unsafe_mmap(lua_State *L) {
	void *addr0 = unixL_optlightuserdata(L, 1);
	size_t len = unixL_checksize(L, 2);
	int prot = unixL_checkint(L, 3);
	int flags = unixL_checkint(L, 4);
	int fd = mman_optfileno(L, 5, -1);
	off_t off = unixL_optoff(L, 6, 0);
	void *addr;

	if (MAP_FAILED == (addr = mmap(addr0, len, prot, flags, fd, off)))
		return unixL_pusherror(L, errno, "mmap", "~$#");

	lua_pushlightuserdata(L, addr);
	return 1;
} /* unsafe_mmap() */


static int unsafe_munlock(lua_State *L) {
	void *addr = unixL_optlightuserdata(L, 1);
	size_t len = unixL_checksize(L, 2);

	if (0 != munlock(addr, len))
		return unixL_pusherror(L, errno, "munlock", "0$#");

	lua_pushboolean(L, 1);
	return 1;
} /* unsafe_munlock() */


static int unsafe_munlockall(lua_State *L) {
	if (0 == munlockall())
		return unixL_pusherror(L, errno, "munlockall", "0$#");

	lua_pushboolean(L, 1);
	return 1;
} /* unsafe_munlockall() */


static int unsafe_munmap(lua_State *L) {
	void *addr = unixL_checklightuserdata(L, 1);
	size_t len = unixL_checksize(L, 2);

	if (0 != munmap(addr, len))
		return unixL_pusherror(L, errno, "munmap", "~$#");

	lua_pushboolean(L, 1);
	return 1;
} /* unsafe_munmap() */


static int unix_open(lua_State *L) {
	int fd = -1, ofd, error;
	u_flags_t flags;
	const char *mode;
	mode_t perm;

	lua_settop(L, 3);
	unixL_checkflags(L, 2, &mode, &flags, &perm);

	if (-1 != (ofd = unixL_optfileno(L, 1, -1))) {
		if ((error = unixL_reopen(L, &fd, ofd, flags)))
			goto error;
	} else {
		const char *path = luaL_checkstring(L, 1);

		if ((error = u_open(&fd, path, flags, perm)))
			goto error;
	}

	lua_pushinteger(L, fd);

	return 1;
error:
	u_close(&fd);

	return unixL_pusherror(L, error, "open", "~$#");
} /* unix_open() */


/*
 * TODO: Emulate openat() with fork+chdir+open+sendmsg.
 */
#if HAVE_OPENAT
static int unix_openat(lua_State *L) {
	int fd = -1, at, error;
	const char *path, *mode;
	u_flags_t flags;
	mode_t perm;

	lua_settop(L, 4);
	at = unixL_checkatfileno(L, 1);
	path = luaL_checkstring(L, 2);
	unixL_checkflags(L, 3, &mode, &flags, &perm);

	if (-1 == (fd = openat(at, path, flags, perm)))
		goto syerr;

	lua_pushinteger(L, fd);

	return 1;
syerr:
	error = errno;
	u_close(&fd);

	return unixL_pusherror(L, error, "openat", "~$#");
} /* unix_openat() */
#endif


static DIR *dir_checkself(lua_State *L, int index) {
	DIR **dp = luaL_checkudata(L, index, "DIR*");

	luaL_argcheck(L, *dp != NULL, index, "attempt to use a closed directory");

	return *dp;
} /* dir_checkself() */

enum dir_field {
	DF_NAME,
	DF_INO,
	DF_TYPE
}; /* enum dir_field */

static const char *dir_field[] = { "name", "ino", "type", NULL };

static void dir_pushfield(lua_State *L, struct dirent *ent, enum dir_field type) {
	switch (type) {
	case DF_NAME:
		lua_pushstring(L, ent->d_name);
		break;
	case DF_INO:
		lua_pushinteger(L, ent->d_ino);
		break;
	case DF_TYPE:
#if defined DTTOIF
		lua_pushinteger(L, DTTOIF(ent->d_type));
#else
		lua_pushnil(L);
#endif
		break;
	default:
		lua_pushnil(L);
		break;
	} /* switch() */
} /* dir_pushfield() */

static void dir_pushtable(lua_State *L, struct dirent *ent) {
	lua_createtable(L, 0, 3);

	dir_pushfield(L, ent, DF_NAME);
	lua_setfield(L, -2, "name");

	dir_pushfield(L, ent, DF_INO);
	lua_setfield(L, -2, "ino");

	dir_pushfield(L, ent, DF_TYPE);
	lua_setfield(L, -2, "type");
} /* dir_pushtable() */

static int dir_read(lua_State *L) {
	DIR *dp = dir_checkself(L, 1);
	struct dirent *ent = NULL;
	int error;

	if ((error = unixL_readdir(L, dp, &ent)))
		return unixL_pusherror(L, error, "readdir", "~$#");

	if (!ent)
		return 0;

	if (lua_isnoneornil(L, 2)) {
		dir_pushtable(L, ent);

		return 1;
	} else {
		int i, n = 0, top = lua_gettop(L);

		for (i = 2; i <= top; i++, n++) {
			dir_pushfield(L, ent, luaL_checkoption(L, i, NULL, dir_field));
		}

		return n;
	}
} /* dir_read() */

static int dir_nextent(lua_State *L) {
	DIR *dp = dir_checkself(L, lua_upvalueindex(2));
	int nup = lua_tointeger(L, lua_upvalueindex(3));
	struct dirent *ent = NULL;
	int error;

	if ((error = unixL_readdir(L, dp, &ent)))
		return luaL_error(L, "readdir: %s", unixL_strerror(L, error));

	if (!ent)
		return 0;

	if (nup < 4) {
		dir_pushtable(L, ent);

		return 1;
	} else {
		int i, n = 0;

		for (i = 4; i <= nup; i++, n++) {
			dir_pushfield(L, ent, luaL_checkoption(L, lua_upvalueindex(i), NULL, dir_field));
		}

		return n;
	}
} /* dir_nextent() */

static int dir_files(lua_State *L) {
	int i, top = lua_gettop(L), nup = top + 2;

	dir_checkself(L, 1);

	lua_pushvalue(L, lua_upvalueindex(1)); /* unixL_State */
	lua_pushvalue(L, 1);
	lua_pushinteger(L, nup);

	for (i = 2; i <= top; i++) {
		lua_pushvalue(L, i);
	}

	lua_pushcclosure(L, &dir_nextent, nup);

	return 1;
} /* dir_files() */

static int dir_rewind(lua_State *L) {
	DIR *dp = dir_checkself(L, 1);

	rewinddir(dp);

	lua_pushboolean(L, 1);

	return 1;
} /* dir_rewind() */

static int dir_close(lua_State *L) {
	DIR **dp = luaL_checkudata(L, 1, "DIR*");
	int error;

	if ((error = unixL_closedir(L, dp)))
		return luaL_error(L, "closedir: %s", unixL_strerror(L, error));

	lua_pushboolean(L, 1);

	return 1;
} /* dir_close() */

static const luaL_Reg dir_methods[] = {
	{ "read",   &dir_read },
	{ "files",  &dir_files },
	{ "rewind", &dir_rewind },
	{ "close",  &dir_close },
	{ NULL,     NULL }
}; /* dir_methods[] */

static const luaL_Reg dir_metamethods[] = {
	{ "__gc", &dir_close },
	{ NULL,   NULL }
}; /* dir_metamethods[] */

static int unix_opendir(lua_State *L) {
	DIR **dp;
	int fd, fd2 = -1, error;

	lua_settop(L, 1);

	dp = lua_newuserdata(L, sizeof *dp);
	*dp = NULL;
	luaL_setmetatable(L, "DIR*");

	if (-1 != (fd = unixL_optfileno(L, 1, -1))) {
		if ((error = unixL_reopen(L, &fd2, fd, U_CLOEXEC)))
			goto error;

		if (-1 == lseek(fd2, 0, SEEK_SET))
			goto syerr;

		if ((error = u_fdopendir(dp, &fd2, 0)))
			goto error;
	} else {
		const char *path = luaL_checkstring(L, 1);

		if (!(*dp = opendir(path)))
			goto syerr;
	}

	return 1;
syerr:
	error = errno;
error:
	u_close(&fd2);

	return unixL_pusherror(L, error, "opendir", "~$#");
} /* unix_opendir() */


/*
 * same defaults as luaposix and as POSIX specifies for syslog in the
 * absence of an explicit openlog
 */
static int unix_openlog(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	const char *ident = luaL_checkstring(L, 1);
	int logopt = unixL_optint(L, 2, 0);
	int facility = unixL_optint(L, 3, LOG_USER);
	int ref;

	/*
	 * FIXME: What if the Lua state is destroyed? Should we use strdup
	 * instead, only free the old reference if openlog is called again
	 * and permit a possible memory leak?
	 *
	 * Note that POSIX (2018) doesn't say anything about the lifetime of
	 * the ident string. Some implementations use the string directly
	 * (e.g. glibc 2.29, OpenBSD 6.4, Solaris 11.4 per syslog(3C)),
	 * while some make a copy (e.g. musl libc 1.1.21).
	 *
	 */
	lua_pushvalue(L, 1);
	ref = luaL_ref(L, LUA_REGISTRYINDEX);

	openlog(ident, logopt, facility);

	luaL_unref(L, LUA_REGISTRYINDEX, U->log.ident);
	U->log.ident = ref;

	return 0;
} /* unix_openlog() */


static int unix_pathconf(lua_State *L) {
	int name = unixL_checkint(L, 2);
	int fd;
	long v;

	if (-1 != (fd = unixL_optfileno(L, 1, -1))) {
		errno = 0;
		v = fpathconf(fd, name);
	} else {
		const char *path = luaL_checkstring(L, 1);

		errno = 0;
		v = pathconf(path, name);
	}

	if (v == -1 && errno)
		return unixL_pusherror(L, errno, "pathconf", "~$#");

	lua_pushinteger(L, v);

	return 1;
} /* unix_pathconf() */


static int unix_pipe(lua_State *L) {
	int fd[2] = { -1, -1 }, error;
	u_flags_t flags;
	const char *mode;

	lua_settop(L, 1);
	unixL_checkflags(L, 1, &mode, &flags, NULL);

	if ((error = u_pipe(fd, flags)))
		goto error;

	lua_pushinteger(L, fd[0]);
	lua_pushinteger(L, fd[1]);

	return 2;
error:
	u_close(&fd[0]);
	u_close(&fd[1]);

	return unixL_pusherror(L, error, "pipe", "~$#");
} /* unix_pipe() */


static u_error_t poll_add(unixL_State *U, int fd, short events, size_t *nfds, size_t *mfds) {
	int error;

	if (*nfds >= INT_MAX)
		return ERANGE;

	if (*mfds <= *nfds) {
		if ((error = u_reallocarray_pollfd(&U->net.fds.buf, &U->net.fds.bufsiz, *nfds + 1)))
			return error;
		*mfds = U->net.fds.bufsiz / sizeof *U->net.fds.buf;
	}

	assert(*mfds > *nfds);
	U->net.fds.buf[*nfds].fd = fd;
	U->net.fds.buf[*nfds].events = events;
	U->net.fds.buf[*nfds].revents = 0;
	++*nfds;

	return 0;
}

static int unix_poll(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int timeout = u_f2ms(luaL_optnumber(L, 2, U_NAN));
	size_t mfds = 0, nfds = 0, i;
	int error, nr;

	luaL_checktype(L, 1, LUA_TTABLE);
	lua_pushnil(L);
	while (lua_next(L, 1) != 0) {
		int fd;
		short events;

		fd = unixL_checkint(L, -2);
		lua_getfield(L, -1, "events");
		events = unixL_checkinteger(L, -1, 0, SHRT_MAX);
		lua_pop(L, 1);

		if ((error = poll_add(U, fd, events, &nfds, &mfds)))
			return unixL_pusherror(L, error, "poll", "~$#");

		lua_pop(L, 1);
	}

	if (-1 == (nr = poll(U->net.fds.buf, nfds, timeout)))
		return unixL_pusherror(L, errno, "poll", "~$#");

	for (i = 0; i < nfds; i++) {
		struct pollfd *pfd = &U->net.fds.buf[i];

		lua_rawgeti(L, 1, pfd->fd);
		lua_pushinteger(L, pfd->revents);
		lua_setfield(L, -2, "revents");
		lua_pop(L, 1);
	}

	lua_pushinteger(L, nr);

	return 1;
} /* unix_poll() */


#if HAVE_POSIX_FADVISE
static int unix_posix_fadvise(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	off_t offset = unixL_checkoff(L, 2);
	off_t len = unixL_checkoff(L, 3);
	int advice = unixL_checkint(L, 4);
	int error;

	if ((error = posix_fadvise(fd, offset, len, advice)))
		return unixL_pusherror(L, error, "posix_fadvise", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_posix_fadvise() */
#endif


#if HAVE_POSIX_FALLOCATE
static int unix_posix_fallocate(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	off_t offset = unixL_checkoff(L, 2);
	off_t len = unixL_checkoff(L, 3);
	int error;

	if ((error = posix_fallocate(fd, offset, len)))
		return unixL_pusherror(L, error, "posix_fallocate", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_posix_fallocate() */
#endif


static int unix_posix_openpt(lua_State *L) {
	u_flags_t flags = unixL_optinteger(L, 1, O_RDWR, 0, U_TMAX(u_flags_t));
	int fd;

	if (-1 == (fd = posix_openpt(flags)))
		return unixL_pusherror(L, errno, "posix_openpt", "~$#");

	lua_pushinteger(L, fd);

	return 1;
} /* unix_posix_openpt() */

static int unix_posix_fopenpt(lua_State *L) {
	u_flags_t flags = unixL_optinteger(L, 1, O_RDWR, 0, U_TMAX(u_flags_t));
	luaL_Stream *fh;
	int fd, error;

	fh = unixL_prepfile(L);

	if (-1 == (fd = posix_openpt(flags)))
		goto syerr;

	if ((error = u_fdopen(&fh->f, &fd, NULL, flags)))
		goto error;

	return 1;
syerr:
	error = errno;
error:
	u_close(&fd);

	return unixL_pusherror(L, error, "posix_openpt", "~$#");
} /* unix_posix_fopenpt() */


static int unix_pread(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkfileno(L, 1);
	size_t size = unixL_checksize(L, 2);
	size_t offset = unixL_checksize(L, 3);
	ssize_t n;
	int error;

	if (U->bufsiz < size && (error = u_realloc(&U->buf, &U->bufsiz, size)))
		return unixL_pusherror(L, error, "pread", "~$#");

	if (-1 == (n = pread(fd, U->buf, size, offset)))
		return unixL_pusherror(L, errno, "pread", "~$#");

	lua_pushlstring(L, U->buf, n);

	return 1;
} /* unix_pread() */


static int unix_ptsname(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkfileno(L, 1);
	int error;

	while ((error = u_ptsname_r(fd, U->buf, U->bufsiz))) {
		if (error != ERANGE || (error = u_growby(&U->buf, &U->bufsiz, 64)))
			return unixL_pusherror(L, error, "ptsname", "~$#");
	}

	lua_pushstring(L, U->buf);

	return 1;
} /* unix_ptsname() */


static int unix_pwrite(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	size_t size;
	const char *src = luaL_checklstring(L, 2, &size);
	size_t offset = unixL_checksize(L, 3);
	ssize_t n;

	if (-1 == (n = pwrite(fd, src, size, offset)))
		return unixL_pusherror(L, errno, "pwrite", "~$#");

	unixL_pushsize(L, n);

	return 1;
} /* unix_pwrite() */


static int unix_raise(lua_State *L) {
	if (0 != raise(luaL_checkint(L, 1)))
		return unixL_pusherror(L, errno, "raise", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_raise() */


static int unix_read(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkfileno(L, 1);
	size_t size = unixL_checksize(L, 2);
	ssize_t n;
	int error;

	if (U->bufsiz < size && (error = u_realloc(&U->buf, &U->bufsiz, size)))
		return unixL_pusherror(L, error, "read", "~$#");

	if (-1 == (n = read(fd, U->buf, size)))
		return unixL_pusherror(L, errno, "read", "~$#");

	lua_pushlstring(L, U->buf, n);

	return 1;
} /* unix_read() */


static int unix_readdir(lua_State *L) {
	return dir_read(L);
} /* unix_readdir() */


static int unix_readlink(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	const char *path = luaL_checkstring(L, 1);
	ssize_t n = 0;
	int error;

	do {
		if (U->bufsiz <= (size_t)n && (error = u_realloc(&U->buf, &U->bufsiz, n + 1)))
			return unixL_pusherror(L, error, "readlink", "~$#");

		if (-1 == (n = readlink(path, U->buf, U->bufsiz)))
			return unixL_pusherror(L, errno, "readlink", "~$#");
	} while ((size_t)n == U->bufsiz);

	lua_pushlstring(L, U->buf, n);

	return 1;
} /* unix_readlink() */


#if HAVE_READLINKAT
static int unix_readlinkat(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkatfileno(L, 1);
	const char *path = luaL_checkstring(L, 2);
	ssize_t n = 0;
	int error;

	do {
		if (U->bufsiz <= (size_t)n && (error = u_realloc(&U->buf, &U->bufsiz, n + 1)))
			return unixL_pusherror(L, error, "readlink", "~$#");

		if (-1 == (n = readlinkat(fd, path, U->buf, U->bufsiz)))
			return unixL_pusherror(L, errno, "readlinkat", "~$#");
	} while ((size_t)n == U->bufsiz);

	lua_pushlstring(L, U->buf, n);

	return 1;
} /* unix_readlinkat() */
#endif


static int unsafe_realloc(lua_State *L) {
	void *addr0 = unixL_checklightuserdata(L, 1);
	size_t size = unixL_checksize(L, 2);
	void *addr;

	if (!(addr = realloc(addr0, size)) && size > 0)
		return unixL_pusherror(L, errno, "realloc", "~$#");

	lua_pushlightuserdata(L, addr);
	return 1;
} /* unsafe_realloc() */


static int unsafe_reallocarray(lua_State *L) {
	void *addr0 = unixL_checklightuserdata(L, 1);
	size_t count = unixL_checksize(L, 2);
	size_t size = unixL_checksize(L, 3);
	void *addr;

	if (count > 0 && SIZE_MAX / count < size)
		return unixL_pusherror(L, ENOMEM, "reallocarray", "~$#");

	if (!(addr = realloc(addr0, count * size)) && count > 0 && size > 0)
		return unixL_pusherror(L, errno, "reallocarray", "~$#");

	lua_pushlightuserdata(L, addr);
	return 1;
} /* unsafe_reallocarray() */


static int unix_recv(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkfileno(L, 1);
	size_t size = unixL_checksize(L, 2);
	int flags = unixL_optinteger(L, 3, 0, 0, INT_MAX);
	ssize_t n;
	int error;

	if (U->bufsiz < size && ((error = u_realloc(&U->buf, &U->bufsiz, size))))
		return unixL_pusherror(L, error, "recv", "~$#");

	if (-1 == (n = recv(fd, U->buf, size, flags)))
		return unixL_pusherror(L, errno, "recv", "~$#");

	lua_pushlstring(L, U->buf, n);

	return 1;
} /* unix_recv() */


static int unix_recvfrom(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkfileno(L, 1);
	size_t size = unixL_checksize(L, 2);
	int flags = unixL_optinteger(L, 3, 0, 0, INT_MAX);
	struct sockaddr_storage from;
	socklen_t fromlen;
	ssize_t n;
	void *ud;
	int error;

	if (U->bufsiz < size && ((error = u_realloc(&U->buf, &U->bufsiz, size))))
		return unixL_pusherror(L, error, "recvfrom", "~$#");

	fromlen = sizeof from;
	if (-1 == (n = recvfrom(fd, U->buf, size, flags, (struct sockaddr *)&from, &fromlen)))
		return unixL_pusherror(L, errno, "recvfrom", "~$#");

	lua_pushlstring(L, U->buf, n);

	/* TODO: What if our buffer is too small? */
	ud = lua_newuserdata(L, fromlen);
	memcpy(ud, &from, MIN(fromlen, sizeof from));
	luaL_setmetatable(L, "struct sockaddr");

	return 2;
} /* unix_recvfrom() */


static int unix_recvfromto(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	int fd = unixL_checkfileno(L, 1);
	size_t size = unixL_checksize(L, 2);
	int flags = unixL_optinteger(L, 3, 0, 0, INT_MAX);
	struct sockaddr_storage from, to;
	size_t fromlen, tolen;
	ssize_t n;
	int error;

	if (U->bufsiz < size && ((error = u_realloc(&U->buf, &U->bufsiz, size))))
		return unixL_pusherror(L, error, "recvfromto", "~$#");

	fromlen = sizeof from;
	tolen = sizeof to;
	if (-1 == (n = u_recvfromto(fd, U->buf, size, flags, (struct sockaddr *)&from, &fromlen, (struct sockaddr *)&to, &tolen, &error)))
		return unixL_pusherror(L, error, "recvfromto", "~$#");

	lua_pushlstring(L, U->buf, n);
	unixL_newsockaddr(L, &from, fromlen);
	unixL_newsockaddr(L, &to, tolen);

	return 3;
} /* unix_recvfromto() */

static int sa__index_in(lua_State *L, const struct sockaddr_in *in, const char *k) {
	if (!strcmp(k, "addr")) {
		char addr[INET_ADDRSTRLEN];

		if (!inet_ntop(AF_INET, &in->sin_addr, addr, sizeof addr))
			return 0;
		lua_pushstring(L, addr);
		return 1;
	} else if (!strcmp(k, "port")) {
		lua_pushinteger(L, ntohs(in->sin_port));
		return 1;
	}

	return 0;
} /* sa__index_in() */

static int sa__index_in6(lua_State *L, const struct sockaddr_in6 *in6, const char *k) {
	if (!strcmp(k, "addr")) {
		char addr[INET6_ADDRSTRLEN];

		if (!inet_ntop(AF_INET6, &in6->sin6_addr, addr, sizeof addr))
			return 0;
		lua_pushstring(L, addr);
		return 1;
	} else if (!strcmp(k, "port")) {
		lua_pushinteger(L, ntohs(in6->sin6_port));
		return 1;
	} else if (!strcmp(k, "flowinfo")) {
		unixL_pushunsigned(L, in6->sin6_flowinfo);
		return 1;
	} else if (!strcmp(k, "scope_id")) {
		unixL_pushunsigned(L, in6->sin6_scope_id);
		return 1;
	}

	return 0;
} /* sa__index_in6() */

static int sa__index_un(lua_State *L, const struct sockaddr_un *un, size_t unlen, const char *k) {
	if (!strcmp(k, "path")) {
		size_t pathsiz, pathlen;

		if (unlen < offsetof(struct sockaddr_un, sun_path))
			return 0;
		pathsiz = un->sun_path[unlen - offsetof(struct sockaddr_un, sun_path)];
		pathlen = strnlen(un->sun_path, pathsiz);
		if (pathlen == 0) {
#if __linux__
			if (pathsiz && (pathlen = strnlen(&un->sun_path[1], pathsiz - 1))) {
				lua_pushlstring(L, un->sun_path, pathlen + 1);
				return 1;
			}
#endif
			return 0;
		}
		lua_pushlstring(L, un->sun_path, pathlen);
		return 1;
	}

	return 0;
} /* sa__index_un() */

static int sa__index(lua_State *L) {
	struct sockaddr *addr = luaL_checkudata(L, 1, "struct sockaddr");
	size_t addrlen = lua_rawlen(L, 1);
	const char *k = luaL_checkstring(L, 2);

	if (addrlen < offsetof(struct sockaddr, sa_family) + sizeof addr->sa_family)
		return 0;

	if (!strcmp(k, "family")) {
		lua_pushinteger(L, addr->sa_family);
		return 0;
	} else if (addr->sa_family == AF_INET) {
		return sa__index_in(L, (struct sockaddr_in *)addr, k);
	} else if (addr->sa_family == AF_INET6) {
		return sa__index_in6(L, (struct sockaddr_in6 *)addr, k);
	} else if (addr->sa_family == AF_UNIX) {
		return sa__index_un(L, (struct sockaddr_un *)addr, addrlen, k);
	}

	return 0;
} /* so__index() */

static int sa__tostring(lua_State *L) {
	struct sockaddr *sa = luaL_checkudata(L, 1, "struct sockaddr");

	lua_pushlstring(L, (char *)sa, lua_rawlen(L, 1));

	return 1;
} /* sa__tostring() */

static const luaL_Reg sa_metamethods[] = {
	{ "__index",    &sa__index },
	{ "__tostring", &sa__tostring },
	{ NULL,         NULL }
}; /* sa_metamethods[] */


struct u_regex {
	regex_t regex;
	int cflags;
	_Bool closed;

	/* allocated array length will be at least re.re_nsub + 1 */
#if HAVE_C_FLEXIBLE_ARRAY_MEMBER
	regmatch_t match[];
#else
	regmatch_t match[1];
#endif
};

#define REGCOMP_ESCAPE 0x100
#define REGCOMP_BRACKET 0x200
#define REGCOMP_ESCAPED(ch) ((ch) | REGCOMP_ESCAPE)
#define REGCOMP_BRACKETED(ch) ((ch) | REGCOMP_BRACKET)

static size_t
regcomp_nsub(const char *cp, const int cflags)
{
	const char *obp = NULL;
	int state = 0, ch;
	size_t n = 0;

	for (; (ch = (*cp)? (state | *cp) : 0); cp++) {
		state &= ~REGCOMP_ESCAPE;

		switch (ch) {
		case '\\':
			state |= REGCOMP_ESCAPE;
			break;
		case '[':
			obp = cp;
			state |= REGCOMP_BRACKET;
			break;
		case REGCOMP_BRACKETED(']'):
			if (cp == &obp[1])
				break;
			if (cp == &obp[2] && obp[1] == '^')
				break;
			obp = NULL;
			state &= ~REGCOMP_BRACKET;
			break;
		case '(':
			n += !!(cflags & REG_EXTENDED);
			break;
		case REGCOMP_ESCAPED('('):
			n += !(cflags & REG_EXTENDED);
			break;
		default:
			break;
		}
	}

	return n;
}

static struct u_regex *
regcomp_prepregex(lua_State *L, int index, size_t nsub)
{
	struct u_regex *re;
	size_t size;

	/* +1 for 0th match */
	if (nsub + 1 > (SIZE_MAX - offsetof(struct u_regex, match)) / sizeof re->match[0])
		luaL_error(L, "too many subexpressions in regular expression");

	size = offsetof(struct u_regex, match) + ((nsub + 1) * sizeof re->match[0]);
	re = lua_newuserdata(L, size);
	memset(re, 0, sizeof *re);
	re->closed = 1; /* starts off closed because not yet compiled */
	luaL_setmetatable(L, "regex_t");

#if LUA_VERSION_NUM > 502
	lua_pushvalue(L, index);
	lua_setuservalue(L, -2);
#else
	lua_createtable(L, 1, 0);
	lua_pushvalue(L, index);
	lua_rawseti(L, -2, 1);
#if LUA_VERSION_NUM > 501
	lua_setuservalue(L, -2);
#else
	lua_setfenv(L, -2);
#endif
#endif

	return re;
}

static int
regex_pusherrstr(lua_State *L, int error, regex_t *preg)
{
	luaL_Buffer errbuf;
	size_t n;

	luaL_buffinit(L, &errbuf);
	n = regerror(error, preg, luaL_prepbuffer(&errbuf), LUAL_BUFFERSIZE);
	if (n > LUAL_BUFFERSIZE) {
#if LUA_VERSION_NUM >= 502
		n = regerror(error, preg, luaL_prepbuffsize(&errbuf, n), n);
#else
		n = LUAL_BUFFERSIZE;
#endif
	}

	luaL_addsize(&errbuf, n - (n > 0));
	luaL_pushresult(&errbuf);

	return 1;
}

static int
regex_pusherror(lua_State *L, int error, regex_t *preg)
{
	lua_pushnil(L);
	regex_pusherrstr(L, error, preg);
	lua_pushinteger(L, error);

	return 3;
}

static int
regex_pushmatch(lua_State *L, const char *s, regmatch_t rm)
{
	if (rm.rm_so < 0 || rm.rm_eo < rm.rm_so)
		luaL_error(L, "unexpected regular expression match offsets");
	lua_pushlstring(L, &s[rm.rm_so], rm.rm_eo - rm.rm_so);
	return 1;
}

static struct u_regex *
regex_checkself(lua_State *L, int index)
{
	struct u_regex *re = luaL_checkudata(L, index, "regex_t");

	luaL_argcheck(L, !re->closed, index, "attempt to use freed regular expression");

	return re;
}

static int
regex__index(lua_State *L)
{
	struct u_regex *re = regex_checkself(L, 1);
	const char *k = luaL_checkstring(L, 2);

	if (!strcmp(k, "nsub")) {
		lua_pushinteger(L, re->regex.re_nsub);
		return 1;
	}

	return 0;
}

static int
regex__tostring(lua_State *L)
{
	struct u_regex *re = regex_checkself(L, 1);

#if LUA_VERSION_NUM > 502
	lua_getuservalue(L, 1);
#elif LUA_VERSION_NUM > 501
	lua_getuservalue(L, 1);
	lua_rawgeti(L, -1, 1);
#else
	lua_getfenv(L, 1);
	lua_rawgeti(L, -1, 1);
#endif

	return 1;
}

static int
regex__gc(lua_State *L)
{
	struct u_regex *re = luaL_checkudata(L, 1, "regex_t");

	if (!re->closed) {
		regfree(&re->regex);
		re->closed = 1;
	}

	return 0;
}

static const luaL_Reg regex_metamethods[] = {
	{ "__index",    &regex__index },
	{ "__tostring", &regex__tostring },
	{ "__gc",       &regex__gc },
	{ NULL,         NULL }
}; /* regex_metamethods[] */


static int unix_regcomp(lua_State *L) {
	const char *patt = luaL_checkstring(L, 1);
	const int cflags = unixL_optint(L, 2, 0);
	size_t nsub = regcomp_nsub(patt, cflags);
	struct u_regex *re;
	int error;

	for (int i = 0; i < 2; i++) {
		re = regcomp_prepregex(L, 1, nsub);
		error = regcomp(&re->regex, patt, cflags);
		if (error) {
			return regex_pusherror(L, error, &re->regex);
		} else if (nsub >= re->regex.re_nsub) {
			re->cflags = cflags;
			re->closed = 0;
			return 1;
		}

		nsub = re->regex.re_nsub;
		regfree(&re->regex);
		lua_pop(L, 1);
	}

	return luaL_error(L, "unable to preallocate match array for regular expression");
} /* unix_regcomp() */


static int unix_regerror(lua_State *L) {
	int error = unixL_checkint(L, 1);
	struct u_regex *re = (lua_isnoneornil(L, 2))? NULL : luaL_checkudata(L, 2, "regex_t");

	return regex_pusherrstr(L, error, (re)? &re->regex : NULL);
} /* unix_regerror() */


/* regexec(regex [[, i][, table], eflags]) */
static int unix_regexec(lua_State *L) {
	struct u_regex *re = regex_checkself(L, 1);
	const char *subj = luaL_checkstring(L, 2);
	int tindex = 0, eflags = 0;
	int top = lua_gettop(L);
	int error;

	luaL_argcheck(L, top <= 5, top, "too many arguments");

	if (top > 2 && lua_isnumber(L, top)) {
		eflags = unixL_checkint(L, top--);
	}

	if (top > 2 && lua_istable(L, top)) {
		luaL_argcheck(L, !(re->cflags & REG_NOSUB), top, "match array specified but regular expression compiled with REG_NOSUB");
		tindex = top--;
	}

	if (top > 2 && lua_isnumber(L, top)) {
		lua_Integer i = luaL_checkinteger(L, top--);
		size_t len = lua_rawlen(L, 2);

		if (i > 0) {
			subj += MIN((unixL_Unsigned)(i - 1), len);
		} else if (i < 0) {
			subj += len - MIN(-(unixL_Unsigned)i, len);
		}
	}

	luaL_argcheck(L, top == 2, top, lua_pushfstring(L, "expected integer or table, got %s", luaL_typename(L, top)));

	if ((error = regexec(&re->regex, subj, re->regex.re_nsub + 1, re->match, eflags)))
		return regex_pusherror(L, error, &re->regex);

	if (re->cflags & REG_NOSUB) {
		lua_pushboolean(L, 1);

		return 1;
	} else if (tindex) {
		lua_pushvalue(L, tindex);

		for (size_t i = 0; i < re->regex.re_nsub + 1; i++) {
			if (LUA_TNIL == lua_geti(L, -1, i)) {
				lua_pop(L, 1);
				lua_createtable(L, 0, 2);
				lua_pushvalue(L, -1);
				lua_seti(L, -3, i);
			}

			lua_pushinteger(L, re->match[i].rm_so);
			lua_setfield(L, -2, "so");
			lua_pushinteger(L, re->match[i].rm_eo);
			lua_setfield(L, -2, "eo");
			lua_pop(L, 1);
		}

		return 1;
	} else if (re->regex.re_nsub) {
		if (re->regex.re_nsub > (size_t)(INT_MAX - lua_gettop(L)) || !lua_checkstack(L, re->regex.re_nsub))
			luaL_error(L, "stack overflow returning regular expression matches");

		for (size_t i = 0; i < re->regex.re_nsub; i++) {
			regmatch_t rm = re->match[i + 1];
			if (rm.rm_so == -1) {
				lua_pushnil(L);
			} else {
				regex_pushmatch(L, subj, rm);
			}
		}

		return re->regex.re_nsub;
	} else {
		return regex_pushmatch(L, subj, re->match[0]);
	}
} /* unix_regexec() */


static int unix_regfree(lua_State *L) {
	struct u_regex *re = regex_checkself(L, 1);

	regfree(&re->regex);
	re->closed = 1;

	return 0;
} /* unix_regfree() */


static int unix_rename(lua_State *L) {
	const char *opath = luaL_checkstring(L, 1);
	const char *npath = luaL_checkstring(L, 2);

	if (0 != rename(opath, npath))
		return unixL_pusherror(L, errno, "rename", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_rename() */


#if HAVE_RENAMEAT
static int unix_renameat(lua_State *L) {
	int fromfd = unixL_checkatfileno(L, 1);
	const char *from = luaL_checkstring(L, 2);
	int tofd = unixL_checkatfileno(L, 3);
	const char *to = luaL_checkstring(L, 4);

	if (0 != renameat(fromfd, from, tofd, to))
		return unixL_pusherror(L, errno, "renameat", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_renameat() */
#endif


static int unix_rewinddir(lua_State *L) {
	return dir_rewind(L);
} /* unix_rewinddir() */


#define unix_S_IFTEST(L, test) do { \
	int mode = luaL_optinteger(L, 1, 0); \
	lua_pushboolean(L, test(mode)); \
	return 1; \
} while (0)

static int unix_S_ISBLK(lua_State *L) {
	unix_S_IFTEST(L, S_ISBLK);
} /* unix_S_ISBLK() */


static int unix_S_ISCHR(lua_State *L) {
	unix_S_IFTEST(L, S_ISCHR);
} /* unix_S_ISCHR() */


static int unix_S_ISDIR(lua_State *L) {
	unix_S_IFTEST(L, S_ISDIR);
} /* unix_S_ISDIR() */


static int unix_S_ISFIFO(lua_State *L) {
	unix_S_IFTEST(L, S_ISFIFO);
} /* unix_S_ISFIFO() */


static int unix_S_ISREG(lua_State *L) {
	unix_S_IFTEST(L, S_ISREG);
} /* unix_S_ISREG() */


static int unix_S_ISLNK(lua_State *L) {
	unix_S_IFTEST(L, S_ISLNK);
} /* unix_S_ISLNK() */


static int unix_S_ISSOCK(lua_State *L) {
	unix_S_IFTEST(L, S_ISSOCK);
} /* unix_S_ISSOCK() */


static int unix_rmdir(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);

	if (0 != rmdir(path))
		return unixL_pusherror(L, errno, "rmdir", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_rmdir() */


static int unix_send(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	size_t size;
	const char *src = luaL_checklstring(L, 2, &size);
	int flags = unixL_optinteger(L, 3, 0, 0, INT_MAX);
	ssize_t n;

	if (-1 == (n = send(fd, src, size, flags)))
		return unixL_pusherror(L, errno, "send", "~$#");

	unixL_pushsize(L, n);

	return 1;
} /* unix_send() */


static int unix_sendto(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	size_t size;
	const char *src = luaL_checklstring(L, 2, &size);
	int flags = unixL_optinteger(L, 3, 0, 0, INT_MAX);
	size_t tolen;
	void *to = unixL_checksockaddr(L, 4, &tolen);
	ssize_t n;

	if (-1 == (n = sendto(fd, src, size, flags, to, tolen)))
		return unixL_pusherror(L, errno, "sendto", "~$#");

	unixL_pushsize(L, n);

	return 1;
} /* unix_sendto() */


static int unix_sendtofrom(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	size_t size;
	const char *src = luaL_checklstring(L, 2, &size);
	int flags = unixL_optinteger(L, 3, 0, 0, INT_MAX);
	size_t tolen;
	struct sockaddr *to = unixL_checksockaddr(L, 4, &tolen);
	size_t fromlen;
	struct sockaddr *from = unixL_checksockaddr(L, 5, &fromlen);
	ssize_t n;
	int error;

	if (-1 == (n = u_sendtofrom(fd, src, size, flags, to, tolen, from, fromlen, &error)))
		return unixL_pusherror(L, error, "sendtofrom", "~$#");

	unixL_pushsize(L, n);

	return 1;
} /* unix_sendtofrom() */


static int unix_setegid(lua_State *L) {
	gid_t gid = unixL_checkgid(L, 1);

	if (0 != setegid(gid))
		return unixL_pusherror(L, errno, "setegid", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_setegid() */


static int unix_setenv(lua_State *L) {
	return unixL_setenv(L, 1, 2, 3);
} /* unix_setenv() */


static int unix_seteuid(lua_State *L) {
	uid_t uid = unixL_checkuid(L, 1);

	if (0 != seteuid(uid))
		return unixL_pusherror(L, errno, "seteuid", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_seteuid() */


static int unix_setgid(lua_State *L) {
	gid_t gid = unixL_checkgid(L, 1);

	if (0 != setgid(gid))
		return unixL_pusherror(L, errno, "setgid", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_setgid() */


static int unix_setgroups(lua_State *L) {
	gid_t *group;
	size_t n, i;

	luaL_checktype(L, 1, LUA_TTABLE);
	n = lua_rawlen(L, 1);

	if (n > (size_t)-1 / sizeof *group)
		return unixL_pusherror(L, ENOMEM, "setgroups", "0$#");

	group = lua_newuserdata(L, n * sizeof *group);

	for (i = 0; i < n; i++) {
		lua_rawgeti(L, 1, i + 1);
		group[i] = unixL_checkgid(L, -1);
	}

	if (0 != setgroups(n, group))
		return unixL_pusherror(L, errno, "setgroups", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_setgroups() */


static int unix_setlocale(lua_State *L) {
	const char *locale;

	if ((locale = setlocale(luaL_checkint(L, 1), luaL_optstring(L, 2, NULL))))
		lua_pushstring(L, locale);
	else
		lua_pushnil(L);

	return 1;
} /* unix_setlocale() */


static int unix_setlogmask(lua_State *L) {
	int mask = unixL_optint(L, 1, 0); /* same default as luaposix */

	lua_pushinteger(L, setlogmask(mask));

	return 1;
} /* unix_setlogmask() */


static int unix_setpgid(lua_State *L) {
	pid_t pid = unixL_checkpid(L, 1);
	pid_t pgid = unixL_checkpid(L, 2);

	if (0 != setpgid(pid, pgid))
		return unixL_pusherror(L, errno, "setpgid", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_setpgid() */


static int unix_setrlimit(lua_State *L) {
	int what = rl_checkrlimit(L, 1);
	struct rlimit rl;

	rl.rlim_cur = rl_optrlim(L, 2, U_RLIM_SAVED_CUR);
	rl.rlim_max = rl_optrlim(L, 3, U_RLIM_SAVED_MAX);

	if (0 != setrlimit(what, &rl))
		return unixL_pusherror(L, errno, "setrlimit", "~$#");

	/*
	 * .rlim_cur and .rlim_max will be updated with new value
	 * if RLIM_SAVED_CUR or RLIM_SAVED_MAX
	 */
	rl_pushrlim(L, rl.rlim_cur);
	rl_pushrlim(L, rl.rlim_max);

	return 2;
} /* unix_setrlimit() */


static int unix_setsockopt(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int level = unixL_checkint(L, 2);
	int type = unixL_checkint(L, 3);
	int i, error;

	luaL_checkany(L, 4);

	switch (level) {
	case IPPROTO_IP:
		switch (type) {
#if HAVE_DECL_IP_PKTINFO
		case IP_PKTINFO:
			goto setbool;
#endif
#if HAVE_DECL_IP_RECVDSTADDR
		case IP_RECVDSTADDR:
			goto setbool;
#endif
#if HAVE_DECL_IP_TTL
		case IP_TTL:
			goto setint;
#endif
		}

		break;
	case IPPROTO_IPV6:
		switch (type) {
#if HAVE_DECL_IPV6_PKTINFO
		case IPV6_PKTINFO:
			goto setbool;
#endif
#if HAVE_DECL_IPV6_RECVPKTINFO
		case IPV6_RECVPKTINFO:
			goto setbool;
#endif
#if HAVE_DECL_IPV6_V6ONLY
		case IPV6_V6ONLY:
			goto setbool;
#endif
		}

		break;
	}

	error = ENOTSUP;
	goto error;
setbool:
	i = lua_toboolean(L, 4);
	if (0 != setsockopt(fd, level, type, &i, sizeof i))
		goto syerr;
	lua_pushboolean(L, 1);
	return 1;
setint:
	i = unixL_checkint(L, 4);
	if (0 != setsockopt(fd, level, type, &i, sizeof i))
		goto syerr;
	lua_pushboolean(L, 1);
	return 1;
syerr:
	error = errno;
error:
	return unixL_pusherror(L, error, "setsockopt", "0$#");
} /* unix_setsockopt() */


static int unsafe_setsockopt(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	int level = unixL_checkint(L, 2);
	int type = unixL_checkint(L, 3);
	const struct iovec iov = unixL_checkstring(L, 4, 0, INT_MAX); /* length must fit socklen_t */
	int n, error;

	n = lua_gettop(L);
	luaL_argcheck(L, n <= 4, 5, lua_pushfstring(L, "expected 4 arguments, got %d", n));

	if (0 != setsockopt(fd, level, type, iov.iov_base, (socklen_t)iov.iov_len))
		return unixL_pusherror(L, errno, "setsockopt", "~$#");

	lua_pushboolean(L, 1);
	return 1;
} /* unsafe_setsockopt() */


static int unix_setsid(lua_State *L) {
	pid_t pg;

	if (-1 == (pg = setsid()))
		return unixL_pusherror(L, errno, "setsid", "~$#");

	lua_pushinteger(L, pg);

	return 1;
} /* unix_setsid() */


static int unix_setuid(lua_State *L) {
	uid_t uid = unixL_checkuid(L, 1);

	if (0 != setuid(uid))
		return unixL_pusherror(L, errno, "setuid", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_setuid() */


static int unix_sigaction(lua_State *L) {
	int signo = luaL_checkint(L, 1);
	struct sigaction act, oact;

	lua_settop(L, 3);

	memset(&oact, 0, sizeof oact);

	if (lua_isnil(L, 2)) {
		if (0 != sigaction(signo, NULL, &oact))
			goto syerr;
	} else {
		luaL_checktype(L, 2, LUA_TTABLE);

		memset(&act, 0, sizeof act);

		lua_getfield(L, 2, "handler");
		act.sa_handler = unixL_tosighandler(L, -1);
		lua_pop(L, 1);

		lua_getfield(L, 2, "mask");
		if (!lua_isnil(L, -1))
			act.sa_mask = *unixL_tosigset(L, -1, NULL);
		lua_pop(L, 1);

		act.sa_flags = unixL_optfint(L, 2, "flags", 0);

		if (0 != sigaction(signo, &act, &oact))
			goto syerr;
	}

	if (lua_toboolean(L, 3)) {
		lua_newtable(L);

		*(u_sighandler_t **)lua_newuserdata(L, sizeof (u_sighandler_t *)) = (u_sighandler_t *)oact.sa_handler;
		luaL_setmetatable(L, "sighandler_t*");
		lua_setfield(L, -2, "handler");

		*(sigset_t *)lua_newuserdata(L, sizeof (sigset_t)) = oact.sa_mask;
		luaL_setmetatable(L, "sigset_t");
		lua_setfield(L, -2, "mask");

		unixL_pushinteger(L, oact.sa_flags);
		lua_setfield(L, -2, "flags");
	} else {
		lua_pushboolean(L, 1);
	}

	return 1;
syerr:
	return unixL_pusherror(L, errno, "sigaction", "~$#");
} /* unix_sigaction() */


static int unix_sigfillset(lua_State *L) {
	lua_settop(L, 1);

	sigfillset(unixL_tosigset(L, 1, NULL));

	return 1;
} /* unix_sigfillset() */


static int unix_sigemptyset(lua_State *L) {
	lua_settop(L, 1);

	sigemptyset(unixL_tosigset(L, 1, NULL));

	return 1;
} /* unix_sigemptyset() */


static int unix_sigaddset(lua_State *L) {
	sigset_t *set = unixL_tosigset(L, 1, NULL);
	int i;

	for (i = 2; i <= lua_gettop(L); i++)
		sigaddset(set, luaL_checkint(L, i));

	lua_settop(L, 1);

	return 1;
} /* unix_sigaddset() */


static int unix_sigdelset(lua_State *L) {
	sigset_t *set = unixL_tosigset(L, 1, NULL);
	int i;

	for (i = 2; i <= lua_gettop(L); i++)
		sigdelset(set, luaL_checkint(L, i));

	lua_settop(L, 1);

	return 1;
} /* unix_sigdelset() */


static int unix_sigismember(lua_State *L) {
	sigset_t tmp;

	lua_pushboolean(L, sigismember(unixL_tosigset(L, 1, &tmp), luaL_checkint(L, 2)));

	return 1;
} /* unix_sigismember() */


static int unix_sigprocmask(lua_State *L) {
	int how = luaL_optint(L, 1, SIG_BLOCK);
	sigset_t tmp, *set, *oset;

	lua_settop(L, 3);

	set = (!lua_isnil(L, 2))? unixL_tosigset(L, 2, &tmp) : NULL;
	oset = unixL_tosigset(L, 3, NULL);

	sigemptyset(oset);

	if (0 != sigprocmask(how, set, oset))
		return unixL_pusherror(L, errno, "sigprocmask", "~$#");

	return 1; /* returns oset */
} /* unix_sigprocmask() */


static int unix_sigtimedwait(lua_State *L) {
	sigset_t tmp, *set;
	struct timespec timeout;
	siginfo_t si;
	int signo, error;

	if (lua_isnoneornil(L, 1)) {
		sigfillset(&tmp);
	} else {
		if (&tmp != (set = unixL_tosigset(L, 1, &tmp)))
			tmp = *set;
	}

	/* these cannot be caught and will trigger EINVAL on AIX */
	sigdelset(&tmp, SIGKILL);
	sigdelset(&tmp, SIGSTOP);

	memset(&si, 0, sizeof si);

	if ((error = u_sigtimedwait(&signo, &tmp, &si, u_f2ts(&timeout, luaL_optnumber(L, 2, U_NAN)))))
		return unixL_pusherror(L, error, "sigtimedwait", "~$#");

	lua_pushinteger(L, signo);

	lua_newtable(L);
	lua_pushinteger(L, si.si_signo);
	lua_setfield(L, -2, "signo");

	return 2;
} /* unix_sigtimedwait() */


static int unix_sigwait(lua_State *L) {
	sigset_t set, *_set;
	int signo, error;

	if (lua_isnoneornil(L, 1)) {
		sigfillset(&set);
	} else {
		if (&set != (_set = unixL_tosigset(L, 1, &set)))
			set = *_set;
	}

	/* these cannot be caught and will trigger EINVAL on AIX */
	sigdelset(&set, SIGKILL);
	sigdelset(&set, SIGSTOP);

	if ((error = u_sigwait(&set, &signo)))
		return unixL_pusherror(L, error, "sigwait", "~$#");

	lua_pushinteger(L, signo);

	return 1;
} /* unix_sigwait() */


static int unix_sleep(lua_State *L) {
	unsigned n = unixL_checkunsigned(L, 1, 0, U_TMAX(unsigned));

	unixL_pushunsigned(L, sleep(n));

	return 1;
} /* unix_sleep() */


static int unix_socket(lua_State *L) {
	int family = unixL_checkint(L, 1);
	int socktype = unixL_checkint(L, 2);
	int protocol = unixL_optint(L, 3, 0);
	int fd;

	if (-1 == (fd = socket(family, socktype, protocol)))
		return unixL_pusherror(L, errno, "socket", "~$#");

	lua_pushinteger(L, fd);

	return 1;
} /* unix_socket() */


static int unix_socketpair(lua_State *L) {
	int family = unixL_checkint(L, 1);
	int socktype = unixL_checkint(L, 2);
	int protocol = unixL_optint(L, 3, 0);
	int fd[2];

	if (0 != socketpair(family, socktype, protocol, fd))
		return unixL_pusherror(L, errno, "socketpair", "~$#");

	lua_pushinteger(L, fd[0]);
	lua_pushinteger(L, fd[1]);

	return 2;
} /* unix_socketpair() */


enum st_field {
	STF_DEV,
	STF_INO,
	STF_MODE,
	STF_NLINK,
	STF_UID,
	STF_GID,
	STF_RDEV,
	STF_SIZE,
	STF_ATIME,
	STF_MTIME,
	STF_CTIME,
	STF_BLKSIZE,
	STF_BLOCKS,
}; /* enum st_field */

static const char *st_field[] = {
	"dev", "ino", "mode", "nlink", "uid", "gid", "rdev", "size",
	"atime", "mtime", "ctime", "blksize", "blocks", NULL
}; /* st_field[] */

/* AIX uses struct st_timespec, where tv_nsec is an int instead of a long. */
#define ST_TIMESPEC_TO_TIMESPEC(st_ts, ts) do { \
	(ts)->tv_sec = (st_ts)->tv_sec; \
	(ts)->tv_nsec = (st_ts)->tv_nsec; \
} while (0)

#define st_pushtimespec(L, st_ts) do { \
	struct timespec ts; \
	ST_TIMESPEC_TO_TIMESPEC((st_ts), &ts); \
	lua_pushnumber(L, u_ts2f(&ts)); \
} while (0)

static void st_pushfield(lua_State *L, const struct stat *st, enum st_field type) {
	switch (type) {
	case STF_DEV:
		lua_pushinteger(L, st->st_dev);
		break;
	case STF_INO:
		lua_pushinteger(L, st->st_ino);
		break;
	case STF_MODE:
		lua_pushinteger(L, st->st_mode);
		break;
	case STF_NLINK:
		lua_pushinteger(L, st->st_nlink);
		break;
	case STF_UID:
		lua_pushinteger(L, st->st_uid);
		break;
	case STF_GID:
		lua_pushinteger(L, st->st_gid);
		break;
#if HAVE_STRUCT_STAT_ST_RDEV
	case STF_RDEV:
		unixL_pushinteger(L, st->st_rdev);
		break;
#endif
	case STF_SIZE:
		unixL_pushinteger(L, st->st_size);
		break;
	case STF_ATIME:
#if HAVE_STRUCT_STAT_ST_ATIMESPEC
		lua_pushnumber(L, u_ts2f(&st->st_atimespec));
#elif HAVE_STRUCT_STAT_ST_ATIM
		st_pushtimespec(L, &st->st_atim);
#else
		lua_pushnumber(L, st->st_atime);
#endif
		break;
	case STF_MTIME:
#if HAVE_STRUCT_STAT_ST_MTIMESPEC
		lua_pushnumber(L, u_ts2f(&st->st_mtimespec));
#elif HAVE_STRUCT_STAT_ST_MTIM
		st_pushtimespec(L, &st->st_mtim);
#else
		lua_pushnumber(L, st->st_mtime);
#endif
		break;
	case STF_CTIME:
#if HAVE_STRUCT_STAT_ST_CTIMESPEC
		lua_pushnumber(L, u_ts2f(&st->st_ctimespec));
#elif HAVE_STRUCT_STAT_ST_CTIM
		st_pushtimespec(L, &st->st_ctim);
#else
		lua_pushnumber(L, st->st_ctime);
#endif
		break;
#if HAVE_STRUCT_STAT_ST_BLKSIZE
	case STF_BLKSIZE:
		unixL_pushinteger(L, st->st_blksize);
		break;
#endif
#if HAVE_STRUCT_STAT_ST_BLOCKS
	case STF_BLOCKS:
		unixL_pushinteger(L, st->st_blocks);
		break;
#endif
	default:
		lua_pushnil(L);
		break;
	}
} /* st_pushfield() */

static void st_pushtable(lua_State *L, const struct stat *st) {
	lua_createtable(L, 0, countof(st_field) - 1);

	st_pushfield(L, st, STF_DEV);
	lua_setfield(L, -2, "dev");

	st_pushfield(L, st, STF_INO);
	lua_setfield(L, -2, "ino");

	st_pushfield(L, st, STF_MODE);
	lua_setfield(L, -2, "mode");

	st_pushfield(L, st, STF_NLINK);
	lua_setfield(L, -2, "nlink");

	st_pushfield(L, st, STF_UID);
	lua_setfield(L, -2, "uid");

	st_pushfield(L, st, STF_GID);
	lua_setfield(L, -2, "gid");

	st_pushfield(L, st, STF_RDEV);
	lua_setfield(L, -2, "rdev");

	st_pushfield(L, st, STF_SIZE);
	lua_setfield(L, -2, "size");

	st_pushfield(L, st, STF_ATIME);
	lua_setfield(L, -2, "atime");

	st_pushfield(L, st, STF_MTIME);
	lua_setfield(L, -2, "mtime");

	st_pushfield(L, st, STF_CTIME);
	lua_setfield(L, -2, "ctime");

	st_pushfield(L, st, STF_BLKSIZE);
	lua_setfield(L, -2, "blksize");

	st_pushfield(L, st, STF_BLOCKS);
	lua_setfield(L, -2, "blocks");
} /* st_pushtable() */

static int st_pushstat(lua_State *L, const struct stat *st, int fields) {
	if (lua_isnoneornil(L, fields)) {
		st_pushtable(L, st);

		return 1;
	} else {
		int top = lua_gettop(L), i;

		for (i = fields; i <= top; i++) {
			st_pushfield(L, st, luaL_checkoption(L, i, NULL, st_field));
		}

		return i - fields;
	}
} /* st_pushstat() */

static int unix_stat(lua_State *L) {
	struct stat st;
	int fd;

	if (-1 != (fd = unixL_optfileno(L, 1, -1))) {
		if (0 != fstat(fd, &st))
			return unixL_pusherror(L, errno, "stat", "0$#");
	} else {
		const char *path = luaL_checkstring(L, 1);

		if (0 != stat(path, &st))
			return unixL_pusherror(L, errno, "stat", "0$#");
	}

	return st_pushstat(L, &st, 2);
} /* unix_stat() */


static int unix_strerror(lua_State *L) {
	lua_pushstring(L, unixL_strerror(L, luaL_checkint(L, 1)));

	return 1;
} /* unix_strerror() */


static int unsafe_strlen(lua_State *L) {
	unixL_pushsize(L, strlen(unixL_checklightuserdata(L, 1)));
	return 1;
} /* unsafe_strlen() */


static int unsafe_strnlen(lua_State *L) {
	unixL_pushsize(L, strnlen(unixL_checklightuserdata(L, 1), unixL_checksize(L, 2)));
	return 1;
} /* unsafe_strnlen() */


static int unix_strsignal(lua_State *L) {
	lua_pushstring(L, unixL_strsignal(L, luaL_checkint(L, 1)));

	return 1;
} /* unix_strsignal() */


static int unix_symlink(lua_State *L) {
	const char *src = luaL_checkstring(L, 1);
	const char *dst = luaL_checkstring(L, 2);

	if (0 != symlink(src, dst))
		return unixL_pusherror(L, errno, "symlink", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_symlink() */


#if HAVE_SYMLINKAT
static int unix_symlinkat(lua_State *L) {
	const char *src = luaL_checkstring(L, 1);
	int fd = unixL_checkatfileno(L, 2);
	const char *dst = luaL_checkstring(L, 3);

	if (0 != symlinkat(src, fd, dst))
		return unixL_pusherror(L, errno, "symlinkat", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_symlinkat() */
#endif


static int unix_sysconf(lua_State *L) {
	int name = unixL_checkint(L, 1);
	long v;

	errno = 0;
	if (-1 == (v = sysconf(name)) && errno)
		return unixL_pusherror(L, errno, "sysconf", "~$#");

	lua_pushinteger(L, v);

	return 1;
} /* unix_sysconf() */


static int unix_syslog(lua_State *L) {
	int priority = unixL_checkint(L, 1);
	const char *msg = luaL_checkstring(L, 2);

	/*
	 * TODO: Transparently behave like string.format, but with
	 * additional support for %m. To help preserve this possibility
	 * enforce the 2-argument form for now, which is how luaposix
	 * behaves, anyhow.
	 */
	if (lua_gettop(L) > 2)
		return luaL_error(L, "expected 2 arguments, got %d", lua_gettop(L));

	syslog(priority, "%s", msg);

	return 0;
} /* unix_syslog() */


static int unix_tcgetpgrp(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	pid_t pgid;

	if (-1 == (pgid = tcgetpgrp(fd)))
		return unixL_pusherror(L, errno, "tcgetpgrp", "~$#");

	lua_pushinteger(L, pgid);

	return 1;
} /* unix_tcgetpgrp() */


static int unix_tcgetsid(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	pid_t sid;

	if (-1 == (sid = tcgetsid(fd)))
		return unixL_pusherror(L, errno, "tcgetsid", "~$#");

	lua_pushinteger(L, sid);

	return 1;
} /* unix_tcgetsid() */


static int unix_tcsetpgrp(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	pid_t pgid = unixL_checkpid(L, 2);

	if (0 != tcsetpgrp(fd, pgid))
		return unixL_pusherror(L, errno, "tcsetpgrp", "~$#");

	lua_pushvalue(L, 1);

	return 1;
} /* unix_tcsetpgrp() */


static int yr_isleap(int year) {
	if (year >= 0)
		return !(year % 4) && ((year % 100) || !(year % 400));
	else
		return yr_isleap(-(year + 1));
} /* yr_isleap() */


static int tm_yday(const struct tm *tm) {
	static const int past[12] = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
	int yday;

	if (tm->tm_yday)
		return tm->tm_yday;

	yday = past[CLAMP(tm->tm_mon, 0, 11)] + CLAMP(tm->tm_mday, 1, 31) - 1;

	return yday + (tm->tm_mon > 1 && yr_isleap(1900 + tm->tm_year));
} /* tm_yday() */


static int yr_nleaps(int year) {
	if (year >= 0)
		return (year / 400) + (year / 4) - (year / 100);
	else
		return -(yr_nleaps(-(year + 1)) + 1);
} /* yr_nleaps() */


static double tm2unix(const struct tm *tm) {
	int year = tm->tm_year + 1900;
	double ts;

	ts = 86400.0 * 365.0 * (year - 1970);
	ts += 86400.0 * (yr_nleaps(year - 1) - yr_nleaps(1969));
	ts += 86400 * tm_yday(tm);
	ts += 3600 * tm->tm_hour;
	ts += 60 * tm->tm_min;
	ts += CLAMP(tm->tm_sec, 0, 59);

	return ts;
} /* tm2unix() */


static int unix_timegm(lua_State *L) {
	struct tm tm = { 0 };

	unixL_opttm(L, 1, NULL, &tm);

	lua_pushnumber(L, tm2unix(&tm));

	return 1;
} /* unix_timegm() */


static int unix_truncate(lua_State *L) {
	const char *path;
	int fd;
	off_t len;

	/* TODO: check overflow */
	len = (off_t)luaL_optnumber(L, 2, 0);

	if (-1 != (fd = unixL_optfileno(L, 1, -1))) {
		if (0 != ftruncate(fd, len))
			return unixL_pusherror(L, errno, "truncate", "0$#");
	} else {
		path = luaL_checkstring(L, 1);

		if (0 != truncate(path, len))
			return unixL_pusherror(L, errno, "truncate", "0$#");
	}

	lua_pushboolean(L, 1);

	return 1;
} /* unix_truncate() */


static int unix_tzset(lua_State *L) {
	tzset();

	lua_pushboolean(L, 1);

	return 1;
} /* unix_tzset() */


static int unix_umask(lua_State *L) {
	mode_t cmask = unixL_getumask(L);

	if (lua_isnoneornil(L, 1)) {
		lua_pushinteger(L, cmask);
	} else {
		lua_pushinteger(L, umask(unixL_optmode(L, 1, cmask, cmask)));
	}

	return 1;
} /* unix_umask() */


static int unix_uname(lua_State *L) {
	struct utsname name;

	if (-1 == uname(&name))
		return unixL_pusherror(L, errno, "uname", "~$#");

	if (lua_isnoneornil(L, 1)) {
		lua_createtable(L, 0, 5);

		lua_pushstring(L, name.sysname);
		lua_setfield(L, -2, "sysname");

		lua_pushstring(L, name.nodename);
		lua_setfield(L, -2, "nodename");

		lua_pushstring(L, name.release);
		lua_setfield(L, -2, "release");

		lua_pushstring(L, name.version);
		lua_setfield(L, -2, "version");

		lua_pushstring(L, name.machine);
		lua_setfield(L, -2, "machine");

		return 1;
	} else {
		static const char *opts[] = {
			"sysname", "nodename", "release", "version", "machine", NULL
		};
		int i, n = 0, top = lua_gettop(L);

		for (i = 1; i <= top; i++) {
			switch (luaL_checkoption(L, i, NULL, opts)) {
			case 0:
				lua_pushstring(L, name.sysname);
				++n;

				break;
			case 1:
				lua_pushstring(L, name.nodename);
				++n;

				break;
			case 2:
				lua_pushstring(L, name.release);
				++n;

				break;
			case 3:
				lua_pushstring(L, name.version);
				++n;

				break;
			case 4:
				lua_pushstring(L, name.machine);
				++n;

				break;
			}
		}

		return n;
	}
} /* unix_uname() */


static int unix_unlink(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);

	if (0 != unlink(path))
		return unixL_pusherror(L, errno, "unlink", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_unlink() */


#if HAVE_UNLINKAT
static int unix_unlinkat(lua_State *L) {
	int at = unixL_checkatfileno(L, 1);
	const char *path = luaL_checkstring(L, 2);
	int flags = luaL_optint(L, 3, 0);

	if (0 != unlinkat(at, path, flags))
		return unixL_pusherror(L, errno, "unlinkat", "0$#");

	lua_pushboolean(L, 1);

	return 1;
} /* unix_unlinkat() */
#endif


static int unix_unlockpt(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);

	if (0 != unlockpt(fd))
		return unixL_pusherror(L, errno, "unlockpt", "~$#");

	lua_pushvalue(L, 1);

	return 1;
} /* unix_unlockpt() */


static int unix_unsetenv(lua_State *L) {
	return unixL_unsetenv(L, 1);
} /* unix_unsetenv() */


/* emulate luaposix because we have no reason not to */
static int unixL_wait(lua_State *L, const char *fn) {
	pid_t pid = luaL_optint(L, 1, -1);
	int options = luaL_optint(L, 2, 0);
	int status = 0;

	if (-1 == (pid = waitpid(pid, &status, options)))
		return unixL_pusherror(L, errno, fn, "~$#");

	lua_settop(L, 0);
	lua_pushinteger(L, pid);

	if (WIFEXITED(status)) {
		lua_pushliteral(L, "exited");
		lua_pushinteger(L, WEXITSTATUS(status));
	} else if (WIFSIGNALED(status)) {
		lua_pushliteral(L, "killed");
		lua_pushinteger(L, WTERMSIG(status));
	} else if (WIFSTOPPED(status)) {
		lua_pushliteral(L, "stopped");
		lua_pushinteger(L, WSTOPSIG(status));
#if defined WIFCONTINUED
	} else if (WIFCONTINUED(status)) {
		lua_pushliteral(L, "continued");
		lua_pushinteger(L, SIGCONT);
#endif
	}

	return lua_gettop(L);
} /* unixL_wait() */


static int unix_wait(lua_State *L) {
	return unixL_wait(L, "wait");
} /* unix_wait() */


static int unix_waitpid(lua_State *L) {
	return unixL_wait(L, "waitpid");
} /* unix_waitpid() */


static int unix_write(lua_State *L) {
	int fd = unixL_checkfileno(L, 1);
	size_t size;
	const char *src = luaL_checklstring(L, 2, &size);
	ssize_t n;

	if (-1 == (n = write(fd, src, size)))
		return unixL_pusherror(L, errno, "write", "~$#");

	unixL_pushsize(L, n);

	return 1;
} /* unix_write() */


static int unix_xor(lua_State *L) {
	unixL_pushinteger(L, unixL_checkinteger(L, 1) ^ unixL_checkinteger(L, 2));

	return 1;
} /* unix_xor() */


static int unix__index(lua_State *L) {
	unixL_State *U = unixL_getstate(L);
	const char *k = luaL_checkstring(L, 2);

	if (!strcmp(k, "errno")) {
		lua_pushinteger(L, U->error);
		return 1;
	} else if (!strcmp(k, "opterr")) {
		lua_pushboolean(L, !!U->opt.opterr);
		return 1;
	} else if (!strcmp(k, "optind")) {
		lua_pushinteger(L, U->opt.optind + U->opt.arg0);
		return 1;
	} else if (!strcmp(k, "optopt")) {
		getopt_pushoptc(L, U->opt.optopt);
		return 1;
	} else if (!strcmp(k, "_arg0")) {
		lua_pushinteger(L, U->opt.arg0);
		return 1;
	} else {
		return 0;
	}
} /* unix__index() */

static int unix__newindex(lua_State *L) {
	if (lua_type(L, 2) == LUA_TSTRING) {
		unixL_State *U = unixL_getstate(L);
		const char *k = lua_tostring(L, 2);

		if (!strcmp(k, "opterr")) {
			if (lua_isboolean(L, 3)) {
				U->opt.opterr = lua_toboolean(L, 3);
			} else {
				U->opt.opterr = unixL_checkint(L, 3);
			}
			return 0;
		}
	}

	lua_rawset(L, 1);

	return 0;
} /* unix__newindex() */


static const luaL_Reg unix_routines[] = {
	{ "accept",             &unix_accept },
	{ "alarm",              &unix_alarm },
	{ "arc4random",         &unix_arc4random },
	{ "arc4random_buf",     &unix_arc4random_buf },
	{ "arc4random_stir",    &unix_arc4random_stir },
	{ "arc4random_uniform", &unix_arc4random_uniform },
	{ "bind",               &unix_bind },
	{ "bitand",             &unix_bitand },
	{ "bitor",              &unix_bitor },
	{ "chdir",              &unix_chdir },
	{ "chmod",              &unix_chmod },
	{ "chown",              &unix_chown },
	{ "chroot",             &unix_chroot },
	{ "clearerr",           &unix_clearerr },
	{ "clock_gettime",      &unix_clock_gettime },
	{ "close",              &unix_close },
	{ "closedir",           &unix_closedir },
	{ "closelog",           &unix_closelog },
	{ "compl",              &unix_compl },
	{ "connect",            &unix_connect },
	{ "dup",                &unix_dup },
	{ "dup2",               &unix_dup2 },
#if HAVE_DUP3
	{ "dup3",               &unix_dup3 },
#endif
	{ "execve",             &unix_execve },
	{ "execl",              &unix_execl },
	{ "execlp",             &unix_execlp },
	{ "execvp",             &unix_execvp },
	{ "_exit",              &unix__exit },
	{ "exit",               &unix_exit },
	{ "fchmod",             &unix_chmod },
	{ "fchown",             &unix_chown },
	{ "fcntl",              &unix_fcntl },
#if HAVE_FDATASYNC
	{ "fdatasync",          &unix_fdatasync },
#endif
	{ "fdopen",             &unix_fdopen },
#if HAVE_FDOPENDIR
	{ "fdopendir",          &unix_fdopendir },
#endif
	{ "fdup",               &unix_fdup },
	{ "feof",               &unix_feof },
	{ "ferror",             &unix_ferror },
	{ "fgetc",              &unix_fgetc },
	{ "fileno",             &unix_fileno },
	{ "flockfile",          &unix_flockfile },
	{ "fnmatch",            &unix_fnmatch },
	{ "fstat",              &unix_stat },
#if HAVE_FSTATAT
	{ "fstatat",            &unix_fstatat },
#endif
	{ "fsync",              &unix_fsync },
	{ "ftrylockfile",       &unix_ftrylockfile },
	{ "funlockfile",        &unix_funlockfile },
	{ "fopen",              &unix_fopen },
#if HAVE_OPENAT
	{ "fopenat",            &unix_fopenat },
#endif
	{ "fpathconf",          &unix_pathconf },
	{ "fpipe",              &unix_fpipe },
	{ "fork",               &unix_fork },
	{ "gai_strerror",       &unix_gai_strerror },
	{ "getaddrinfo",        &unix_getaddrinfo },
	{ "getc",               &unix_fgetc },
	{ "getegid",            &unix_getegid },
	{ "geteuid",            &unix_geteuid },
	{ "getenv",             &unix_getenv },
	{ "getmode",            &unix_getmode },
	{ "getgid",             &unix_getgid },
	{ "getgrnam",           &unix_getgrnam },
	{ "getgrgid",           &unix_getgrnam },
	{ "getgroups",          &unix_getgroups },
	{ "gethostname",        &unix_gethostname },
	{ "getifaddrs",         &unix_getifaddrs },
	{ "getnameinfo",        &unix_getnameinfo },
	{ "getopt",             &unix_getopt },
	{ "getpeername",        &unix_getpeername },
	{ "getpgid",            &unix_getpgid },
	{ "getpgrp",            &unix_getpgrp },
	{ "getpid",             &unix_getpid },
	{ "getppid",            &unix_getppid },
	{ "getprogname",        &unix_getprogname },
	{ "getpwnam",           &unix_getpwnam },
	{ "getpwuid",           &unix_getpwnam },
	{ "getrlimit",          &unix_getrlimit },
	{ "getrusage",          &unix_getrusage },
	{ "getsockname",        &unix_getsockname },
	{ "gettimeofday",       &unix_gettimeofday },
	{ "getuid",             &unix_getuid },
	{ "grantpt",            &unix_grantpt },
	{ "ioctl",              &unix_ioctl },
	{ "isatty",             &unix_isatty },
	{ "issetugid",          &unix_issetugid },
	{ "kill",               &unix_kill },
	{ "lchown",             &unix_lchown },
	{ "link",               &unix_link },
	{ "listen",             &unix_listen },
	{ "lockf",              &unix_lockf },
	{ "LOG_MASK",           &unix_LOG_MASK },
	{ "LOG_UPTO",           &unix_LOG_UPTO },
	{ "lseek",              &unix_lseek },
	{ "lstat",              &unix_lstat },
	{ "mkdir",              &unix_mkdir },
#if HAVE_MKDIRAT
	{ "mkdirat",            &unix_mkdirat },
#endif
	{ "mkfifo",             &unix_mkfifo },
#if HAVE_MKFIFOAT
	{ "mkfifoat",           &unix_mkfifoat },
#endif
	{ "mkpath",             &unix_mkpath },
	{ "open",               &unix_open },
#if HAVE_OPENAT
	{ "openat",             &unix_openat },
#endif
	{ "opendir",            &unix_opendir },
	{ "openlog",            &unix_openlog },
	{ "pathconf",           &unix_pathconf },
	{ "pipe",               &unix_pipe },
	{ "poll",               &unix_poll },
#if HAVE_POSIX_FADVISE
	{ "posix_fadvise",      &unix_posix_fadvise },
#endif
#if HAVE_POSIX_FALLOCATE
	{ "posix_fallocate",    &unix_posix_fallocate },
#endif
	{ "posix_openpt",       &unix_posix_openpt },
	{ "posix_fopenpt",      &unix_posix_fopenpt },
	{ "pread",              &unix_pread },
	{ "ptsname",            &unix_ptsname },
	{ "pwrite",             &unix_pwrite },
	{ "raise",              &unix_raise },
	{ "read",               &unix_read },
	{ "readdir",            &unix_readdir },
	{ "readlink",           &unix_readlink },
#if HAVE_READLINKAT
	{ "readlinkat",         &unix_readlinkat },
#endif
	{ "recv",               &unix_recv },
	{ "recvfrom",           &unix_recvfrom },
	{ "recvfromto",         &unix_recvfromto },
	{ "regcomp",            &unix_regcomp },
	{ "regerror",           &unix_regerror },
	{ "regexec",            &unix_regexec },
	{ "regfree",            &unix_regfree },
	{ "rename",             &unix_rename },
#if HAVE_RENAMEAT
	{ "renameat",           &unix_renameat },
#endif
	{ "rewinddir",          &unix_rewinddir },
	{ "rmdir",              &unix_rmdir },
	{ "S_ISBLK",            &unix_S_ISBLK },
	{ "S_ISCHR",            &unix_S_ISCHR },
	{ "S_ISDIR",            &unix_S_ISDIR },
	{ "S_ISFIFO",           &unix_S_ISFIFO },
	{ "S_ISREG",            &unix_S_ISREG },
	{ "S_ISLNK",            &unix_S_ISLNK },
	{ "S_ISSOCK",           &unix_S_ISSOCK },
	{ "send",               &unix_send },
	{ "sendto",             &unix_sendto },
	{ "sendtofrom",         &unix_sendtofrom },
	{ "setegid",            &unix_setegid },
	{ "setenv",             &unix_setenv },
	{ "seteuid",            &unix_seteuid },
	{ "setgid",             &unix_setgid },
	{ "setgroups",          &unix_setgroups },
	{ "setlocale",          &unix_setlocale },
	{ "setlogmask",         &unix_setlogmask },
	{ "setpgid",            &unix_setpgid },
	{ "setrlimit",          &unix_setrlimit },
	{ "setsockopt",         &unix_setsockopt },
	{ "setsid",             &unix_setsid },
	{ "setuid",             &unix_setuid },
	{ "sigaction",          &unix_sigaction },
	{ "sigfillset",         &unix_sigfillset },
	{ "sigemptyset",        &unix_sigemptyset },
	{ "sigaddset",          &unix_sigaddset },
	{ "sigdelset",          &unix_sigdelset },
	{ "sigismember",        &unix_sigismember },
	{ "sigprocmask",        &unix_sigprocmask },
	{ "sigtimedwait",       &unix_sigtimedwait },
	{ "sigwait",            &unix_sigwait },
	{ "sleep",              &unix_sleep },
	{ "socket",             &unix_socket },
	{ "socketpair",         &unix_socketpair },
	{ "stat",               &unix_stat },
	{ "strerror",           &unix_strerror },
	{ "strsignal",          &unix_strsignal },
	{ "symlink",            &unix_symlink },
#if HAVE_SYMLINKAT
	{ "symlinkat",          &unix_symlinkat },
#endif
	{ "sysconf",            &unix_sysconf },
	{ "syslog",             &unix_syslog },
	{ "tcgetpgrp",          &unix_tcgetpgrp },
	{ "tcgetsid",           &unix_tcgetsid },
	{ "tcsetpgrp",          &unix_tcsetpgrp },
	{ "timegm",             &unix_timegm },
	{ "truncate",           &unix_truncate },
	{ "tzset",              &unix_tzset },
	{ "umask",              &unix_umask },
	{ "uname",              &unix_uname },
	{ "unlink",             &unix_unlink },
#if HAVE_UNLINKAT
	{ "unlinkat",           &unix_unlinkat },
#endif
	{ "unlockpt",           &unix_unlockpt },
	{ "unsetenv",           &unix_unsetenv },
	{ "wait",               &unix_wait },
	{ "waitpid",            &unix_waitpid },
	{ "write",              &unix_write },
	{ "xor",                &unix_xor },
	{ NULL,                 NULL }
}; /* unix_routines[] */

static const luaL_Reg unsafe_routines[] = {
	{ "calloc",       &unsafe_calloc },
	{ "fcntl",        &unsafe_fcntl },
#if HAVE_FMEMOPEN
	{ "fmemopen",     &unsafe_fmemopen },
#endif
	{ "free",         &unsafe_free },
	{ "getsockopt",   &unsafe_getsockopt },
	{ "ioctl",        &unsafe_ioctl },
	{ "malloc",       &unsafe_malloc },
	{ "memcpy",       &unsafe_memcpy },
	{ "memset",       &unsafe_memset },
	{ "mlock",        &unsafe_mlock },
	{ "mlockall",     &unsafe_mlockall },
	{ "mmap",         &unsafe_mmap },
	{ "munlock",      &unsafe_munlock },
	{ "munlockall",   &unsafe_munlockall },
	{ "munmap",       &unsafe_munmap },
	{ "realloc",      &unsafe_realloc },
	{ "reallocarray", &unsafe_reallocarray },
	{ "setsockopt",   &unsafe_setsockopt },
	{ "strlen",       &unsafe_strlen },
	{ "strnlen",      &unsafe_strnlen },
	{ NULL,         NULL }
}; /* unsafe_routines[] */

#define UNIX_CONST(x) { #x, x }

struct unix_const {
	char name[24];
	long long value;
}; /* struct unix_const */

static const struct unix_const const_af[] = {
	UNIX_CONST(AF_UNSPEC), UNIX_CONST(AF_UNIX), UNIX_CONST(AF_INET),
	UNIX_CONST(AF_INET6),
}; /* const_af[] */

static const struct unix_const const_sock[] = {
	UNIX_CONST(SOCK_DGRAM), UNIX_CONST(SOCK_STREAM),
#if defined SOCK_RAW
	UNIX_CONST(SOCK_RAW),
#endif
#if defined SOCK_SEQPACKET
	UNIX_CONST(SOCK_SEQPACKET),
#endif
#if defined SOCK_CLOEXEC
	UNIX_CONST(SOCK_CLOEXEC),
#endif
#if defined SOCK_NONBLOCK
	UNIX_CONST(SOCK_NONBLOCK),
#endif
#if defined SOCK_NOSIGPIPE
	UNIX_CONST(SOCK_NOSIGPIPE),
#endif
}; /* const_sock[] */

static const struct unix_const const_ipproto[] = {
	UNIX_CONST(IPPROTO_IP), UNIX_CONST(IPPROTO_IPV6),
	UNIX_CONST(IPPROTO_TCP), UNIX_CONST(IPPROTO_UDP),
	UNIX_CONST(IPPROTO_ICMP),
#if defined IPPRPTO_RAW
	UNIX_CONST(IPPROTO_RAW),
#endif
}; /* const_ipproto[] */

static const struct unix_const const_ip[] = {
#if defined IP_PKTINFO
	UNIX_CONST(IP_PKTINFO),
#endif
#if defined IP_RECVDSTADDR
	UNIX_CONST(IP_RECVDSTADDR),
#endif
#if defined IP_SENDSRCADDR
	UNIX_CONST(IP_SENDSRCADDR),
#endif
#if defined IP_TTL
	UNIX_CONST(IP_TTL),
#endif
}; /* const_ip[] */

static const struct unix_const const_ipv6[] = {
#if defined IPV6_PKTINFO
	UNIX_CONST(IPV6_PKTINFO),
#endif
#if defined IPV6_RECVPKTINFO
	UNIX_CONST(IPV6_RECVPKTINFO),
#endif
#if defined IPV6_V6ONLY
	UNIX_CONST(IPV6_V6ONLY),
#endif
}; /* const_ipv6[] */

static const struct unix_const const_ai[] = {
	UNIX_CONST(AI_PASSIVE), UNIX_CONST(AI_CANONNAME),
	UNIX_CONST(AI_NUMERICHOST), UNIX_CONST(AI_NUMERICSERV),
	UNIX_CONST(AI_ADDRCONFIG),
#if defined AI_V4MAPPED
	UNIX_CONST(AI_V4MAPPED),
#endif
#if defined AI_ALL
	UNIX_CONST(AI_ALL),
#endif
}; /* const_ai[] */

static const struct unix_const const_eai[] = {
	UNIX_CONST(EAI_AGAIN), UNIX_CONST(EAI_BADFLAGS), UNIX_CONST(EAI_FAIL),
	UNIX_CONST(EAI_FAMILY), UNIX_CONST(EAI_MEMORY),
	UNIX_CONST(EAI_NONAME), UNIX_CONST(EAI_SERVICE),
	UNIX_CONST(EAI_SOCKTYPE), UNIX_CONST(EAI_SYSTEM),
#if defined EAI_OVERFLOW
	UNIX_CONST(EAI_OVERFLOW),
#endif
}; /* const_eai[] */

static const struct unix_const const_mman[] = {
#if defined MAP_ANON
	UNIX_CONST(MAP_ANON),
#endif
#if defined MAP_ANONYMOUS
	UNIX_CONST(MAP_ANONYMOUS),
#endif
#if defined MAP_FILE
	UNIX_CONST(MAP_FILE),
#endif
	UNIX_CONST(MAP_FIXED),
	UNIX_CONST(MAP_PRIVATE),
	UNIX_CONST(MAP_SHARED),

	UNIX_CONST(MCL_CURRENT),
	UNIX_CONST(MCL_FUTURE),

	UNIX_CONST(PROT_EXEC),
	UNIX_CONST(PROT_NONE),
	UNIX_CONST(PROT_READ),
	UNIX_CONST(PROT_WRITE),
}; /* const_mman[] */

static const struct unix_const const_msg[] = {
#if defined MSG_EOR
	UNIX_CONST(MSG_EOR),
#endif
#if defined MSG_NOSIGNAL
	UNIX_CONST(MSG_NOSIGNAL),
#endif
#if defined MSG_DONTWAIT
	UNIX_CONST(MSG_DONTWAIT),
#endif
#if defined MSG_OOB
	UNIX_CONST(MSG_OOB),
#endif
#if defined MSG_PEEK
	UNIX_CONST(MSG_PEEK),
#endif
#if defined MSG_WAITALL
	UNIX_CONST(MSG_WAITALL),
#endif
}; /* const_msg[] */

static const struct unix_const const_ni[] = {
	UNIX_CONST(NI_NOFQDN),
	UNIX_CONST(NI_NUMERICHOST),
	UNIX_CONST(NI_NAMEREQD),
	UNIX_CONST(NI_NUMERICSERV),
#if defined NI_NUMERICSCOPE
	UNIX_CONST(NI_NUMERICSCOPE),
#endif
	UNIX_CONST(NI_DGRAM),
}; /* const_ni[] */

/* historical BSD constants */
static const struct unix_const const_param[] = {
#if defined MAXPATHLEN
	UNIX_CONST(MAXPATHLEN),
#endif
	{ "0", 0 }, /* in case empty (see entry in unix_const table) */
}; /* const_param[] */

static const struct unix_const const_poll[] = {
	UNIX_CONST(POLLERR), 
	UNIX_CONST(POLLHUP),
	UNIX_CONST(POLLIN),
	UNIX_CONST(POLLOUT),
	UNIX_CONST(POLLNVAL),
	UNIX_CONST(POLLPRI),
	UNIX_CONST(POLLRDBAND),
	UNIX_CONST(POLLRDNORM),
	UNIX_CONST(POLLWRBAND),
	UNIX_CONST(POLLWRNORM),
}; /* const_poll[] */

static const struct unix_const const_clock[] = {
	{ "CLOCK_MONOTONIC", U_CLOCK_MONOTONIC },
	{ "CLOCK_REALTIME",  U_CLOCK_REALTIME },
}; /* const_clock[] */

static const struct unix_const const_errno[] = {
	/* ISO C */
	UNIX_CONST(EDOM), UNIX_CONST(EILSEQ), UNIX_CONST(ERANGE),

	/* POSIX */
#if defined E2BIG
	UNIX_CONST(E2BIG),
#endif
#if defined EACCES
	UNIX_CONST(EACCES),
#endif
#if defined EADDRINUSE
	UNIX_CONST(EADDRINUSE),
#endif
#if defined EADDRNOTAVAIL
	UNIX_CONST(EADDRNOTAVAIL),
#endif
#if defined EAFNOSUPPORT
	UNIX_CONST(EAFNOSUPPORT),
#endif
#if defined EAGAIN
	UNIX_CONST(EAGAIN),
#endif
#if defined EALREADY
	UNIX_CONST(EALREADY),
#endif
#if defined EBADF
	UNIX_CONST(EBADF),
#endif
#if defined EBADMSG
	UNIX_CONST(EBADMSG),
#endif
#if defined EBUSY
	UNIX_CONST(EBUSY),
#endif
#if defined ECANCELED
	UNIX_CONST(ECANCELED),
#endif
#if defined ECHILD
	UNIX_CONST(ECHILD),
#endif
#if defined ECONNABORTED
	UNIX_CONST(ECONNABORTED),
#endif
#if defined ECONNREFUSED
	UNIX_CONST(ECONNREFUSED),
#endif
#if defined ECONNRESET
	UNIX_CONST(ECONNRESET),
#endif
#if defined EDEADLK
	UNIX_CONST(EDEADLK),
#endif
#if defined EDESTADDRREQ
	UNIX_CONST(EDESTADDRREQ),
#endif
#if defined EDQUOT
	UNIX_CONST(EDQUOT),
#endif
#if defined EEXIST
	UNIX_CONST(EEXIST),
#endif
#if defined EFAULT
	UNIX_CONST(EFAULT),
#endif
#if defined EFBIG
	UNIX_CONST(EFBIG),
#endif
#if defined EHOSTUNREACH
	UNIX_CONST(EHOSTUNREACH),
#endif
#if defined EIDRM
	UNIX_CONST(EIDRM),
#endif
#if defined EINPROGRESS
	UNIX_CONST(EINPROGRESS),
#endif
#if defined EINTR
	UNIX_CONST(EINTR),
#endif
#if defined EINVAL
	UNIX_CONST(EINVAL),
#endif
#if defined EIO
	UNIX_CONST(EIO),
#endif
#if defined EISCONN
	UNIX_CONST(EISCONN),
#endif
#if defined EISDIR
	UNIX_CONST(EISDIR),
#endif
#if defined ELOOP
	UNIX_CONST(ELOOP),
#endif
#if defined EMFILE
	UNIX_CONST(EMFILE),
#endif
#if defined EMLINK
	UNIX_CONST(EMLINK),
#endif
#if defined EMSGSIZE
	UNIX_CONST(EMSGSIZE),
#endif
#if defined EMULTIHOP
	UNIX_CONST(EMULTIHOP),
#endif
#if defined ENAMETOOLONG
	UNIX_CONST(ENAMETOOLONG),
#endif
#if defined ENETDOWN
	UNIX_CONST(ENETDOWN),
#endif
#if defined ENETRESET
	UNIX_CONST(ENETRESET),
#endif
#if defined ENETUNREACH
	UNIX_CONST(ENETUNREACH),
#endif
#if defined ENFILE
	UNIX_CONST(ENFILE),
#endif
#if defined ENOBUFS
	UNIX_CONST(ENOBUFS),
#endif
#if defined ENODATA
	UNIX_CONST(ENODATA),
#endif
#if defined ENODEV
	UNIX_CONST(ENODEV),
#endif
#if defined ENOENT
	UNIX_CONST(ENOENT),
#endif
#if defined ENOEXEC
	UNIX_CONST(ENOEXEC),
#endif
#if defined ENOLCK
	UNIX_CONST(ENOLCK),
#endif
#if defined ENOLINK
	UNIX_CONST(ENOLINK),
#endif
#if defined ENOMEM
	UNIX_CONST(ENOMEM),
#endif
#if defined ENOMSG
	UNIX_CONST(ENOMSG),
#endif
#if defined ENOPROTOOPT
	UNIX_CONST(ENOPROTOOPT),
#endif
#if defined ENOSPC
	UNIX_CONST(ENOSPC),
#endif
#if defined ENOSR
	UNIX_CONST(ENOSR),
#endif
#if defined ENOSTR
	UNIX_CONST(ENOSTR),
#endif
#if defined ENOSYS
	UNIX_CONST(ENOSYS),
#endif
#if defined ENOTCONN
	UNIX_CONST(ENOTCONN),
#endif
#if defined ENOTDIR
	UNIX_CONST(ENOTDIR),
#endif
#if defined ENOTEMPTY
	UNIX_CONST(ENOTEMPTY),
#endif
#if defined ENOTRECOVERABLE
	UNIX_CONST(ENOTRECOVERABLE),
#endif
#if defined ENOTSOCK
	UNIX_CONST(ENOTSOCK),
#endif
#if defined ENOTSUP
	UNIX_CONST(ENOTSUP),
#endif
#if defined ENOTTY
	UNIX_CONST(ENOTTY),
#endif
#if defined ENXIO
	UNIX_CONST(ENXIO),
#endif
#if defined EOPNOTSUPP
	UNIX_CONST(EOPNOTSUPP),
#endif
#if defined EOVERFLOW
	UNIX_CONST(EOVERFLOW),
#endif
#if defined EOWNERDEAD
	UNIX_CONST(EOWNERDEAD),
#endif
#if defined EPERM
	UNIX_CONST(EPERM),
#endif
#if defined EPIPE
	UNIX_CONST(EPIPE),
#endif
#if defined EPROTO
	UNIX_CONST(EPROTO),
#endif
#if defined EPROTONOSUPPORT
	UNIX_CONST(EPROTONOSUPPORT),
#endif
#if defined EPROTOTYPE
	UNIX_CONST(EPROTOTYPE),
#endif
#if defined EROFS
	UNIX_CONST(EROFS),
#endif
#if defined ESPIPE
	UNIX_CONST(ESPIPE),
#endif
#if defined ESRCH
	UNIX_CONST(ESRCH),
#endif
#if defined ESTALE
	UNIX_CONST(ESTALE),
#endif
#if defined ETIME
	UNIX_CONST(ETIME),
#endif
#if defined ETIMEDOUT
	UNIX_CONST(ETIMEDOUT),
#endif
#if defined ETXTBSY
	UNIX_CONST(ETXTBSY),
#endif
#if defined EWOULDBLOCK
	UNIX_CONST(EWOULDBLOCK),
#endif
#if defined EXDEV
	UNIX_CONST(EXDEV),
#endif
}; /* const_errno[] */

static const struct unix_const const_fnmatch[] = {
	UNIX_CONST(FNM_NOMATCH),
	UNIX_CONST(FNM_PATHNAME),
	UNIX_CONST(FNM_PERIOD),
	UNIX_CONST(FNM_NOESCAPE),
}; /* const_fnmatch[] */

static const struct unix_const const_iff[] = {
#if defined IFF_UP
	UNIX_CONST(IFF_UP),
#endif
#if defined IFF_BROADCAST
	UNIX_CONST(IFF_BROADCAST),
#endif
#if defined IFF_DEBUG
	UNIX_CONST(IFF_DEBUG),
#endif
#if defined IFF_LOOPBACK
	UNIX_CONST(IFF_LOOPBACK),
#endif
#if defined IFF_POINTOPOINT
	UNIX_CONST(IFF_POINTOPOINT),
#endif
#if defined IFF_NOTRAILERS
	UNIX_CONST(IFF_NOTRAILERS),
#endif
#if defined IFF_RUNNING
	UNIX_CONST(IFF_RUNNING),
#endif
#if defined IFF_NOARP
	UNIX_CONST(IFF_NOARP),
#endif
#if defined IFF_PROMISC
	UNIX_CONST(IFF_PROMISC),
#endif
#if defined IFF_SIMPLEX
	UNIX_CONST(IFF_SIMPLEX),
#endif
#if defined IFF_MULTICAST
	UNIX_CONST(IFF_MULTICAST),
#endif
}; /* const_iff[] */

static const struct unix_const const_wait[] = {
#if defined WCONTINUED
	UNIX_CONST(WCONTINUED),
#endif
	UNIX_CONST(WNOHANG),
	UNIX_CONST(WUNTRACED),
#if defined WSTOPPED
	UNIX_CONST(WSTOPPED),
#endif
}; /* const_wait[] */

static const struct unix_const const_regex[] = {
	UNIX_CONST(REG_EXTENDED),
	UNIX_CONST(REG_ICASE),
	UNIX_CONST(REG_NOSUB),
	UNIX_CONST(REG_NEWLINE),

	UNIX_CONST(REG_NOTBOL),
	UNIX_CONST(REG_NOTEOL),

	UNIX_CONST(REG_BADBR),
	UNIX_CONST(REG_BADPAT),
	UNIX_CONST(REG_BADRPT),
	UNIX_CONST(REG_EBRACE),
	UNIX_CONST(REG_EBRACK),
	UNIX_CONST(REG_ECOLLATE),
	UNIX_CONST(REG_ECTYPE),
	UNIX_CONST(REG_EESCAPE),
	UNIX_CONST(REG_EPAREN),
	UNIX_CONST(REG_ERANGE),
	UNIX_CONST(REG_ESPACE),
	UNIX_CONST(REG_ESUBREG),
	UNIX_CONST(REG_NOMATCH),
}; /* const_regex[] */

static const struct unix_const const_resource[] = {
	UNIX_CONST(RLIMIT_CORE), UNIX_CONST(RLIMIT_CPU),
	UNIX_CONST(RLIMIT_DATA), UNIX_CONST(RLIMIT_FSIZE),
	UNIX_CONST(RLIMIT_NOFILE), UNIX_CONST(RLIMIT_STACK),
#if HAVE_DECL_RLIMIT_AS
	UNIX_CONST(RLIMIT_AS),
#endif

	UNIX_CONST(RUSAGE_CHILDREN), UNIX_CONST(RUSAGE_SELF),
}; /* const_resource[] */

static const struct unix_const const_signal[] = {
	UNIX_CONST(SIGABRT), UNIX_CONST(SIGALRM), UNIX_CONST(SIGBUS),
	UNIX_CONST(SIGCHLD), UNIX_CONST(SIGCONT), UNIX_CONST(SIGFPE),
	UNIX_CONST(SIGHUP), UNIX_CONST(SIGILL), UNIX_CONST(SIGINT),
	UNIX_CONST(SIGKILL), UNIX_CONST(SIGPIPE), UNIX_CONST(SIGQUIT),
	UNIX_CONST(SIGSEGV), UNIX_CONST(SIGSTOP), UNIX_CONST(SIGTERM),
	UNIX_CONST(SIGTSTP), UNIX_CONST(SIGTTIN), UNIX_CONST(SIGTTOU),
	UNIX_CONST(SIGUSR1), UNIX_CONST(SIGUSR2), UNIX_CONST(SIGTRAP),
	UNIX_CONST(SIGURG), UNIX_CONST(SIGXCPU), UNIX_CONST(SIGXFSZ),
	UNIX_CONST(NSIG),

	UNIX_CONST(SIG_BLOCK), UNIX_CONST(SIG_UNBLOCK), UNIX_CONST(SIG_SETMASK),

	UNIX_CONST(SA_NOCLDSTOP), UNIX_CONST(SA_ONSTACK), UNIX_CONST(SA_RESETHAND),
	UNIX_CONST(SA_RESTART), UNIX_CONST(SA_NOCLDWAIT), UNIX_CONST(SA_NODEFER),
#if defined SA_SIGINFO
	UNIX_CONST(SA_SIGINFO),
#endif
}; /* const_signal[] */

static const struct {
	char name[24];
	u_sighandler_t *func;
} unix_sighandler[] = {
	{ "SIG_DFL", (u_sighandler_t *)SIG_DFL },
	{ "SIG_ERR", (u_sighandler_t *)SIG_ERR },
	{ "SIG_IGN", (u_sighandler_t *)SIG_IGN },
}; /* unix_sighandler[] */

static const struct unix_const const_syslog[] = {
	/* severity levels */
	UNIX_CONST(LOG_EMERG),
	UNIX_CONST(LOG_ALERT),
	UNIX_CONST(LOG_CRIT),
	UNIX_CONST(LOG_ERR),
	UNIX_CONST(LOG_WARNING),
	UNIX_CONST(LOG_NOTICE),
	UNIX_CONST(LOG_INFO),
	UNIX_CONST(LOG_DEBUG),

	/* facilities */
	UNIX_CONST(LOG_USER),
	UNIX_CONST(LOG_LOCAL0),
	UNIX_CONST(LOG_LOCAL1),
	UNIX_CONST(LOG_LOCAL2),
	UNIX_CONST(LOG_LOCAL3),
	UNIX_CONST(LOG_LOCAL4),
	UNIX_CONST(LOG_LOCAL5),
	UNIX_CONST(LOG_LOCAL6),
	UNIX_CONST(LOG_LOCAL7),
#if defined LOG_AUDIT
	UNIX_CONST(LOG_AUDIT),
#endif
#if defined LOG_AUTH
	UNIX_CONST(LOG_AUTH),
#endif
#if defined LOG_AUTHPRIV
	UNIX_CONST(LOG_AUTHPRIV),
#endif
#if defined LOG_CRON
	UNIX_CONST(LOG_CRON),
#endif
#if defined LOG_DAEMON
	UNIX_CONST(LOG_DAEMON),
#endif
#if defined LOG_FTP
	UNIX_CONST(LOG_FTP),
#endif
#if defined LOG_LPR
	UNIX_CONST(LOG_LPR),
#endif
#if defined LOG_MAIL
	UNIX_CONST(LOG_MAIL),
#endif
#if defined LOG_NEWS
	UNIX_CONST(LOG_NEWS),
#endif
#if defined LOG_UUCP
	UNIX_CONST(LOG_UUCP),
#endif

	/* options */
	UNIX_CONST(LOG_PID),
	UNIX_CONST(LOG_CONS),
	UNIX_CONST(LOG_NDELAY),
	UNIX_CONST(LOG_ODELAY),
	UNIX_CONST(LOG_NOWAIT),
#if defined LOG_PERROR
	UNIX_CONST(LOG_PERROR),
#endif
}; /* const_syslog[] */

static const struct unix_const const_fcntl[] = {
#if defined AT_EACCESS
	UNIX_CONST(AT_EACCESS),
#endif
#if defined AT_FDCWD
	UNIX_CONST(AT_FDCWD),
#endif
#if defined AT_REMOVEDIR
	UNIX_CONST(AT_REMOVEDIR),
#endif
#if defined AT_SYMLINK_FOLLOW
	UNIX_CONST(AT_SYMLINK_FOLLOW),
#endif
#if defined AT_SYMLINK_NOFOLLOW
	UNIX_CONST(AT_SYMLINK_NOFOLLOW),
#endif

	UNIX_CONST(F_DUPFD),
#if defined F_DUPFD_CLOEXEC
	UNIX_CONST(F_DUPFD_CLOEXEC),
#endif
#if defined F_DUP2FD
	UNIX_CONST(F_DUP2FD),
#endif
#if defined F_DUP2FD_CLOEXEC
	UNIX_CONST(F_DUP2FD_CLOEXEC),
#endif
	UNIX_CONST(F_GETFD), UNIX_CONST(F_SETFD),
	UNIX_CONST(F_GETFL), UNIX_CONST(F_SETFL),
	UNIX_CONST(F_GETLK), UNIX_CONST(F_SETLK), UNIX_CONST(F_SETLKW),
	UNIX_CONST(F_GETOWN), UNIX_CONST(F_SETOWN),
#if defined F_GETPATH
	UNIX_CONST(F_GETPATH),
#endif
#if defined F_CLOSEM
	UNIX_CONST(F_CLOSEM),
#endif
#if defined F_MAXFD
	UNIX_CONST(F_MAXFD),
#endif
	UNIX_CONST(FD_CLOEXEC),

	UNIX_CONST(F_RDLCK), UNIX_CONST(F_WRLCK), UNIX_CONST(F_UNLCK),

	UNIX_CONST(SEEK_SET), UNIX_CONST(SEEK_CUR), UNIX_CONST(SEEK_END),

	UNIX_CONST(O_ACCMODE),
	{ "O_CLOEXEC", U_CLOEXEC }, /* not natively supported on NetBSD 5.1 */
	UNIX_CONST(O_CREAT),
#if defined O_DIRECTORY
	UNIX_CONST(O_DIRECTORY),
#endif
	UNIX_CONST(O_EXCL),
	UNIX_CONST(O_NOCTTY),
	UNIX_CONST(O_NOFOLLOW),
	UNIX_CONST(O_TRUNC),
#if defined O_TMPFILE
	UNIX_CONST(O_TMPFILE),
#endif

	UNIX_CONST(O_APPEND),
	UNIX_CONST(O_NONBLOCK),
#if defined O_NDELAY
	UNIX_CONST(O_NDELAY),
#endif
#if defined O_SYNC
	UNIX_CONST(O_SYNC),
#endif
#if defined O_DSYNC
	UNIX_CONST(O_DSYNC),
#endif
#if defined O_RSYNC
	UNIX_CONST(O_RSYNC),
#endif

	UNIX_CONST(O_RDONLY), UNIX_CONST(O_RDWR), UNIX_CONST(O_WRONLY),
#if defined O_EXEC
	UNIX_CONST(O_EXEC),
#endif
#if defined O_SEARCH
	UNIX_CONST(O_SEARCH),
#endif

#if defined POSIX_FADV_DONTNEED
	UNIX_CONST(POSIX_FADV_DONTNEED),
#endif
#if defined POSIX_FADV_NOREUSE
	UNIX_CONST(POSIX_FADV_NOREUSE),
#endif
#if defined POSIX_FADV_NORMAL
	UNIX_CONST(POSIX_FADV_NORMAL),
#endif
#if defined POSIX_FADV_RANDOM
	UNIX_CONST(POSIX_FADV_RANDOM),
#endif
#if defined POSIX_FADV_SEQUENTIAL
	UNIX_CONST(POSIX_FADV_SEQUENTIAL),
#endif
#if defined POSIX_FADV_WILLNEED
	UNIX_CONST(POSIX_FADV_WILLNEED),
#endif
}; /* const_fcntl[] */

static const struct unix_const const_ioctl[] = {
#if defined SIOCATMARK
	UNIX_CONST(SIOCATMARK),
#endif
#if defined TIOCGSIZE
	UNIX_CONST(TIOCGSIZE),
#endif
#if defined TIOCSSIZE
	UNIX_CONST(TIOCSSIZE),
#endif
#if defined TIOCGWINSZ
	UNIX_CONST(TIOCGWINSZ),
#endif
#if defined TIOCSWINSZ
	UNIX_CONST(TIOCSWINSZ),
#endif
#if defined TIOCNOTTY
	UNIX_CONST(TIOCNOTTY),
#endif
#if defined TIOCSCTTY
	UNIX_CONST(TIOCSCTTY),
#endif
}; /* const_ioctl[] */

static const struct unix_const const_locale[] = {
	UNIX_CONST(LC_ALL), UNIX_CONST(LC_COLLATE), UNIX_CONST(LC_CTYPE),
	UNIX_CONST(LC_MONETARY), UNIX_CONST(LC_NUMERIC), UNIX_CONST(LC_TIME),
}; /* const_locale[] */

/* miscellaneous constants */
static const struct unix_const const_unistd[] = {
	UNIX_CONST(STDIN_FILENO), UNIX_CONST(STDOUT_FILENO),
	UNIX_CONST(STDERR_FILENO),

	UNIX_CONST(F_ULOCK), UNIX_CONST(F_LOCK),
	UNIX_CONST(F_TLOCK), UNIX_CONST(F_TEST),

	UNIX_CONST(_PC_FILESIZEBITS),
	UNIX_CONST(_PC_NAME_MAX),
	UNIX_CONST(_PC_PATH_MAX),
	UNIX_CONST(_PC_PIPE_BUF),

	UNIX_CONST(_SC_LINE_MAX),
	UNIX_CONST(_SC_OPEN_MAX),
	UNIX_CONST(_SC_PAGE_SIZE), UNIX_CONST(_SC_PAGESIZE),
}; /* const_unistd[] */

static const struct {
	const struct unix_const *table;
	size_t size;
} unix_const[] = {
	{ const_af,       countof(const_af) },
	{ const_sock,     countof(const_sock) },
	{ const_ipproto,  countof(const_ipproto) },
	{ const_ip,       countof(const_ip) },
	{ const_ipv6,     countof(const_ipv6) },
	{ const_ai,       countof(const_ai) },
	{ const_eai,      countof(const_eai) },
	{ const_mman,     countof(const_mman) },
	{ const_msg,      countof(const_msg) },
	{ const_ni,       countof(const_ni) },
	{ const_param,    countof(const_param) - 1 },
	{ const_poll,     countof(const_poll) },
	{ const_clock,    countof(const_clock) },
	{ const_errno,    countof(const_errno) },
	{ const_fnmatch,  countof(const_fnmatch) },
	{ const_iff,      countof(const_iff) },
	{ const_wait,     countof(const_wait) },
	{ const_signal,   countof(const_signal) },
	{ const_syslog,   countof(const_syslog) },
	{ const_regex,    countof(const_regex) },
	{ const_resource, countof(const_resource) },
	{ const_fcntl,    countof(const_fcntl) },
	{ const_ioctl,    countof(const_ioctl) },
	{ const_locale,   countof(const_locale) },
	{ const_unistd,   countof(const_unistd) },
}; /* unix_const[] */


int luaopen_unix(lua_State *L) {
	unixL_State *U;
	size_t i, j;

	/*
	 * unixL_State context upvalue
	 */
	U = unixL_loadstate(L);

	/*
	 * add struct ifaddrs* class
	 */
	lua_pushvalue(L, -1);
	unixL_newmetatable(L, "struct ifaddrs*", ifs_methods, ifs_metamethods, 1);
	lua_pop(L, 1);

	/*
	 * add struct addrinfo* class
	 */
	lua_pushvalue(L, -1);
	unixL_newmetatable(L, "struct addrinfo*", gai_methods, gai_metamethods, 1);
	lua_pop(L, 1);

	/*
	 * add DIR* class
	 */
	lua_pushvalue(L, -1);
	unixL_newmetatable(L, "DIR*", dir_methods, dir_metamethods, 1);
	lua_pop(L, 1);

	/*
	 * add regex_t class
	 */
	lua_pushvalue(L, -1);
	unixL_newmetatable(L, "regex_t", NULL, regex_metamethods, 1);
	lua_pop(L, 1);

	/*
	 * add sigset_t class
	 */
	lua_pushvalue(L, -1);
	unixL_newmetatable(L, "sigset_t", sigset_methods, sigset_metamethods, 1);
	lua_pop(L, 1);

	/*
	 * add sighandler_t class
	 *
	 * See note at typedef of u_sighandler_t.
	 */
	lua_pushvalue(L, -1);
	unixL_newmetatable(L, "sighandler_t*", sighandler_methods, sighandler_metamethods, 1);
	lua_pop(L, 1);

	/*
	 * add struct sockaddr class
	 */
	lua_pushvalue(L, -1);
	unixL_newmetatable(L, "struct sockaddr", NULL, sa_metamethods, 1);
	lua_pop(L, 1);

	/*
	 * insert unix routines into module table with unixL_State as upvalue
	 */
	luaL_newlibtable(L, unix_routines);
	lua_pushvalue(L, -2);
	luaL_setfuncs(L, unix_routines, 1);

	/*
	 * create environ table
	 */
	lua_createtable(L, 0, 0);
	luaL_newlibtable(L, env_metamethods);
	lua_pushvalue(L, -4); /* unixL_State */
	luaL_setfuncs(L, env_metamethods, 1);
	lua_setmetatable(L, -2);
	lua_setfield(L, -2, "environ");

	/*
	 * insert integer constants
	 */
	for (i = 0; i < countof(unix_const); i++) {
		const struct unix_const *const table = unix_const[i].table;
		const size_t size = unix_const[i].size;

		for (j = 0; j < size; j++) {
			/* throw error if our macro improperly stringified an identifier */
			if (*table[j].name >= '0' && *table[j].name <= '9')
				return luaL_error(L, "%s: bogus constant identifier string conversion (near %s)", table[j].name, (j == 0)? "?" : table[j - 1].name);

			unixL_pushinteger(L, table[j].value);
			lua_setfield(L, -2, table[j].name);
		}
	}

	/*
	 * special RLIM values
	 */
	lua_pushnumber(L, RL_RLIM_INFINITY);
	lua_setfield(L, -2, "RLIM_INFINITY");
	lua_pushnumber(L, RL_RLIM_SAVED_CUR);
	lua_setfield(L, -2, "RLIM_SAVED_CUR");
	lua_pushnumber(L, RL_RLIM_SAVED_MAX);
	lua_setfield(L, -2, "RLIM_SAVED_MAX");

	/*
	 * insert signal handlers
	 */
	for (i = 0; i < countof(unix_sighandler); i++) {
		/* See note at typeof of u_sighandler_t */
		*(u_sighandler_t **)lua_newuserdata(L, sizeof unix_sighandler[i].func) = unix_sighandler[i].func;
		luaL_setmetatable(L, "sighandler_t*");
		lua_setfield(L, -2, unix_sighandler[i].name);
	}

	/*
	 * add __index and __newindex metamethods to unix module table
	 */
	lua_createtable(L, 0, 2);
	lua_pushvalue(L, -3);
	lua_pushcclosure(L, &unix__index, 1);
	lua_setfield(L, -2, "__index");
	lua_pushvalue(L, -3);
	lua_pushcclosure(L, &unix__newindex, 1);
	lua_setfield(L, -2, "__newindex");
	lua_setmetatable(L, -2);

	return 1;
} /* luaopen_unix() */


int luaopen_unix_unsafe(lua_State *L) {
	unixL_State *U;

	/*
	 * unixL_State context upvalue
	 */
	U = unixL_loadstate(L);

	/*
	 * insert unix routines into module table with unixL_State as upvalue
	 */
	luaL_newlibtable(L, unsafe_routines);
	lua_pushvalue(L, -2);
	luaL_setfuncs(L, unsafe_routines, 1);

	return 1;
} /* luaopen_unix_unsafe() */
