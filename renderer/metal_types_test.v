module renderer

import macos

fn test_metal_render_step_counts_retain_source_pointer_width() {
	max_count := ~usize(0)
	buffer := MetalBuffer{
		len: max_count
	}
	step := MetalRenderStep{
		vertex_count: max_count
		instance_count: max_count
	}
	assert buffer.len == max_count
	assert step.vertex_count == max_count
	assert step.instance_count == max_count
}

fn test_metal_buffer_sync_writes_native_buffer() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut buffer := MetalBuffer.init(api.buffer_options(), 2)!
	defer {
		buffer.deinit()
	}

	buffer.sync([u8(1), 2, 3, 4])!

	// Metal queries the native allocation on every sync, so Ghostty retains
	// the initialization length even when the underlying buffer grows.
	assert buffer.len == 2
	assert macos.metal_buffer_length(buffer.handle) == 8
	assert read_metal_buffer(buffer, 4) == [u8(1), 2, 3, 4]
}

fn test_metal_texture_initial_upload_and_replace_region() ! {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut texture := MetalTexture.init(api.image_texture_options(.gray, false), 4, 4,
		[u8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])!
	defer {
		texture.deinit()
	}

	texture.replace_region(1, 1, 2, 2, [u8(90), 80, 70, 60])!

	bytes := read_metal_texture(texture)
	assert bytes[0..4] == [u8(0), 1, 2, 3]
	assert bytes[5] == 90
	assert bytes[6] == 80
	assert bytes[9] == 70
	assert bytes[10] == 60
}

fn test_metal_buffer_init_fill_copies_data() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut buffer := MetalBuffer.init_fill(api.buffer_options(), [u8(5), 6, 7])!
	defer {
		buffer.deinit()
	}

	assert buffer.len == 3
	assert macos.metal_buffer_length(buffer.handle) == 3
	assert read_metal_buffer(buffer, 3) == [u8(5), 6, 7]
}

fn test_metal_buffer_sync_within_capacity_leaves_tail() {
	// Preallocate a 4-element buffer, then sync fewer elements. The
	// remaining (untouched) bytes should not be reallocated away and the
	// capacity should be preserved. (Port of buffer.zig sync semantics.)
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut buffer := MetalBuffer.init_fill(api.buffer_options(), [u8(0), 0, 0, 0])!
	defer {
		buffer.deinit()
	}

	buffer.sync([u8(1), 2])!

	assert buffer.len == 4
	assert macos.metal_buffer_length(buffer.handle) == 4
	data := read_metal_buffer(buffer, 4)
	assert data[0] == 1
	assert data[1] == 2
	// Tail is left untouched (still zero from the initial allocation).
	assert data[2] == 0
	assert data[3] == 0
}

fn test_metal_texture_bpp_for_pixel_formats() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	// r8unorm is 1 byte per pixel: a 2x2 texture is 4 bytes.
	mut gray := MetalTexture.init(api.image_texture_options(.gray, false), 2, 2, none)!
	defer {
		gray.deinit()
	}
	assert gray.bpp == 1

	// bgra8unorm is 4 bytes per pixel: a 2x2 texture is 16 bytes.
	mut color := MetalTexture.init(api.image_texture_options(.bgra, false), 2, 2, none)!
	defer {
		color.deinit()
	}
	assert color.bpp == 4
}

fn test_metal_texture_replace_region_respects_bpp() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	// 2x2 bgra8unorm texture (4 bytes per pixel, row stride = 8 bytes).
	mut texture := MetalTexture.init(api.image_texture_options(.bgra, false), 2, 2,
		[]u8{len: 16})!
	defer {
		texture.deinit()
	}

	// Replace the single pixel at (1, 1) with 4 bytes.
	texture.replace_region(1, 1, 1, 1, [u8(11), 22, 33, 44])!

	// Pixel (1, 1) lives at offset 1*8 + 1*4 = 12.
	data := read_metal_texture(texture)
	assert data[12] == 11
	assert data[13] == 22
	assert data[14] == 33
	assert data[15] == 44
	// Other pixels untouched.
	assert data[0] == 0
	assert data[11] == 0
}

fn read_metal_buffer(buffer MetalBuffer, len int) []u8 {
	mut result := []u8{len: len}
	if len > 0 {
		ptr := macos.metal_buffer_contents(buffer.handle)
		assert ptr != unsafe { nil }
		unsafe { vmemcpy(result.data, ptr, len) }
	}
	return result
}

fn read_metal_texture(texture MetalTexture) []u8 {
	mut result := []u8{len: int(texture.width * texture.height * texture.bpp)}
	macos.metal_texture_get_bytes(texture.handle, mut result, usize(texture.width * texture.bpp), 0, 0, usize(texture.width), usize(texture.height))
	return result
}

