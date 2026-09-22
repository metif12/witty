module font

fn test_atlas_wasm_api_happy_path() {
	mut atlas := atlas_new(34, u8(AtlasFormat.grayscale)) or {
		assert false, 'atlas_new must allocate a valid grayscale atlas'
		return
	}
	defer { atlas_free(atlas) }

	region := atlas_reserve(mut atlas, 2, 2) or {
		assert false, 'atlas_reserve must return a host-owned region'
		return
	}
	defer {
		unsafe { free(region) }
	}
	assert region.width == 2
	assert region.height == 2

	data := [u8(1), 2, 3, 4]
	modified := atlas.modified.load()
	atlas_set(mut atlas, region, data.data, usize(data.len))
	assert atlas.modified.load() > modified
	assert atlas.data[int(region.y * atlas.size + region.x)] == 1
	assert atlas.data[int((region.y + 1) * atlas.size + region.x + 1)] == 4

	assert atlas_grow(mut atlas, 35)
	assert atlas.size == 35
	atlas_clear(mut atlas)
	assert atlas.data.all(it == 0)
}

fn test_atlas_wasm_api_reports_reserve_and_grow_failures() {
	mut atlas := atlas_new(4, u8(AtlasFormat.grayscale)) or {
		assert false, 'atlas_new must allocate a valid grayscale atlas'
		return
	}
	defer { atlas_free(atlas) }

	assert atlas_reserve(mut atlas, 3, 3) == none
	mut tw := atlas_grow_tripwire()
	tw.error_always(.alloc_data, error('OutOfMemory'))
	defer { tw.end(.reset) or { panic(err) } }
	assert !atlas_grow(mut atlas, 8)
	assert atlas.size == 4
}

fn test_atlas_wasm_free_accepts_none() {
	atlas_free(none)
}
