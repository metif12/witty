module apprt

// runtime.v - Runtime enum for the application runtime.
// Translated from ghostty/src/apprt/runtime.zig

// Runtime is the runtime to use for Ghostty. All runtimes do not provide
// equivalent feature sets.
pub enum Runtime as u8 {
	// Will not produce an executable at all when `zig build` is called.
	// This is only useful if you're only interested in the lib only (macOS).
	none_
	// GTK4. Rich windowed application. This uses a full GObject-based
	// approach to building the application.
	gtk
}

// default returns the default runtime for the build target. The source accepts
// std.Target explicitly; V's compile-time platform selection supplies the
// equivalent target here.
pub fn Runtime.default() Runtime {
	$if linux {
		return Runtime.gtk
	} $else $if freebsd {
		return Runtime.gtk
	} $else {
		return Runtime.none_
	}
}

pub fn Runtime.selected() Runtime {
	$if app_runtime_none ? { return .none_ }
	$if app_runtime_gtk ? { return .gtk }
	return Runtime.default()
}
