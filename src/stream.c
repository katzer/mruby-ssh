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

#include "stream.h"
#include "channel.h"

#include "mruby.h"
#include "mruby/data.h"
#include "mruby/hash.h"
#include "mruby/class.h"
#include "mruby/string.h"
#include "mruby/variable.h"
#include "mruby/ext/ssh.h"

#include <libssh2.h>

#if MRUBY_RELEASE_NO < 10400
static mrb_int
mrb_str_index(mrb_state *mrb, mrb_value str, const char *lit, mrb_int len, mrb_int off)
{
    mrb_value pos = mrb_funcall(mrb, str, "index", 2, mrb_str_new_static(mrb, lit, len), mrb_fixnum_value(off));
    return mrb_nil_p(pos) ? -1 : mrb_fixnum(pos);
}
#endif

static mrb_sym SYM_ID;
static mrb_sym SYM_BUF;
static mrb_value KEY_CHOMP;

static int MAX_READ_SIZE = 0x4000;

static int
mrb_ssh_stream_id (mrb_state *mrb, mrb_value self)
{
    return (int) mrb_fixnum(mrb_attr_get(mrb, self, SYM_ID));
}

static mrb_value
mrb_ssh_f_init (mrb_state *mrb, mrb_value self)
{
    mrb_value channel;
    mrb_int stream = 0;

    mrb_get_args(mrb, "o|i", &channel, &stream);

    if (DATA_PTR(channel) == NULL) {
        mrb_raise(mrb, E_SSH_ERROR, "Channel not opened.");
    }

    mrb_iv_set(mrb, self, SYM_ID, mrb_fixnum_value(stream));
    mrb_iv_set(mrb, self, mrb_intern_static(mrb, "@channel", 8), channel);

    DATA_PTR(self) = DATA_PTR(channel);

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_gets (mrb_state *mrb, mrb_value self)
{
    ssize_t rc;
    int stream              = mrb_ssh_stream_id(mrb, self);
    mrb_ssh_t *ssh          = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data = mrb_ssh_channel_bang(mrb, self);

    mrb_value arg, opts, res, buf = mrb_attr_get(mrb, self, SYM_BUF);
    mrb_bool arg_given            = FALSE, mem_size_given = FALSE;
    size_t mem_size               = 256;
    mrb_int pos, sep_len          = 0;
    int chomp                     = FALSE;
    const char *sep               = NULL;
    char *mem                     = NULL;

    mrb_get_args(mrb, "|o?H!", &arg, &arg_given, &opts);

    if (mrb_hash_p(opts)) {
        chomp = mrb_type(mrb_hash_get(mrb, opts, KEY_CHOMP)) == MRB_TT_TRUE;
    }

    if (mrb_string_p(arg)) {
        sep     = RSTRING_PTR(arg);
        sep_len = RSTRING_LEN(arg);
    } else
    if (mrb_hash_p(arg)) {
        sep     = "\n";
        sep_len = 1;
        chomp   = mrb_type(mrb_hash_get(mrb, arg, KEY_CHOMP)) == MRB_TT_TRUE;
    } else
    if (arg_given && mrb_fixnum_p(arg)) {
        mem_size       = (int)mrb_fixnum(arg);
        mem_size_given = TRUE;
    } else
    if (arg_given && mrb_nil_p(arg)) {
        mem_size  = MAX_READ_SIZE;
    } else
    if (!arg_given) {
        sep     = "\n";
        sep_len = 1;
    } else {
        mrb_raise(mrb, E_TYPE_ERROR, "String or Fixnum expected.");
    }

    if (sep && mrb_test(buf) && ((pos = mrb_str_index(mrb, buf, sep, sep_len, 0)) != -1))
        goto hit;

    if (mem_size_given && mrb_test(buf)) {
        if (RSTRING_LEN(buf) >= mem_size) {
            pos = mem_size;
            goto hit;
        } else {
            mem_size -= RSTRING_LEN(buf);
        }
    }

    mem = mrb_malloc(mrb, mem_size * sizeof(char));

  read:

    while ((rc = libssh2_channel_read_ex(data->channel, stream, mem, mem_size)) == LIBSSH2_ERROR_EAGAIN) {
        mrb_ssh_wait_socket(ssh);
    };

    if (rc <= 0) {
        mrb_iv_remove(mrb, self, SYM_BUF);
        res = buf;
        goto chomp;
    }

    if (mrb_test(buf)) {
        buf = mrb_str_cat(mrb, buf, mem, rc);
    } else {
        buf = mrb_str_new(mrb, mem, rc);
    }

    if (!sep && !mem_size_given && rc > 0)
        goto read;

    if (!sep) {
        mrb_iv_remove(mrb, self, SYM_BUF);
        res = buf;
        goto chomp;
    }

    if ((pos = mrb_str_index(mrb, buf, sep, sep_len, 0)) == -1)
        goto read;

  hit:

    pos += sep_len;
    res = mrb_str_new(mrb, RSTRING_PTR(buf), pos);
    buf = mrb_str_substr(mrb, buf, pos, RSTRING_LEN(buf) - pos);

    mrb_iv_set(mrb, self, SYM_BUF, buf);

  chomp:

    if (mem) {
        mrb_free(mrb, mem);
    }

    if (mrb_string_p(res) && RSTRING_LEN(res) == 0) {
        return mrb_nil_value();
    }

    if (chomp && mrb_string_p(res)) {
        mrb_funcall(mrb, res, "chop!", 0);
    }

    return res;
}

static mrb_value
mrb_ssh_f_write (mrb_state *mrb, mrb_value self)
{
    ssize_t rc;
    const char *buf;
    mrb_int buf_len;

    int stream              = mrb_ssh_stream_id(mrb, self);
    mrb_ssh_t *ssh          = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data = mrb_ssh_channel_bang(mrb, self);

    mrb_get_args(mrb, "s", &buf, &buf_len);

    while ((rc = libssh2_channel_write_ex(data->channel, stream, buf, (size_t)buf_len)) == LIBSSH2_ERROR_EAGAIN) {
        mrb_ssh_wait_socket(ssh);
    }

    if (rc < 0) {
        mrb_ssh_raise_last_error(mrb, ssh);
    }

    return mrb_fixnum_value(rc);
}

static mrb_value
mrb_ssh_f_flush (mrb_state *mrb, mrb_value self)
{
    int rc, stream          = mrb_ssh_stream_id(mrb, self);
    mrb_ssh_t *ssh          = mrb_ssh_session(mrb, self);
    mrb_ssh_channel_t *data = mrb_ssh_channel_bang(mrb, self);

    while ((rc = libssh2_channel_flush_ex(data->channel, stream)) == LIBSSH2_ERROR_EAGAIN) {
        mrb_ssh_wait_socket(ssh);
    }

    mrb_iv_set(mrb, self, SYM_BUF, mrb_nil_value());

    return mrb_fixnum_value(rc);
}

void
mrb_mruby_ssh_stream_init (mrb_state *mrb)
{
    struct RClass *ssh, *cls;

    ssh = mrb_module_get(mrb, "SSH");
    cls = mrb_define_class_under(mrb, ssh, "Stream", mrb->object_class);

    SYM_ID    = mrb_intern_static(mrb, "@id", 3);
    SYM_BUF   = mrb_intern_static(mrb, "buf", 3);
    KEY_CHOMP = mrb_symbol_value(mrb_intern_static(mrb, "chomp", 5));

    mrb_define_method(mrb, cls, "initialize", mrb_ssh_f_init,  MRB_ARGS_ARG(1,1));
    mrb_define_method(mrb, cls, "gets",       mrb_ssh_f_gets,  MRB_ARGS_OPT(2));
    mrb_define_method(mrb, cls, "write",      mrb_ssh_f_write, MRB_ARGS_REQ(1));
    mrb_define_method(mrb, cls, "flush",      mrb_ssh_f_flush, MRB_ARGS_NONE());

    mrb_define_const(mrb, cls, "STDIO",   mrb_fixnum_value(0));
    mrb_define_const(mrb, cls, "STDERR",  mrb_fixnum_value(SSH_EXTENDED_DATA_STDERR));
}

#endif
