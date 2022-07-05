/**
 * src/mh/mh.c -- source file for mh library
 *
 * @author sskaje
 * @license MIT
 * ------------------------------------------------------------------------
 * The MIT License (MIT)
 *
 * Copyright (c) 2018 - , sskaje (https://sskaje.me/)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * ------------------------------------------------------------------------
 */

#include "mh_mh.h"
#include <libkern/OSCacheControl.h>


const char *usertag_to_text(unsigned int tag);

/**
 * task_for_pid
 *
 * @param process
 * @return mh_reverse_int32
 */
static int mh_task_for_pid(MHProcess *process)
{
    return task_for_pid(mach_task_self(), process->process_id, &process->process_task);
}

/**
 * Open task
 *
 * @param process_id
 * @param process
 * @return
 */
int mh_open_task(pid_t process_id, MHProcess *process)
{
    process->process_id = process_id;

    int err = mh_task_for_pid(process);

    if (err != KERN_SUCCESS) {
        printf("task_for_pid() failure: %d - %s\n", err, mach_error_string(err));
        return -1;
    }

    return 0;
}

/**
 * Reset process
 *
 * @param process
 * @return
 */
int mh_reset_process(MHProcess *process)
{
    process->process_id         = 0;
    process->is64bit            = 0;
    process->process_task       = 0;
    process->image_file_path    = 0;
    process->image_load_address = 0;
    return 0;
}

/**
 * Read dyld info
 *
 * @param process
 * @param dyld_info
 * @return
 */
int mh_read_dyld(MHProcess *process, MHDyldInfo *dyld_info)
{
    int err;

    dyld_info->count = TASK_DYLD_INFO_COUNT;

    // read DYLD info
    err = task_info(process->process_task, TASK_DYLD_INFO, (task_info_t) &dyld_info->dyld_info, &dyld_info->count);

    if (err != KERN_SUCCESS)
    {
        printf("task_info() failure: %d - %s\n", err, mach_error_string(err));
        return -2;
    }

    if (dyld_info->dyld_info.all_image_info_format == TASK_DYLD_ALL_IMAGE_INFO_32) {
        process->is64bit = 0;
    } else {
        process->is64bit = 1;
    }

    return 0;
}

/**
 * Read dyld images
 *
 * @param process
 * @param images
 * @param image_count
 * @return
 */
int mh_read_dyld_images(MHProcess *process, pointer_t *images, int *image_count)
{
    int err;

    MHDyldInfo dyld_info;
    mh_read_dyld(process, &dyld_info);

    int os_ptr_size = sizeof(pointer_t);

    int app_ptr_size = 4;

    if (process->is64bit) {
        app_ptr_size = 8;
    }

    // 32 bit + 32 bit + 32/64 bit, 16 bytes is enough
//    mach_vm_size_t all_image_infos_size = 16;
    mach_vm_size_t all_image_infos_size = sizeof(struct dyld_all_image_infos);

    struct dyld_all_image_infos *all_image_infos = NULL;

    err = mach_vm_read(
            process->process_task,
            dyld_info.dyld_info.all_image_info_addr,
            all_image_infos_size,
            (vm_offset_t *) &all_image_infos,
            (mach_msg_type_number_t *) &all_image_infos_size
                      );

    if (err != KERN_SUCCESS) {
        printf("mach_vm_read() failure: %d - %s\n", err, mach_error_string(err));
        return -3;
    }

    if (all_image_infos->version < 0x01) {
        printf("unexpected dyld_all_image_infos.version=%d\n", all_image_infos->version);
        return -4;
    } else if (all_image_infos->version > 0x0f) {
        printf("unsupported dyld_all_image_infos.version=%d\n", all_image_infos->version);
        return -5;
    }

//    printf("dyld_all_image_infos.version=%d\n", all_image_infos->version);
//    printf("dyld_all_image_infos.infoArrayCount=%d\n", all_image_infos->infoArrayCount);
//    printf("dyld_all_image_infos.infoArray=%016llx\n", (unsigned long long int) all_image_infos->infoArray);

//    hexDump("Dump all_image_infos", all_image_infos, (int) all_image_infos_size);

    mach_vm_address_t info_array_address = *(mach_vm_address_t *) &all_image_infos->infoArray;
    mach_vm_address_t image_info_size    = sizeof(struct dyld_image_info);

    if (app_ptr_size != os_ptr_size) {
        // for 32-bit app, lower 32 bits is infoArray
        if (app_ptr_size == 4) {
            info_array_address &= 0xFFFFFFFF;
            // half size
            image_info_size /= 2;
        } else {
            printf("Exit\n");
            return -3;
        }
    }

//    printf("infoArrayCount=%d, infoArrayAddr=%016llx\n", all_image_infos->infoArrayCount, info_array_address);

    void *info_array_bytes = NULL;

    mach_vm_address_t info_array_size = image_info_size * all_image_infos->infoArrayCount;

    err = mach_vm_read(
            process->process_task,
            info_array_address,
            info_array_size,
            (vm_offset_t *) &info_array_bytes,
            (mach_msg_type_number_t *) &info_array_size
                      );

    if (err != KERN_SUCCESS) {
        printf("mach_vm_read() failure: %d - %s\n", err, mach_error_string(err));
        return -2;
    }

//    hexDump("Dump info_array_bytes", info_array_bytes, (int) info_array_size);

    *image_count = all_image_infos->infoArrayCount;

    MHImage *_images = calloc(all_image_infos->infoArrayCount, sizeof(MHImage));

    for (uint32_t infoIndex = 0; infoIndex < all_image_infos->infoArrayCount; infoIndex++) {
        void *info_image = (uint8_t *) info_array_bytes + image_info_size * infoIndex;

        if (process->is64bit) {
            _images[infoIndex].load_address = *(mach_vm_address_t *) info_image;
            _images[infoIndex].file_path    = *(mach_vm_address_t *) (info_image + app_ptr_size);
        } else {
            _images[infoIndex].load_address = *(uint32_t *) info_image;
            _images[infoIndex].file_path    = *(uint32_t *) (info_image + app_ptr_size);
        }

        if (infoIndex == 0) {
            // self image
            process->image_load_address = _images[infoIndex].load_address;
            process->image_file_path    = _images[infoIndex].file_path;
        }
    }

    *images = (pointer_t) _images;

    mach_vm_deallocate(mach_task_self(), (vm_offset_t) info_array_bytes, info_array_size);
    mach_vm_deallocate(mach_task_self(), (vm_offset_t) all_image_infos, all_image_infos_size);

    return 0;
}

