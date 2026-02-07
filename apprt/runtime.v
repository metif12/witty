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
