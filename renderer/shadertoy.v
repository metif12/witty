module renderer

import configpkg
import os
import time

const shadertoy_prefix = $embed_file('shaders/shadertoy_prefix.glsl').to_string()
const max_shader_size = 4 * 1024 * 1024

// The target to load shaders for.
pub enum Target as u8 {
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
pub fn load_from_files(paths configpkg.RepeatablePath, target Target) ![]string {
	mut shaders := []string{cap: paths.items.len}
	for item in paths.items {
		path := match item {
			configpkg.PathOptional { item.path }
			configpkg.PathRequired { item.path }
		}
		optional := item is configpkg.PathOptional
		shader := load_from_file(path, target) or {
			if optional && is_missing_file_error(err) {
				continue
			}
			return err
		}
		shaders << shader
	}
	return shaders
}

// Load a single shader from a file and convert it to the target language
// ready to be used with renderers.
pub fn load_from_file(path string, target Target) !string {
	if !os.exists(path) {
		return error('shader file not found: ${path}')
	}
	src := os.read_file(path) or { return error('unable to read shader ${path}: ${err}') }
	if src.len > max_shader_size {
		return error('shader exceeds 4 MiB limit: ${path}')
	}
	spv := spirv_from_glsl(glsl_from_shader(src))!
	return match target {
		.glsl { glsl_from_spv(spv)! }
		.msl { msl_from_spv(spv)! }
	}
}

// Convert a ShaderToy shader into valid GLSL.
//
// ShaderToy shaders aren't full shaders, they're just implementing a
// mainImage function and don't define any of the uniforms. This function
// will convert the ShaderToy shader into a valid GLSL shader that can be
// compiled and linked.
pub fn glsl_from_shader(src string) string {
	return shadertoy_prefix + '\n\n' + src
}

// Convert a GLSL shader into SPIR-V assembly.
pub fn spirv_from_glsl(src string) ![]u8 {
	input_path, output_path := shader_temp_paths('frag', 'spv')
	defer {
		remove_shader_temp(input_path)
		remove_shader_temp(output_path)
	}
	os.write_file(input_path, src) or { return error('unable to write temporary GLSL: ${err}') }
	run_shader_tool('glslangValidator', [
		'-V',
		'--target-env',
		'vulkan1.2',
		'-S',
		'frag',
		'-o',
		output_path,
		input_path,
	])!
	spv := os.read_file_array[u8](output_path)
	if spv.len == 0 {
		return error('glslangValidator produced empty SPIR-V')
	}
	return spv
}

// Convert SPIR-V binary to MSL.
pub fn msl_from_spv(spv []u8) !string {
	return source_from_spv(spv, .msl)
}

// Convert SPIR-V binary to GLSL.
pub fn glsl_from_spv(spv []u8) !string {
	return source_from_spv(spv, .glsl)
}

fn source_from_spv(spv []u8, target Target) !string {
	if spv.len == 0 || spv.len % 4 != 0 {
		return error('invalid SPIR-V byte length: ${spv.len}')
	}
	input_path, output_path := shader_temp_paths('spv', match target {
		.glsl { 'glsl' }
		.msl { 'metal' }
	})
	defer {
		remove_shader_temp(input_path)
		remove_shader_temp(output_path)
	}
	os.write_file_array(input_path, spv) or { return error('unable to write temporary SPIR-V: ${err}') }
	mut args := [input_path]
	match target {
		.glsl {
			args << ['--version', '430']
		}
		.msl {
			args << ['--msl', '--msl-decoration-binding']
		}
	}
	args << ['--output', output_path]
	run_shader_tool('spirv-cross', args)!
	result := os.read_file(output_path) or {
		return error('unable to read spirv-cross output: ${err}')
	}
	if result.len == 0 {
		return error('spirv-cross produced empty shader source')
	}
	return result
}

fn run_shader_tool(name string, args []string) !string {
	executable := os.find_abs_path_of_executable(name) or {
		return error('${name} is required to compile custom shaders')
	}
	mut process := os.new_process(executable)
	process.set_args(args)
	process.set_redirect_stdio()
	process.run()
	mut output := ''
	mut diagnostics := ''
	for process.is_alive() {
		if process.is_pending(.stdout) {
			output += process.stdout_read()
		}
		if process.is_pending(.stderr) {
			diagnostics += process.stderr_read()
		}
		time.sleep(time.millisecond)
	}
	output += process.stdout_slurp()
	diagnostics += process.stderr_slurp()
	process.wait()
	code := process.code
	process.close()
	if code != 0 {
		mut message := output
		if message.len > 0 && diagnostics.len > 0 {
			message += '\n'
		}
		message = (message + diagnostics).trim_space()
		if message.len > 0 {
			return error('${name} failed (${code}): ${message}')
		}
		return error('${name} failed with exit code ${code}')
	}
	return output
}

fn shader_temp_paths(input_extension string, output_extension string) (string, string) {
	stamp := time.sys_mono_now()
	base := 'witty-shader-${os.getpid()}-${stamp}'
	return os.join_path(os.temp_dir(), '${base}.${input_extension}'), os.join_path(os.temp_dir(), '${base}.${output_extension}')
}

fn remove_shader_temp(path string) {
	if os.exists(path) {
		os.rm(path) or {}
	}
}

fn is_missing_file_error(err IError) bool {
	return err.msg().starts_with('shader file not found:')
}
