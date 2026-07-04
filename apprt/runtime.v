module apprt

// runtime.v - Runtime enum for the application runtime.
// Translated from ghostty/src/apprt/runtime.zig

// Runtime is the runtime to use for Ghostty. All runtimes do not provide
// equivalent feature sets.
pub enum Runtime {
	// Will not produce an executable at all when `zig build` is called.
	// This is only useful if you're only interested in the lib only (macOS).
	none_
	// GTK4. Rich windowed application. This uses a full GObject-based
	// approach to building the application.
	gtk
}

// default_for_os returns the default runtime for the given OS name. The
// Linux and FreeBSD default is GTK because it is a full featured
// application. Otherwise we use none so we don't create an exe and instead
// create libghostty (on macOS, Xcode builds the app that links the lib).
pub fn Runtime.default_for_os(os_name string) Runtime {
	return match os_name {
		'linux', 'freebsd' { Runtime.gtk }
		else { Runtime.none_ }
	}
}

// default_runtime returns the default runtime for the platform witty is
// currently built for.
pub fn default_runtime() Runtime {
	$if linux {
		return Runtime.gtk
	} $else $if freebsd {
		return Runtime.gtk
	} $else {
		return Runtime.none_
	}
}
