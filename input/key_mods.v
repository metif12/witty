module input

// Modifier remapping. See key-remap in Config for detailed docs.

// Mod represents a single modifier key.
pub enum Mod {
	shift
	ctrl
	alt
	super_
}

// Aliases for modifier names.
const mod_aliases = {
	'cmd':     Mod.super_
	'command': Mod.super_
	'opt':     Mod.alt
	'option':  Mod.alt
	'control': Mod.ctrl
}

// RemapSet contains a set of modifier remappings.
// Modifier remapping allows users to remap one modifier key to another.
pub struct RemapSet {
pub mut:
	// Available mappings: maps from-mods to to-mods.
	entries []RemapEntry
	// Mask of which modifier keys have remappings registered.
	mask RemapMask
}

// RemapEntry is a single from→to modifier mapping.
pub struct RemapEntry {
pub:
	from Mods
	to   Mods
}

// RemapMask tracks which modifier keys and sides have remappings registered.
// Used as a fast pre-check before doing expensive lookups.
pub struct RemapMask {
pub mut:
	// Which modifier keys (shift/ctrl/alt/super) have any remapping.
	keys_mask u8
	// Which modifiers have left-side remappings.
	left_sides u8
	// Which modifiers have right-side remappings.
	right_sides u8
}

// update adds a modifier to the mask, marking it as having a remapping.
pub fn (mut m RemapMask) update(mods Mods) {
	keys := mods.keys_int()
	side_bits := mods.sides_int()

	m.keys_mask |= keys

	// Update left_sides: set bit if this key is active AND side is left.
	// Since left=0, we invert sides (~sides) so left becomes 1.
	m.left_sides |= (keys & ~side_bits) & 0x0f

	// Update right_sides: set bit if this key is active AND side is right.
	m.right_sides |= (keys & side_bits) & 0x0f
}

// does_match returns true if the given mods match any remapping in this mask.
pub fn (m RemapMask) does_match(mods Mods) bool {
	// Find which pressed keys have remappings registered.
	active := mods.keys_int() & m.keys_mask
	if active == 0 {
		return false
	}

	sides := mods.sides_int()
	side_match := (~sides & m.left_sides) | (sides & m.right_sides)

	return (active & side_match & 0x0f) != 0
}

// keys_int returns a 4-bit mask of which standard modifier keys are set.
// Bit 0=shift, 1=ctrl, 2=alt, 3=super.
pub fn (m Mods) keys_int() u8 {
	mut v := u8(0)
	if m.shift {
		v |= 1
	}
	if m.ctrl {
		v |= 2
	}
	if m.alt {
		v |= 4
	}
	if m.super_ {
		v |= 8
	}
	return v
}

// sides_int returns a 4-bit mask of which sides are right.
// Each bit corresponds to shift/ctrl/alt/super. 0=left, 1=right.
pub fn (m Mods) sides_int() u8 {
	mut v := u8(0)
	if m.sides.shift == .right {
		v |= 1
	}
	if m.sides.ctrl == .right {
		v |= 2
	}
	if m.sides.alt == .right {
		v |= 4
	}
	return v
}

// without_locks returns mods without lock keys set.
pub fn (m Mods) without_locks() Mods {
	return Mods{
		shift: m.shift
		ctrl: m.ctrl
		alt: m.alt
		super_: m.super_
		sides: m.sides
	}
}

// ctrl_or_super checks if super is on (macOS) or ctrl.
pub fn (m Mods) ctrl_or_super() bool {
	// On macOS, use super (command) key
	return m.super_
}

// ctrl_or_super_mods sets either ctrl or super (but not both) on mods.
// On Mac, sets super. On non-Mac, sets ctrl.
pub fn ctrl_or_super_mods(m Mods) Mods {
	mut copy := m
	// On macOS, default to super (command)
	copy.super_ = true
	return copy
}

