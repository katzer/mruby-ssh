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

#include "channel.h"

#include "mruby.h"
#include "mruby/data.h"
#include "mruby/class.h"
#include "mruby/string.h"
#include "mruby/ext/ssh.h"

#include <stdlib.h>
#include <libssh2.h>

static mrb_sym SYM_SESSION;
static mrb_sym SYM_TYPE;
static mrb_sym SYM_WIN_SIZE;
static mrb_sym SYM_PKG_SIZE;

static void
mrb_ssh_channel_free (mrb_state *mrb, void *p)
{
    mrb_ssh_channel_t *data;

    if (!p) return;

    data = (mrb_ssh_channel_t *)p;

    if (data->channel && data->session->data && mrb_ssh_initialized()) {
        libssh2_channel_close(data->channel);
        libssh2_channel_free(data->channel);
    }

    free(data);
}

static mrb_data_type const mrb_ssh_channel_type = { "SSH::Channel", mrb_ssh_channel_free };

static mrb_value
mrb_ssh_f_open (mrb_state *mrb, mrb_value self)
{
    const char *ctype, *msg = NULL;
    unsigned int type_len, msg_len = 0, win_size, pkg_size;

    mrb_ssh_t *ssh;
    LIBSSH2_CHANNEL *channel;
    mrb_ssh_channel_t *data;
    mrb_value session, type;

    mrb_get_args(mrb, "|s!", &msg, &msg_len);

    if (DATA_PTR(self)) goto done;

    session = mrb_attr_get(mrb, self, SYM_SESSION);
    ssh     = DATA_PTR(session);

    if (!(ssh && mrb_ssh_initialized())) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "SSH session not connected.");
    }

    if (!libssh2_userauth_authenticated(ssh->session)) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "SSH session not authenticated.");
    }

    win_size = mrb_fixnum(mrb_attr_get(mrb, self, SYM_WIN_SIZE));
    pkg_size = mrb_fixnum(mrb_attr_get(mrb, self, SYM_PKG_SIZE));
    type     = mrb_attr_get(mrb, self, SYM_TYPE);
    ctype    = mrb_string_value_ptr(mrb, type);
    type_len = mrb_string_value_len(mrb, type);

    do {
        channel = libssh2_channel_open_ex(ssh->session, ctype, type_len, win_size, pkg_size, msg, msg_len);

        if (channel) break;

        if (libssh2_session_last_errno(ssh->session) == LIBSSH2_ERROR_EAGAIN) {
            mrb_ssh_wait_socket(ssh);
        } else {
            mrb_raise(mrb, E_RUNTIME_ERROR, "Unable to open the SSH channel.");
        }
    } while (!channel);

    data          = malloc(sizeof(mrb_ssh_channel_t));
    data->session = mrb_ptr(session);
    data->channel = channel;

    mrb_data_init(self, data, &mrb_ssh_channel_type);

  done:

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_close (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_channel_free(mrb, DATA_PTR(self));

    DATA_PTR(self)  = NULL;
    DATA_TYPE(self) = NULL;

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_closed (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_channel_t *data = DATA_PTR(self);

    if (!(data && mrb_ssh_initialized()))
        return mrb_true_value();

    return mrb_bool_value(data->session->data ? FALSE : TRUE);
}

void
mrb_mruby_ssh_channel_init (mrb_state *mrb)
{
    struct RClass *ssh, *cls;

    ssh = mrb_module_get(mrb, "SSH");
    cls = mrb_define_class_under(mrb, ssh, "Channel", mrb->object_class);

    MRB_SET_INSTANCE_TT(cls, MRB_TT_DATA);

    SYM_SESSION  = mrb_intern_static(mrb, "@session", 8);
    SYM_TYPE     = mrb_intern_static(mrb, "@type", 5);
    SYM_PKG_SIZE = mrb_intern_static(mrb, "@local_maximum_packet_size", 26);
    SYM_WIN_SIZE = mrb_intern_static(mrb, "@local_maximum_window_size", 26);

    mrb_define_method(mrb, cls, "open",       mrb_ssh_f_open,   MRB_ARGS_OPT(1));
    mrb_define_method(mrb, cls, "close",      mrb_ssh_f_close,  MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "closed?",    mrb_ssh_f_closed, MRB_ARGS_NONE());

    mrb_define_const(mrb, cls, "WINDOW_DEFAULT", mrb_fixnum_value(LIBSSH2_CHANNEL_WINDOW_DEFAULT));
    mrb_define_const(mrb, cls, "PACKET_DEFAULT", mrb_fixnum_value(LIBSSH2_CHANNEL_PACKET_DEFAULT));
}