fn test_metal_sampler_target_and_empty_frame() ! {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}

	mut sampler := MetalSampler.init(MetalSamplerOptions{
		device: api.device
	})!
	defer {
		sampler.deinit()
	}
	assert sampler.handle != unsafe { nil }

	mut target := MetalTarget.init(MetalTargetOptions{
		device: api.device
		width: 8
		height: 6
		storage_mode: api.default_storage_mode
	})!
	defer {
		target.deinit()
	}
	assert target.surface.get_width() == 8
	assert target.surface.get_height() == 6
	assert target.texture != unsafe { nil }

	mut frame := MetalFrame.begin(api.queue)!
	mut pass := MetalRenderPass.begin(frame.command_buffer, [MetalRenderPassAttachment{
		texture: target.texture
		clear_color: [f64(0.25), 0.5, 0.75, 1.0]!
	}])!
	pass.complete()
	assert frame.complete(true) == .completed
}

fn test_metal_builtin_shader_pipelines_compile() ! {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut shaders := MetalShaders.init(api.device, []string{}, .bgra8unorm)!
	assert shaders.library != unsafe { nil }
	assert shaders.bg_color.handle != unsafe { nil }
	assert shaders.cell_bg.handle != unsafe { nil }
	assert shaders.cell_text.handle != unsafe { nil }
	assert shaders.image.handle != unsafe { nil }
	assert shaders.bg_image.handle != unsafe { nil }
	assert $sizeof(CellText) == 32

	mut target := MetalTarget.init(MetalTargetOptions{
		device: api.device
		width: 4
		height: 4
		storage_mode: api.default_storage_mode
	})!
	defer {
		target.deinit()
	}
	mut uniforms := MetalBuffer.init_fill(api.buffer_options(), []u8{len: int($sizeof(Uniforms))})!
	defer {
		uniforms.deinit()
	}
	mut frame := MetalFrame.begin(api.queue)!
	mut pass := MetalRenderPass.begin(frame.command_buffer, [MetalRenderPassAttachment{
		texture: target.texture
		clear_color: [f64(0), 0, 0, 1]!
	}])!
	pass.step(MetalRenderStep{
		pipeline: shaders.bg_color
		uniforms: uniforms.handle
		vertex_count: 3
	})
	pass.complete()
	assert frame.complete(true) == .completed

	mut layer := MetalIOSurfaceLayer.init()!
	assert layer.layer != unsafe { nil }
	layer.set_surface_sync(target.surface)
	layer.release()
	shaders.deinit()
	// Ghostty deliberately makes shader teardown idempotent.
	shaders.deinit()
}

fn test_metal_text_cell_grayscale_no_flags() {
	cell := CellText{
		atlas: .grayscale
		grid_pos: [u16(1), 2]!
	}

	assert u8(cell.atlas) == 0
	assert cell.bools.packed() == 0
	assert cell.grid_pos[0] == 1
	assert cell.grid_pos[1] == 2
}

fn test_metal_text_cell_keeps_color_atlas_flag() {
	cell := CellText{
		atlas: .color
		bools: cell_text_bools(true, true)
		grid_pos: [u16(3), 4]!
		color: [u8(10), 20, 30, 40]!
		glyph_pos: [u32(5), 6]!
		glyph_size: [u32(7), 8]!
		bearings: [i16(1), 2]!
	}

	assert u8(cell.atlas) == 1
	assert cell.bools.packed() == 3
	assert cell.grid_pos[0] == 3
	assert cell.grid_pos[1] == 4
}

fn test_metal_uniform_layout_matches_shader_abi() {
	assert $sizeof(MetalUniforms) == 144
	assert __offsetof(MetalUniforms, projection_matrix) == 0
	assert __offsetof(MetalUniforms, screen_size) == 64
	assert __offsetof(MetalUniforms, cell_size) == 72
	assert __offsetof(MetalUniforms, grid_size) == 80
	assert __offsetof(MetalUniforms, grid_padding) == 96
	assert __offsetof(MetalUniforms, padding_extend) == 112
	assert __offsetof(MetalUniforms, min_contrast) == 116
	assert __offsetof(MetalUniforms, cursor_pos) == 120
	assert __offsetof(MetalUniforms, cursor_color) == 124
	assert __offsetof(MetalUniforms, bg_color) == 128
	assert __offsetof(MetalUniforms, cursor_wide) == 132
	assert __offsetof(MetalUniforms, use_linear_correction) == 135
}

fn test_metal_uniform_and_background_flags_are_packed() {
	uniforms := metal_uniforms(Uniforms{
		padding_extend: PaddingExtend{
			left: true
			up: true
		}
		bools: UniformBools{
			cursor_wide: true
			use_linear_correction: true
		}
	})
	assert uniforms.padding_extend == 5
	assert uniforms.cursor_wide == 1
	assert uniforms.use_linear_correction == 1

	background := BgImageBuffer{
		opacity: 0.5
		info: bg_image_info(.br, .stretch, true)
	}
	assert background.opacity == 0.5
	assert background.info.packed() == u8(8 | (2 << 4) | (1 << 6))
}
