#ifndef UNIX_GETOPT_C
#define UNIX_GETOPT_C

#include <stdarg.h> /* va_list va_start va_end */
#include <stdio.h>  /* flockfile(3) funlockfile(3) vfprintf(3) */
#include <string.h>


#define U_GETOPT_R_INITIALIZER { NULL, 1, 1, 0, 0, NULL }
#define U_GETOPT_R_INIT(k) do { \
	*k = (struct u_getopt_r)U_GETOPT_R_INITIALIZER; \
} while (0)

struct u_getopt_r {
	char *optarg;
	int opterr, optind, optopt;
	unsigned pc;
	char *cp;
};

static const char *
getopt_progname(int argc, char *const argv[], struct u_getopt_r *K)
{
	(void)K;
	return (argc > 0 && argv[0])? argv[0] : "";
}

static void
getopt_err(int argc, char *const argv[], const char *shortopts, struct u_getopt_r *K, const char *fmt, ...)
{
	va_list ap;

	if (*shortopts == ':' || !K->opterr)
		return;

	flockfile(stderr);
	(void)fprintf(stderr, "%s: ", getopt_progname(argc, argv, K));
	va_start(ap, fmt);
	(void)vfprintf(stderr, fmt, ap);
	va_end(ap);
	funlockfile(stderr);

	return;
}

#define GETOPT_ENTER                                                    \
	do {                                                            \
	enum { pc0 = __LINE__ };                                        \
	switch (pc0 + K->pc) {                                          \
	case __LINE__: (void)0

#define GETOPT_SAVE_AND_DO(do_statement)                                \
	do {                                                            \
		K->pc = __LINE__ - pc0;                                 \
		do_statement;                                           \
		case __LINE__: (void)0;                                 \
	} while (0)

#define GETOPT_YIELD(rv)                                                \
	GETOPT_SAVE_AND_DO(return (rv))

#define GETOPT_LEAVE                                                    \
	GETOPT_SAVE_AND_DO(break);                                      \
	}                                                               \
	} while (0)

static int
u_getopt_r(int argc, char *const argv[], const char *shortopts, struct u_getopt_r *K)
{
	K->optarg = NULL;
	K->optopt = 0;

	GETOPT_ENTER;

	while (K->optind < argc) {
		K->cp = argv[K->optind];

		if (!K->cp || *(K->cp) != '-' || !strcmp(K->cp, "-")) {
			break;
		} else if (!strcmp(K->cp, "--")) {
			K->optind++;
			break;
		}

		for (;;) {
			char *shortopt;

			if (!(K->optopt = *++K->cp)) {
				K->optind++;
				break;
			} else if (!(shortopt = strchr(shortopts, K->optopt))) {
				getopt_err(argc, argv, shortopts, K, "illegal option -- %c\n", K->optopt);
				GETOPT_YIELD('?');
			} else if (shortopt[1] != ':') {
				GETOPT_YIELD(K->optopt);
			} else if (K->cp[1]) {
				K->optarg = &K->cp[1];
				K->optind++;
				GETOPT_YIELD(K->optopt);
				break;
			} else if (K->optind + 1 < argc) {
				K->optarg = argv[K->optind + 1];
				K->optind += 2;
				GETOPT_YIELD(K->optopt);
				break;
			} else {
				getopt_err(argc, argv, shortopts, K, "option requires an argument -- %c\n", K->optopt);
				K->optind++;
				GETOPT_YIELD((*shortopts == ':')? ':' : '?');
				break;
			}
		}
	}

	GETOPT_LEAVE;

	return -1;
}

#endif /* UNIX_GETOPT_C */
