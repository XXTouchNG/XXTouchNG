/**
 * src/app/commands/memory.c -- mh_cli: memory command
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


int mh_cmd_memory_read(MHContext *context, mach_vm_address_t address, mach_vm_size_t size)
{
    COMMAND_REQUIRE_PROCESS()

    printf("Read memory: addr=%016llx, size=0x%llx\n", address, size);

    return mh_dump_memory(&context->process, address, size);
}

int mh_cmd_memory_write(MHContext *context, mach_vm_address_t address, void *bytes, mach_vm_size_t size)
{
    COMMAND_REQUIRE_PROCESS()

    printf("Write memory: addr=%016llx, size=0x%llx\n", address, size);

    mh_write_memory(&context->process, address, bytes, size);

    return 0;
}


int mh_cmd_memory_write_hex(MHContext *context, mach_vm_address_t address, void *bytes, mach_vm_size_t size)
{
    // hex 2 bytes
    const char *nbytes = (const char *) mh_hex2bytes(bytes, size);

    return mh_cmd_memory_write(context, address, (void *) nbytes, size / 2);
}

// EOF
