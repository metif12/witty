module datastruct

import math
import strings

// SplitTree represents a tree of view types that can be divided.
//
// Concretely for Ghostty, it represents a tree of terminal views. In
// its basic state, there are no splits and it is a single full-sized
// terminal. However, it can be split arbitrarily many times among two
// axes (horizontal and vertical) to create a tree of terminal views.
//
// This is an immutable tree structure, meaning all operations on it
// will return a new tree with the operation applied. This allows us to
// store versions of the tree in a history for easy undo/redo.
//
// The View type T must implement the following methods:
//
//   - fn ref(mut self) &T - Increase a reference count of the view.
//     The returned value is expected to be a new reference (but that
//     may just be a copy).
//
//   - fn unref(mut self) - Decrease the reference count of a view.
//
//   - fn eql(self &T, other &T) bool - Check if two views are equal.
//
// Optionally, T may implement:
//
//   - fn split_tree_label(self &T) string - Return a label that is
//     used for the debug view. Without it, the node handle is used.
pub struct SplitTree[T] {
pub mut:
	// All the nodes in the tree. Node at index 0 is always the root.
	nodes []Node[T]
	// The handle of the zoomed node. A "zoomed" node is one that is
	// expected to be made the full size of the split tree. Various
	// operations may unzoom (e.g. resize).
	zoomed ?Handle
}

// Node is either a leaf (containing a view) or a split (dividing space).
pub type Node[T] = Leaf[T] | Split

// Handle is a compact index into the nodes array. Ghostty deliberately keeps
// split-tree references at 16 bits rather than widening them to pointer-sized
// integers.
pub type Handle = u16

// handle_root is the handle for the root node (index 0).
pub const handle_root = Handle(0)

pub fn (handle Handle) idx() int {
	return int(u16(handle))
}

// offset advances a handle while retaining Ghostty's reserved maximum value.
pub fn (handle Handle) offset(value usize) Handle {
	final := usize(u16(handle)) + value
	assert final < usize(65535)
	return Handle(final)
}

// Float16 retains the exact IEEE-754 binary16 values used by Ghostty's split
// ratios and spatial calculations. V has no f16 primitive, so arithmetic is
// performed through an exact wider value and rounded back to binary16 after
// every operation.
pub type Float16 = u16

pub fn Float16.from_f32(value f32) Float16 {
	return Float16.from_f64(f64(value))
}

fn Float16.from_f64(value f64) Float16 {
	bits := math.f64_bits(value)
	sign := u16((bits >> 48) & 0x8000)
	exponent := int((bits >> 52) & 0x7ff)
	mantissa := bits & 0x000fffffffffffff

	if exponent == 0x7ff {
		if mantissa == 0 {
			return Float16(sign | 0x7c00)
		}
		// Preserve the payload and ensure a NaN never rounds into infinity.
		mut payload := u16(mantissa >> 42)
		if payload == 0 {
			payload = 1
		}
		return Float16(sign | 0x7c00 | payload)
	}

	half_exponent := exponent - 1023 + 15
	if half_exponent >= 31 {
		return Float16(sign | 0x7c00)
	}
	if half_exponent <= 0 {
		if half_exponent < -10 {
			return Float16(sign)
		}
		value_mantissa := mantissa | (u64(1) << 52)
		shift := u32(43 - half_exponent)
		mut half_mantissa := value_mantissa >> shift
		remainder_mask := (u64(1) << shift) - 1
		remainder := value_mantissa & remainder_mask
		halfway := u64(1) << (shift - 1)
		if remainder > halfway || (remainder == halfway && (half_mantissa & 1) != 0) {
			half_mantissa++
		}
		return Float16(sign | u16(half_mantissa))
	}

	mut rounded := (u64(half_exponent) << 10) | (mantissa >> 42)
	remainder := mantissa & ((u64(1) << 42) - 1)
	halfway := u64(1) << 41
	if remainder > halfway || (remainder == halfway && (rounded & 1) != 0) {
		rounded++
	}
	return Float16(sign | u16(rounded))
}

pub fn (value Float16) f32() f32 {
	bits := u16(value)
	sign := u32(bits & 0x8000) << 16
	exponent := u32((bits >> 10) & 0x1f)
	mut mantissa := u32(bits & 0x03ff)

	if exponent == 0 {
		if mantissa == 0 {
			return math.f32_from_bits(sign)
		}
		mut unbiased := -14
		for (mantissa & 0x0400) == 0 {
			mantissa <<= 1
			unbiased--
		}
		mantissa &= 0x03ff
		return math.f32_from_bits(sign | (u32(unbiased + 127) << 23) | (mantissa << 13))
	}
	if exponent == 0x1f {
		return math.f32_from_bits(sign | 0x7f800000 | (mantissa << 13))
	}
	return math.f32_from_bits(sign | ((exponent + 112) << 23) | (mantissa << 13))
}

fn (left Float16) add(right Float16) Float16 {
	return Float16.from_f64(f64(left.f32()) + f64(right.f32()))
}

