module terminal

// Page represents a specific section of terminal screen. The primary
// idea of a page is that it is a fully self-contained unit that can be
// serialized, copied, etc. as a convenient way to represent a section
// of the screen.
//
// This property is useful for renderers which want to copy just the pages
// for the visible portion of the screen, or for infinite scrollback where
// we may want to serialize and store pages that are sufficiently far
// away from the current viewport.
//
// Translated from Ghostty's terminal/page.zig to V.
// In Zig, pages use a single contiguous mmap'd block with offset-based
// addressing. In V, we use V arrays and maps with GC-managed memory.

// ============================================================
// Constants
// ============================================================

// The allocator to use for multi-codepoint grapheme data. We use
// a chunk size of 4 codepoints. It'd be best to set this empirically
// but it is currently set based on vibes. My thinking around 4 codepoints
// is that most skin-tone emoji are <= 4 codepoints, letter combiners
// are usually <= 4 codepoints, and 4 codepoints is a nice power of two
// for alignment.
const grapheme_chunk_len = 4

// Chunk size in bytes for grapheme data.
const grapheme_chunk = grapheme_chunk_len * 4 // sizeof(u32)

// Default grapheme bytes capacity.
const grapheme_bytes_default = u32(8192)

// The allocator used for shared utf8-encoded strings within a page.
// Note the chunk size below is the minimum size of a single allocation.
// At the time of writing this, the strings table is only used for OSC8
// IDs and URIs. IDs are usually short and URIs are usually longer. I chose
// 32 bytes as a compromise between these two since it represents single
// domain links quite well and is not too wasteful for short IDs.
const string_chunk_len = 32
const string_chunk = string_chunk_len

// Default number of hyperlinks we support.
//
// The cell multiplier is the number of cells per hyperlink entry that
// we support. A hyperlink can be longer than this multiplier; the multiplier
// just sets the total capacity to simplify adjustable size metrics.
const hyperlink_count_default = 4
const hyperlink_cell_multiplier = 16

// Standard capacity for a new page.
const std_capacity = PageCapacity{
	cols: 80
	rows: 128
}

// Number of pages to preheat the pool with.
const page_preheat = 4

// ============================================================
// StyleSet - manages ref-counted styles for a page
// ============================================================

// StyleEntry stores a style with its reference count.
struct StyleEntry {
mut:
	style     CellStyle
	ref_count int
	in_use    bool
}

// StyleSet manages the available set of styles in use on a page.
pub struct StyleSet {
pub mut:
	entries []StyleEntry
}

// Initialize a new empty StyleSet.
pub fn StyleSet.init() StyleSet {
	// Entry 0 is reserved for the default style (unused).
	return StyleSet{
		entries: [StyleEntry{}]
	}
}

// Add a style to the set. If the style already exists, returns the
// existing ID and increments the ref count. Otherwise adds it and
// returns the new ID with ref_count = 1.
pub fn (mut self StyleSet) add(style CellStyle) !u32 {
	// Check if style already exists.
	for i := 1; i < self.entries.len; i++ {
		if self.entries[i].in_use && styles_equal(self.entries[i].style, style) {
			self.entries[i].ref_count++
			return u32(i)
		}
	}
	// Find a free slot.
	for i := 1; i < self.entries.len; i++ {
		if !self.entries[i].in_use {
			self.entries[i] = StyleEntry{
				style: style
				ref_count: 1
				in_use: true
			}
			return u32(i)
		}
	}
	// No free slot, append.
	self.entries << StyleEntry{
		style: style
		ref_count: 1
		in_use: true
	}
	return u32(self.entries.len - 1)
}

// Add a style, preferring to use the given ID.
pub fn (mut self StyleSet) add_with_id(style CellStyle, preferred_id u32) !u32 {
	// Check if style already exists.
	for i := 1; i < self.entries.len; i++ {
		if self.entries[i].in_use && styles_equal(self.entries[i].style, style) {
			self.entries[i].ref_count++
			return u32(i)
		}
	}
	// Try to use the preferred ID.
	pid := int(preferred_id)
	if pid > 0 && pid < self.entries.len && !self.entries[pid].in_use {
		self.entries[pid] = StyleEntry{
			style: style
			ref_count: 1
			in_use: true
		}
		return preferred_id
	}
	// Fall back to regular add.
	return self.add(style)
}

// Increment the ref count for a style.
pub fn (mut self StyleSet) use_style(id u32) {
	if int(id) < self.entries.len {
		self.entries[int(id)].ref_count++
	}
}

// Decrement the ref count for a style. If ref count hits 0, the
// slot is freed.
pub fn (mut self StyleSet) release(id u32) {
	if int(id) < self.entries.len && self.entries[int(id)].in_use {
		self.entries[int(id)].ref_count--
		if self.entries[int(id)].ref_count <= 0 {
			self.entries[int(id)].in_use = false
			self.entries[int(id)].ref_count = 0
		}
	}
}

// Get a style by ID.
pub fn (self &StyleSet) get(id u32) CellStyle {
	if int(id) < self.entries.len && self.entries[int(id)].in_use {
		return self.entries[int(id)].style
	}
	return CellStyle{}
}

// Get the ref count for a style.
pub fn (self &StyleSet) ref_count(id u32) int {
	if int(id) < self.entries.len {
		return self.entries[int(id)].ref_count
	}
	return 0
}

// Returns the number of styles with capacity for the given count,
// accounting for load factor. In V, we just return count + 2 to
// account for the reserved slot 0 and some headroom.
pub fn StyleSet.capacity_for_count(count int) u16 {
	if count == 0 {
		return 0
	}
	// Match Zig behavior: capacity accounts for load factor.
	// In practice this means roughly 2x the count, minimum 4.
	mut cap := count * 2
	if cap < 4 {
		cap = 4
	}
	return u16(cap)
}

