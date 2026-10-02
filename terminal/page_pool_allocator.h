#ifndef WITTY_PAGE_POOL_ALLOCATOR_H
#define WITTY_PAGE_POOL_ALLOCATOR_H
/* Zig 0.15.2 PageAllocator POSIX map/unmap/realloc and Ghostty's
 * os/mach.zig TaggedPageAllocator. Syscalls are the platform boundary. */
#include <stdint.h>
#include <stddef.h>
static size_t witty_pool_align(size_t n,size_t a) { return (n+a-1)&~(a-1); }
#ifdef _WIN32
#include <windows.h>
#include <winternl.h>
#ifndef MEM_RESERVE_PLACEHOLDER
#define MEM_RESERVE_PLACEHOLDER 0x00040000
#endif
#ifndef MEM_PRESERVE_PLACEHOLDER
#define MEM_PRESERVE_PLACEHOLDER 0x00000400
#endif
NTSYSAPI NTSTATUS NTAPI NtAllocateVirtualMemory(HANDLE,PVOID *,ULONG_PTR,PSIZE_T,ULONG,ULONG);
NTSYSAPI NTSTATUS NTAPI NtFreeVirtualMemory(HANDLE,PVOID *,PSIZE_T,ULONG);
static size_t witty_page_pool_page_size(void) { SYSTEM_INFO info;GetSystemInfo(&info);return info.dwPageSize; }
static void *witty_page_pool_map(size_t n,uint8_t alignment,uint8_t tag) {
    size_t page=witty_page_pool_page_size();(void)tag;
    if(n>=SIZE_MAX-page || alignment>=sizeof(size_t)*8) return NULL;
    size_t bytes=(size_t)1<<alignment;
    void *base=NULL;SIZE_T size=n;
    NTSTATUS status=NtAllocateVirtualMemory(GetCurrentProcess(),&base,0,&size,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);
    if(status==0 && ((uintptr_t)base&(bytes-1))==0)return base;
    if(status==0) { SIZE_T zero=0;NtFreeVirtualMemory(GetCurrentProcess(),&base,&zero,MEM_RELEASE); }
    size_t overalloc=n+bytes-page,aligned=witty_pool_align(n,page);
    base=NULL;size=overalloc;
    status=NtAllocateVirtualMemory(GetCurrentProcess(),&base,0,&size,MEM_RESERVE|MEM_RESERVE_PLACEHOLDER,PAGE_NOACCESS);
    if(status!=0)return NULL;
    uintptr_t placeholder=(uintptr_t)base,result=witty_pool_align(placeholder,bytes);
    size_t prefix=result-placeholder;
    if(prefix) { void *prefix_base=base;SIZE_T prefix_len=prefix;NtFreeVirtualMemory(GetCurrentProcess(),&prefix_base,&prefix_len,MEM_RELEASE|MEM_PRESERVE_PLACEHOLDER); }
    uintptr_t suffix_start=result+aligned;size_t suffix=placeholder+overalloc-suffix_start;
    if(suffix) { void *suffix_base=(void *)suffix_start;SIZE_T suffix_len=suffix;NtFreeVirtualMemory(GetCurrentProcess(),&suffix_base,&suffix_len,MEM_RELEASE|MEM_PRESERVE_PLACEHOLDER); }
    base=(void *)result;size=aligned;
    status=NtAllocateVirtualMemory(GetCurrentProcess(),&base,0,&size,MEM_COMMIT|MEM_PRESERVE_PLACEHOLDER,PAGE_READWRITE);
    if(status==0)return base;
    base=(void *)result;size=aligned;NtFreeVirtualMemory(GetCurrentProcess(),&base,&size,MEM_RELEASE);return NULL;
}
static void witty_page_pool_unmap(void *memory,size_t length) {
    SIZE_T zero=0;(void)length;NtFreeVirtualMemory(GetCurrentProcess(),&memory,&zero,MEM_RELEASE);
}
static void *witty_page_pool_realloc(void *memory,size_t old,size_t length,int may_move) {
    size_t page=witty_page_pool_page_size(),wanted=witty_pool_align(length,page);(void)may_move;
    if(length<=old) {
        uintptr_t end=(uintptr_t)memory+old,new_end=witty_pool_align((uintptr_t)memory+length,page);
        if(end>new_end) { void *decommit=(void *)new_end;SIZE_T size=end-new_end;NtAllocateVirtualMemory(GetCurrentProcess(),&decommit,0,&size,MEM_RESET,PAGE_NOACCESS); }
        return memory;
    }
    return wanted<=witty_pool_align(old,page)?memory:NULL;
}
#else
#include <sys/mman.h>
#include <unistd.h>
#include <stdatomic.h>
static _Atomic(uintptr_t) witty_page_pool_next_hint;
static void *witty_page_pool_map(size_t n,uint8_t alignment,uint8_t tag) {
    size_t page=(size_t)sysconf(_SC_PAGESIZE);
    if(n>=SIZE_MAX-page || alignment>=sizeof(size_t)*8) return NULL;
    size_t bytes=(size_t)1<<alignment, aligned=witty_pool_align(n,page);
    size_t max_drop=bytes-(bytes<page?bytes:page);
    size_t overalloc=max_drop<=aligned-n?aligned:witty_pool_align(aligned+max_drop,page);
    uintptr_t hint=atomic_load_explicit(&witty_page_pool_next_hint,memory_order_relaxed);
#ifdef __APPLE__
    int fd=tag ? (int)((uint32_t)tag<<24) : -1;
#else
    int fd=-1; (void)tag;
#endif
    void *memory=mmap((void *)hint,overalloc,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,fd,0);
    if(memory==MAP_FAILED) return NULL;
    uintptr_t result=witty_pool_align((uintptr_t)memory,bytes);
    size_t drop=result-(uintptr_t)memory;
    if(drop) munmap(memory,drop);
    size_t remaining=overalloc-drop;
    if(remaining>aligned) munmap((void *)(result+aligned),remaining-aligned);
    uintptr_t next=result+aligned;
    atomic_compare_exchange_strong_explicit(&witty_page_pool_next_hint,&hint,next,memory_order_relaxed,memory_order_relaxed);
    return (void *)result;
}
static void witty_page_pool_unmap(void *memory,size_t length) {
    size_t page=(size_t)sysconf(_SC_PAGESIZE);
    munmap(memory,witty_pool_align(length,page));
}
static void *witty_page_pool_realloc(void *memory,size_t old,size_t length,int may_move) {
    size_t page=(size_t)sysconf(_SC_PAGESIZE);
    size_t wanted=witty_pool_align(length,page), previous=witty_pool_align(old,page);
    if(wanted==previous) return memory;
#ifdef __linux__
    void *result=mremap(memory,old,length,may_move?MREMAP_MAYMOVE:0);
    return result==MAP_FAILED?NULL:result;
#else
    (void)may_move;
    if(wanted<previous) {
        munmap((void *)((uintptr_t)memory+wanted),previous-wanted);
        return memory;
    }
    return NULL;
#endif
}
#endif
#endif
