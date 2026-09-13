module renderer

// --- Original Ghostty Comments Start: src/renderer/image.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/renderer/image.zig
//
// Generic image rendering state for the renderer. This stores all
// images and their placements and exposes only a limited public API
// for adding images and placements and drawing them.
// The full image state for the renderer that specifies what images
// need to be uploaded, pruned, etc.
// The placements for the Kitty image protocol.
// The end index (exclusive) for placements that should be
// drawn below the background, below the text, etc.
// True if there are any virtual placements. This needs to be known
// because virtual placements need to be recalculated more often
// on frame builds and are generally more expensive to handle.
// Overlays
// Upload any images to the GPU that need to be uploaded,
// and remove any images that are no longer needed on the GPU.
//
// If any uploads fail, they are ignored. The return value
// can be used to detect if upload was a total success (true)
// or not (false).
// Draw the given named set of placements.
//
// Any placements that have non-uploaded images are ignored. Any
// graphics API errors during drawing are also ignored.
// Look up the image
// Get the texture
// Create our vertex buffer, which is always exactly one item.
// future(mitchellh): we can group rendering multiple instances of a single image
// Update our overlay state. Null value deletes any existing overlay.
// If we don't have an overlay, remove any existing one.
// For transmit time we always just use the current time
// and overwrite the overlay.
// Ensure we have space for our overlay placement. Do this before
// we upload our image so we don't have to deal with cleaning
// that up.
// Setup our image.
// Setup our placement
// Returns true if the Kitty graphics state requires an update based
// on the terminal state and our internal state.
//
// This does not read/write state used by drawing.
// If the terminal kitty image state is dirty, we must update.
// If we have any virtual references, we must also rebuild our
// kitty state on every frame because any cell change can move
// an image. If the virtual placements were removed, this will
// be set to false on the next update.
// Update the Kitty graphics state from the terminal.
//
// This reads/writes state used by drawing.
// We always clear our previous placements no matter what because
// we rebuild them from scratch.
// Go through our known images and if there are any that are no longer
// in use then mark them to be freed.
//
// This never conflicts with the below because a placement can't
// reference an image that doesn't exist.
// We're only looking at Kitty images
// The top-left and bottom-right corners of our viewport in screen
// points. This lets us determine offsets and containment of placements.
// Go through the placements and ensure the image is
// on the GPU or else is ready to be sent to the GPU.
// Special logic based on location
// We need to mark virtual placements on our renderer so that
// we know to rebuild in more scenarios since cell changes can
// now trigger placement changes.
// We also continue out because virtual placements are
// only triggered by the unicode placeholder, not by the
// placement itself.
// Get the image for the placement
// For errors we log and continue. We try to place
// other placements even if one fails.
// If we have virtual placements then we need to scan for placeholders.
// For errors we log and continue. We try to place
// other placements even if one fails.
// Sort the placements by their Z value.
// Find our indices. The values are sorted by z so we can
// find the first placement out of bounds to find the limits.
// If we didn't see any images with a z > the bg limit,
// then our bg end is the end of our placement list.
// Same idea for the image_text_end.
// Get the viewport-relative position for this
// placement and add it to the placements list.
// Get the rect for the placement. If this placement doesn't have
// a rect then its virtual or something so skip it.
// This is expensive but necessary.
// If the selection isn't within our viewport then skip it.
// We need to prep this image for upload if it isn't in the
// cache OR it is in the cache but the transmit time doesn't
// match meaning this image is different.
// Calculate the dimensions of our image, taking in to
// account the rows / columns specified by the placement.
// Calculate the source rectangle
// Get the viewport-relative Y position of the placement.
// Accumulate the placement
// If our placement is zero sized then we don't do anything.
// This is unreachable with virtual placements because we should
// only ever be looking at virtual placements that are in our
// viewport in the renderer and virtual placements only ever take
// up one row.
// Prepare the image for the GPU and store the placement.
// Prepare an image for upload to the GPU.
// If this image exists and its transmit time is the same we assume
// it is the identical image so we don't need to send it to the GPU.
// Copy the data so we own it.
// If this is a new entry we can just remove it since it
// was never sent to the GPU.
// If this was an existing entry, it is invalid and
// we must unload it.
// Note: we don't need to errdefer free the data because it is
// put into the map immediately below and our errdefer to
// handle our map state will fix this up.
// Store it in the map
// If any error happens, we unload the image and it is invalid.
// Prepare the provided Kitty image for upload to the GPU by copying its
// data with our allocator and setting it to the pending state.
// constCasts are always gross but this one is safe is because
// the data is only read from here and copied into its own
// buffer.
// Represents a single image placement on the grid.
// A placement is a request to render an instance of an image.
// The image being rendered. This MUST be in the image map.
// The grid x/y where this placement is located.
// The width/height of the placed image.
// The offset in pixels from the top left of the cell.
// This is clamped to the size of a cell.
// The source rectangle of the placement.
// Image identifier used to store and lookup images.
//
// This is tagged by different image types to make it easier to
// store different kinds of images in the same map without having
// to worry about ID collisions.
// Image sent to the terminal state via the kitty graphics protocol.
// The value is the ID assigned by the terminal.
// Debug overlay. This is always composited down to a single
// image for now. In the future we can support layers here if we want.
// Z-ordering tie-breaker for images with the same z value.
// If our tags aren't the same, we sort by tag.
// Kitty images always sort before (lower z) non-kitty images.
// No sensical ordering
// The map used for storing images.
// The state for a single image that is to be rendered.
// The image data is pending upload to the GPU.
//
// This data is owned by this union so it must be freed once uploaded.
// This is the same as the pending states but there is
// a texture already allocated that we want to replace.
// The image is uploaded and ready to be used.
// The image isn't uploaded yet but is scheduled to be unloaded.
// The image is uploaded and is scheduled to be unloaded.
// The image is uploaded and scheduled to be replaced
// with new data, but it's also scheduled to be unloaded.
// Pending image data that needs to be uploaded to the GPU.
// Data is always expected to be (width * height * bpp).
// 1 byte per pixel grayscale.
// 2 bytes per pixel grayscale + alpha.
// 3 bytes per pixel RGB.
// 3 bytes per pixel BGR.
// 4 byte per pixel RGBA.
// 4 byte per pixel BGRA.
// Get bytes per pixel for this format.
// Mark this image for unload whatever state it is in.
// Mark the current image to be replaced with a pending one. This will
// attempt to update the existing texture if we have one, otherwise it
// will act like a new upload.
// If we have pending data right now, free it.
// If we have an existing texture, use it in the replace.
// Otherwise we just become a pending image.
// Returns true if this image is pending upload.
// Returns true if this image has an associated texture.
// Returns true if this image is marked for unload.
// Converts the image data to a format that can be uploaded to the GPU.
// If the data is already in a format that can be uploaded, this is a
// no-op.
// As things stand, we currently convert all images to RGBA before
// uploading to the GPU. This just makes things easier. In the future
// we may want to support other formats.
// If the pending data isn't RGBA we'll need to swizzle it.
// Prepare the pending image data for upload to the GPU.
// This doesn't need GPU access so is safe to call any time.
// Upload the pending image to the GPU and change the state of this
// image to ready.
// Texture creation failed, usually a GPU memory issue.
// No error recover is required after this call because it just
// converts in place and is idempotent.
// Get our pending info
// Create our texture
// Uploaded. We can now clear our data and change our state.
//
// NOTE: For the `replace` state, this will free the old texture.
//       We don't currently actually replace the existing texture
//       in-place but that is an optimization we can do later.
// Returns any pending image data for this image that requires upload.
//
// If there is no pending data to upload, returns null.
// Returns the texture for this image.
//
// If there is no texture for it yet, returns null.
// Same as getPending but returns a pointer instead of a copy.
//
// --- Original Ghostty Comments End: src/renderer/image.zig

