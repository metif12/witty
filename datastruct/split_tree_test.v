module main

import datastruct

fn test_split_tree_source_enum_layouts_and_ordinals() {
	assert sizeof(datastruct.Handle) == 2
	assert datastruct.handle_root.idx() == 0
	assert datastruct.Handle(41).offset(1) == datastruct.Handle(42)
	assert sizeof(datastruct.Float16) == 2
	assert sizeof(datastruct.Split) == 8
	assert sizeof(datastruct.Slot) == 8
	assert sizeof(datastruct.Layout) == 1
	assert u8(datastruct.Layout.horizontal) == 0
	assert u8(datastruct.Layout.vertical) == 1
	assert sizeof(datastruct.Direction) == 1
	assert u8(datastruct.Direction.left) == 0
	assert u8(datastruct.Direction.right) == 1
	assert u8(datastruct.Direction.down) == 2
	assert u8(datastruct.Direction.up) == 3
	assert sizeof(datastruct.Side) == 1
	assert u8(datastruct.Side.left) == 0
	assert u8(datastruct.Side.right) == 1
	assert sizeof(datastruct.SpatialDirection) == 1
	assert u8(datastruct.SpatialDirection.left) == 0
	assert u8(datastruct.SpatialDirection.right) == 1
	assert u8(datastruct.SpatialDirection.down) == 2
	assert u8(datastruct.SpatialDirection.up) == 3
}

fn test_split_tree_float16_rounding() {
	assert u16(datastruct.Float16.from_f32(0.8)) == 0x3a66
	assert datastruct.Float16.from_f32(0.8).f32() == f32(0.7998046875)
	assert u16(datastruct.Float16.from_f32(0.3)) == 0x34cd
	assert datastruct.Float16.from_f32(0.3).f32() == f32(0.300048828125)
	// Round-to-nearest, ties-to-even in both directions.
	assert u16(datastruct.Float16.from_f32(1.00048828125)) == 0x3c00
	assert u16(datastruct.Float16.from_f32(1.00146484375)) == 0x3c02
	assert u16(datastruct.Float16.from_f32(0.00000005960464477539063)) == 0x0001
	assert u16(datastruct.Float16.from_f32(65504)) == 0x7bff
	for raw in 0 .. 65536 {
		value := datastruct.Float16(raw)
		// NaN conversion is permitted to quiet the payload; all finite values
		// and infinities must round-trip bit-for-bit.
		if (raw & 0x7c00) == 0x7c00 && (raw & 0x03ff) != 0 {
			continue
		}
		assert datastruct.Float16.from_f32(value.f32()) == value
	}
}

// TestView is used in tests to implement the required view interface.
pub struct TestView {
	label string
}

pub fn (mut self TestView) ref() &TestView {
	return &TestView{
		label: self.label
	}
}

pub fn (mut self TestView) unref() {
	// No-op with V's GC
}

pub fn (self &TestView) eql(other &TestView) bool {
	return self.label == other.label
}

pub fn (self &TestView) split_tree_label() string {
	return self.label
}

// helper: find a view handle by label
fn find_handle(tree &datastruct.SplitTree[TestView], label string) datastruct.Handle {
	mut it := tree.iterator()
	for {
		entry := it.next() or { break }
		if entry.view.split_tree_label() == label {
			return entry.handle
		}
	}
	panic('view not found: ${label}')
}

fn test_is_split() {
	// Empty tree should not be split
	mut empty := datastruct.SplitTree.empty[TestView]()
	defer {
		empty.free()
	}
	assert !empty.is_split()

	// Single node tree should not be split
	mut v1 := TestView{ label: 'A' }
	mut single := datastruct.SplitTree.new[TestView](&v1)
	defer {
		single.free()
	}
	assert !single.is_split()

	// datastruct.Split tree should be split
	mut v2 := TestView{ label: 'B' }
	mut tree2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		tree2.free()
	}
	mut split := single.split_(datastruct.handle_root, .right, 0.5, &tree2)
	defer {
		split.free()
	}
	assert split.is_split()
}

