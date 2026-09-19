module png

import wuffs

// decode translates wuffs.png.decode. Allocation is handled by V's GC.
pub fn decode(source []u8) !wuffs.ImageData {
	return wuffs.png_decode(source)
}
