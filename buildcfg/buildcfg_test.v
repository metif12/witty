module buildcfg

fn test_source_runtime_safety_modes() {
	$if prod {
		assert !runtime_safety
		assert !slow_runtime_safety
	} $else $if release_safe ? {
		assert runtime_safety
		assert !slow_runtime_safety
	} $else {
		assert runtime_safety
		assert slow_runtime_safety
	}
}