fn test_empty_tree() {
	mut t := datastruct.SplitTree.empty[TestView]()
	defer {
		t.free()
	}
	assert t.format() == 'empty'
}

fn test_single_node() {
	mut v := TestView{ label: 'A' }
	mut t := datastruct.SplitTree.new[TestView](&v)
	defer {
		t.free()
	}
	expected := '+---+\n| A |\n+---+\n'
	assert t.format_diagram() == expected
}

fn test_split_horizontal() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}
	mut t3 := t1.split_(datastruct.handle_root, .right, 0.5, &t2)
	defer {
		t3.free()
	}

	expected_t3 := '+---++---+\n| A || B |\n+---++---+\nsplit (layout: horizontal, ratio: 0.50)\n  leaf: A\n  leaf: B\n'
	assert t3.format() == expected_t3

	// datastruct.Split right at B
	mut vc := TestView{ label: 'C' }
	mut tc := datastruct.SplitTree.new[TestView](&vc)
	defer {
		tc.free()
	}
	b_handle := find_handle(&t3, 'B')
	mut t4 := t3.split_(b_handle, .right, 0.5, &tc)
	defer {
		t4.free()
	}

	expected_t4 := '+--------++---++---+\n|    A   || B || C |\n+--------++---++---+\nsplit (layout: horizontal, ratio: 0.50)\n  leaf: A\n  split (layout: horizontal, ratio: 0.50)\n    leaf: B\n    leaf: C\n'
	assert t4.format() == expected_t4

	// datastruct.Split right at C
	mut vd := TestView{ label: 'D' }
	mut td := datastruct.SplitTree.new[TestView](&vd)
	defer {
		td.free()
	}
	c_handle := find_handle(&t4, 'C')
	mut t5 := t4.split_(c_handle, .right, 0.5, &td)
	defer {
		t5.free()
	}

	expected_t5 := '+------------------++--------++---++---+\n|         A        ||    B   || C || D |\n+------------------++--------++---++---+\nsplit (layout: horizontal, ratio: 0.50)\n  leaf: A\n  split (layout: horizontal, ratio: 0.50)\n    leaf: B\n    split (layout: horizontal, ratio: 0.50)\n      leaf: C\n      leaf: D\n'
	assert t5.format() == expected_t5

	// Find "previous" from D back.
	mut current := u8(`D`)
	for current != u8(`A`) {
		handle := find_handle(&t5, [current].bytestr())
		prev_handle := t5.goto_(handle, datastruct.GotoPrevious{}) or {
			panic('expected a previous split-tree view')
		}
		prev_entry := t5.nodes[prev_handle.idx()]
		if prev_entry is datastruct.Leaf[TestView] {
			assert prev_entry.view.label == [current - 1].bytestr()
		}
		current -= 1
	}

	// A has no previous
	a_handle := find_handle(&t5, 'A')
	assert t5.goto_(a_handle, datastruct.GotoPrevious{}) == none

	// Find "next" from A forward.
	current = u8(`A`)
	for current != u8(`D`) {
		handle := find_handle(&t5, [current].bytestr())
		next_handle := t5.goto_(handle, datastruct.GotoNext{}) or {
			panic('expected a next split-tree view')
		}
		next_entry := t5.nodes[next_handle.idx()]
		if next_entry is datastruct.Leaf[TestView] {
			assert next_entry.view.label == [current + 1].bytestr()
		}
		current += 1
	}

	// D has no next
	d_handle := find_handle(&t5, 'D')
	assert t5.goto_(d_handle, datastruct.GotoNext{}) == none
}

fn test_split_vertical() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	mut t3 := t1.split_(datastruct.handle_root, .down, 0.5, &t2)
	defer {
		t3.free()
	}

	expected := '+---+\n| A |\n+---+\n+---+\n| B |\n+---+\n'
	assert t3.format_diagram() == expected
}

fn test_split_horizontal_zero_ratio() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	// A | B horizontal with ratio 0
	mut split := t1.split_(datastruct.handle_root, .right, 0, &t2)
	defer {
		split.free()
	}

	expected := '+---+\n| B |\n+---+\n'
	assert split.format_diagram() == expected
}

