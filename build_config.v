// Translated from Ghostty's build_config.zig
//
// Build options, available at comptime. Used to configure features. This
// will reproduce some of the fields from builtin and build_options just
// so we can limit the amount of imports we need AND give us the ability
// to shim logic and values into them later.

module main

// The semantic version of this build as a string.
pub const version_string = '0.1.0-dev'

// ReleaseChannel determines the release channel for this build.
pub enum ReleaseChannel {
	// Stable release
	stable
	// Tip/nightly release (built from latest source)
	tip
}

// The release channel for this build.
pub const release_channel = ReleaseChannel.tip

// The artifact we're producing. This can be used to determine if we're
// building a standalone exe, an embedded lib, etc.
pub enum Artifact {
	// Standalone executable
	exe
	// Embeddable library
	lib
	// The WASM-targeted module.
	wasm_module
}

// The artifact being built. In V this defaults to exe.
pub const artifact = Artifact.exe

// The bundle ID for the app. This is used in many places and is currently
// hardcoded here. We could make this configurable in the future if there
// is a reason to do so.
//
// On macOS, this must match the App bundle ID. We can get that dynamically
// via an API but I don't want to pay the cost of that at runtime.
//
// On GTK, this should match the various folders with resources.
//
// There are many places that don't use this variable so simply swapping
// this variable is NOT ENOUGH to change the bundle ID. I just wanted to
// avoid it in V code as much as possible.
pub const bundle_id = 'com.mitchellh.ghostty'

// True if runtime safety checks are enabled.
// In V, this maps to whether we're in a debug build.
// V doesn't expose build mode as a comptime constant, so we default to true
// for safety. Override this for release builds.
pub const is_debug = true

// True if we should have "slow" runtime safety checks. The initial motivation
// for this was terminal page/pagelist integrity checks. These were VERY
// slow but very thorough. But they made it so slow that the terminal couldn't
// be used for real work. We'd love to have an option to run a build with
// safety checks that could be used for real work. This lets us do that.
//
// In Zig this is: std.debug.runtime_safety and builtin.mode == .Debug
// In V, we tie it to is_debug. In release builds this should be false.
pub const slow_runtime_safety = is_debug
