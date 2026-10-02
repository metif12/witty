#ifndef WITTY_NATIVE_STRING_TEST_ABI_H
#define WITTY_NATIVE_STRING_TEST_ABI_H
#include <Foundation/Foundation.h>
#include <objc/message.h>
#include <objc/runtime.h>
static inline void witty_native_string_test_pump(double delay) {
    id loop = ((id (*)(id, SEL))objc_msgSend)((id)objc_getClass("NSRunLoop"), sel_registerName("currentRunLoop"));
    id until = ((id (*)(id, SEL, double))objc_msgSend)((id)objc_getClass("NSDate"),
        sel_registerName("dateWithTimeIntervalSinceNow:"), delay);
    ((void (*)(id, SEL, id))objc_msgSend)(loop, sel_registerName("runUntilDate:"), until);
}
#endif
