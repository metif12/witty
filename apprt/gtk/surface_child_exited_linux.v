module gtk

// surface_child_exited_linux.v - The GObject SurfaceChildExited widget class
// for the GTK apprt.
//
// Translated from ghostty/src/apprt/gtk/class/surface_child_exited.zig.
//
// A banner overlay shown when the terminal's child process exits, reporting
// whether the command succeeded (exit code 0) or failed. In ghostty this is an
// `adw.Banner` subclass (Adwaita >= 1.3) with a no-op fallback for older
// Adwaita. It carries the `apprt.surface.Message.ChildExited` data and formats
// a banner title + CSS class ("normal"/"abnormal") from the exit code, plus a
// `close-request` signal emitted when the banner's close button is clicked.
//
// FOLLOWING THE ESTABLISHED PATTERN: GObject registration, `.ui`/blueprint
// template, and property/signal machinery are stubbed with `// TODO(gtk)`; the
// real logic (storing the ChildExited data, deriving the banner title +
// css-class from the exit code) is translated. The class is a plain V struct
// wrapping the GObject/GtkWidget ptr.
//
// Reuses: `apprt.ChildExited` (apprt/surface.v), `gtk_widget_add_css_class` /
// `gtk_widget_remove_css_class` (surface_class_linux.v). The adw.Banner title
// setter is declared here (unique to this file).

import apprt

// --- New C bindings unique to this file -----------------------------------

// AdwBanner*.
pub type AdwBanner = voidptr

fn C.adw_banner_set_title(banner AdwBanner, title &char)

// --- SurfaceChildExited ---------------------------------------------------

// SurfaceChildExited is the V model of the `GhosttySurfaceChildExited` GObject
// class. Fields mirror the Zig `Private` struct. The Zig
// `?*apprt.surface.Message.ChildExited` is modeled with a value + presence
// flag (V has no `?struct` field ergonomics matching a boxed pointer here).
@[heap]
pub struct SurfaceChildExited {
pub mut:
	// The GtkWidget (adw.Bin) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	// The banner widget (template child).
	banner AdwBanner = unsafe { nil }

	// The child-exited data sent by the apprt, and whether it is set.
	data     apprt.ChildExited
	has_data bool
}

// new_surface_child_exited creates a new SurfaceChildExited. Mirrors instance
// `init`.
pub fn new_surface_child_exited() &SurfaceChildExited {
	return &SurfaceChildExited{}
}

// set_data stores a copy of the child-exited data (or clears it) and refreshes
// the banner. Mirrors `setData` (which copies into a glib-allocated boxed value
// and notifies the `data` property, whose notify handler runs `propData`).
pub fn (mut self SurfaceChildExited) set_data(data ?apprt.ChildExited) {
	d := data or {
		self.has_data = false
		self.apply_data()
		return
	}
	self.data = d
	self.has_data = true
	// TODO(gtk): notifyByPspec(properties.data). The notify triggers propData;
	// we invoke it directly here.
	self.apply_data()
}

// apply_data updates the banner title and CSS classes from the current data.
// Mirrors `propData`.
fn (self &SurfaceChildExited) apply_data() {
	if !self.has_data {
		// Not localized on purpose (matches the Zig original).
		C.adw_banner_set_title(self.banner, c'This is a bug in Ghostty. Please report it.')
		return
	}

	if self.data.exit_code == 0 {
		C.adw_banner_set_title(self.banner, c'Command succeeded')
		C.gtk_widget_add_css_class(self.widget, c'normal')
		C.gtk_widget_remove_css_class(self.widget, c'abnormal')
	} else {
		C.adw_banner_set_title(self.banner, c'Command failed')
		C.gtk_widget_remove_css_class(self.widget, c'normal')
		C.gtk_widget_add_css_class(self.widget, c'abnormal')
	}
}

// close_button_clicked is the banner "button-clicked" template callback. It
// requests the banner be closed. Mirrors `closeButtonClicked`.
pub fn (self &SurfaceChildExited) close_button_clicked() {
	// TODO(gtk): emit `close-request` signal.
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty this is `SurfaceChildExited = if
// (adw_version.supportsBanner()) SurfaceChildExitedBanner else
// SurfaceChildExitedNoop`. We translate the banner variant. The banner class is
// registered via gobject.ext.defineClass; classInit loads the
// `surface-child-exited` blueprint `.ui` template, binds the `banner` template
// child, wires the `clicked`/`notify_data` template callbacks, registers the
// `data` property, registers the `close-request` signal, and wires
// dispose/finalize. V has no such machinery, so all of that is stubbed. The
// no-op fallback (older Adwaita) is not modeled here since witty targets a
// modern Adwaita; its behavior is to emit `close-request` immediately on
// setData.
