module zigimg

fn test_flate_source_small_lookup_and_linked_codes() {
	// A complete chain has two 15-bit leaves under one 9-bit lookup prefix.
	lens := [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 15]
	tree := tiff_flate_tree(lens, 30, 15)!
	assert tree.lookup.len == 512
	assert tree.symbols.len == 30
	mut linked := 0
	for symbol in tree.symbols {
		if symbol.bits == 0 { continue }
		if symbol.bits > 9 { linked++ }
		for low in 0 .. (1 << (15 - int(symbol.bits))) {
			found := tree.find(u64(symbol.code) + u64(low))!
			assert found.value == symbol.value
			assert found.bits == symbol.bits
		}
	}
	assert linked == 7
}

fn test_flate_source_codegen_fixture() {
	lens := [u8(4), 3, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 3, 2]
	tree := tiff_flate_tree(lens, 19, 7)!
	assert tree.lookup.len == 128
	for i in 0 .. 12 { assert tree.symbols[i].bits == 0 }
	for i, code in [0, 32, 64, 80, 96, 112, 120] {
		assert tree.find(u64(code))!.value == [3, 18, 1, 4, 17, 0, 16][i]
	}
}