/**
 * Read memory
 *
 * @param process
 * @param address
 * @param size
 * @return
 */
void *mh_read_memory(MHProcess *process, mach_vm_address_t address, mach_vm_size_t *size)
{
    void *tmp = NULL;

    mach_vm_read(
                 process->process_task,
                 address,
                 *size,
                 (vm_offset_t *) &tmp,
                 (mach_msg_type_number_t *) size
                );

    return tmp;
}
/**
 * Dump memory
 *
 * @param process
 * @param address
 * @param size
 * @return
 */
int mh_dump_memory(MHProcess *process, mach_vm_address_t address, mach_vm_size_t size)
{
    void *tmp = mh_read_memory(process, address, &size);

    return mh_dump_hex(tmp, size, address);
}

/**
 * Write memory
 *
 * @param process
 * @param address
 * @param bytes
 * @param size
 * @return
 */
int mh_write_memory(MHProcess *process, mach_vm_address_t address, void *bytes, mach_vm_size_t size)
{
    int                         protection;
    int                         pagesize;
    kern_return_t               err;
    mach_vm_address_t           region_address;
    mach_vm_size_t              region_size;
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t      infoCount;
    memory_object_name_t        object;
    vm_map_t                    task;
    
    task = process->process_task;
    pagesize = getpagesize();
    region_address = address & ~(pagesize - 1);
    infoCount  = VM_REGION_BASIC_INFO_COUNT_64;
    
    // find region
    err = mach_vm_region(
                       task,
                       &region_address,
                       &region_size,
                       VM_REGION_BASIC_INFO_64,
                       (vm_region_info_t)&info,
                       &infoCount,
                       &object
                       );
    
    if (err != KERN_SUCCESS)
    {
        return err;
    }
    
    // modify protection level
    protection = info.protection & (VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    region_address = address & ~(pagesize - 1);
    err = mach_vm_protect(task, region_address, pagesize, false, VM_PROT_ALL | VM_PROT_COPY);
    if (err != KERN_SUCCESS)
    {
        return err;
    }
    
    // write memory
    err = mach_vm_write(
                        task,
                        address,
                        (vm_offset_t) bytes,
                        (mach_msg_type_number_t) size
                        );
    if (err != KERN_SUCCESS)
    { // restore protection and return err code
        mach_vm_protect(task, region_address, pagesize, false, protection);
        return err;
    }
    
    // flush and invalidate cache
    // sys_dcache_flush((void *)address, size);
    // sys_icache_invalidate((void *)address, size);
    
    // restore protection
    return mach_vm_protect(task, region_address, pagesize, false, protection);
}


bool mh_region_submap_info(MHProcess *process, mach_vm_address_t *address, mach_vm_size_t *size,
                           vm_region_submap_info_data_64_t *region_info)
{
    bool                   success = true;
    mach_msg_type_number_t info_count;
    natural_t              depth   = 0;

    while (true) {
        info_count = VM_REGION_SUBMAP_INFO_COUNT_64;
        success    = mach_vm_region_recurse(process->process_task, address, size, &depth,
                                            (vm_region_recurse_info_t) region_info, &info_count) == KERN_SUCCESS;
        if (!success || !region_info->is_submap) {
            break;
        }
        depth++;
    }
    return success;
}

void mh_print_submap_region_info(MHProcess *process)
{
    mach_vm_address_t               address    = 0x0;
    mach_vm_size_t                  size;
    mach_vm_size_t                  total_size = 0;
    vm_region_submap_info_data_64_t info;
    mach_msg_type_number_t          info_count;
    natural_t                       depth      = 0;

    const char step[10][11] = {
            "\0",
            "\t\0",
            "\t\t\0",
            "\t\t\t\0",
            "\t\t\t\t\0",
            "\t\t\t\t\t\0",
            "\t\t\t\t\t\t\0",
            "\t\t\t\t\t\t\t\0",
            "\t\t\t\t\t\t\t\t\0",
            "\t\t\t\t\t\t\t\t\t\0"
    };


    while (1) {
        info_count = VM_REGION_SUBMAP_INFO_COUNT_64;
        if (mach_vm_region_recurse(process->process_task, &address, &size, &depth, (vm_region_recurse_info_t) &info,
                                   &info_count) != KERN_SUCCESS) {
            break;
        }


        printf(
                "[%d] %s 0x%016llx-0x%016llx size=0x%08llx offset=%016llx, %c%c%c/%c%c%c, %s\n",
                info.is_submap,
                step[depth],
                address,
                address + size,
                size,
                info.offset,
                (info.protection & VM_PROT_READ) ? 'r' : '-',
                (info.protection & VM_PROT_WRITE) ? 'w' : '-',
                (info.protection & VM_PROT_EXECUTE) ? 'x' : '-',
                (info.max_protection & VM_PROT_READ) ? 'r' : '-',
                (info.max_protection & VM_PROT_WRITE) ? 'w' : '-',
                (info.max_protection & VM_PROT_EXECUTE) ? 'x' : '-',
                usertag_to_text(info.user_tag)
              );

        if (info.is_submap) {
            depth++;
        } else {
            total_size += size;
            address += size;
        }
    }

    printf("total region size=%016llx\n", total_size);
}

/**
 * Convert VM_MEMORY_* Macro to Text
 *
 * @param tag
 * @return
 */
const char *usertag_to_text(unsigned int tag)
{

#define TAGCASE(VAL, TXT) case VAL: return TXT;

    switch (tag) {
        TAGCASE(VM_MEMORY_MALLOC, "MALLOC")
        TAGCASE(VM_MEMORY_MALLOC_SMALL, "MALLOC_SMALL")
        TAGCASE(VM_MEMORY_MALLOC_LARGE, "MALLOC_LARGE")
        TAGCASE(VM_MEMORY_MALLOC_HUGE, "MALLOC_HUGE")
        TAGCASE(VM_MEMORY_SBRK, "SBRK")
        TAGCASE(VM_MEMORY_REALLOC, "REALLOC")
        TAGCASE(VM_MEMORY_MALLOC_TINY, "MALLOC_TINY")
        TAGCASE(VM_MEMORY_MALLOC_LARGE_REUSABLE, "MALLOC_LARGE_REUSABLE")
        TAGCASE(VM_MEMORY_MALLOC_LARGE_REUSED, "MALLOC_LARGE_REUSED")
        TAGCASE(VM_MEMORY_ANALYSIS_TOOL, "ANALYSIS_TOOL")
        TAGCASE(VM_MEMORY_MALLOC_NANO, "MALLOC_NANO")
        TAGCASE(VM_MEMORY_MACH_MSG, "Mach Message")
        TAGCASE(VM_MEMORY_IOKIT, "IOKit")
        TAGCASE(VM_MEMORY_STACK, "STACK")
        TAGCASE(VM_MEMORY_GUARD, "GUARD")
        TAGCASE(VM_MEMORY_SHARED_PMAP, "SHARED_PMAP")
        TAGCASE(VM_MEMORY_DYLIB, "dylib")
        TAGCASE(VM_MEMORY_OBJC_DISPATCHERS, "Obj-C Dispatchers")
        TAGCASE(VM_MEMORY_UNSHARED_PMAP, "UNSHARED_PMAP")
        TAGCASE(VM_MEMORY_APPKIT, "AppKit")
        TAGCASE(VM_MEMORY_FOUNDATION, "FOUNDATION")
        TAGCASE(VM_MEMORY_COREGRAPHICS, "Core Graphics")
        TAGCASE(VM_MEMORY_CORESERVICES, "Core Services")
//        TAGCASE(VM_MEMORY_CARBON, "CARBON")
        TAGCASE(VM_MEMORY_JAVA, "JAVA")
        TAGCASE(VM_MEMORY_COREDATA, "Core Data")
        TAGCASE(VM_MEMORY_COREDATA_OBJECTIDS, "Core Data Object IDs")
        TAGCASE(VM_MEMORY_ATS, "Apple Type Services")
        TAGCASE(VM_MEMORY_LAYERKIT, "LayerKit")
        TAGCASE(VM_MEMORY_CGIMAGE, "CGImage")
        TAGCASE(VM_MEMORY_TCMALLOC, "TCMalloc")
        TAGCASE(VM_MEMORY_COREGRAPHICS_DATA, "Core Graphics Data")
        TAGCASE(VM_MEMORY_COREGRAPHICS_SHARED, "Core Graphics Shared")
        TAGCASE(VM_MEMORY_COREGRAPHICS_FRAMEBUFFERS, "Core Graphics Framebuffers")
        TAGCASE(VM_MEMORY_COREGRAPHICS_BACKINGSTORES, "Core Graphics Backing Stores")
#ifdef VM_MEMORY_COREGRAPHICS_XALLOC
        TAGCASE(VM_MEMORY_COREGRAPHICS_XALLOC, "COREGRAPHICS_XALLOC")
#endif
//        TAGCASE(VM_MEMORY_COREGRAPHICS_MISC, "COREGRAPHICS_MISC")
        TAGCASE(VM_MEMORY_DYLD, "dyld")
        TAGCASE(VM_MEMORY_DYLD_MALLOC, "dyld Malloc")
        TAGCASE(VM_MEMORY_SQLITE, "SQLITE")
        TAGCASE(VM_MEMORY_JAVASCRIPT_CORE, "JavaScript Core")
        TAGCASE(VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR, "JavaScript JIT Executable Allocator")
        TAGCASE(VM_MEMORY_JAVASCRIPT_JIT_REGISTER_FILE, "JavaScript JIT Register File")
        TAGCASE(VM_MEMORY_GLSL, "GLSL")
        TAGCASE(VM_MEMORY_OPENCL, "OpenCL")
        TAGCASE(VM_MEMORY_COREIMAGE, "Core Image")
        TAGCASE(VM_MEMORY_WEBCORE_PURGEABLE_BUFFERS, "WebCore Purgeable Buffers")
        TAGCASE(VM_MEMORY_IMAGEIO, "ImageIO")
        TAGCASE(VM_MEMORY_COREPROFILE, "Core Profile")
        TAGCASE(VM_MEMORY_ASSETSD, "ASSETSD")
        TAGCASE(VM_MEMORY_OS_ALLOC_ONCE, "OS Alloc Once")
        TAGCASE(VM_MEMORY_LIBDISPATCH, "libdispatch")
        TAGCASE(VM_MEMORY_ACCELERATE, "ACCELERATE")
        TAGCASE(VM_MEMORY_COREUI, "CoreUI")
        TAGCASE(VM_MEMORY_COREUIFILE, "CoreUI File")
        TAGCASE(VM_MEMORY_GENEALOGY, "Genealogy")
        TAGCASE(VM_MEMORY_RAWCAMERA, "RAW Camera")
        TAGCASE(VM_MEMORY_CORPSEINFO, "Corpse Info")
        TAGCASE(VM_MEMORY_ASL, "Apple System Log (ASL)")
#ifdef VM_MEMORY_SWIFT_RUNTIME
        TAGCASE(VM_MEMORY_SWIFT_RUNTIME, "SWIFT_RUNTIME")
#endif
#ifdef VM_MEMORY_SWIFT_METADATA
        TAGCASE(VM_MEMORY_SWIFT_METADATA, "SWIFT_METADATA")
#endif
#ifdef VM_MEMORY_DHMM
        TAGCASE(VM_MEMORY_DHMM, "DHMM")
#endif
#ifdef VM_MEMORY_SCENEKIT
        TAGCASE(VM_MEMORY_SCENEKIT, "SCENEKIT")
#endif
#ifdef VM_MEMORY_SKYWALK
        TAGCASE(VM_MEMORY_SKYWALK, "SKYWALK")
#endif
        TAGCASE(VM_MEMORY_APPLICATION_SPECIFIC_1, "APPLICATION_SPECIFIC_1")
        TAGCASE(VM_MEMORY_APPLICATION_SPECIFIC_16, "APPLICATION_SPECIFIC_16")
        default:
            return "";
    }
}

/**
 * Get name of user_tag from vm region submap
 *
 * @param process
 * @param address
 * @param size
 * @return
 */
const char *mh_usertag_to_text(MHProcess *process, mach_vm_address_t address, mach_vm_size_t size)
{
    const char                      *user_tag_description = "";
    mach_vm_address_t               region_address        = address;
    mach_vm_size_t                  region_size           = size;
    vm_region_submap_info_data_64_t submap_info;

    if (mh_region_submap_info(process, &region_address, &region_size, &submap_info) && region_address <= address &&
        address + size <= region_address + region_size) {
        user_tag_description = usertag_to_text(submap_info.user_tag);
    }

    return user_tag_description;
}

/**
 * Search data in buffer using Boyer-Moore Search
 *
 * @param haystack
 * @param size
 * @param needle
 * @param nlen
 * @param offsets
 * @return
 */
int mh_search_bytes(const unsigned char *haystack, mach_vm_size_t size, unsigned char *needle, int nlen,
                    vm_offset_t *offsets)
{
    int i, j, good_suffix_map[nlen], bad_char_map[BM_CHAR_MAP_SIZE];

    /* Preprocessing */
    mh_bm_prepare_good_suffixes(needle, nlen, good_suffix_map);
    mh_bm_prepare_bad_characters(needle, nlen, bad_char_map);

    int result_size = 0;

    /* Searching */
    j = 0;
    while (j <= size - nlen) {
        for (i = nlen - 1; i >= 0 && needle[i] == haystack[i + j]; --i);
        if (i < 0) {
            offsets[result_size] = (vm_offset_t) j;
            ++result_size;

            j += good_suffix_map[0];
        } else {
            j += mh_bm_max_int(good_suffix_map[i], bad_char_map[haystack[i + j]] - nlen + 1 + i);
        }
    }

    return result_size;
}


#pragma mark - Value Search

typedef struct { char c; int8_t x;   } mh_s_int8;
typedef struct { char c; uint8_t x;  } mh_s_uint8;
typedef struct { char c; int16_t x;  } mh_s_int16;
typedef struct { char c; uint16_t x; } mh_s_uint16;
typedef struct { char c; int32_t x;  } mh_s_int32;
typedef struct { char c; uint32_t x; } mh_s_uint32;
typedef struct { char c; int64_t x;  } mh_s_int64;
typedef struct { char c; uint64_t x; } mh_s_uint64;
typedef struct { char c; float x;    } mh_s_float;
typedef struct { char c; double x;   } mh_s_double;

#define MH_DALIGN_int8_t   (offsetof(mh_s_int8,   x))
#define MH_DALIGN_int16_t  (offsetof(mh_s_int16,  x))
#define MH_DALIGN_int32_t  (offsetof(mh_s_int32,  x))
#define MH_DALIGN_int64_t  (offsetof(mh_s_int64,  x))
#define MH_DALIGN_uint8_t  (offsetof(mh_s_uint8,  x))
#define MH_DALIGN_uint16_t (offsetof(mh_s_uint16, x))
#define MH_DALIGN_uint32_t (offsetof(mh_s_uint32, x))
#define MH_DALIGN_uint64_t (offsetof(mh_s_uint64, x))
#define MH_DALIGN_float    (offsetof(mh_s_float,  x))
#define MH_DALIGN_double   (offsetof(mh_s_double, x))

#define MH_DFETCH0(T) \
T va, lv, hv;

#define MH_DFETCH1(T, _VA, _LV, _HV) \
memcpy((void *)&va, _VA, sizeof(T)); \
memcpy((void *)&lv, _LV, sizeof(T)); \
memcpy((void *)&hv, _HV, sizeof(T));

#define MH_DTYPE(ENT, CH1, CH2) \
(*ENT->dataType == CH1 && *(ENT->dataType + 1) == CH2)

#define MH_DITER(T) \
int rsize = 0; \
int dsize = sizeof(T); \
int align = MH_DALIGN_## T; \
MH_DFETCH0(T); \
mach_vm_offset_t hay = (mach_vm_offset_t) haystack; \
mach_vm_offset_t offset; \
if (hay % align != 0) { \
    hay += (align - (hay % align)); \
} \
mach_vm_size_t tlen = hlen - dsize; \
for (offset = 0; offset < tlen; offset += align) { \
    MH_DFETCH1(T, (void *)(hay + offset), &entry->lv, &entry->hv); \
    if (va >= lv && va <= hv) { \
        offsets[rsize] = (vm_offset_t) offset; \
        ++rsize; \
    } \
} \
return rsize;

#define MH_DCOMPARE(T) \
MH_DFETCH0(T); \
MH_DFETCH1(T, haystack, &entry->lv, &entry->hv); \
return (va >= lv && va <= hv);


int mh_search_entries(const unsigned char *haystack, mach_vm_size_t hlen, struct search_entry *entry, vm_offset_t *offsets)
{
    /**/ if (MH_DTYPE(entry, 'I', '8')) { MH_DITER(int8_t);   }
    else if (MH_DTYPE(entry, 'I', '1')) { MH_DITER(int16_t);  }
    else if (MH_DTYPE(entry, 'I', '3')) { MH_DITER(int32_t);  }
    else if (MH_DTYPE(entry, 'I', '6')) { MH_DITER(int64_t);  }
    else if (MH_DTYPE(entry, 'U', '8')) { MH_DITER(uint8_t);  }
    else if (MH_DTYPE(entry, 'U', '1')) { MH_DITER(uint16_t); }
    else if (MH_DTYPE(entry, 'U', '3')) { MH_DITER(uint32_t); }
    else if (MH_DTYPE(entry, 'U', '6')) { MH_DITER(uint64_t); }
    else if (MH_DTYPE(entry, 'F', '3')) { MH_DITER(float);    }
    else if (MH_DTYPE(entry, 'F', '6')) { MH_DITER(double);   }
    else { assert(false); }
    return 0;
}

int mh_compare_entry(const unsigned char *haystack, struct search_entry *entry)
{
    /**/ if (MH_DTYPE(entry, 'I', '8')) { MH_DCOMPARE(int8_t);   }
    else if (MH_DTYPE(entry, 'I', '1')) { MH_DCOMPARE(int16_t);  }
    else if (MH_DTYPE(entry, 'I', '3')) { MH_DCOMPARE(int32_t);  }
    else if (MH_DTYPE(entry, 'I', '6')) { MH_DCOMPARE(int64_t);  }
    else if (MH_DTYPE(entry, 'U', '8')) { MH_DCOMPARE(uint8_t);  }
    else if (MH_DTYPE(entry, 'U', '1')) { MH_DCOMPARE(uint16_t); }
    else if (MH_DTYPE(entry, 'U', '3')) { MH_DCOMPARE(uint32_t); }
    else if (MH_DTYPE(entry, 'U', '6')) { MH_DCOMPARE(uint64_t); }
    else if (MH_DTYPE(entry, 'F', '3')) { MH_DCOMPARE(float);    }
    else if (MH_DTYPE(entry, 'F', '6')) { MH_DCOMPARE(double);   }
    else { assert(false); }
    return 0;
}

mach_vm_size_t mh_size_for_type(const char *type)
{
    /**/ if (strcmp(type, "I8")  == 0) { return sizeof(int8_t);   }
    else if (strcmp(type, "I16") == 0) { return sizeof(int16_t);  }
    else if (strcmp(type, "I32") == 0) { return sizeof(int32_t);  }
    else if (strcmp(type, "I64") == 0) { return sizeof(int64_t);  }
    else if (strcmp(type, "U8")  == 0) { return sizeof(uint8_t);  }
    else if (strcmp(type, "U16") == 0) { return sizeof(uint16_t); }
    else if (strcmp(type, "U32") == 0) { return sizeof(uint32_t); }
    else if (strcmp(type, "U64") == 0) { return sizeof(uint64_t); }
    else if (strcmp(type, "F32") == 0) { return sizeof(float);    }
    else if (strcmp(type, "F64") == 0) { return sizeof(double);   }
    return 0;
}

// EOF
