typedef struct { long majorVersion; long minorVersion; long patchVersion; } witty_native_os_version;
static inline bool witty_native_os_at_least(long major, long minor, long patch) {
    id info=((id (*)(id,SEL))objc_msgSend)((id)objc_getClass("NSProcessInfo"),sel_registerName("processInfo"));
    return ((bool (*)(id,SEL,witty_native_os_version))objc_msgSend)(info,sel_registerName("isOperatingSystemAtLeastVersion:"),(witty_native_os_version){major,minor,patch});
}
