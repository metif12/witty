module font

// Tests for font discovery.
// Translated from ghostty/src/font/discovery.zig

// test_descriptor_hash tests that a default descriptor produces
// a non-zero hash.
fn test_descriptor_hash() {
	d := Descriptor{}
	assert d.hashcode() != 0
}

// test_descriptor_hash_family_names tests that descriptors with
// different family names produce different hashes.
fn test_descriptor_hash_family_names() {
	d1 := Descriptor{ family: 'A' }
	d2 := Descriptor{ family: 'B' }
	assert d1.hashcode() != d2.hashcode()
}

// test_fontconfig tests basic fontconfig discovery.
fn test_fontconfig() {
	// TODO: requires real fontconfig backend
	// Uncomment when fontconfig bindings are available:
	//
	// mut fc := FontconfigDiscovery.init()
	// defer { fc.deinit() }
	// mut it := fc.discover(Descriptor{ family: 'monospace', size: 12 }) or { return }
	// defer { it.deinit() }
}

// test_fontconfig_codepoint tests fontconfig discovery for a specific codepoint.
fn test_fontconfig_codepoint() {
	// TODO: requires real fontconfig backend
	// Uncomment when fontconfig bindings are available:
	//
	// mut fc := FontconfigDiscovery.init()
	// defer { fc.deinit() }
	// mut it := fc.discover(Descriptor{ codepoint: `A`, size: 12 }) or { return }
	// defer { it.deinit() }
	//
	// // The first result should have the codepoint. Later ones may not
	// // because fontconfig returns all fonts sorted.
	// mut face := it.next() or { return } or { return }
	// defer { face.deinit() }
	// assert face.has_codepoint(`A`, unsafe { nil })
	//
	// // Should have other codepoints too
	// assert face.has_codepoint(`B`, unsafe { nil })
}

// test_coretext tests basic CoreText discovery.
fn test_coretext() {
	// TODO: requires real CoreText backend
	// Uncomment when CoreText bindings are available:
	//
	// mut ct := CoreTextDiscovery.init()
	// defer { ct.deinit() }
	// mut it := ct.discover(Descriptor{ family: 'Monaco', size: 12 }) or { return }
	// defer { it.deinit() }
	// mut count := 0
	// for {
	//     _ = it.next() or { break } or { break }
	//     count += 1
	// }
	// assert count > 0
}

// test_coretext_codepoint tests CoreText discovery for a specific codepoint.
fn test_coretext_codepoint() {
	// TODO: requires real CoreText backend
	// Uncomment when CoreText bindings are available:
	//
	// mut ct := CoreTextDiscovery.init()
	// defer { ct.deinit() }
	// mut it := ct.discover(Descriptor{ codepoint: `A`, size: 12 }) or { return }
	// defer { it.deinit() }
	//
	// // The first result should have the codepoint.
	// face := it.next() or { return } or { return }
	// assert face.has_codepoint(`A`, unsafe { nil })
	//
	// // Should have other codepoints too
	// assert face.has_codepoint(`B`, unsafe { nil })
}

// test_coretext_sorting tests that CoreText sorts results correctly.
fn test_coretext_sorting() {
	// TODO: requires real CoreText backend and SF Pro font
	// This test is also disabled in the Zig source because SF Pro
	// is not available in CI.
	//
	// The solution likely involves directly testing that the
	// sort_matching_descriptors function sorts a bundled test
	// font correctly, instead of relying on the system fonts.
}

// test_score_comparison tests that Score comparison works correctly.
fn test_score_comparison() {
	// A score with codepoint should be higher than one without
	s1 := Score{ codepoint: true }
	s2 := Score{ monospace: true }
	assert s1.to_int() > s2.to_int()

	// Monospace is more important than exact_style
	s3 := Score{ monospace: true }
	s4 := Score{ exact_style: true }
	assert s3.to_int() > s4.to_int()

	// Exact style is more important than italic
	s5 := Score{ exact_style: true }
	s6 := Score{ italic: true }
	assert s5.to_int() > s6.to_int()

	// Italic is more important than bold
	s7 := Score{ italic: true }
	s8 := Score{ bold: true }
	assert s7.to_int() > s8.to_int()

	// Glyph count is least significant
	s9 := Score{ glyph_count: 65535 }
	s10 := Score{ bold: true }
	assert s10.to_int() > s9.to_int()
}

// test_descriptor_clone tests that cloning a descriptor works correctly.
fn test_descriptor_clone() {
	d := Descriptor{
		family:    'Test Family'
		style:     'Bold'
		codepoint: 0x41
		size:      12.0
		bold:      true
		variations: [Variation{
			id:    VariationId{ value: 0x77676874 } // 'wght'
			value: 700.0
		}]
	}
	c := d.clone()
	assert c.family or { '' } == 'Test Family'
	assert c.style or { '' } == 'Bold'
	assert c.codepoint == 0x41
	assert c.bold == true
	assert c.variations.len == 1
	assert c.variations[0].value == 700.0
}
