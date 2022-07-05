/*
 * Copyright (c) 2016 Siguza
 */

#include <stdbool.h>            // bool, true, false
#include <stdint.h>             // uint32_t
#include <stdio.h>              // FILE, fputs, fputc
#include <stdlib.h>             // free, malloc
#include <string.h>

#include <mach-o/fat.h>         // FAT_CIGAM, fat_header
#include <mach-o/loader.h>      // MH_*, mach_header, mach_header_64, load_command
#include <mach-o/nlist.h>       // N_WEAK_DEF, nlist, nlist_64

#include "arch.h"               // FOR_ARCH_IN, strArch
#include "platform.h"           // strPlatform
#include "util.h"               // printStr, startsWith
#include "dylib.h"

#define SWAP32(i) ((i >> 24) & 0xff) | ((i >> 8) & 0xff00) | ((i << 8) & 0xff0000) | ((i << 24) & 0xff000000)

#define READ_OR_RETURN(ptr, ntimes, stream) \
{ \
    if(fread((ptr), 1, (ntimes), (stream)) != (ntimes)) \
    { \
        return RETVAL_IO; \
    } \
}

#define SEEK_OR_RETURN(stream, off) \
{ \
    if(fseek((stream), (off), SEEK_CUR) != 0) \
    { \
        return RETVAL_IO; \
    } \
} \

#define ALLOC_OR_RETURN(dst, size) \
{ \
    if((dst = malloc(size)) == NULL) \
    { \
        return RETVAL_MEM; \
    } \
}

#define ALLOC_ARCH_TABLE(dst, arch) \
{ \
    ALLOC_OR_RETURN(dst, sizeof(arch_table_t)) \
    dst->buf            = NULL; \
    dst->reExports      = NULL; \
    dst->symbols        = NULL; \
    dst->weakDefSymbols = NULL; \
    dst->objcClasses    = NULL; \
    dst->objcIvars      = NULL; \
    dst->next           = NULL; \
}

#define SYMTYPE_UNKNOWN     0
#define SYMTYPE_REEXPORT    1
#define SYMTYPE_NORMAL      2
#define SYMTYPE_WEAK        3
#define SYMTYPE_OBJC_CLASS  4
#define SYMTYPE_OBJC_IVAR   5

#define FOREACH_ADD_SYMBOL(dylib, arch, strtab, sym, nsyms) \
{ \
    for(uint32_t i = 0; i < (nsyms); ++i) \
    { \
        if((sym)[i].n_value != 0 && ((sym)[i].n_type & N_EXT)) \
        { \
            int ret = addSymbol((dylib), (arch), &(strtab)[(sym)[i].n_un.n_strx], ((sym)[i].n_desc & N_WEAK_DEF) > 0 ? SYMTYPE_WEAK : SYMTYPE_UNKNOWN); \
            if(ret != RETVAL_SUCCESS) \
            { \
                return ret; \
            } \
        } \
    } \
}

#define GET_SYMBOL(table, type) \
( \
    (type) == SYMTYPE_REEXPORT    ? (table)->reExports      : \
    (type) == SYMTYPE_NORMAL      ? (table)->symbols        : \
    (type) == SYMTYPE_WEAK        ? (table)->weakDefSymbols : \
    (type) == SYMTYPE_OBJC_CLASS  ? (table)->objcClasses    : (table)->objcIvars \
)

#define SET_SYMBOL(table, type, sym) \
{ \
    if((type) == SYMTYPE_REEXPORT  ) (table)->reExports      = (sym); \
    if((type) == SYMTYPE_NORMAL    ) (table)->symbols        = (sym); \
    if((type) == SYMTYPE_WEAK      ) (table)->weakDefSymbols = (sym); \
    if((type) == SYMTYPE_OBJC_CLASS) (table)->objcClasses    = (sym); \
    if((type) == SYMTYPE_OBJC_IVAR ) (table)->objcIvars      = (sym); \
}

typedef union
{
    struct fat_header       fat;
    struct mach_header      _32;
    struct mach_header_64   _64;
} hdr_t;

