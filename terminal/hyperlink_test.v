module terminal

// hyperlink_test.v - Tests for hyperlink types.
//
// Translated from Ghostty's terminal/hyperlink.zig.
// Most tests are stubs (XTODO) since they require page memory management.

fn test_hyperlink_dupe_implicit() {
	link := Hyperlink{
		id: HyperlinkIdKind(HyperlinkImplicitId{ offset: 42 })
		uri: 'https://example.com'
	}

	duped := link.dupe()
	assert duped.uri == 'https://example.com'

	match duped.id {
		HyperlinkImplicitId {
			assert duped.id.offset == 42
		}
		HyperlinkExplicitId {
			assert false, 'expected implicit id'
		}
	}
}

fn test_hyperlink_dupe_explicit() {
	link := Hyperlink{
		id: HyperlinkIdKind(HyperlinkExplicitId{ value: 'my-link-id' })
		uri: 'https://example.com/page'
	}

	duped := link.dupe()
	assert duped.uri == 'https://example.com/page'

	match duped.id {
		HyperlinkExplicitId {
			assert duped.id.value == 'my-link-id'
		}
		HyperlinkImplicitId {
			assert false, 'expected explicit id'
		}
	}
}

fn test_hyperlink_page_entry_eql_implicit() {
	a := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: 10 })
		uri_offset: 100
		uri_len: 20
	}
	b := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: 10 })
		uri_offset: 100
		uri_len: 20
	}
	c := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: 11 })
		uri_offset: 100
		uri_len: 20
	}

	assert a.eql(&b)
	assert !a.eql(&c)
}

fn test_hyperlink_page_entry_eql_explicit() {
	a := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryExplicitId{ offset: 0, len: 5 })
		uri_offset: 100
		uri_len: 20
	}
	b := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryExplicitId{ offset: 0, len: 5 })
		uri_offset: 100
		uri_len: 20
	}
	c := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryExplicitId{ offset: 0, len: 6 })
		uri_offset: 100
		uri_len: 20
	}

	assert a.eql(&b)
	assert !a.eql(&c)
}

fn test_hyperlink_page_entry_eql_mixed_kinds() {
	a := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: 10 })
		uri_offset: 100
		uri_len: 20
	}
	b := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryExplicitId{ offset: 10, len: 0 })
		uri_offset: 100
		uri_len: 20
	}

	// Different id kinds should not be equal
	assert !a.eql(&b)
}

fn test_hyperlink_page_entry_hash() {
	a := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: 10 })
		uri_offset: 100
		uri_len: 20
	}
	b := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: 10 })
		uri_offset: 100
		uri_len: 20
	}

	// Same entries should produce same hash
	assert a.hash() == b.hash()
}

fn test_hyperlink_page_entry_dupe() {
	original := HyperlinkPageEntry{
		id: HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: 42 })
		uri_offset: 200
		uri_len: 30
	}

	duped := original.dupe()
	assert duped.uri_offset == 200
	assert duped.uri_len == 30
	assert original.eql(&duped)
}

// XTODO: Tests for HyperlinkSet require RefCountedSet implementation.
// XTODO: Tests for PageEntry.dupe across pages require page memory management.
// XTODO: Tests for PageEntry.hash with base pointer require page memory.
// XTODO: Tests for PageEntry.eql with different base pointers require page memory.
// XTODO: Tests for PageEntry.free require page string allocator.