fn (left Float16) sub(right Float16) Float16 {
	return Float16.from_f64(f64(left.f32()) - f64(right.f32()))
}

fn (left Float16) mul(right Float16) Float16 {
	return Float16.from_f64(f64(left.f32()) * f64(right.f32()))
}

fn (left Float16) div(right Float16) Float16 {
	return Float16.from_f64(f64(left.f32()) / f64(right.f32()))
}

fn (value Float16) sqrt() Float16 {
	return Float16.from_f64(math.sqrt(f64(value.f32())))
}

// Leaf node containing a view.
pub struct Leaf[T] {
pub mut:
	view &T
}

// Split node dividing space between two children.
pub struct Split {
pub:
	// The layout direction of this split.
	layout Layout
	// The ratio of space given to the left/top child.
	ratio Float16
	// Handle (index) of the left/top child.
	left Handle
	// Handle (index) of the right/bottom child.
	right Handle
}

// Layout direction for a split.
pub enum Layout as u8 {
	horizontal
	vertical
}

// Direction for split operations.
pub enum Direction as u8 {
	left
	right
	down
	up
}

// Side of a tree (left or right).
pub enum Side as u8 {
	left
	right
}

// SpatialDirection for spatial navigation.
pub enum SpatialDirection as u8 {
	left
	right
	down
	up
}

// Goto specifies how to navigate from a node.
pub type Goto = GotoPrevious | GotoNext | GotoPreviousWrapped | GotoNextWrapped | GotoSpatial

// GotoPrevious - previous view, none if we're the first view.
pub struct GotoPrevious {}

// GotoNext - next view, none if we're the last view.
pub struct GotoNext {}

// GotoPreviousWrapped - previous view, but wrapped around to the last view.
// May return the same view if this is the first view.
pub struct GotoPreviousWrapped {}

// GotoNextWrapped - next view, but wrapped around to the first view.
// May return the same view if this is the last view.
pub struct GotoNextWrapped {}

// GotoSpatial - a spatial direction. "Spatial" means that the direction is
// based on the nearest surface in the given direction visually
// as the surfaces are laid out on a 2D grid.
pub struct GotoSpatial {
pub:
	direction SpatialDirection
}

// ViewEntry pairs a handle with its view.
pub struct ViewEntry[T] {
pub:
	handle Handle
	view   &T
}

// SplitTreeIterator iterates over all the views in the tree.
pub struct SplitTreeIterator[T] {
mut:
	i Handle
pub:
	nodes []Node[T]
}

// Spatial representation of the split tree.
//
// The bounds of the representation are always based on the total
// 2D space being 1x1. The x/y coordinates and width/height dimensions
// of each individual split and leaf are relative to this.
// This means that the spatial representation is a normalized
// representation of the actual space.
//
// We use a normalized form because we can calculate it without
// access to the actual rendered view sizes. These actual sizes
// may not be available at various times because GUI toolkits often
// only make them available once they're part of a widget tree and
// a SplitTree can represent views that aren't currently visible.
//
// The top-left corner of the tree is always (0, 0).
pub struct Spatial {
pub:
	// The slots of the spatial representation in the same order
	// as the tree it was created from.
	slots []Slot
}

// Slot represents the position and size of a node in spatial coordinates.
pub struct Slot {
pub mut:
	x      Float16
	y      Float16
	width  Float16
	height Float16
}

// max_x returns the right edge of the slot.
fn (s &Slot) max_x() Float16 {
	return s.x.add(s.width)
}

// max_y returns the bottom edge of the slot.
fn (s &Slot) max_y() Float16 {
	return s.y.add(s.height)
}

// --- Internal types ---

// Design note: we use a recursive backtracking search because
// split trees are never that deep, so we can abuse the stack as
// a safe allocator (stack overflow unlikely unless the kernel is
// tuned in some really weird way).
type Backtrack = BacktrackDeadend | BacktrackBacktrack | BacktrackResult

struct BacktrackDeadend {}

struct BacktrackBacktrack {}

struct BacktrackResult {
	handle Handle
}

struct Dimensions {
	width  u16
	height u16
}

// --- SplitTree methods ---

// empty returns an empty split tree with no nodes.
pub fn SplitTree.empty[T]() SplitTree[T] {
	return SplitTree[T]{}
}

// new creates a new tree with a single view.
pub fn SplitTree.new[T](view &T) SplitTree[T] {
	mut v := unsafe { view }
	reffed := v.ref()
	mut nodes := []Node[T]{cap: 1}
	nodes << Leaf[T]{
		view: reffed
	}
	return SplitTree[T]{
		nodes:  nodes
		zoomed: none
	}
}

// free releases all view references in the tree.
pub fn (mut self SplitTree[T]) free() {
	// Important: only free memory if we have memory to free,
	// because we use an undefined state for empty trees.
	if self.nodes.len > 0 {
		// Unref all our views
		for mut node in self.nodes {
			if mut node is Leaf[T] {
				node.view.unref()
			}
		}
	}
	self.nodes = []Node[T]{}
	self.zoomed = none
}

