module font

import ascii
import fontconfig
import os

// Tests for font discovery.
// Translated from ghostty/src/font/discovery.zig

fn test_discover_uses_the_target_backend_directly() {
	mut discover := Discover.init()
	defer { discover.deinit() }
	$if macos {
		mut it := discover.discover(Descriptor{ family: 'Menlo', size: 12 })!
		defer { it.deinit() }
		value := it.next()!
		assert value.has_value, 'CoreText returned no Menlo face'
		mut face := value.face
		defer { face.deinit() }
		assert !isnil(face.coretext.ct_font)
		assert face.has_codepoint(u32(`A`), none)
	} $else {
		mut it := discover.discover(Descriptor{ family: 'monospace', size: 12 })!
		defer { it.deinit() }
		value := it.next()!
		assert value.has_value, 'fontconfig returned no monospace font'
		mut face := value.face
		defer { face.deinit() }
		assert (face.fontconfig_pattern.get(.file, 0)! as fontconfig.ValueString).value.len > 0
		assert face.has_codepoint(u32(`A`), none)
	}
}

fn test_discovery_iterators_return_explicit_empty_value() {
	mut fc := FcDiscoverIterator{}
	assert !(fc.next()!).has_value
	$if macos {
		mut ct := CtDiscoverIterator{}
		assert !(ct.next()!).has_value
	}
}

// test_descriptor_hash tests that a default descriptor produces
// a non-zero hash.
fn test_descriptor_hash() {
	d := Descriptor{}
	// Reference value from Descriptor.hash under Zig 0.15.2.
	assert d.hashcode() == u64(0x96ab7b8f4eaa5424)
	mut hasher := SourceHash{}
	d.hash(mut hasher)
	assert hasher.final() == d.hashcode()
}

// test_descriptor_hash_family_names tests that descriptors with
// different family names produce different hashes.
fn test_descriptor_hash_family_names() {
	d1 := Descriptor{
		family: 'A'
	}
	d2 := Descriptor{
		family: 'B'
	}
	assert d1.hashcode() == u64(0xbe9ee1e426d783d7)
	assert d1.hashcode() != d2.hashcode()
}

// Ghostty hashes the IEEE-754 bits of the requested point size. Values that
// differ by less than the old decimal quantization must remain distinct.
fn test_descriptor_hash_exact_size_bits() {
	d1 := Descriptor{
		size: f32(12.000001)
	}
	d2 := Descriptor{
		size: f32(12.000002)
	}
	assert d1.size != d2.size
	assert d1.hashcode() != d2.hashcode()
}

// test_fontconfig tests basic fontconfig discovery.
fn test_fontconfig() {
	mut fc := FontconfigDiscovery.init()
	defer { fc.deinit() }
	mut it := fc.discover(Descriptor{ family: 'monospace', size: 12 }) or {
		assert false, err.msg()
		return
	}
	defer { it.deinit() }
	value := it.next() or {
		assert false, err.msg()
		return
	}
	assert value.has_value, 'fontconfig returned no monospace font'
	mut face := value.face
	defer { face.deinit() }
	assert !isnil(face.fontconfig_pattern)
	assert !isnil(face.fontconfig_charset)
	assert !isnil(face.fontconfig_langset)
	path := (face.fontconfig_pattern.get(.file, 0)! as fontconfig.ValueString).value
	assert path.len > 0
	assert os.exists(path)
}

// test_fontconfig_codepoint tests fontconfig discovery for a specific codepoint.
fn test_fontconfig_codepoint() {
	mut fc := FontconfigDiscovery.init()
	defer { fc.deinit() }
	mut it := fc.discover(Descriptor{ codepoint: u32(0x41), size: 12 }) or {
		assert false, err.msg()
		return
	}
	defer { it.deinit() }

	// The first result must carry the requested-codepoint coverage metadata.
	value := it.next() or {
		assert false, err.msg()
		return
	}
	assert value.has_value, 'fontconfig returned no face for U+0041'
	mut face := value.face
	defer { face.deinit() }
	assert face.has_codepoint(u32(0x41), none)
}

