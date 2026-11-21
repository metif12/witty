module font

// The wasm-compatible Atlas API. Ghostty keeps this under Atlas.Wasm; V does
// not support declarations nested in a struct namespace, so the functions are
// exposed directly from the font module and the root wasm file gives them the
// exact exported symbol names.

pub fn atlas_new(size u32, format u8) ?&Atlas {
	format_value := unsafe { AtlasFormat(format) }
	atlas := Atlas.init(size, format_value) or { return none }
	mut result := &Atlas{}
	unsafe {
		*result = atlas
	}
	return result
}

pub fn atlas_free(ptr ?&Atlas) {
	if mut value := ptr {
		value.deinit()
		unsafe {
			free(value)
		}
	}
}

// The returned region is host-owned and must be released with free.
pub fn atlas_reserve(mut self Atlas, width u32, height u32) ?&AtlasRegion {
	region := self.reserve(width, height) or { return none }
	mut result := &AtlasRegion{}
	unsafe {
		*result = region
	}
	return result
}

pub fn atlas_set(mut self Atlas, reg &AtlasRegion, data &u8, len uint) {
	bytes := unsafe { data.vbytes(int(len)) }
	self.set(*reg, bytes)
}

pub fn atlas_grow(mut self Atlas, size_new u32) bool {
	self.grow(size_new) or { return false }
	return true
}

pub fn atlas_clear(mut self Atlas) {
	self.clear()
}