// clone returns a new tree with the same nodes and incremented view references.
pub fn (self &SplitTree[T]) clone() SplitTree[T] {
	// If we're empty then return an empty tree.
	if self.is_empty() {
		return SplitTree.empty[T]()
	}

	// Copy the nodes array.
	mut nodes := self.nodes.clone()

	// Increase the reference count of all the views in the nodes.
	ref_nodes[T](mut nodes)

	return SplitTree[T]{
		nodes:  nodes
		zoomed: self.zoomed
	}
}

// is_empty returns true if this is an empty tree.
pub fn (self &SplitTree[T]) is_empty() bool {
	// An empty tree has no nodes.
	return self.nodes.len == 0
}

// is_split returns true if this tree has more than one split (i.e., the root
// is a split node). This is useful for determining if actions like
// resize_split or toggle_split_zoom are performable.
pub fn (self &SplitTree[T]) is_split() bool {
	// An empty tree is not split.
	if self.is_empty() {
		return false
	}
	// The root node is at index 0. If it's a split, we have multiple splits.
	return self.nodes[0] is Split
}

// iterator returns an iterator over all the views in the tree.
pub fn (self &SplitTree[T]) iterator() SplitTreeIterator[T] {
	return SplitTreeIterator[T]{
		i:     handle_root
		nodes: self.nodes
	}
}

// next returns the next ViewEntry from the iterator, or none.
pub fn (mut self SplitTreeIterator[T]) next() ?ViewEntry[T] {
	// Skip split nodes, only return leaves.
	for Handle(self.i).idx() < self.nodes.len {
		handle := self.i
		node := self.nodes[Handle(self.i).idx()]
		// The iterator is allowed to advance to the reserved maximum value as
		// its end sentinel; Handle.offset intentionally rejects that value.
		self.i = Handle(u16(self.i) + 1)
		if node is Leaf[T] {
			return ViewEntry[T]{
				handle: handle
				view:   node.view
			}
		}
	}
	return none
}

// zoom changes the zoomed state to the given node handle. None unzooms.
// Assumes a present handle is valid.
pub fn (mut self SplitTree[T]) zoom(handle ?Handle) {
	if value := handle {
		assert value.idx() < self.nodes.len
	}
	self.zoomed = handle
}

// goto_ navigates from a node in the split tree. Returns none if the direction
// results in no visitable view.
//
// The name uses trailing underscore to avoid conflict with V keyword.
pub fn (self &SplitTree[T]) goto_(from Handle, to Goto) ?Handle {
	match to {
		GotoPrevious {
			return self.previous(from)
		}
		GotoNext {
			return self.next_node(from)
		}
		GotoPreviousWrapped {
			if prev := self.previous(from) {
				return prev
			}
			return self.deepest(.right, handle_root)
		}
		GotoNextWrapped {
			if next := self.next_node(from) {
				return next
			}
			return self.deepest(.left, handle_root)
		}
		GotoSpatial {
			// Get our spatial representation.
			sp := self.spatial()
			return self.nearest(sp, from, to.direction)
		}
	}
}

// deepest returns the deepest view in the tree in the given direction.
// This can be used to find the leftmost/rightmost surface within
// a given split structure.
pub fn (self &SplitTree[T]) deepest(side Side, from Handle) Handle {
	mut current := from
	for {
		node := self.nodes[current.idx()]
		if node is Split {
			current = match side {
				.left { node.left }
				.right { node.right }
			}
		} else {
			return current
		}
	}
	return current // unreachable
}

// previous returns the previous view from the given node handle.
// Returns none if there is no previous (this is the first view).
//
// "Previous" is defined as the previous node in an in-order
// traversal of the tree.
fn (self &SplitTree[T]) previous(from Handle) ?Handle {
	result := self.previous_backtrack(from, handle_root)
	if result is BacktrackResult {
		return result.handle
	}
	return none
}

// next_node returns the next view from the given node handle.
// Returns none if there is no next (this is the last view).
fn (self &SplitTree[T]) next_node(from Handle) ?Handle {
	result := self.next_backtrack(from, handle_root)
	if result is BacktrackResult {
		return result.handle
	}
	return none
}

fn (self &SplitTree[T]) previous_backtrack(from Handle, current Handle) Backtrack {
	// If we reached the point that we're trying to find the previous
	// value of, then we need to backtrack from here.
	if from == current {
		return BacktrackBacktrack{}
	}

	node := self.nodes[current.idx()]
	if node is Split {
		left_result := self.previous_backtrack(from, node.left)
		if left_result is BacktrackResult {
			return left_result
		}
		if left_result is BacktrackBacktrack {
			// Backtrack from the left means we have to continue
			// backtracking because we can't see what's before the left.
			return BacktrackBacktrack{}
		}
		// Deadend on the left, try right.
		right_result := self.previous_backtrack(from, node.right)
		if right_result is BacktrackResult {
			return right_result
		}
		if right_result is BacktrackDeadend {
			// Deadend means it's not in this split at all since
			// we already tracked the left.
			return BacktrackDeadend{}
		}
		// Backtrack from right means the previous is in our left view
		// because we can see the immediate previous and there MUST
		// be leaves (we can't have split-only leaves).
		return BacktrackResult{
			handle: self.deepest(.right, node.left)
		}
	}
	// Leaf that isn't our target, deadend.
	return BacktrackDeadend{}
}

