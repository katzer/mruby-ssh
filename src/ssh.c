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

#ifdef _WIN32
# define _WIN32_WINNT _WIN32_WINNT_VISTA
# include <winsock2.h>
#endif

#include "session.h"

#ifndef MRB_SSH_TINY
# include "channel.h"
# include "stream.h"
#endif

#include "mruby.h"
#include "mruby/error.h"
#include "mruby/variable.h"
#include "mruby/ext/ssh.h"

#include <libssh2.h>

static int mrb_ssh_ready = 0;
static size_t mrb_main_p = 0;

static mrb_value
mrb_ssh_f_startup (mrb_state *mrb, mrb_value self)
{
#ifdef _WIN32
    WSADATA wsaData;
#endif

    if (mrb_ssh_ready) return mrb_nil_value();

#ifdef _WIN32
    if (WSAStartup(MAKEWORD(2,2), &wsaData) != 0) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "WSAStartup failed");
    }
#endif

    if (libssh2_init(0) != 0) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "libssh2_init failed");
    }

    mrb_ssh_ready = 1;

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_shutdown (mrb_state *mrb, mrb_value self)
{
    if (!mrb_ssh_ready) return mrb_nil_value();

#ifdef _WIN32
    WSACleanup();
#endif
    libssh2_exit();

    mrb_ssh_ready = 0;

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_ready (mrb_state *mrb, mrb_value self)
{
    return mrb_bool_value(mrb_ssh_ready);
}

inline unsigned int
mrb_ssh_initialized()
{
    return mrb_ssh_ready;
}

void
mrb_ssh_raise_last_error (mrb_state *mrb, mrb_ssh_t *ssh)
{
    int err = libssh2_session_last_errno(ssh->session);

    char *msg;
    libssh2_session_last_error(ssh->session, &msg, NULL, 0);

    mrb_ssh_raise(mrb, err, msg);
}

void
mrb_ssh_raise (mrb_state *mrb, int err, const char* msg)
{
    struct RClass *c;
    mrb_value exc;

    switch (err) {
    case LIBSSH2_ERROR_NONE:
        return;
    case LIBSSH2_ERROR_KEY_EXCHANGE_FAILURE:
        c = E_SSH_HOST_KEY_ERROR; break;
    case LIBSSH2_ERROR_SOCKET_TIMEOUT:
    case LIBSSH2_ERROR_TIMEOUT:
        c = E_SSH_TIMEOUT_ERROR; break;
    case LIBSSH2_ERROR_SOCKET_DISCONNECT:
        c = E_SSH_DISCONNECT_ERROR; break;
    case LIBSSH2_ERROR_AUTHENTICATION_FAILED:
        c = E_SSH_AUTH_ERROR; break;
    case LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED:
        c = E_SSH_CHANNEL_REQUEST_ERROR; break;
    default:
        c = E_SSH_ERROR; break;
    }

    exc = mrb_exc_new_str(mrb, c, mrb_str_new_cstr(mrb, msg));
    mrb_iv_set(mrb, exc, mrb_intern_static(mrb, "@errno", 6), mrb_fixnum_value(err));

    mrb_exc_raise(mrb, exc);
}

void
mrb_mruby_ssh_gem_init (mrb_state *mrb)
{
    struct RClass *ssh = mrb_define_module(mrb, "SSH");

    mrb_define_class_method(mrb, ssh, "startup",  mrb_ssh_f_startup,  MRB_ARGS_NONE());
    mrb_define_class_method(mrb, ssh, "shutdown", mrb_ssh_f_shutdown, MRB_ARGS_NONE());
    mrb_define_class_method(mrb, ssh, "ready?",   mrb_ssh_f_ready,    MRB_ARGS_NONE());

    mrb_mruby_ssh_session_init(mrb);

#ifndef MRB_SSH_TINY
    mrb_mruby_ssh_channel_init(mrb);
    mrb_mruby_ssh_stream_init(mrb);
#endif

    if (mrb_main_p == 0) {
        mrb_main_p = (size_t)mrb;
    }

    mrb_ssh_f_startup(mrb, mrb_nil_value());
}

void
mrb_mruby_ssh_gem_final (mrb_state *mrb)
{
    if (mrb_main_p == (size_t) mrb) {
        mrb_ssh_f_shutdown(mrb, mrb_nil_value());
        mrb_main_p = 0;
    }
}