import terminal
import kitty
import math
import time
import macos

const overlay_image_key = u64(1) << 32

fn kitty_image_key(id u32) u64 {
	return u64(id)
}

fn image_key(id ImageId) u64 {
	return match id {
		KittyImageId { kitty_image_key(id.id) }
		OverlayImageId { overlay_image_key }
	}
}

// Image identifier used to store and lookup images.
//
// This is tagged by different image types to make it easier to
// store different kinds of images in the same map without having
// to worry about ID collisions.
pub type ImageId = KittyImageId | OverlayImageId

pub struct KittyImageId {
pub:
	// Image sent to the terminal state via the kitty graphics protocol.
	// The value is the ID assigned by the terminal.
	id u32
}

pub struct OverlayImageId {
	// Debug overlay. This is always composited down to a single
	// image for now.
	dummy_ u8
}

// Z-ordering tie-breaker for images with the same z value.
pub fn (lhs ImageId) z_less_than(rhs ImageId) bool {
	// If our tags aren't the same, we sort by tag.
	match lhs {
		KittyImageId {
			match rhs {
				KittyImageId {
					// Both kitty: compare by ID
					return lhs.id < rhs.id
				}
				OverlayImageId {
					// Kitty images always sort before (lower z) non-kitty images.
					return true
				}
			}
		}
		OverlayImageId {
			match rhs {
				KittyImageId {
					return false
				}
				OverlayImageId {
					// No sensical ordering
					return false
				}
			}
		}
	}
}