// Compare two CellStyles for equality.
fn styles_equal(a CellStyle, b CellStyle) bool {
	return a.flags.bold == b.flags.bold && a.flags.faint == b.flags.faint
		&& a.flags.italic == b.flags.italic && a.flags.underline == b.flags.underline
		&& a.flags.overline == b.flags.overline && a.flags.blink == b.flags.blink
		&& a.flags.inverse == b.flags.inverse && a.flags.invisible == b.flags.invisible
		&& a.flags.strikethrough == b.flags.strikethrough && a.fg_color == b.fg_color
		&& a.bg_color == b.bg_color && a.underline_color == b.underline_color
		&& a.fg_r == b.fg_r && a.fg_g == b.fg_g && a.fg_b == b.fg_b
		&& a.bg_r == b.bg_r && a.bg_g == b.bg_g && a.bg_b == b.bg_b
		&& a.fg_palette == b.fg_palette && a.bg_palette == b.bg_palette
}

// ============================================================
// HyperlinkStorage - manages hyperlinks with ref counting
// ============================================================

// HyperlinkEntry stores a hyperlink with its reference count.
struct HyperlinkEntry {
mut:
	link      Hyperlink
	ref_count int
	in_use    bool
}

// HyperlinkStorage manages the set of hyperlinks for a page.
pub struct HyperlinkStorage {
pub mut:
	entries []HyperlinkEntry
}

// Initialize a new empty HyperlinkStorage.
pub fn HyperlinkStorage.init() HyperlinkStorage {
	// Entry 0 is reserved (unused).
	return HyperlinkStorage{
		entries: [HyperlinkEntry{}]
	}
}

// Add a hyperlink and return its ID (with ref_count = 1).
pub fn (mut self HyperlinkStorage) add(link Hyperlink) u32 {
	// Check if link already exists.
	for i := 1; i < self.entries.len; i++ {
		if self.entries[i].in_use && self.entries[i].link.uri == link.uri {
			self.entries[i].ref_count++
			return u32(i)
		}
	}
	// Find free slot.
	for i := 1; i < self.entries.len; i++ {
		if !self.entries[i].in_use {
			self.entries[i] = HyperlinkEntry{
				link: link
				ref_count: 1
				in_use: true
			}
			return u32(i)
		}
	}
	// Append.
	self.entries << HyperlinkEntry{
		link: link
		ref_count: 1
		in_use: true
	}
	return u32(self.entries.len - 1)
}

// Increment ref count for a hyperlink.
pub fn (mut self HyperlinkStorage) use_link(id u32) {
	if int(id) < self.entries.len {
		self.entries[int(id)].ref_count++
	}
}

// Decrement ref count for a hyperlink. Free if reaches 0.
pub fn (mut self HyperlinkStorage) release(id u32) {
	if int(id) < self.entries.len && self.entries[int(id)].in_use {
		self.entries[int(id)].ref_count--
		if self.entries[int(id)].ref_count <= 0 {
			self.entries[int(id)].in_use = false
			self.entries[int(id)].ref_count = 0
		}
	}
}

// Get a hyperlink by ID.
pub fn (self &HyperlinkStorage) get(id u32) Hyperlink {
	if int(id) < self.entries.len && self.entries[int(id)].in_use {
		return self.entries[int(id)].link
	}
	return Hyperlink{}
}

// Get ref count for a hyperlink.
pub fn (self &HyperlinkStorage) ref_count(id u32) int {
	if int(id) < self.entries.len {
		return self.entries[int(id)].ref_count
	}
	return 0
}

// Returns the number of hyperlinks with capacity for the given count.
pub fn HyperlinkStorage.capacity_for_count(count int) int {
	if count == 0 {
		return 0
	}
	mut cap := count * 2
	if cap < 4 {
		cap = 4
	}
	return cap
}

// ============================================================
// IntegrityError
// ============================================================

pub enum IntegrityError {
	zero_row_count
	zero_col_count
	unmarked_grapheme_row
	missing_grapheme_data
	invalid_grapheme_count
	unmarked_grapheme_cell
	missing_style
	unmarked_style_row
	mismatched_style_ref
	invalid_style_count
	missing_hyperlink_data
	mismatched_hyperlink_ref
	unmarked_hyperlink_cell
	unmarked_hyperlink_row
	invalid_spacer_tail_location
	invalid_spacer_head_location
	unwrapped_spacer_head
}

// ============================================================
// PageCapacity - describes how many cols/rows a page can hold
// ============================================================

// Capacity of a page.
//
// This capacity can be maxed out (every field max) and still fit
// within a page layout. For V, the memory-related fields are tracked
// for API compatibility but V's GC manages actual memory.
pub struct PageCapacity {
pub mut:
	// Number of columns and rows we can know about.
	cols u16 = 80
	rows u16 = 128
	// Number of unique styles that can be used on this page.
	styles u16 = 16
	// Number of bytes to allocate for grapheme data.
	grapheme_bytes u32 = grapheme_bytes_default
}

// Returns the maximum number of columns that can be used with this
// capacity while still fitting at least one row.
//
// In V, since memory is GC-managed, this is a heuristic based on
// keeping the total cell count reasonable.
pub fn (self PageCapacity) max_cols() ?u16 {
	// Compute total cell-equivalent "bits" available.
	total_cells := u32(self.cols) * u32(self.rows)
	if total_cells == 0 {
		return none
	}
	// Maximum cols = total_cells (with 1 row).
	max := if total_cells > u32(max_u16) { max_u16 } else { u16(total_cells) }
	return max
}

// Adjust the capacity parameters while retaining approximately the same
// total size. Adjustments happen by limiting the rows in the page.
// Everything else can grow. If it is impossible to achieve the desired
// adjustment, returns capacity with 1 row.
pub fn (self PageCapacity) adjust(cols u16) PageCapacity {
	if cols == 0 {
		return self
	}
	// The total "budget" is cols * rows from the original capacity.
	total_cells := u32(self.cols) * u32(self.rows)
	new_rows := total_cells / u32(cols)
	mut capped_rows := u16(0)
	if new_rows == 0 {
		capped_rows = 1
	} else if new_rows > u32(max_u16) {
		capped_rows = max_u16
	} else {
		capped_rows = u16(new_rows)
	}
	return PageCapacity{
		cols: cols
		rows: capped_rows
		styles: self.styles
		grapheme_bytes: self.grapheme_bytes
	}
}