typedef union
{
    struct load_command         hdr;
    struct dylib_command        dylib;
    struct version_min_command  version;
    struct symtab_command       symtab;
    struct build_version_command build;
} lc_t;

typedef struct nlist    sym32_t;
typedef struct nlist_64 sym64_t;
typedef struct fat_arch fat_arch_t;

typedef struct
{
    uint32_t c :  8;
    uint32_t b :  8;
    uint32_t a : 16;
} version_t;

void initDylib(dylib_t *dylib)
{
    dylib->platform             = PLATFORM_UNKNOWN;
    dylib->arch                 = ARCH_UNKNOWN;
    dylib->installName          = NULL;
    dylib->currentVersion       = 0x10000;
    dylib->compatibilityVersion = 0x10000;
    dylib->table                = NULL;
}

void cleanupSymbols(symbol_t *sym)
{
    while(sym != NULL)
    {
        symbol_t *next = sym->next;
        free(sym);
        sym = next;
    }
}

void cleanupDylib(dylib_t *dylib)
{
    if(dylib->installName != NULL)
    {
        free(dylib->installName);
        dylib->installName = NULL;
    }
    arch_table_t *table = dylib->table;
    dylib->table = NULL;
    while(table != NULL)
    {
        cleanupSymbols(table->reExports);
        cleanupSymbols(table->symbols);
        cleanupSymbols(table->weakDefSymbols);
        cleanupSymbols(table->objcClasses);
        cleanupSymbols(table->objcIvars);
        buf_t *buf = table->buf;
        while(buf != NULL)
        {
            buf_t *next = buf->next;
            free(buf);
            buf = next;
        }
        arch_table_t *next = table->next;
        free(table);
        table = next;
    }
}

static int addSymbol(dylib_t *dylib, arch_t arch, char *sym, int type)
{
    if(strcmp(sym, "<redacted>") == 0 || startsWith(sym, "_OBJC_METACLASS_$")) // Ignore
    {
        return RETVAL_SUCCESS;
    }
    if(type == SYMTYPE_UNKNOWN)
    {
        if(startsWith(sym, "_OBJC_CLASS_$"))
        {
            type = SYMTYPE_OBJC_CLASS;
            sym += strlen("_OBJC_CLASS_$");
        }
        else if(startsWith(sym, "_OBJC_IVAR_$"))
        {
            type = SYMTYPE_OBJC_IVAR;
            sym += strlen("_OBJC_IVAR_$");
        }
        else
        {
            type = SYMTYPE_NORMAL;
        }
    }
    arch_t found = ARCH_UNKNOWN;
    symbol_t *prev = NULL;
    arch_table_t *src = NULL;
    for(src = dylib->table; src != NULL; src = src->next)
    {
        if((src->arch & arch) != 0)
        {
            continue;
        }
        prev = NULL;
        for(symbol_t *s = GET_SYMBOL(src, type); s != NULL; s = s->next)
        {
            if(strcmp(sym, s->name) == 0)
            {
                found = src->arch;
                goto after;
            }
            prev = s;
        }
    }
    after:; // need semicolon because declaration is following
    arch_t need = (found | arch);
    arch_table_t *dst = NULL;
    for(dst = dylib->table; dst != NULL; dst = dst->next)
    {
        if(dst->arch == need)
        {
            break;
        }
    }
    if(dst == NULL)
    {
        ALLOC_OR_RETURN(dst, sizeof(arch_table_t))
        dst->arch           = need;
        dst->buf            = NULL;
        dst->reExports      = NULL;
        dst->symbols        = NULL;
        dst->weakDefSymbols = NULL;
        dst->objcClasses    = NULL;
        dst->objcIvars      = NULL;
        dst->next           = NULL;
        arch_table_t *table = dylib->table;
        if(table == NULL || table->arch > need)
        {
            dst->next = table;
            dylib->table = dst;
        }
        else
        {
            while(true)
            {
                if(table->next == NULL || table->next->arch > need)
                {
                    dst->next = table->next;
                    table->next = dst;
                    break;
                }
                table = table->next;
            }
        }
    }
    symbol_t *s;
    if(found == ARCH_UNKNOWN)
    {
        ALLOC_OR_RETURN(s, sizeof(symbol_t))
        s->name = sym;
    }
    else if(prev == NULL)
    {
        s = GET_SYMBOL(src, type);
        SET_SYMBOL(src, type, s->next)
    }
    else
    {
        s = prev->next;
        prev->next = s->next;
    }
    s->next = NULL;
    prev = GET_SYMBOL(dst, type);
    if(prev == NULL)
    {
        SET_SYMBOL(dst, type, s)
    }
    else
    {
        for(; prev->next != NULL && strcmp(s->name, prev->next->name) > 0; prev = prev->next) /* empty */ ;
        s->next = prev->next;
        prev->next = s;
    }
    return RETVAL_SUCCESS;
}

