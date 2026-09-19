module renderer

import kitty
import terminal
import macos

struct ImageMetalFrameCapture {
mut:
	calls  int
	status u64
	sync_  bool
}

fn image_metal_frame_completion(renderer_ptr voidptr, target_ptr voidptr, status u64, sync_ bool) {
	mut capture := unsafe { &ImageMetalFrameCapture(renderer_ptr) }
	assert target_ptr != unsafe { nil }
	capture.calls++
	capture.status = status
	capture.sync_ = sync_
}

// ============================================================
// Image tests
// ============================================================

// Test PixelFormat bytes per pixel.
fn test_pixel_format_bpp() {
	assert sizeof(PixelFormat) == 1
	assert u8(PixelFormat.gray) == 0
	assert u8(PixelFormat.gray_alpha) == 1
	assert u8(PixelFormat.rgb) == 2
	assert u8(PixelFormat.bgr) == 3
	assert u8(PixelFormat.rgba) == 4
	assert u8(PixelFormat.bgra) == 5
	assert PixelFormat.gray.bpp() == 1
	assert PixelFormat.gray_alpha.bpp() == 2
	assert PixelFormat.rgb.bpp() == 3
	assert PixelFormat.bgr.bpp() == 3
	assert PixelFormat.rgba.bpp() == 4
	assert PixelFormat.bgra.bpp() == 4
}

// Test PendingImage data_len calculation.
fn test_pending_image_data_len() {
	p := PendingImage{
		width: 10
		height: 20
		pixel_format: .rgba
	}
	assert p.data_len() == 10 * 20 * 4
}

// Test PendingImage data_len with different format.
fn test_pending_image_data_len_rgb() {
	p := PendingImage{
		width: 5
		height: 5
		pixel_format: .rgb
	}
	assert p.data_len() == 5 * 5 * 3
}

fn test_pending_image_length_uses_source_usize_contract() {
	p := PendingImage{
		width: 70_000
		height: 70_000
		pixel_format: .gray
	}
	assert p.len() == usize(4_900_000_000)
}

fn test_pending_image_data_slice() {
	p := PendingImage{
		width: 2
		height: 1
		pixel_format: .rgb
		data: [u8(1), 2, 3, 4, 5, 6]
	}
	assert p.len() == 6
	assert p.data_slice() == [u8(1), 2, 3, 4, 5, 6]
}

fn test_image_prep_for_upload_converts_in_place() ! {
	mut image := Image{
		state: .pending
		pending: PendingImage{
			width: 2
			height: 1
			pixel_format: .bgr
			data: [u8(1), 2, 3, 4, 5, 6]
		}
	}
	image.prep_for_upload()!
	pending := image.pending or { return error('missing converted image') }
	assert pending.pixel_format == .rgba
	assert pending.data == [u8(3), 2, 1, 255, 6, 5, 4, 255]

	// Preparation is idempotent once the data is RGBA.
	image.prep_for_upload()!
	assert (image.pending or { return error('missing converted image') }).data == pending.data
}

// Test Image state transitions.
fn test_image_state_pending() {
	img := Image{}
	assert img.state == .pending
	assert img.is_pending()
	assert !img.is_unloading()
	assert !img.has_texture()
}

// Test Image mark_for_unload.
fn test_image_mark_for_unload() {
	mut img := Image{}
	img.state = .ready
	img.mark_for_unload()
	assert img.state == .unload_ready
	assert img.is_unloading()
	assert !img.is_pending()
	assert img.has_texture()
}

fn test_image_mark_for_unload_preserves_pending_and_replace_variants() {
	mut pending := Image{ state: .pending }
	pending.mark_for_unload()
	assert pending.state == .unload_pending
	assert pending.is_pending()
	assert !pending.has_texture()

	mut replace := Image{ state: .replace }
	replace.mark_for_unload()
	assert replace.state == .unload_replace
	assert replace.is_pending()
	assert replace.has_texture()

	replace.mark_for_unload()
	assert replace.state == .unload_replace
}