const max_u16 = u16(65535)

// ============================================================
// PageSize - actual used size within a page
// ============================================================

pub struct PageSize {
pub mut:
	cols u16
	rows u16
}

// ============================================================
// Page - a page of terminal rows
// ============================================================

@[heap]
pub struct Page {
pub mut:
	// The array of rows in the page. The rows are always in row order
	// (i.e. index 0 is the top row, index 1 is the row below that, etc.)
	rows []RowData

	// Set to true when an operation is performed that dirties all rows
	// in the page. See RowData.dirty for more information on dirty tracking.
	//
	// NOTE: A value of false does NOT indicate that
	//       the page has no dirty rows in it, only
	//       that no full-page-dirtying operations
	//       have occurred since it was last cleared.
	dirty bool

	// The current dimensions of the page. The capacity may be larger
	// than this. This allows us to allocate a larger page than necessary
	// and also to resize a page smaller without reallocating.
	size PageSize

	// The capacity of this page. This is the full size of the backing
	// memory and is fixed at page creation time.
	capacity PageCapacity

	// The available set of styles in use on this page.
	styles StyleSet

	// The structures used for tracking hyperlinks within the page.
	// The map maps cell positions to hyperlink IDs and the IDs are in
	// the ref counted set.
	hyperlink_set HyperlinkStorage
	hyperlink_map map[u64]u32 // cell_key -> hyperlink_id
}

// Initialize a new page, allocating the required backing memory.
// The size of the initialized page defaults to the full capacity.
pub fn Page.init(cap PageCapacity) Page {
	mut rows := []RowData{cap: int(cap.rows)}
	for _ in 0 .. int(cap.rows) {
		rows << RowData.init(u32(cap.cols))
	}
	return Page{
		rows: rows
		capacity: cap
		size: PageSize{
			cols: cap.cols
			rows: 0
		}
		dirty: false
		styles: StyleSet.init()
		hyperlink_set: HyperlinkStorage.init()
	}
}

// Deinitialize the page, freeing any backing memory.
// In V, the GC handles memory, but we clear the data.
pub fn (mut self Page) deinit() {
	self.rows = []
	self.hyperlink_map = map[u64]u32{}
	self.styles = StyleSet.init()
	self.hyperlink_set = HyperlinkStorage.init()
}

// Reinitialize the page with the same capacity.
pub fn (mut self Page) reinit(cap PageCapacity) {
	self.capacity = cap
	self.size = PageSize{
		cols: cap.cols
		rows: 0
	}
	self.rows = []RowData{cap: int(cap.rows)}
	for _ in 0 .. int(cap.rows) {
		self.rows << RowData.init(u32(cap.cols))
	}
	self.dirty = false
	self.styles = StyleSet.init()
	self.hyperlink_set = HyperlinkStorage.init()
	self.hyperlink_map = map[u64]u32{}
}

// Verifies the integrity of the page data. This is not fast,
// but it is useful for assertions, deserialization, etc.
//
// Integrity errors are also logged as warnings.
pub fn (self &Page) verify_integrity() ?IntegrityError {
	// Some things that seem like we should check but do not:
	//
	// - We do not check that the style ref count is exact, only that
	//   it is at least what we see. We do this because some fast paths
	//   trim rows without clearing data.
	// - We do not check that styles seen is exactly the same as the
	//   styles count in the page for the same reason as above.
	// - We only check that we saw less graphemes than the total memory
	//   used for the same reason as styles above.
	//
	if self.size.cols == 0 {
		return IntegrityError.zero_col_count
	}
	if self.size.rows == 0 {
		return IntegrityError.zero_row_count
	}

	mut graphemes_seen := 0
	mut styles_seen := map[u32]int{}
	mut hyperlinks_seen := map[u32]int{}
	total_graphemes := self.grapheme_count()

	for y in 0 .. int(self.size.rows) {
		if y >= self.rows.len {
			break
		}
		row := self.rows[y]
		graphemes_start := graphemes_seen

		for x in 0 .. int(self.size.cols) {
			if x >= row.cells.len {
				break
			}
			cell := row.cells[x]

			if cell.has_grapheme {
				// If a cell has grapheme data, it must actually have graphemes.
				if cell.graphemes.len == 0 {
					return IntegrityError.missing_grapheme_data
				}
				graphemes_seen++
			} else if total_graphemes > 0 {
				// It should not have grapheme data if it isn't marked.
				if cell.graphemes.len > 0 {
					return IntegrityError.unmarked_grapheme_cell
				}
			}

			if cell.style_id != default_style_id {
				if !row.styled {
					return IntegrityError.unmarked_style_row
				}
				styles_seen[cell.style_id] = styles_seen[cell.style_id] + 1
			}

			if cell.has_hyperlink {
				key := cell_key(y, x, int(self.capacity.cols))
				if key !in self.hyperlink_map {
					return IntegrityError.missing_hyperlink_data
				}
				if !row.hyperlink {
					return IntegrityError.unmarked_hyperlink_row
				}
				hl_id := self.hyperlink_map[key]
				hyperlinks_seen[hl_id] = hyperlinks_seen[hl_id] + 1
			} else {
				// It should not have hyperlink data if it isn't marked.
				key := cell_key(y, x, int(self.capacity.cols))
				if key in self.hyperlink_map {
					return IntegrityError.unmarked_hyperlink_cell
				}
			}

			// Check spacer validity.
			match cell.wide {
				.narrow, .wide {}
				.spacer_tail {
					// Spacer tails can't be at the start because they follow
					// a wide char.
					if x == 0 {
						return IntegrityError.invalid_spacer_tail_location
					}
					// Spacer tails must follow a wide char.
					prev := row.cells[x - 1]
					if prev.wide != .wide {
						return IntegrityError.invalid_spacer_tail_location
					}
				}
				.spacer_head {
					// Spacer heads must be at the end.
					if x != int(self.size.cols) - 1 {
						return IntegrityError.invalid_spacer_head_location
					}
					// The row must be wrapped.
					if !row.wrap {
						return IntegrityError.unwrapped_spacer_head
					}
				}
			}
		}

		// Check row grapheme data.
		if graphemes_seen > graphemes_start {
			// If a cell in a row has grapheme data, the row must
			// be marked as having grapheme data.
			if !row.grapheme {
				return IntegrityError.unmarked_grapheme_row
			}
		}
	}

	// Our graphemes seen should not exceed the grapheme count.
	if graphemes_seen > total_graphemes {
		return IntegrityError.invalid_grapheme_count
	}

	// Verify all our styles have the correct ref count.
	for style_id, count in styles_seen {
		rc := self.styles.ref_count(style_id)
		if rc < count {
			return IntegrityError.mismatched_style_ref
		}
	}

	// Verify all our hyperlinks have the correct ref count.
	for hl_id, count in hyperlinks_seen {
		rc := self.hyperlink_set.ref_count(hl_id)
		if rc < count {
			return IntegrityError.mismatched_hyperlink_ref
		}
	}

	return none
}