// test_coretext tests basic CoreText discovery.
fn test_coretext() {
	$if macos {
		mut ct := CoreTextDiscovery.init()
		defer { ct.deinit() }
		mut it := ct.discover(Descriptor{ family: 'Menlo', size: 12 }) or {
			assert false, err.msg()
			return
		}
		defer { it.deinit() }
		value := it.next() or {
			assert false, err.msg()
			return
		}
		assert value.has_value, 'CoreText returned no Menlo face'
		mut face := value.face
		defer { face.deinit() }
		assert face.has_codepoint(u32(`A`), none)
	}
}

// test_coretext_codepoint tests CoreText discovery for a specific codepoint.
fn test_coretext_codepoint() {
	$if macos {
		mut ct := CoreTextDiscovery.init()
		defer { ct.deinit() }
		mut it := ct.discover(Descriptor{ codepoint: u32(0x41), size: 12 }) or {
			assert false, err.msg()
			return
		}
		defer { it.deinit() }

		value := it.next() or {
			assert false, err.msg()
			return
		}
		assert value.has_value, 'CoreText returned no face for U+0041'
		mut face := value.face
		defer { face.deinit() }
		assert face.has_codepoint(u32(0x41), none)
	}
}

// Ghostty propagates an error loading the selected collection face while
// looking up a CoreText fallback. It must not silently try a lower-priority
// style or turn the failure into an absent fallback.
fn test_coretext_fallback_propagates_collection_face_load_error() {
	$if macos {
		mut collection := Collection.init()
		defer { collection.deinit() }
		collection.regular_faces << EntryOrAlias.new_entry(Entry{
			face: EntryFace(DeferredFace{})
		})

		ct := CoreTextDiscovery.init()
		ct.discover_fallback(mut collection, Descriptor{
			codepoint: 0x4E00
		}) or {
			assert err.msg() == 'deferred loading unavailable'
			return
		}
		assert false, 'expected the collection face load error'
	}
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
	s1 := Score.init(0, 0, false, false, false, false, true)
	s2 := Score.init(0, 0, false, false, false, true, false)
	assert s1.int() > s2.int()

	// Monospace is more important than exact_style
	s3 := Score.init(0, 0, false, false, false, true, false)
	s4 := Score.init(0, 0, false, false, true, false, false)
	assert s3.int() > s4.int()

	// Exact style is more important than italic
	s5 := Score.init(0, 0, false, false, true, false, false)
	s6 := Score.init(0, 0, false, true, false, false, false)
	assert s5.int() > s6.int()

	// Italic is more important than bold
	s7 := Score.init(0, 0, false, true, false, false, false)
	s8 := Score.init(0, 0, true, false, false, false, false)
	assert s7.int() > s8.int()

	// Glyph count is least significant
	s9 := Score.init(65535, 0, false, false, false, false, false)
	s10 := Score.init(0, 0, true, false, false, false, false)
	assert s10.int() > s9.int()

	all := Score.init(0xabcd, 0xef, true, true, true, true, true)
	assert sizeof(Score) == 4
	assert all.int() == 0x1fef_abcd
	assert all.glyph_count() == 0xabcd
	assert all.fuzzy_style() == 0xef
	assert all.bold()
	assert all.italic()
	assert all.exact_style()
	assert all.monospace()
	assert all.codepoint()
}

fn test_coretext_score_uses_zig_ascii_matching() {
	assert ascii.eql_ignore_case('Bold Italic', 'bOLD iTALIC')
	assert !ascii.eql_ignore_case('İtalic', 'italic')
	assert !ascii.eql_ignore_case('Regular\x00Bold', 'regular')
	assert ascii.index_of_ignore_case('ExtraBold Italic', 'bold') != none
	assert ascii.index_of_ignore_case('Khaki', 'kh') == none
}

// test_descriptor_clone tests that cloning a descriptor works correctly.
fn test_descriptor_clone() {
	d := Descriptor{
		family:     'Test Family'
		style:      'Bold'
		codepoint:  0x41
		size:       12.0
		bold:       true
		variations: [
			Variation{
				id:    VariationId{
					value: 0x77676874
				} // 'wght'
				value: 700.0
			},
		]
	}
	c := d.clone()
	assert c.family or { '' } == 'Test Family'
	assert c.style or { '' } == 'Bold'
	assert c.codepoint == 0x41
	assert c.bold == true
	assert c.variations.len == 1
	assert c.variations[0].value == 700.0
}
