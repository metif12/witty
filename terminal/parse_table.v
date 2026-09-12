module terminal

// The primary export of this file is "table", which contains a
// state transition table for VT emulation.
//
// This is based on the vt100.net state machine:
// https://vt100.net/emu/dec_ansi_parser
// But has some modifications:
//
//   * csi_param accepts the colon character (':') since the SGR command
//     accepts colon as a valid parameter value.
//
// Source: parse_table.zig
//
// In Zig, this table is generated at comptime. In V, we generate it
// at module init time using the same transition logic.

// ============================================================
// TransitionAction - actions taken during state transitions
// ============================================================

// TransitionAction is an action that can be taken during a state
// transition. This is more of an internal action, not one used by
// end users, typically.
pub enum TransitionAction {
	ta_none
	ta_ignore
	ta_print
	ta_execute
	ta_collect
	ta_param
	ta_esc_dispatch
	ta_csi_dispatch
	ta_put
	ta_osc_put
	ta_apc_put
}

// ============================================================
// Transition - a (state, action) pair for the table
// ============================================================

// Transition is the transition to take within the table.
// Given a current state and input byte, the table returns
// the new state and the action to perform.
pub struct Transition {
pub:
	state  ParserState
	action TransitionAction
}

// ============================================================
// Table type and dimensions
// ============================================================

// The number of possible input bytes (0x00..0xFF).
const table_byte_count = 256

// The number of parser states.
const table_state_count = 14

// TransitionRow wraps [14]Transition to work around a V compiler bug
// where nested fixed-size arrays of structs ([256][14]Transition) don't
// get proper C type declarations.
pub struct TransitionRow {
pub mut:
	cols [14]Transition
}

// Table is the exactly-sized state transition table. TransitionRow is a V
// adapter for the nested fixed array used by Ghostty.
pub type Table = [256]TransitionRow

// ============================================================
// Table generation
// ============================================================