// A helper that verifies integrity and panics on violation.
pub fn (self &Page) assert_integrity() {
	result := self.verify_integrity() or { return }
	// If we get here without error, integrity is verified.
	// In V, the error return pattern is different from Zig.
	_ = result
}

// Clone the contents of this page. This creates a deep copy.
pub fn (self &Page) clone() Page {
	mut new_rows := []RowData{cap: self.rows.len}
	for row in self.rows {
		mut new_cells := []CellData{cap: row.cells.len}
		for cell in row.cells {
			mut new_cell := CellData{
				codepoint: cell.codepoint
				content_tag: cell.content_tag
				style_id: cell.style_id
				wide: cell.wide
				is_protected: cell.is_protected
				has_grapheme: cell.has_grapheme
				has_hyperlink: cell.has_hyperlink
				semantic_content: cell.semantic_content
				color_palette: cell.color_palette
				color_rgb_r: cell.color_rgb_r
				color_rgb_g: cell.color_rgb_g
				color_rgb_b: cell.color_rgb_b
			}
			if cell.graphemes.len > 0 {
				new_cell.graphemes = cell.graphemes.clone()
			}
			new_cells << new_cell
		}
		new_rows << RowData{
			cells: new_cells
			wrap: row.wrap
			wrap_continuation: row.wrap_continuation
			grapheme: row.grapheme
			styled: row.styled
			hyperlink: row.hyperlink
			semantic_prompt: row.semantic_prompt
			kitty_virtual_placeholder: row.kitty_virtual_placeholder
			dirty: row.dirty
		}
	}

	// Deep copy the styles.
	mut new_styles := StyleSet{
		entries: self.styles.entries.clone()
	}

	// Deep copy hyperlink set.
	mut new_hl_set := HyperlinkStorage{
		entries: self.hyperlink_set.entries.clone()
	}

	// Clone hyperlink map.
	mut new_hl_map := map[u64]u32{}
	for k, v in self.hyperlink_map {
		new_hl_map[k] = v
	}

	return Page{
		rows: new_rows
		dirty: self.dirty
		size: self.size
		capacity: self.capacity
		styles: new_styles
		hyperlink_set: new_hl_set
		hyperlink_map: new_hl_map
	}
}

// Compute the exact capacity required to store a range of rows from
// this page.
//
// The returned capacity will have the same number of columns as this
// page and the number of rows equal to the range given.
//
// Preconditions:
// - Range must be at least 1 row
// - Start and end must be valid for this page
pub fn (self &Page) exact_row_capacity(y_start int, y_end int) PageCapacity {
	assert y_start < y_end
	assert y_end <= int(self.size.rows)

	// Track unique style IDs.
	mut style_ids := map[u32]bool{}
	mut grapheme_bytes := u32(0)

	// First pass: count styles and grapheme bytes.
	for y in y_start .. y_end {
		if y >= self.rows.len {
			break
		}
		row := self.rows[y]
		for x in 0 .. int(self.size.cols) {
			if x >= row.cells.len {
				break
			}
			cell := row.cells[x]
			if cell.style_id != default_style_id {
				style_ids[cell.style_id] = true
			}
			if cell.has_grapheme && cell.graphemes.len > 0 {
				// Each grapheme allocation rounds up to grapheme_chunk.
				bytes := u32(cell.graphemes.len) * 4 // sizeof(u32)
				// Round up to grapheme_chunk.
				chunks := (bytes + u32(grapheme_chunk) - 1) / u32(grapheme_chunk)
				grapheme_bytes += chunks * u32(grapheme_chunk)
			}
		}
	}

	styles_cap := StyleSet.capacity_for_count(style_ids.len)

	return PageCapacity{
		cols: self.size.cols
		rows: u16(y_end - y_start)
		styles: styles_cap
		grapheme_bytes: grapheme_bytes
	}
}

// Clone the contents of another page into this page. The capacities
// can be different, but the size of the other page must fit into
// this page.
//
// The y_start and y_end parameters allow you to clone only a portion
// of the other page. This is useful for splitting a page into two
// or more pages.
//
// The column count of this page will always be the same as this page.
// If the other page has more columns, the extra columns will be
// truncated. If the other page has fewer columns, the extra columns
// will be zeroed.
pub fn (mut self Page) clone_from(other &Page, y_start u16, y_end u16) {
	assert y_start <= y_end
	assert y_end <= other.size.rows

	count := int(y_end) - int(y_start)
	for i in 0 .. count {
		src_idx := int(y_start) + i
		if src_idx >= other.rows.len || i >= self.rows.len {
			break
		}
		self.clone_row_from(other, u16(i), u16(src_idx))
	}
}

// Clone a single row from another page into this page.
pub fn (mut self Page) clone_row_from(other &Page, dst_row_idx u16, src_row_idx u16) {
	self.clone_partial_row_from(other, dst_row_idx, src_row_idx, 0, self.size.cols)
}

