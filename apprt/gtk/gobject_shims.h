#pragma once

#include <gio/gio.h>
#include <glib-object.h>
#include <adwaita.h>

static inline void witty_gobject_class_set_get_property(
    gpointer klass,
    gpointer callback) {
  G_OBJECT_CLASS(klass)->get_property = (GObjectGetPropertyFunc)callback;
}

static inline void witty_gobject_class_set_set_property(
    gpointer klass,
    gpointer callback) {
  G_OBJECT_CLASS(klass)->set_property = (GObjectSetPropertyFunc)callback;
}

static inline void witty_gobject_class_set_dispose(
    gpointer klass,
    gpointer callback) {
  G_OBJECT_CLASS(klass)->dispose = (GObjectFinalizeFunc)callback;
}

static inline void witty_gobject_class_set_finalize(
    gpointer klass,
    gpointer callback) {
  G_OBJECT_CLASS(klass)->finalize = (GObjectFinalizeFunc)callback;
}

static inline void witty_gobject_call_parent_dispose(gpointer instance) {
  GObjectClass *parent = G_OBJECT_CLASS(
      g_type_class_peek_parent(G_OBJECT_GET_CLASS(instance)));
  if (parent->dispose != NULL) parent->dispose(G_OBJECT(instance));
}

static inline void witty_gobject_call_parent_finalize(gpointer instance) {
  GObjectClass *parent = G_OBJECT_CLASS(
      g_type_class_peek_parent(G_OBJECT_GET_CLASS(instance)));
  if (parent->finalize != NULL) parent->finalize(G_OBJECT(instance));
}

static inline void witty_gapplication_class_set_startup(
    gpointer klass,
    gpointer callback) {
  G_APPLICATION_CLASS(klass)->startup = (void (*)(GApplication *))callback;
}

static inline void witty_gapplication_class_set_activate(
    gpointer klass,
    gpointer callback) {
  G_APPLICATION_CLASS(klass)->activate = (void (*)(GApplication *))callback;
}

static inline void witty_gapplication_call_parent_startup(gpointer instance) {
  GApplicationClass *parent = G_APPLICATION_CLASS(
      g_type_class_peek_parent(G_OBJECT_GET_CLASS(instance)));
  if (parent->startup != NULL) parent->startup(G_APPLICATION(instance));
}

static inline void witty_gapplication_call_parent_activate(gpointer instance) {
  GApplicationClass *parent = G_APPLICATION_CLASS(
      g_type_class_peek_parent(G_OBJECT_GET_CLASS(instance)));
  if (parent->activate != NULL) parent->activate(G_APPLICATION(instance));
}

static inline const gchar *witty_glog_field_key(
    const GLogField *fields,
    gsize index) {
  return fields[index].key;
}

static inline gconstpointer witty_glog_field_value(
    const GLogField *fields,
    gsize index) {
  return fields[index].value;
}

static inline gssize witty_glog_field_length(
    const GLogField *fields,
    gsize index) {
  return fields[index].length;
}

static inline void witty_dialog_class_set_response(
    gpointer klass,
    gboolean alert_dialog,
    gpointer callback) {
#if ADW_CHECK_VERSION(1, 5, 0)
  if (alert_dialog) {
    ADW_ALERT_DIALOG_CLASS(klass)->response =
        (void (*)(AdwAlertDialog *, const char *))callback;
  } else {
#else
  (void)alert_dialog;
  {
#endif
    ADW_MESSAGE_DIALOG_CLASS(klass)->response =
        (void (*)(AdwMessageDialog *, const char *))callback;
  }
}

// gtk_css_section_get_bytes is GTK 4.16+. Callers already gate it with
// gtk_at_least, but builds against older GTK headers must still compile/link.
static inline GBytes *witty_gtk_css_section_get_bytes(GtkCssSection *section) {
#if GTK_CHECK_VERSION(4, 16, 0)
  return gtk_css_section_get_bytes(section);
#else
  (void)section;
  return NULL;
#endif
}
