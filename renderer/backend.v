module renderer

// Possible renderer backend implementations, used for build options.
pub enum Backend as u8 {
	opengl
	metal
	webgl
}

// Returns the default backend for the current platform.
pub fn Backend.default_() Backend {
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