// Clone a single row from another page into this page, supporting
// partial copy. clone_row_from calls this.
pub fn (mut self Page) clone_partial_row_from(other &Page, dst_row_idx u16, src_row_idx u16, x_start u16, x_end_req u16) {
	if int(src_row_idx) >= other.rows.len || int(dst_row_idx) >= self.rows.len {
		return
	}

	cell_len := if self.size.cols < other.size.cols { self.size.cols } else { other.size.cols }
	x_end := if x_end_req < cell_len { x_end_req } else { cell_len }

	src_row := other.rows[int(src_row_idx)]
	mut dst_row := &self.rows[int(dst_row_idx)]

	// If our destination has styles or graphemes then we need to
	// clear some state.
	if dst_row.managed_memory() {
		self.clear_cells(dst_row_idx, x_start, x_end)
	}

	// Copy row metadata but adjust if partial copy.
	is_full_row := (int(x_end) - int(x_start)) >= int(self.size.cols)
	if is_full_row {
		dst_row.wrap = src_row.wrap
		dst_row.wrap_continuation = src_row.wrap_continuation
		dst_row.grapheme = src_row.grapheme
		dst_row.hyperlink = src_row.hyperlink
		dst_row.styled = src_row.styled
		dst_row.semantic_prompt = src_row.semantic_prompt
		dst_row.kitty_virtual_placeholder = src_row.kitty_virtual_placeholder
		dst_row.dirty = src_row.dirty
	} else {
		// For partial copy, keep original flags for non-copied regions.
		dst_row.dirty = dst_row.dirty || src_row.dirty
	}

	// Copy cells.
	same_page := unsafe { voidptr(other) == voidptr(&self) }
	for xi in int(x_start) .. int(x_end) {
		if xi >= src_row.cells.len || xi >= dst_row.cells.len {
			break
		}
		src_cell := src_row.cells[xi]
		mut dst_cell := CellData{
			codepoint: src_cell.codepoint
			content_tag: if src_cell.content_tag == .codepoint_grapheme {
				ContentTag.codepoint
			} else {
				src_cell.content_tag
			}
			wide: src_cell.wide
			is_protected: src_cell.is_protected
			semantic_content: src_cell.semantic_content
			color_palette: src_cell.color_palette
			color_rgb_r: src_cell.color_rgb_r
			color_rgb_g: src_cell.color_rgb_g
			color_rgb_b: src_cell.color_rgb_b
		}

		// Copy graphemes.
		if src_cell.has_grapheme && src_cell.graphemes.len > 0 {
			dst_cell.graphemes = src_cell.graphemes.clone()
			dst_cell.has_grapheme = true
			dst_cell.content_tag = .codepoint_grapheme
			dst_row.grapheme = true
		}

		// Copy hyperlinks.
		if src_cell.has_hyperlink {
			src_key := cell_key(int(src_row_idx), xi, int(other.capacity.cols))
			if src_key in other.hyperlink_map {
				src_hl_id := other.hyperlink_map[src_key]
				if same_page {
					// Same page: reuse the hyperlink ID.
					self.hyperlink_set.use_link(src_hl_id)
				} else {
					// Different page: clone the hyperlink.
					src_link := other.hyperlink_set.get(src_hl_id)
					// Add returns existing ID if duplicate.
					self.hyperlink_set.add(src_link)
				}
				dst_key := cell_key(int(dst_row_idx), xi, int(self.capacity.cols))
				hl_id := if same_page {
					src_hl_id
				} else {
					self.hyperlink_set.add(other.hyperlink_set.get(other.hyperlink_map[src_key]))
				}
				self.hyperlink_map[dst_key] = hl_id
				dst_cell.has_hyperlink = true
				dst_row.hyperlink = true
			}
		}

		// Copy styles.
		if src_cell.style_id != default_style_id {
			if same_page {
				// Same page: use the same style ID.
				dst_cell.style_id = src_cell.style_id
				self.styles.use_style(src_cell.style_id)
			} else {
				// Different page: add the style to our set.
				src_style := other.styles.get(src_cell.style_id)
				dst_cell.style_id = self.styles.add_with_id(src_style, src_cell.style_id) or { 0 }
			}
			dst_row.styled = true
		}

		dst_row.cells[xi] = dst_cell
	}

	// If we are growing columns, then we need to ensure spacer heads
	// are cleared.
	if self.size.cols > other.size.cols {
		last_idx := int(other.size.cols) - 1
		if last_idx >= 0 && last_idx < dst_row.cells.len {
			if dst_row.cells[last_idx].wide == .spacer_head {
				dst_row.cells[last_idx].wide = .narrow
			}
		}
	}
}

// Get a single row. y must be valid.
pub fn (self &Page) get_row(y int) &RowData {
	assert y < int(self.size.rows)
	return &self.rows[y]
}

// Get the cells for a row.
pub fn (self &Page) get_cells(row &RowData) []CellData {
	return row.cells[..int(self.size.cols)]
}

// Get the row and cell for the given X/Y within this page.
pub struct RowAndCell {
pub mut:
	row  &RowData = unsafe { nil }
	cell &CellData = unsafe { nil }
}

pub fn (mut self Page) get_row_and_cell(x int, y int) RowAndCell {
	assert y < int(self.size.rows)
	assert x < int(self.size.cols)
	return RowAndCell{
		row: unsafe { &self.rows[y] }
		cell: unsafe { &self.rows[y].cells[x] }
	}
}