static void swapIfLess(int i, uint32_t *off, uint32_t *len, char **tab)
{
    uint32_t tmp;
    char *tmc;
    if(off[i] > off[i + 1])
    {
        tmp = off[i];
        off[i] = off[i + 1];
        off[i + 1] = tmp;
        tmp = len[i];
        len[i] = len[i + 1];
        len[i + 1] = tmp;
        tmc = tab[i];
        tab[i] = tab[i + 1];
        tab[i + 1] = tmc;
    }
}

static int parseLoadCommands(FILE *in, dylib_t *dylib, uint32_t ncmds, long start, arch_t arch)
{
    platform_t plat = PLATFORM_UNKNOWN;
    uint32_t symoff  = 0,
             nsyms   = 0,
             stroff  = 0,
             strsize = 0;

    lc_t lc;
    char *lcbuf = (char*)&lc;
    size_t hdrsize = sizeof(lc.hdr);
    for(uint32_t i = 0; i < ncmds; ++i)
    {
        long pos = ftell(in);
        READ_OR_RETURN(lcbuf, hdrsize, in)
        switch(lc.hdr.cmd)
        {
            case LC_ID_DYLIB:
                READ_OR_RETURN(lcbuf + hdrsize, sizeof(lc.dylib) - hdrsize, in)
                dylib->currentVersion = lc.dylib.dylib.current_version;
                dylib->compatibilityVersion = lc.dylib.dylib.compatibility_version;
                ALLOC_OR_RETURN(dylib->installName, lc.dylib.cmdsize - lc.dylib.dylib.name.offset)
                SEEK_OR_RETURN(in, lc.dylib.dylib.name.offset - (ftell(in) - pos))
                READ_OR_RETURN(dylib->installName, lc.dylib.cmdsize - lc.dylib.dylib.name.offset, in)
                break;
            case LC_REEXPORT_DYLIB:
                // TODO
                break;
            case LC_VERSION_MIN_MACOSX:
            case LC_VERSION_MIN_IPHONEOS:
            case LC_VERSION_MIN_TVOS:
            case LC_VERSION_MIN_WATCHOS:
                if(plat != PLATFORM_UNKNOWN)
                {
                    return RETVAL_PLATFORM_MULTI;
                }
                plat = lc.hdr.cmd == LC_VERSION_MIN_MACOSX   ? PLATFORM_MACOS:
                       lc.hdr.cmd == LC_VERSION_MIN_IPHONEOS ? PLATFORM_IOS  :
                       lc.hdr.cmd == LC_VERSION_MIN_TVOS     ? PLATFORM_TVOS : PLATFORM_WATCHOS;
                break;
            case LC_BUILD_VERSION:
                READ_OR_RETURN(lcbuf + hdrsize, sizeof(lc.build) - hdrsize, in)
                plat = lc.build.platform;
                break;
            case LC_SYMTAB:
                READ_OR_RETURN(lcbuf + hdrsize, sizeof(lc.symtab) - hdrsize, in)
                symoff  = lc.symtab.symoff;
                nsyms   = lc.symtab.nsyms;
                stroff  = lc.symtab.stroff;
                strsize = lc.symtab.strsize;
                break;
        }
        SEEK_OR_RETURN(in, lc.hdr.cmdsize - (ftell(in) - pos))
    }

    // Sanity checks
    if(plat == PLATFORM_UNKNOWN)
    {
        return RETVAL_PLATFORM_MISSING;
    }
    if(dylib->platform == PLATFORM_UNKNOWN)
    {
        dylib->platform = plat;
    }
    else if(dylib->platform != plat)
    {
        return RETVAL_PLATFORM_MISMATCH;
    }
    if(symoff == 0)
    {
        return RETVAL_SYMTAB_MISSING;
    }
    if(dylib->installName == NULL)
    {
        return RETVAL_ID_MISSING;
    }

    arch_table_t *table;
    if(dylib->table == NULL)
    {
        ALLOC_ARCH_TABLE(table, arch)
        dylib->table = table;
    }
    else
    {
        for(table = dylib->table; true; table = table->next)
        {
            if(table->arch == arch)
            {
                break;
            }
            if(table->next == NULL)
            {
                ALLOC_ARCH_TABLE(table->next, arch)
                table = table->next;
                break;
            }
        }
    }

    bool is64 = isArch64(arch);
    buf_t *buf;
    char *symtab, *strtab;
    uint32_t off[3] = {symoff, stroff},
             len[3] = {nsyms * (is64 ? sizeof(sym64_t) : sizeof(sym32_t)), strsize};

    // symtab
    if(table->buf == NULL)
    {
        ALLOC_OR_RETURN(buf, sizeof(buf_t*) + len[0])
        table->buf = buf;
    }
    else
    {
        for(buf = table->buf; buf->next != NULL; buf = buf->next){}
        ALLOC_OR_RETURN(buf->next, sizeof(buf_t*) + len[0])
        buf = buf->next;
    }
    symtab = &buf->c;

    // strtab
    ALLOC_OR_RETURN(buf->next, sizeof(buf_t*) + len[1])
    buf = buf->next;
    buf->next = NULL;
    strtab = &buf->c;

    char *tab[2] = {symtab, strtab};
    swapIfLess(0, off, len, tab);
    for(uint32_t i = 0; i < 2; ++i)
    {
        SEEK_OR_RETURN(in, off[i] - (ftell(in) - start))
        READ_OR_RETURN(tab[i], len[i], in)
    }

    if(is64)
    {
        sym64_t *sym = (sym64_t*)symtab;
        FOREACH_ADD_SYMBOL(dylib, arch, strtab, sym, nsyms)
    }
    else
    {
        sym32_t *sym = (sym32_t*)symtab;
        FOREACH_ADD_SYMBOL(dylib, arch, strtab, sym, nsyms)
    }

    return RETVAL_SUCCESS;
}

