module renderer

import configpkg
import os

fn test_shader_target_source_layout_and_ordinals() {
	assert sizeof(Target) == 1
	assert u8(Target.glsl) == 0
	assert u8(Target.msl) == 1
}

fn test_glsl_from_shader_uses_ghostty_prefix() {
	user_source := 'void mainImage(out vec4 color, in vec2 coord) { color = vec4(1); }'
	source := glsl_from_shader(user_source)
	assert source.starts_with('#version 430 core\n')
	assert source.contains('layout(binding = 1, std140) uniform Globals')
	assert source.contains('uniform vec4  iCurrentCursor;')
	assert source.contains('void main() { mainImage (_fragColor, gl_FragCoord.xy); }')
	assert source == shadertoy_prefix + '\n\n' + user_source
}

fn test_load_shaders_skips_only_missing_optional_files() {
	missing := os.join_path(os.temp_dir(), 'witty-shader-missing-${os.getpid()}.glsl')
	paths := configpkg.RepeatablePath{
		items: [configpkg.Path{ path: missing, optional: true }]
	}
	assert load_from_files(paths, .glsl)! == []string{}

	required := configpkg.RepeatablePath{
		items: [configpkg.Path{ path: missing }]
	}
	load_from_files(required, .glsl) or {
		assert err.msg().starts_with('shader file not found:')
		return
	}
	assert false, 'missing required shader should fail'
}

fn test_spirv_cross_rejects_invalid_byte_length_before_tool_lookup() {
	msl_from_spv([u8(1), 2, 3]) or {
		assert err.msg() == 'invalid SPIR-V byte length: 3'
		return
	}
	assert false, 'invalid SPIR-V should fail'
}

fn test_shader_conversion_pipeline_invokes_compilers() {
	$if windows {
		return
	}
	dir := os.join_path(os.temp_dir(), 'witty-shader-tools-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	glslang_path := os.join_path(dir, 'glslangValidator')
	spirv_cross_path := os.join_path(dir, 'spirv-cross')
	os.write_file(glslang_path, '#!/bin/sh
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then out="$2"; shift 2; else shift; fi
done
printf "\\003\\002\\043\\007" > "$out"
')!
	os.write_file(spirv_cross_path, '#!/bin/sh
out=""
kind="glsl"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) out="$2"; shift 2 ;;
    --msl) kind="msl"; shift ;;
    *) shift ;;
  esac
done
printf "%s-output" "$kind" > "$out"
')!
	os.chmod(glslang_path, 0o700)!
	os.chmod(spirv_cross_path, 0o700)!
	old_path := os.getenv_opt('PATH')
	os.setenv('PATH', dir, true)
	defer {
		if value := old_path {
			os.setenv('PATH', value, true)
		} else {
			os.unsetenv('PATH')
		}
	}

	spv := spirv_from_glsl('#version 430 core\nvoid main() {}')!
	assert spv == [u8(3), 2, 35, 7]
	assert glsl_from_spv(spv)! == 'glsl-output'
	assert msl_from_spv(spv)! == 'msl-output'
}