// Move cells from one location to another. This will replace the
// previous contents with a blank cell. Because this is a move, this
// doesn't allocate and can't fail.
pub fn (mut self Page) move_cells(src_row_idx int, src_left int, dst_row_idx int, dst_left int, len int) {
	// Clear our destination no matter what.
	self.clear_cells(u16(dst_row_idx), u16(dst_left), u16(dst_left + len))

	mut src_row := &self.rows[src_row_idx]
	mut dst_row := &self.rows[dst_row_idx]

	// If src has no managed memory, this is very fast.
	if !src_row.managed_memory() {
		for i in 0 .. len {
			dst_row.cells[dst_left + i] = src_row.cells[src_left + i]
		}
	} else {
		// Source has graphemes or hyperlinks...
		for i in 0 .. len {
			si := src_left + i
			di := dst_left + i
			src_cell := src_row.cells[si]
			dst_row.cells[di] = src_cell

			if src_cell.has_grapheme {
				// Move grapheme data.
				dst_row.cells[di].graphemes = src_cell.graphemes.clone()
				dst_row.cells[di].has_grapheme = true
				dst_row.cells[di].content_tag = .codepoint_grapheme
				dst_row.grapheme = true
			}
			if src_cell.has_hyperlink {
				src_key := cell_key(src_row_idx, si, int(self.capacity.cols))
				if src_key in self.hyperlink_map {
					hl_id := self.hyperlink_map[src_key]
					self.hyperlink_map.delete(src_key)
					dst_key := cell_key(dst_row_idx, di, int(self.capacity.cols))
					self.hyperlink_map[dst_key] = hl_id
					dst_row.cells[di].has_hyperlink = true
					dst_row.hyperlink = true
				}
			}
		}
	}

	// The destination row has styles if any of the cells are styled.
	if !dst_row.styled {
		for i in 0 .. len {
			if dst_row.cells[dst_left + i].style_id != default_style_id {
				dst_row.styled = true
				break
			}
		}
	}

	// Clear source row cells. We can NOT use clear_cells here because
	// clear_cells will garbage collect our styles and graphemes but we
	// moved them above.
	for i in 0 .. len {
		src_row.cells[src_left + i] = CellData{}
	}
	if len == int(self.size.cols) {
		src_row.grapheme = false
		src_row.hyperlink = false
		src_row.styled = false
		src_row.kitty_virtual_placeholder = false
	}
}

// Swap two cells within the same row as quickly as possible.
pub fn (mut self Page) swap_cells(row_idx int, src_x int, dst_x int) {
	mut row := &self.rows[row_idx]

	// Graphemes are keyed by cell, so we do have to move them.
	src_has_grapheme := row.cells[src_x].has_grapheme
	dst_has_grapheme := row.cells[dst_x].has_grapheme
	if src_has_grapheme || dst_has_grapheme {
		// Just swap the grapheme data in place since it's on the cells.
	}

	// Hyperlinks are keyed by cell position, so swap map entries.
	src_has_hl := row.cells[src_x].has_hyperlink
	dst_has_hl := row.cells[dst_x].has_hyperlink
	if src_has_hl || dst_has_hl {
		src_key := cell_key(row_idx, src_x, int(self.capacity.cols))
		dst_key := cell_key(row_idx, dst_x, int(self.capacity.cols))
		src_hl := self.hyperlink_map[src_key] or { 0 }
		dst_hl := self.hyperlink_map[dst_key] or { 0 }
		if src_has_hl && dst_has_hl {
			self.hyperlink_map[src_key] = dst_hl
			self.hyperlink_map[dst_key] = src_hl
		} else if src_has_hl {
			self.hyperlink_map.delete(src_key)
			self.hyperlink_map[dst_key] = src_hl
		} else {
			self.hyperlink_map.delete(dst_key)
			self.hyperlink_map[src_key] = dst_hl
		}
	}

	// Swap the cells themselves.
	old_dst := row.cells[dst_x]
	row.cells[dst_x] = row.cells[src_x]
	row.cells[src_x] = old_dst
}

// Clear the cells in the given row. This will reclaim memory used
// by graphemes and styles. Note that if the style cleared is still
// active, Page cannot know this and it will still be ref counted down.
// The best solution for this is to artificially increment the ref count
// prior to calling this function.
pub fn (mut self Page) clear_cells(row_idx u16, left u16, end u16) {
	if int(row_idx) >= self.rows.len {
		return
	}
	mut row := &self.rows[int(row_idx)]
	cols := int(self.size.cols)

	// If we have managed memory (styles, graphemes, or hyperlinks)
	// in this row then we go cell by cell and clear them if present.
	if row.grapheme {
		for x in int(left) .. int(end) {
			if x < row.cells.len && row.cells[x].has_grapheme {
				row.cells[x].graphemes = []
				row.cells[x].has_grapheme = false
				row.cells[x].content_tag = .codepoint
			}
		}
		// If we cleared the full row width, clear the flag.
		if int(end) - int(left) >= cols {
			row.grapheme = false
		} else {
			self.update_row_grapheme_flag(row)
		}
	}

	if row.hyperlink {
		for x in int(left) .. int(end) {
			if x < row.cells.len && row.cells[x].has_hyperlink {
				key := cell_key(int(row_idx), x, int(self.capacity.cols))
				if key in self.hyperlink_map {
					hl_id := self.hyperlink_map[key]
					self.hyperlink_set.release(hl_id)
					self.hyperlink_map.delete(key)
				}
				row.cells[x].has_hyperlink = false
			}
		}
		if int(end) - int(left) >= cols {
			row.hyperlink = false
		} else {
			self.update_row_hyperlink_flag(row)
		}
	}

	if row.styled {
		for x in int(left) .. int(end) {
			if x < row.cells.len && row.cells[x].has_styling() {
				self.styles.release(row.cells[x].style_id)
			}
		}
		if int(end) - int(left) >= cols {
			row.styled = false
		} else {
			self.update_row_styled_flag(row)
		}
	}

	// Zero the cells.
	for x in int(left) .. int(end) {
		if x < row.cells.len {
			row.cells[x] = CellData{}
		}
	}
	row.dirty = true
}

// Clear an entire row.
pub fn (mut self Page) clear_row(row_idx u16) {
	self.clear_cells(row_idx, 0, self.size.cols)
	if int(row_idx) < self.rows.len {
		mut row := &self.rows[int(row_idx)]
		row.wrap = false
		row.wrap_continuation = false
		row.styled = false
		row.grapheme = false
		row.hyperlink = false
		row.semantic_prompt = .unknown
		row.kitty_virtual_placeholder = false
	}
}