fn test_split_vertical_zero_ratio() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	mut split := t1.split_(datastruct.handle_root, .down, 0, &t2)
	defer {
		split.free()
	}

	expected := '+---+\n| B |\n+---+\n'
	assert split.format_diagram() == expected
}

fn test_split_horizontal_full_width() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	mut split := t1.split_(datastruct.handle_root, .right, 1, &t2)
	defer {
		split.free()
	}

	expected := '+---+\n| A |\n+---+\n'
	assert split.format_diagram() == expected
}

fn test_split_vertical_full_width() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	mut split := t1.split_(datastruct.handle_root, .down, 1, &t2)
	defer {
		split.free()
	}

	expected := '+---+\n| A |\n+---+\n'
	assert split.format_diagram() == expected
}

fn test_remove_leaf() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}
	mut t3 := t1.split_(datastruct.handle_root, .right, 0.5, &t2)
	defer {
		t3.free()
	}

	// Remove "A"
	a_handle := find_handle(&t3, 'A')
	mut t4 := t3.remove(a_handle)
	defer {
		t4.free()
	}

	expected := '+---+\n| B |\n+---+\n'
	assert t4.format_diagram() == expected
}

fn test_split_twice_remove_intermediary() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}
	mut v3 := TestView{ label: 'C' }
	mut t3 := datastruct.SplitTree.new[TestView](&v3)
	defer {
		t3.free()
	}

	// A | B horizontal
	mut split1 := t1.split_(datastruct.handle_root, .right, 0.5, &t2)
	defer {
		split1.free()
	}

	// Insert C below
	mut split2 := split1.split_(datastruct.handle_root, .down, 0.5, &t3)
	defer {
		split2.free()
	}

	expected_split2 := '+---++---+\n| A || B |\n+---++---+\n+--------+\n|    C   |\n+--------+\n'
	assert split2.format_diagram() == expected_split2

	// Remove "B"
	b_handle := find_handle(&split2, 'B')
	mut split3 := split2.remove(b_handle)
	defer {
		split3.free()
	}

	expected_split3 := '+---+\n| A |\n+---+\n+---+\n| C |\n+---+\n'
	assert split3.format_diagram() == expected_split3

	// Remove every node from split2 (our most complex one), which should
	// never crash. We don't test the result is correct, this just verifies
	// we don't hit any assertion failures.
	for i in 0 .. split2.nodes.len {
		mut removed := split2.remove(datastruct.Handle(i))
		removed.free()
	}
}

fn test_spatial_goto() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}
	mut v3 := TestView{ label: 'C' }
	mut t3 := datastruct.SplitTree.new[TestView](&v3)
	defer {
		t3.free()
	}
	mut v4 := TestView{ label: 'D' }
	mut t4 := datastruct.SplitTree.new[TestView](&v4)
	defer {
		t4.free()
	}

	// A | B horizontal
	mut split_ab := t1.split_(datastruct.handle_root, .right, 0.5, &t2)
	defer {
		split_ab.free()
	}

	// A | C vertical (split A down)
	a_handle_in_ab := find_handle(&split_ab, 'A')
	mut split_ac := split_ab.split_(a_handle_in_ab, .down, 0.8, &t3)
	defer {
		split_ac.free()
	}

	// B | D vertical (split B down)
	b_handle_in_ab := find_handle(&split_ab, 'B')
	mut split_bd := split_ac.split_(b_handle_in_ab, .down, 0.3, &t4)
	defer {
		split_bd.free()
	}
	split := &split_bd
	expected_split := '+---++---+\n|   || B |\n|   |+---+\n|   |+---+\n| A ||   |\n|   ||   |\n|   ||   |\n|   || D |\n+---+|   |\n+---+|   |\n| C ||   |\n+---++---+\n'
	assert split.format_diagram() == expected_split

	// datastruct.Spatial C => right should be D
	c_handle := find_handle(split, 'C')
	target := split.goto_(c_handle, datastruct.GotoSpatial{ direction: .right }) or {
		panic('expected a split-tree view to the right')
	}
	target_node := split.nodes[target.idx()]
	if target_node is datastruct.Leaf[TestView] {
		assert target_node.view.label == 'D'
	} else {
		assert false
	}

	// datastruct.Spatial D => left should be A
	d_handle := find_handle(split, 'D')
	target2 := split.goto_(d_handle, datastruct.GotoSpatial{ direction: .left }) or {
		panic('expected a split-tree view to the left')
	}
	target_node2 := split.nodes[target2.idx()]
	if target_node2 is datastruct.Leaf[TestView] {
		assert target_node2.view.label == 'A'
	} else {
		assert false
	}

	// Equalize
	mut equal := split.equalize()
	defer {
		equal.free()
	}

	expected_eq := '+---++---+\n| A || B |\n+---++---+\n+---++---+\n| C || D |\n+---++---+\n'
	assert equal.format_diagram() == expected_eq
}

