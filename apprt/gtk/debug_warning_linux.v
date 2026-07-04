module gtk

// debug_warning_linux.v - Debug warning banner (GhosttyDebugWarning).
//
// Translated from ghostty/src/apprt/gtk/class/debug_warning.zig.
//
// In ghostty this is a GObject class that shows a "you are running a debug
// build" banner. Its parent is `adw.Bin` (wrapping an `adw.Banner`) when the
// linked libadwaita supports banners (1.3+), otherwise `gtk.Box` (wrapping a
// `gtk.Label`), chosen at comptime. The visual tree comes entirely from a
// compiled blueprint `.ui` template.
//
// V has no GObject class-registration / comptime / template machinery, so:
//   * The class is modeled as a plain V struct `DebugWarning` wrapping the
//     underlying GObject pointer (`obj`). The parent choice (Bin vs Box) is a
//     RUNTIME check (`adw_supports_banner()`) instead of comptime.
//   * GObject type registration (`defineClass`), the `.ui` template
//     (`setTemplateFromResource` / `initTemplate`), and the `Common` ref helpers
//     are STUBBED — see the "GObject class registration" section. There is no
//     real logic beyond building the template, which is out of scope.

// --- New opaque handle aliases --------------------------------------------
// (Grep-verified: not declared elsewhere in the module.)

// AdwBin is an AdwBin* (banner container, libadwaita >= 1.3).
pub type AdwBin = voidptr

// --- DebugWarning ---------------------------------------------------------

// DebugWarning is the debug-build warning banner GObject
// (`GhosttyDebugWarning`). Modeled as a struct wrapping the GObject pointer.
@[heap]
pub struct DebugWarning {
mut:
	// The underlying AdwBin/GtkBox GObject instance pointer.
	//
	// TODO(gtk): GObject class registration — created via
	// `gobject.ext.defineClass`/`newInstance` in ghostty; stubbed handle here.
	obj GObject = unsafe { nil }
}

// debug_warning_new creates a new DebugWarning banner.
//
// TODO(gtk): ghostty builds the widget tree from the compiled blueprint via
// `gtk.Widget.initTemplate` (the `instanceInit`). The banner uses blueprint
// version 1.3 when banners are supported, else 1.2. That template machinery has
// no V equivalent; here we allocate the plain wrapper.
pub fn debug_warning_new() &DebugWarning {
	return &DebugWarning{}
}

// --- GObject reference counting -------------------------------------------
// Mirrors the `Common(Self, null)` ref helpers.

// ref increments the reference count of the DebugWarning GObject.
pub fn (mut self DebugWarning) ref() {
	if !isnil(self.obj) {
		object_ref(self.obj)
	}
}

// unref decrements the reference count of the DebugWarning GObject.
pub fn (mut self DebugWarning) unref() {
	if !isnil(self.obj) {
		object_unref(self.obj)
	}
}