// Pixel format for image data.
pub enum PixelFormat as u8 {
	// 1 byte per pixel grayscale.
	gray
	// 2 bytes per pixel grayscale + alpha.
	gray_alpha
	// 3 bytes per pixel RGB.
	rgb
	// 3 bytes per pixel BGR.
	bgr
	// 4 bytes per pixel RGBA.
	rgba
	// 4 bytes per pixel BGRA.
	bgra
}

// Get bytes per pixel for this format.
pub fn (f PixelFormat) bpp() usize {
	return match f {
		.gray { 1 }
		.gray_alpha { 2 }
		.rgb { 3 }
		.bgr { 3 }
		.rgba { 4 }
		.bgra { 4 }
	}
}

// Pending image data that needs to be uploaded to the GPU.
pub struct PendingImage {
pub mut:
	height       u32
	width        u32
	pixel_format PixelFormat
	// Data is always expected to be (width * height * bpp).
	data []u8
}

// Returns the expected data length.
pub fn (p &PendingImage) data_len() usize {
	return usize(p.width) * usize(p.height) * p.pixel_format.bpp()
}

// Returns the expected data length as an array index.
pub fn (p &PendingImage) len() usize {
	return p.data_len()
}

// Returns the pending pixel data at its dimension-derived length.
pub fn (p &PendingImage) data_slice() []u8 {
	return p.data[..p.len()]
}

// Image upload state tracks whether the image data is pending, ready (uploaded
// to GPU), or unloading.
pub enum ImageUploadState as u8 {
	// The image data is pending upload to the GPU.
	pending
	// The image has been replaced - old texture exists, new data pending.
	replace
	// The image is uploaded and ready to be used.
	ready
	// Pending data scheduled to be unloaded.
	unload_pending
	// An uploaded texture scheduled to be unloaded.
	unload_ready
	// A texture plus replacement data scheduled to be unloaded.
	unload_replace
}

pub enum ImageTextureBackend {
	none_
	metal
	opengl
}

// The state for a single image that is to be rendered.
pub struct Image {
pub mut:
	// Current state of the image.
	state ImageUploadState = .pending
	// Pending data for upload.
	pending ?PendingImage
	// GPU texture handle (opaque, backend-specific).
	texture_handle voidptr = unsafe { nil }
	// OpenGL textures are integer object names rather than pointers, so they
	// retain their typed wrapper alongside the Metal handle.
	gl_texture      GLTexture
	texture_backend ImageTextureBackend
	// Width/height of the image.
	width  u32
	height u32
}

// Mark this image for unload whatever state it is in.
pub fn (mut self Image) mark_for_unload() {
	self.state = match self.state {
		.pending { .unload_pending }
		.ready { .unload_ready }
		.replace { .unload_replace }
		.unload_pending, .unload_ready, .unload_replace {
			return
		}
	}
}

// Mark the current image to be replaced with a pending one.
pub fn (mut self Image) mark_for_replace(new_pending PendingImage) {
	has_texture := self.has_texture()
	self.pending = new_pending
	self.state = if has_texture { .replace } else { .pending }
}

// Returns true if this image is pending upload.
pub fn (self &Image) is_pending() bool {
	return self.state in [.pending, .replace, .unload_pending, .unload_replace]
}

// Returns true if this image is marked for unload.
pub fn (self &Image) is_unloading() bool {
	return self.state in [.unload_pending, .unload_ready, .unload_replace]
}

// Returns true if this image has a texture ready.
pub fn (self &Image) has_texture() bool {
	return self.state in [.ready, .replace, .unload_ready, .unload_replace]
}

pub fn (mut self Image) deinit() {
	self.release_texture()
	self.pending = none
	self.width = 0
	self.height = 0
}

fn (mut self Image) release_texture() {
	match self.texture_backend {
		.metal { macos.metal_release(self.texture_handle) }
		.opengl { self.gl_texture.deinit() }
		.none_ {}
	}
	self.texture_handle = unsafe { nil }
	self.gl_texture = GLTexture{}
	self.texture_backend = .none_
}

// Entry in the image map, pairing an image with its transmit time.
pub struct ImageEntry {
pub mut:
	image         Image
	transmit_time u64
}

// Represents a single image placement on the grid.
// A placement is a request to render an instance of an image.
pub struct ImagePlacement {
pub mut:
	// The image being rendered. This MUST be in the image map.
	image_id ImageId

	// The grid x/y where this placement is located.
	x i32
	y i32
	z i32

	// The width/height of the placed image.
	width  u32
	height u32

	// The offset in pixels from the top left of the cell.
	// This is clamped to the size of a cell.
	cell_offset_x u32
	cell_offset_y u32

