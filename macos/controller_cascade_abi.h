static inline witty_macos_point witty_macos_cascade_top_left(void* window, witty_macos_point point) {
    return ((witty_macos_point (*)(id,SEL,witty_macos_point))objc_msgSend)((id)window,sel_registerName("cascadeTopLeftFromPoint:"),point);
}