// See previous_backtrack for detailed comments. This is a mirror of that.
fn (self &SplitTree[T]) next_backtrack(from Handle, current Handle) Backtrack {
	if from == current {
		return BacktrackBacktrack{}
	}
	node := self.nodes[current.idx()]
	if node is Split {
		right_result := self.next_backtrack(from, node.right)
		if right_result is BacktrackResult {
			return right_result
		}
		if right_result is BacktrackBacktrack {
			return BacktrackBacktrack{}
		}
		left_result := self.next_backtrack(from, node.left)
		if left_result is BacktrackResult {
			return left_result
		}
		if left_result is BacktrackDeadend {
			return BacktrackDeadend{}
		}
		return BacktrackResult{
			handle: self.deepest(.left, node.right)
		}
	}
	return BacktrackDeadend{}
}

// nearest returns the nearest leaf node (view) in the given direction.
fn (self &SplitTree[T]) nearest(sp Spatial, from Handle, direction SpatialDirection) ?Handle {
	target := sp.slots[from.idx()]

	mut best_handle := ?Handle(none)
	mut best_distance := Float16(0)

	for handle in 0 .. sp.slots.len {
		// Never match ourself
		candidate := Handle(handle)
		if candidate == from {
			continue
		}
		// Only match leaves
		if self.nodes[handle] is Split {
			continue
		}

		slot := sp.slots[handle]

		// Ensure it is in the proper direction
		in_direction := match direction {
			.left { slot.max_x().f32() <= target.x.f32() }
			.right { slot.x.f32() >= target.max_x().f32() }
			.up { slot.max_y().f32() <= target.y.f32() }
			.down { slot.y.f32() >= target.max_y().f32() }
		}
		if !in_direction {
			continue
		}

		// Track our distance
		dx := slot.x.sub(target.x)
		dy := slot.y.sub(target.y)
		distance := dx.mul(dx).add(dy.mul(dy)).sqrt()

		// If we have a nearest it must be closer.
		if best_handle != none {
			if distance.f32() >= best_distance.f32() {
				continue
			}
		}
		best_handle = candidate
		best_distance = distance
	}

	return best_handle
}

// resize_in_place resizes the given node in place. The node MUST be a split.
//
// In general, this is an immutable data structure so this is
// heavily discouraged. However, this is provided for convenience
// and performance reasons where it's very important for GUIs to
// update the ratio during a live resize than to redraw the entire
// widget tree.
pub fn (mut self SplitTree[T]) resize_in_place(at Handle, ratio f32) {
	node := self.nodes[at.idx()]
	if node is Split {
		self.nodes[at.idx()] = Node[T](Split{
			layout: node.layout
			ratio:  Float16.from_f32(ratio)
			left:   node.left
			right:  node.right
		})
	} else {
		panic('split-tree resize target must be a split')
	}
}

// split_ inserts another tree into this tree at the given node in the
// specified direction. The other tree will be inserted in the new direction.
// For example, if the direction is "right" then `insert` is inserted right
// of the existing node.
//
// The previous trees will not be freed, but reference counts
// for the views will be increased accordingly for the new tree.
pub fn (self &SplitTree[T]) split_(at Handle, direction Direction, ratio f32, insert &SplitTree[T]) SplitTree[T] {
	// We need sum total of nodes between the two trees plus one for the new split node.
	total := self.nodes.len + insert.nodes.len + 1
	assert(total <= 65535) // fits in u16

	mut nodes := []Node[T]{cap: total}

	// We can copy our nodes exactly as they are, since they're
	// mostly not changing (only `at` is changing).
	for node in self.nodes {
		nodes << node
	}

	// We can copy the destination nodes as well directly next to
	// the source nodes. We just have to go through and offset
	// all the handles in the destination tree to account for the shift.
	for node in insert.nodes {
		if node is Split {
			nodes << Node[T](Split{
				layout: node.layout
				ratio:  node.ratio
				left:   node.left.offset(usize(self.nodes.len))
				right:  node.right.offset(usize(self.nodes.len))
			})
		} else {
			nodes << node
		}
	}

	// Determine our split layout and if we're on the left
	mut layout := Layout.horizontal
	mut is_left := false
	match direction {
		.left {
			layout = .horizontal
			is_left = true
		}
		.right {
			layout = .horizontal
			is_left = false
		}
		.up {
			layout = .vertical
			is_left = true
		}
		.down {
			layout = .vertical
			is_left = false
		}
	}

	// Copy our previous value to the end of the nodes list and
	// create our new split node.
	nodes << nodes[at.idx()]
	last := Handle(nodes.len - 1)
	insert_root := Handle(self.nodes.len)
	nodes[at.idx()] = Node[T](Split{
		layout: layout
		ratio:  Float16.from_f32(ratio)
		left:   if is_left { insert_root } else { last }
		right:  if is_left { last } else { insert_root }
	})

	// We need to increase the reference count of all the nodes.
	ref_nodes[T](mut nodes)

	return SplitTree[T]{
		nodes: nodes
		// Splitting always resets zoom state.
		zoomed: none
	}
}

