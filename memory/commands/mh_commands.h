/**
 * src/app/commands/commands.h -- mh_cli: commands
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
#ifndef MH_COMMANDS_H
#define MH_COMMANDS_H

#include "mh_app.h"


#define COMMAND_REQUIRE_PROCESS_ERROR -99
#define COMMAND_REQUIRE_PROCESS() if (!context->process_id) { \
        printf("please open process first\n"); \
        return COMMAND_REQUIRE_PROCESS_ERROR; \
        }

typedef enum {
    MH_FAST = 0,
    MH_NORMAL,
    MH_ALL,
} MHSearchMapMode;

#ifdef  __cplusplus
extern "C" {
#endif

int mh_cmd_open(MHContext *context, pid_t pid);

int mh_cmd_close(MHContext *context);

int mh_cmd_process_list(MHContext *context);

int mh_cmd_process_dyld(MHContext *context);

int mh_cmd_process_vm_region(MHContext *context);

int mh_cmd_process_base_address(MHContext *context, mach_vm_address_t *base);

int mh_cmd_memory_write_hex(MHContext *context, mach_vm_address_t address, void *bytes, mach_vm_size_t size);

int mh_cmd_memory_write(MHContext *context, mach_vm_address_t address, void *bytes, mach_vm_size_t size);

int mh_cmd_memory_read(MHContext *context, mach_vm_address_t address, mach_vm_size_t size);

int mh_cmd_utils_hex2bytes(char *bytes, size_t length);

int mh_cmd_utils_bytes2hex(char *bytes, size_t length);

int mh_cmd_utils_float2hex(float number);

int mh_cmd_utils_double2hex(double number);

int mh_cmd_utils_int2hex(long long int number);

int mh_cmd_search_result_list(MHContext *context);

int mh_cmd_update_search_bytes(MHContext *context, char *needle, size_t needle_length);

int mh_cmd_search_bytes(MHContext *context, char *needle, size_t needle_length, mach_vm_address_t start_pos, int max_count);

int mh_cmd_search_entries(MHContext *context, struct search_entry *entries, int ncount, mach_vm_address_t start_pos, int max_count);

int mh_cmd_update_search_entries(MHContext *context, struct search_entry *entries, int ncount);

MHSearchMapMode mh_get_search_map_mode(void);

void mh_set_search_map_mode(MHSearchMapMode mode);

#ifdef  __cplusplus
}
#endif

#endif //MH_COMMANDS_H

// EOF
