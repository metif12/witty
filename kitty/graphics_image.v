module kitty

// --- Original Ghostty Comments Start: src/terminal/kitty/graphics_image.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/kitty/graphics_image.zig
//
// Maximum width or height of an image. Taken directly from Kitty.
// Maximum size in bytes, taken from Kitty.
// An image that is still being loaded. The image should be initialized
// using init on the first chunk and then addData for each subsequent
// chunk. Once all chunks have been added, complete should be called
// to finalize the image.
// The in-progress image. The first chunk must have all the metadata
// so this comes from that initially.
// The data that is being built up.
// This is non-null when a transmit and display command is given
// so that we display the image after it is fully loaded.
// Quiet is the quiet settings for the initial load command. This is
// used if q isn't set on subsequent chunks.
// Initialize a chunked immage from the first image transmission.
// If this is a multi-chunk image, this should only be the FIRST
// chunk.
// Build our initial image from the properties sent via the control.
// These can be overwritten by the data loading process. For example,
// PNG loading sets the width/height from the data.
// Special case for the direct medium, we just add the chunk directly.
// Otherwise, the payload data is guaranteed to be a path.
// posix.realpath *asserts* that the path does not have
// internal nulls instead of erroring.
// Depending on the medium, load the data from the path.
// Reads the data from a shared memory segment.
// windows is currently unsupported, does it support shm?
// libc is required for shm_open
// Since we're only supporting posix then max_path_bytes should
// be enough to stack allocate the path.
// The size from stat on may be larger than our expected size because
// shared memory has to be a multiple of the page size.
// Png we decode the full data size because later decoding will
// get the proper dimensions and assert validity.
// For these formats we have a size we must have.
// Our stat size must be at least the expected size otherwise
// the shared memory data is invalid.
// Our end size always uses the expected size so we cut off the
// padding for mmap alignment.
// Reads the data from a temporary file and returns it. This allocates
// and does not free any of the data, so the caller must free it.
//
// This will also delete the temporary file if it is in a safe location.
// Verify file seems "safe". This is logic copied directly from Kitty,
// mostly. This is really rough but it will catch obvious bad actors.
// Temporary file logic
// File must be a regular file
// Read the file
// Set our data
// Returns true if path appears to be in a temporary directory.
// Copies logic from Kitty.
// The temporary dir is sometimes a symlink. On macOS for
// example /tmp is /private/var/...
// Adds a chunk of data to the image. Use this if the image
// is coming in chunks (the "m" parameter in the protocol).
// If no data, skip
// If our data would get too big, return an error
// Ensure we have enough room to add the data
// to the end of the ArrayList before doing so.
// Complete the chunked image, returning a completed image.
// Decompress the data if it is compressed.
// Decode the png if we have to
// Validate our dimensions.
// Data length must be what we expect
// Set our time
// Everything looks good, copy the image data over.
// Debug function to write the data to a file. This is useful for
// capturing some test data for unit tests.
// Decompress the data in-place.
// Open our zlib stream
// Write it to an array list
// Empty our current data list, take ownership over managed array list
// Make sure we note that our image is no longer compressed
// Decode the data as PNG. This will also updated the image dimensions.
// Replace our data
// Store updated image dimensions
// Image represents a single fully loaded image.
// Set this to true if this image was loaded by a command that
// doesn't specify an ID or number, since such commands should
// not be responded to, even though we do currently give them
// IDs in the public range (which is bad!).
// Mostly for logging
// The rect taken up by some image placement, in grid cells. This will
// be rounded up to the nearest grid cell since we can't place images
// in partial grid cells.
// This specifically tests we ALLOW invalid RGB data because Kitty
// documents that this should work.
// <ESC>_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA<ESC>\
// should be decompressed
// should be decompressed
// Setup our initial chunk
// Read our remaining chunks
// Complete
// Setup our initial chunk
// Read our remaining chunks
// Complete
// Temporary file should still be there
// Temporary file should be gone
//
// --- Original Ghostty Comments End: src/terminal/kitty/graphics_image.zig


// Kitty graphics protocol image types.
//
// Source: kitty/graphics_image.zig, kitty/graphics_render.zig
//
// Defines the Image (fully loaded image data), LoadingImage (in-progress
// image loading), Rect (placement rectangle in grid cells), and
// RenderPlacement (placement rendering information) types.

import os
import time
import compress.zlib
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

	match t.medium {
		.direct {
			// Direct medium: the data is inline in the command payload.
			result.add_data(cmd.data)!
		}
		.file {
			// File medium: read the image data from the specified file path.
			path := cmd.data.bytestr()
			if path.len == 0 {
				return error('invalid data: empty file path')
			}
			if path.len > 4096 {
				return error('file path too long')
			}
			data := os.read_bytes(path) or {
				return error('invalid data: cannot read file ${path}')
			}
			result.add_data(data)!
		}
		.temporary_file {
			// Temporary file medium: read from a file that must be in a temp dir.
			// After reading, the file should be deleted.
			path := cmd.data.bytestr()
			if path.len == 0 {
				return error('invalid data: empty file path')
			}
			if path.len > 4096 {
				return error('file path too long')
			}
			if !is_path_in_temp_dir(path) {
				return error('temporary file not in temp dir')
			}
			// Kitty requires temp files to have "tty-graphics-protocol" in name.
			base := os.base(path)
			if !base.contains('tty-graphics-protocol') {
				return error('temporary file not named correctly')
			}
			data := os.read_bytes(path) or {
				return error('invalid data: cannot read temporary file ${path}')
			}
			result.add_data(data)!
			// Best-effort delete of the temporary file after reading.
			os.rm(path) or {}
		}
		.shared_memory {
			// Shared memory medium requires platform-specific shm_open/mmap.
			return error('unsupported medium: shared memory not yet implemented')
		}
	}

	return result
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
	// Decompress the data if it is compressed.
	if self.image.compression == .zlib_deflate {
		decompressed := zlib.decompress(self.data) or {
			return error('decompression failed: ${err.msg()}')
		}
		self.data = decompressed
		self.image.compression = .none_
	}

	// Decode the PNG if we have to. PNG decoding produces raw pixel data
	// and sets the width/height/format from the PNG header.
	if self.image.format == .png {
		// TODO: PNG decoding requires stb_image or equivalent integration.
		// Once available, decode self.data as PNG, extract width/height/format/pixels.
		return error('unsupported format: PNG decoding not yet implemented')
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
// Copies logic from Kitty: checks common temp dirs and TMPDIR env.
fn is_path_in_temp_dir(path string) bool {
	if path.starts_with('/tmp') {
		return true
	}
	if path.starts_with('/var/tmp') {
		return true
	}
	if path.starts_with('/dev/shm') {
		return true
	}
	// Check TMPDIR environment variable if set.
	tmpdir := os.getenv('TMPDIR')
	if tmpdir.len > 0 && path.starts_with(tmpdir) {
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