// Returns the hyperlink ID for the given cell.
pub fn (self &Page) lookup_hyperlink(row_idx int, col_idx int) ?u32 {
	key := cell_key(row_idx, col_idx, int(self.capacity.cols))
	if key in self.hyperlink_map {
		return self.hyperlink_map[key]
	}
	return none
}

// Clear the hyperlink from the given cell.
//
// In order to update the hyperlink flag on the row, call
// update_row_hyperlink_flag after you finish clearing any
// hyperlinks in the row.
pub fn (mut self Page) clear_hyperlink(row_idx int, col_idx int) {
	key := cell_key(row_idx, col_idx, int(self.capacity.cols))
	if key in self.hyperlink_map {
		hl_id := self.hyperlink_map[key]
		self.hyperlink_set.release(hl_id)
		self.hyperlink_map.delete(key)
	}
	if row_idx < self.rows.len && col_idx < self.rows[row_idx].cells.len {
		self.rows[row_idx].cells[col_idx].has_hyperlink = false
	}
}

// Convert a hyperlink into a page entry, returning the ID.
//
// To release the memory associated with the given hyperlink,
// release the ID from the hyperlink_set. If the refcount reaches
// zero the slot is freed.
pub fn (mut self Page) insert_hyperlink(link Hyperlink) u32 {
	return self.hyperlink_set.add(link)
}

// Set the hyperlink for the given cell. If the cell already has a
// hyperlink, then this will handle memory management and refcount
// update for the prior hyperlink.
//
// DOES NOT increment the reference count for the new hyperlink!
//
// Caller is responsible for updating the refcount in the hyperlink
// set as necessary by calling use_link if the id was not acquired with
// add.
pub fn (mut self Page) set_hyperlink(row_idx int, col_idx int, id u32) {
	key := cell_key(row_idx, col_idx, int(self.capacity.cols))

	if key in self.hyperlink_map {
		old_id := self.hyperlink_map[key]
		// Always release the old hyperlink.
		self.hyperlink_set.release(old_id)
	}

	self.hyperlink_map[key] = id
	if row_idx < self.rows.len && col_idx < self.rows[row_idx].cells.len {
		self.rows[row_idx].cells[col_idx].has_hyperlink = true
	}
	if row_idx < self.rows.len {
		self.rows[row_idx].hyperlink = true
	}
}

// Move the hyperlink from one cell to another. This can't fail
// because we avoid any allocations since we're just moving data.
// Destination must NOT have a hyperlink.
fn (mut self Page) move_hyperlink(src_row int, src_col int, dst_row int, dst_col int) {
	src_key := cell_key(src_row, src_col, int(self.capacity.cols))
	dst_key := cell_key(dst_row, dst_col, int(self.capacity.cols))
	if src_key in self.hyperlink_map {
		hl_id := self.hyperlink_map[src_key]
		self.hyperlink_map.delete(src_key)
		self.hyperlink_map[dst_key] = hl_id
	}
	// NOTE: We must not set has_hyperlink here because this
	// function is used in various cases where we swap cell contents
	// and its unsafe. The flip side: the caller must be careful
	// to set the proper cell state to represent the move.
}

// Returns the number of hyperlinks in the page. This isn't the byte
// size but the total number of unique cells that have hyperlink data.
pub fn (self &Page) hyperlink_count() int {
	return self.hyperlink_map.len
}

// Returns the hyperlink capacity for the page.
pub fn (self &Page) hyperlink_capacity() int {
	// In V, maps grow dynamically. Return a reasonable capacity
	// based on the page size for compatibility with tests.
	return int(self.size.cols) * int(self.size.rows)
}

// Set the graphemes for the given cell. This asserts that the cell
// has no graphemes set, and only contains a single codepoint.
pub fn (mut self Page) set_graphemes(row_idx int, col_idx int, cps []u32) {
	mut row := &self.rows[row_idx]
	mut cell := &row.cells[col_idx]
	assert cell.codepoint > 0
	assert cell.content_tag == .codepoint

	cell.graphemes = cps.clone()
	cell.content_tag = .codepoint_grapheme
	cell.has_grapheme = true
	row.grapheme = true
}

// Append a codepoint to the given cell as a grapheme.
pub fn (mut self Page) append_grapheme(row_idx int, col_idx int, cp u32) {
	mut row := &self.rows[row_idx]
	mut cell := &row.cells[col_idx]

	cell.graphemes << cp
	if cell.content_tag != .codepoint_grapheme {
		cell.content_tag = .codepoint_grapheme
		cell.has_grapheme = true
		row.grapheme = true
	}
}

// Returns the codepoints for the given cell. These are the codepoints
// in addition to the first codepoint. The first codepoint is NOT
// included since it is on the cell itself.
pub fn (self &Page) lookup_grapheme(row_idx int, col_idx int) ?[]u32 {
	if row_idx >= self.rows.len {
		return none
	}
	row := self.rows[row_idx]
	if col_idx >= row.cells.len {
		return none
	}
	cell := row.cells[col_idx]
	if cell.has_grapheme && cell.graphemes.len > 0 {
		return cell.graphemes
	}
	return none
}

// Move the graphemes from one cell to another. This can't fail
// because we avoid any allocations since we're just moving data.
//
// WARNING: This will NOT change the content_tag on the cells because
// there are scenarios where we want to move graphemes without changing
// the content tag. Callers beware but assert_integrity should catch this.
fn (mut self Page) move_grapheme(src_row int, src_col int, dst_row int, dst_col int) {
	if src_row < self.rows.len && src_col < self.rows[src_row].cells.len {
		graphemes := self.rows[src_row].cells[src_col].graphemes.clone()
		self.rows[src_row].cells[src_col].graphemes = []
		self.rows[src_row].cells[src_col].has_grapheme = false
		self.rows[src_row].cells[src_col].content_tag = .codepoint
		if dst_row < self.rows.len && dst_col < self.rows[dst_row].cells.len {
			self.rows[dst_row].cells[dst_col].graphemes = graphemes
			self.rows[dst_row].cells[dst_col].has_grapheme = true
			self.rows[dst_row].cells[dst_col].content_tag = .codepoint_grapheme
		}
	}
}

