#ifndef WITTY_KEYMAP_SHIMS_H
#define WITTY_KEYMAP_SHIMS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __APPLE__
#include <Carbon/Carbon.h>

static inline void *witty_keymap_current_source(void) {
    return (void *)TISCopyCurrentKeyboardLayoutInputSource();
}

static inline void witty_keymap_release(void *source) {
    if (source != NULL) CFRelease((CFTypeRef)source);
}

static inline int witty_keymap_source_id(void *source, char *out, size_t cap) {
    if (source == NULL || out == NULL || cap == 0) return -1;
    CFStringRef value = (CFStringRef)TISGetInputSourceProperty(
        (TISInputSourceRef)source, kTISPropertyInputSourceID);
    if (value == NULL || !CFStringGetCString(value, out, (CFIndex)cap,
                                             kCFStringEncodingUTF8)) return -1;
    return 0;
}

static inline int witty_keymap_translate(void *source, uint16_t code,
                                         uint32_t modifiers, uint32_t *dead_key,
                                         char *out, size_t cap,
                                         int *composing) {
    if (source == NULL || dead_key == NULL || out == NULL || cap == 0) return -1;
    CFDataRef data = (CFDataRef)TISGetInputSourceProperty(
        (TISInputSourceRef)source, kTISPropertyUnicodeKeyLayoutData);
    if (data == NULL) return -1;
    const UCKeyboardLayout *layout =
        (const UCKeyboardLayout *)CFDataGetBytePtr(data);
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
    Boolean ok = CFStringGetCString(string, out, (CFIndex)cap,
                                    kCFStringEncodingUTF8);
    CFRelease(string);
    return ok ? 0 : -1;
}

#else
static inline void *witty_keymap_current_source(void) { return (void *)1; }
static inline void witty_keymap_release(void *source) { (void)source; }
static inline int witty_keymap_source_id(void *source, char *out, size_t cap) {
    (void)source;
    if (out != NULL && cap > 0) out[0] = 0;
    return 0;
}
static inline int witty_keymap_translate(void *source, uint16_t code,
                                         uint32_t modifiers, uint32_t *dead_key,
                                         char *out, size_t cap,
                                         int *composing) {
    (void)source; (void)code; (void)modifiers; (void)dead_key;
    if (out != NULL && cap > 0) out[0] = 0;
    if (composing != NULL) *composing = 0;
    return 0;
}
#endif

#endif