	// The source rectangle of the placement.
	source_x      u32
	source_y      u32
	source_width  u32
	source_height u32
}

// Which set of placements to draw.
pub enum DrawPlacements as u8 {
	kitty_below_bg
	kitty_below_text
	kitty_above_text
	overlay
}

// Generic image rendering state for the renderer. This stores all
// images and their placements and exposes only a limited public API
// for adding images and placements and drawing them.
pub struct ImageRenderState {
pub mut:
	// Map of image ID to image entry.
	images map[u64]ImageEntry

	// The placements for the Kitty image protocol.
	kitty_placements []ImagePlacement

	// The end index (exclusive) for placements that should be
	// drawn below the background, below the text, etc.
	kitty_bg_end   u32
	kitty_text_end u32

	// True if there are any virtual placements. This needs to be known
	// because virtual placements need to be recalculated more often
	// on frame builds and are generally more expensive to handle.
	kitty_virtual bool

	// Overlays
	overlay_placements []ImagePlacement
}

pub fn ImageRenderState.empty() ImageRenderState {
	return ImageRenderState{}
}

pub fn (mut self ImageRenderState) deinit() {
	for _, mut entry in self.images {
		entry.image.deinit()
	}
	self.images = map[u64]ImageEntry{}
	self.kitty_placements = []
	self.overlay_placements = []
}

// Upload any images to the GPU that need to be uploaded,
// and remove any images that are no longer needed on the GPU.
//
// If any uploads fail, they are ignored. The return value
// can be used to detect if upload was a total success (true)
// or not (false).
pub fn (mut self ImageRenderState) upload(api &MetalAPI) bool {
	mut success := true
	mut to_remove := []u64{}
	for id, mut entry in self.images {
		if entry.image.is_unloading() {
			entry.image.deinit()
			to_remove << id
			continue
		}
		if entry.image.is_pending() {
			entry.image.upload(api) or {
				success = false
				self.images[id] = entry
				continue
			}
			self.images[id] = entry
		}
	}
	for id in to_remove {
		self.images.delete(id)
	}
	return success
}

fn (mut self Image) upload(api &MetalAPI) ! {
	self.prep_for_upload()!
	pending := self.pending or { return error('image has no pending data') }
	mut texture := MetalTexture.init(api.image_texture_options(.rgba, true), pending.width, pending.height, pending.data_slice())!
	self.release_texture()
	self.texture_handle = texture.handle
	self.texture_backend = .metal
	texture.handle = unsafe { nil }
	self.pending = none
	self.width = pending.width
	self.height = pending.height
	self.state = .ready
}

pub fn (mut self ImageRenderState) upload_opengl(api &OpenGLAPI) bool {
	mut success := true
	mut to_remove := []u64{}
	for id, mut entry in self.images {
		if entry.image.is_unloading() {
			entry.image.deinit()
			to_remove << id
			continue
		}
		if entry.image.is_pending() {
			entry.image.upload_opengl(api) or {
				success = false
				self.images[id] = entry
				continue
			}
			self.images[id] = entry
		}
	}
	for id in to_remove {
		self.images.delete(id)
	}
	return success
}

fn (mut self Image) upload_opengl(api &OpenGLAPI) ! {
	self.prep_for_upload()!
	pending := self.pending or { return error('image has no pending data') }
	mut texture := GLTexture.init(api.image_texture_options(.rgba, true), pending.width, pending.height, pending.data_slice())!
	self.release_texture()
	self.gl_texture = texture
	texture.id = 0
	self.texture_backend = .opengl
	self.pending = none
	self.width = pending.width
	self.height = pending.height
	self.state = .ready
}

// Converts pending image data to the upload format in place. Images that are
// already RGBA are left untouched.
pub fn (mut self Image) convert() ! {
	mut pending := self.pending or { return error('image has no pending data') }
	if pending.data.len != int(pending.data_len()) {
		return error('image data size does not match dimensions')
	}
	if pending.pixel_format == .rgba {
		return
	}
	pending.data = pending_to_rgba(pending)!
	pending.pixel_format = .rgba
	self.pending = pending
}

// Prepare pending image data for a later GPU upload.
pub fn (mut self Image) prep_for_upload() ! {
	assert self.is_pending()
	self.convert()!
}

