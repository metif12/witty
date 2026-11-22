// TerminalWindow.title's super setter must start at its defining class,
// including when AppKit installs a subclass for native tabs or observation.
#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline void witty_window_font_super_set_title(void* window, void* title) {
    struct objc_super super = {(id)window, class_getSuperclass((Class)objc_getClass("VTTerminalWindow"))};
    ((void (*)(struct objc_super*, SEL, id))objc_msgSendSuper)(&super, sel_registerName("setTitle:"), (id)title);
}
#endif
