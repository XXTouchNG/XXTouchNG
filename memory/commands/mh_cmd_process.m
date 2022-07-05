/**
 * src/app/commands/process.c -- mh_cli: process command
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


int mh_cmd_process_dyld(MHContext *context)
{
    COMMAND_REQUIRE_PROCESS()

    pointer_t *imagePtr  = NULL;
    int       imageCount = 0;
    mh_read_dyld_images(&context->process, (pointer_t *) &imagePtr, &imageCount);

    MHImage *images = (MHImage *) imagePtr;

    for (int i = 0; i < imageCount; i++) {
        printf("[%4d] ", i);
        mach_vm_address_t tmpSize;

        void *tmp = NULL;

        if (context->process.is64bit) {
            tmpSize = sizeof(struct mach_header_64);
        } else {
            tmpSize = sizeof(struct mach_header);
        }

        mach_vm_read(
                context->process.process_task,
                images[i].load_address,
                tmpSize,
                (vm_offset_t *) &tmp,
                (mach_msg_type_number_t *) &tmpSize
                    );

        if (context->process.is64bit) {
            struct mach_header_64 *mach = (struct mach_header_64 *) tmp;
            printf("Bits=64, Magic=%08x, ", mach->magic);
        } else {
            struct mach_header *mach = (struct mach_header *) tmp;
            printf("Bits=32, Magic=%08x, ", mach->magic);
        }

        char *imageFilePath = NULL;
        tmpSize = 1024;
        mach_vm_read(
                context->process.process_task,
                images[i].file_path,
                tmpSize,
                (vm_offset_t *) &imageFilePath,
                (mach_msg_type_number_t *) &tmpSize
                    );

        printf("%016llx %s\n", images[i].load_address, (const char *) imageFilePath);

    }

    free(images);

    return 0;
}


int mh_cmd_process_base_address(MHContext *context, mach_vm_address_t *base)
{
    COMMAND_REQUIRE_PROCESS()
    
    int err;
    
    mach_vm_address_t address                 = 0x1;
    mach_vm_size_t    size;
    
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t         infoCount;
    mach_port_t                    objectName = MACH_PORT_NULL;
    
    infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    err       = mach_vm_region(
                               context->process.process_task,
                               &address,
                               &size,
                               VM_REGION_BASIC_INFO_64,
                               (vm_region_info_t) &info,
                               &infoCount,
                               &objectName);
    if (err != KERN_SUCCESS)
    {
        return err;
    }
    
    *base = address;
    return KERN_SUCCESS;
}


int mh_cmd_process_vm_region(MHContext *context)
{
    COMMAND_REQUIRE_PROCESS()

    int err;

    mach_vm_address_t address                 = 0x0;
    mach_vm_size_t    size;

    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t         infoCount;
    mach_port_t                    objectName = MACH_PORT_NULL;

    int region_count = 0;

    while (1) {
        infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        err       = mach_vm_region(
                context->process.process_task, &address, &size, VM_REGION_BASIC_INFO_64,
                (vm_region_info_t) &info,
                &infoCount,
                &objectName);
        if (err != KERN_SUCCESS) {
            break;
        }

        printf(
                "0x%016llx-0x%016llx size=0x%08llx offset=%016llx, %c%c%c/%c%c%c, %s\n",
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
                mh_usertag_to_text(&context->process, address, size)
              );

        address += size;
        ++region_count;
    }

    return region_count;
}


int mh_cmd_process_list(MHContext *context)
{
    int    _processTypeName[CTL_MAXNAME];
    size_t _processTypeNameLength = 0;


    const size_t maxLength = sizeof(_processTypeName) / sizeof(*_processTypeName);
    _processTypeNameLength = maxLength;

#define SYSCTL_PROC_CPUTYPE "sysctl.proc_cputype"

    int result = sysctlnametomib(SYSCTL_PROC_CPUTYPE, _processTypeName, &_processTypeNameLength);
    assert(result == 0);
    assert(_processTypeNameLength < maxLength);

    // last element in the name MIB will be the process ID that the client fills in before calling sysctl()
    _processTypeNameLength++;

    int    processListName[]     = {CTL_KERN, KERN_PROC, KERN_PROC_ALL};
    size_t processListNameLength = sizeof(processListName) / sizeof(*processListName);

    size_t processListRequestSize = 0;
    if (sysctl(processListName, (u_int) processListNameLength, NULL, &processListRequestSize, NULL, 0) != 0) return -1;
    struct kinfo_proc *processList = malloc(processListRequestSize);
    if (processList == NULL) return -2;

    size_t processListActualSize = processListRequestSize;
    if (sysctl(processListName, (u_int) processListNameLength, processList, &processListActualSize, NULL, 0) != 0
        || (processListActualSize == 0)) {
        free(processList);
        return -3;
    }

    const size_t processCount = processListActualSize / sizeof(*processList);

    printf("PID\tUID\tbits\tName\n");

    for (size_t processIndex = processCount; processIndex > 0; processIndex--) {
        struct kinfo_proc processInfo = processList[processIndex - 1];

        uid_t uid               = processInfo.kp_eproc.e_ucred.cr_uid;
        pid_t processIdentifier = processInfo.kp_proc.p_pid;

//        bool isBeingForked = (processInfo.kp_proc.p_stat & SIDL) != 0;
        if (processIdentifier != -1) {
            cpu_type_t cpuType     = 0;
            size_t     cpuTypeSize = sizeof(cpuType);

            // Grab CPU architecture type
            _processTypeName[_processTypeNameLength - 1] = processIdentifier;
            if (sysctl(_processTypeName, (u_int) _processTypeNameLength, &cpuType, &cpuTypeSize, NULL, 0) == 0) {
                bool is64Bit = ((cpuType & CPU_ARCH_ABI64) != 0);

                const char *internalName = processInfo.kp_proc.p_comm;

                printf("%-5d\t%-5d\t%dbit\t%s\n", processIdentifier, uid, is64Bit ? 64 : 32, internalName);
            }
        }
    }
    printf("Process count=%d\n", (int) processCount);

    free(processList);

    return 0;
}

// EOF
