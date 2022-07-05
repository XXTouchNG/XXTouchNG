/*
 * Copyright (c) 2016 Siguza
 */

#include "platform.h"

const char* strPlatform(platform_t platform)
{
    switch(platform)
    {
        case PLATFORM_MACOS:    return "macos";
        case PLATFORM_IOS:      return "ios";
        case PLATFORM_TVOS:     return "tvos";
        case PLATFORM_WATCHOS:  return "watchos";
        case PLATFORM_BRIDGEOS: return "bridgeos";
        case PLATFORM_MACCATALYST: return "maccatalyst";
    }
    return "unknown";
}