// remove removes a node from the tree.
pub fn (self &SplitTree[T]) remove(at Handle) SplitTree[T] {
	assert at.idx() < self.nodes.len

	// If we're removing node zero then we're clearing the tree.
	if at == handle_root {
		return SplitTree.empty[T]()
	}

	// Count nodes needed after the removal.
	count := self.count_after_removal(handle_root, at, 0)

	// Pre-allocate nodes with dummy values. We use a helper to construct
	// the sum-type value because V's generics can't infer the element type
	// when casting `Node[T](Split{})` directly inside the `init:` field.
	mut new_nodes := []Node[T]{len: int(count), init: empty_node[T]()}
	mut result := SplitTree[T]{
		nodes:  new_nodes
		zoomed: none
	}

	// Traverse the tree and copy all our nodes into place.
	written := remove_node_impl[T](self, mut result, 0, handle_root, at)
	assert(written != 0)

	// Increase the reference count of all the nodes.
	ref_nodes[T](mut result.nodes)

	return result
}

fn remove_node_impl[T](old &SplitTree[T], mut new_tree SplitTree[T], new_offset usize, current Handle, target Handle) usize {
	assert(current != target)

	// If we have a zoomed node and this is it then we migrate it.
	if zoomed := old.zoomed {
		if zoomed == current {
			assert new_tree.zoomed == none
			new_tree.zoomed = Handle(new_offset)
		}
	}

	node := old.nodes[current.idx()]
	if node is Split {
		// If we're removing one of the split node sides then
		// we remove the split node itself as well and only add
		// the other (non-removed) side.
		if node.left == target {
			return remove_node_impl[T](old, mut new_tree, new_offset, node.right, target)
		}
		if node.right == target {
			return remove_node_impl[T](old, mut new_tree, new_offset, node.left, target)
		}

		// Neither side is being directly removed, so we traverse.
		left_count := remove_node_impl[T](old, mut new_tree, new_offset + 1, node.left, target)
		assert(left_count != 0)
		right_count := remove_node_impl[T](old, mut new_tree, new_offset + left_count + 1, node.right,
			target)
		assert(right_count != 0)
		new_tree.nodes[int(new_offset)] = Node[T](Split{
			layout: node.layout
			ratio:  node.ratio
			left:   Handle(new_offset + 1)
			right:  Handle(new_offset + 1 + left_count)
		})
		return left_count + right_count + 1
	}
	if node is Leaf[T] {
		// Leaf is simple, just copy it over. We don't ref anything
		// yet because it'd make undo harder. We do that all at once later.
		new_tree.nodes[int(new_offset)] = Node[T](Leaf[T]{ view: node.view })
		return 1
	}
	return 0 // unreachable
}

// count_after_removal returns the number of nodes that would be needed
// to store the tree if the target node is removed.
fn (self &SplitTree[T]) count_after_removal(current Handle, target Handle, acc usize) usize {
	assert(current != target)

	node := self.nodes[current.idx()]
	if node is Leaf[T] {
		// Leaf is simple, always takes one node.
		return acc + 1
	}
	if node is Split {
		// Split is slightly more complicated. If either side is the
		// target to remove, then we remove the split node as well
		// so our count is just the count of the other side.
		//
		// If neither side is the target, then we count both sides
		// and add one to account for the split node itself.
		if node.left == target {
			return self.count_after_removal(node.right, target, acc)
		}
		if node.right == target {
			return self.count_after_removal(node.left, target, acc)
		}
		left := self.count_after_removal(node.left, target, 0)
		right := self.count_after_removal(node.right, target, 0)
		return acc + left + right + 1
	}
	return acc // unreachable
}

// empty_node returns a placeholder Node[T] used to pre-fill node arrays
// before they are overwritten during a tree traversal. We need this helper
// because V's generics can't infer the element type when casting
// `Node[T](Split{})` directly inside an array's `init:` field.
fn empty_node[T]() Node[T] {
	return Split{}
}

// ref_nodes increases reference count of all views in the nodes slice.
// This should be called LAST so you don't have to undo the refs.
fn ref_nodes[T](mut nodes []Node[T]) {
	// We need to increase the reference count of all the nodes.
	for i in 0 .. nodes.len {
		mut node := nodes[i]
		if mut node is Leaf[T] {
			reffed := node.view.ref()
			nodes[i] = Node[T](Leaf[T]{ view: reffed })
		}
	}
}

