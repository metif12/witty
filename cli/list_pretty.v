// TTY presentation for the list-colors and list-keybinds actions.
//
// Translated from ghostty/src/cli/list_colors.zig and list_keybinds.zig. The
// pinned source uses vaxis windows to produce this stream; Witty emits the
// equivalent styled rows directly because its small vaxis compatibility
// module does not retain an off-screen cell window.
module cli

import configpkg
import input
import strings
import terminal

const unicode_mode_set = '\x1b[?2027h'
const unicode_mode_reset = '\x1b[?2027l'

fn ansi_index(text string, index u8, bold bool, dim bool) string {
	mut codes := ['38;5;${index}']
	if bold {
		codes << '1'
	}
	if dim {
		codes << '2'
	}
	return '\x1b[${codes.join(';')}m${text}\x1b[0m'
}

fn ansi_rgb_foreground(text string, rgb terminal.RGB) string {
	return '\x1b[38;2;${rgb.r};${rgb.g};${rgb.b}m${text}\x1b[0m'
}

fn ansi_rgb_swatch(rgb terminal.RGB) string {
	return '\x1b[38;2;${rgb.r};${rgb.g};${rgb.b};48;2;${rgb.r};${rgb.g};${rgb.b}m  \x1b[0m'
}

// list_colors_pretty_output lays the sorted color list out in terminal-width
// columns, using the same column-major order and truecolor styles as Ghostty.
pub fn list_colors_pretty_output(entries []terminal.NamedRGB, terminal_width int) string {
	if entries.len == 0 {
		return unicode_mode_set + unicode_mode_reset
	}
	mut max_name_len := 0
	for entry in entries {
		if entry.name.len > max_name_len {
			max_name_len = entry.name.len
		}
	}
	column_size := max_name_len + 15
	columns := (terminal_width + 2) / column_size
	if columns == 0 {
		panic('terminal is too narrow for list-colors')
	}
	step := entries.len / columns + 1
	mut out := strings.new_builder(entries.len * 32)
	out.write_string(unicode_mode_set)
	for row in 0 .. step {
		mut visible_width := 0
		for column in 0 .. columns {
			index := row + step * column
			if index >= entries.len {
				continue
			}
			entry := entries[index]
			out.write_string(entry.name)
			padding := max_name_len - entry.name.len
			out.write_string(' '.repeat(padding))
			out.write_string(' = ')
			hex := '#${entry.rgb.r:02x}${entry.rgb.g:02x}${entry.rgb.b:02x}'
			out.write_string(ansi_rgb_foreground(hex, entry.rgb))
			out.write_u8(` `)
			out.write_string(ansi_rgb_swatch(entry.rgb))
			visible_width += column_size - 2
			if column + 1 < columns {
				out.write_string('  ')
				visible_width += 2
			}
		}
		if terminal_width > visible_width {
			out.write_string(' '.repeat(terminal_width - visible_width))
		}
		out.write_u8(`\n`)
	}
	out.write_string(unicode_mode_reset)
	return out.str()
}

struct PrettyBinding {
	has_table  bool
	table_name string
	triggers   []input.Trigger
	actions    []input.Action
}

fn collect_pretty_bindings(set &input.Set, prefix []input.Trigger, table_name string, has_table bool, mut result []PrettyBinding) {
	for entry in set.bindings {
		mut triggers := prefix.clone()
		triggers << entry.trigger
		match entry.value.typ {
			.leader {
				collect_pretty_bindings(entry.value.leader, triggers, table_name, has_table, mut
					result)
			}
			.leaf {
				result << PrettyBinding{
					has_table:  has_table
					table_name: table_name
					triggers:   triggers
					actions:    [entry.value.leaf_action]
				}
			}
			.leaf_chained {
				result << PrettyBinding{
					has_table:  has_table
					table_name: table_name
					triggers:   triggers
					actions:    entry.value.chain_actions
				}
			}
		}
	}
}

fn trigger_modifier_count(trigger input.Trigger) int {
	mut count := 0
	if trigger.mods.super_() {
		count++
	}
	if trigger.mods.ctrl() {
		count++
	}
	if trigger.mods.shift() {
		count++
	}
	if trigger.mods.alt() {
		count++
	}
	return count
}

fn binding_modifier_count(binding PrettyBinding) int {
	mut count := 0
	for trigger in binding.triggers {
		count += trigger_modifier_count(trigger)
	}
	return count
}

fn trigger_key_order(trigger input.Trigger) int {
	return match trigger.key.typ {
		.physical { int(trigger.key.physical) }
		.unicode { int(trigger.key.unicode) }
		.catch_all { 0x7fffffff }
	}
}

