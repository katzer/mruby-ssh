/* MIT License
 *
 * Copyright (c) Sebastian Katzer 2017
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
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef MRB_SSH_TINY

#include "mruby.h"
#include "mruby/ext/ssh.h"

#include <libssh2.h>

MRB_BEGIN_DECL

struct mrb_ssh_channel
{
    struct RData *session;
    LIBSSH2_CHANNEL *channel;
};

typedef struct mrb_ssh_channel mrb_ssh_channel_t;

void mrb_mruby_ssh_channel_init (mrb_state *mrb);

mrb_ssh_t *mrb_ssh_session (mrb_state *mrb, mrb_value self);
mrb_ssh_channel_t *mrb_ssh_channel_bang (mrb_state *mrb, mrb_value self);

MRB_END_DECL

#endif
