module renderer

// ============================================================
// Image tests
// ============================================================

// Test PixelFormat bytes per pixel.
fn test_pixel_format_bpp() {
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
	assert img.state == .unloading
	assert img.is_unloading()
	assert !img.is_pending()
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
	mut state := ImageRenderState.empty()
	state.images[1] = ImageEntry{
		image: Image{ state: .unloading }
	}
	state.images[2] = ImageEntry{
		image: Image{ state: .ready }
	}
	result := state.upload()
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
	assert unloading.image.state == .unloading
	assert state.overlay_placements.len == 0
	state.upload()
	assert overlay_image_key !in state.images
}

// Test DrawPlacements enum.
fn test_draw_placements_enum() {
	assert DrawPlacements.kitty_below_bg != DrawPlacements.kitty_below_text
	assert DrawPlacements.kitty_above_text != DrawPlacements.overlay
}
