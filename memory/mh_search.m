/**
 * src/mh/search.c -- source file for mh search functions
 * Boyer-Moore Algorithm
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

#include "mh_search.h"


int mh_bm_max_int(int left, int right) {
    return left > right ? left : right;
}

void mh_bm_prepare_bad_characters(const unsigned char *needle, int nlen, int *bad_char_map) {
    int i;

    for (i = 0; i < BM_CHAR_MAP_SIZE; ++i) {
        bad_char_map[i] = nlen;
    }
    for (i = 0; i < nlen - 1; ++i) {
        bad_char_map[needle[i]] = nlen - i - 1;
    }
}

static void bm_generate_suffixes(const unsigned char *needle, int nlen, int *suffix) {
    int f = 0, g, i;

    suffix[nlen - 1] = nlen;
    g = nlen - 1;
    for (i = nlen - 2; i >= 0; --i) {
        if (i > g && suffix[i + nlen - 1 - f] < i - g) {
            suffix[i] = suffix[i + nlen - 1 - f];
        } else {
            if (i < g) {
                g = i;
            }
            f = i;
            while (g >= 0 && needle[g] == needle[g + nlen - 1 - f]) {
                --g;
            }
            suffix[i] = f - g;
        }
    }
}

void mh_bm_prepare_good_suffixes(unsigned char *needle, int nlen, int *good_suffix_map) {
    int i, j, suffix[nlen];

    bm_generate_suffixes(needle, nlen, suffix);

    for (i = 0; i < nlen; ++i) {
        good_suffix_map[i] = nlen;
    }

    j = 0;
    for (i = nlen - 1; i >= 0; --i) {
        if (suffix[i] == i + 1) {
            for (; j < nlen - 1 - i; ++j) {
                if (good_suffix_map[j] == nlen) {
                    good_suffix_map[j] = nlen - 1 - i;
                }
            }
        }
    }

    for (i = 0; i <= nlen - 2; ++i) {
        good_suffix_map[nlen - 1 - suffix[i]] = nlen - 1 - i;
    }
}


int mh_bm_search(const unsigned char *haystack, int hlen, unsigned char *needle, int nlen, int *result) {
    int i, j, good_suffix_map[nlen], bad_char_map[BM_CHAR_MAP_SIZE];

    /* Preprocessing */
    mh_bm_prepare_good_suffixes(needle, nlen, good_suffix_map);
    mh_bm_prepare_bad_characters(needle, nlen, bad_char_map);

    int ret_size = 0;

    /* Searching */
    j = 0;
    while (j <= hlen - nlen) {
        for (i = nlen - 1; i >= 0 && needle[i] == haystack[i + j]; --i);
        if (i < 0) {
            printf("Pos: %d %s\n", j, haystack+j);
            result[ret_size] = j;
            ++ ret_size;

            j += good_suffix_map[0];
        } else {
            j += mh_bm_max_int(good_suffix_map[i], bad_char_map[haystack[i + j]] - nlen + 1 + i);
        }
    }

    return ret_size;
}


// EOF
