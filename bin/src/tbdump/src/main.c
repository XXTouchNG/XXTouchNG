/*
 * Copyright (c) 2016 Siguza
 */

#include <errno.h>              // errno
#include <stdbool.h>            // bool, true, false
#include <stdio.h>              // FILE, fputs, fprintf, stderr
#include <stdlib.h>             // exit
#include <string.h>             // strcmp, strerror

#include "dylib.h"              // dylib_t, initDylib, cleanupDylib
#include "util.h"               // openStream

#define VERSION         "0.2.0"
#define BUGTRACKER_URL  "https://github.com/Siguza/tbdump/issues"

static void printUsage(const char *self)
{
    fprintf(stderr, "Usage:\n"
                    "    %s [-f] dylib\n"
                    "    %s -r [-f] folder\n"
                    "\n"
                    "Description:\n"
                    "    Create text-based stub libraries (.tbd files) from dylibs or frameworks.\n"
                    "    In default mode, output is written to stdout.\n"
                    "    Use \"-\" to read from stdin.\n"
                    "\n"
                    "Options:\n"
                    "    -f  Force parsing of all files and ignore all I/O and format errors.\n"
                    "    -r  \"Recursive mode\": Recurse into a directory, parsing all files whose\n"
                    "        names end in \".dylib\" or which have no suffix at all.\n"
                    "        Rather than writing to stdout, rebuild the source directory tree in the\n"
                    "        current directory, with .tbd files replacing dylibs and frameworks.\n"
                    "\n"
                    "Return values:\n"
                    "    0   Success\n"
                    "    1   Generic error\n"
                    "    2   Invalid argument\n"
                    "    3   Memory error\n"
                    "    4   File I/O error\n"
                    "    5   Data format error\n"
                    , self, self);
}

static const char* retvalStr(int retval)
{
    switch(retval)
    {
        case RETVAL_MAGIC:              return "Unrecognized magic value.";
        case RETVAL_NO_DYLIB:           return "File is not a dylib.";
        case RETVAL_PLATFORM_MISSING:   return "File does not contain any LC_VERSION_MIN_* load command.";
        case RETVAL_PLATFORM_MULTI:     return "File contains multiple LC_VERSION_MIN_* load commands.";
        case RETVAL_PLATFORM_MISMATCH:  return "Attempted to merge multiple files for differing platforms.";
        case RETVAL_SYMTAB_MISSING:     return "File contains no symbols.";
        case RETVAL_ID_MISSING:         return "File contains no install name.";
    }
    return "Internal error.";
}

int main(int argc, const char** argv)
{
    bool recursive = false,
         force = false;
    int off = 1;

    for(; off < argc; ++off)
    {
        if(argv[off][0] != '-')
        {
            break;
        }
        else if(strcmp(argv[off], "-f") == 0)
        {
            force = true;
        }
        else if(strcmp(argv[off], "-r") == 0)
        {
            recursive = true;
        }
        else
        {
            fprintf(stderr, "[!] Unrecognized option: %s\n\n", argv[off]);
            printUsage(argv[0]);
            return 2;
        }
    }
    if(argc - off != 1)
    {
        if(argc > 1)
        {
            fprintf(stderr, "[!] Too %s arguments.\n\n", argc - off < 2 ? "few" : "many");
        }
        else
        {
            fprintf(stderr, "tbdump version " VERSION
#ifdef TIMESTAMP
#define xstr(a) str(a)
#define str(a) #a
            ", compiled on " xstr(TIMESTAMP)
#undef xstr
#undef str
#endif
             "\n\n");
        }
        printUsage(argv[0]);
        return 2;
    }

    dylib_t dylib;
    if(recursive)
    {
        // TODO
    }
    else
    {
        initDylib(&dylib);
        FILE *in = openStream(argv[off]);
        if(in == NULL)
        {
            if(!force)
            {
                fprintf(stderr, "[!] Failed to open \"%s\" for reading.\n", argv[off]);
                return 4;
            }
        }
        else
        {
            int ret;
            switch(ret = parseDylib(in, &dylib))
            {
                case RETVAL_SUCCESS:
                    printDylib(stdout, &dylib);
                    break;
                case RETVAL_MEM:
                    fputs("[!] Memory allocation failure.\n", stderr);
                    return 3;
                case RETVAL_IO:
                    fprintf(stderr, "[!] Error reading from %s: %s\n", argv[off],
                            ferror(in) != 0 ? strerror(errno) :
                            feof(in)   != 0 ? "Hit end of file." : "Internal error.");
                    if(!force)
                    {
                        return 4;
                    }
                    break;
                case RETVAL_MAGIC:
                case RETVAL_NO_DYLIB:
                case RETVAL_PLATFORM_MISSING:
                case RETVAL_PLATFORM_MULTI:
                case RETVAL_PLATFORM_MISMATCH:
                case RETVAL_SYMTAB_MISSING:
                    fprintf(stderr, "[!] Data format error while parsing %s: %s\n", argv[off], retvalStr(ret));
                    if(!force)
                    {
                        return 5;
                    }
                    break;
                default:
                    fputs("[!] Internal error: Illegal retval.\n"
                          "[!] Please report this at " BUGTRACKER_URL "\n", stderr);
                    return 1;
            }
            cleanupDylib(&dylib);
            closeStream(in);
        }
    }

    return 0;
}