// equalize adjusts all splits so that each split's ratio is based on
// the relative weight (number of leaves) of its children.
pub fn (self &SplitTree[T]) equalize() SplitTree[T] {
	if self.is_empty() {
		return SplitTree.empty[T]()
	}

	// Copy the nodes array.
	mut nodes := self.nodes.clone()

	// Go through and equalize our ratios based on weights.
	for i in 0 .. nodes.len {
		node := nodes[i]
		if node is Split {
			weight_left := self.weight(node.left, node.layout, 0)
			weight_right := self.weight(node.right, node.layout, 0)
			assert(weight_left > 0)
			assert(weight_right > 0)
			total_f := f32(weight_left + weight_right)
			weight_left_f := Float16.from_f32(f32(weight_left))
			total_f16 := Float16.from_f32(total_f)
			nodes[i] = Node[T](Split{
				layout: node.layout
				ratio:  Float16(weight_left_f).div(total_f16)
				left:   node.left
				right:  node.right
			})
		}
	}

	// Increase the reference count of all the views in the nodes.
	ref_nodes[T](mut nodes)

	return SplitTree[T]{
		nodes:  nodes
		zoomed: self.zoomed
	}
}

fn (self &SplitTree[T]) weight(from Handle, layout Layout, acc usize) usize {
	node := self.nodes[from.idx()]
	if node is Leaf[T] {
		return acc + 1
	}
	if node is Split {
		if node.layout == layout {
			return self.weight(node.left, layout, acc) +
				self.weight(node.right, layout, acc)
		}
		return 1
	}
	return acc // unreachable
}

// resize resizes the nearest split matching the layout by the given ratio.
// Positive is right and down.
//
// The ratio is a signed delta representing the percentage to move
// the divider. The percentage is of the entire grid size, not just
// the specific split size.
// We use the entire grid size because that's what Ghostty's
// `resize_split` keybind does, because it maps to a general human
// understanding of moving a split relative to the entire window
// (generally).
//
// For example, a ratio of 0.1 and a layout of `vertical` will find
// the nearest vertical split and move the divider down by 10% of
// the total grid height.
//
// If no matching split is found, this does nothing, but will always
// still return a cloned tree.
pub fn (self &SplitTree[T]) resize(from Handle, layout Layout, ratio f32) SplitTree[T] {
	ratio_f16 := Float16.from_f32(ratio)
	ratio_value := Float16(ratio_f16).f32()
	assert(ratio_value >= -1 && ratio_value <= 1)
	assert(!math.is_nan(f64(ratio_value)))
	assert(!math.is_inf(f64(ratio_value), 0))

	// Fast path empty trees.
	if self.is_empty() {
		return SplitTree.empty[T]()
	}

	// From this point forward worst case we return a clone.
	mut result := self.clone()

	// Find our nearest parent split node matching the layout.
	parent_result := self.find_parent_split(layout, from, handle_root)
	parent_handle := if parent_result is BacktrackResult {
		parent_result.handle
	} else {
		return result
	}

	// Get our spatial layout, because we need the dimensions of this
	// split with regards to the entire grid.
	sp := result.spatial()

	// Get the ratio of the split relative to the full grid.
	// Our scale is the amount we need to multiply our individual
	// ratio by to get the full ratio. It's actually a ratio on its
	// own but I'm trying to avoid that word: it's the ratio of
	// our spatial width/height to the total.
	scale := match layout {
		.horizontal { sp.slots[Handle(parent_handle).idx()].width.div(sp.slots[0].width) }
		.vertical { sp.slots[Handle(parent_handle).idx()].height.div(sp.slots[0].height) }
	}

	parent_node := result.nodes[Handle(parent_handle).idx()]
	current_ratio := if parent_node is Split {
		parent_node.ratio
	} else {
		Float16.from_f32(0.5) // should not happen
	}
	full_ratio := Float16(current_ratio).mul(scale)

	// Set the final new ratio, clamping it to [0, 1]
	new_ratio := math.min(math.max(full_ratio.add(ratio_f16).f32(), f32(0)), f32(1))
	result.resize_in_place(parent_handle, new_ratio)
	return result
}

fn (self &SplitTree[T]) find_parent_split(layout Layout, from Handle, current Handle) Backtrack {
	if from == current {
		return BacktrackBacktrack{}
	}
	node := self.nodes[current.idx()]
	if node is Split {
		left_result := self.find_parent_split(layout, from, node.left)
		if left_result is BacktrackResult {
			return left_result
		}
		if left_result is BacktrackBacktrack {
			if node.layout == layout {
				return BacktrackResult{ handle: current }
			}
			return BacktrackBacktrack{}
		}
		// Deadend on left, try right
		right_result := self.find_parent_split(layout, from, node.right)
		if right_result is BacktrackResult {
			return right_result
		}
		if right_result is BacktrackDeadend {
			return BacktrackDeadend{}
		}
		// Backtrack from right
		if node.layout == layout {
			return BacktrackResult{ handle: current }
		}
		return BacktrackBacktrack{}
	}
	return BacktrackDeadend{}
}

