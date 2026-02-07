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
//   - fn split_tree_label(self &T) string - Return a label that is
//     used for the debug view.
pub struct SplitTree[T] {
pub mut:
	// All the nodes in the tree. Node at index 0 is always the root.
	nodes []Node[T]
	// The handle of the zoomed node. A "zoomed" node is one that is
	// expected to be made the full size of the split tree. Various
	// operations may unzoom (e.g. resize).
	zoomed int = -1 // -1 means no zoom
}

// Node is either a leaf (containing a view) or a split (dividing space).
pub type Node[T] = Leaf[T] | Split

// A handle into the nodes array. We use plain int indices.
// handle_root is the handle for the root node (index 0).
pub const handle_root = 0

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
	ratio f32
	// Handle (index) of the left/top child.
	left int
	// Handle (index) of the right/bottom child.
	right int
}

// Layout direction for a split.
pub enum Layout {
	horizontal
	vertical
}

// Direction for split operations.
pub enum Direction {
	left
	right
	down
	up
}

// Side of a tree (left or right).
pub enum Side {
	left
	right
}

// SpatialDirection for spatial navigation.
pub enum SpatialDirection {
	left
	right
	down
	up
}

// Goto specifies how to navigate from a node.
pub type Goto = GotoPrevious | GotoNext | GotoPreviousWrapped | GotoNextWrapped | GotoSpatial

// GotoPrevious - previous view, -1 if we're the first view.
pub struct GotoPrevious {}

// GotoNext - next view, -1 if we're the last view.
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
	handle int
	view   &T
}

// SplitTreeIterator iterates over all the views in the tree.
pub struct SplitTreeIterator[T] {
mut:
	i int
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
	x      f32
	y      f32
	width  f32
	height f32
}

// max_x returns the right edge of the slot.
fn (s &Slot) max_x() f32 {
	return s.x + s.width
}

// max_y returns the bottom edge of the slot.
fn (s &Slot) max_y() f32 {
	return s.y + s.height
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
	handle int
}

struct Dimensions {
	width  int
	height int
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
	return SplitTree[T]{
		nodes: [Node[T](Leaf[T]{ view: reffed })]
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
	self.zoomed = -1
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
		i:     0
		nodes: self.nodes
	}
}

// next returns the next ViewEntry from the iterator, or none.
pub fn (mut self SplitTreeIterator[T]) next() ?ViewEntry[T] {
	// Skip split nodes, only return leaves.
	for self.i < self.nodes.len {
		handle := self.i
		node := self.nodes[self.i]
		self.i++
		if node is Leaf[T] {
			return ViewEntry[T]{
				handle: handle
				view:   node.view
			}
		}
	}
	return none
}

// zoom changes the zoomed state to the given node handle.
// Pass -1 to unzoom. Assumes the handle is valid.
pub fn (mut self SplitTree[T]) zoom(handle int) {
	if handle >= 0 {
		assert(handle < self.nodes.len)
	}
	self.zoomed = handle
}

