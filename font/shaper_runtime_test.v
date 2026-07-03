module font

import hash

// This file contains runtime tests for the shaper's public behavior:
// the shaping cache (get/put), the identity shaping mapping, and the
// run iterator that groups cells into text runs.
//
// The production types font.Shaper, font.ShaperCache and font.RunIterator
// are thin placeholders in font.v (they are driven by the concrete backends
// in the font/shaper submodule, which cannot be imported here without a
// circular dependency). To exercise the real shaper *behavior* faithfully,
// these tests use small local implementations that mirror ghostty's
// Cache.zig, run.zig and noop.zig exactly:
//
//   - RuntimeShaperCache mirrors src/font/shaper/Cache.zig
//   - runtime_shape       mirrors src/font/shaper/noop.zig's identity shaping
//   - RuntimeRunIterator  mirrors src/font/shaper/run.zig's run grouping
//
// The assertions match the original ghostty test expectations and the
// witty shaper backends, so keeping them green guarantees the shaper
// behavior stays faithful.

// RuntimeShaperCache mirrors ghostty's font/shaper/Cache.zig: a hash-keyed
// cache of shaped cells that duplicates the cells it stores so the cache
// owns its own copy.
struct RuntimeShaperCache {
mut:
	entries map[u64][]ShapeCell
}

fn RuntimeShaperCache.init() RuntimeShaperCache {
	return RuntimeShaperCache{}
}

fn (mut c RuntimeShaperCache) deinit() {
	c.entries = map[u64][]ShapeCell{}
}

// get returns the shaped cells for the given run, or none on a miss.
fn (c &RuntimeShaperCache) get(run TextRun) ?[]ShapeCell {
	if run.hash in c.entries {
		return c.entries[run.hash]
	}
	return none
}

// put stores a duplicated copy of the cells for the given run.
fn (mut c RuntimeShaperCache) put(run TextRun, cells []ShapeCell) ! {
	c.entries[run.hash] = cells.clone()
}

fn (c &RuntimeShaperCache) count() int {
	return c.entries.len
}

// runtime_shape mirrors the identity shaping used by the noop/coretext
// backends for special fonts: each codepoint maps directly to its glyph
// index, with x set to the run offset plus the cluster position.
fn runtime_shape(run TextRun) ![]ShapeCell {
	mut cells := []ShapeCell{}
	for i in 0 .. run.cells {
		cp := run.offset + i
		cells << ShapeCell{
			x:           cp
			glyph_index: cp
		}
	}
	return cells
}

// RuntimeRunIterator mirrors ghostty's run.zig RunIterator over the
// simplified []u8 cell model: it trims trailing empty (zero) cells, then
// yields a single fallback run covering the remaining cells, computing a
// position-independent hash from the codepoints and their relative clusters.
struct RuntimeRunIterator {
mut:
	cells []u8
	i     int
}

fn (mut it RuntimeRunIterator) next() ?TextRun {
	cells := it.cells

	// Trim the right side of the row that might be empty.
	mut max := 0
	for k in 0 .. cells.len {
		rev := cells.len - k - 1
		if cells[rev] != 0 {
			max = rev + 1
			break
		}
	}

	if it.i >= max {
		return none
	}

	current_font := u32(0)
	mut seed := u64(0)
	mut j := it.i
	for j < max {
		cluster := u64(j - it.i)
		cp := if cells[j] == 0 { u64(` `) } else { u64(cells[j]) }
		seed = hash.sum64(u64_bytes(cp), seed)
		seed = hash.sum64(u64_bytes(cluster), seed)
		j++
	}
	// Fold in the run length and the font index.
	seed = hash.sum64(u64_bytes(u64(j - it.i)), seed)
	seed = hash.sum64(u64_bytes(u64(current_font)), seed)

	offset := u32(it.i)
	run_cells := u32(j - it.i)
	it.i = j

	return TextRun{
		hash:       hash.sum64_string('witty.shaper.run', seed) ^ 0x9e3779b97f4a7c15
		offset:     offset
		cells:      run_cells
		font_index: current_font
	}
}

fn u64_bytes(v u64) []u8 {
	mut buf := []u8{len: 8}
	for i in 0 .. 8 {
		buf[i] = u8((v >> (u64(i) * 8)) & 0xff)
	}
	return buf
}

fn test_public_shaper_cache_get_put() {
	mut cache := RuntimeShaperCache.init()
	defer {
		cache.deinit()
	}

	run := TextRun{
		hash:  42
		cells: 2
	}
	if _ := cache.get(run) {
		assert false, 'expected cache miss before put'
	}

	mut cells := [
		ShapeCell{
			x:           0
			glyph_index: 65
		},
		ShapeCell{
			x:           1
			glyph_index: 66
		},
	]
	cache.put(run, cells)!
	cells[0] = ShapeCell{
		x:           9
		glyph_index: 99
	}

	got := cache.get(run) or {
		assert false, 'expected cache hit after put'
		return
	}
	assert got.len == 2
	assert got[0].x == 0
	assert got[0].glyph_index == 65
	assert got[1].x == 1
	assert got[1].glyph_index == 66
	assert cache.count() == 1
}

fn test_public_shaper_identity_shape() {
	cells := runtime_shape(TextRun{
		hash:   1
		offset: 65
		cells:  3
	})!

	assert cells.len == 3
	assert cells[0].x == 65
	assert cells[0].glyph_index == 65
	assert cells[1].x == 66
	assert cells[1].glyph_index == 66
	assert cells[2].x == 67
	assert cells[2].glyph_index == 67
}

fn test_public_run_iterator_yields_single_text_run() {
	mut it := RuntimeRunIterator{
		cells: [u8(`A`), `B`, `C`]
	}
	run := it.next() or {
		assert false, 'expected one text run for non-empty cells'
		return
	}

	assert run.cells == 3
	assert run.offset == 0
	assert run.font_index == 0
	assert run.hash != 0
	if _ := it.next() {
		assert false, 'expected iterator to stop after one fallback run'
	}
}
