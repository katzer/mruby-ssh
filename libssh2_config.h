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

/* Use mbedtls */
#define LIBSSH2_MBEDTLS 1

/* Enable debugging and activate tracing */
#ifdef MRB_SSH_DEBUG
# define LIBSSH2DEBUG 1
#endif

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1
/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1
/* Define to 1 if the compiler supports the 'long long' data type. */
#define HAVE_LONGLONG 1
/* Define to 1 if you have the select function. */
#define HAVE_SELECT 1
/* Define to 1 if you have the `strtoll' function. */
#define HAVE_STRTOLL 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1
/* Define to 1 if you have the <netinet/in.h> header file. */
#define HAVE_NETINET_IN_H 1
/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1
/* Define to 1 if you have the <errno.h> header file. */
#define HAVE_ERRNO_H 1
/* Define to 1 if you have the <fcntl.h> header file. */
#define HAVE_FCNTL_H 1
/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1
/* Define to 1 if you have the <stdio.h> header file. */
#define HAVE_STDIO_H 1
/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1
/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1
/* Enable newer diffie-hellman-group-exchange-sha1 syntax */
#define LIBSSH2_DH_GEX_NEW 1

#ifdef __MINGW32__
/* Define to 1 if you have the <unistd.h> header file. */
# define HAVE_UNISTD_H 1
/* Define to 1 if you have the <sys/time.h> header file. */
# define HAVE_SYS_TIME_H 1
/* Define to 1 if you have the `gettimeofday' function. */
# define HAVE_GETTIMEOFDAY 1
#endif

#ifdef _WIN32
/* Define to 1 if you have the <windows.h> header file. */
# define HAVE_WINDOWS_H 1
/* Define to 1 if you have the <ws2tcpip.h> header file. */
# define HAVE_WS2TCPIP_H 1
/* Define to 1 if you have the <winsock2.h> header file. */
# define HAVE_WINSOCK2_H 1
/* use ioctlsocket() for non-blocking sockets */
# define HAVE_IOCTLSOCKET 1
#else
/* Define to 1 if you have the <unistd.h> header file. */
# define HAVE_UNISTD_H 1
/* Define to 1 if you have the <sys/time.h> header file. */
# define HAVE_SYS_TIME_H 1
/* Define to 1 if you have the `gettimeofday' function. */
# define HAVE_GETTIMEOFDAY 1
/* Define to 1 if you have the <sys/select.h> header file. */
# define HAVE_SYS_SELECT_H 1
/* Define to 1 if you have the <sys/uio.h> header file. */
# define HAVE_SYS_UIO_H 1
/* Define to 1 if you have the <sys/socket.h> header file. */
# define HAVE_SYS_SOCKET_H 1
/* Define to 1 if you have the <sys/ioctl.h> header file. */
# define HAVE_SYS_IOCTL_H 1
/* Define to 1 if you have the <sys/un.h> header file. */
# define HAVE_SYS_UN_H 1
/* Define to 1 if you have the <sys/stat.h> header file. */
# define HAVE_SYS_STAT_H 1
/* Define to 1 if you have the <sys/types.h> header file. */
# define HAVE_SYS_TYPES_H 1
/* Define to 1 if you have the `poll' function. */
# define HAVE_POLL 1
/* use O_NONBLOCK for non-blocking sockets */
# define HAVE_O_NONBLOCK 1
/* Define to 1 if you have the <arpa/inet.h> header file. */
# define HAVE_ARPA_INET_H 1
/* Define to 1 if you have `alloca', as a function or macro. */
# define HAVE_ALLOCA 1
/* Define to 1 if you have <alloca.h> and it should be used (not on Ultrix). */
# define HAVE_ALLOCA_H 1
#endif

/* Enable large inode numbers on Mac OS X 10.5.  */
#ifndef _DARWIN_USE_64_BIT_INODE
# define _DARWIN_USE_64_BIT_INODE 1
#endif