int parseDylib(FILE *in, dylib_t *dylib)
{
    long start = ftell(in);
    arch_t arch;

    hdr_t hdr;
    char *buf = (char*)&hdr;
    size_t magicsize = sizeof(hdr.fat.magic);
    READ_OR_RETURN(buf, magicsize, in);
    if(hdr.fat.magic == FAT_CIGAM)
    {
        READ_OR_RETURN(buf + magicsize, sizeof(hdr.fat) - magicsize, in)
        fat_arch_t ar;
        uint32_t *off;
        uint32_t num = SWAP32(hdr.fat.nfat_arch);
        ALLOC_OR_RETURN(off, num * sizeof(uint32_t))
        for(uint32_t i = 0; i < num; ++i)
        {
            // Cannot use READ_OR_RETURN because free()
            if(fread(&ar, 1, sizeof(fat_arch_t), in) != sizeof(fat_arch_t))
            {
                free(off);
                return RETVAL_IO;
            }
            off[i] = SWAP32(ar.offset);
        }
        // Screw it, for everything < 10, bubble sort is good enough!
        for(uint32_t i = num - 1; i > 0; --i)
        {
            for(uint32_t j = 0; j < i; ++j)
            {
                if(off[j + 1] < off[j])
                {
                    uint32_t tmp = off[j];
                    off[j] = off[j + 1];
                    off[j + 1] = tmp;
                }
            }
        }
        for(uint32_t i = 0; i < num; ++i)
        {
            SEEK_OR_RETURN(in, off[i] - (ftell(in) - start))
            int ret = parseDylib(in, dylib);
            if(ret != RETVAL_SUCCESS)
            {
                free(off); // program might continue on certain errors
                return ret;
            }
        }
        free(off);
        return RETVAL_SUCCESS;
    }
    else if(hdr._32.magic == MH_MAGIC)
    {
        READ_OR_RETURN(buf + magicsize, sizeof(hdr._32) - magicsize, in)
        if(hdr._32.filetype != MH_DYLIB)
        {
            return RETVAL_NO_DYLIB;
        }
        dylib->arch |= arch = cpu2arch(hdr._32.cputype, hdr._32.cpusubtype);
        return parseLoadCommands(in, dylib, hdr._32.ncmds, start, arch);
    }
    else if(hdr._64.magic == MH_MAGIC_64)
    {
        READ_OR_RETURN(buf + magicsize, sizeof(hdr._64) - magicsize, in)
        if(hdr._64.filetype != MH_DYLIB)
        {
            return RETVAL_NO_DYLIB;
        }
        dylib->arch |= arch = cpu2arch(hdr._64.cputype, hdr._64.cpusubtype);
        return parseLoadCommands(in, dylib, hdr._64.ncmds, start, arch);
    }
    return RETVAL_MAGIC;
}

