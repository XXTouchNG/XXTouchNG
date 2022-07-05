/**
 * src/mh/utils.h -- header file for mh utilities
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


#ifndef MH_UTILS_H
#define MH_UTILS_H

#include <stdlib.h>
#include <stdio.h>
#include <mach/mach.h>

#ifdef  __cplusplus
extern "C" {
#endif

uint8_t *mh_hex2bytes(const char *inhex, size_t length);

char *mh_bytes2hex(const uint8_t *bytes, size_t buflen);

int mh_dump_hex(void *tmp, mach_vm_size_t size, mach_vm_address_t address_offset);

int mh_hex2int(char p);
int mh_is_hex_char(char p);
int mh_is_space_char(char p);

#ifdef  __cplusplus
}
#endif

#endif //MH_UTILS_H

// EOF