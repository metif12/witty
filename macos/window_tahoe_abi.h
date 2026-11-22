#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
#include <AppKit/AppKit.h>
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
typedef void (*witty_tahoe_frame_callback)(void*);
static inline void* witty_tahoe_observe_frame(void* view, void* context,
                                             witty_tahoe_frame_callback callback) {
    id token = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSViewFrameDidChangeNotification object:(id)view
        queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            callback(context);
        }];
    return [token retain];
}
static inline void witty_tahoe_observe_group(void* group, void* observer) {
    [(id)group addObserver:(id)observer forKeyPath:@"windows"
                 options:NSKeyValueObservingOptionNew context:NULL];
    [(id)group addObserver:(id)observer forKeyPath:@"tabBarVisible"
                 options:NSKeyValueObservingOptionNew context:NULL];
}
static inline void witty_tahoe_remove_group_observer(void* group, void* observer) {
    [(id)group removeObserver:(id)observer forKeyPath:@"windows"];
    [(id)group removeObserver:(id)observer forKeyPath:@"tabBarVisible"];
}
static inline bool witty_tahoe_event_in_view(void* view, void* event) {
    NSView* target = (NSView*)view;
    NSPoint point = [target convertPoint:[(NSEvent*)event locationInWindow] fromView:nil];
    return CGRectContainsPoint(target.bounds, point);
}
#endif
