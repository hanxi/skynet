#pragma once
#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
// #define _WINSOCK_DEPRECATED_NO_WARNINGS
// #include <WinSock2.h>

#define random rand
#define srandom srand
#define snprintf _snprintf

#define pid_t int

pid_t getpid();
int kill(pid_t pid, int exit_code);

void usleep(size_t us);
void sleep(size_t ms);

enum { CLOCK_THREAD_CPUTIME_ID, CLOCK_REALTIME, CLOCK_MONOTONIC };
int clock_gettime(int what, struct timespec *ti);

enum { LOCK_EX, LOCK_NB };
int flock(int fd, int flag);

struct sigaction {
  void (*sa_handler)(int);
  int sa_flags;
  int sa_mask;
};
enum { SIGPIPE, SIGHUP, SA_RESTART };
void sigfillset(int *flag);
void sigaction(int flag, struct sigaction *action, int param);

int pipe(int fd[2]);
int daemon(int a, int b);

char *strsep(char **stringp, const char *delim);

int write(int fd, const void *ptr, size_t sz);
int read(int fd, void *buffer, size_t sz);
int close(int fd);
