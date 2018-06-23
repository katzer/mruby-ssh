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

#ifndef MRUBY_SSH_H
#define MRUBY_SSH_H

#ifdef __cplusplus
extern "C" {
#endif

#include <libssh2.h>

struct mrb_ssh
{
    LIBSSH2_SESSION *session;
    libssh2_socket_t sock;
};

typedef struct mrb_ssh mrb_ssh_t;

#define E_SSH_ERROR                    (mrb_class_get_under(mrb, mrb_module_get(mrb, "SSH"), "Exception"))
#define E_SSH_AUTH_ERROR               (mrb_class_get_under(mrb, mrb_module_get(mrb, "SSH"), "AuthenticationFailed"))
#define E_SSH_CHANNEL_REQUEST_ERROR    (mrb_class_get_under(mrb, mrb_module_get(mrb, "SSH"), "ChannelRequestFailed"))
#define E_SSH_CONNECT_ERROR            (mrb_class_get_under(mrb, mrb_module_get(mrb, "SSH"), "ConnectError"))
#define E_SSH_DISCONNECT_ERROR         (mrb_class_get_under(mrb, mrb_module_get(mrb, "SSH"), "Disconnected"))
#define E_SSH_HOST_KEY_ERROR           (mrb_class_get_under(mrb, mrb_module_get(mrb, "SSH"), "HostKeyMismatch"))
#define E_SSH_TIMEOUT_ERROR            (mrb_class_get_under(mrb, mrb_module_get(mrb, "SSH"), "Timeout"))

unsigned int mrb_ssh_initialized();
int mrb_ssh_wait_socket (mrb_ssh_t *ssh);
void mrb_ssh_raise_last_error (mrb_state *mrb, mrb_ssh_t *ssh);
void mrb_ssh_raise (mrb_state *mrb, int err, const char* msg);

#ifdef __cplusplus
}
#endif
#endif
