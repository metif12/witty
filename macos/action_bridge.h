/* Objective-C ABI adapters only; translated action logic lives in V. */
static inline void* witty_action_timer(double interval, void* target, void* selector, void* info, bool repeats) {
 return ((id(*)(id,SEL,double,id,SEL,id,bool))objc_msgSend)((id)objc_getClass("NSTimer"),sel_registerName("scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:"),interval,(id)target,(SEL)selector,(id)info,repeats);
}
static inline void* witty_action_hit_super(void* view, void* defining_class, double x, double y) {
 struct objc_super sup = {(id)view,class_getSuperclass((Class)defining_class)};
 return ((id(*)(struct objc_super*,SEL,CGPoint))objc_msgSendSuper)(&sup,sel_registerName("hitTest:"),(CGPoint){x,y});
}
static inline void witty_action_add_tab(void* window, void* other, long order) {
 ((void(*)(id,SEL,id,long))objc_msgSend)((id)window,sel_registerName("addTabbedWindow:ordered:"),(id)other,order);
}
static inline void witty_macos_set_document_cursor(void* view, void* cursor) {
 ((void(*)(id,SEL,CGRect,id))objc_msgSend)((id)view,sel_registerName("addCursorRect:cursor:"),((CGRect(*)(id,SEL))objc_msgSend)((id)view,sel_registerName("bounds")),(id)cursor);
}
static inline void witty_action_show_popover(void* popover, void* view, unsigned long edge) {
 ((void(*)(id,SEL,CGRect,id,unsigned long))objc_msgSend)((id)popover,sel_registerName("showRelativeToRect:ofView:preferredEdge:"),((CGRect(*)(id,SEL))objc_msgSend)((id)view,sel_registerName("bounds")),(id)view,edge);
}
static inline void witty_action_repeat_forever(void* animation) {
 ((void(*)(id,SEL,float))objc_msgSend)((id)animation,sel_registerName("setRepeatCount:"),__builtin_inff());
}
