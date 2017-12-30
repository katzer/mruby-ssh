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

#define _WIN32_WINNT _WIN32_WINNT_VISTA

#ifdef _WIN32
# include <winsock2.h>
# include <ws2tcpip.h>
# include <windows.h>
#else
# include <sys/socket.h>
# include <arpa/inet.h>
# include <netdb.h>
# include <unistd.h>
# include <netinet/in.h>
#endif

#include <libssh2.h>
#include <libssh2_sftp.h>
#include <stdlib.h>

#include "mruby.h"
#include "mruby/array.h"
#include "mruby/data.h"
#include "mruby/error.h"
#include "mruby/variable.h"

struct sftp_session
{
    LIBSSH2_SESSION *ssh_session;
    LIBSSH2_SFTP    *sftp_session;
    int sock;
};

static char *
mrb_ssh_host_to_ai_addr (int family, const char *host)
{
    struct addrinfo *res, *rp;
    struct addrinfo hints;
    static char ipname[INET6_ADDRSTRLEN];
    void *addr;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = family;

    if (getaddrinfo(host, NULL, &hints, &res) != 0)
        return NULL;

    for (rp=res; rp!=NULL; rp=rp->ai_next) {
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

    ip = mrb_ssh_host_to_ai_addr(family, host);
    inet_pton(family, ip, &(sin.sin_addr));
    free(ip);

    rc = connect(sock, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in));

    if (rc != 0) return rc;

    *ptr = sock;

    return 0;
}

static void
mrb_ssh_close_socket (int sock) {
#ifdef WIN32
    closesocket(sock);
#else
    close(sock);
#endif
}

static int
mrb_ssh_init_session (int sock, LIBSSH2_SESSION **ptr)
{
    LIBSSH2_SESSION *session;
    int rc;

    session = libssh2_session_init();

    if (!session) return 2;

    libssh2_session_set_blocking(session, 1);

    rc = libssh2_session_handshake(session, sock);

    if (rc != 0) return rc;

    *ptr = session;

    return 0;
}

static void
mrb_ssh_close_session (LIBSSH2_SESSION **session)
{
    libssh2_session_disconnect(*session, NULL);
    libssh2_session_free(*session);
}

static LIBSSH2_SFTP_HANDLE*
mrb_sftp_get_handle (mrb_state *mrb, mrb_value self, char **path, int *path_len)
{
    mrb_int dir_len, argc;
    mrb_bool dir_given;
    char *dir;

    struct sftp_session *session = DATA_PTR(self);
    LIBSSH2_SFTP *sftp_session;
    LIBSSH2_SFTP_HANDLE *sftp_handle;

    if (!session) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "Session not connected.");
    }

    sftp_session = session->sftp_session;

    if (!sftp_session) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "Session not authenticated.");
    }

    mrb_get_args(mrb, "|s?", &dir, &dir_len, &dir_given, &argc);

    if (!dir_given) {
        dir     = "";
        dir_len = 0;
    }

    if (dir_len > 1 && dir[dir_len - 1] == '/') {
        dir[--dir_len] = 0;
    }

    sftp_handle = libssh2_sftp_opendir(sftp_session, dir);

    if (!sftp_handle) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "The system cannot find the dir specified.");
    }

    if (path)
        *path = dir;

    if (path_len)
        *path_len = dir_len;

    return sftp_handle;
}

static int
mrb_sftp_join_path (char *buf, char *pref, int pref_len, char *path)
{
    if (pref_len == 0) {
        return sprintf(buf, "%s", path);
    } else
    if (pref_len == 1 && pref[0] == '/') {
        return sprintf(buf, "/%s", path);
    } else {
        return sprintf(buf, "%s/%s", pref, path);
    }
}

static mrb_value
mrb_sftp_f_connect (mrb_state *mrb, mrb_value self)
{
    mrb_int port, host_len, argc;
    char* host;

    struct sftp_session *session;
    LIBSSH2_SESSION *ssh_session;
    int sock;

    mrb_get_args(mrb, "si", &host, &host_len, &port, &argc);

    if (mrb_ssh_init_socket(AF_INET, host, port, &sock) != 0) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "Failed to connect.");
    }

    if (mrb_ssh_init_session(sock, &ssh_session) != 0) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "Could not init ssh session.");
    }

    session               = malloc(sizeof(struct sftp_session));
    session->ssh_session  = ssh_session;
    session->sftp_session = NULL;
    session->sock         = sock;
    DATA_PTR(self)        = session;

    mrb_iv_set(mrb, self, mrb_intern_lit(mrb, "@host"),
                          mrb_str_new(mrb, host, host_len));

    return mrb_nil_value();
}

static mrb_value
mrb_sftp_f_close (mrb_state *mrb, mrb_value self)
{
    struct sftp_session *session = DATA_PTR(self);

    if (!session)
        return mrb_nil_value();

    libssh2_sftp_shutdown(session->sftp_session);
    mrb_ssh_close_session(&session->ssh_session);
    mrb_ssh_close_socket(session->sock);
    free(session);

    DATA_PTR(self) = NULL;

    mrb_iv_set(mrb, self, mrb_intern_lit(mrb, "@host"),
                          mrb_nil_value());

    return mrb_nil_value();
}

