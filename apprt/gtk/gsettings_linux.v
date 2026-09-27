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
