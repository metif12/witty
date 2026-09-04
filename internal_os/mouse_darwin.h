#ifndef WITTY_INTERNAL_OS_MOUSE_DARWIN_H
#define WITTY_INTERNAL_OS_MOUSE_DARWIN_H

#include <math.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdint.h>

static inline uint32_t witty_internal_os_click_interval(void) {
    Class cls = objc_getClass("NSEvent");
    if (cls == NULL) return 0;
    SEL selector = sel_registerName("doubleClickInterval");
    double interval = ((double (*)(id, SEL))objc_msgSend)((id)cls, selector);
    return (uint32_t)ceil(interval * 1000.0);
}

#endif
