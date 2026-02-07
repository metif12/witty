module renderer

// Possible renderer backend implementations, used for build options.
pub enum Backend {
	opengl
	metal
	webgl
}

// Returns the default backend for the current platform.
pub fn Backend.default_backend() Backend {
	// On macOS/iOS, Metal is preferred.
	// On other platforms, OpenGL is the default.
	$if macos {
		return .metal
	} $else $if ios {
		return .metal
	} $else {
		return .opengl
	}
}