fn pretty_binding_less(lhs PrettyBinding, rhs PrettyBinding) bool {
	if lhs.has_table != rhs.has_table {
		return !lhs.has_table
	}
	if lhs.has_table && lhs.table_name != rhs.table_name {
		return lhs.table_name < rhs.table_name
	}
	if lhs.triggers.len != rhs.triggers.len {
		return lhs.triggers.len > rhs.triggers.len
	}
	lhs_count := binding_modifier_count(lhs)
	rhs_count := binding_modifier_count(rhs)
	if lhs_count != rhs_count {
		return lhs_count > rhs_count
	}
	for index in 0 .. lhs.triggers.len {
		lhs_mods := lhs.triggers[index].mods.int()
		rhs_mods := rhs.triggers[index].mods.int()
		if lhs_mods != rhs_mods {
			return lhs_mods > rhs_mods
		}
	}
	for index in 0 .. lhs.triggers.len {
		lhs_key := trigger_key_order(lhs.triggers[index])
		rhs_key := trigger_key_order(rhs.triggers[index])
		if lhs_key != rhs_key {
			return lhs_key < rhs_key
		}
	}
	return false
}

fn pretty_binding_compare(lhs &PrettyBinding, rhs &PrettyBinding) int {
	if pretty_binding_less(*lhs, *rhs) {
		return -1
	}
	if pretty_binding_less(*rhs, *lhs) {
		return 1
	}
	return 0
}

fn trigger_key_text(trigger input.Trigger) string {
	return match trigger.key.typ {
		.physical { trigger.key.physical.key_name() }
		.unicode { rune(trigger.key.unicode).str() }
		.catch_all { 'catch_all' }
	}
}

fn trigger_pretty_width(trigger input.Trigger) int {
	mut width := trigger_key_text(trigger).runes().len
	if trigger.mods.super_() {
		width += 8
	}
	if trigger.mods.ctrl() {
		width += 8
	}
	if trigger.mods.alt() {
		width += 8
	}
	if trigger.mods.shift() {
		width += 8
	}
	return width
}

fn binding_pretty_width(binding PrettyBinding) int {
	mut width := 0
	for index, trigger in binding.triggers {
		if index > 0 {
			width += 5
		}
		width += trigger_pretty_width(trigger)
	}
	return width
}

fn write_pretty_trigger(mut out strings.Builder, trigger input.Trigger) int {
	mut width := 0
	if trigger.mods.super_() {
		out.write_string(ansi_index('super', 1, false, false))
		out.write_string(' + ')
		width += 8
	}
	if trigger.mods.ctrl() {
		out.write_string(ansi_index('ctrl ', 2, false, false))
		out.write_string(' + ')
		width += 8
	}
	if trigger.mods.alt() {
		out.write_string(ansi_index('alt  ', 3, false, false))
		out.write_string(' + ')
		width += 8
	}
	if trigger.mods.shift() {
		out.write_string(ansi_index('shift', 4, false, false))
		out.write_string(' + ')
		width += 8
	}
	key := trigger_key_text(trigger)
	out.write_string(key)
	return width + key.runes().len
}

// list_keybinds_pretty_output recursively flattens chords and key tables,
// orders them with Ghostty's ChordBinding.lessThan rules, and styles each row.
pub fn list_keybinds_pretty_output(keybinds configpkg.Keybinds) string {
	mut bindings := []PrettyBinding{}
	collect_pretty_bindings(&keybinds.set, [], '', false, mut bindings)
	for table_name, table in keybinds.tables {
		collect_pretty_bindings(&table, [], table_name, true, mut bindings)
	}
	bindings.sort_with_compare(pretty_binding_compare)

	mut widest_chord := 0
	mut widest_table_prefix := 0
	for binding in bindings {
		chord_width := binding_pretty_width(binding)
		if chord_width > widest_chord {
			widest_chord = chord_width
		}
		if binding.has_table {
			table_width := binding.table_name.runes().len + 1
			if table_width > widest_table_prefix {
				widest_table_prefix = table_width
			}
		}
	}
	action_column := widest_table_prefix + widest_chord + 3
	mut out := strings.new_builder(bindings.len * 80)
	out.write_string(unicode_mode_set)
	for binding in bindings {
		mut column := 0
		if binding.has_table {
			out.write_string(ansi_index(binding.table_name, 8, false, false))
			out.write_string(ansi_index('/', 8, false, false))
			column += binding.table_name.runes().len + 1
		}
		for index, trigger in binding.triggers {
			if index > 0 {
				out.write_string(ansi_index('  >  ', 6, true, false))
				column += 5
			}
			column += write_pretty_trigger(mut out, trigger)
		}
		if action_column > column {
			out.write_string(' '.repeat(action_column - column))
		}
		for index, action_value in binding.actions {
			if index > 0 {
				out.write_string('\x1b[2m, \x1b[0m')
			}
			action := action_value.format()
			colon := action.index_u8(`:`)
			if colon >= 0 {
				out.write_string(action[..colon])
				out.write_string('\x1b[2m:\x1b[0m')
				out.write_string(ansi_index(action[colon + 1..], 5, false, false))
			} else {
				out.write_string(action)
			}
		}
		out.write_u8(`\n`)
	}
	out.write_string(unicode_mode_reset)
	return out.str()
}
