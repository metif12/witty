module terminal

// Tests for build_options.v (translated from build_options.zig)

fn test_build_options_default() {
	opts := BuildOptions{}
	assert opts.artifact == .ghostty
	assert opts.oniguruma == false
	assert opts.simd == false
	assert opts.slow_runtime_safety == false
	assert opts.c_abi == false
}

fn test_build_options_custom() {
	opts := BuildOptions{
		artifact: .lib
		oniguruma: true
		simd: true
		slow_runtime_safety: false
		c_abi: true
	}
	assert opts.artifact == .lib
	assert opts.oniguruma == true
	assert opts.simd == true
	assert opts.c_abi == true
}

fn test_artifact_values() {
	assert Artifact.ghostty != Artifact.lib
}
