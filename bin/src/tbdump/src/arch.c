/*
 * Copyright (c) 2016 Siguza
 */

#include <stdbool.h>            // bool, true, false

#include <mach/machine.h>       // cpu_type_t, cpu_subtype_t

#include "arch.h"

const char* strArch(arch_t arch)
{
    switch(arch)
    {
        case ARCH_I386:     return "i386";
        case ARCH_X86_64:   return "x86_64";
        case ARCH_ARMV7:    return "armv7";
        case ARCH_ARMV7S:   return "armv7s";
        case ARCH_ARMV7K:   return "armv7k";
        case ARCH_ARM64:    return "arm64";
        case ARCH_ARM64E:   return "arm64e";
        case ARCH_ARM64_32: return "arm64_32";
    }
    return "unknown";
}

arch_t cpu2arch(cpu_type_t cpu, cpu_subtype_t sub)
{
    switch(cpu)
    {
        case CPU_TYPE_I386:     return ARCH_I386;
        case CPU_TYPE_X86_64:   return ARCH_X86_64;
        case CPU_TYPE_ARM:
            switch(sub)
            {
                case CPU_SUBTYPE_ARM_V7S: return ARCH_ARMV7S;
                case CPU_SUBTYPE_ARM_V7K: return ARCH_ARMV7K;
            }
            return ARCH_ARMV7;
        case CPU_TYPE_ARM64:
            switch(sub)
            {
                case CPU_SUBTYPE_ARM64E: return ARCH_ARM64E;
            }
            return ARCH_ARM64;
        case CPU_TYPE_ARM64_32: return ARCH_ARM64_32;
    }
    return ARCH_UNKNOWN;
}

bool isArch64(arch_t arch)
{
    return ((ARCH_X86_64 | ARCH_ARM64 | ARCH_ARM64E) & arch) != 0;
}
