#ifndef WITTY_IMAGE_CLOSE_FIXTURES_H
#define WITTY_IMAGE_CLOSE_FIXTURES_H
#include <stddef.h>
#ifdef WITTY_IMAGE_CLOSE_DECLARATIONS
int witty_image_close_setup(const char *, int);
int witty_image_close_seed(int, int);
int witty_image_close_cleanup(const char *, int, int);
int witty_image_close_raw(int);
int witty_image_close_valid(int);
int witty_image_close_refs(int);
int witty_image_close_kind(int);
int witty_image_close_flags(int);
ptrdiff_t witty_image_close_bytes(int, int, unsigned char *, size_t);
#else
#ifdef WITTY_IMAGE_CLOSE_NATIVE
#define WITTY_IMAGE_CLOSE_LINKAGE
#else
#define WITTY_IMAGE_CLOSE_LINKAGE static
#endif
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
#include <stdio.h>
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_setup(const char *root, int kind) {
    char target[4096], seed[4096];
    if (mkdir(root,0700) != 0) return -1;
    snprintf(target,sizeof(target),"%s/target",root);
    snprintf(seed,sizeof(seed),"%s/seed",root);
    if (kind==1) {
        if (mkfifo(target,0600)!=0) return -1;
        return open(target,O_RDWR|O_NONBLOCK|O_CLOEXEC);
    }
    if (kind==2) {
        if (mkdir(target,0700)!=0) return -1;
        return open(target,O_RDONLY|O_CLOEXEC);
    }
    const char *path=kind>=3?seed:target;
    int fd=open(path,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    unsigned char bytes[32]; for (int i=0;i<32;++i) bytes[i]=(unsigned char)(i*31+7);
    if (fd<0 || write(fd,bytes,32)!=32 || close(fd)!=0) return -1;
    if (kind==3 && symlink("seed",target)!=0) return -1;
    if (kind==4 && link(seed,target)!=0) return -1;
    return open(target,O_RDONLY|O_CLOEXEC);
}
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_seed(int fd, int kind) {
    if (kind!=1) return 0;
    unsigned char bytes[32]; for (int i=0;i<32;++i) bytes[i]=(unsigned char)(i*31+7);
    return write(fd,bytes,32)==32?0:-1;
}
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_raw(int fd) { return close(fd); }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_valid(int fd) { return fcntl(fd,F_GETFD)>=0; }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_refs(int keeper) {
    struct stat target,st; if (fstat(keeper,&target)!=0) return -1;
    int refs=0;
    for(int fd=0;fd<128;++fd) if(fstat(fd,&st)==0 && st.st_dev==target.st_dev && st.st_ino==target.st_ino) ++refs;
    return refs;
}
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_kind(int fd) {
    struct stat st; if (fstat(fd,&st)!=0) return -1;
    return S_ISREG(st.st_mode)?0:S_ISFIFO(st.st_mode)?1:S_ISDIR(st.st_mode)?2:3;
}
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_flags(int fd) {
    int flags=fcntl(fd,F_GETFL),desc=fcntl(fd,F_GETFD);
    if(flags<0 || desc<0) return -1;
    return ((desc&FD_CLOEXEC)!=0)*10+(flags&O_ACCMODE);
}
WITTY_IMAGE_CLOSE_LINKAGE ptrdiff_t witty_image_close_bytes(int fd,int kind,unsigned char *bytes,size_t cap) {
    if(kind==2) return 0;
    ptrdiff_t n=kind==1?read(fd,bytes,cap):pread(fd,bytes,cap,0);
    if(n>=0) return n;
    return errno==EAGAIN||errno==EWOULDBLOCK?-1:-2;
}
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_cleanup(const char *root,int kind,int keeper) {
    char path[4096]; if(close(keeper)!=0) return -1;
    snprintf(path,sizeof(path),"%s/target",root);
    if((kind==2?rmdir(path):unlink(path))!=0) return -1;
    if(kind>=3) { snprintf(path,sizeof(path),"%s/seed",root); if(unlink(path)!=0) return -1; }
    return rmdir(root);
}
#else
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_setup(const char *p,int k) { (void)p;(void)k;return -1; }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_seed(int f,int k) { (void)f;(void)k;return -1; }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_cleanup(const char *p,int k,int f) { (void)p;(void)k;(void)f;return -1; }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_raw(int f) { (void)f;return -1; }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_valid(int f) { (void)f;return 0; }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_refs(int f) { (void)f;return -1; }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_kind(int f) { (void)f;return -1; }
WITTY_IMAGE_CLOSE_LINKAGE int witty_image_close_flags(int f) { (void)f;return -1; }
WITTY_IMAGE_CLOSE_LINKAGE ptrdiff_t witty_image_close_bytes(int f,int k,unsigned char *b,size_t n) { (void)f;(void)k;(void)b;(void)n;return -2; }
#endif
#undef WITTY_IMAGE_CLOSE_LINKAGE
#endif
#endif
