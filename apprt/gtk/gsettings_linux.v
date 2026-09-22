module gtk

// gsettings_linux.v - Read GNOME/GTK settings values.
//
// Translated from ghostty/src/apprt/gtk/gsettings.zig.
//
// The Zig original reads well-typed GTK *Settings* keys (gtk-enable-primary-
// paste, gtk-xft-dpi, gtk-font-name) off the default `GtkSettings` object by
// reading a GObject property into a `GValue`. It uses Zig comptime to map each
// key to its native type and its GValue storage type.
//
// V has no comptime type mapping over an enum the way Zig does, so instead of
// one generic `get(comptime key)` we provide one typed getter per key. The
// underlying mechanism (GtkSettings.getDefault + GObject.getProperty into a
// GValue) is faithful.
//
// Per the translation brief we also expose the plain GSettings bindings
// (g_settings_new / g_settings_get_*) so GNOME schema values can be read.

// --- Opaque handle aliases (module-local) ---------------------------------

// GtkSettings is a gtk.Settings*.
pub type GtkSettings = voidptr

// --- New C bindings: GtkSettings + GValue ---------------------------------

fn C.gtk_settings_get_default() GtkSettings
fn C.g_object_get_property(object GObject, property_name &char, value GValue)

fn C.g_value_init(value GValue, g_type GType) GValue
fn C.g_value_unset(value GValue)
fn C.g_value_get_int(value GValue) int
fn C.g_value_get_string(value GValue) &char

// GType constants for the GValue storage types we use. These correspond to the
// fundamental type ids: G_TYPE_INT = (6 << 2), G_TYPE_STRING = (16 << 2).
const g_type_int = GType(6 << 2)
const g_type_string = GType(16 << 2)

// --- GtkSettings key readers ----------------------------------------------
//
// Each function corresponds to a `Key` variant in the Zig original. They return
// an optional (V `?`) mirroring the Zig `?T`, returning none when the default
// GtkSettings is unavailable.

// gtk_setting_enable_primary_paste reads "gtk-enable-primary-paste" (bool).
// Mirrors `get(.@"gtk-enable-primary-paste")`.
pub fn gtk_setting_enable_primary_paste() ?bool {
	settings := C.gtk_settings_get_default()
	if isnil(settings) {
		return none
	}
	mut storage := GValueStorage{}
	value := C.g_value_init(storage.ptr(), g_type_int)
	defer {
		C.g_value_unset(value)
	}
	C.g_object_get_property(GObject(settings), c'gtk-enable-primary-paste', value)
	return C.g_value_get_int(value) != 0
}

// gtk_setting_xft_dpi reads "gtk-xft-dpi" (c_int). Mirrors `get(.@"gtk-xft-dpi")`.
pub fn gtk_setting_xft_dpi() ?int {
	settings := C.gtk_settings_get_default()
	if isnil(settings) {
		return none
	}
	mut storage := GValueStorage{}
	value := C.g_value_init(storage.ptr(), g_type_int)
	defer {
		C.g_value_unset(value)
	}
	C.g_object_get_property(GObject(settings), c'gtk-xft-dpi', value)
	return C.g_value_get_int(value)
}

// gtk_setting_font_name reads "gtk-font-name" (string). Mirrors
// `getAlloc(alloc, .@"gtk-font-name")`. Returns none if the setting is
// unavailable or unset. The returned string is a V copy of the value.
pub fn gtk_setting_font_name() ?string {
	settings := C.gtk_settings_get_default()
	if isnil(settings) {
		return none
	}
	mut storage := GValueStorage{}
	value := C.g_value_init(storage.ptr(), g_type_string)
	defer {
		C.g_value_unset(value)
	}
	C.g_object_get_property(GObject(settings), c'gtk-font-name', value)
	ptr := C.g_value_get_string(value)
	if isnil(ptr) {
		return none
	}
	return unsafe { cstring_to_vstring(ptr) }
}

// GValueStorage is the stack storage for GLib's GValue POD. Its largest union
// members require eight-byte alignment and the structure occupies 24 bytes on
// Ghostty's supported targets. Keeping the storage in the caller mirrors the
// source's `var value = gobject.ext.Value.new(...)` and avoids a heap allocation
// that `g_value_unset` does not free.
struct GValueStorage {
mut:
	words [3]u64
}

fn (mut storage GValueStorage) ptr() GValue {
	return GValue(&storage.words[0])
}

// --- GSettings (GNOME schema) bindings ------------------------------------
//
// Provided per the translation brief for reading GNOME/GSettings schema values
// (e.g. org.gnome.desktop.interface). Not used by the Zig gsettings.zig itself,
// which only reads GtkSettings, but declared here for the module to build on.

// GSettings handle alias `GSettings` is declared in c_gtk_linux.v; reused here.

fn C.g_settings_new(schema_id &char) GSettings
fn C.g_settings_get_boolean(settings GSettings, key &char) int
fn C.g_settings_get_int(settings GSettings, key &char) int
fn C.g_settings_get_string(settings GSettings, key &char) &char
fn C.g_settings_get_double(settings GSettings, key &char) f64

// gsettings_new creates a GSettings object for the given schema id. Returns nil
// if the schema is not installed (GLib aborts in that case, so callers should
// only use known-installed schemas).
pub fn gsettings_new(schema_id string) GSettings {
	return C.g_settings_new(&char(schema_id.str))
}

// gsettings_get_boolean reads a boolean value from a GSettings schema.
pub fn gsettings_get_boolean(settings GSettings, key string) bool {
	return C.g_settings_get_boolean(settings, &char(key.str)) != 0
}

// gsettings_get_int reads an integer value from a GSettings schema.
pub fn gsettings_get_int(settings GSettings, key string) int {
	return C.g_settings_get_int(settings, &char(key.str))
}

// gsettings_get_double reads a double value from a GSettings schema.
pub fn gsettings_get_double(settings GSettings, key string) f64 {
	return C.g_settings_get_double(settings, &char(key.str))
}

// gsettings_get_string reads a string value from a GSettings schema. The
// returned string is a V copy; the GLib-allocated original is freed.
pub fn gsettings_get_string(settings GSettings, key string) string {
	ptr := C.g_settings_get_string(settings, &char(key.str))
	if isnil(ptr) {
		return ''
	}
	result := unsafe { cstring_to_vstring(ptr) }
	g_free_mem(voidptr(ptr))
	return result
}
