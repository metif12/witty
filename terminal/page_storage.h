#ifndef WITTY_TERMINAL_PAGE_STORAGE_H
#define WITTY_TERMINAL_PAGE_STORAGE_H
#include <stdint.h>
#include <stddef.h>
#include <sys/mman.h>
#include <unistd.h>
// page.zig Cell's u2 tag, u24 content, u16 style, u2 width, two
// flags, u2 semantics and u16 padding. Only the active payload is stored.
typedef struct WittyPageCell {
    union {
        struct {
            uint64_t content_tag:2, codepoint:21, content_padding:3;
            uint64_t style_id:16, wide:2, is_protected:1, has_hyperlink:1;
            uint64_t semantic_content:2, padding:16;
        };
        struct { uint64_t _tag:2, content_payload:24, _remaining:38; };
    };
} WittyPageCell;
static inline uint32_t witty_cell_content(const WittyPageCell *cell) {return cell->content_payload;}
static inline void witty_cell_set_content(WittyPageCell *cell,uint32_t value) {cell->content_payload=value;}
typedef struct WittyPageRow {
    uint64_t cells_offset:32, wrap:1, wrap_continuation:1, grapheme:1;
    uint64_t styled:1, hyperlink:1, semantic_prompt:2;
    uint64_t kitty_virtual_placeholder:1, dirty:1, padding:23;
} WittyPageRow;
_Static_assert(sizeof(WittyPageCell)==8,"Cell must be packed u64");
_Static_assert(sizeof(WittyPageRow)==8,"Row must be packed u64");
static inline void *witty_page_mmap(size_t length) {
    void *memory=mmap(NULL,length,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
    return memory==MAP_FAILED ? NULL : memory;
}
static inline void witty_page_munmap(void *memory,size_t length) { munmap(memory,length); }
#endif
