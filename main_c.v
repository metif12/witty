// Translated from Ghostty's main_c.zig
//
// This is the main file for the C API. The C API is used to embed Ghostty
// within other applications. Depending on the build settings some APIs
// may not be available (i.e. embedding into macOS exposes various Metal
// support).
//
// This currently isn't supported as a general purpose embedding API.
// This is currently used only to embed ghostty within a macOS app. However,
// it could be expanded to be general purpose in the future.

module main


// BuildMode mirrors the C enum ghostty_build_mode_e.
pub enum BuildMode {
	debug
	release_safe
	release_fast
	release_small
}

// Info corresponds to ghostty_info_s. Contains metadata about the
// Ghostty build such as version and build mode.
pub struct Info {
pub:
	mode        BuildMode
	version     string
	version_len int
}

// GhosttyString corresponds to ghostty_string_s. A string type used
// across the C API boundary with explicit length and sentinel tracking.
pub struct GhosttyString {
pub:
	ptr      voidptr
	len      int
	sentinel bool
}

// empty returns an empty GhosttyString with null pointer.
pub fn GhosttyString.empty() GhosttyString {
	return GhosttyString{
		ptr:      unsafe { nil }
		len:      0
		sentinel: false
	}
}

// from_string creates a GhosttyString from a V string.
pub fn GhosttyString.from_string(s string) GhosttyString {
	return GhosttyString{
		ptr:      s.str
		len:      s.len
		sentinel: true
	}
}

// from_bytes creates a GhosttyString from a byte slice.
pub fn GhosttyString.from_bytes(b []u8) GhosttyString {
	return GhosttyString{
		ptr:      b.data
		len:      b.len
		sentinel: false
	}
}

// XTODO: The following C API export functions need full implementation.
// In Zig these are `export fn` declarations that get exported as C symbols.
// V doesn't have direct C export support in the same way. These would need
// to be implemented using V's C interop or as a separate C wrapper.

// ghostty_init: Initialize ghostty global state.
// XTODO: Needs global state management (global.zig equivalent).
// pub export fn ghostty_init(argc: usize, argv: [*][*:0]u8) c_int

// ghostty_cli_try_action: Runs an action if it is specified.
// XTODO: Needs CLI action infrastructure.
// pub export fn ghostty_cli_try_action() void

// ghostty_info: Return metadata about Ghostty, such as version, build mode, etc.
pub fn ghostty_info() Info {
	return Info{
		mode:        if is_debug { .debug } else { .release_fast }
		version:     version_string
		version_len: version_string.len
	}
}

// ghostty_translate: Translate a string maintained by libghostty into the
// current application language. This will return the same string (same pointer)
// if no translation is found, so the pointer must be stable through
// the function call.
//
// This should only be used for singular strings maintained by Ghostty.
// XTODO: Needs i18n/translation infrastructure.
pub fn ghostty_translate(msgid string) string {
	return msgid
}

// ghostty_string_free: Free a string allocated by Ghostty.
// XTODO: Needs allocator integration for proper deallocation.
pub fn ghostty_string_free(str GhosttyString) {
	_ = str
	// In V, memory management is handled differently.
	// The GC or manual free would be used here.
}

// XTODO: Additional C API exports that need implementation:
// - Config API (@import("config.zig").CApi)
// - Apprt-specific C API (apprt.runtime.CAPI for embedded runtime)
// - Benchmark API (@import("benchmark/main.zig").CApi)
