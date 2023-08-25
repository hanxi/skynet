#ifndef socket_poll_h
#define socket_poll_h

#include <stdbool.h>

struct event {
	void * s;
	bool read;
	bool write;
	bool error;
	bool eof;
};

#if defined(_MSC_VER)

#include "wepoll.h"
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

#define ssize_t size_t
typedef HANDLE poll_fd;

static bool sp_invalid(poll_fd fd);
static poll_fd sp_create();
static void sp_release(poll_fd fd);
static int sp_add(poll_fd fd, SOCKET sock, void* ud);
static void sp_del(poll_fd fd, SOCKET sock);
static int sp_enable(poll_fd, SOCKET sock, void *ud, bool read_enable, bool write_enable);
static int sp_wait(poll_fd, struct event* e, int max);
static void sp_nonblocking(SOCKET sock);

  #include "socket_wepoll.h"

#else

typedef int poll_fd;

static bool sp_invalid(poll_fd fd);
static poll_fd sp_create();
static void sp_release(poll_fd fd);
static int sp_add(poll_fd fd, int sock, void *ud);
static void sp_del(poll_fd fd, int sock);
static int sp_enable(poll_fd, int sock, void *ud, bool read_enable, bool write_enable);
static int sp_wait(poll_fd, struct event *e, int max);
static void sp_nonblocking(int sock);

#ifdef __linux__
  #include "socket_epoll.h"
#endif

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined (__NetBSD__)
  #include "socket_kqueue.h"
#endif

#endif

#endif

