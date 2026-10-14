#ifndef WITTY_READER_DELIMITER_FIXTURES_H
#define WITTY_READER_DELIMITER_FIXTURES_H
#include <stddef.h>
#ifdef WITTY_READER_DELIMITER_DECLARATIONS
int witty_reader_delimiter_setup(const char *);
int witty_reader_delimiter_replace(int);
int witty_reader_delimiter_seed(size_t,size_t);
int witty_reader_delimiter_shutdown(void);
int witty_reader_delimiter_cleanup(void);
int witty_reader_delimiter_close(void);
int witty_reader_delimiter_valid(void);
int witty_reader_delimiter_refs(void);
ptrdiff_t witty_reader_delimiter_drain(unsigned char *,size_t);
#else
#ifdef WITTY_READER_DELIMITER_NATIVE
#define WITTY_READER_DELIMITER_LINKAGE
#else
#define WITTY_READER_DELIMITER_LINKAGE static
#endif
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
static int witty_reader_delimiter_fd=-1,witty_reader_delimiter_pipe[2]={-1,-1};
static struct stat witty_reader_delimiter_identity[2];
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_setup(const char *path) {
    int fd=open(path,O_RDWR|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if(fd<0)return -1;
    witty_reader_delimiter_fd=fd;
    if(unlink(path)!=0)return -1;
    unsigned char data[2048];for(size_t i=0;i<sizeof(data);++i)data[i]=(unsigned char)(i*37+19);
    if(write(fd,data,sizeof(data))!=(ptrdiff_t)sizeof(data))return -1;
    if(pipe(witty_reader_delimiter_pipe)!=0)return -1;
    if(fd>=128 || witty_reader_delimiter_pipe[0]>=128 || witty_reader_delimiter_pipe[1]>=128)return -1;
    for(int i=0;i<2;++i)if(fcntl(witty_reader_delimiter_pipe[i],F_SETFL,O_NONBLOCK)!=0 || fcntl(witty_reader_delimiter_pipe[i],F_SETFD,FD_CLOEXEC)!=0)return -1;
    if(fstat(witty_reader_delimiter_pipe[0],&witty_reader_delimiter_identity[0])!=0 || fstat(witty_reader_delimiter_pipe[1],&witty_reader_delimiter_identity[1])!=0)return -1;
    return fd;
}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_replace(int writing) {
    return dup2(witty_reader_delimiter_pipe[writing!=0],witty_reader_delimiter_fd)==witty_reader_delimiter_fd?0:-1;
}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_seed(size_t start,size_t count) {
    unsigned char data[4096];if(count>sizeof(data))return -1;
    for(size_t i=0;i<count;++i)data[i]=(unsigned char)((i+start)*31+7);
    return write(witty_reader_delimiter_pipe[1],data,count)==(ptrdiff_t)count?0:-1;
}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_shutdown(void) {
    if(close(witty_reader_delimiter_pipe[1])!=0)return -1;
    witty_reader_delimiter_pipe[1]=-1;return 0;
}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_valid(void) {return fcntl(witty_reader_delimiter_fd,F_GETFD)>=0?1:0;}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_refs(void) {
    struct stat st;int count=0;
    for(int fd=0;fd<128;++fd)if(fstat(fd,&st)==0 &&
       ((st.st_dev==witty_reader_delimiter_identity[0].st_dev && st.st_ino==witty_reader_delimiter_identity[0].st_ino) ||
        (st.st_dev==witty_reader_delimiter_identity[1].st_dev && st.st_ino==witty_reader_delimiter_identity[1].st_ino)))++count;
    return count;
}
WITTY_READER_DELIMITER_LINKAGE ptrdiff_t witty_reader_delimiter_drain(unsigned char *bytes,size_t count) {
    ptrdiff_t n=read(witty_reader_delimiter_pipe[0],bytes,count);
    if(n>=0)return n;
    return errno==EAGAIN||errno==EWOULDBLOCK?-1:-2;
}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_close(void) {return close(witty_reader_delimiter_fd);}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_cleanup(void) {
    int result=0;
    if(witty_reader_delimiter_fd>=0 && fcntl(witty_reader_delimiter_fd,F_GETFD)>=0 && close(witty_reader_delimiter_fd)!=0)result=-1;
    witty_reader_delimiter_fd=-1;
    for(int i=0;i<2;++i) {if(witty_reader_delimiter_pipe[i]>=0 && close(witty_reader_delimiter_pipe[i])!=0)result=-1;witty_reader_delimiter_pipe[i]=-1;}
    return result;
}
#else
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_setup(const char *p) {(void)p;return -1;}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_replace(int w) {(void)w;return -1;}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_seed(size_t s,size_t n) {(void)s;(void)n;return -1;}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_shutdown(void) {return -1;}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_cleanup(void) {return -1;}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_close(void) {return -1;}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_valid(void) {return 0;}
WITTY_READER_DELIMITER_LINKAGE int witty_reader_delimiter_refs(void) {return -1;}
WITTY_READER_DELIMITER_LINKAGE ptrdiff_t witty_reader_delimiter_drain(unsigned char *p,size_t n) {(void)p;(void)n;return -2;}
#endif
#undef WITTY_READER_DELIMITER_LINKAGE
#endif
#endif
