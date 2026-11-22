#ifndef WITTY_KEYMAP_SHIMS_H
#define WITTY_KEYMAP_SHIMS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __APPLE__
#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
#include <Carbon/Carbon.h>
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline void *witty_keymap_current_source(void) {
    return (void *)TISCopyCurrentKeyboardLayoutInputSource();
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline const void *witty_keymap_unicode_layout(void *source) {
    if (source == NULL) return NULL;
    CFDataRef data = (CFDataRef)TISGetInputSourceProperty(
        (TISInputSourceRef)source, kTISPropertyUnicodeKeyLayoutData);
    return data == NULL ? NULL : (const void *)CFDataGetBytePtr(data);
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline void witty_keymap_release(void *source) {
    if (source != NULL) CFRelease((CFTypeRef)source);
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline int witty_keymap_source_id(void *source, char *out, size_t cap) {
    if (source == NULL || out == NULL || cap == 0) return -1;
    CFStringRef value = (CFStringRef)TISGetInputSourceProperty(
        (TISInputSourceRef)source, kTISPropertyInputSourceID);
    if (value == NULL || !CFStringGetCString(value, out, (CFIndex)cap,
                                             kCFStringEncodingUTF8)) return -1;
    return 0;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline int witty_keymap_translate(const void *layout_raw, uint16_t code,
                                         uint32_t modifiers, uint32_t *dead_key,
                                         char *out, size_t cap,
                                         size_t *out_len,
                                         int *composing) {
    if (layout_raw == NULL || dead_key == NULL || out_len == NULL ||
        composing == NULL) return -1;
    const UCKeyboardLayout *layout = (const UCKeyboardLayout *)layout_raw;
    UniChar chars[4];
    UniCharCount count = 0;
    OSStatus status = UCKeyTranslate(layout, code, kUCKeyActionDown, modifiers,
                                     LMGetKbdType(), 0, dead_key, 4, &count,
                                     chars);
    if (status != noErr) return -1;

    *composing = 0;
    if (*dead_key != 0 && count == 0) {
        uint32_t ignored_dead_key = *dead_key;
        status = UCKeyTranslate(layout, 0x31, kUCKeyActionDown, modifiers,
                                LMGetKbdType(), kUCKeyTranslateNoDeadKeysMask,
                                &ignored_dead_key, 4, &count, chars);
        if (status != noErr) return -1;
        *composing = 1;
    }

    CFStringRef string = CFStringCreateWithCharacters(kCFAllocatorDefault,
                                                       chars, (CFIndex)count);
    if (string == NULL) return -1;
    CFIndex used = 0;
    CFIndex converted = CFStringGetBytes(
        string, CFRangeMake(0, (CFIndex)count), kCFStringEncodingUTF8, 0,
        false, (UInt8 *)out, (CFIndex)cap, &used);
    CFRelease(string);
    if (converted != (CFIndex)count) return -1;
    *out_len = (size_t)used;
    return 0;
}
#endif
#endif

#endif