static mrb_value
mrb_sftp_f_closed (mrb_state *mrb, mrb_value self)
{
    struct sftp_session *session = DATA_PTR(self);
    return session ? mrb_false_value() : mrb_true_value();
}

static mrb_value
mrb_sftp_f_logged (mrb_state *mrb, mrb_value self)
{
    struct sftp_session *session = DATA_PTR(self);

    if (session && libssh2_userauth_authenticated(session->ssh_session))
        return mrb_true_value();

    return mrb_false_value();
}

static mrb_value
mrb_sftp_f_login (mrb_state *mrb, mrb_value self)
{
    mrb_int user_len, pass_len, argc;
    mrb_bool user_given, pass_given;
    char *user, *pass;

    struct sftp_session *session = DATA_PTR(self);
    LIBSSH2_SESSION *ssh_session;

    if (!session) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "Session not connected.");
    }

    ssh_session = session->ssh_session;

    mrb_get_args(mrb, "|s?s?", &user, &user_len, &user_given, &pass, &pass_len, &pass_given, &argc);

    if (!user_given) {
        user     = "anonymus";
        user_len = 8;
    }

    if (!pass_given) {
        pass     = NULL;
        pass_len = 0;
    }

    switch (libssh2_userauth_password_ex(ssh_session, user, user_len, pass, pass_len, NULL)) {
        case LIBSSH2_ERROR_SOCKET_DISCONNECT:
            mrb_sftp_f_close(mrb, self);
            mrb_raise(mrb, E_RUNTIME_ERROR, "Session not connected.");
        case LIBSSH2_ERROR_AUTHENTICATION_FAILED:
            mrb_raise(mrb, E_RUNTIME_ERROR, "Authentication failed.");
    }

    session->sftp_session = libssh2_sftp_init(ssh_session);

    if (!session->sftp_session) {
        char *msg;
        libssh2_session_last_error(ssh_session, &msg, NULL, 0);
        mrb_raise(mrb, E_RUNTIME_ERROR, msg);
    }

    return mrb_nil_value();
}

static mrb_value
mrb_sftp_f_list (mrb_state *mrb, mrb_value self)
{
    LIBSSH2_SFTP_HANDLE *handle;
    mrb_value entries;

    handle  = mrb_sftp_get_handle(mrb, self, NULL, NULL);
    entries = mrb_ary_new(mrb);

    do {
        char mem[512];
        char longentry[512];
        int mem_len;

        mem_len = libssh2_sftp_readdir_ex(handle, mem, sizeof(mem), longentry, sizeof(longentry), NULL);

        if (mem_len <= 0)
            break;

        if (mem_len == 1 && mem[0] == '.')
            continue;

        if (mem_len == 2 && mem[0] == '.' && mem[0] == mem[1])
            continue;

        mrb_ary_push(mrb, entries, mrb_str_new_cstr(mrb, longentry));
    } while (1);

    libssh2_sftp_closedir(handle);

    return entries;
}

static mrb_value
mrb_sftp_f_entries (mrb_state *mrb, mrb_value self)
{
    char *dir;
    int dir_len;
    mrb_value entries;
    LIBSSH2_SFTP_HANDLE *handle;

    handle  = mrb_sftp_get_handle(mrb, self, &dir, &dir_len);
    entries = mrb_ary_new(mrb);

    do {
        char mem[512];
        int  mem_len, path_len;

        mem_len = libssh2_sftp_readdir(handle, mem, sizeof(mem), NULL);

        if (mem_len <= 0)
            break;

        if (mem_len == 1 && mem[0] == '.')
            continue;

        if (mem_len == 2 && mem[0] == '.' && mem[0] == mem[1])
            continue;

        char path[mem_len + 1 + dir_len];
        path_len = mrb_sftp_join_path(path, dir, dir_len, mem);

        mrb_ary_push(mrb, entries, mrb_str_new(mrb, path, path_len));
    } while (1);

    libssh2_sftp_closedir(handle);

    return entries;
}

static mrb_value
mrb_ssh_f_last_errno (mrb_state *mrb, mrb_value self)
{
    struct sftp_session *session = DATA_PTR(self);
    int err;

    if (!session) return mrb_nil_value();

    err = libssh2_session_last_errno(session->ssh_session);

    if (err == LIBSSH2_ERROR_SFTP_PROTOCOL && session->sftp_session) {
        err = libssh2_sftp_last_error(session->sftp_session);
    }

    return mrb_fixnum_value(err);
}

