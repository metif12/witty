#ifndef WITTY_STREAM_DISCARD_FIXTURES_H
#define WITTY_STREAM_DISCARD_FIXTURES_H
#include <stddef.h>
#ifdef WITTY_STREAM_DISCARD_DECLARATIONS
int witty_stream_discard_setup(const char *);
int witty_stream_discard_replace(int);
int witty_stream_discard_seed(size_t,size_t);
int witty_stream_discard_shutdown(void);
int witty_stream_discard_cleanup(void);
int witty_stream_discard_close(void);
int witty_stream_discard_restore(const char *,size_t);
int witty_stream_discard_valid(void);
int witty_stream_discard_refs(void);
ptrdiff_t witty_stream_discard_drain(unsigned char *,size_t);
#else
#ifdef WITTY_STREAM_DISCARD_NATIVE
#define WITTY_STREAM_DISCARD_LINKAGE
#else
#define WITTY_STREAM_DISCARD_LINKAGE static
#endif
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
static int witty_stream_discard_fd=-1,witty_stream_discard_pipe[2]={-1,-1};
static struct stat witty_stream_discard_identity[2];
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_setup(const char *path) {
    int fd=open(path,O_RDWR|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if(fd<0)return -1;
    witty_stream_discard_fd=fd;
    if(unlink(path)!=0)return -1;
    unsigned char data[2048];for(size_t i=0;i<sizeof(data);++i)data[i]=(unsigned char)(i*31+7);
    if(write(fd,data,sizeof(data))!=(ptrdiff_t)sizeof(data))return -1;
    if(pipe(witty_stream_discard_pipe)!=0)return -1;
    if(fd>=128 || witty_stream_discard_pipe[0]>=128 || witty_stream_discard_pipe[1]>=128)return -1;
    for(int i=0;i<2;++i)if(fcntl(witty_stream_discard_pipe[i],F_SETFL,O_NONBLOCK)!=0 || fcntl(witty_stream_discard_pipe[i],F_SETFD,FD_CLOEXEC)!=0)return -1;
    if(fstat(witty_stream_discard_pipe[0],&witty_stream_discard_identity[0])!=0 || fstat(witty_stream_discard_pipe[1],&witty_stream_discard_identity[1])!=0)return -1;
    return fd;
}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_replace(int writing) {
    return dup2(witty_stream_discard_pipe[writing!=0],witty_stream_discard_fd)==witty_stream_discard_fd?0:-1;
}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_seed(size_t start,size_t count) {
    unsigned char data[4096];if(count>sizeof(data))return -1;
    for(size_t i=0;i<count;++i)data[i]=(unsigned char)((i+start)*31+7);
    return write(witty_stream_discard_pipe[1],data,count)==(ptrdiff_t)count?0:-1;
}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_shutdown(void) {
    if(close(witty_stream_discard_pipe[1])!=0)return -1;
    witty_stream_discard_pipe[1]=-1;return 0;
}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_valid(void) {return fcntl(witty_stream_discard_fd,F_GETFD)>=0?1:0;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_refs(void) {
    struct stat st;int count=0;
    for(int fd=0;fd<128;++fd)if(fstat(fd,&st)==0 &&
       ((st.st_dev==witty_stream_discard_identity[0].st_dev && st.st_ino==witty_stream_discard_identity[0].st_ino) ||
        (st.st_dev==witty_stream_discard_identity[1].st_dev && st.st_ino==witty_stream_discard_identity[1].st_ino)))++count;
    return count;
}
WITTY_STREAM_DISCARD_LINKAGE ptrdiff_t witty_stream_discard_drain(unsigned char *bytes,size_t count) {
    ptrdiff_t n=read(witty_stream_discard_pipe[0],bytes,count);
    if(n>=0)return n;
    return errno==EAGAIN||errno==EWOULDBLOCK?-1:-2;
}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_restore(const char *path,size_t length) {
    if(length>4096)return -1;
    int fd=open(path,O_RDWR|O_CREAT|O_EXCL|O_CLOEXEC,0600);if(fd<0)return -1;
    if(unlink(path)!=0){close(fd);return -1;}
    unsigned char data[4096];for(size_t i=0;i<length;++i)data[i]=(unsigned char)(i*37+19);
    if(write(fd,data,length)!=(ptrdiff_t)length || lseek(fd,0,SEEK_SET)<0){close(fd);return -1;}
    int result=dup2(fd,witty_stream_discard_fd)==witty_stream_discard_fd?0:-1;
    if(close(fd)!=0)return -1;return result;
}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_close(void) {return close(witty_stream_discard_fd);}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_cleanup(void) {
    int result=0;
    if(witty_stream_discard_fd>=0 && fcntl(witty_stream_discard_fd,F_GETFD)>=0 && close(witty_stream_discard_fd)!=0)result=-1;
    witty_stream_discard_fd=-1;
    for(int i=0;i<2;++i) {if(witty_stream_discard_pipe[i]>=0 && close(witty_stream_discard_pipe[i])!=0)result=-1;witty_stream_discard_pipe[i]=-1;}
    return result;
}
#else
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_setup(const char *p) {(void)p;return -1;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_replace(int w) {(void)w;return -1;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_seed(size_t s,size_t n) {(void)s;(void)n;return -1;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_shutdown(void) {return -1;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_cleanup(void) {return -1;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_close(void) {return -1;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_restore(const char *p,size_t n) {(void)p;(void)n;return -1;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_valid(void) {return 0;}
WITTY_STREAM_DISCARD_LINKAGE int witty_stream_discard_refs(void) {return -1;}
WITTY_STREAM_DISCARD_LINKAGE ptrdiff_t witty_stream_discard_drain(unsigned char *p,size_t n) {(void)p;(void)n;return -2;}
#endif
#undef WITTY_STREAM_DISCARD_LINKAGE
#endif
#endif
