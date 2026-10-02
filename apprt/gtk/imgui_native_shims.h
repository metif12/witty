#pragma once
#include <adwaita.h>

typedef struct {
  AdwBinClass parent_class;
  void (*setup)(gpointer);
  void (*render)(gpointer);
} GhosttyImguiWidgetClass;

static inline gsize witty_imgui_class_size(void) {
  return sizeof(GhosttyImguiWidgetClass);
}
static inline void witty_imgui_class_set_setup(gpointer klass, gpointer callback) {
  ((GhosttyImguiWidgetClass *)klass)->setup = (void (*)(gpointer))callback;
}
static inline void witty_imgui_class_set_render(gpointer klass, gpointer callback) {
  ((GhosttyImguiWidgetClass *)klass)->render = (void (*)(gpointer))callback;
}
static inline void witty_imgui_call_setup(gpointer instance) {
  GhosttyImguiWidgetClass *klass = (GhosttyImguiWidgetClass *)G_OBJECT_GET_CLASS(instance);
  if (klass->setup != NULL) klass->setup(instance);
}
static inline void witty_imgui_call_render(gpointer instance) {
  GhosttyImguiWidgetClass *klass = (GhosttyImguiWidgetClass *)G_OBJECT_GET_CLASS(instance);
  if (klass->render != NULL) klass->render(instance);
}
static inline void witty_imgui_parent_dispose(gpointer parent, gpointer instance) {
  if (((GObjectClass *)parent)->dispose != NULL)
    ((GObjectClass *)parent)->dispose(instance);
}