// gen_table generates the full state transition table for VT emulation.
// This is the V equivalent of the Zig comptime genTable() function.
fn gen_table() Table {
	// We accumulate using an "optional" table so we can detect duplicates.
	// In V we use a sentinel value (ta_none with ground) as "unset" and
	// track which entries have been explicitly set via a separate bool table.
	mut set := [256][14]bool{}
	mut result := [256]TransitionRow{}

	// Initialize everything to default (none/ground).
	for i in 0 .. table_byte_count {
		for j in 0 .. table_state_count {
			result[i].cols[j] = Transition{
				state: .ground
				action: .ta_none
			}
			set[i][j] = false
		}
	}

	// Helper closures are not available in V module scope,
	// so we inline the logic using helper functions below.

	// anywhere transitions: for every source state, set global transitions
	for s in 0 .. table_state_count {
		source := unsafe { ParserState(s) }

		// anywhere => ground
		table_single(mut result, mut set, 0x18, source, .ground, .ta_execute)
		table_single(mut result, mut set, 0x1A, source, .ground, .ta_execute)
		table_range(mut result, mut set, 0x80, 0x8F, source, .ground, .ta_execute)
		table_range(mut result, mut set, 0x91, 0x97, source, .ground, .ta_execute)
		table_single(mut result, mut set, 0x99, source, .ground, .ta_execute)
		table_single(mut result, mut set, 0x9A, source, .ground, .ta_execute)
		table_single(mut result, mut set, 0x9C, source, .ground, .ta_none)

		// anywhere => escape
		table_single(mut result, mut set, 0x1B, source, .escape, .ta_none)

		// anywhere => sos_pm_apc_string
		table_single(mut result, mut set, 0x98, source, .sos_pm_apc_string, .ta_none)
		table_single(mut result, mut set, 0x9E, source, .sos_pm_apc_string, .ta_none)
		table_single(mut result, mut set, 0x9F, source, .sos_pm_apc_string, .ta_none)

		// anywhere => csi_entry
		table_single(mut result, mut set, 0x9B, source, .csi_entry, .ta_none)

		// anywhere => dcs_entry
		table_single(mut result, mut set, 0x90, source, .dcs_entry, .ta_none)

		// anywhere => osc_string
		table_single(mut result, mut set, 0x9D, source, .osc_string, .ta_none)
	}

	// ground
	{
		table_single(mut result, mut set, 0x19, .ground, .ground, .ta_execute)
		table_range(mut result, mut set, 0, 0x17, .ground, .ground, .ta_execute)
		table_range(mut result, mut set, 0x1C, 0x1F, .ground, .ground, .ta_execute)
		table_range(mut result, mut set, 0x20, 0x7F, .ground, .ground, .ta_print)
	}

	// escape_intermediate
	{
		source := ParserState.escape_intermediate

		table_single(mut result, mut set, 0x19, source, source, .ta_execute)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_execute)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_execute)
		table_range(mut result, mut set, 0x20, 0x2F, source, source, .ta_collect)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => ground
		table_range(mut result, mut set, 0x30, 0x7E, source, .ground, .ta_esc_dispatch)
	}

	// sos_pm_apc_string
	{
		source := ParserState.sos_pm_apc_string

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_apc_put)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_apc_put)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_apc_put)
		table_range(mut result, mut set, 0x20, 0x7F, source, source, .ta_apc_put)
	}

	// escape
	{
		source := ParserState.escape

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_execute)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_execute)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_execute)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => ground
		table_range(mut result, mut set, 0x30, 0x4F, source, .ground, .ta_esc_dispatch)
		table_range(mut result, mut set, 0x51, 0x57, source, .ground, .ta_esc_dispatch)
		table_range(mut result, mut set, 0x60, 0x7E, source, .ground, .ta_esc_dispatch)
		table_single(mut result, mut set, 0x59, source, .ground, .ta_esc_dispatch)
		table_single(mut result, mut set, 0x5A, source, .ground, .ta_esc_dispatch)
		table_single(mut result, mut set, 0x5C, source, .ground, .ta_esc_dispatch)

		// => escape_intermediate
		table_range(mut result, mut set, 0x20, 0x2F, source, .escape_intermediate, .ta_collect)

		// => sos_pm_apc_string
		table_single(mut result, mut set, 0x58, source, .sos_pm_apc_string, .ta_none)
		table_single(mut result, mut set, 0x5E, source, .sos_pm_apc_string, .ta_none)
		table_single(mut result, mut set, 0x5F, source, .sos_pm_apc_string, .ta_none)

		// => dcs_entry
		table_single(mut result, mut set, 0x50, source, .dcs_entry, .ta_none)

		// => csi_entry
		table_single(mut result, mut set, 0x5B, source, .csi_entry, .ta_none)

		// => osc_string
		table_single(mut result, mut set, 0x5D, source, .osc_string, .ta_none)
	}

	// dcs_entry
	{
		source := ParserState.dcs_entry

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_ignore)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_ignore)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => dcs_intermediate
		table_range(mut result, mut set, 0x20, 0x2F, source, .dcs_intermediate, .ta_collect)

		// => dcs_ignore
		table_single(mut result, mut set, 0x3A, source, .dcs_ignore, .ta_none)

		// => dcs_param
		table_range(mut result, mut set, 0x30, 0x39, source, .dcs_param, .ta_param)
		table_single(mut result, mut set, 0x3B, source, .dcs_param, .ta_param)
		table_range(mut result, mut set, 0x3C, 0x3F, source, .dcs_param, .ta_collect)

		// => dcs_passthrough
		table_range(mut result, mut set, 0x40, 0x7E, source, .dcs_passthrough, .ta_none)
	}

	// dcs_intermediate
	{
		source := ParserState.dcs_intermediate

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_ignore)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x20, 0x2F, source, source, .ta_collect)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => dcs_ignore
		table_range(mut result, mut set, 0x30, 0x3F, source, .dcs_ignore, .ta_none)

		// => dcs_passthrough
		table_range(mut result, mut set, 0x40, 0x7E, source, .dcs_passthrough, .ta_none)
	}

	// dcs_ignore
	{
		source := ParserState.dcs_ignore

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_ignore)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_ignore)
	}

	// dcs_param
	{
		source := ParserState.dcs_param

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_ignore)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x30, 0x39, source, source, .ta_param)
		table_single(mut result, mut set, 0x3B, source, source, .ta_param)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => dcs_ignore
		table_single(mut result, mut set, 0x3A, source, .dcs_ignore, .ta_none)
		table_range(mut result, mut set, 0x3C, 0x3F, source, .dcs_ignore, .ta_none)

		// => dcs_intermediate
		table_range(mut result, mut set, 0x20, 0x2F, source, .dcs_intermediate, .ta_collect)

		// => dcs_passthrough
		table_range(mut result, mut set, 0x40, 0x7E, source, .dcs_passthrough, .ta_none)
	}

	// dcs_passthrough
	{
		source := ParserState.dcs_passthrough

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_put)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_put)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_put)
		table_range(mut result, mut set, 0x20, 0x7E, source, source, .ta_put)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)
	}

	// csi_param
	{
		source := ParserState.csi_param

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_execute)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_execute)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_execute)
		table_range(mut result, mut set, 0x30, 0x39, source, source, .ta_param)
		table_single(mut result, mut set, 0x3A, source, source, .ta_param)
		table_single(mut result, mut set, 0x3B, source, source, .ta_param)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => ground
		table_range(mut result, mut set, 0x40, 0x7E, source, .ground, .ta_csi_dispatch)

		// => csi_ignore
		table_range(mut result, mut set, 0x3C, 0x3F, source, .csi_ignore, .ta_none)

		// => csi_intermediate
		table_range(mut result, mut set, 0x20, 0x2F, source, .csi_intermediate, .ta_collect)
	}

	// csi_ignore
	{
		source := ParserState.csi_ignore

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_execute)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_execute)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_execute)
		table_range(mut result, mut set, 0x20, 0x3F, source, source, .ta_ignore)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => ground
		table_range(mut result, mut set, 0x40, 0x7E, source, .ground, .ta_none)
	}

	// csi_intermediate
	{
		source := ParserState.csi_intermediate

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_execute)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_execute)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_execute)
		table_range(mut result, mut set, 0x20, 0x2F, source, source, .ta_collect)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => ground
		table_range(mut result, mut set, 0x40, 0x7E, source, .ground, .ta_csi_dispatch)

		// => csi_ignore
		table_range(mut result, mut set, 0x30, 0x3F, source, .csi_ignore, .ta_none)
	}

	// csi_entry
	{
		source := ParserState.csi_entry

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_execute)
		table_range(mut result, mut set, 0, 0x17, source, source, .ta_execute)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_execute)
		table_single(mut result, mut set, 0x7F, source, source, .ta_ignore)

		// => ground
		table_range(mut result, mut set, 0x40, 0x7E, source, .ground, .ta_csi_dispatch)

		// => csi_ignore
		table_single(mut result, mut set, 0x3A, source, .csi_ignore, .ta_none)

		// => csi_intermediate
		table_range(mut result, mut set, 0x20, 0x2F, source, .csi_intermediate, .ta_collect)

		// => csi_param
		table_range(mut result, mut set, 0x30, 0x39, source, .csi_param, .ta_param)
		table_single(mut result, mut set, 0x3B, source, .csi_param, .ta_param)
		table_range(mut result, mut set, 0x3C, 0x3F, source, .csi_param, .ta_collect)
	}

	// osc_string
	{
		source := ParserState.osc_string

		// events
		table_single(mut result, mut set, 0x19, source, source, .ta_ignore)
		table_range(mut result, mut set, 0, 0x06, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x08, 0x17, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x1C, 0x1F, source, source, .ta_ignore)
		table_range(mut result, mut set, 0x20, 0xFF, source, source, .ta_osc_put)

		// XTerm accepts either BEL or ST for terminating OSC
		// sequences, and when returning information, uses the same
		// terminator used in a query.
		table_single(mut result, mut set, 0x07, source, .ground, .ta_none)
	}

	// Fill in any unset entries with the default transition:
	// stay in the same state with no action.
	for i in 0 .. table_byte_count {
		for j in 0 .. table_state_count {
			if !set[i][j] {
				result[i].cols[j] = Transition{
					state: unsafe { ParserState(j) }
					action: .ta_none
				}
			}
		}
	}

	return result
}

// table_single sets a single transition in the table for a given
// input byte and source state.
fn table_single(mut t [256]TransitionRow, mut s [256][14]bool, c u8, s0 ParserState, s1 ParserState, a TransitionAction) {
	si := int(s0)
	t[c].cols[si] = Transition{
		state: s1
		action: a
	}
	s[c][si] = true
}

// table_range sets transitions for a range of input bytes [from, to]
// inclusive for a given source state.
fn table_range(mut t [256]TransitionRow, mut s [256][14]bool, from int, to int, s0 ParserState, s1 ParserState, a TransitionAction) {
	for i in from .. to + 1 {
		table_single(mut t, mut s, u8(i), s0, s1, a)
	}
}

// ============================================================
// The global transition table instance
// ============================================================

// The state transition table. Indexed as:
//   table[input_byte].cols[state] -> Transition
//
// The table maps (state, input_byte) -> (action, new_state).
// This is the V equivalent of the Zig comptime-generated `table` constant.
pub const table = gen_table()

// ============================================================
// Lookup helper
// ============================================================

// lookup retrieves the transition for a given input byte and current state.
pub fn table_lookup(c u8, state ParserState) Transition {
	return table[c].cols[int(state)]
}