// spatial returns a spatial representation of the split tree.
//
// The bounds of the representation are always based on the total
// 2D space being 1x1.
pub fn (self &SplitTree[T]) spatial() Spatial {
	// No nodes, empty spatial representation.
	if self.nodes.len == 0 {
		return Spatial{ slots: []Slot{} }
	}

	// Get our total dimensions.
	dim := self.dimensions(handle_root)

	// Create our slots which will match our nodes exactly.
	mut slots := []Slot{len: self.nodes.len}
	slots[0] = Slot{
		x:      Float16.from_f32(0)
		y:      Float16.from_f32(0)
		width:  Float16.from_f32(f32(dim.width))
		height: Float16.from_f32(f32(dim.height))
	}
	self.fill_spatial_slots(mut slots, handle_root)

	// Normalize the dimensions to 1x1 grid.
	for i in 0 .. slots.len {
		width := Float16.from_f32(f32(dim.width))
		height := Float16.from_f32(f32(dim.height))
		slots[i].x = slots[i].x.div(width)
		slots[i].y = slots[i].y.div(height)
		slots[i].width = slots[i].width.div(width)
		slots[i].height = slots[i].height.div(height)
	}

	return Spatial{ slots: slots }
}

fn (self &SplitTree[T]) fill_spatial_slots(mut slots []Slot, current Handle) {
	assert(slots[current.idx()].width.f32() >= 0 && slots[current.idx()].height.f32() >= 0)
	node := self.nodes[current.idx()]
	if node is Split {
		current_idx := current.idx()
		left_idx := node.left.idx()
		right_idx := node.right.idx()
		match node.layout {
			.horizontal {
				slots[left_idx] = Slot{
					x:      slots[current_idx].x
					y:      slots[current_idx].y
					width:  slots[current_idx].width.mul(node.ratio)
					height: slots[current_idx].height
				}
				slots[right_idx] = Slot{
					x:      slots[current_idx].x.add(slots[current_idx].width.mul(node.ratio))
					y:      slots[current_idx].y
					width:  slots[current_idx].width.mul(Float16.from_f32(1).sub(node.ratio))
					height: slots[current_idx].height
				}
			}
			.vertical {
				slots[left_idx] = Slot{
					x:      slots[current_idx].x
					y:      slots[current_idx].y
					width:  slots[current_idx].width
					height: slots[current_idx].height.mul(node.ratio)
				}
				slots[right_idx] = Slot{
					x:      slots[current_idx].x
					y:      slots[current_idx].y.add(slots[current_idx].height.mul(node.ratio))
					width:  slots[current_idx].width
					height: slots[current_idx].height.mul(Float16.from_f32(1).sub(node.ratio))
				}
			}
		}
		self.fill_spatial_slots(mut slots, node.left)
		self.fill_spatial_slots(mut slots, node.right)
	}
	// Leaf node: current slot is already filled by caller.
}

// dimensions gets the dimensions of the tree starting from the given node.
//
// This creates relative dimensions (see Spatial) by assuming each
// leaf is exactly 1x1 unit in size.
fn (self &SplitTree[T]) dimensions(current Handle) Dimensions {
	node := self.nodes[current.idx()]
	if node is Split {
		left := self.dimensions(node.left)
		right := self.dimensions(node.right)
		return match node.layout {
			.horizontal {
				Dimensions{
					width:  left.width + right.width
					height: math.max(left.height, right.height)
				}
			}
			.vertical {
				Dimensions{
					width:  math.max(left.width, right.width)
					height: left.height + right.height
				}
			}
		}
	}
	return Dimensions{ width: 1, height: 1 }
}

// --- Format methods ---

// format returns a human-readable representation of the tree.
// By default this outputs a diagram followed by a textual representation.
pub fn (self &SplitTree[T]) format() string {
	if self.nodes.len == 0 {
		return 'empty'
	}
	diagram := self.format_diagram()
	text := self.format_text()
	return diagram + text
}

// format_text returns a textual representation of the tree.
pub fn (self &SplitTree[T]) format_text() string {
	if self.nodes.len == 0 {
		return 'empty'
	}
	mut sb := strings.new_builder(256)
	self.format_text_inner(mut sb, handle_root, 0)
	return sb.str()
}

fn (self &SplitTree[T]) format_text_inner(mut sb strings.Builder, current Handle, depth usize) {
	for _ in 0 .. depth {
		sb.write_string('  ')
	}

	if zoomed := self.zoomed {
		if zoomed == current {
			sb.write_string('(zoomed) ')
		}
	}

	node := self.nodes[current.idx()]
	if node is Split {
		layout_str := match node.layout {
			.horizontal { 'horizontal' }
			.vertical { 'vertical' }
		}
		sb.write_string('split (layout: ${layout_str}, ratio: ${node.ratio.f32():.2f})\n')
		self.format_text_inner(mut sb, node.left, depth + 1)
		self.format_text_inner(mut sb, node.right, depth + 1)
	} else if node is Leaf[T] {
		sb.write_string('leaf: ${view_label[T](node.view, current)}\n')
	}
}