// Test Image has_texture.
fn test_image_has_texture() {
	mut img := Image{}
	img.state = .ready
	assert img.has_texture()
	img.state = .replace
	assert img.has_texture()
	img.state = .pending
	assert !img.has_texture()
	img.state = .unload_ready
	assert img.has_texture()
	img.state = .unload_replace
	assert img.has_texture()
}

// Test Image mark_for_replace.
fn test_image_mark_for_replace() {
	mut img := Image{
		width: 10
		height: 10
	}
	img.state = .ready
	img.mark_for_replace(PendingImage{
		width: 20
		height: 20
		pixel_format: .rgba
	})
	assert img.state == .replace
	assert img.is_pending()
	assert img.has_texture()
}

fn test_image_mark_for_replace_without_texture_stays_pending() {
	mut img := Image{ state: .unload_pending }
	img.mark_for_replace(PendingImage{
		width: 20
		height: 20
		pixel_format: .rgba
	})
	assert img.state == .pending
	assert img.is_pending()
	assert !img.has_texture()
}

// Test ImageId z ordering.
fn test_image_id_z_ordering_kitty() {
	a := ImageId(KittyImageId{ id: 1 })
	b := ImageId(KittyImageId{ id: 2 })
	assert a.z_less_than(b)
	assert !b.z_less_than(a)
}

fn test_image_id_z_ordering_kitty_before_overlay() {
	a := ImageId(KittyImageId{ id: 1 })
	b := ImageId(OverlayImageId{})
	// Kitty images always sort before non-kitty images
	assert a.z_less_than(b)
	assert !b.z_less_than(a)
}

fn test_image_id_z_ordering_overlay_same() {
	a := ImageId(OverlayImageId{})
	b := ImageId(OverlayImageId{})
	// No sensible ordering for identical types
	assert !a.z_less_than(b)
	assert !b.z_less_than(a)
}

// Test ImageRenderState creation and deinit.
fn test_image_render_state_empty() {
	mut state := ImageRenderState.empty()
	assert state.images.len == 0
	assert state.kitty_placements.len == 0
	assert state.overlay_placements.len == 0
	assert !state.kitty_virtual
	state.deinit()
}

// Test ImageRenderState upload removes unloading images.
fn test_image_render_state_upload_removes_unloading() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut state := ImageRenderState.empty()
	state.images[1] = ImageEntry{
		image: Image{ state: .unload_pending }
	}
	state.images[2] = ImageEntry{
		image: Image{ state: .ready }
	}
	result := state.upload(&api)
	assert result == true
	assert 1 !in state.images
	assert 2 in state.images
	state.deinit()
}

fn test_overlay_update_prepares_image_and_placement() {
	mut state := ImageRenderState.empty()
	overlay := Overlay{
		width: 2
		height: 3
		pixels: []u8{len: 2 * 3 * 4, init: 7}
	}
	state.overlay_update(overlay)

	assert overlay_image_key in state.images
	entry := state.images[overlay_image_key] or { panic('missing overlay image') }
	assert entry.image.state == .pending
	pending := entry.image.pending or { panic('missing pending overlay') }
	assert pending.width == 2
	assert pending.height == 3
	assert pending.pixel_format == .rgba
	assert pending.data == overlay.pixels
	assert state.overlay_placements.len == 1
	placement := state.overlay_placements[0]
	assert placement.width == 2
	assert placement.height == 3
	assert placement.source_width == 2
	assert placement.source_height == 3
}

fn test_overlay_update_replaces_then_unloads_image() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut state := ImageRenderState.empty()
	state.overlay_update(Overlay{
		width: 1
		height: 1
		pixels: [u8(1), 2, 3, 4]
	})
	mut ready_entry := state.images[overlay_image_key] or { panic('missing overlay image') }
	ready_entry.image.state = .ready
	state.images[overlay_image_key] = ready_entry

	state.overlay_update(Overlay{
		width: 1
		height: 1
		pixels: [u8(5), 6, 7, 8]
	})
	replaced := state.images[overlay_image_key] or { panic('missing replaced overlay') }
	assert replaced.image.state == .replace
	assert state.overlay_placements.len == 1

	state.overlay_update(none)
	unloading := state.images[overlay_image_key] or { panic('missing unloading overlay') }
	assert unloading.image.state == .unload_replace
	assert state.overlay_placements.len == 0
	state.upload(&api)
	assert overlay_image_key !in state.images
}

