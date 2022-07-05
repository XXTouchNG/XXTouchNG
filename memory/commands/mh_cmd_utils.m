/**
 * src/app/commands/utils.c -- mh_cli: utilities command
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


static uint32_t mh_reverse_int32(uint32_t arg)
{
    uint32_t result;
    result = ((arg & 0xFF) << 24) | ((arg & 0xFF00) << 8) | ((arg >> 8) & 0xFF00) | ((arg >> 24) & 0xFF);

    return result;
}

static uint64_t mh_reverse_int64(uint64_t arg)
{
    union Swap64
    {
        uint64_t i;
        uint32_t ul[2];
    } tmp, result;
    tmp.i = arg;
    result.ul[0] = mh_reverse_int32(tmp.ul[1]);
    result.ul[1] = mh_reverse_int32(tmp.ul[0]);

    return result.i;
}

static void mh_copy_float(void *dst, float f)
{
    union Copy32
    {
        float    f;
        uint32_t i;
    } m;
    m.f = f;


    m.i = mh_reverse_int32(m.i);

    memcpy(dst, &m.f, sizeof(float));
}

static void mh_copy_double(void *dst, double d)
{
    union Copy64
    {
        double   d;
        uint64_t i;
    } m;
    m.d = d;
    m.i = mh_reverse_int64(m.i);

    memcpy(dst, &m.d, sizeof(double));
}

int mh_cmd_utils_hex2bytes(char *bytes, size_t length)
{
    printf("Result:  %s \n", mh_hex2bytes(bytes, length));
    return 0;
}


int mh_cmd_utils_bytes2hex(char *bytes, size_t length)
{
    printf("Result:  %s \n", mh_bytes2hex((uint8_t *) bytes, length));
    return 0;
}

int mh_cmd_utils_float2hex(float number)
{
    printf("Result:  %s \n", mh_bytes2hex((uint8_t *) &number, sizeof(float)));
    uint32_t n = 0;
    mh_copy_float(&n, number);

    printf("Reverse: %s \n", mh_bytes2hex((uint8_t *) &n, sizeof(float)));

    return 0;
}

int mh_cmd_utils_double2hex(double number)
{
    printf("Result:  %s \n", mh_bytes2hex((uint8_t *) &number, sizeof(double)));

    uint32_t n = 0;
    mh_copy_double(&n, number);

    printf("Reverse: %s \n", mh_bytes2hex((uint8_t *) &n, sizeof(double)));

    return 0;
}

int mh_cmd_utils_int2hex(long long int number)
{
    fprintf(stdout, "int64: %s \n", mh_bytes2hex((uint8_t *) &number, sizeof(long long int)));
    fprintf(stdout, "int32: %s \n", mh_bytes2hex((uint8_t *) &number, sizeof(int)));
    fprintf(stdout, "int16: %s \n", mh_bytes2hex((uint8_t *) &number, sizeof(int16_t)));

    return 0;
}


// EOF