// Clear the graphemes for a given cell.
//
// In order to update the grapheme flag on the row, call
// update_row_grapheme_flag after you finish clearing any
// graphemes in the row.
pub fn (mut self Page) clear_grapheme(row_idx int, col_idx int) {
	if row_idx < self.rows.len && col_idx < self.rows[row_idx].cells.len {
		self.rows[row_idx].cells[col_idx].graphemes = []
		self.rows[row_idx].cells[col_idx].has_grapheme = false
		// Mark that we no longer have graphemes by changing the content tag.
		self.rows[row_idx].cells[col_idx].content_tag = .codepoint
	}
}

// Checks if the row contains any graphemes and sets
// the grapheme flag to false if none are found.
//
// Call after removing graphemes in a row.
pub fn (mut self Page) update_row_grapheme_flag(row &RowData) {
	for cell in row.cells {
		if cell.has_grapheme {
			return
		}
	}
	unsafe {
		mut r := row
		r.grapheme = false
	}
}

// Returns the number of graphemes in the page. This isn't the byte
// size but the total number of unique cells that have grapheme data.
pub fn (self &Page) grapheme_count() int {
	mut count := 0
	for row in self.rows {
		if !row.grapheme {
			continue
		}
		for cell in row.cells {
			if cell.has_grapheme {
				count++
			}
		}
	}
	return count
}

// Checks if the row contains any hyperlinks and sets
// the hyperlink flag to false if none are found.
//
// Call after removing hyperlinks in a row.
pub fn (mut self Page) update_row_hyperlink_flag(row &RowData) {
	for cell in row.cells {
		if cell.has_hyperlink {
			return
		}
	}
	unsafe {
		mut r := row
		r.hyperlink = false
	}
}

// Checks if the row contains any styles and sets
// the styled flag to false if none are found.
//
// Call after removing styles in a row.
pub fn (mut self Page) update_row_styled_flag(row &RowData) {
	for cell in row.cells {
		if cell.has_styling() {
			return
		}
	}
	unsafe {
		mut r := row
		r.styled = false
	}
}

// Returns true if this page is dirty at all.
pub fn (self &Page) is_dirty() bool {
	if self.dirty {
		return true
	}
	for y in 0 .. int(self.size.rows) {
		if y < self.rows.len && self.rows[y].dirty {
			return true
		}
	}
	return false
}

// Returns true if a row is entirely blank (no codepoints).
pub fn (self &Page) row_is_blank(row_idx u16) bool {
	if int(row_idx) >= self.rows.len {
		return true
	}
	row := self.rows[int(row_idx)]
	for cell in row.cells {
		if cell.has_text() {
			return false
		}
	}
	return true
}

// ============================================================
// Helper: cell key for hyperlink map
// ============================================================

// Compute a unique key for a cell position in the hyperlink map.
fn cell_key(row_idx int, col_idx int, max_cols int) u64 {
	return u64(row_idx) * u64(max_cols) + u64(col_idx)
}

// ============================================================
// PageNode - a node in the doubly-linked list of pages
// ============================================================

@[heap]
pub struct PageNode {
pub mut:
	prev   ?&PageNode
	next   ?&PageNode
	data   Page
	serial u64
}

// ============================================================
// PageNodeList - doubly-linked list of PageNode
// ============================================================

pub struct PageNodeList {
pub mut:
	first ?&PageNode
	last  ?&PageNode
}

// Append a node to the end of the list.
pub fn (mut self PageNodeList) append(node &PageNode) {
	unsafe {
		mut n := node
		n.prev = self.last
		n.next = none
	}
	if mut l := self.last {
		l.next = node
	}
	self.last = node
	if self.first == none {
		self.first = node
	}
}

// Prepend a node to the beginning of the list.
pub fn (mut self PageNodeList) prepend(node &PageNode) {
	unsafe {
		mut n := node
		n.next = self.first
		n.prev = none
	}
	if mut f := self.first {
		f.prev = node
	}
	self.first = node
	if self.last == none {
		self.last = node
	}
}

// Remove a node from the list.
pub fn (mut self PageNodeList) remove(node &PageNode) {
	if p := node.prev {
		unsafe {
			mut mp := p
			mp.next = node.next
		}
	} else {
		self.first = node.next
	}
	if n := node.next {
		unsafe {
			mut mn := n
			mn.prev = node.prev
		}
	} else {
		self.last = node.prev
	}
	unsafe {
		mut mnode := node
		mnode.prev = none
		mnode.next = none
	}
}

// Insert a node after an existing node.
pub fn (mut self PageNodeList) insert_after(existing &PageNode, node &PageNode) {
	unsafe {
		mut n := node
		n.prev = existing
		n.next = existing.next
	}
	if next := existing.next {
		unsafe {
			mut mn := next
			mn.prev = node
		}
	} else {
		self.last = node
	}
	unsafe {
		mut me := existing
		me.next = node
	}
}

// Insert a node before an existing node.
pub fn (mut self PageNodeList) insert_before(existing &PageNode, node &PageNode) {
	unsafe {
		mut n := node
		n.next = existing
		n.prev = existing.prev
	}
	if prev := existing.prev {
		unsafe {
			mut mp := prev
			mp.next = node
		}
	} else {
		self.first = node
	}
	unsafe {
		mut me := existing
		me.prev = node
	}
}

// Pop and return the first node.
pub fn (mut self PageNodeList) pop_first() ?&PageNode {
	f := self.first or { return none }
	self.remove(f)
	return f
}

// Pop and return the last node.
pub fn (mut self PageNodeList) pop_last() ?&PageNode {
	l := self.last or { return none }
	self.remove(l)
	return l
}
