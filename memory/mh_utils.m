/**
 * src/mh/utils.c -- source file for mh utilities
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

#include "mh_utils.h"


/**
 * Convert HEX string to bytes
 *
 * @param inhex
 * @param length
 * @return
 */
uint8_t *mh_hex2bytes(const char *inhex, size_t length)
{
    uint8_t *retval;
    uint8_t *p;
    int     len, i;

    len    = (int) (length / 2);
    retval = calloc((size_t) (len + 1), sizeof(uint8_t));

    for (i = 0, p = (uint8_t *) inhex; i < len; i++) {
        retval[i] = (mh_hex2int(*p) << 4) | mh_hex2int(*(p + 1));
        p += 2;
    }
    retval[len] = 0;
    return retval;
}

static char byteMap[]  = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
static int  byteMapLen = sizeof(byteMap);

/**
 * convert number to hex digit [0-9a-f]
 *
 * @param nibble
 * @return
 */
static char nibbleToChar(uint8_t nibble)
{
    if (nibble < byteMapLen) return byteMap[nibble];
    return '*';
}

/**
 * Convert a buffer of binary values into a hex string
 *
 * @param bytes
 * @param buflen
 * @return
 */
char *mh_bytes2hex(const uint8_t *bytes, size_t buflen)
{
    char *retval;
    int  i;

    retval = calloc(buflen * 2 + 1, sizeof(char));

    for (i = 0; i < buflen; i++) {
        retval[i * 2]     = nibbleToChar((uint8_t) (bytes[i] & 0xf0) >> 4);
        retval[i * 2 + 1] = nibbleToChar((uint8_t) (bytes[i] & 0x0f) >> 0);
    }

    retval[buflen * 2 + 1] = '\0';
    return retval;
}

/**
 * Dump buffer to HEX/ASCII output like `hexdump -C`
 *
 * @param tmp
 * @param size
 * @param address_offset
 * @return
 */
int mh_dump_hex(void *tmp, mach_vm_size_t size, mach_vm_address_t address_offset)
{
    int           i;
    unsigned char buff[17];
    unsigned char *pc = (unsigned char *) tmp;

    // Process every byte in the data.
    for (i = 0; i < size; i++) {
        // Multiple of 16 means new line (with line offset).

        if ((i % 16) == 0) {
            // Just don't print ASCII for the zeroth line.
            if (i != 0)
                printf("  %s\n", buff);

            // Output the offset.
            printf("  %016llx ", (mach_vm_address_t) i + address_offset);
        }

        // Now the hex code for the specific character.
        printf(" %02x", pc[i]);

        // And store a printable ASCII character for later.
        if ((pc[i] < 0x20) || (pc[i] > 0x7e))
            buff[i % 16] = '.';
        else
            buff[i % 16]   = pc[i];
        buff[(i % 16) + 1] = '\0';
    }

    // Pad out last line if not exactly 16 characters.
    while ((i % 16) != 0) {
        printf("   ");
        i++;
    }

    // And print the final ASCII bit.
    printf("  %s\n", buff);

    return (int) size;
}

/**
 * Convert HEX char to number
 *
 * @param p
 * @return
 */
int mh_hex2int(char p)
{
    return (p % 32 + 9) % 25;
}

/**
 * is p a HEX char
 * [0-9a-fA-F]
 *
 * @param p
 * @return
 */
int mh_is_hex_char(char p)
{
    return (p >= '0' && p <= '9') || (p >= 'a' && p <= 'f') || (p >= 'A' && p <= 'F');
}

/**
 * is p a space char
 * ' ', \t, \r, \n, \0
 *
 * @param p
 * @return
 */
int mh_is_space_char(char p)
{
    return (p == ' ' || p == '\t' || p == '\r' || p == '\n' || p == '\0');
}

// EOF