fn test_image_upload_converts_to_rgba_texture() ! {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut state := ImageRenderState.empty()
	defer {
		state.deinit()
	}
	state.images[3] = ImageEntry{
		image: Image{
			state: .pending
			pending: PendingImage{
				width: 2
				height: 1
				pixel_format: .gray_alpha
				data: [u8(20), 40, 60, 80]
			}
			width: 2
			height: 1
		}
	}
	assert state.upload(&api)
	entry := state.images[3] or { return error('missing uploaded image') }
	assert entry.image.state == .ready
	assert entry.image.pending == none
	texture := entry.image.metal_texture or { return error('missing uploaded Metal texture') }
	assert texture.handle != unsafe { nil }
	mut bytes := []u8{len: 8}
	macos.metal_texture_get_bytes(texture.handle, mut bytes, 8, 0, 0, 2, 1)
	assert bytes == [u8(20), 20, 20, 40, 60, 60, 60, 80]
}

fn test_image_draw_encodes_gpu_placement() ! {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut shaders := MetalShaders.init(api.device, []string{}, .bgra8unorm)!
	defer {
		shaders.deinit()
	}
	mut state := ImageRenderState.empty()
	defer {
		state.deinit()
	}
	state.images[7] = ImageEntry{
		image: Image{
			state: .pending
			pending: PendingImage{
				width: 1
				height: 1
				pixel_format: .rgba
				data: [u8(255), 0, 0, 255]
			}
			width: 1
			height: 1
		}
	}
	state.kitty_placements << ImagePlacement{
		image_id: KittyImageId{ id: 7 }
		width: 1
		height: 1
		source_width: 1
		source_height: 1
	}
	state.kitty_bg_end = 1
	assert state.upload(&api)

	mut target := api.init_target(4, 4)!
	defer {
		target.deinit()
	}
	mut uniforms := MetalBuffer.init_fill(api.buffer_options(), []u8{len: int($sizeof(Uniforms))})!
	defer {
		uniforms.deinit()
	}
	mut capture := ImageMetalFrameCapture{}
	mut frame := MetalFrame.begin(api.queue, voidptr(&capture), voidptr(&target),
		voidptr(image_metal_frame_completion))!
	mut pass := frame.render_pass([MetalRenderPassAttachment{
		target: MetalRenderAttachmentTarget(target)
		clear_color: [f64(0), 0, 0, 1]!
	}])
	pass.step(MetalRenderStep{
		pipeline: shaders.bg_color
		uniforms: uniforms
		draw: MetalRenderDraw{
			draw_type: .triangle
			vertex_count: 3
		}
	})
	state.draw(&api, shaders.image, mut pass, .kitty_below_bg)
	pass.complete()
	frame.complete(true)
	assert capture.calls == 1
	assert metal_command_buffer_status(capture.status) == .completed
	assert capture.sync_
}

