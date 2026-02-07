module renderer

import terminal

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
pub enum PixelFormat {
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
pub fn (f PixelFormat) bpp() u32 {
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
pub fn (p &PendingImage) data_len() u32 {
	return p.width * p.height * p.pixel_format.bpp()
}

// Image upload state tracks whether the image data is pending, ready (uploaded
// to GPU), or unloading.
pub enum ImageUploadState {
	// The image data is pending upload to the GPU.
	pending
	// The image is uploaded and ready to be used.
	ready
	// The image is marked for unload (will be freed on next upload cycle).
	unloading
	// The image has been replaced - old texture exists, new data pending.
	replace
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
	// Width/height of the image.
	width  u32
	height u32
}

// Mark this image for unload whatever state it is in.
pub fn (mut self Image) mark_for_unload() {
	self.state = .unloading
}

// Mark the current image to be replaced with a pending one.
pub fn (mut self Image) mark_for_replace(new_pending PendingImage) {
	self.pending = new_pending
	self.state = .replace
}

// Returns true if this image is pending upload.
pub fn (self &Image) is_pending() bool {
	return self.state == .pending || self.state == .replace
}

// Returns true if this image is marked for unload.
pub fn (self &Image) is_unloading() bool {
	return self.state == .unloading
}

// Returns true if this image has a texture ready.
pub fn (self &Image) has_texture() bool {
	return self.state == .ready || self.state == .replace
}

pub fn (mut self Image) deinit() {
	self.pending = none
	self.texture_handle = unsafe { nil }
}

// Entry in the image map, pairing an image with its transmit time.
pub struct ImageEntry {
pub mut:
	image         Image
	transmit_time i64
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
pub enum DrawPlacements {
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
	images map[u32]ImageEntry

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
	self.images = map[u32]ImageEntry{}
	self.kitty_placements = []
	self.overlay_placements = []
}

// Upload any images to the GPU that need to be uploaded,
// and remove any images that are no longer needed on the GPU.
//
// If any uploads fail, they are ignored. The return value
// can be used to detect if upload was a total success (true)
// or not (false).
pub fn (mut self ImageRenderState) upload() bool {
	// XTODO: Image upload requires GPU API integration.
	// This method should iterate through images, upload pending ones
	// to the GPU, and remove unloading ones.
	mut to_remove := []u32{}
	for id, mut entry in self.images {
		if entry.image.is_unloading() {
			entry.image.deinit()
			to_remove << id
		}
	}
	for id in to_remove {
		self.images.delete(id)
	}
	return true
}

// Returns true if the Kitty graphics state requires an update based
// on the terminal state and our internal state.
//
// This does not read/write state used by drawing.
pub fn (self &ImageRenderState) kitty_requires_update(t &terminal.Terminal) bool {
	// XTODO: needs screen.kitty_images.dirty check
	// If we have any virtual references, we must also rebuild our
	// kitty state on every frame because any cell change can move
	// an image.
	if self.kitty_virtual {
		return true
	}
	_ = t
	return false
}

// Update the Kitty graphics state from the terminal.
//
// This reads/writes state used by drawing.
pub fn (mut self ImageRenderState) kitty_update(t &terminal.Terminal, cell_size CellSize) {
	// XTODO: Full kitty graphics update requires terminal.kitty_images
	// (ImageStorage) with placement iteration, image preparation, and
	// viewport coordinate calculation.
	// We always clear our previous placements no matter what because
	// we rebuild them from scratch.
	self.kitty_placements.clear()
	self.kitty_virtual = false

	// Reset z-layer indices
	self.kitty_bg_end = 0
	self.kitty_text_end = 0

	_ = t
	_ = cell_size
}

// Update our overlay state. None value deletes any existing overlay.
pub fn (mut self ImageRenderState) overlay_update(overlay ?Overlay) {
	// XTODO: Overlay image upload requires GPU API integration.
	self.overlay_placements.clear()

	if ov := overlay {
		_ = ov
	}
}

// Draw the given named set of placements.
//
// Any placements that have non-uploaded images are ignored. Any
// graphics API errors during drawing are also ignored.
pub fn (mut self ImageRenderState) draw(placement_type DrawPlacements) {
	// XTODO: Drawing requires GPU API integration (pipeline, render pass,
	// buffer creation, texture binding).
	_ = placement_type
}
