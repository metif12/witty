module renderer

import font
import opengl

$if renderer_opengl ?|| ( !renderer_metal ?&& !macos && !ios ) {
	fn test_image_texture_format_source_layout_and_ordinals() {
		assert sizeof(ImageTextureFormat) == 1
		assert u8(ImageTextureFormat.gray) == 0
		assert u8(ImageTextureFormat.rgba) == 1
		assert u8(ImageTextureFormat.bgra) == 2
	}

	fn test_render_pass_tags_and_counts_match_source_contract() {
		assert sizeof(GLRenderAttachmentKind) == 1
		assert u8(GLRenderAttachmentKind.texture) == 0
		assert u8(GLRenderAttachmentKind.target) == 1
		attachment_texture := GLRenderAttachmentTarget(GLTexture{
			id: 1
		})
		attachment_target := GLRenderAttachmentTarget(GLTarget{
			fbo: 2
		})
		assert attachment_texture.kind() == .texture
		assert attachment_target.kind() == .target
		assert attachment_texture is GLTexture
		assert attachment_target is GLTarget
		assert sizeof(GLVertexStepFunction) == 1
		assert u8(GLVertexStepFunction.constant) == 0
		assert u8(GLVertexStepFunction.per_vertex) == 1
		assert u8(GLVertexStepFunction.per_instance) == 2

		max_count := ~usize(0)
		buffer := GLBuffer{
			len: max_count
		}
		target := GLTarget{
			width:  max_count
			height: max_count
		}
		texture := GLTexture{
			width:  max_count
			height: max_count
		}
		draw := GLDraw{
			primitive:      .triangle_strip
			vertex_count:   max_count
			instance_count: max_count
		}
		assert buffer.len == max_count
		assert target.width == max_count
		assert target.height == max_count
		assert texture.width == max_count
		assert texture.height == max_count
		assert draw.vertex_count == max_count
		assert draw.instance_count == max_count
	}

	fn test_opengl_vertex_scalar_adapter_is_compact_and_complete() {
		assert sizeof(GLVertexScalarType) == 1
		assert u8(GLVertexScalarType.u8_) == 0
		assert u8(GLVertexScalarType.u16_) == 1
		assert u8(GLVertexScalarType.u32_) == 2
		assert u8(GLVertexScalarType.i8_) == 3
		assert u8(GLVertexScalarType.i16_) == 4
		assert u8(GLVertexScalarType.i32_) == 5
		assert u8(GLVertexScalarType.f32_) == 6
		assert u8(GLVertexScalarType.f64_) == 7
	}

	fn test_opengl_init_does_not_require_a_current_context() {
		default_api := OpenGLAPI.init(RendererOptions{})!
		assert default_api.blending == .native

		linear_api := OpenGLAPI.init(RendererOptions{
			config: DerivedConfig{
				blending: .linear_corrected
			}
		})!
		assert linear_api.blending == .linear_corrected
	}

	fn test_opengl_buffer_options_are_shared_by_every_role() {
		api := OpenGLAPI{}
		want := GLBufferOptions{
			target: .array
			usage:  .dynamic_draw
		}
		assert api.buffer_options() == want
		assert api.instance_buffer_options() == want
		assert api.uniform_buffer_options() == want
		assert api.fg_buffer_options() == want
		assert api.bg_buffer_options() == want
		assert api.image_buffer_options() == want
		assert api.bg_image_buffer_options() == want
	}

	fn test_opengl_options_retain_canonical_gl_types() {
		buffer := GLBufferOptions{
			target: .storage
			usage:  .dynamic_copy
		}
		assert buffer.target == opengl.BufferTarget.storage
		assert u32(buffer.target) == u32(C.GL_SHADER_STORAGE_BUFFER)
		assert buffer.usage == opengl.BufferUsage.dynamic_copy
		assert u32(buffer.usage) == u32(C.GL_DYNAMIC_COPY)

		texture := GLTextureOptions{
			format:          .rgb
			internal_format: .srgb
			target:          .cube_map
			min_filter:      .nearest_mipmap_linear
			mag_filter:      .nearest
			wrap_s:          .clamp_to_border
			wrap_t:          .mirrored_repeat
		}
		assert texture.format == opengl.TextureFormat.rgb
		assert texture.internal_format == opengl.TextureInternalFormat.srgb
		assert texture.target == opengl.TextureTarget.cube_map
		assert texture.min_filter == opengl.TextureMinFilter.nearest_mipmap_linear
		assert texture.mag_filter == opengl.TextureMagFilter.nearest
		assert texture.wrap_s == opengl.TextureWrap.clamp_to_border
		assert texture.wrap_t == opengl.TextureWrap.mirrored_repeat
	}

	fn test_opengl_texture_and_sampler_options_match_source() {
		api := OpenGLAPI{}
		assert api.texture_options() == GLTextureOptions{
			format:          .rgba
			internal_format: .srgba
			target:          .t2d
			min_filter:      .linear
			mag_filter:      .linear
			wrap_s:          .clamp_to_edge
			wrap_t:          .clamp_to_edge
		}
		assert api.sampler_options() == GLSamplerOptions{
			min_filter: .linear
			mag_filter: .linear
			wrap_s:     .clamp_to_edge
			wrap_t:     .clamp_to_edge
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
		assert gray.target == .rectangle
		assert gray.min_filter == .nearest

		bgra := api.atlas_texture_options(.bgra)!
		assert bgra.format == .bgra
		assert bgra.internal_format == .srgba
		assert bgra.target == .rectangle

		if _ := api.atlas_texture_options(font.AtlasFormat.bgr) {
			assert false
		} else {
			assert err.msg().contains('unsupported')
		}
	}

	fn test_opengl_shader_include_expansion_matches_source_preprocessor() {
		expanded := expand_gl_shader(gl_cell_text_vertex_shader_raw)
		assert expanded.starts_with('#version 430 core')
		assert !expanded.starts_with('#include "common.glsl"')
		assert expanded.contains('layout(location = 0) in uvec2 glyph_pos;')
	}

	fn test_opengl_shader_vertex_layouts_match_source() {
		assert $sizeof(CellText) == 32
		assert __offsetof(CellText, glyph_pos) == 0
		assert __offsetof(CellText, glyph_size) == 8
		assert __offsetof(CellText, bearings) == 16
		assert __offsetof(CellText, grid_pos) == 20
		assert __offsetof(CellText, color) == 24
		assert __offsetof(CellText, atlas) == 28
		assert __offsetof(CellText, bools) == 29

		text := gl_text_cell_attributes()
		assert text.len == 7
		assert text[0] == GLVertexAttribute{ scalar_type: .u32_, count: 2, offset: 0 }
		assert text[6] == GLVertexAttribute{ scalar_type: .u8_, count: 1, offset: 29 }

		image := gl_image_attributes()
		assert image.len == 4
		assert $sizeof(ImageVertex) == 40
		assert __offsetof(ImageVertex, grid_pos) == 0
		assert __offsetof(ImageVertex, cell_offset) == 8
		assert __offsetof(ImageVertex, source_rect) == 16
		assert __offsetof(ImageVertex, dest_size) == 32
		assert image[0].offset == 0
		assert image[3].offset == 32

		bg_image := gl_bg_image_attributes()
		assert bg_image.len == 2
		assert bg_image[1].offset == 4
	}

	fn test_opengl_uniform_conversion_packs_boolean_fields() {
		packed := gl_uniforms(Uniforms{
			padding_extend: PaddingExtend{
				left: true
				up:   true
			}
			bools:          UniformBools{
				cursor_wide:           true
				use_display_p3:        true
				use_linear_blending:   true
				use_linear_correction: true
			}
		})
		assert packed.padding_extend == 5
		assert packed.bools == 0b1111
		assert __offsetof(GLUniforms, screen_size) == 64
		assert __offsetof(GLUniforms, grid_padding) == 96
		assert __offsetof(GLUniforms, bools) == 132
	}

	fn test_opengl_text_and_background_image_values_are_packed_for_gpu() {
		text := CellText{
			atlas:    .color
			bools:    cell_text_bools(true, true)
			bearings: [i16(-2), 7]!
		}
		assert u8(text.atlas) == 1
		assert text.bools.packed() == 3
		assert text.bearings[0] == -2
		assert text.bearings[1] == 7

		bg := BgImageBuffer{
			opacity: 0.5
			info:    bg_image_info(.br, .stretch, true)
		}
		assert bg.opacity == 0.5
		assert bg.info.packed() == u8(8 | (2 << 4) | (1 << 6))
	}
}
