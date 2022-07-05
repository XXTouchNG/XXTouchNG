/**
 * src/app/commands/open.c -- mh_cli: open command
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


int mh_cmd_open(MHContext *context, pid_t pid)
{
    int err = mh_open_task(pid, &context->process);
    if (err) {
#if DEBUG
        printf("Failed to open task, pid=%d. Error: %d\n", pid, err);
#endif
        return err;
    }
#if DEBUG
    printf("Current PID=%d\n", context->process.process_id);
#endif
    mh_read_dyld(&context->process, &context->dyld);
    context->process_id = context->process.process_id;
    return 0;
}


int mh_cmd_close(MHContext *context)
{
    // reset process
    mh_reset_process(&context->process);
    // reset dyld

    // reset context
    context->process_id = 0;

    return 0;
}

// EOF
