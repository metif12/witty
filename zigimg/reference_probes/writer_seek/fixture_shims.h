#ifndef WITTY_WRITER_SEEK_FIXTURES_H
#define WITTY_WRITER_SEEK_FIXTURES_H
#include <stddef.h>
#ifdef WITTY_WRITER_SEEK_DECLARATIONS
int witty_writer_seek_setup(const char *);
int witty_writer_seek_replace(int);
int witty_writer_seek_seed(size_t,size_t);
int witty_writer_seek_shutdown(void);
int witty_writer_seek_cleanup(void);
int witty_writer_seek_close(void);
int witty_writer_seek_restore(const char *,size_t);
int witty_writer_seek_valid(void);
ptrdiff_t witty_writer_seek_view(unsigned char *,size_t);
int witty_writer_seek_refs(void);
ptrdiff_t witty_writer_seek_drain(unsigned char *,size_t);
#else
#ifdef WITTY_WRITER_SEEK_NATIVE
#define WITTY_WRITER_SEEK_LINKAGE
#else
#define WITTY_WRITER_SEEK_LINKAGE static
#endif
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
#include <stdint.h>
static int witty_writer_seek_fd=-1,witty_writer_seek_pipe[2]={-1,-1};
static struct stat witty_writer_seek_identity[2];
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_setup(const char *path) {
    int fd=open(path,O_RDWR|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if(fd<0)return -1;
    witty_writer_seek_fd=fd;
    if(unlink(path)!=0)return -1;
    unsigned char data[2048];for(size_t i=0;i<sizeof(data);++i)data[i]=(unsigned char)(i*31+7);
    if(write(fd,data,sizeof(data))!=(ptrdiff_t)sizeof(data))return -1;
    if(pipe(witty_writer_seek_pipe)!=0)return -1;
    if(fd>=128 || witty_writer_seek_pipe[0]>=128 || witty_writer_seek_pipe[1]>=128)return -1;
    for(int i=0;i<2;++i)if(fcntl(witty_writer_seek_pipe[i],F_SETFL,O_NONBLOCK)!=0 || fcntl(witty_writer_seek_pipe[i],F_SETFD,FD_CLOEXEC)!=0)return -1;
    if(fstat(witty_writer_seek_pipe[0],&witty_writer_seek_identity[0])!=0 || fstat(witty_writer_seek_pipe[1],&witty_writer_seek_identity[1])!=0)return -1;
    return fd;
}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_replace(int writing) {
    return dup2(witty_writer_seek_pipe[writing!=0],witty_writer_seek_fd)==witty_writer_seek_fd?0:-1;
}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_seed(size_t start,size_t count) {
    unsigned char data[4096];if(count>sizeof(data))return -1;
    for(size_t i=0;i<count;++i)data[i]=(unsigned char)((i+start)*31+7);
    return write(witty_writer_seek_pipe[1],data,count)==(ptrdiff_t)count?0:-1;
}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_shutdown(void) {
    if(close(witty_writer_seek_pipe[1])!=0)return -1;
    witty_writer_seek_pipe[1]=-1;return 0;
}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_valid(void) {return fcntl(witty_writer_seek_fd,F_GETFD)>=0?1:0;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_refs(void) {
    struct stat st;int count=0;
    for(int fd=0;fd<128;++fd)if(fstat(fd,&st)==0 &&
       ((st.st_dev==witty_writer_seek_identity[0].st_dev && st.st_ino==witty_writer_seek_identity[0].st_ino) ||
        (st.st_dev==witty_writer_seek_identity[1].st_dev && st.st_ino==witty_writer_seek_identity[1].st_ino)))++count;
    return count;
}
WITTY_WRITER_SEEK_LINKAGE ptrdiff_t witty_writer_seek_drain(unsigned char *bytes,size_t count) {
    ptrdiff_t n=read(witty_writer_seek_pipe[0],bytes,count);
    if(n>=0)return n;
    return errno==EAGAIN||errno==EWOULDBLOCK?-1:-2;
}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_restore(const char *path,size_t length) {
    if(length>4096)return -1;
    int fd=open(path,O_RDWR|O_CREAT|O_EXCL|O_CLOEXEC,0600);if(fd<0)return -1;
    if(unlink(path)!=0){close(fd);return -1;}
    unsigned char data[4096];for(size_t i=0;i<length;++i)data[i]=(unsigned char)(i*37+19);
    if(write(fd,data,length)!=(ptrdiff_t)length || lseek(fd,0,SEEK_SET)<0){close(fd);return -1;}
    int result=dup2(fd,witty_writer_seek_fd)==witty_writer_seek_fd?0:-1;
    if(close(fd)!=0)return -1;return result;
}
WITTY_WRITER_SEEK_LINKAGE ptrdiff_t witty_writer_seek_view(unsigned char *bytes,size_t capacity) {
    struct stat st;if(fstat(witty_writer_seek_fd,&st)!=0)return errno==EBADF?0:-1;
    if(!S_ISREG(st.st_mode))return 0;
    if(st.st_size<0 || (uint64_t)st.st_size>capacity)return -1;
    size_t filled=0;while(filled<(size_t)st.st_size) {
        ptrdiff_t n=pread(witty_writer_seek_fd,bytes+filled,(size_t)st.st_size-filled,(off_t)filled);
        if(n<=0)return -1;filled+=(size_t)n;
    }
    return (ptrdiff_t)filled;
}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_close(void) {return close(witty_writer_seek_fd);}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_cleanup(void) {
    int result=0;
    if(witty_writer_seek_fd>=0 && fcntl(witty_writer_seek_fd,F_GETFD)>=0 && close(witty_writer_seek_fd)!=0)result=-1;
    witty_writer_seek_fd=-1;
    for(int i=0;i<2;++i) {if(witty_writer_seek_pipe[i]>=0 && close(witty_writer_seek_pipe[i])!=0)result=-1;witty_writer_seek_pipe[i]=-1;}
    return result;
}
#else
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_setup(const char *p) {(void)p;return -1;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_replace(int w) {(void)w;return -1;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_seed(size_t s,size_t n) {(void)s;(void)n;return -1;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_shutdown(void) {return -1;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_cleanup(void) {return -1;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_close(void) {return -1;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_restore(const char *p,size_t n) {(void)p;(void)n;return -1;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_valid(void) {return 0;}
WITTY_WRITER_SEEK_LINKAGE ptrdiff_t witty_writer_seek_view(unsigned char *p,size_t n) {(void)p;(void)n;return -1;}
WITTY_WRITER_SEEK_LINKAGE int witty_writer_seek_refs(void) {return -1;}
WITTY_WRITER_SEEK_LINKAGE ptrdiff_t witty_writer_seek_drain(unsigned char *p,size_t n) {(void)p;(void)n;return -2;}
#endif
#undef WITTY_WRITER_SEEK_LINKAGE
#endif
#endif
