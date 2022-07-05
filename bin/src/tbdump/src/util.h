/*
 * Copyright (c) 2016 Siguza
 */

#ifndef UTIL_H
#define UTIL_H

#include <stdbool.h>            // bool
#include <stdio.h>              // FILE

FILE* openStream(const char *path);

void closeStream(FILE *f);

int printStr(FILE *out, const char *str);

bool startsWith(const char *str, const char *pre);

#endif
