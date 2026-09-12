module terminal

// Tests for the VT parser state transition table.
//
// Source: parse_table.zig tests
//
// The Zig test simply forces comptime-evaluation of the table to
// verify it succeeds in creation. Our equivalent verifies the table
// was generated correctly by checking specific known transitions.

// Test that the table is generated successfully.
// This is the equivalent of the Zig test that just accesses `table`
// to force comptime evaluation.
fn test_table_creation() {
	// Verify the table exists and has the right dimensions.
	// Access a few entries to make sure it's populated.
	t := table
	assert t.len == table_byte_count
	assert t[0].cols.len == table_state_count
}

fn test_transition_action_source_ordinals() {
	assert sizeof(TransitionAction) == 1
	assert int(TransitionAction.ta_none) == 0
	assert int(TransitionAction.ta_ignore) == 1
	assert int(TransitionAction.ta_print) == 2
	assert int(TransitionAction.ta_execute) == 3
	assert int(TransitionAction.ta_collect) == 4
	assert int(TransitionAction.ta_param) == 5
	assert int(TransitionAction.ta_esc_dispatch) == 6
	assert int(TransitionAction.ta_csi_dispatch) == 7
	assert int(TransitionAction.ta_put) == 8
	assert int(TransitionAction.ta_osc_put) == 9
	assert int(TransitionAction.ta_apc_put) == 10
	assert sizeof(Transition) == 2
}

// Test ground state: printable characters produce print action.
fn test_ground_print() {
	tr := table_lookup(u8(`A`), .ground)
	assert tr.state == .ground
	assert tr.action == .ta_print
}

// Test ground state: C0 control characters produce execute action.
fn test_ground_execute() {
	// 0x0A (LF) should produce execute in ground state
	tr := table_lookup(0x0A, .ground)
	assert tr.state == .ground
	assert tr.action == .ta_execute
}

// Test ESC (0x1B) from ground transitions to escape state.
fn test_ground_to_escape() {
	tr := table_lookup(0x1B, .ground)
	assert tr.state == .escape
	assert tr.action == .ta_none
}

// Test CSI entry from escape state (ESC [).
fn test_escape_to_csi_entry() {
	tr := table_lookup(0x5B, .escape)
	assert tr.state == .csi_entry
	assert tr.action == .ta_none
}

// Test CSI param: digits produce param action and stay in csi_param.
fn test_csi_param_digit() {
	tr := table_lookup(u8(`3`), .csi_param)
	assert tr.state == .csi_param
	assert tr.action == .ta_param
}

// Test CSI param: colon produces param action (SGR subparam separator).
fn test_csi_param_colon() {
	tr := table_lookup(0x3A, .csi_param)
	assert tr.state == .csi_param
	assert tr.action == .ta_param
}

// Test CSI param: final byte dispatches and transitions to ground.
fn test_csi_param_final() {
	// 'm' (0x6D) is a common CSI final byte (SGR)
	tr := table_lookup(0x6D, .csi_param)
	assert tr.state == .ground
	assert tr.action == .ta_csi_dispatch
}

// Test OSC string: printable characters produce osc_put.
fn test_osc_string_put() {
	tr := table_lookup(u8(`h`), .osc_string)
	assert tr.state == .osc_string
	assert tr.action == .ta_osc_put
}

// Test OSC string: BEL (0x07) terminates.
fn test_osc_string_bel() {
	tr := table_lookup(0x07, .osc_string)
	assert tr.state == .ground
	assert tr.action == .ta_none
}

// Test anywhere transition: 0x9B (CSI) from any state.
fn test_anywhere_csi() {
	tr := table_lookup(0x9B, .ground)
	assert tr.state == .csi_entry
	assert tr.action == .ta_none

	// In osc_string, 0x9B is in the 0x20-0xFF range which overrides
	// the anywhere transition, so it stays in osc_string with osc_put.
	tr2 := table_lookup(0x9B, .osc_string)
	assert tr2.state == .osc_string
	assert tr2.action == .ta_osc_put
}

// Test DCS entry transitions.
fn test_dcs_entry_to_passthrough() {
	// Final byte in DCS entry goes to dcs_passthrough
	tr := table_lookup(0x40, .dcs_entry)
	assert tr.state == .dcs_passthrough
	assert tr.action == .ta_none
}

// Test DCS passthrough: data bytes produce put action.
fn test_dcs_passthrough_put() {
	tr := table_lookup(u8(`x`), .dcs_passthrough)
	assert tr.state == .dcs_passthrough
	assert tr.action == .ta_put
}

// Test SOS/PM/APC string: data bytes produce apc_put action.
fn test_apc_put() {
	tr := table_lookup(u8(`z`), .sos_pm_apc_string)
	assert tr.state == .sos_pm_apc_string
	assert tr.action == .ta_apc_put
}
