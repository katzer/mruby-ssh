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

#include "session.h"

#include "mruby.h"
#include "mruby/data.h"
#include "mruby/hash.h"
#include "mruby/class.h"
#include "mruby/ext/ssh.h"
#include "mruby/variable.h"

#include <string.h>
#include <stdlib.h>
#include <libssh2.h>

#ifdef _WIN32
# include <winsock2.h>
# include <windows.h>
# include <ws2tcpip.h>
# include "getpass.c"
#else
# include <sys/socket.h>
# include <arpa/inet.h>
# include <netdb.h>
# include <unistd.h>
#endif

static void
mrb_ssh_close_socket (int sock)
{
#ifdef WIN32
    closesocket(sock);
#else
    close(sock);
#endif
}

static void
mrb_ssh_session_free(mrb_state *mrb, void *p)
{
    mrb_ssh_t *ssh;

    if (!p) return;

    ssh = (mrb_ssh_t *)p;

    if (mrb_ssh_initialized()) {
        while (libssh2_session_disconnect(ssh->session, NULL) == LIBSSH2_ERROR_EAGAIN) {
            mrb_ssh_wait_socket(ssh);
        };

        while (libssh2_session_free(ssh->session) == LIBSSH2_ERROR_EAGAIN) {
            mrb_ssh_wait_socket(ssh);
        };
    }

    mrb_ssh_close_socket(ssh->sock);

    free(ssh);
}

static mrb_data_type const mrb_ssh_session_type = { "SSH::Session", mrb_ssh_session_free };

int
mrb_ssh_wait_socket (mrb_ssh_t *ssh)
{
    struct timeval timeout;
    fd_set fd, *write_fd = NULL, *read_fd = NULL;
    int rc, dir;

    timeout.tv_sec = 10;
    timeout.tv_usec = 0;

    FD_ZERO(&fd);
    FD_SET(ssh->sock, &fd);

    dir = libssh2_session_block_directions(ssh->session);

    if (dir & LIBSSH2_SESSION_BLOCK_INBOUND)
        read_fd = &fd;

    if (dir & LIBSSH2_SESSION_BLOCK_OUTBOUND)
        write_fd = &fd;

    rc = select(ssh->sock + 1, read_fd, write_fd, NULL, &timeout);

    return rc;
}

static char *
mrb_ssh_host_to_ip (int family, const char *host)
{
    struct addrinfo *res, *rp;
    struct addrinfo hints;
    static char ipname[INET6_ADDRSTRLEN];
    void *addr;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = family;

    if (getaddrinfo(host, NULL, &hints, &res) != 0)
        return NULL;

    for (rp = res; rp != NULL; rp = rp->ai_next) {
        if (rp->ai_family == AF_INET) {
            addr = (&((struct sockaddr_in *)(rp->ai_addr))->sin_addr);
        } else {
            addr = (&((struct sockaddr_in6 *)(rp->ai_addr))->sin6_addr);
        }

        if (inet_ntop(rp->ai_family, addr, ipname, sizeof(ipname)) != NULL) {
            freeaddrinfo(res);
            return strdup(ipname);
        }
    }

    freeaddrinfo(res);

    return NULL;
}

static int
mrb_ssh_init_socket (int family, const char *host, int port, int *ptr)
{
    struct sockaddr_in sin;
    int sock, rc;
    char *ip;

    sock = socket(family, SOCK_STREAM, 0);

    sin.sin_family = family;
    sin.sin_port   = htons(port);

    if (!(ip = mrb_ssh_host_to_ip(family, host)))
        return -1;

    inet_pton(family, ip, &(sin.sin_addr));
    free(ip);

    rc = connect(sock, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in));

    if (rc != 0) return rc;

    *ptr = sock;

    return 0;
}

static int
mrb_ssh_init_session (int sock, LIBSSH2_SESSION **ptr, int blocking, long timeout, int compress, int sigpipe)
{
    LIBSSH2_SESSION *session;
    int rc;

    session = libssh2_session_init();

    if (!session) {
        mrb_ssh_close_socket(sock);
        return 1;
    }

    libssh2_session_set_blocking(session, blocking);
    libssh2_session_set_timeout(session, timeout);
    libssh2_session_flag(session, LIBSSH2_FLAG_SIGPIPE, sigpipe);
    libssh2_session_flag(session, LIBSSH2_FLAG_COMPRESS, compress);

    while ((rc = libssh2_session_handshake(session, sock)) == LIBSSH2_ERROR_EAGAIN);

    if (rc == 0) {
        *ptr = session;
        libssh2_session_set_last_error(session, 0, NULL);
    } else {
        mrb_ssh_close_socket(sock);
        libssh2_session_free(session);
    }

    return rc;
}