fn pending_to_rgba(pending PendingImage) ![]u8 {
	if pending.data.len != int(pending.data_len()) {
		return error('image data size does not match dimensions')
	}
	if pending.pixel_format == .rgba {
		return pending.data.clone()
	}
	pixels := int(usize(pending.width) * usize(pending.height))
	mut rgba := []u8{len: pixels * 4}
	for i in 0 .. pixels {
		src := i * int(pending.pixel_format.bpp())
		dst := i * 4
		match pending.pixel_format {
			.gray {
				rgba[dst] = pending.data[src]
				rgba[dst + 1] = pending.data[src]
				rgba[dst + 2] = pending.data[src]
				rgba[dst + 3] = 255
			}
			.gray_alpha {
				rgba[dst] = pending.data[src]
				rgba[dst + 1] = pending.data[src]
				rgba[dst + 2] = pending.data[src]
				rgba[dst + 3] = pending.data[src + 1]
			}
			.rgb {
				rgba[dst] = pending.data[src]
				rgba[dst + 1] = pending.data[src + 1]
				rgba[dst + 2] = pending.data[src + 2]
				rgba[dst + 3] = 255
			}
			.bgr {
				rgba[dst] = pending.data[src + 2]
				rgba[dst + 1] = pending.data[src + 1]
				rgba[dst + 2] = pending.data[src]
				rgba[dst + 3] = 255
			}
			.bgra {
				rgba[dst] = pending.data[src + 2]
				rgba[dst + 1] = pending.data[src + 1]
				rgba[dst + 2] = pending.data[src]
				rgba[dst + 3] = pending.data[src + 3]
			}
			.rgba {}
		}
	}
	return rgba
}

// Returns true if the Kitty graphics state requires an update based
// on the terminal state and our internal state.
//
// This does not read/write state used by drawing.
//
pub fn (self &ImageRenderState) kitty_requires_update(t &terminal.Terminal) bool {
	if storage := kitty.terminal_storage(t) {
		if storage.dirty {
			return true
		}
	}

	// If we have any virtual references, we must also rebuild our
	// kitty state on every frame because any cell change can move
	// an image.
	if self.kitty_virtual {
		return true
	}
	return false
}

// Storage-aware variant of kitty_requires_update that has direct access
// to the Kitty image storage. This is a faithful translation of Ghostty's
// State.kittyRequiresUpdate.
pub fn (self &ImageRenderState) kitty_requires_update_storage(storage &kitty.ImageStorage) bool {
	// If the terminal kitty image state is dirty, we must update.
	if storage.dirty {
		return true
	}

	// If we have any virtual references, we must also rebuild our
	// kitty state on every frame because any cell change can move
	// an image. If the virtual placements were removed, this will
	// be set to false on the next update.
	if self.kitty_virtual {
		return true
	}

	return false
}

// Update the Kitty graphics state from the terminal.
//
// This reads/writes state used by drawing.
//
pub fn (mut self ImageRenderState) kitty_update(t &terminal.Terminal, cell_size CellSize) {
	mut storage := kitty.terminal_storage(t) or {
		self.kitty_placements.clear()
		self.kitty_virtual = false
		self.kitty_bg_end = 0
		self.kitty_text_end = 0
		return
	}

	top := t.screens.active.pages.get_top_left(.viewport)
	bot := t.screens.active.pages.get_bottom_right(.viewport) or { top }

	mut pinned := []KittyPinnedPlacement{}
	mut has_virtual := false
	for entry in storage.placements {
		match entry.value.location {
			kitty.PlacementPin {
				image := storage.image_by_id(entry.key.image_id) or { continue }
				pinned << KittyPinnedPlacement{
					image: image
					placement: entry.value
				}
			}
			kitty.PlacementVirtual {
				has_virtual = true
			}
		}
	}

	mut virtuals := []kitty.VirtualPlacement{}
	if has_virtual {
		mut it := kitty.placement_iterator(&t.screens.active.pages, top.y, bot.y + 1)
		for {
			placement := it.next() or { break }
			virtuals << placement
		}
	}

	self.kitty_update_storage(mut storage, t, top.y, bot.y, cell_size, pinned, virtuals)
	// A virtual placement keeps this state hot even when the current viewport
	// contains no matching Unicode placeholder cells.
	if has_virtual {
		self.kitty_virtual = true
	}
}

// A resolved (image, placement) pair for a pin-anchored Kitty placement.
// The terminal-facing entry point resolves these from ImageStorage before
// handing them to the shared CPU-side update routine.
pub struct KittyPinnedPlacement {
pub:
	image     kitty.Image
	placement kitty.Placement
}

