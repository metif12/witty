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

import os
import global_state


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

// ghostty_init initializes ghostty global state. In Ghostty's C API this
// receives (argc, argv) from the embedder; in V we rely on `os.args` which
// is already populated. The signature is kept so it can be called from a
// host that wants to pass through process args. Returns 0 on success and
// 1 on initialization failure (matching the Zig return).
pub fn ghostty_init(argc int, argv []string) int {
	// Ghostty's Zig version sets `std.os.argv = argv[0..argc]` here before
	// initializing global state. V's `os.args` is populated automatically
	// from libc and exposed as an immutable const, so we don't reassign it;
	// any embedder that needs a different argv should set it through env
	// inheritance instead.
	_ = argc
	_ = argv

	mut state := global_state.get_state_mut()
	state.init() or {
		eprintln('failed to initialize ghostty error=${err}')
		return 1
	}
	return 0
}

// ghostty_cli_try_action runs the detected CLI action if one was set during
// global state init. If there is no action this returns; otherwise it runs
// the action and exits the process with its return code.
pub fn ghostty_cli_try_action() {
	state := global_state.get_state()
	if state.action == .none {
		return
	}
	eprintln('executing CLI action=${state.action}')
	// XTODO: action.run(state.alloc) once cli module is translated.
	// For now we treat any non-none action as a no-op that exits 0.
	exit(0)
}

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
