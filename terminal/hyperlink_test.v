module terminal

fn implicit_link(offset u32, uri string) Hyperlink {
	return Hyperlink{
		id: HyperlinkImplicitId{ offset: offset }
		uri: uri
	}
}

fn explicit_link(id string, uri string) Hyperlink {
	return Hyperlink{
		id: HyperlinkExplicitId{ value: id }
		uri: uri
	}
}

fn test_hyperlink_dupe_preserves_implicit_identity() {
	link := implicit_link(42, 'https://example.com')
	duped := link.dupe()
	assert link.eql(&duped)
	match duped.id {
		HyperlinkImplicitId {
			assert duped.id.offset == 42
		}
		else {
			assert false, 'expected implicit ID'
		}
	}
}

fn test_hyperlink_dupe_preserves_explicit_identity() {
	link := explicit_link('my-link-id', 'https://example.com/page')
	duped := link.dupe()
	assert link.eql(&duped)
	match duped.id {
		HyperlinkExplicitId {
			assert duped.id.value == 'my-link-id'
		}
		else {
			assert false, 'expected explicit ID'
		}
	}
}

fn test_hyperlink_identity_includes_id_and_uri() {
	a := explicit_link('one', 'https://example.com')
	b := explicit_link('two', 'https://example.com')
	c := implicit_link(1, 'https://example.com')
	d := explicit_link('one', 'https://example.org')
	assert !a.eql(&b)
	assert !a.eql(&c)
	assert !a.eql(&d)
}

fn test_hyperlink_page_entry_round_trip_and_dupe() {
	link := explicit_link('same-id', 'https://example.com')
	entry := HyperlinkPageEntry.from_hyperlink(&link)
	duped := entry.dupe()
	round_trip := duped.hyperlink()
	assert link.eql(&round_trip)
	assert entry.eql(&duped)
	assert entry.hash() == duped.hash()
}

fn test_hyperlink_page_entry_hashes_semantic_data() {
	link_a := explicit_link('one', 'https://example.com')
	link_b := explicit_link('two', 'https://example.com')
	link_c := implicit_link(1, 'https://example.com')
	link_d := implicit_link(2, 'https://example.com')
	a := HyperlinkPageEntry.from_hyperlink(&link_a)
	b := HyperlinkPageEntry.from_hyperlink(&link_b)
	c := HyperlinkPageEntry.from_hyperlink(&link_c)
	d := HyperlinkPageEntry.from_hyperlink(&link_d)
	assert a.hash() != b.hash()
	assert a.hash() != c.hash()
	assert c.hash() != d.hash()
	// Values produced by Ghostty's source algorithm with Zig 0.15.2.
	assert a.hash() == u64(0x605bb8addff95e18)
	assert c.hash() == u64(0x946408359003474a)
}

fn test_hyperlink_set_deduplicates_full_identity() {
	mut set := HyperlinkSet.init()
	first := set.add(explicit_link('one', 'https://example.com'))
	again := set.add(explicit_link('one', 'https://example.com'))
	different_id := set.add(explicit_link('two', 'https://example.com'))
	implicit := set.add(implicit_link(1, 'https://example.com'))

	assert first == again
	assert set.ref_count(first) == 2
	assert different_id != first
	assert implicit != first
	assert set.count() == 3
}

fn test_hyperlink_set_release_and_reuse() {
	mut set := HyperlinkSet.init()
	first := set.add(implicit_link(1, 'https://one.example'))
	set.use_link(first)
	assert set.ref_count(first) == 2
	set.release(first)
	assert set.ref_count(first) == 1
	set.release(first)
	assert set.ref_count(first) == 0
	assert set.count() == 0

	reused := set.add(implicit_link(2, 'https://two.example'))
	assert reused == first
	assert set.get(reused).uri == 'https://two.example'
}

fn test_hyperlink_set_lookup() {
	mut set := HyperlinkSet.init()
	link := explicit_link('id', 'https://example.com')
	id := set.add(link)
	assert set.lookup(&link)? == id
	other := explicit_link('other', 'https://example.com')
	assert set.lookup(&other) == none
}

fn test_hyperlink_set_add_with_id_reuses_requested_slot() {
	mut set := HyperlinkSet.init()
	first := set.add(implicit_link(1, 'https://one.example'))
	second := set.add(implicit_link(2, 'https://two.example'))
	assert first == 1
	assert second == 2
	set.release(first)

	reused := set.add_with_id(explicit_link('replacement', 'https://three.example'), first)
	assert reused == first
	assert set.get(reused).uri == 'https://three.example'
	assert set.ref_count(reused) == 1
}

fn test_hyperlink_set_add_with_id_falls_back_for_live_slot() {
	mut set := HyperlinkSet.init()
	first := set.add(implicit_link(1, 'https://one.example'))
	second := set.add_with_id(implicit_link(2, 'https://two.example'), first)
	assert second != first
	assert set.get(first).uri == 'https://one.example'
	assert set.get(second).uri == 'https://two.example'
}

fn test_hyperlink_set_add_with_id_deduplicates_before_reusing_slot() {
	mut set := HyperlinkSet.init()
	first := set.add(implicit_link(1, 'https://one.example'))
	second := set.add(implicit_link(2, 'https://two.example'))
	set.release(first)

	reused := set.add_with_id(implicit_link(2, 'https://two.example'), first)
	assert reused == second
	assert set.ref_count(second) == 2
	assert set.count() == 1
}