// Update the Kitty graphics state from the terminal, given the already
// resolved pin-anchored placements and any virtual placements.
//
// This is a faithful translation of the CPU-side of Ghostty's
// State.kittyUpdate: placement prep (viewport rect math + source rect +
// viewport-relative Y), virtual placement prep, z-sorting, and the
// bg/text-end index computation.
//
// `top_y` and `bot_y` are the screen-space Y coordinates of the top-left
// and bottom-right corners of the viewport, computed by the caller (in
// Ghostty via `pages.pointFromPin(.screen, ...)`).
pub fn (mut self ImageRenderState) kitty_update_storage(mut storage kitty.ImageStorage, t &terminal.Terminal, top_y u32, bot_y u32, cell_size CellSize, pinned []KittyPinnedPlacement, virtuals []kitty.VirtualPlacement) {
	// The terminal storage's dirty flag is consumed by this update.
	defer {
		storage.dirty = false
	}

	// We always clear our previous placements no matter what because
	// we rebuild them from scratch.
	self.kitty_placements.clear()
	self.kitty_virtual = false

	// Go through our known images and if there are any that are no longer
	// in use then mark them to be freed.
	//
	// This never conflicts with the below because a placement can't
	// reference an image that doesn't exist.
	for id, mut entry in self.images {
		if id == overlay_image_key {
			continue
		}
		// We're only looking at Kitty images. Our image map keys are kitty
		// image IDs directly (u32). If the storage no longer has this
		// image, mark it for unload.
		if storage.image_by_id(u32(id)) == none {
			entry.image.mark_for_unload()
			self.images[id] = entry
		}
	}

	// Go through the placements and ensure the image is
	// on the GPU or else is ready to be sent to the GPU.
	for pin in pinned {
		// For errors we log and continue. We try to place
		// other placements even if one fails.
		self.prep_kitty_placement(t, top_y, bot_y, pin.image, pin.placement) or { continue }
	}

	// If we have any virtual placements then we need to prep them. The
	// presence of virtual placements is signalled by the caller passing
	// a non-empty list; we set kitty_virtual so future frames rebuild.
	if virtuals.len > 0 {
		// We need to mark virtual placements on our renderer so that
		// we know to rebuild in more scenarios since cell changes can
		// now trigger placement changes.
		self.kitty_virtual = true

		for virtual_p in virtuals {
			// For errors we log and continue. We try to place
			// other placements even if one fails.
			self.prep_kitty_virtual_placement(mut storage, virtual_p, top_y, cell_size) or {
				continue
			}
		}
	}

	// Sort the placements by their Z value and compute the bg/text end
	// indices.
	self.kitty_sort_and_index()
}

// Sort the placements by their Z value and compute the bg/text end
// indices. This is a self-contained faithful translation of the tail of
// Ghostty's kittyUpdate and operates purely on `kitty_placements`.
fn (mut self ImageRenderState) kitty_sort_and_index() {
	// Sort the placements by their Z value.
	self.kitty_placements.sort_with_compare(fn (a &ImagePlacement, b &ImagePlacement) int {
		if a.z < b.z {
			return -1
		}
		if a.z > b.z {
			return 1
		}
		// Equal z: use the image id tie-breaker.
		if a.image_id.z_less_than(b.image_id) {
			return -1
		}
		if b.image_id.z_less_than(a.image_id) {
			return 1
		}
		return 0
	})

	// Find our indices. The values are sorted by z so we can
	// find the first placement out of bounds to find the limits.
	bg_limit := i32(-2147483648 / 2) // std.math.minInt(i32) / 2
	mut bg_end := ?u32(none)
	mut text_end := ?u32(none)
	for i, p in self.kitty_placements {
		if bg_end == none && p.z >= bg_limit {
			bg_end = u32(i)
		}
		if text_end == none && p.z >= 0 {
			text_end = u32(i)
		}
	}

	// If we didn't see any images with a z > the bg limit,
	// then our bg end is the end of our placement list.
	self.kitty_bg_end = bg_end or { u32(self.kitty_placements.len) }
	// Same idea for the image_text_end.
	self.kitty_text_end = text_end or { u32(self.kitty_placements.len) }
}