fn test_resize() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	// A | B horizontal
	mut split := t1.split_(datastruct.handle_root, .right, 0.5, &t2)
	defer {
		split.free()
	}

	expected_split := '+---++---+\n| A || B |\n+---++---+\n'
	assert split.format_diagram() == expected_split

	// Resize right (+0.25)
	b_handle := find_handle(&split, 'B')
	mut resized := split.resize(b_handle, .horizontal, 0.25)
	defer {
		resized.free()
	}
	expected_resized := '+-------------++---+\n|      A      || B |\n+-------------++---+\n'
	assert resized.format_diagram() == expected_resized

	// Resize the other direction (negative ratio)
	mut resized2 := split.resize(b_handle, .horizontal, -0.25)
	defer {
		resized2.free()
	}
	expected_resized2 := '+---++-------------+\n| A ||      B      |\n+---++-------------+\n'
	assert resized2.format_diagram() == expected_resized2
}

fn test_clone_empty_tree() {
	mut t := datastruct.SplitTree.empty[TestView]()
	defer {
		t.free()
	}

	mut t2 := t.clone()
	defer {
		t2.free()
	}

	assert t2.format() == 'empty'
}

fn test_zoom() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	// A | B horizontal
	mut split := t1.split_(datastruct.handle_root, .right, 0.5, &t2)
	defer {
		split.free()
	}
	b_handle := find_handle(&split, 'B')
	split.zoom(b_handle)

	expected_text := 'split (layout: horizontal, ratio: 0.50)\n  leaf: A\n  (zoomed) leaf: B\n'
	assert split.format_text() == expected_text

	// Clone preserves zoom
	mut cloned := split.clone()
	defer {
		cloned.free()
	}
	assert cloned.format_text() == expected_text
}

fn test_split_resets_zoom() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	// Zoom A
	a_handle := find_handle(&t1, 'A')
	t1.zoom(a_handle)

	// A | B horizontal
	mut split := t1.split_(datastruct.handle_root, .right, 0.5, &t2)
	defer {
		split.free()
	}

	// Splitting resets zoom
	expected_text := 'split (layout: horizontal, ratio: 0.50)\n  leaf: A\n  leaf: B\n'
	assert split.format_text() == expected_text
}

fn test_remove_and_zoom() {
	mut v1 := TestView{ label: 'A' }
	mut t1 := datastruct.SplitTree.new[TestView](&v1)
	defer {
		t1.free()
	}
	mut v2 := TestView{ label: 'B' }
	mut t2 := datastruct.SplitTree.new[TestView](&v2)
	defer {
		t2.free()
	}

	// A | B horizontal
	mut split := t1.split_(datastruct.handle_root, .right, 0.5, &t2)
	defer {
		split.free()
	}
	a_handle := find_handle(&split, 'A')
	split.zoom(a_handle)

	// Remove A, should unzoom
	mut removed_a := split.remove(a_handle)
	defer {
		removed_a.free()
	}
	assert removed_a.zoomed == none
	assert removed_a.format_text() == 'leaf: B\n'

	// Remove B, should keep zoom on A
	b_handle := find_handle(&split, 'B')
	mut removed_b := split.remove(b_handle)
	defer {
		removed_b.free()
	}
	assert removed_b.format_text() == '(zoomed) leaf: A\n'
}
