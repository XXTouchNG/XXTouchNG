/**
 * src/mh/search.h -- header file for mh search functions
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

#ifndef MH_SEARCH_H
#define MH_SEARCH_H

#include <string.h>
#include <stdio.h>

#define BM_CHAR_MAP_SIZE 256

#ifdef  __cplusplus
extern "C" {
#endif

int mh_bm_max_int(int left, int right);

void mh_bm_prepare_bad_characters(const unsigned char *needle, int nlen, int *bad_char_map);

void mh_bm_prepare_good_suffixes(unsigned char *needle, int nlen, int *good_suffix_map);

int mh_bm_search(const unsigned char *haystack, int hlen, unsigned char *needle, int nlen, int *ret);

#ifdef  __cplusplus
}
#endif

#endif //MH_SEARCH_H