// Get the viewport-relative position for this placement and add it to
// the placements list. Faithful translation of prepKittyPlacement.
fn (mut self ImageRenderState) prep_kitty_placement(t &terminal.Terminal, top_y u32, bot_y u32, image kitty.Image, p kitty.Placement) ! {
	// Get the rect for the placement. If this placement doesn't have
	// a rect then its virtual or something so skip it.
	rect := p.rect(image, t) or { return }

	// This is expensive but necessary. In the V simplified model, pins
	// carry an absolute screen-space Y directly.
	img_top_y := rect.top_left.y
	img_bot_y := rect.bottom_right.y

	// If the selection isn't within our viewport then skip it.
	if img_top_y > bot_y {
		return
	}
	if img_bot_y < top_y {
		return
	}

	// We need to prep this image for upload if it isn't in the
	// cache OR it is in the cache but the transmit time doesn't
	// match meaning this image is different.
	self.prep_kitty_image(image)!

	// Calculate the dimensions of our image, taking in to
	// account the rows / columns specified by the placement.
	dest_w, dest_h := p.calculated_size(image, t)

	// Calculate the source rectangle
	source_x := math.min(image.width, p.source_x)
	source_y := math.min(image.height, p.source_y)
	source_width := if p.source_width > 0 {
		math.min(image.width - source_x, p.source_width)
	} else {
		image.width
	}
	source_height := if p.source_height > 0 {
		math.min(image.height - source_y, p.source_height)
	} else {
		image.height
	}

	// Get the viewport-relative Y position of the placement.
	y_pos := i32(img_top_y) - i32(top_y)

	// Accumulate the placement
	if dest_w > 0 && dest_h > 0 {
		self.kitty_placements << ImagePlacement{
			image_id: KittyImageId{
				id: image.id
			}
			x: i32(rect.top_left.x)
			y: y_pos
			z: p.z
			width: dest_w
			height: dest_h
			cell_offset_x: p.x_offset
			cell_offset_y: p.y_offset
			source_x: source_x
			source_y: source_y
			source_width: source_width
			source_height: source_height
		}
	}
}

// Prepare a virtual (unicode placeholder) placement. Faithful translation
// of prepKittyVirtualPlacement.
fn (mut self ImageRenderState) prep_kitty_virtual_placement(mut storage kitty.ImageStorage, p kitty.VirtualPlacement, viewport_top_y u32, cell_size CellSize) ! {
	image := storage.image_by_id(p.image_id) or {
		// missing image for virtual placement, ignoring
		return
	}

	rp := p.render_placement(storage, &image, cell_size.width, cell_size.height) or {
		// error rendering virtual placement
		return
	}

	// If our placement is zero sized then we don't do anything.
	if rp.dest_width == 0 || rp.dest_height == 0 {
		return
	}

	// placement_iterator only produces virtual placements inside the
	// viewport, so this subtraction is the flat-Pages equivalent of
	// pages.pointFromPin(.viewport, rp.top_left).viewport.y.
	viewport_y := rp.top_left.y - viewport_top_y

	// Prepare the image for the GPU and store the placement.
	self.prep_kitty_image(image)!
	self.kitty_placements << ImagePlacement{
		image_id: KittyImageId{
			id: image.id
		}
		x: i32(rp.top_left.x)
		y: i32(viewport_y)
		z: -1
		width: rp.dest_width
		height: rp.dest_height
		cell_offset_x: rp.offset_x
		cell_offset_y: rp.offset_y
		source_x: rp.source_x
		source_y: rp.source_y
		source_width: rp.source_width
		source_height: rp.source_height
	}
}

// Prepare the provided Kitty image for upload to the GPU by copying its
// data and setting it to the pending state. Faithful translation of
// prepKittyImage + prepImage.
//
// BOUNDARY: The actual GPU texture upload happens in `upload`. Here we
// only prepare the CPU-side pending image state.
fn (mut self ImageRenderState) prep_kitty_image(image kitty.Image) ! {
	id := kitty_image_key(image.id)
	transmit_time := image.transmit_time

	// If this image exists and its transmit time is the same we assume
	// it is the identical image so we don't need to send it to the GPU.
	found_existing := id in self.images
	if found_existing {
		existing := self.images[id] or { ImageEntry{} }
		if existing.transmit_time == transmit_time {
			return
		}
	}

	pixel_format := match image.format {
		.gray { PixelFormat.gray }
		.gray_alpha { PixelFormat.gray_alpha }
		.rgb { PixelFormat.rgb }
		.rgba { PixelFormat.rgba }
		.png {
			return error('png should be decoded by now')
		}
	}

	// Copy the data so we own it.
	pending := PendingImage{
		width: image.width
		height: image.height
		pixel_format: pixel_format
		data: image.data.clone()
	}

	if found_existing {
		// If this was an existing entry, replace it (marks for replace,
		// which keeps the existing texture if any).
		mut entry := self.images[id] or { ImageEntry{} }
		entry.image.mark_for_replace(pending)
		entry.image.prep_for_upload() or {
			entry.image.mark_for_unload()
			self.images[id] = entry
			return error('image conversion error')
		}
		entry.transmit_time = transmit_time
		self.images[id] = entry
	} else {
		// New entry.
		mut entry := ImageEntry{
			image: Image{
				state: .pending
				pending: pending
				width: image.width
				height: image.height
			}
		}
		entry.image.prep_for_upload() or {
			entry.image.mark_for_unload()
			self.images[id] = entry
			return error('image conversion error')
		}
		entry.transmit_time = transmit_time
		self.images[id] = entry
	}
}