static void printArch(FILE *out, arch_t arch)
{
    bool first = true;
    FOR_ARCH_IN(a, arch)
    {
        if(first)
        {
            first = false;
        }
        else
        {
            fputs(", ", out);
        }
        printStr(out, strArch(a));
    }
}

static void printSymbols(FILE *out, const char *name, const symbol_t *sym)
{
    if(sym == NULL)
    {
        return;
    }
    int off = 5;
    fputs("    ", out);
    fputs(name, out);
    off += strlen(name);
    fputc(':', out);
    for(; off < 20; ++off)
    {
        fputc(' ', out);
    }
    fputs(" [ ", out);
    off += 3;
    for(int i = off; sym != NULL; sym = sym->next)
    {
        i += printStr(out, sym->name);
        if(sym->next != NULL)
        {
            fputs(", ", out);
            i += 2;
            if(i > 70)
            {
                fputc('\n', out);
                for(i = 0; i < off; ++i)
                {
                    fputc(' ', out);
                }
            }
        }
    }
    fputs(" ]\n", out);
}

static void printVersion(FILE *out, uint32_t version)
{
    version_t *v = (version_t*)&version;
    fprintf(out, "%u.%u", v->a, v->b);
    if(v->c != 0x0)
    {
        fprintf(out, ".%u", v->c);
    }
}

void printDylib(FILE *out, const dylib_t *dylib)
{
    fputs("---\n"
          "archs:           [ ", out);
    printArch(out, dylib->arch);
    fputs(" ]\n"
          "platform:        ", out);
    printStr(out, strPlatform(dylib->platform));
    fputs("\n"
          "install-name:    ", out);
    printStr(out, dylib->installName);
    if(dylib->currentVersion != 0x10000)
    {
        fputs("\n"
              "current-version: ", out);
        printVersion(out, dylib->currentVersion);
    }
    if(dylib->compatibilityVersion != 0x10000)
    {
        fputs("\n"
              "compatibility-version: ", out);
        printVersion(out, dylib->compatibilityVersion);
    }
    fputs("\n", out);
    bool first = true;
    for(arch_table_t *table = dylib->table; table != NULL; table = table->next)
    {
        if(table->reExports == NULL && table->symbols == NULL && table->weakDefSymbols == NULL && table->objcClasses == NULL && table->objcIvars == NULL)
        {
            continue;
        }
        if(first)
        {
            fputs("exports:         \n", out);
            first = false;
        }
        fputs("  - archs:           [ ", out);
        printArch(out, table->arch);
        fputs(" ]\n", out);
        printSymbols(out, "re-exports", table->reExports);
        printSymbols(out, "symbols", table->symbols);
        printSymbols(out, "weak-def-symbols", table->weakDefSymbols);
        printSymbols(out, "objc-classes", table->objcClasses);
        printSymbols(out, "objc-ivars", table->objcIvars);
    }
    fputs("...\n", out);
}
