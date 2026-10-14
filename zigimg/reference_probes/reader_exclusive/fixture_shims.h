#ifndef WITTY_READER_EXCLUSIVE_FIXTURES_H
#define WITTY_READER_EXCLUSIVE_FIXTURES_H
#include "reader_delimiter/fixture_shims.h"
#ifdef WITTY_READER_DELIMITER_DECLARATIONS
int witty_reader_exclusive_payload(const char *,const unsigned char *,size_t);
#else
#ifdef WITTY_READER_DELIMITER_NATIVE
#define WITTY_READER_EXCLUSIVE_LINKAGE
#else
#define WITTY_READER_EXCLUSIVE_LINKAGE static
#endif
WITTY_READER_EXCLUSIVE_LINKAGE int witty_reader_exclusive_payload(const char *path,const unsigned char *data,size_t length) {
#ifndef _WIN32
    int fd=witty_reader_delimiter_setup(path);
    if(fd<0 || ftruncate(fd,(off_t)length)!=0)return -1;
    if(length && pwrite(fd,data,length,0)!=(ptrdiff_t)length)return -1;
    if(lseek(fd,0,SEEK_SET)!=0)return -1;
    return fd;
#else
    (void)path;(void)data;(void)length;return -1;
#endif
}
#undef WITTY_READER_EXCLUSIVE_LINKAGE
#endif
#endif
