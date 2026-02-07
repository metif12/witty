module terminal

// Keep track of the location of tabstops.
//
// This is implemented as a bit set. There is a preallocation segment that
// is used for almost all screen sizes. Then there is a dynamically allocated
// segment if the screen is larger than the preallocation amount.
//
// In reality, tabstops don't need to be the most performant in any metric.
// This implementation tries to balance denser memory usage (by using a bitset)
// and minimizing unnecessary allocations.
//
// NOTE: This replaces the simpler Tabstops stub in terminal.v. Remove
// the old Tabstops definition from terminal.v to avoid duplicate symbols.

// Unit is the type we use per tabstop unit (see file docs).
// Each unit stores 8 tabstop bits.

// The number of bits per unit.
const tabstop_unit_bits = 8

// The number of columns we preallocate for. This is kind of high which
// costs us some memory, but this is more columns than a 6k monitor at
// 12-point font size, so this should prevent allocation in almost all
// real world scenarios for the price of wasting at most
// (columns / sizeof(Unit)) bytes.
const tabstop_prealloc_columns = 512

// The number of entries we need for our preallocation.
const tabstop_prealloc_count = tabstop_prealloc_columns / tabstop_unit_bits // 64

// We precompute all the possible masks since we never use a huge bit size.
const tabstop_masks = [u8(1), 2, 4, 8, 16, 32, 64, 128]!

// Tabstops tracks tab stop positions using a bitset for efficient storage.
// A preallocated array handles up to 512 columns without dynamic allocation.
// For larger terminals, a dynamic slice extends the capacity.
pub struct Tabstops {
mut:
	// The number of columns this tabstop is set to manage. Use resize()
	// to change this number.
	cols int
	// Preallocated tab stops (enough for 512 columns).
	prealloc_stops [tabstop_prealloc_count]u8
	// Dynamically expanded stops above prealloc stops.
	dynamic_stops []u8
}

// Returns the entry index in the stops array that would contain this column.
fn tabstop_entry(col u32) int {
	return int(col) / tabstop_unit_bits
}

// Returns the bit index within the entry for this column.
fn tabstop_index(col u32) int {
	return int(col) % tabstop_unit_bits
}

// init creates a new Tabstops with the given number of columns and
// initial tab stop interval. Returns error if dynamic allocation fails.
pub fn Tabstops.init(cols int, interval int) !Tabstops {
	mut res := Tabstops{}
	res.resize(cols)!
	res.reset(interval)
	return res
}

// deinit frees any dynamic allocation.
pub fn (mut self Tabstops) deinit() {
	self.dynamic_stops = []
}

// set marks a tabstop at a certain column. The columns are 0-indexed.
pub fn (mut self Tabstops) set(col u32) {
	i := tabstop_entry(col)
	idx := tabstop_index(col)
	if i < tabstop_prealloc_count {
		self.prealloc_stops[i] |= tabstop_masks[idx]
		return
	}

	dynamic_i := i - tabstop_prealloc_count
	self.dynamic_stops[dynamic_i] |= tabstop_masks[idx]
}

// unset removes a tabstop at a certain column. The columns are 0-indexed.
// Uses XOR to toggle the bit off (assumes bit is currently set).
pub fn (mut self Tabstops) unset(col u32) {
	i := tabstop_entry(col)
	idx := tabstop_index(col)
	if i < tabstop_prealloc_count {
		self.prealloc_stops[i] ^= tabstop_masks[idx]
		return
	}

	dynamic_i := i - tabstop_prealloc_count
	self.dynamic_stops[dynamic_i] ^= tabstop_masks[idx]
}

// get returns whether a tabstop is set at a specific column. The columns
// are 0-indexed.
pub fn (self Tabstops) get(col u32) bool {
	i := tabstop_entry(col)
	idx := tabstop_index(col)
	mask := tabstop_masks[idx]
	unit := if i < tabstop_prealloc_count {
		self.prealloc_stops[i]
	} else {
		dynamic_i := i - tabstop_prealloc_count
		self.dynamic_stops[dynamic_i]
	}

	return unit & mask == mask
}

// resize adjusts the tabstops to support up to cols columns.
// If cols fits within the preallocated space, no allocation occurs.
// Otherwise, a dynamic slice is allocated or extended.
// TODO: needs interval to set new tabstops
pub fn (mut self Tabstops) resize(cols int) ! {
	// Do nothing if it fits within preallocated space.
	if cols <= tabstop_prealloc_columns {
		self.cols = cols
		return
	}

	// What we need in the dynamic size
	size := cols - tabstop_prealloc_columns
	if size < self.dynamic_stops.len {
		self.cols = cols
		return
	}

	// Allocate new dynamic stops and copy existing data.
	// Note: we could probably try to realloc here but it doesn't matter much.
	mut new_stops := []u8{len: size}
	// Copy existing dynamic data if any
	if self.dynamic_stops.len > 0 {
		for i in 0 .. self.dynamic_stops.len {
			new_stops[i] = self.dynamic_stops[i]
		}
	}

	self.dynamic_stops = new_stops
	self.cols = cols
}

// capacity returns the maximum number of columns this can support currently
// without needing to resize.
pub fn (self Tabstops) capacity() int {
	return (tabstop_prealloc_count + self.dynamic_stops.len) * tabstop_unit_bits
}

// reset unsets all tabstops and then sets tabstops at the given interval.
// An interval of 0 sets no tabstops.
pub fn (mut self Tabstops) reset(interval int) {
	// Clear preallocated stops
	for i in 0 .. tabstop_prealloc_count {
		self.prealloc_stops[i] = 0
	}
	// Clear dynamic stops
	for i in 0 .. self.dynamic_stops.len {
		self.dynamic_stops[i] = 0
	}

	if interval > 0 {
		mut i := interval
		for i < self.cols - 1 {
			self.set(u32(i))
			i += interval
		}
	}
}
