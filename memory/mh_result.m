/**
 * src/mh/result.c -- source file for mh result functions
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

#include "mh_mh.h"


/**
 * init result list
 *
 * @param results
 * @return
 */
int mh_result_init(struct result_head *results)
{
    STAILQ_INIT(results);
    STAILQ_EMPTY(results);

    return 0;
}
/**
 * If result list is empty
 *
 * @param results
 * @return
 */
int mh_result_empty(struct result_head *results)
{
    return STAILQ_EMPTY(results);
}

/**
 *
 *
 * @param results
 * @return
 */
int mh_result_free(struct result_head *results)
{
    // free search result if redo search
    if (!mh_result_empty(results)) {
        struct result_entry *np = NULL;
//        STAILQ_FOREACH(np, results, next) {
//            STAILQ_REMOVE(results, np, result_entry, next);
//            free(np);
//        }

        while (STAILQ_FIRST(results) != NULL) {
            np = STAILQ_FIRST(results);
            STAILQ_REMOVE_HEAD(results, next);
            free(np);
        }
    }

    return 0;
}

/**
 * add result to list
 *
 * @param results
 * @param address
 * @param region_address
 * @param region_size
 * @return
 */
int mh_result_add(struct result_head *results,
                  mach_vm_address_t address,
                  mach_vm_address_t region_address,
                  mach_vm_size_t region_size
                 )
{
    struct result_entry *n = (struct result_entry *) malloc(sizeof(struct result_entry));

    n->address        = address;
    n->region_address = region_address;
    n->region_size    = region_size;

    STAILQ_INSERT_TAIL(results, n, next);

    return 0;
}

/**
 * Remove result from list, returns 1 if node is removed
 *
 * @param results
 * @param address
 * @return
 */
int mh_result_remove_by_address(struct result_head *results, mach_vm_address_t address)
{
    struct result_entry *np = NULL;

    STAILQ_FOREACH(np, results, next) {
        if (np->address == address) {
            STAILQ_REMOVE(results, np, result_entry, next);
            free(np);
            return 1;
        }
    }

    return 0;
}