// goto_ navigates from a node in the split tree. Returns -1
// if the direction results in no visitable view.
//
// The name uses trailing underscore to avoid conflict with V keyword.
pub fn (self &SplitTree[T]) goto_(from int, to Goto) int {
	match to {
		GotoPrevious {
			return self.previous(from)
		}
		GotoNext {
			return self.next_node(from)
		}
		GotoPreviousWrapped {
			prev := self.previous(from)
			if prev >= 0 {
				return prev
			}
			return self.deepest(.right, handle_root)
		}
		GotoNextWrapped {
			nxt := self.next_node(from)
			if nxt >= 0 {
				return nxt
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
pub fn (self &SplitTree[T]) deepest(side Side, from int) int {
	mut current := from
	for {
		node := self.nodes[current]
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
// Returns -1 if there is no previous (this is the first view).
//
// "Previous" is defined as the previous node in an in-order
// traversal of the tree.
fn (self &SplitTree[T]) previous(from int) int {
	result := self.previous_backtrack(from, handle_root)
	if result is BacktrackResult {
		return result.handle
	}
	return -1
}

// next_node returns the next view from the given node handle.
// Returns -1 if there is no next (this is the last view).
fn (self &SplitTree[T]) next_node(from int) int {
	result := self.next_backtrack(from, handle_root)
	if result is BacktrackResult {
		return result.handle
	}
	return -1
}

fn (self &SplitTree[T]) previous_backtrack(from int, current int) Backtrack {
	// If we reached the point that we're trying to find the previous
	// value of, then we need to backtrack from here.
	if from == current {
		return BacktrackBacktrack{}
	}

	node := self.nodes[current]
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
fn (self &SplitTree[T]) next_backtrack(from int, current int) Backtrack {
	if from == current {
		return BacktrackBacktrack{}
	}
	node := self.nodes[current]
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
fn (self &SplitTree[T]) nearest(sp Spatial, from int, direction SpatialDirection) int {
	target := sp.slots[from]

	mut best_handle := -1
	mut best_distance := f32(0)

	for handle in 0 .. sp.slots.len {
		// Never match ourself
		if handle == from {
			continue
		}
		// Only match leaves
		if self.nodes[handle] is Split {
			continue
		}

		slot := sp.slots[handle]

		// Ensure it is in the proper direction
		in_direction := match direction {
			.left { slot.max_x() <= target.x }
			.right { slot.x >= target.max_x() }
			.up { slot.max_y() <= target.y }
			.down { slot.y >= target.max_y() }
		}
		if !in_direction {
			continue
		}

		// Track our distance
		dx := slot.x - target.x
		dy := slot.y - target.y
		distance := f32(math.sqrt(f64(dx * dx + dy * dy)))

		// If we have a nearest it must be closer.
		if best_handle >= 0 {
			if distance >= best_distance {
				continue
			}
		}
		best_handle = handle
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
pub fn (mut self SplitTree[T]) resize_in_place(at int, ratio f32) {
	node := self.nodes[at]
	if node is Split {
		self.nodes[at] = Node[T](Split{
			layout: node.layout
			ratio:  ratio
			left:   node.left
			right:  node.right
		})
	}
}

// split_ inserts another tree into this tree at the given node in the
// specified direction. The other tree will be inserted in the new direction.
// For example, if the direction is "right" then `insert` is inserted right
// of the existing node.
//
// The previous trees will not be freed, but reference counts
// for the views will be increased accordingly for the new tree.
pub fn (self &SplitTree[T]) split_(at int, direction Direction, ratio f32, insert &SplitTree[T]) SplitTree[T] {
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
				left:   node.left + self.nodes.len
				right:  node.right + self.nodes.len
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
	nodes << nodes[at]
	last_idx := nodes.len - 1
	nodes[at] = Node[T](Split{
		layout: layout
		ratio:  ratio
		left:   if is_left { self.nodes.len } else { last_idx }
		right:  if is_left { last_idx } else { self.nodes.len }
	})

	// We need to increase the reference count of all the nodes.
	ref_nodes[T](mut nodes)

	return SplitTree[T]{
		nodes: nodes
		// Splitting always resets zoom state.
		zoomed: -1
	}
}

// remove removes a node from the tree.
pub fn (self &SplitTree[T]) remove(at int) SplitTree[T] {
	assert(at < self.nodes.len)

	// If we're removing node zero then we're clearing the tree.
	if at == handle_root {
		return SplitTree.empty[T]()
	}

	// Count nodes needed after the removal.
	count := self.count_after_removal(handle_root, at, 0)

	// Pre-allocate nodes with dummy values.
	mut new_nodes := []Node[T]{len: count, init: Node[T](Split{})}
	mut result := SplitTree[T]{
		nodes:  new_nodes
		zoomed: -1
	}

	// Traverse the tree and copy all our nodes into place.
	written := remove_node_impl[T](self, mut result, 0, handle_root, at)
	assert(written != 0)

	// Increase the reference count of all the nodes.
	ref_nodes[T](mut result.nodes)

	return result
}

fn remove_node_impl[T](old &SplitTree[T], mut new_tree SplitTree[T], new_offset int, current int, target int) int {
	assert(current != target)

	// If we have a zoomed node and this is it then we migrate it.
	if old.zoomed >= 0 && old.zoomed == current {
		assert(new_tree.zoomed == -1)
		new_tree.zoomed = new_offset
	}

	node := old.nodes[current]
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
		new_tree.nodes[new_offset] = Node[T](Split{
			layout: node.layout
			ratio:  node.ratio
			left:   new_offset + 1
			right:  new_offset + 1 + left_count
		})
		return left_count + right_count + 1
	}
	if node is Leaf[T] {
		// Leaf is simple, just copy it over. We don't ref anything
		// yet because it'd make undo harder. We do that all at once later.
		new_tree.nodes[new_offset] = Node[T](Leaf[T]{ view: node.view })
		return 1
	}
	return 0 // unreachable
}

// count_after_removal returns the number of nodes that would be needed
// to store the tree if the target node is removed.
fn (self &SplitTree[T]) count_after_removal(current int, target int, acc int) int {
	assert(current != target)

	node := self.nodes[current]
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
			weight_left_f := f32(weight_left)
			nodes[i] = Node[T](Split{
				layout: node.layout
				ratio:  weight_left_f / total_f
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

fn (self &SplitTree[T]) weight(from int, layout Layout, acc int) int {
	node := self.nodes[from]
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
pub fn (self &SplitTree[T]) resize(from int, layout Layout, ratio f32) SplitTree[T] {
	assert(ratio >= -1 && ratio <= 1)
	assert(!math.is_nan(f64(ratio)))
	assert(!math.is_inf(f64(ratio), 0))

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
		.horizontal { sp.slots[parent_handle].width / sp.slots[0].width }
		.vertical { sp.slots[parent_handle].height / sp.slots[0].height }
	}

	parent_node := result.nodes[parent_handle]
	current_ratio := if parent_node is Split {
		parent_node.ratio
	} else {
		f32(0.5) // should not happen
	}
	full_ratio := current_ratio * scale

	// Set the final new ratio, clamping it to [0, 1]
	new_ratio := math.min(math.max(full_ratio + ratio, f32(0)), f32(1))
	result.resize_in_place(parent_handle, new_ratio)
	return result
}

fn (self &SplitTree[T]) find_parent_split(layout Layout, from int, current int) Backtrack {
	if from == current {
		return BacktrackBacktrack{}
	}
	node := self.nodes[current]
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
		x:      0
		y:      0
		width:  f32(dim.width)
		height: f32(dim.height)
	}
	self.fill_spatial_slots(mut slots, handle_root)

	// Normalize the dimensions to 1x1 grid.
	for i in 0 .. slots.len {
		slots[i].x /= f32(dim.width)
		slots[i].y /= f32(dim.height)
		slots[i].width /= f32(dim.width)
		slots[i].height /= f32(dim.height)
	}

	return Spatial{ slots: slots }
}

fn (self &SplitTree[T]) fill_spatial_slots(mut slots []Slot, current int) {
	assert(slots[current].width >= 0 && slots[current].height >= 0)
	node := self.nodes[current]
	if node is Split {
		match node.layout {
			.horizontal {
				slots[node.left] = Slot{
					x:      slots[current].x
					y:      slots[current].y
					width:  slots[current].width * node.ratio
					height: slots[current].height
				}
				slots[node.right] = Slot{
					x:      slots[current].x + slots[current].width * node.ratio
					y:      slots[current].y
					width:  slots[current].width * (1 - node.ratio)
					height: slots[current].height
				}
			}
			.vertical {
				slots[node.left] = Slot{
					x:      slots[current].x
					y:      slots[current].y
					width:  slots[current].width
					height: slots[current].height * node.ratio
				}
				slots[node.right] = Slot{
					x:      slots[current].x
					y:      slots[current].y + slots[current].height * node.ratio
					width:  slots[current].width
					height: slots[current].height * (1 - node.ratio)
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
fn (self &SplitTree[T]) dimensions(current int) Dimensions {
	node := self.nodes[current]
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

fn (self &SplitTree[T]) format_text_inner(mut sb strings.Builder, current int, depth int) {
	for _ in 0 .. depth {
		sb.write_string('  ')
	}

	if self.zoomed >= 0 && self.zoomed == current {
		sb.write_string('(zoomed) ')
	}

	node := self.nodes[current]
	if node is Split {
		layout_str := match node.layout {
			.horizontal { 'horizontal' }
			.vertical { 'vertical' }
		}
		sb.write_string('split (layout: ${layout_str}, ratio: ${node.ratio:.2f})\n')
		self.format_text_inner(mut sb, node.left, depth + 1)
		self.format_text_inner(mut sb, node.right, depth + 1)
	} else if node is Leaf[T] {
		sb.write_string('leaf: ${node.view.split_tree_label()}\n')
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
	mut min_w := f32(1)
	mut min_h := f32(1)
	for slot in sp.slots {
		if slot.width > 0 {
			min_w = math.min(min_w, slot.width)
		}
		if slot.height > 0 {
			min_h = math.min(min_h, slot.height)
		}
	}
	ratio_w := f32(1) / min_w
	ratio_h := f32(1) / min_h

	mut scaled_slots := []Slot{len: sp.slots.len}
	for i in 0 .. sp.slots.len {
		scaled_slots[i] = Slot{
			x:      sp.slots[i].x * ratio_w
			y:      sp.slots[i].y * ratio_h
			width:  sp.slots[i].width * ratio_w
			height: sp.slots[i].height * ratio_h
		}
	}

	// The width we need for the largest label.
	mut max_label_width := 0
	for node in self.nodes {
		if node is Leaf[T] {
			label := node.view.split_tree_label()
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
	grid_w := int(math.ceil(f64(scaled_slots[0].width))) * cell_width
	grid_h := int(math.ceil(f64(scaled_slots[0].height))) * cell_height

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
		if slot.width == 0 || slot.height == 0 {
			continue
		}

		px := int(math.floor(f64(slot.x))) * cell_width
		py := int(math.floor(f64(slot.y))) * cell_height
		pw := int(math.max(math.floor(f64(slot.width)), 1)) * cell_width
		ph := int(math.max(math.floor(f64(slot.height)), 1)) * cell_height

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
			(self.nodes[handle] as Leaf[T]).view.split_tree_label()
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
