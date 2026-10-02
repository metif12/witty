module renderer

fn test_unconfigured_metal_library_requires_build_artifact() {
	$if !compiled_metallib ? {
		load_builtin_metal_library(unsafe { nil }) or {
			assert err.msg().starts_with('MetalShaderLibraryNotBuilt:')
			return
		}
		assert false
	}
}
