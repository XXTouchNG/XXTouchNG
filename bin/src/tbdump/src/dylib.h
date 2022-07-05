/*
 * Copyright (c) 2016 Siguza
 */

#ifndef DYLIB_H
#define DYLIB_H

#include <stdint.h>             // uint32_t
#include <stdio.h>              // FILE

#include "arch.h"               // arch_t
#include "platform.h"           // platform_t

#define RETVAL_SUCCESS              0
#define RETVAL_MEM                  1
#define RETVAL_IO                   2
#define RETVAL_MAGIC                3
#define RETVAL_NO_DYLIB             4
#define RETVAL_PLATFORM_MISSING     5
#define RETVAL_PLATFORM_MULTI       6
#define RETVAL_PLATFORM_MISMATCH    7
#define RETVAL_SYMTAB_MISSING       8
#define RETVAL_ID_MISSING           9

typedef struct _struct_symbol
{
    char *name;
    struct _struct_symbol *next;
} symbol_t;

typedef struct _struct_buf
{
    struct _struct_buf *next;
    char c;
} buf_t;

typedef struct _struct_arch_table
{
    arch_t arch;
    buf_t *buf; // linked list for symtab and strtab
    symbol_t *reExports;
    symbol_t *symbols;
    symbol_t *weakDefSymbols;
    symbol_t *objcClasses;
    symbol_t *objcIvars;
    struct _struct_arch_table *next;
} arch_table_t;

typedef struct
{
    platform_t platform;
    arch_t arch;
    char *installName;
    uint32_t currentVersion;
    uint32_t compatibilityVersion;
    arch_table_t *table;
} dylib_t;

void initDylib(dylib_t *dylib);

void cleanupDylib(dylib_t *dylib);

int parseDylib(FILE *in, dylib_t *dylib);

void printDylib(FILE *out, const dylib_t *dylib);

#endif
