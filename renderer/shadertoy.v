module renderer

import configpkg

// The target to load shaders for.
pub enum ShaderTarget {
	glsl
	msl
}

// SpirvLog retrieves errors from SPIR-V compilation.
pub struct SpirvLog {
pub mut:
	info  string
	debug string
}

pub fn (mut self SpirvLog) deinit() {
	self.info = ''
	self.debug = ''
}

// Load a set of shaders from files and convert them to the target
// format. The shader order is preserved.
pub fn load_shaders_from_files(paths configpkg.RepeatablePath, target ShaderTarget) ![]string {
	// XTODO: Shader loading requires file I/O, GLSL parsing,
	// glslang SPIR-V compilation, and spirv-cross conversion.
	// The pipeline is:
	// 1. Read shader file from disk
	// 2. Convert ShaderToy fragment to full GLSL (prepend uniforms prefix)
	// 3. Compile GLSL to SPIR-V using glslang
	// 4. Convert SPIR-V to target language (GLSL or MSL) using spirv-cross
	_ = paths
	_ = target
	return []string{}
}

// Load a single shader from a file and convert it to the target language
// ready to be used with renderers.
pub fn load_shader_from_file(path string, target ShaderTarget) !string {
	// XTODO: Same pipeline as load_shaders_from_files but for a single file.
	_ = path
	_ = target
	return ''
}

// Convert a ShaderToy shader into valid GLSL.
//
// ShaderToy shaders aren't full shaders, they're just implementing a
// mainImage function and don't define any of the uniforms. This function
// will convert the ShaderToy shader into a valid GLSL shader that can be
// compiled and linked.
pub fn glsl_from_shader(src string) string {
	// XTODO: This should prepend the shadertoy_prefix.glsl contents
	// which define all the uniforms (iResolution, iTime, etc.) and then
	// append the user's shader source.
	prefix := '// Shadertoy prefix would be prepended here\n'
	return prefix + '\n\n' + src
}

// Convert a GLSL shader into SPIR-V assembly.
pub fn spirv_from_glsl(src string) ![]u8 {
	// XTODO: SPIR-V compilation requires glslang C library bindings.
	// The process:
	// 1. Create glslang input with GLSL source, fragment stage, Vulkan 1.2 target
	// 2. Preprocess and parse the shader
	// 3. Link the program
	// 4. Generate SPIR-V binary output
	_ = src
	return []u8{}
}

// Convert SPIR-V binary to MSL.
pub fn msl_from_spv(spv []u8) !string {
	// XTODO: MSL conversion requires spirv-cross C library bindings.
	// Uses SPVC_BACKEND_MSL with decoration binding enabled.
	_ = spv
	return ''
}

// Convert SPIR-V binary to GLSL.
pub fn glsl_from_spv(spv []u8) !string {
	// XTODO: GLSL conversion requires spirv-cross C library bindings.
	// Uses SPVC_BACKEND_GLSL with version 430.
	_ = spv
	return ''
}
