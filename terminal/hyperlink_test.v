module terminal

fn test_hyperlink_id_uses_source_width() {
	assert sizeof(HyperlinkId) == 2
}

fn implicit_link(offset u32, uri string) Hyperlink {
	return Hyperlink{
		id:  HyperlinkImplicitId{ offset: offset }
		uri: uri
	}
}

fn explicit_link(id string, uri string) Hyperlink {
	return Hyperlink{
		id:  HyperlinkExplicitId{ value: id }
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
	first := set.add(explicit_link('one', 'https://example.com')) or { panic(err) }
	again := set.add(explicit_link('one', 'https://example.com')) or { panic(err) }
	different_id := set.add(explicit_link('two', 'https://example.com')) or { panic(err) }
	implicit := set.add(implicit_link(1, 'https://example.com')) or { panic(err) }

	assert first == again
	assert set.ref_count(first) == 2
	assert different_id != first
	assert implicit != first
	assert set.count() == 3
}

fn test_hyperlink_set_release_and_reuse() {
	mut set := HyperlinkSet.init()
	first := set.add(implicit_link(1, 'https://one.example')) or { panic(err) }
	used := set.string_used()
	set.use_link(first)
	assert set.ref_count(first) == 2
	set.release(first)
	assert set.ref_count(first) == 1
	set.release(first)
	assert set.ref_count(first) == 0
	assert set.count() == 0
	// Dead entries retain their strings until the slot is reaped.
	assert set.string_used() == used

	reused := set.add(implicit_link(2, 'https://two.example')) or { panic(err) }
	assert reused == first
	assert set.get(reused).uri == 'https://two.example'
	assert set.string_used() == used
}

fn test_hyperlink_set_reports_out_of_memory_and_needs_rehash() {
	layout := page_set_layout(4, hyperlink_set_item_size, 8)
	mut full := HyperlinkSet.init_bounded(layout, bitmap_allocator_layout(uint(string_bytes_default), string_chunk))
	assert full.capacity() == 2
	first := full.add(implicit_link(1, 'https://one.example')) or { panic(err) }
	_ := full.add(implicit_link(2, 'https://two.example')) or { panic(err) }

	mut full_error := ''
	_ := full.add(implicit_link(3, 'https://three.example')) or {
		full_error = err.msg()
		u32(0)
	}
	assert full_error == 'set out of memory'

	full.release(first)
	mut rehash_error := ''
	_ := full.add(implicit_link(3, 'https://three.example')) or {
		rehash_error = err.msg()
		u32(0)
	}
	assert rehash_error == 'set needs rehash'
}

fn test_hyperlink_set_lookup() {
	mut set := HyperlinkSet.init()
	link := explicit_link('id', 'https://example.com')
	id := set.add(link) or { panic(err) }
	assert set.lookup(&link)? == id
	other := explicit_link('other', 'https://example.com')
	assert set.lookup(&other) == none
}

fn test_hyperlink_set_add_with_id_reuses_requested_slot() {
	mut set := HyperlinkSet.init()
	first := set.add(implicit_link(1, 'https://one.example')) or { panic(err) }
	second := set.add(implicit_link(2, 'https://two.example')) or { panic(err) }
	assert first == 1
	assert second == 2
	set.release(first)

	reused := set.add_with_id(explicit_link('replacement', 'https://three.example'), first) or {
		panic(err)
	}
	assert reused == first
	assert set.get(reused).uri == 'https://three.example'
	assert set.ref_count(reused) == 1
}

fn test_hyperlink_set_add_with_id_falls_back_for_live_slot() {
	mut set := HyperlinkSet.init()
	first := set.add(implicit_link(1, 'https://one.example')) or { panic(err) }
	second := set.add_with_id(implicit_link(2, 'https://two.example'), first) or { panic(err) }
	assert second != first
	assert set.get(first).uri == 'https://one.example'
	assert set.get(second).uri == 'https://two.example'
}

fn test_hyperlink_set_add_with_id_deduplicates_before_reusing_slot() {
	mut set := HyperlinkSet.init()
	first := set.add(implicit_link(1, 'https://one.example')) or { panic(err) }
	second := set.add(implicit_link(2, 'https://two.example')) or { panic(err) }
	set.release(first)

	reused := set.add_with_id(implicit_link(2, 'https://two.example'), first) or { panic(err) }
	assert reused == second
	assert set.ref_count(second) == 2
	// The pinned RefCountedSet increments living on this addWithId path even
	// when upsert selects an already-live semantic duplicate.
	assert set.count() == 2
}

fn test_hyperlink_set_robin_hood_displacement_updates_stored_psl() {
	mut set := HyperlinkSet.init()
	mut links_by_bucket := [][]Hyperlink{len: int(set.layout.table_cap)}
	for offset in 0 .. 256 {
		link := implicit_link(u32(offset), 'https://collision.example/${offset}')
		entry := HyperlinkPageEntry.from_hyperlink(&link)
		bucket := int(entry.hash() & u64(set.layout.table_mask))
		links_by_bucket[bucket] << link
	}

	mut start_bucket := -1
	for bucket in 0 .. int(set.layout.table_cap) {
		next_bucket := (bucket + 1) & int(set.layout.table_mask)
		if links_by_bucket[bucket].len >= 2 && links_by_bucket[next_bucket].len >= 1 {
			start_bucket = bucket
			break
		}
	}
	assert start_bucket >= 0

	next_bucket := (start_bucket + 1) & int(set.layout.table_mask)
	first := links_by_bucket[start_bucket][0]
	displaced := links_by_bucket[next_bucket][0]
	colliding := links_by_bucket[start_bucket][1]

	first_id := set.add(first)!
	displaced_id := set.add(displaced)!
	colliding_id := set.add(colliding)!

	assert set.lookup(&first) or { panic('first hyperlink missing') } == first_id
	assert set.lookup(&colliding) or { panic('colliding hyperlink missing') } == colliding_id
	assert set.set.items_view(set.base)[int(displaced_id)].meta.psl == 1
	assert set.lookup(&displaced) or { panic('displaced hyperlink missing') } == displaced_id
}
