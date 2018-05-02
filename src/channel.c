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
#include "mruby/hash.h"
#include "mruby/class.h"
#include "mruby/string.h"
#include "mruby/ext/ssh.h"

#include <stdlib.h>
#include <libssh2.h>

static mrb_sym SYM_SESSION;
static mrb_sym SYM_TYPE;
static mrb_sym SYM_WIN_SIZE;
static mrb_sym SYM_PKG_SIZE;
static mrb_value KEY_CHOMP;
static mrb_value KEY_STREAM;

static void
mrb_ssh_channel_free3 (mrb_state *mrb, void *p, int wait)
{
    mrb_ssh_channel_t *data;

    if (!p) return;

    data = (mrb_ssh_channel_t *)p;

    if (data->channel && data->session->data && mrb_ssh_initialized()) {
        libssh2_channel_close(data->channel);

        if (wait == TRUE) {
            while (libssh2_channel_wait_closed(data->channel) == LIBSSH2_ERROR_EAGAIN);
        }

        libssh2_channel_free(data->channel);
    }

    free(data);
}

static void
mrb_ssh_channel_free (mrb_state *mrb, void *p)
{
    mrb_ssh_channel_free3(mrb, p, FALSE);
}

static mrb_data_type const mrb_ssh_channel_type = { "SSH::Channel", mrb_ssh_channel_free };

static mrb_ssh_t *
mrb_ssh_session (mrb_state *mrb, mrb_value self)
{
    return DATA_PTR(mrb_attr_get(mrb, self, SYM_SESSION));
}

static void
mrb_ssh_raise_unless_opened (mrb_state *mrb, mrb_ssh_channel_t *channel)
{
    if (channel && channel->session->data && mrb_ssh_initialized()) return;
    mrb_raise(mrb, E_RUNTIME_ERROR, "SSH channel not opened.");
}

