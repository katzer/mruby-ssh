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

#define HAVE_UNISTD_H
#define HAVE_INTTYPES_H
#define HAVE_STDLIB_H
#define HAVE_SYS_TIME_H
#define HAVE_LONGLONG
#define HAVE_GETTIMEOFDAY
#define HAVE_INET_ADDR
#define HAVE_SELECT
#define HAVE_SOCKET
#define HAVE_STRTOLL
#define HAVE_SNPRINTF

#ifdef _WIN32
# define HAVE_WINDOWS_H
# define HAVE_WS2TCPIP_H
# define HAVE_WINSOCK2_H
# define HAVE_IOCTLSOCKET
#else
# define _GNU_SOURCE
# define HAVE_SYS_SELECT_H
# define HAVE_SYS_UIO_H
# define HAVE_SYS_SOCKET_H
# define HAVE_SYS_IOCTL_H
# define HAVE_SYS_UN_H
# define HAVE_POLL
# define HAVE_O_NONBLOCK
#endif

#define LIBSSH2_MBEDTLS