fn test_kitty_update_reads_terminal_storage() ! {
	mut t := terminal.Terminal.init(terminal.Options{
		rows: 5
		cols: 5
	})!
	t.width_px = 50
	t.height_px = 100
	defer {
		kitty.deinit_terminal_storage(mut t)
		t.deinit()
	}

	transmit := kitty.Parser.parse_string('a=t,f=24,t=d,i=7,s=1,v=1;////')!
	assert (kitty.execute(mut t, &transmit) or { panic('expected transmit response') }).ok()
	display := kitty.Parser.parse_string('a=p,i=7,p=9,c=1,r=1,C=1')!
	assert (kitty.execute(mut t, &display) or { panic('expected display response') }).ok()

	mut state := ImageRenderState.empty()
	defer {
		state.deinit()
	}
	assert state.kitty_requires_update(&t)
	state.kitty_update(&t, CellSize{
		width: 10
		height: 20
	})

	storage := kitty.terminal_storage(&t) or { panic('expected image storage') }
	assert !storage.dirty
	assert kitty_image_key(7) in state.images
	entry := state.images[kitty_image_key(7)] or { panic('expected prepared image') }
	pending := entry.image.pending or { panic('expected pending image') }
	assert pending.pixel_format == .rgba
	assert pending.data == [u8(255), 255, 255, 255]
	assert state.kitty_placements.len == 1
	placement := state.kitty_placements[0]
	assert placement.image_id == ImageId(KittyImageId{ id: 7 })
	assert placement.x == 0
	assert placement.y == 0
	assert placement.width == 10
	assert placement.height == 20
}

fn test_kitty_virtual_placement_keeps_renderer_updates_active_without_placeholder() ! {
	mut t := terminal.Terminal.init(terminal.Options{
		rows: 5
		cols: 5
	})!
	t.width_px = 50
	t.height_px = 100
	defer {
		kitty.deinit_terminal_storage(mut t)
		t.deinit()
	}

	transmit := kitty.Parser.parse_string('a=t,f=24,t=d,i=7,s=1,v=1;////')!
	assert (kitty.execute(mut t, &transmit) or { panic('expected transmit response') }).ok()
	virtual_display := kitty.Parser.parse_string('a=p,i=7,p=9,c=1,r=1,U=1,C=1')!
	assert (kitty.execute(mut t, &virtual_display) or { panic('expected display response') }).ok()

	mut state := ImageRenderState.empty()
	defer {
		state.deinit()
	}
	state.kitty_update(&t, CellSize{
		width: 10
		height: 20
	})
	assert state.kitty_virtual
	assert state.kitty_placements.len == 0
	assert state.kitty_requires_update(&t)
}

fn test_kitty_virtual_placement_uses_viewport_relative_row() ! {
	mut t := terminal.Terminal.init(terminal.Options{
		rows: 5
		cols: 5
	})!
	t.width_px = 50
	t.height_px = 100
	defer {
		t.deinit()
	}

	mut storage := kitty.ImageStorage{}
	storage.add_image(kitty.Image{
		id: 7
		width: 1
		height: 1
		data: [u8(255), 255, 255]
	})!
	storage.add_placement(7, 9, kitty.Placement{
		location: kitty.PlacementVirtual{}
		columns: 1
		rows: 1
	})
	defer {
		storage.deinit(t.screens.active)
	}

	mut state := ImageRenderState.empty()
	defer {
		state.deinit()
	}
	state.kitty_update_storage(mut storage, &t, 3, 7, CellSize{
		width: 10
		height: 20
	}, []KittyPinnedPlacement{}, [kitty.VirtualPlacement{
		pin: terminal.Pin{
			x: 2
			y: 4
		}
		image_id: 7
		placement_id: 9
		width: 1
		height: 1
	}])

	assert state.kitty_placements.len == 1
	assert state.kitty_placements[0].x == 2
	assert state.kitty_placements[0].y == 1
}

// Test DrawPlacements enum.
fn test_draw_placements_enum() {
	assert sizeof(DrawPlacements) == 1
	assert u8(DrawPlacements.kitty_below_bg) == 0
	assert u8(DrawPlacements.kitty_below_text) == 1
	assert u8(DrawPlacements.kitty_above_text) == 2
	assert u8(DrawPlacements.overlay) == 3
}

fn test_image_upload_state_source_layout_and_ordinals() {
	assert sizeof(ImageUploadState) == 1
	assert u8(ImageUploadState.pending) == 0
	assert u8(ImageUploadState.replace) == 1
	assert u8(ImageUploadState.ready) == 2
	assert u8(ImageUploadState.unload_pending) == 3
	assert u8(ImageUploadState.unload_ready) == 4
	assert u8(ImageUploadState.unload_replace) == 5
}