static mrb_value
mrb_ssh_f_open (mrb_state *mrb, mrb_value self)
{
    const char *ctype, *msg   = NULL;
    mrb_int type_len, msg_len = 0;
    mrb_int win_size, pkg_size;

    mrb_ssh_t *ssh;
    LIBSSH2_CHANNEL *channel;
    mrb_ssh_channel_t *data;
    mrb_value session, type;

    mrb_get_args(mrb, "|s!", &msg, &msg_len);

    if (DATA_PTR(self)) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "SSH Channel already open.");
    }

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

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_request (mrb_state *mrb, mrb_value self)
{
    int rc;
    const char *req, *msg    = NULL;
    mrb_int req_len, msg_len = 0;
    mrb_int ext_data         = LIBSSH2_CHANNEL_EXTENDED_DATA_IGNORE;
    mrb_ssh_t *ssh           = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data  = DATA_PTR(self);

    mrb_get_args(mrb, "s|s!i", &req, &req_len, &msg, &msg_len, &ext_data);
    mrb_ssh_raise_unless_opened(mrb, data);

    while (libssh2_channel_handle_extended_data2(data->channel, (int)ext_data) == LIBSSH2_ERROR_EAGAIN) {
        mrb_ssh_wait_socket(ssh);
    }

    while ((rc = libssh2_channel_process_startup(data->channel, req, req_len, msg, msg_len)) == LIBSSH2_ERROR_EAGAIN) {
        mrb_ssh_wait_socket(ssh);
    }

    switch (rc) {
        case LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED:
            return mrb_false_value();
        case 0:
            return mrb_true_value();
        default:
            mrb_ssh_raise_last_error(mrb, ssh);
    }

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_read (mrb_state *mrb, mrb_value self)
{
    ssize_t rc;
    int chomp = FALSE, stream = FALSE;
    int bytes = 0, buf_len    = 0x4000;
    char buf[0x4000], *output = NULL;
    mrb_value res, arg        = mrb_nil_value();
    mrb_ssh_t *ssh            = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data   = DATA_PTR(self);

    mrb_ssh_raise_unless_opened(mrb, data);
    mrb_get_args(mrb, "H!", &arg);

    if (mrb_hash_p(arg)) {
        stream = mrb_fixnum(mrb_hash_get(mrb, arg, KEY_STREAM));
        chomp  = mrb_type(mrb_hash_get(mrb, arg, KEY_CHOMP)) == MRB_TT_TRUE;
    }

    for (;;) {
        do {
            rc = libssh2_channel_read_ex(data->channel, stream, buf, buf_len);

            if (rc <= 0)
                break;

            bytes += rc;

            if (!output) {
                output = (char *)malloc(sizeof(char) * (rc + 1));
                strncpy (output, buf, rc);
            }

            if (bytes > buf_len) {
                output = (char *)realloc(output, sizeof(char) * (bytes + 1));
                strncat(output, buf, rc);
            }

        } while (rc > 0);

        if (rc == LIBSSH2_ERROR_EAGAIN) {
            mrb_ssh_wait_socket(ssh);
        } else break;
    }

    if (bytes == 0)
        return mrb_nil_value();

    res = mrb_str_new_static(mrb, output, bytes);

    if (chomp) {
        res = mrb_funcall(mrb, res, "chomp", 0);
    }

    return res;
}

static mrb_value
mrb_ssh_f_env (mrb_state *mrb, mrb_value self)
{
    int rc;
    const char *env, *val;
    mrb_int env_len, val_len;
    mrb_ssh_t *ssh           = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data  = DATA_PTR(self);

    mrb_get_args(mrb, "ss", &env, &env_len, &val, &val_len);
    mrb_ssh_raise_unless_opened(mrb, data);

    while ((rc = libssh2_channel_setenv_ex(data->channel, env, env_len, val, val_len)) == LIBSSH2_ERROR_EAGAIN) {
        mrb_ssh_wait_socket(ssh);
    }

    switch (rc) {
        case LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED:
            return mrb_false_value();
        case 0:
            return mrb_true_value();
        default:
            mrb_ssh_raise_last_error(mrb, ssh);
    }

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_eof (mrb_state *mrb, mrb_value self)
{
    int rc;
    mrb_ssh_t *ssh           = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data  = DATA_PTR(self);

    mrb_ssh_raise_unless_opened(mrb, data);

    while ((rc = libssh2_channel_send_eof(data->channel)) == LIBSSH2_ERROR_EAGAIN) {
        mrb_ssh_wait_socket(ssh);
    }

    if (rc != 0) {
        mrb_ssh_raise_last_error(mrb, ssh);
    }

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_eof_bang (mrb_state *mrb, mrb_value self)
{
    int rc;
    mrb_ssh_t *ssh           = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data  = DATA_PTR(self);

    mrb_ssh_f_eof(mrb, self);

    while ((rc = libssh2_channel_wait_eof(data->channel)) == LIBSSH2_ERROR_EAGAIN) {
        mrb_ssh_wait_socket(ssh);
    }

    if (rc != 0) {
        mrb_ssh_raise_last_error(mrb, ssh);
    }

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_get_eof (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_t *ssh           = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data  = DATA_PTR(self);

    mrb_ssh_raise_unless_opened(mrb, data);

    switch (libssh2_channel_eof(data->channel)) {
        case 1:
            return mrb_true_value();
        case 0:
            return mrb_false_value();
        default:
            mrb_ssh_raise_last_error(mrb, ssh);
    }

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_close (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_channel_free3(mrb, DATA_PTR(self), FALSE);

    DATA_PTR(self)  = NULL;
    DATA_TYPE(self) = NULL;

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_close_bang (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_channel_free3(mrb, DATA_PTR(self), TRUE);

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
    KEY_CHOMP    = mrb_symbol_value(mrb_intern_static(mrb, "chomp", 5));
    KEY_STREAM   = mrb_symbol_value(mrb_intern_static(mrb, "stream", 6));

    mrb_define_method(mrb, cls, "open",       mrb_ssh_f_open,    MRB_ARGS_OPT(1));
    mrb_define_method(mrb, cls, "request",    mrb_ssh_f_request, MRB_ARGS_ARG(1,1));
    mrb_define_method(mrb, cls, "read",       mrb_ssh_f_read,    MRB_ARGS_OPT(1));
    mrb_define_method(mrb, cls, "env",        mrb_ssh_f_env,     MRB_ARGS_REQ(2));
    mrb_define_method(mrb, cls, "eof",        mrb_ssh_f_eof,     MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "eof!",       mrb_ssh_f_eof_bang, MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "eof?",       mrb_ssh_f_get_eof, MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "close",      mrb_ssh_f_close,   MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "close!",     mrb_ssh_f_close_bang, MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "closed?",    mrb_ssh_f_closed,  MRB_ARGS_NONE());

    mrb_define_const(mrb, cls, "WINDOW_DEFAULT", mrb_fixnum_value(LIBSSH2_CHANNEL_WINDOW_DEFAULT));
    mrb_define_const(mrb, cls, "PACKET_DEFAULT", mrb_fixnum_value(LIBSSH2_CHANNEL_PACKET_DEFAULT));
    mrb_define_const(mrb, cls, "EXT_NORMAL", mrb_fixnum_value(LIBSSH2_CHANNEL_EXTENDED_DATA_NORMAL));
    mrb_define_const(mrb, cls, "EXT_IGNORE", mrb_fixnum_value(LIBSSH2_CHANNEL_EXTENDED_DATA_IGNORE));
    mrb_define_const(mrb, cls, "EXT_MERGE",  mrb_fixnum_value(LIBSSH2_CHANNEL_EXTENDED_DATA_MERGE));
    mrb_define_const(mrb, cls, "STDOUT",     mrb_fixnum_value(0));
    mrb_define_const(mrb, cls, "STDERR",     mrb_fixnum_value(SSH_EXTENDED_DATA_STDERR));
}
