#ifndef poll_socket_wepoll_h
#define poll_socket_wepoll_h

#include "skynet.h"

#pragma comment(lib, "ws2_32.lib")

static bool sp_invalid(poll_fd efd) { return efd == 0; }

static poll_fd sp_create() { return epoll_create(1024); }

static void sp_release(poll_fd efd) { epoll_close(efd); }

static int sp_add(poll_fd efd, SOCKET sock, void *ud) {
  struct epoll_event ev;
  ev.events = EPOLLIN;
  ev.data.ptr = ud;
  if (epoll_ctl(efd, EPOLL_CTL_ADD, sock, &ev) == -1) {
    return 1;
  }
  return 0;
}

static void sp_del(poll_fd efd, SOCKET sock) {
  epoll_ctl(efd, EPOLL_CTL_DEL, sock, NULL);
}

static int sp_enable(poll_fd efd, SOCKET sock, void *ud, bool read_enable,
                     bool write_enable) {
  struct epoll_event ev;
  ev.events = (read_enable ? EPOLLIN : 0) | (write_enable ? EPOLLOUT : 0);
  ev.data.ptr = ud;
  if (epoll_ctl(efd, EPOLL_CTL_MOD, sock, &ev) == -1) {
    return 1;
  }
  return 0;
}

static int sp_wait(poll_fd efd, struct event *e, int max) {
  struct epoll_event *ev =
      (struct epoll_event *)skynet_malloc(sizeof(struct epoll_event *) * max);
  int n = epoll_wait(efd, ev, max, -1);
  int i;
  for (i = 0; i < n; i++) {
    e[i].s = ev[i].data.ptr;
    unsigned flag = ev[i].events;
    e[i].write = (flag & EPOLLOUT) != 0;
    e[i].read = (flag & EPOLLIN) != 0;
    e[i].error = (flag & EPOLLERR) != 0;
    e[i].eof = (flag & EPOLLHUP) != 0;
  }
  skynet_free(ev);
  return n;
}

static void sp_nonblocking(SOCKET sock) {
  // https://learn.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-ioctlsocket
  u_long iMode = 1;
  int iResult = ioctlsocket(sock, FIONBIO, &iMode);
  if (iResult != NO_ERROR) {
    printf("ioctlsocket failed with error: %d\n", iResult);
  }
}

#endif