// Update our overlay state. None value deletes any existing overlay.
pub fn (mut self ImageRenderState) overlay_update(overlay ?Overlay) {
	self.overlay_placements.clear()

	if ov := overlay {
		pending := ov.pending_image()
		if pending.data.len != int(pending.data_len()) {
			return
		}

		if overlay_image_key in self.images {
			mut entry := self.images[overlay_image_key] or { ImageEntry{} }
			entry.image.mark_for_replace(pending)
			entry.image.width = pending.width
			entry.image.height = pending.height
			entry.transmit_time = time.sys_mono_now()
			self.images[overlay_image_key] = entry
		} else {
			self.images[overlay_image_key] = ImageEntry{
				image: Image{
					state: .pending
					pending: pending
					width: pending.width
					height: pending.height
				}
				transmit_time: time.sys_mono_now()
			}
		}

		self.overlay_placements << ImagePlacement{
			image_id: OverlayImageId{}
			x: 0
			y: 0
			z: 0
			width: pending.width
			height: pending.height
			source_width: pending.width
			source_height: pending.height
		}
	} else if overlay_image_key in self.images {
		mut entry := self.images[overlay_image_key] or { ImageEntry{} }
		entry.image.mark_for_unload()
		self.images[overlay_image_key] = entry
	}
}

// Draw the given named set of placements.
//
// Any placements that have non-uploaded images are ignored. Any
// graphics API errors during drawing are also ignored.
pub fn (mut self ImageRenderState) draw(api &MetalAPI, pipeline MetalPipeline, mut pass MetalRenderPass, placement_type DrawPlacements) {
	placements := match placement_type {
		.kitty_below_bg {
			self.kitty_placements[..int(self.kitty_bg_end)]
		}
		.kitty_below_text {
			start := int(self.kitty_bg_end)
			end := int(self.kitty_text_end)
			self.kitty_placements[start..end]
		}
		.kitty_above_text {
			start := int(self.kitty_text_end)
			self.kitty_placements[start..]
		}
		.overlay { self.overlay_placements }
	}
	for placement in placements {
		entry := self.images[image_key(placement.image_id)] or { continue }
		if entry.image.state !in [.ready, .unload_ready] || entry.image.texture_handle == unsafe { nil } {
			continue
		}
		vertex := ImageVertex{
			grid_pos: [f32(placement.x), f32(placement.y)]!
			cell_offset: [f32(placement.cell_offset_x), f32(placement.cell_offset_y)]!
			source_rect: [f32(placement.source_x), f32(placement.source_y),
				f32(placement.source_width), f32(placement.source_height)]!
			dest_size: [f32(placement.width), f32(placement.height)]!
		}
		mut buffer := MetalBuffer.init_fill(api.buffer_options(), [vertex]) or { continue }
		pass.step(MetalRenderStep{
			pipeline: pipeline
			buffers: [buffer.handle]
			textures: [entry.image.texture_handle]
			draw: MetalRenderDraw{
				draw_type: .triangle_strip
				vertex_count: 4
			}
		})
		buffer.deinit()
	}
}

pub fn (mut self ImageRenderState) draw_opengl(api &OpenGLAPI, pipeline GLPipeline, mut pass GLRenderPass, placement_type DrawPlacements) {
	placements := match placement_type {
		.kitty_below_bg {
			self.kitty_placements[..int(self.kitty_bg_end)]
		}
		.kitty_below_text {
			start := int(self.kitty_bg_end)
			end := int(self.kitty_text_end)
			self.kitty_placements[start..end]
		}
		.kitty_above_text {
			start := int(self.kitty_text_end)
			self.kitty_placements[start..]
		}
		.overlay { self.overlay_placements }
	}
	for placement in placements {
		entry := self.images[image_key(placement.image_id)] or { continue }
		if entry.image.state !in [.ready, .unload_ready] || entry.image.texture_backend != .opengl
			|| entry.image.gl_texture.id == 0 {
			continue
		}
		vertex := ImageVertex{
			grid_pos: [f32(placement.x), f32(placement.y)]!
			cell_offset: [f32(placement.cell_offset_x), f32(placement.cell_offset_y)]!
			source_rect: [f32(placement.source_x), f32(placement.source_y),
				f32(placement.source_width), f32(placement.source_height)]!
			dest_size: [f32(placement.width), f32(placement.height)]!
		}
		mut buffer := GLBuffer.init_fill(api.image_buffer_options(), [vertex]) or { continue }
		pass.step(GLRenderStep{
			pipeline: pipeline
			buffers: [buffer]
			textures: [entry.image.gl_texture]
			draw: GLDraw{
				primitive: .triangle_strip
				vertex_count: 4
			}
		})
		buffer.deinit()
	}
}
