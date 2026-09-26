module renderer

import input
import terminal

fn link_test_state() !terminal.RenderState {
	mut term := terminal.Terminal.init(terminal.Options{ cols: 5, rows: 3 })!
	mut stream := term.vt_stream()
	stream.next_slice('1ABCD2EFGH\r\n3IJKL'.bytes())!
	stream.deinit()
	mut state := terminal.RenderState.empty()
	state.update(mut term)
	term.deinit()
	return state
}

fn test_render_cell_map() ! {
	mut state := link_test_state()!
	defer {
		state.deinit()
	}
	mut links := LinkSet.from_config([
		input.Link{ regex: 'AB', action: .open, highlight: .always },
		input.Link{ regex: 'EF', action: .open, highlight: .always },
	])!
	defer {
		links.deinit()
	}
	mut result := terminal.CellSet{}
	links.render_cell_map(mut result, &state, none, input.Mods{})!
	assert !result[u64(0) << 32 | 0]
	assert result[u64(0) << 32 | 1]
	assert result[u64(0) << 32 | 2]
	assert !result[u64(0) << 32 | 3]
	assert result[u64(1) << 32 | 1]
	assert !result[u64(2) << 32 | 1]
}

fn test_render_cell_map_hover() ! {
	mut state := link_test_state()!
	defer {
		state.deinit()
	}
	mut links := LinkSet.from_config([
		input.Link{ regex: 'AB', action: .open, highlight: .hover },
		input.Link{ regex: 'EF', action: .open, highlight: .always },
	])!
	defer {
		links.deinit()
	}
	mut result := terminal.CellSet{}
	links.render_cell_map(mut result, &state, none, input.Mods{})!
	assert !result[u64(0) << 32 | 1]
	assert result[u64(1) << 32 | 1]

	result = terminal.CellSet{}
	links.render_cell_map(mut result, &state, terminal.Coordinate{ x: 1, y: 0 }, input.Mods{})!
	assert result[u64(0) << 32 | 1]
	assert result[u64(0) << 32 | 2]
	assert result[u64(1) << 32 | 1]
}

fn test_render_cell_map_modifiers() ! {
	mut state := link_test_state()!
	defer {
		state.deinit()
	}
	mut links := LinkSet.from_config([
		input.Link{
			regex: 'EF'
			action: .open
			highlight: .always_mods
			mods: input.Mods.init(false, true, false, false, false, false, input.SideInfo{})
		},
	])!
	defer {
		links.deinit()
	}
	mut result := terminal.CellSet{}
	links.render_cell_map(mut result, &state, none, input.Mods{})!
	assert result.len == 0
	links.render_cell_map(mut result, &state, none, input.Mods.init(false, true, false, false, false, false, input.SideInfo{}))!
	assert result[u64(1) << 32 | 1]
}
