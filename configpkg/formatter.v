module configpkg

import datastruct.comparison

// Generated from the documentation comments in the pinned Ghostty
// config/Config.zig. Records are separated by ASCII record separators so the
// Markdown remains byte-for-byte data rather than V string literals.
const config_help_data = $embed_file('config_help.txt').to_string()

struct ConfigEntryGroup {
	key    string
	values []string
}

// EntryFormatter is config.formatter.EntryFormatter. V strings own their
// storage, so the translated formatter returns the bytes that Zig writes to
// std.Io.Writer while preserving the same name and type-driven entry API.
pub struct EntryFormatter {
pub:
	name string
}

// entry_formatter returns a formatter for one configuration field.
pub fn entry_formatter(name string) EntryFormatter {
	return EntryFormatter{
		name: name
	}
}

// format_entry formats a single value with this formatter's field name.
pub fn (f EntryFormatter) format_entry[T](value T) string {
	return format_entry(f.name, value)
}

// format_entry is config.formatter.formatEntry.
pub fn format_entry[T](name string, value T) string {
	values := format_entry_values(value)
	mut result := ''
	for item in values {
		result += '${name} = ${item}\n'
	}
	return result
}

fn format_entry_values[T](value T) []string {
	$if T is $option {
		if actual := value {
			return format_entry_values(actual)
		}
		return ['']
	} $else $if T is bool {
		return [value.str()]
	} $else $if T is $int {
		return [value.str()]
	} $else $if T is $float {
		return [value.str()]
	} $else $if T is $enum {
		$for method in T.methods {
			$if method.name == 'format_entry' && method.return_type is string {
				return [value.format_entry()]
			}
		}
		return [enum_config_string(value.str())]
	} $else $if T is string {
		return [value]
	} $else $if T is []string {
		return if value.len == 0 { [''] } else { value.clone() }
	} $else $if T is $struct {
		$for method in T.methods {
			$if method.name == 'format_entry' {
				$if method.return_type is string {
					return [value.format_entry()]
				} $else $if method.return_type is []string {
					return value.format_entry()
				} $else $if method.return_type is ?string {
					if formatted := value.format_entry() {
						return [formatted]
					}
					return []
				}
			}
		}

		// Zig's remaining struct case is a packed set of boolean flags.
		mut fields := []string{}
		mut field_count := 0
		mut bool_count := 0
		$for field in T.fields {
			field_count++
			$if field.typ is bool {
				bool_count++
				name := field.name.trim_string_right('_').replace('_', '-')
				fields << if value.$(field.name) { name } else { 'no-${name}' }
			}
		}
		if field_count == 0 || field_count != bool_count {
			panic('missing config formatter case for struct type')
		}
		return [fields.join(',')]
	} $else $if T is $sumtype {
		$for method in T.methods {
			$if method.name == 'format_entry' {
				$if method.return_type is string {
					return [value.format_entry()]
				} $else $if method.return_type is []string {
					return value.format_entry()
				} $else $if method.return_type is ?string {
					if formatted := value.format_entry() {
						return [formatted]
					}
					return []
				}
			}
		}
		panic('missing config formatter case for sum type')
	} $else {
		$compile_error('missing config formatter case for type')
	}
}

// format_config returns this configuration in Ghostty's file syntax. With
// changes_only enabled, fields are compared after finalization against the
// platform defaults and only semantically changed fields are emitted.
pub fn (c Config) format_config(changes_only bool) string {
	return c.format_config_with_docs(changes_only, false)
}

// format_config_with_docs is Ghostty's FileFormatter: it emits each modeled
// public configuration field and optionally places its generated help text
// immediately above the field as configuration comments.
pub fn (c Config) format_config_with_docs(changes_only bool, docs bool) string {
	groups := config_entry_groups(c)
	default_config := Config.default_config()
	mut output := ''
	for group in groups {
		if changes_only && !default_config.changed(&c, group.key) {
			continue
		}
		formatter := entry_formatter(group.key)
		mut documented := false
		if docs {
			if help := config_help(group.key) {
				for line in help.split('\n') {
					output += '# ${line}\n'
				}
				documented = true
			}
		}
		for value in group.values {
			output += formatter.format_entry(value)
		}
		if documented {
			output += '\n'
		}
	}
	return output
}

// changed reports whether one public configuration field differs between two
// configs. Ghostty's API takes its generated Key enum; V uses the equivalent
// hyphenated key spelling. The compile-time field projection is the V
// equivalent of Zig's comptime Key-to-field lookup.
pub fn (c &Config) changed(new &Config, key string) bool {
	if key == 'link' {
		return !c.link.equal(new.link)
	}
	$for field in Config.fields {
		$if !field.is_map {
			if field.name !in ['diagnostics', 'conditional_state', 'link', 'replay_steps',
				'xdg_terminal_exec'] && field.name.replace('_', '-') == key {
				return !comparison.deep_equal(c.$(field.name), new.$(field.name))
			}
		}
	}
	panic('unknown config key: ${key}')
}

fn config_help(key string) ?string {
	marker := '\x1e${key}\n'
	marker_index := config_help_data.index(marker) or { return none }
	start := marker_index + marker.len
	rest := config_help_data[start..]
	end := rest.index_u8(30)
	value := if end < 0 { rest } else { rest[..end] }
	return value.trim_string_right('\n')
}

fn enum_config_string(value string) string {
	if value == 'format_8_bit' {
		return '8-bit'
	}
	if value == 'format_16_bit' {
		return '16-bit'
	}
	return value.trim_string_right('_').replace('_', '-')
}

fn config_entry_groups(c Config) []ConfigEntryGroup {
	mut result := []ConfigEntryGroup{}
	$for field in Config.fields {
		$if !field.is_map {
			$if field.name != 'diagnostics' && field.name != 'xdg_terminal_exec' && field.name != 'conditional_state' && field.name != 'replay_steps' {
				add_value(mut result, field.name.replace('_', '-'), c.$(field.name))
			}
		}
	}
	if result.len != config_keys.len {
		panic('config formatter field count differs from Config.Key')
	}

	mut ordered := []ConfigEntryGroup{cap: config_keys.len}
	for key in config_keys {
		mut found := false
		for group in result {
			if group.key == key {
				ordered << ConfigEntryGroup{
					key: group.key
					values: group.values.clone()
				}
				found = true
				break
			}
		}
		if !found {
			panic('missing config formatter key: ${key}')
		}
	}
	return ordered
}

fn add_group(mut groups []ConfigEntryGroup, key string, values []string) {
	groups << ConfigEntryGroup{
		key: key
		values: values
	}
}

fn add_value[T](mut groups []ConfigEntryGroup, key string, value T) {
	add_group(mut groups, key, format_entry_values(value))
}