static void
mrb_ssh_raise_unless_connected (mrb_state *mrb, mrb_ssh_t *ssh)
{
    if (ssh && ssh->session) return;
    mrb_raise(mrb, E_RUNTIME_ERROR, "SSH session not connected.");
}

static void
kbd_func (const char *name, int name_len, const char *inst, int inst_len,
          int num_prompts, const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
          LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses, void **abstract)
{
    char *pass = getpass("Password: ");

    (void)name;
    (void)name_len;
    (void)inst;
    (void)inst_len;

    if (num_prompts == 1) {
        responses[0].text   = strdup(pass);
        responses[0].length = strlen(pass);
    }

    (void)prompts;
    (void)abstract;
}

static mrb_value
mrb_ssh_f_connect (mrb_state *mrb, mrb_value self)
{
    mrb_int host_len;
    char* host;
    mrb_value opts;

    mrb_ssh_t *ssh;
    LIBSSH2_SESSION *session;
    int sock, blocking = 1, port = 22, compress = 0, sigpipe = 0;
    long timeout = 15000;

    if (DATA_PTR(self)) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "SSH session already connected.");
    }

    mrb_get_args(mrb, "s|H!", &host, &host_len, &opts);

    if (mrb_hash_p(opts)) {
        port     = (int) mrb_fixnum(mrb_hash_fetch(mrb, opts, mrb_symbol_value(mrb_intern_lit(mrb, "port")), mrb_fixnum_value(port)));
        timeout  = (long)mrb_fixnum(mrb_hash_fetch(mrb, opts, mrb_symbol_value(mrb_intern_lit(mrb, "timeout")), mrb_fixnum_value(timeout)));
        blocking = mrb_type(mrb_hash_fetch(mrb, opts, mrb_symbol_value(mrb_intern_lit(mrb, "block")), mrb_true_value())) == MRB_TT_TRUE;
        compress = mrb_type(mrb_hash_fetch(mrb, opts, mrb_symbol_value(mrb_intern_lit(mrb, "compress")), mrb_false_value())) == MRB_TT_TRUE;
        sigpipe  = mrb_type(mrb_hash_fetch(mrb, opts, mrb_symbol_value(mrb_intern_lit(mrb, "sigpipe")), mrb_false_value())) == MRB_TT_TRUE;
    }

    if (mrb_ssh_init_socket(AF_INET, host, port, &sock) != 0) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "Failed to connect.");
    }

    if (mrb_ssh_init_session(sock, &session, blocking, timeout, compress, sigpipe) != 0) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "Could not init ssh session.");
    }

    ssh            = malloc(sizeof(mrb_ssh_t));
    ssh->sock      = sock;
    ssh->session   = session;

    mrb_data_init(self, ssh, &mrb_ssh_session_type);

    mrb_iv_set(mrb, self, mrb_intern_static(mrb, "@host", 5),
                          mrb_str_new_static(mrb, host, host_len));

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_close (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_session_free(mrb, DATA_PTR(self));

    DATA_PTR(self)  = NULL;
    DATA_TYPE(self) = NULL;

    mrb_iv_set(mrb, self, mrb_intern_static(mrb, "@host", 5),
                          mrb_nil_value());

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_closed (mrb_state *mrb, mrb_value self)
{
    return DATA_PTR(self) && mrb_ssh_initialized() ? mrb_false_value() : mrb_true_value();
}

static mrb_value
mrb_ssh_f_login (mrb_state *mrb, mrb_value self)
{
    mrb_bool pass_given, pass_is_key = FALSE, prompt = TRUE;
    mrb_int user_len = 0, pass_len = 0, phrase_len = 0;
    const char *user, *pass, *phrase = NULL;
    char *pubkey = NULL, *err;
    int ret;

    mrb_ssh_t *ssh = DATA_PTR(self);
    mrb_ssh_raise_unless_connected(mrb, ssh);

    mrb_get_args(mrb, "s|s!?bbs!", &user, &user_len, &pass, &pass_len, &pass_given, &prompt, &pass_is_key, &phrase, &phrase_len);

    if (pass_is_key && pass_given) {
        pubkey = (char *)malloc(sizeof(char) * (pass_len + 4 + 1));
        strcpy(pubkey, pass);
        strncat(pubkey, ".pub", 4);
    }

    if (pass_is_key) {
        while ((ret = libssh2_userauth_publickey_fromfile_ex(ssh->session, user, user_len, pubkey, pass, phrase)) == LIBSSH2_ERROR_EAGAIN);
    } else if (!prompt || (pass_given && pass)) {
        while ((ret = libssh2_userauth_password_ex(ssh->session, user, user_len, pass, pass_len, NULL)) == LIBSSH2_ERROR_EAGAIN);
    } else {
        while ((ret = libssh2_userauth_keyboard_interactive_ex(ssh->session, user, user_len, &kbd_func)) == LIBSSH2_ERROR_EAGAIN);
    }

    free(pubkey);

    switch (ret) {
        case LIBSSH2_ERROR_NONE:
            break;
        case LIBSSH2_ERROR_SOCKET_DISCONNECT:
            mrb_ssh_f_close(mrb, self);
        case LIBSSH2_ERROR_AUTHENTICATION_FAILED:
            libssh2_session_last_error(ssh->session, &err, NULL, 0);
            mrb_raise(mrb, E_RUNTIME_ERROR, err);
    }

    return mrb_nil_value();
}

static mrb_value
mrb_ssh_f_logged (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_t *ssh = DATA_PTR(self);

    if (ssh && libssh2_userauth_authenticated(ssh->session))
        return mrb_true_value();

    return mrb_false_value();
}

static mrb_value
mrb_ssh_f_blocking (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_t *ssh = DATA_PTR(self);

    if (ssh && libssh2_session_get_blocking(ssh->session))
        return mrb_true_value();

    return mrb_false_value();
}

static mrb_value
mrb_ssh_f_last_errno (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_t *ssh = DATA_PTR(self);
    int err;

    if (!ssh) return mrb_nil_value();

    err = libssh2_session_last_errno(ssh->session);

    return mrb_fixnum_value(err);
}

static mrb_value
mrb_ssh_f_last_error (mrb_state *mrb, mrb_value self)
{
    mrb_ssh_t *ssh = DATA_PTR(self);
    int err, len;
    char *msg;

    if (!ssh) return mrb_nil_value();

    err = libssh2_session_last_error(ssh->session, &msg, &len, 0);

    if (err == 0) return mrb_nil_value();

    return mrb_str_new_static(mrb, msg, len);
}

static mrb_value
mrb_ssh_f_fingerprint (mrb_state *mrb, mrb_value self)
{
    char fingerprint[76] = "\0";
    const char *keys;
    char key[4];

    mrb_ssh_t *ssh = DATA_PTR(self);
    mrb_ssh_raise_unless_connected(mrb, ssh);

    keys = libssh2_hostkey_hash(ssh->session, LIBSSH2_HOSTKEY_HASH_SHA1);

    for (int i = 0; i < 20; i++) {
        sprintf(key, "%02X ", (unsigned char)keys[i]);
        strcat(fingerprint, key);
    }

    return mrb_str_new_static(mrb, fingerprint, 59);
}

static mrb_value
mrb_ssh_f_userauth_list (mrb_state *mrb, mrb_value self)
{
    mrb_int user_len;
    char *user, *authlist;

    mrb_ssh_t *ssh = DATA_PTR(self);
    mrb_ssh_raise_unless_connected(mrb, ssh);

    mrb_get_args(mrb, "s", &user, &user_len);

    authlist = libssh2_userauth_list(ssh->session, user, user_len);

    return mrb_str_new_cstr(mrb, authlist);
}

void
mrb_mruby_ssh_session_init (mrb_state *mrb)
{
    struct RClass *ssh, *cls;

    ssh = mrb_module_get(mrb, "SSH");
    cls = mrb_define_class_under(mrb, ssh, "Session", mrb->object_class);

    MRB_SET_INSTANCE_TT(cls, MRB_TT_DATA);

    mrb_define_method(mrb, cls, "connect",     mrb_ssh_f_connect, MRB_ARGS_ARG(1,1));
    mrb_define_method(mrb, cls, "close",       mrb_ssh_f_close,   MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "closed?",     mrb_ssh_f_closed,  MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "login",       mrb_ssh_f_login,   MRB_ARGS_ARG(1,4));
    mrb_define_method(mrb, cls, "logged_in?",  mrb_ssh_f_logged,  MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "blocking?",   mrb_ssh_f_blocking,MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "last_errno",  mrb_ssh_f_last_errno, MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "last_error",  mrb_ssh_f_last_error, MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "fingerprint", mrb_ssh_f_fingerprint, MRB_ARGS_NONE());
    mrb_define_method(mrb, cls, "userauth_list", mrb_ssh_f_userauth_list, MRB_ARGS_REQ(1));
}
