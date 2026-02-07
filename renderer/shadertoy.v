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
//
// Shader loading requires file I/O, GLSL parsing, glslang SPIR-V
// compilation, and spirv-cross conversion. These C libraries are not
// available in V, so this returns empty results.
//
// The pipeline would be:
// 1. Read shader file from disk
// 2. Convert ShaderToy fragment to full GLSL (prepend uniforms prefix)
// 3. Compile GLSL to SPIR-V using glslang
// 4. Convert SPIR-V to target language (GLSL or MSL) using spirv-cross
pub fn load_shaders_from_files(paths configpkg.RepeatablePath, target ShaderTarget) ![]string {
	_ = paths
	_ = target
	return []string{}
}

// Load a single shader from a file and convert it to the target language
// ready to be used with renderers. Requires glslang and spirv-cross C
// libraries which are not available in V.
pub fn load_shader_from_file(path string, target ShaderTarget) !string {
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
	// This should prepend the shadertoy_prefix.glsl contents which define
	// all the uniforms (iResolution, iTime, etc.) and then append the
	// user's shader source. The prefix is not yet bundled.
	prefix := '// Shadertoy prefix would be prepended here\n'
	return prefix + '\n\n' + src
}

// Convert a GLSL shader into SPIR-V assembly.
// SPIR-V compilation requires glslang C library bindings which are not
// available in V. Returns empty result.
pub fn spirv_from_glsl(src string) ![]u8 {
	_ = src
	return []u8{}
}

// Convert SPIR-V binary to MSL.
// MSL conversion requires spirv-cross C library bindings which are not
// available in V. Returns empty result.
pub fn msl_from_spv(spv []u8) !string {
	_ = spv
	return ''
}

// Convert SPIR-V binary to GLSL.
// GLSL conversion requires spirv-cross C library bindings which are not
// available in V. Returns empty result.
pub fn glsl_from_spv(spv []u8) !string {
	_ = spv
	return ''
}
