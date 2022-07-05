/**
 * src/app/commands/search.c -- mh_cli: search command
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

#include "mh_commands.h"
#include "mh_mh.h"

static MHSearchMapMode mh_global_search_map_mode = MH_NORMAL;

MHSearchMapMode mh_get_search_map_mode() {
    return mh_global_search_map_mode;
}

void mh_set_search_map_mode(MHSearchMapMode mode) {
    mh_global_search_map_mode = mode;
}

int mh_cmd_search_entries(MHContext *context, struct search_entry *entries, int ncount, mach_vm_address_t start_pos, int max_count)
{
    if (context->result_count)
    {
        mh_result_free(&context->results);
        context->result_count = 0;
    }
    
    COMMAND_REQUIRE_PROCESS()
    if (max_count == 0) {
#if DEBUG
        printf("Max count must be greater than 0\n");
#endif
        return -1;
    }
    
    mach_vm_address_t address = start_pos;
    mach_vm_size_t size;
    mach_vm_address_t region_address = start_pos;
    mach_vm_size_t region_size;
    
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount;
    mach_port_t objectName = MACH_PORT_NULL;
    
    kern_return_t err;
    
    int total_result_count = 0;
    
    while (1)
    {
        infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        
        err = mach_vm_region(
                             context->process.process_task,
                             &region_address,
                             &region_size,
                             VM_REGION_BASIC_INFO_64,
                             (vm_region_info_t) &info,
                             &infoCount,
                             &objectName);
        
        if (err != KERN_SUCCESS)
        {
            break;
        }
        
        bool region_protected = ((info.protection & (VM_PROT_READ | VM_PROT_COPY)) == 0);
        const char *region_usertag = mh_usertag_to_text(&context->process, region_address, region_size);
        switch (mh_get_search_map_mode()) {
            case MH_ALL:
                if (!region_protected)
                {
                    break;
                }
                else
                { // TODO: patch region to make it accessible
                    
                }
            case MH_NORMAL:
                if (!region_protected)
                {
                    if (region_usertag[0] != '\0')
                    { // all except protected regions & empty
                        break;
                    }
                }
            case MH_FAST:
                if (!region_protected)
                {
                    if (region_usertag[0] == 'M'  || // MALLOC_*
                        region_usertag[0] == 'S'  || // STACK
                        region_usertag[0] == 'T')    // TCMalloc
                    { // including MALLOC_*, SWIFT_*, TCMalloc
                        break;
                    }
                }
            default:
                goto NEXT;
                break;
        }
        
        
        if (
            start_pos != 0 &&
            start_pos >= region_address &&
            start_pos <= region_address + region_size
        )
        { // first region, follow the start position.
            address = start_pos;
            size = region_size - (start_pos - region_address);
            start_pos = 0;
        }
        else
        { // other regions
            address = region_address;
            size = region_size;
        }
        
        
#if MAX_READ_MEMORY_SIZE > 0
        if (region_size > MAX_READ_MEMORY_SIZE)
        {
            size = MAX_READ_MEMORY_SIZE;
        }
        
        while (address + size <= region_address + region_size)
        {
#endif
            void *mem = NULL;
            
            err = mach_vm_read(
                               context->process.process_task,
                               address,
                               size,
                               (vm_offset_t *) &mem,
                               (mach_msg_type_number_t *) &size
                               );
            
            if (err != KERN_SUCCESS)
            {
                goto NEXT;
            }
            
            vm_offset_t *offsets = (vm_offset_t *) malloc(size * sizeof(vm_offset_t));
            
            if (!offsets)
            { // failed to alloc offsets map, remember to clean
                mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem, size);
                goto NEXT;
            }
            
            // find first entries in region
            struct search_entry *entry0 = entries;
            int result_count = mh_search_entries(mem, size, entry0, offsets);
            for (mach_vm_size_t i = 0; i < result_count; i++)
            {
                mach_vm_address_t o = address + offsets[i];
                
                // union search
                int k;
                for (k = 1; k < ncount; k++)
                {
                    struct search_entry *entry1 = &entries[k];
                    mach_vm_address_t o1 = o + entry1->offset;
                    mach_vm_size_t size1 = mh_size_for_type(entry1->dataType);
                    
                    void *mem1 = NULL;
                    
                    err = mach_vm_read(
                                       context->process.process_task,
                                       o1,
                                       size1,
                                       (vm_offset_t *) &mem1,
                                       (mach_msg_type_number_t *) &size1
                                       );
                    
                    if (err != KERN_SUCCESS)
                    { // failed to check the unit of union search
                        break;
                    }
                    
                    int result1 = mh_compare_entry(mem1, entry1);
                    mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem1, size1);
                    
                    if (!result1)
                    { // not passed
                        break;
                    }
                }
                
                if (k != ncount)
                { // error occured, next match
                    continue;
                }
                
                mh_result_add(&context->results, o, region_address, region_size);
                total_result_count++;
                
                if (total_result_count >= max_count)
                {
                    break;
                }
            }
            
            // do clean
            free(offsets);
            mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem, size);
            
            if (total_result_count >= max_count)
            {
                goto NEXT;
            }
            
#if MAX_READ_MEMORY_SIZE > 0
            address += size;
        };
#endif
        
    NEXT:
        region_address += region_size;
        if (total_result_count >= max_count)
        {
            break;
        }
    }
    
    context->result_count = total_result_count;
    
    return 0;
}

int mh_cmd_search_bytes(MHContext *context, char *needle, size_t needle_length, mach_vm_address_t start_pos, int max_count)
{
    if (context->result_count)
    {
        mh_result_free(&context->results);
        context->result_count = 0;
    }

    COMMAND_REQUIRE_PROCESS()
    if (max_count == 0) {
#if DEBUG
        printf("Max count must be greater than 0\n");
#endif
        return -1;
    }

    mach_vm_address_t address = start_pos;
    mach_vm_size_t size;
    mach_vm_address_t region_address = start_pos;
    mach_vm_size_t region_size;

    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount;
    mach_port_t objectName = MACH_PORT_NULL;

    kern_return_t err;

    int total_result_count = 0;

    while (1)
    {
        infoCount = VM_REGION_BASIC_INFO_COUNT_64;

        err = mach_vm_region(
                             context->process.process_task,
                             &region_address,
                             &region_size,
                             VM_REGION_BASIC_INFO_64,
                             (vm_region_info_t) &info,
                             &infoCount,
                             &objectName
                             );

        if (err != KERN_SUCCESS)
        {
            break;
        }

        const char *region_usertag = mh_usertag_to_text(&context->process, region_address, region_size);

        // currently only search for MALLOC_** and STACK
        if (!(info.protection & VM_PROT_READ) ||
            (region_usertag[0] != 'M' && region_usertag[0] != 'S' && region_usertag[0] != 'T'))
        {
            goto NEXT;
        }

        address = region_address;
        size = region_size;

#if MAX_READ_MEMORY_SIZE > 0
        if (region_size > MAX_READ_MEMORY_SIZE)
        {
            size = MAX_READ_MEMORY_SIZE;
        }

        while (address + size <= region_address + region_size)
        {
#endif

            void *mem = NULL;
            
            err = mach_vm_read(
                               context->process.process_task,
                               address,
                               size,
                               (vm_offset_t *) &mem,
                               (mach_msg_type_number_t *) &size
                               );
            
            if (err != KERN_SUCCESS)
            {
#if DEBUG
                printf("mach_vm_read(%016llx:%llx) failure: %d - %s\n", address, size, err, mach_error_string(err));
#endif
                goto NEXT;
            }
            
            vm_offset_t *offsets;
            
            if (needle_length > 1 && needle[0] != needle[1])
            {
                offsets = (vm_offset_t *) malloc((size / needle_length + 1) * sizeof(vm_offset_t));
            }
            else
            {
                offsets = (vm_offset_t *) malloc(size * sizeof(vm_offset_t));
            }
            
            if (!offsets)
            {
                mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem, size);
                goto NEXT;
            }
            
            int result_count = mh_search_bytes(mem, size, (unsigned char *) needle, (int) needle_length, offsets);
            int add_count = (total_result_count + result_count > max_count) ? (int)(max_count - total_result_count) : (result_count);
            for (mach_vm_size_t i = 0; i < add_count; i++)
            {
                mh_result_add(&context->results, address + offsets[i], region_address, region_size);
            }
            total_result_count += add_count;
            
            free(offsets);
            mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem, size);
            
            if (total_result_count >= max_count)
            {
                goto NEXT;
            }
            
#if MAX_READ_MEMORY_SIZE > 0
            address += size;
            
        };
        
#endif

    NEXT:
        region_address += region_size;
        if (total_result_count >= max_count)
        {
            break;
        }
    }

    context->result_count = total_result_count;
    context->query_size   = MAX(((needle_length / 16) + 1) * 16, context->query_size);

#if DEBUG
    printf("Found %d result(s).\n", (int) context->result_count);
#endif

    return 0;
}

int mh_cmd_update_search_entries(MHContext *context, struct search_entry *entries, int ncount)
{
    COMMAND_REQUIRE_PROCESS()
    
    if (mh_result_empty(&context->results)) {
#if DEBUG
        printf("Please use search command before using update-search\n");
#endif
        return -1;
    }
    if (context->result_count < 1) {
#if DEBUG
        printf("No result left\n");
#endif
        return -2;
    }
    
    kern_return_t err;
    struct result_entry *np = NULL;
    STAILQ_FOREACH(np, &context->results, next) {
        mach_vm_address_t o = np->address;
        
        int k;
        for (k = 0; k < ncount; k++)
        {
            struct search_entry *entry1 = &entries[k];
            mach_vm_address_t o1 = o + entry1->offset;
            mach_vm_size_t size1 = mh_size_for_type(entry1->dataType);
            
            void *mem1 = NULL;
            
            err = mach_vm_read(
                               context->process.process_task,
                               o1,
                               size1,
                               (vm_offset_t *) &mem1,
                               (mach_msg_type_number_t *) &size1
                               );
            
            if (err != KERN_SUCCESS)
            { // failed to check the unit of union search
                break;
            }
            
            int result1 = mh_compare_entry(mem1, entry1);
            mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem1, size1);
            
            if (!result1)
            { // not passed
                break;
            }
        }
        
        if (k != ncount)
        { // mismatch, remove
            STAILQ_REMOVE(&context->results, np, result_entry, next);
            free(np);
            --context->result_count;
        }
    }
    
    return 0;
}

int mh_cmd_update_search_bytes(MHContext *context, char *needle, size_t needle_length)
{
    COMMAND_REQUIRE_PROCESS()

    if (mh_result_empty(&context->results)) {
#if DEBUG
        printf("Please use search command before using update-search\n");
#endif
        return -1;
    }
    if (context->result_count < 1) {
#if DEBUG
        printf("No result left\n");
#endif
        return -2;
    }

    kern_return_t err;
    void *mem = NULL;
    mach_vm_size_t size;

    struct result_entry *np = NULL;
    STAILQ_FOREACH(np, &context->results, next) {
#if DEBUG
        printf("update search @address:%016llx\n", np->address);
#endif
        err = mach_vm_read(
                           context->process.process_task,
                           np->address,
                           (mach_vm_size_t) needle_length,
                           (vm_offset_t *) &mem,
                           (mach_msg_type_number_t *) &size
                           );

        if (err != KERN_SUCCESS) {
#if DEBUG
            printf(
                    "mach_vm_read(%016llx:%llx) failure: %d - %s\n",
                    np->address,
                    (unsigned long long int) needle_length,
                    err,
                    mach_error_string(err)
                  );
#endif
            continue;
        }

        if (strncmp(needle, mem, needle_length) != 0)
        {
            // mismatch, remove
            STAILQ_REMOVE(&context->results, np, result_entry, next);
            free(np);
            --context->result_count;
        }
        
        // do clean
        mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem, size);
    }

    context->query_size = MAX(((needle_length / 16) + 1) * 16, context->query_size);
#if DEBUG
    printf("Found %d result(s).\n", (int) context->result_count);
#endif
    return 0;
}

int mh_cmd_search_result_list(MHContext *context)
{
    COMMAND_REQUIRE_PROCESS()

    kern_return_t  err;
    void           *mem = NULL;
    mach_vm_size_t size;

    int i = 0;

    struct result_entry *np = NULL;
    STAILQ_FOREACH(np, &context->results, next) {
#if DEBUG
        printf("update search @address:%016llx\n", np->address);
#endif
        err = mach_vm_read(
                           context->process.process_task,
                           np->address,
                           (mach_vm_size_t) context->query_size,
                           (vm_offset_t *) &mem,
                           (mach_msg_type_number_t *) &size
                           );

        if (err != KERN_SUCCESS) {
#if DEBUG
            printf(
                    "mach_vm_read(%016llx:%llx) failure: %d - %s\n",
                    np->address,
                    (unsigned long long int) context->query_size,
                    err,
                    mach_error_string(err)
                  );
#endif
            continue;
        }

        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t         infoCount;
        mach_port_t                    objectName = MACH_PORT_NULL;

        infoCount = VM_REGION_BASIC_INFO_COUNT_64;

        err = mach_vm_region(
                             context->process.process_task, &np->region_address, &np->region_size,
                             VM_REGION_BASIC_INFO_64, (vm_region_info_t) &info,
                             &infoCount,
                             &objectName
                             );

        if (err != KERN_SUCCESS)
        {
            mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem, size);
            break;
        }

        const char *region_usertag = mh_usertag_to_text(&context->process, np->region_address, np->region_size);
        printf(
                "[%d] 0x%016llx-0x%016llx size=0x%08llx offset=%016llx, %c%c%c/%c%c%c, %s\n",
                i++,
                np->region_address,
                np->region_address + np->region_size,
                size,
                info.offset,
                (info.protection & VM_PROT_READ) ? 'r' : '-',
                (info.protection & VM_PROT_WRITE) ? 'w' : '-',
                (info.protection & VM_PROT_EXECUTE) ? 'x' : '-',
                (info.max_protection & VM_PROT_READ) ? 'r' : '-',
                (info.max_protection & VM_PROT_WRITE) ? 'w' : '-',
                (info.max_protection & VM_PROT_EXECUTE) ? 'x' : '-',
                region_usertag
              );

        mh_dump_hex((void *) mem, (vm_size_t) context->query_size, np->address);
        
        // do clean
        mach_vm_deallocate(mach_task_self(), (vm_offset_t) mem, size);
    }

    return 0;
}

// EOF
