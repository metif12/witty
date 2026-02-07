module kitty

// Kitty graphics protocol image types.
//
// Source: kitty/graphics_image.zig, kitty/graphics_render.zig
//
// Defines the Image (fully loaded image data), LoadingImage (in-progress
// image loading), Rect (placement rectangle in grid cells), and
// RenderPlacement (placement rendering information) types.

import time
import terminal

// Maximum width or height of an image. Taken directly from Kitty.
pub const max_dimension = 10000

// Maximum size in bytes, taken from Kitty.
pub const max_image_size = 400 * 1024 * 1024 // 400MB

// ============================================================
// Image
// ============================================================

// Image represents a single fully loaded image that can be placed
// in the terminal grid.
pub struct Image {
pub mut:
	// Image identifier.
	id u32
	// Image number (for image number-based addressing).
	number u32
	// Image width in pixels.
	width u32
	// Image height in pixels.
	height u32
	// The pixel format of the image data.
	format TransmissionFormat = .rgba
	// Compression used on the data.
	compression TransmissionCompression = .none_
	// The raw pixel data.
	data []u8
	// Timestamp when image was transmitted.
	transmit_time time.Time = time.now()
	// True if image was loaded by a command that doesn't specify
	// an ID or number.
	implicit_id bool
}

// Free the image data.
pub fn (mut self Image) deinit() {
	self.data = []
}

// Mostly for logging.
pub fn (self &Image) without_data() Image {
	return Image{
		id: self.id
		number: self.number
		width: self.width
		height: self.height
		format: self.format
		compression: self.compression
		implicit_id: self.implicit_id
	}
}

// ============================================================
// LoadingImage
// ============================================================

// LoadingImage represents an image that is still being loaded in
// chunks. Once all chunks are received, it is completed into an Image.
pub struct LoadingImage {
pub mut:
	// The in-progress image with metadata from the first chunk.
	image Image
	// The raw data being built up from chunks.
	data []u8
	// Non-null when transmit and display command is given to display
	// the image after loading.
	display ?Display
	// Quiet settings for the initial load command (used if q isn't
	// set on subsequent chunks).
	quiet Quiet = .no
}

// Free the loading image data.
pub fn (mut self LoadingImage) destroy() {
	self.data = []
	self.image.deinit()
}

// Initialize a chunked image from the first image transmission.
// If this is a multi-chunk image, this should only be the FIRST chunk.
pub fn LoadingImage.init_from_cmd(cmd &Command) !LoadingImage {
	// XTODO: Full implementation depends on file I/O, shared memory,
	// and path resolution which are platform-specific.
	// Only direct medium is partially supported.
	t := cmd.transmission() or { return error('no transmission in command') }
	mut result := LoadingImage{
		image: Image{
			id: t.image_id
			number: t.image_number
			width: t.width
			height: t.height
			compression: t.compression
			format: t.format_
		}
		display: cmd.display()
		quiet: cmd.quiet
	}

	// Special case for the direct medium, we just add the chunk directly.
	if t.medium == .direct {
		result.add_data(cmd.data)!
		return result
	}

	// XTODO: file, temporary_file, shared_memory mediums need
	// platform-specific I/O (realpath, file reading, shm_open, mmap).
	return error('non-direct medium not yet supported')
}

// Adds a chunk of data to the image. Use this if the image
// is coming in chunks (the "m" parameter in the protocol).
pub fn (mut self LoadingImage) add_data(data []u8) ! {
	// If no data, skip
	if data.len == 0 {
		return
	}
	// If our data would get too big, return an error
	if self.data.len + data.len > max_image_size {
		return error('image data too large max_size=${max_image_size}')
	}
	// Append the data
	self.data << data
}

// Complete the chunked image, returning a completed image.
pub fn (mut self LoadingImage) complete() !Image {
	// XTODO: Decompression (zlib_deflate) requires compress module integration.
	// XTODO: PNG decoding requires wuffs or stb_image integration.

	// Decompress the data if it is compressed.
	if self.image.compression == .zlib_deflate {
		// XTODO: zlib decompression not yet implemented
		return error('zlib decompression not yet supported')
	}

	// Decode the png if we have to
	if self.image.format == .png {
		// XTODO: PNG decoding not yet implemented
		return error('PNG decoding not yet supported')
	}

	// Validate our dimensions.
	if self.image.width == 0 || self.image.height == 0 {
		return error('dimensions required')
	}
	if self.image.width > max_dimension || self.image.height > max_dimension {
		return error('dimensions too large')
	}

	// Data length must be what we expect
	bpp := int(self.image.format.bpp())
	expected_len := int(self.image.width) * int(self.image.height) * bpp
	actual_len := self.data.len
	if actual_len != expected_len {
		return error('unexpected length image id=${self.image.id} expected=${expected_len} actual=${actual_len}')
	}

	// Everything looks good, copy the image data over.
	mut result := self.image
	result.data = self.data.clone()
	self.image = Image{}
	self.data = []
	return result
}

// Returns true if path appears to be in a temporary directory.
// Copies logic from Kitty.
fn is_path_in_temp_dir(path string) bool {
	// XTODO: Full implementation needs TempDir and realpath support.
	if path.starts_with('/tmp') {
		return true
	}
	if path.starts_with('/dev/shm') {
		return true
	}
	return false
}

// ============================================================
// Rect
// ============================================================

// Rect represents the rectangular area taken up by an image placement
// in grid cells (rounded up to nearest grid cell).
pub struct Rect {
pub:
	top_left     terminal.Pin
	bottom_right terminal.Pin
}

// ============================================================
// RenderPlacement
// ============================================================

// RenderPlacement holds placement and rendering information for
// an image in the terminal view.
pub struct RenderPlacement {
pub mut:
	// Top-left corner of the image in grid coordinates.
	top_left terminal.Pin
	// Horizontal offset in pixels from the top-left corner of the grid cell.
	offset_x u32
	// Vertical offset in pixels from the top-left corner of the grid cell.
	offset_y u32
	// X coordinate of source rectangle in the image.
	source_x u32
	// Y coordinate of source rectangle in the image.
	source_y u32
	// Width of source rectangle (from the image data).
	source_width u32
	// Height of source rectangle (from the image data).
	source_height u32
	// Final width of the image in pixels at destination.
	dest_width u32
	// Final height of the image in pixels at destination.
	dest_height u32
}
