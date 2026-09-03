module terminal

// Translated from ghostty/src/terminal/build_options.zig

// Options set by Zig build.zig and exposed via `terminal_options`.
pub struct BuildOptions {
pub:
	// The target artifact to build. This will gate some functionality.
	artifact Artifact = .ghostty
	// Whether Oniguruma regex support is available. If this isn't
	// available, some features will be disabled. This may be outdated,
	// but the specific disabled features are:
	//
	// - Kitty graphics protocol
	// - Tmux control mode
	//
	oniguruma bool
	// Whether to build SIMD-accelerated code paths. This pulls in more
	// build-time dependencies and adds libc as a runtime dependency,
	// but results in significant performance improvements.
	simd bool
	// True if we should enable the "slow" runtime safety checks. These
	// are runtime safety checks that are slower than typical and should
	// generally be disabled in production builds.
	slow_runtime_safety bool
	// Force C ABI mode on or off. If not set, then it will be set based on
	// Options.
	c_abi bool
}

// The Zig `add` method installs these fields into a Zig Build.Module. V build
// options are selected by compile-time defines rather than module mutation;
// these accessors expose the two values synthesized by Ghostty's build step.
pub fn (self BuildOptions) kitty_graphics() bool {
	return self.oniguruma
}

pub fn (self BuildOptions) tmux_control_mode() bool {
	return self.oniguruma
}

pub enum Artifact {
	// Ghostty application
	ghostty
	// libghostty-vt, Zig module
	lib
}