// format_diagram returns an ASCII art diagram of the tree.
pub fn (self &SplitTree[T]) format_diagram() string {
	if self.nodes.len == 0 {
		return 'empty'
	}

	// Get our spatial representation.
	sp := self.spatial()

	// Scale our spatial representation to have minimum width/height 1.
	mut min_w := Float16.from_f32(1)
	mut min_h := Float16.from_f32(1)
	for slot in sp.slots {
		if slot.width.f32() > 0 {
			min_w = if min_w.f32() < slot.width.f32() { min_w } else { slot.width }
		}
		if slot.height.f32() > 0 {
			min_h = if min_h.f32() < slot.height.f32() { min_h } else { slot.height }
		}
	}
	ratio_w := Float16.from_f32(1).div(min_w)
	ratio_h := Float16.from_f32(1).div(min_h)

	mut scaled_slots := []Slot{len: sp.slots.len}
	for i in 0 .. sp.slots.len {
		scaled_slots[i] = Slot{
			x:      sp.slots[i].x.mul(ratio_w)
			y:      sp.slots[i].y.mul(ratio_h)
			width:  sp.slots[i].width.mul(ratio_w)
			height: sp.slots[i].height.mul(ratio_h)
		}
	}

	// The width we need for the largest label.
	mut max_label_width := 0
	for handle, node in self.nodes {
		if node is Leaf[T] {
			label := view_label[T](node.view, Handle(handle))
			if label.len > max_label_width {
				max_label_width = label.len
			}
		}
	}
	if max_label_width == 0 {
		max_label_width = 1
	}

	// We need space for whitespace and ASCII art so add that.
	// Border + whitespace + label + whitespace + border.
	cell_width := 2 + max_label_width + 2
	// Border + label + border. No whitespace needed on the vertical axis.
	cell_height := 1 + 1 + 1

	// Make a grid that can fit our entire ASCII diagram.
	// Get our initial width/height. Each leaf is 1x1 in this.
	// We round up for this because partial widths/heights should
	// take up an extra cell.
	grid_w := int(math.ceil(f64(scaled_slots[0].width.f32()))) * cell_width
	grid_h := int(math.ceil(f64(scaled_slots[0].height.f32()))) * cell_height

	// Create the grid filled with spaces, each row ending with newline.
	mut grid := [][]u8{len: grid_h}
	for y in 0 .. grid_h {
		grid[y] = []u8{len: grid_w + 1, init: u8(` `)}
		grid[y][grid_w] = u8(`\n`)
	}

	// Draw each node
	for handle in 0 .. scaled_slots.len {
		// We only draw leaf nodes. Splits are only used for layout.
		if self.nodes[handle] is Split {
			continue
		}

		slot := scaled_slots[handle]

		// If our width/height is zero then we skip this.
		if slot.width.f32() == 0 || slot.height.f32() == 0 {
			continue
		}

		px := int(math.floor(f64(slot.x.f32()))) * cell_width
		py := int(math.floor(f64(slot.y.f32()))) * cell_height
		pw := int(math.max(math.floor(f64(slot.width.f32())), 1)) * cell_width
		ph := int(math.max(math.floor(f64(slot.height.f32())), 1)) * cell_height

		// Top border
		grid[py][px] = u8(`+`)
		for c in 1 .. pw - 1 {
			grid[py][px + c] = u8(`-`)
		}
		grid[py][px + pw - 1] = u8(`+`)

		// Bottom border
		grid[py + ph - 1][px] = u8(`+`)
		for c in 1 .. pw - 1 {
			grid[py + ph - 1][px + c] = u8(`-`)
		}
		grid[py + ph - 1][px + pw - 1] = u8(`+`)

		// Left and right borders
		for r in py + 1 .. py + ph - 1 {
			grid[r][px] = u8(`|`)
			grid[r][px + pw - 1] = u8(`|`)
		}

		// Get our label text
		label := if self.nodes[handle] is Leaf[T] {
			view_label[T]((self.nodes[handle] as Leaf[T]).view, Handle(handle))
		} else {
			'?'
		}

		// Draw the handle in the center
		x_mid := pw / 2 + px
		y_mid := ph / 2 + py
		label_start := x_mid - label.len / 2
		for ci in 0 .. label.len {
			grid[y_mid][label_start + ci] = label[ci]
		}
	}

	// Output every row
	mut sb := strings.new_builder(grid_h * (grid_w + 1))
	for row in grid {
		// We currently have a bug in our height calculation that
		// results in trailing blank lines. Ignore those. We should
		// really fix our height calculation instead. If someone wants
		// to do that just remove this line and see the tests that fail
		// and go from there.
		if row[0] == u8(` `) {
			break
		}
		for b in row {
			sb.write_u8(b)
		}
	}
	return sb.str()
}

// view_label mirrors Ghostty's optional splitTreeLabel declaration: views that
// don't provide it are formatted with their compact node handle.
fn view_label[T](view &T, handle Handle) string {
	$for method in T.methods {
		$if method.name == 'split_tree_label' {
			return view.split_tree_label()
		}
	}
	return handle.idx().str()
}
