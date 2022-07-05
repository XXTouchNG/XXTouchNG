/*
 * Copyright (c) 2016 Siguza
 */

#ifndef PLATFORM_H
#define PLATFORM_H
#include <mach-o/loader.h>

typedef unsigned char platform_t;

#define PLATFORM_UNKNOWN    ((platform_t)0)

const char* strPlatform(platform_t platform);

#endif
