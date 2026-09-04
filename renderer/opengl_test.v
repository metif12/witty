module renderer

import font

fn test_opengl_init_does_not_require_a_current_context() {
	default_api := OpenGLAPI.init()!
	assert default_api.blending == .none_

	linear_api := OpenGLAPI.init(RendererOptions{
		config: DerivedConfig{
			blending: .linear_corrected
		}
	})!
	assert linear_api.blending == .linear_corrected
}

fn test_opengl_target_options_follow_blending_mode() {
	native := OpenGLAPI{
		blending: .none_
	}
	assert native.target_options(80, 24) == GLTargetOptions{
		width: 80
		height: 24
		internal_format: .rgba
	}

	linear := OpenGLAPI{
		blending: .linear
	}
	assert linear.target_options(120, 40) == GLTargetOptions{
		width: 120
		height: 40
		internal_format: .srgba
	}
}

fn test_opengl_buffer_options_are_shared_by_every_role() {
	api := OpenGLAPI{}
	want := GLBufferOptions{
		target: .array
		usage: .dynamic_draw
	}
	assert api.buffer_options() == want
	assert api.instance_buffer_options() == want
	assert api.uniform_buffer_options() == want
	assert api.fg_buffer_options() == want
	assert api.bg_buffer_options() == want
	assert api.image_buffer_options() == want
	assert api.bg_image_buffer_options() == want
}

fn test_opengl_texture_and_sampler_options_match_source() {
	api := OpenGLAPI{}
	assert api.texture_options() == GLTextureOptions{
		format: .rgba
		internal_format: .srgba
		target: .texture_2d
		min_filter: .linear
		mag_filter: .linear
		wrap_s: .clamp_to_edge
		wrap_t: .clamp_to_edge
	}
	assert api.sampler_options() == GLSamplerOptions{
		min_filter: .linear
		mag_filter: .linear
		wrap_s: .clamp_to_edge
		wrap_t: .clamp_to_edge
	}
}

fn test_opengl_image_texture_options_translate_pixel_layout_and_color_space() {
	api := OpenGLAPI{}
	gray := api.image_texture_options(.gray, false)
	assert gray.format == .red
	assert gray.internal_format == .rgba
	assert gray.min_filter == .linear

	bgra := api.image_texture_options(.bgra, true)
	assert bgra.format == .bgra
	assert bgra.internal_format == .srgba
}

fn test_opengl_atlas_texture_options_match_atlas_layout() {
	api := OpenGLAPI{}
	gray := api.atlas_texture_options(.grayscale)!
	assert gray.format == .red
	assert gray.internal_format == .red
	assert gray.target == .texture_rectangle
	assert gray.min_filter == .nearest

	bgra := api.atlas_texture_options(.bgra)!
	assert bgra.format == .bgra
	assert bgra.internal_format == .srgba
	assert bgra.target == .texture_rectangle

	if _ := api.atlas_texture_options(font.AtlasFormat.bgr) {
		assert false
	} else {
		assert err.msg().contains('unsupported')
	}
}
