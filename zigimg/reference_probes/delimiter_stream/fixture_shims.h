#ifndef WITTY_DELIMITER_STREAM_FIXTURES_H
#define WITTY_DELIMITER_STREAM_FIXTURES_H
#include "reader_exclusive/fixture_shims.h"
#include "writer_seek/fixture_shims.h"
#ifdef WITTY_READER_DELIMITER_DECLARATIONS
int witty_delimiter_stream_writer(const char *);
ptrdiff_t witty_delimiter_stream_fill(void);
#else
#ifdef WITTY_READER_DELIMITER_NATIVE
#define WITTY_DELIMITER_STREAM_LINKAGE
#else
#define WITTY_DELIMITER_STREAM_LINKAGE static
#endif
WITTY_DELIMITER_STREAM_LINKAGE int witty_delimiter_stream_writer(const char *path) {
    int fd=witty_writer_seek_setup(path);
    if(fd<0 || witty_writer_seek_restore(path,0)!=0)return -1;
    return fd;
}
WITTY_DELIMITER_STREAM_LINKAGE ptrdiff_t witty_delimiter_stream_fill(void) {
#ifndef _WIN32
    unsigned char bytes[4096];for(size_t i=0;i<sizeof(bytes);++i)bytes[i]=211;
    ptrdiff_t total=0;
    for(;;) {
        ptrdiff_t n=write(witty_writer_seek_pipe[1],bytes,sizeof(bytes));
        if(n>0){total+=n;continue;}
        if(n<0 && (errno==EAGAIN || errno==EWOULDBLOCK))return total;
        return -1;
    }
#else
    return -1;
#endif
}
#undef WITTY_DELIMITER_STREAM_LINKAGE
#endif
#endif