static mrb_value
mrb_ssh_f_last_error (mrb_state *mrb, mrb_value self)
{
    struct sftp_session *session = DATA_PTR(self);
    char *msg;
    int err, len;

    if (!session) return mrb_nil_value();

    err = libssh2_session_last_error(session->ssh_session, &msg, &len, 0);

    if (err == 0) return mrb_nil_value();

    return mrb_str_new(mrb, msg, len);
}

void
mrb_mruby_ssh_gem_init (mrb_state *mrb)
{
    struct RClass *ftp;

    if (libssh2_init(0) != 0) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "libssh2_init failed");
    }

#ifdef _WIN32
    WSADATA wsaData;

    if (WSAStartup(MAKEWORD(2,2), &wsaData) != 0) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "WSAStartup failed");
    }
#endif

    ftp = mrb_define_class(mrb, "SFTP", mrb->object_class);

    mrb_define_method(mrb, ftp, "connect", mrb_sftp_f_connect, MRB_ARGS_ARG(1,1));
    mrb_define_method(mrb, ftp, "login",   mrb_sftp_f_login,   MRB_ARGS_OPT(2));
    mrb_define_method(mrb, ftp, "logged_in?", mrb_sftp_f_logged, MRB_ARGS_NONE());
    mrb_define_method(mrb, ftp, "list",    mrb_sftp_f_list,    MRB_ARGS_OPT(1));
    mrb_define_method(mrb, ftp, "entries", mrb_sftp_f_entries, MRB_ARGS_OPT(1));
    mrb_define_method(mrb, ftp, "close",   mrb_sftp_f_close,   MRB_ARGS_NONE());
    mrb_define_method(mrb, ftp, "closed?", mrb_sftp_f_closed,  MRB_ARGS_NONE());
    mrb_define_method(mrb, ftp, "last_error", mrb_ssh_f_last_error, MRB_ARGS_NONE());
    mrb_define_method(mrb, ftp, "last_errno", mrb_ssh_f_last_errno, MRB_ARGS_NONE());

    mrb_define_alias(mrb, ftp, "ls", "list");
    mrb_define_alias(mrb, ftp, "dir", "list");

    mrb_define_const(mrb, ftp, "TIMEOUT_ERROR",        mrb_fixnum_value(LIBSSH2_ERROR_TIMEOUT));
    mrb_define_const(mrb, ftp, "DISCONNECT_ERROR",     mrb_fixnum_value(LIBSSH2_ERROR_SOCKET_DISCONNECT));
    mrb_define_const(mrb, ftp, "AUTHENTICATION_ERROR", mrb_fixnum_value(LIBSSH2_ERROR_AUTHENTICATION_FAILED));
    mrb_define_const(mrb, ftp, "NO_SUCH_FILE_ERROR",   mrb_fixnum_value(LIBSSH2_FX_NO_SUCH_FILE));
    mrb_define_const(mrb, ftp, "NO_SUCH_PATH_ERROR",   mrb_fixnum_value(LIBSSH2_FX_NO_SUCH_PATH));
    mrb_define_const(mrb, ftp, "PERMISSION_ERROR",     mrb_fixnum_value(LIBSSH2_FX_PERMISSION_DENIED));
    mrb_define_const(mrb, ftp, "FILE_EXIST_ERROR",     mrb_fixnum_value(LIBSSH2_FX_FILE_ALREADY_EXISTS));
    mrb_define_const(mrb, ftp, "WRITE_PROTECT_ERROR",  mrb_fixnum_value(LIBSSH2_FX_WRITE_PROTECT));
    mrb_define_const(mrb, ftp, "WRITE_PROTECT_ERROR",  mrb_fixnum_value(LIBSSH2_FX_WRITE_PROTECT));
    mrb_define_const(mrb, ftp, "OUT_OF_SPACE_ERROR",   mrb_fixnum_value(LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM));
    mrb_define_const(mrb, ftp, "OUT_OF_SPACE_ERROR",   mrb_fixnum_value(LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM));
    mrb_define_const(mrb, ftp, "DIR_NOT_EMPTY_ERROR",  mrb_fixnum_value(LIBSSH2_FX_DIR_NOT_EMPTY));
    mrb_define_const(mrb, ftp, "NOT_A_DIR_ERROR",      mrb_fixnum_value(LIBSSH2_FX_NOT_A_DIRECTORY));
    mrb_define_const(mrb, ftp, "INVALID_NAME_ERROR",   mrb_fixnum_value(LIBSSH2_FX_INVALID_FILENAME));
    mrb_define_const(mrb, ftp, "LINK_LOOP_ERROR",      mrb_fixnum_value(LIBSSH2_FX_LINK_LOOP));
    mrb_define_const(mrb, ftp, "NO_CONNECTION_ERROR",  mrb_fixnum_value(LIBSSH2_FX_NO_CONNECTION));
    mrb_define_const(mrb, ftp, "EOF",                  mrb_fixnum_value(LIBSSH2_FX_EOF));
}

void
mrb_mruby_ssh_gem_final (mrb_state *mrb)
{
#ifdef _WIN32
    WSACleanup();
#endif
    libssh2_exit();
}
