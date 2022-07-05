/**
 * src/mh/mh.h -- header file for mh library
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
#ifndef MH_MH_H
#define MH_MH_H

#include <stdio.h>
#include <unistd.h>
#include <assert.h>
#include <stdlib.h>

#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach/vm_region.h>

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR

#include "mach_vm.h"

#else

#include <mach/mach_vm.h>

#endif

#include <mach-o/loader.h>
#include <mach-o/dyld_images.h>

#include <sys/sysctl.h>

#include "mh_search.h"
#include "mh_utils.h"


typedef struct {
    pid_t process_id;
    vm_map_t process_task;
    bool is64bit;
    mach_vm_address_t image_load_address;
    mach_vm_address_t image_file_path;
} MHProcess;

typedef struct {
    mach_vm_address_t load_address;
    mach_vm_address_t file_path;
} MHImage;

typedef struct {
    task_dyld_info_data_t dyld_info;
    mach_msg_type_number_t count;
} MHDyldInfo;

struct result_entry {
    mach_vm_address_t address;
    mach_vm_address_t region_address;
    mach_vm_size_t    region_size;

    STAILQ_ENTRY(result_entry) next;
};

STAILQ_HEAD(result_head, result_entry);

struct search_entry {
    uint8_t lv[8];
    uint8_t hv[8];
    vm_offset_t offset;  // must be positive
    const char *dataType;
};

#ifdef  __cplusplus
extern "C" {
#endif

int mh_result_init(struct result_head *results);

int mh_result_free(struct result_head *results);

int mh_result_empty(struct result_head *results);

int mh_result_add(struct result_head *results,
                  mach_vm_address_t address,
                  mach_vm_address_t region_address,
                  mach_vm_size_t region_size
                 );

int mh_result_remove_by_address(struct result_head *results, mach_vm_address_t address);

int mh_open_task(pid_t process_id, MHProcess *process);

int mh_reset_process(MHProcess *process);

int mh_read_dyld(MHProcess *process, MHDyldInfo *dyld_info);

int mh_read_dyld_images(MHProcess *process, pointer_t *images, int *image_count);

bool mh_region_submap_info(MHProcess *process, mach_vm_address_t *address, mach_vm_size_t *size,
                           vm_region_submap_info_data_64_t *region_info);

void * mh_read_memory(MHProcess *process, mach_vm_address_t address, mach_vm_size_t *size);

int mh_dump_memory(MHProcess *process, mach_vm_address_t address, mach_vm_size_t size);

void mh_print_submap_region_info(MHProcess *process);

const char *mh_usertag_to_text(MHProcess *process, mach_vm_address_t address, mach_vm_size_t size);

int mh_search_bytes(const unsigned char *haystack, mach_vm_size_t hlen, unsigned char *needle, int nlen,
                    vm_offset_t *offsets);

int mh_write_memory(MHProcess *process, mach_vm_address_t address, void* bytes, mach_vm_size_t size);

int mh_search_entries(const unsigned char *haystack, mach_vm_size_t hlen, struct search_entry *entry, vm_offset_t *offsets);

int mh_compare_entry(const unsigned char *haystack, struct search_entry *entry);

mach_vm_size_t mh_size_for_type(const char *type);

#ifdef  __cplusplus
}
#endif

#endif //MH_MH_H

