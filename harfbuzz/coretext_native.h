#ifndef WITTY_HARFBUZZ_CORETEXT_NATIVE_H
#define WITTY_HARFBUZZ_CORETEXT_NATIVE_H
/* hb-coretext.h includes ApplicationServices, which only native code reads. */
#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
#include <hb-coretext.h>
#endif
#endif
