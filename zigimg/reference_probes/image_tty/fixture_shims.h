#ifndef WITTY_IMAGE_TTY_FIXTURES_H
#define WITTY_IMAGE_TTY_FIXTURES_H
#include <stddef.h>
#ifdef WITTY_IMAGE_TTY_DECLARATIONS
int witty_image_tty_keeper_fd(void);
int witty_image_tty_positional_error(int);
int witty_image_tty_setup(void);
const char *witty_image_tty_path(void);
int witty_image_tty_cleanup(void);
int witty_image_tty_state(void);
int witty_image_tty_session(void);
int witty_image_tty_refs(void);
int witty_image_tty_raw(int,int);
int witty_image_tty_raw_close(int);
ptrdiff_t witty_image_tty_seed(const unsigned char *,size_t);
ptrdiff_t witty_image_tty_read(int,unsigned char *,size_t);
#else
#ifdef WITTY_IMAGE_TTY_NATIVE
#define WITTY_IMAGE_TTY_LINKAGE
#else
#define WITTY_IMAGE_TTY_LINKAGE static
#endif
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <termios.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <poll.h>
static int witty_image_tty_master=-1,witty_image_tty_keeper=-1;
static char witty_image_tty_name[4096];
static struct sigaction witty_image_tty_previous_hup;
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_session(void) { return getsid(0)==getpid() && getpgrp()==getpid(); }
/* /dev/tty is opened with NOCTTY only to inspect this fixture's isolated session.
   A controlling tty is owned only when the keeper's foreground group is ours. */
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_state(void) {
    int fd=open("/dev/tty",O_RDONLY|O_NOCTTY|O_NONBLOCK|O_CLOEXEC);
    if(fd<0) return errno==ENXIO||errno==ENOENT?0:-1;
    pid_t group=tcgetpgrp(fd),owned=tcgetpgrp(witty_image_tty_keeper);close(fd);
    return group==getpgrp() && owned==group?1:2;
}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_refs(void) {
    struct stat target,st;if(fstat(witty_image_tty_keeper,&target)!=0)return -1;
    int count=0;
    for(int fd=0;fd<128;++fd) if(fstat(fd,&st)==0 && st.st_dev==target.st_dev && st.st_ino==target.st_ino && st.st_rdev==target.st_rdev) ++count;
    return count;
}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_keeper_fd(void) { return witty_image_tty_keeper; }
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_positional_error(int writing) {
    unsigned char byte=127;
    ptrdiff_t n=writing?pwrite(witty_image_tty_keeper,&byte,1,0):pread(witty_image_tty_keeper,&byte,1,0);
    return n<0 && errno==ENXIO?1:0;
}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_setup(void) {
    if(witty_image_tty_master>=0 || witty_image_tty_keeper>=0) return -1;
    if(!witty_image_tty_session() && setsid()<0) return -1;
    /* Never detach or alter a controlling terminal that this fixture did not own. */
    int existing=open("/dev/tty",O_RDONLY|O_NOCTTY|O_CLOEXEC);
    if(existing>=0) { close(existing);return -1; }
    if(errno!=ENXIO && errno!=ENOENT) return -1;
    struct sigaction ignored;memset(&ignored,0,sizeof(ignored));ignored.sa_handler=SIG_IGN;sigemptyset(&ignored.sa_mask);
    if(sigaction(SIGHUP,&ignored,&witty_image_tty_previous_hup)!=0) return -1;
    witty_image_tty_master=posix_openpt(O_RDWR|O_NOCTTY|O_NONBLOCK|O_CLOEXEC);
    if(witty_image_tty_master<0 || grantpt(witty_image_tty_master)!=0 || unlockpt(witty_image_tty_master)!=0)return -1;
    const char *name=ptsname(witty_image_tty_master);
    if(!name || strlen(name)>=sizeof(witty_image_tty_name)) return -1;
    strcpy(witty_image_tty_name,name);
    witty_image_tty_keeper=open(name,O_RDWR|O_NOCTTY|O_NONBLOCK|O_CLOEXEC);
    if(witty_image_tty_keeper<0 || witty_image_tty_keeper>=128 || witty_image_tty_master>=128) return -1;
    struct termios attributes;
    if(tcgetattr(witty_image_tty_keeper,&attributes)!=0)return -1;
    cfmakeraw(&attributes);
    if(tcsetattr(witty_image_tty_keeper,TCSANOW,&attributes)!=0)return -1;
    return witty_image_tty_state()==0?0:-1;
}
WITTY_IMAGE_TTY_LINKAGE const char *witty_image_tty_path(void) { return witty_image_tty_name; }
WITTY_IMAGE_TTY_LINKAGE ptrdiff_t witty_image_tty_seed(const unsigned char *bytes,size_t len) {
    if(write(witty_image_tty_master,bytes,len)!=(ptrdiff_t)len)return -1;
    if(len) {
        struct pollfd ready={witty_image_tty_keeper,POLLIN,0};
        int n;do {n=poll(&ready,1,1000);}while(n<0 && errno==EINTR);
        if(n!=1 || !(ready.revents&POLLIN))return -1;
    }
    return (ptrdiff_t)len;
}
WITTY_IMAGE_TTY_LINKAGE ptrdiff_t witty_image_tty_read(int input,unsigned char *bytes,size_t len) {
    ptrdiff_t n=read(input?witty_image_tty_keeper:witty_image_tty_master,bytes,len);
    if(n>=0)return n;
    return errno==EAGAIN||errno==EWOULDBLOCK?-1:-2;
}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_raw(int writing,int noctty) {
    return open(witty_image_tty_name,(writing?O_WRONLY|O_CREAT|O_TRUNC:O_RDONLY)|O_CLOEXEC|(noctty?O_NOCTTY:0),0666);
}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_raw_close(int fd) { return close(fd); }
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_cleanup(void) {
    int state=witty_image_tty_state();
    if(state<0 || state==2)return -1;
    /* Darwin session leaders cannot use TIOCNOTTY. Each case runs in its own
       process; close only our handles and let process exit release the session.
       Do not reopen /dev/tty after the master has been destroyed. */
    if(close(witty_image_tty_keeper)!=0 || close(witty_image_tty_master)!=0) return -1;
    witty_image_tty_keeper=-1;witty_image_tty_master=-1;
    if(sigaction(SIGHUP,&witty_image_tty_previous_hup,NULL)!=0)return -1;
    return 0;
}
#else
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_keeper_fd(void) {return -1;}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_positional_error(int w) {(void)w;return 0;}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_setup(void) {return -1;}
WITTY_IMAGE_TTY_LINKAGE const char *witty_image_tty_path(void) {return "";}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_cleanup(void) {return -1;}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_state(void) {return -1;}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_session(void) {return 0;}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_refs(void) {return -1;}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_raw(int w,int n) {(void)w;(void)n;return -1;}
WITTY_IMAGE_TTY_LINKAGE int witty_image_tty_raw_close(int f) {(void)f;return -1;}
WITTY_IMAGE_TTY_LINKAGE ptrdiff_t witty_image_tty_seed(const unsigned char *b,size_t n) {(void)b;(void)n;return -1;}
WITTY_IMAGE_TTY_LINKAGE ptrdiff_t witty_image_tty_read(int i,unsigned char *b,size_t n) {(void)i;(void)b;(void)n;return -2;}
#endif
#undef WITTY_IMAGE_TTY_LINKAGE
#endif
#endif
