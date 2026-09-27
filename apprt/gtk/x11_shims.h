#pragma once

#include <X11/XKBlib.h>
#include <X11/Xlib.h>
#include <gdk/x11/gdkx.h>

static inline int witty_gdk_is_x11_surface(void *surface) {
  return GDK_IS_X11_SURFACE(surface);
}

static inline int witty_x11_event_type(const void *event) {
  return ((const XEvent *)event)->type;
}

static inline int witty_xkb_event_type(const void *event) {
  return ((const XkbEvent *)event)->any.xkb_type;
}

static inline unsigned int witty_xkb_event_lookup_mods(const void *event) {
  return ((const XkbEvent *)event)->state.lookup_mods;
}
