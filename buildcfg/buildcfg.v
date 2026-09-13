// Translated from Ghostty's src/build/Config.zig ReleaseChannel declaration.
module buildcfg

// ReleaseChannel determines the release channel for this build.
pub enum ReleaseChannel as u8 {
	// Tip/nightly release (built from latest source)
	tip
	// Stable release
	stable
}
