/*
 * Copyright (c) 2016 Siguza
 */

#include <stdbool.h>            // bool, false
#include <stdio.h>              // FILE, fopen, fprintf, stdin
#include <string.h>             // strlen, strncmp

#include "util.h"

FILE* openStream(const char *path)
{
    if(strcmp(path, "-") == 0)
    {
        return stdin;
    }
    return fopen(path, "r");
}

void closeStream(FILE *f)
{
    if(f != stdin)
    {
        fclose(f);
    }
}

int printStr(FILE *out, const char *str)
{
    for(size_t i = 0, len = strlen(str); i < len; ++i)
    {
        if(!(
            (str[i] >= '.' && str[i] <= '9') ||
            (str[i] >= 'A' && str[i] <= 'Z') ||
            (str[i] >= 'a' && str[i] <= 'z') ||
             str[i] == '_' || str[i] == '-'
        ))
        {
            return fprintf(out, "'%s'", str);
        }
    }
    return fprintf(out, "%s", str);
}

bool startsWith(const char *str, const char *pre)
{
    size_t max = strlen(pre);
    return strlen(str) < max ? false : strncmp(str, pre, max) == 0;
}
