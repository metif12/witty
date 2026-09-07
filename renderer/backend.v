module renderer

// Possible renderer backend implementations, used for build options.
pub enum Backend {
	opengl
	metal
	webgl
}

// Returns the default backend for the current platform.
pub fn Backend.default_backend() Backend {
	$if wasm32 {
		return .webgl
	} $else $if macos {
		return .metal
	} $else $if ios {
		return .metal
	} $else {
		return .opengl
	}
}
