/*
 * Copyright (c) 2016 Siguza
 */

#ifndef ARCH_H
#define ARCH_H

#include <stdbool.h>            // bool
#include <stdint.h>             // uint32_t

#include <mach/machine.h>       // cpu_type_t, cpu_subtype_t

typedef uint32_t arch_t;

#define ARCH_UNKNOWN    ((arch_t)0x0)
#define ARCH_I386       ((arch_t)0x1)
#define ARCH_X86_64     ((arch_t)0x2)
#define ARCH_ARMV7      ((arch_t)0x4)
#define ARCH_ARMV7S     ((arch_t)0x8)
#define ARCH_ARMV7K     ((arch_t)0x10)
#define ARCH_ARM64      ((arch_t)0x20)
#define ARCH_ARM64E     ((arch_t)0x40)
#define ARCH_ARM64_32   ((arch_t)0x80)

#define ARCH_MIN        ARCH_I386
#define ARCH_MAX        ARCH_ARM64_32

#define FOR_ARCH_IN(dst, src) for(arch_t dst = ARCH_MIN; dst <= ARCH_MAX; dst <<= 1) if((src & dst) > 0)

const char* strArch(arch_t arch);

arch_t cpu2arch(cpu_type_t cpu, cpu_subtype_t sub);

bool isArch64(arch_t arch);

#endif