// parse parses a modifier remap string like "ctrl=super" or "left_alt=ctrl"
// and adds it to the set.
pub fn (mut s RemapSet) parse(inp string) ! {
	// Find the assignment point ('=')
	eql_idx := inp.index_u8(`=`)
	if eql_idx < 0 {
		return error('missing assignment')
	}

	// Parse the "to" side (defaults to left if no explicit side)
	to_str := inp[eql_idx + 1..]
	to_mod, to_side_opt := parse_mod(to_str)!
	to_side := to_side_opt or { Side.left }
	to_mods := init_mods(to_mod, to_side)

	// Parse the "from" side
	from_str := inp[..eql_idx]
	from_mod, from_side_opt := parse_mod(from_str)!

	if from_side := from_side_opt {
		// Sided from: add single mapping
		from_mods := init_mods(from_mod, from_side)
		s.entries << RemapEntry{
			from: from_mods
			to: to_mods
		}
		s.mask.update(from_mods)
	} else {
		// Unsided from: add both left and right mappings
		from_left := init_mods(from_mod, .left)
		from_right := init_mods(from_mod, .right)
		s.entries << RemapEntry{
			from: from_left
			to: to_mods
		}
		s.entries << RemapEntry{
			from: from_right
			to: to_mods
		}
		s.mask.update(from_left)
		s.mask.update(from_right)
	}
}

// finalize must be called prior to any remappings so that the mapping
// is sorted properly. Right-sided entries sort first.
pub fn (mut s RemapSet) finalize() {
	// Sort so that entries with right sides come first
	s.entries.sort_with_compare(fn (a &RemapEntry, b &RemapEntry) int {
		a_has_right := a.from.sides_int() != 0
		b_has_right := b.from.sides_int() != 0
		if a_has_right && !b_has_right {
			return -1
		}
		if !a_has_right && b_has_right {
			return 1
		}
		return 0
	})
}

// is_remapped returns true if the given mods need remapping.
pub fn (s RemapSet) is_remapped(mods Mods) bool {
	return s.mask.does_match(mods)
}

// apply applies a remap to the given mods.
pub fn (s RemapSet) apply(mods Mods) Mods {
	if !s.is_remapped(mods) {
		return mods
	}

	mods_binding := mods.keys_int()
	mods_sides := mods.sides_int()

	for entry in s.entries {
		from_binding := entry.from.keys_int()
		if mods_binding & from_binding != from_binding {
			continue
		}
		from_sides := entry.from.sides_int()
		if (mods_sides ^ from_sides) & from_binding != 0 {
			continue
		}

		// Found a match - apply the remap
		mut mods_int := mods.int()
		mods_int &= ~entry.from.int()
		mods_int |= entry.to.int()
		return mods_from_int(mods_int)
	}

	return mods
}

// parse_mod parses a single modifier string like "ctrl", "left_shift", "cmd".
// Returns the Mod and an optional Side.
fn parse_mod(inp string) !(Mod, ?Side) {
	// Check for side prefix
	underscore_idx := inp.index_u8(`_`)
	mut side_str := ''
	mut mod_str := inp
	if underscore_idx >= 0 {
		side_str = inp[..underscore_idx]
		mod_str = inp[underscore_idx + 1..]
	}

	// Parse the modifier name
	mod_val := if mod_str == 'shift' {
		Mod.shift
	} else if mod_str == 'ctrl' {
		Mod.ctrl
	} else if mod_str == 'alt' {
		Mod.alt
	} else if mod_str == 'super' || mod_str == 'super_' {
		Mod.super_
	} else if mod_str in mod_aliases {
		mod_aliases[mod_str]
	} else {
		return error('invalid modifier: ${mod_str}')
	}

	// Parse optional side
	if side_str.len > 0 {
		side_val := if side_str == 'left' {
			Side.left
		} else if side_str == 'right' {
			Side.right
		} else {
			return error('invalid side: ${side_str}')
		}
		return mod_val, side_val
	}

	return mod_val, none
}

// init_mods creates a Mods with a single modifier set on the given side.
fn init_mods(mod_val Mod, side Side) Mods {
	mut m := Mods{}
	match mod_val {
		.shift {
			m.shift = true
			m.sides.shift = side
		}
		.ctrl {
			m.ctrl = true
			m.sides.ctrl = side
		}
		.alt {
			m.alt = true
			m.sides.alt = side
		}
		.super_ {
			m.super_ = true
			// SideInfo doesn't have super field, store in a compatible way
		}
	}
	return m
}

// mods_from_int reconstructs Mods from a u16 integer value.
fn mods_from_int(v u16) Mods {
	return Mods{
		shift: (v & 1) != 0
		ctrl: (v & 2) != 0
		alt: (v & 4) != 0
		super_: (v & 8) != 0
	}
}
