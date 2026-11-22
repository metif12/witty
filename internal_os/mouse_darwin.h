#ifndef WITTY_INTERNAL_OS_MOUSE_DARWIN_H
#define WITTY_INTERNAL_OS_MOUSE_DARWIN_H

#include <math.h>
#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
#include <objc/message.h>
#include <objc/runtime.h>
#endif
#include <stdint.h>

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline int witty_internal_os_click_interval(uint32_t *value) {
    Class cls = objc_getClass("NSEvent");
    if (cls == NULL) return 0;
    SEL selector = sel_registerName("doubleClickInterval");
    double interval = ((double (*)(id, SEL))objc_msgSend)((id)cls, selector);
    *value = (uint32_t)ceil(interval * 1000.0);
    return 1;
}
#endif

#endif
