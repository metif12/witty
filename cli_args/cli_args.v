module cli_args

import comma_splitter
import diagnostics
import zig_fmt

// TODO:
//   - Only `--long=value` format is accepted. Do we want to allow
//     `--long value`? Not currently allowed.

// For trimming
pub const whitespace = ' \t'

// parse_argument_string translates std.process.ArgIteratorGeneral(.{}), used
// by the benchmark and synthetic C/string entry points. Single quotes are
// ordinary characters; double quotes and backslash parity follow Zig's
// general process-argument iterator.
pub fn parse_argument_string(input string) []string {
	mut args := []string{}
	mut index := 0
	for {
		for index < input.len && input[index] in [` `, `\t`, `\r`, `\n`] {
			index++
		}
		if index >= input.len {
			break
		}

		mut token := []u8{}
		mut backslash_count := 0
		mut in_quote := false
		for {
			character := if index < input.len { input[index] } else { u8(0) }
			if character == 0 {
				for _ in 0 .. backslash_count {
					token << `\\`
				}
				args << token.bytestr()
				return args
			}
			if character == `'` {
				for _ in 0 .. backslash_count {
					token << `\\`
				}
				backslash_count = 0
				token << character
				index++
				continue
			}
			if character == `"` {
				quote_is_real := backslash_count % 2 == 0
				for _ in 0 .. backslash_count / 2 {
					token << `\\`
				}
				backslash_count = 0
				if quote_is_real {
					in_quote = !in_quote
				} else {
					token << `"`
				}
				index++
				continue
			}
			if character == `\\` {
				backslash_count++
				index++
				continue
			}
			if character in [` `, `\t`, `\r`, `\n`] {
				for _ in 0 .. backslash_count {
					token << `\\`
				}
				backslash_count = 0
				if in_quote {
					token << character
					index++
					continue
				}
				args << token.bytestr()
				index++
				break
			}
			for _ in 0 .. backslash_count {
				token << `\\`
			}
			backslash_count = 0
			token << character
			index++
		}
	}
	return args
}

// The function type for a compatibility handler. The compatibility
// handler is documented in the `parse` function documentation.
//
// The function type should return bool if the compatibility was
// handled, and false otherwise. If false is returned then the
// naturally occurring error will continue to be processed as if
// this compatibility handler was not present.
//
// Compatibility handlers aren't allowed to return errors because
// they're generally only called in error cases, so we already have
// an error message to show users. If there is an error in handling
// the compatibility, then the handler should return false.
pub type CompatibilityHandler = fn (key string, value string) bool

// Parse the command line arguments from args into dst.
//
// dst must be a struct. The fields and their types will be used to determine
// the valid CLI flags. See the tests in this file as an example. For field
// types that are structs, the struct can implement the `parse_cli` function
// to do custom parsing. Since V has no u21 integer, a translated u21 field is
// represented as u32 with `@[cli_u21]` so parsing retains the source bound.
//
// If the destination type has a field "_arena" of type `?ArenaAllocator`,
// an arena allocator will be created (or reused if set already) for any
// allocations. Allocations are necessary for certain types, like `[]const u8`.
// (Not applicable in V - V uses GC for memory management.)
//
// If the destination type has a field "diagnostics", it must be of type
// "DiagnosticList" and any diagnostic messages will be added to that list.
// When diagnostics are present, only allocation errors will be returned.
//
// A destination may declare `compatibility(key, value) bool` to handle old
// field names or values after normal parsing fails. It may also declare
// `parse_manually_hook(arg, mut iter) bool` and `help()`; these are discovered
// through V's compile-time method reflection.
//
// Note: If the arena is already non-null, then it will be used. In this
// case, in the case of an error some memory might be leaked into the arena.
pub fn parse[T](mut dst T, args []string) ! {
	mut iter := slice_iterator(args)
	for {
		arg := iter.next() or { break }
		// Actions are detected before parsing, but remain in argv so diagnostic
		// indexes retain their original command-line position.
		if arg.len > 0 && arg[0] == `+` {
			continue
		}
		// A manual hook returning false consumed the iterator and ends parsing.
		// Returning true continues normal parsing of this same argument.
		mut continue_parsing := true
		$for method in T.methods {
			$if method.name == 'parse_manually_hook' {
				continue_parsing = dst.$method(arg, &iter)
			}
		}
		if !continue_parsing {
			return
		}

		// Destinations with `help()` own --help/-h handling, just as the
		// Zig parser checks for a help declaration.
		if arg == '--help' || arg == '-h' {
			mut showed_help := false
			$for method in T.methods {
				$if method.name == 'help' {
					dst.$method() or { return error('ActionHelpRequested') }
					showed_help = true
				}
			}
			if showed_help {
				return
			}
		}

		// If this doesn't start with "--" then it isn't a config
		// flag. We don't support positional arguments or configuration
		// values set with spaces so this is an error.
		if !arg.starts_with('--') {
			if append_diagnostic[T](mut dst, arg, 'invalid field', diagnostics.CliLocation{
				index: usize(iter.idx)
			})
			{
				continue
			}
			return error('invalid field')
		}

		mut key := arg[2..]
		mut value := ?string(none)
		eq_pos := index_byte(key, `=`)
		if eq_pos >= 0 {
			value = key[eq_pos + 1..]
			key = key[..eq_pos]
		}

		parse_into_field[T](mut dst, key, value) or {
			// A destination may recover old names/values with
			// `compatibility(key, value) bool`. The empty string represents a
			// missing value because V's reflected calls cannot pass optionals.
			mut compatibility_handled := false
			compatibility_value := value or { '' }
			$for method in T.methods {
				$if method.name == 'compatibility' {
					compatibility_handled = dst.$method(key, compatibility_value)
				}
			}
			if compatibility_handled {
				continue
			}

			mut message := err.msg()
			if message == 'invalid field' {
				message = 'unknown field'
			} else if message == 'value required' {
				message = format_value_required[T](key)
			} else if message == 'invalid value' {
				message = format_invalid_value[T](key, value)
			}
			if append_diagnostic[T](mut dst, key, message, diagnostics.CliLocation{
				index: usize(iter.idx)
			})
			{
				continue
			}
			return err
		}
	}
}

// compatibility_renamed applies a value to a replacement field. It is the V
// form of Ghostty's generated compatibilityRenamed handler.
pub fn compatibility_renamed[T](mut dst T, to string, value string) bool {
	parse_into_field[T](mut dst, to, value) or { return false }
	return true
}

// has_field reports whether key names a parser-visible field of T. This is the
// reflected field test used by actions that share argv with Config and must
// decide which parser owns a diagnostic.
pub fn has_field[T](key string) bool {
	normalized_key := key.replace('-', '_')
	$for field in T.fields {
		if field.name.len > 0 && field.name[0] != `_` && field.name != 'diagnostics'
			&& !field.attrs.contains('cli_internal')
			&& translated_identifier_name(field.name) == normalized_key {
			return true
		}
	}
	return false
}

// Parse a single key/value pair into the destination type T.
//
// This may result in allocations. In V, the GC handles memory.
// It is expected that the caller manages any needed cleanup.
pub fn parse_into_field[T](mut dst T, key string, value ?string) ! {
	// Convert hyphens to underscores for V field name matching,
	// since V identifiers can't contain hyphens.
	normalized_key := key.replace('-', '_')

	// Extract the raw value string. We do this outside $for because
	// V's compile-time blocks don't support `or` expressions.
	raw := if v := value { v } else { '' }
	has_value := value != none

	$for field in T.fields {
		if field.name.len > 0 && field.name[0] != `_` && field.name != 'diagnostics'
			&& !field.attrs.contains('cli_internal')
			&& translated_identifier_name(field.name) == normalized_key {
			defaults := T{}

			// If the value is empty string (set but empty string),
			// then we reset the value to the default.
			if has_value && raw.len == 0 {
				// Composite values may define initialization logic instead of a
				// field default. This is the V equivalent of Ghostty's `init`
				// declaration check. It intentionally takes precedence over the
				// ordinary field default.
				$if field.is_struct && !field.is_option {
					$for method in field.methods {
						$if method.name == 'init' {
							mut initialized := defaults.$(field.name)
							initialized.$method() or { return error('invalid value') }
							dst.$(field.name) = initialized
							return
						}
					}
				}

				// V's generic field metadata does not expose whether a field has
				// an explicit default expression. Translated auto-struct fields
				// without a Zig default carry `cli_required`; an empty value for
				// those fields must be parsed normally and rejected when invalid.
				if field.attrs.contains('cli_required') {
					// Continue into the type-specific parser below.
				} else {
					// Assign from a zero-argument instance to preserve V field
					// defaults, matching Zig's field.default_value_ptr behavior.
					dst.$(field.name) = defaults.$(field.name)
					return
				}
			}

			// Composite field types can provide their own mutating parser. V's
			// method reflection gives us the same dispatch that Zig implements
			// with @hasDecl(Field, "parseCLI").
			$if field.is_struct && !field.is_option {
				$for method in field.methods {
					$if method.name == 'parse_cli' {
						if !has_value {
							return error('value required')
						}
						mut parsed_field := dst.$(field.name)
						parsed_field.$method(raw) or { return error('invalid value') }
						dst.$(field.name) = parsed_field
						return
					}
				}
			}
			$if field.is_option && field.is_struct {
				dst.$(field.name) = parse_optional_custom(dst.$(field.name), value) or {
					return error('invalid value')
				}
				return
			}
			$if field.is_option && field.is_enum {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = parse_optional_enum(dst.$(field.name), raw)!
				return
			}

			// No type-specific parser: derive parsing from the field type.

			$if field.unaliased_typ is string {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = raw
				return
			} $else $if field.unaliased_typ is ?string {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = raw
				return
			} $else $if field.unaliased_typ is bool {
				bool_str := if has_value { raw } else { 't' }
				dst.$(field.name) = parse_bool(bool_str)!
				return
			} $else $if field.unaliased_typ is ?bool {
				bool_str := if has_value { raw } else { 't' }
				dst.$(field.name) = parse_bool(bool_str)!
				return
			} $else $if field.unaliased_typ is u8 || field.unaliased_typ is ?u8 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = u8(parse_unsigned_int(raw, 8) or {
					return error('invalid value')
				})
				return
			} $else $if field.unaliased_typ is u16 || field.unaliased_typ is ?u16 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = u16(parse_unsigned_int(raw, 16) or {
					return error('invalid value')
				})
				return
			} $else $if field.unaliased_typ is u32 || field.unaliased_typ is ?u32 {
				if !has_value {
					return error('value required')
				}
				bits := if field.attrs.contains('cli_u21') { 21 } else { 32 }
				n := parse_unsigned_int(raw, bits) or { return error('invalid value') }
				dst.$(field.name) = u32(n)
				return
			} $else $if field.unaliased_typ is u64 || field.unaliased_typ is ?u64 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = parse_unsigned_int(raw, 64) or { return error('invalid value') }
				return
			} $else $if field.unaliased_typ is usize || field.unaliased_typ is ?usize {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = usize(parse_unsigned_int(raw, int(sizeof(usize) * 8)) or {
					return error('invalid value')
				})
				return
			} $else $if field.unaliased_typ is int || field.unaliased_typ is ?int {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = int(parse_signed_int(raw, int(sizeof(int) * 8)) or {
					return error('invalid value')
				})
				return
			} $else $if field.unaliased_typ is i8 || field.unaliased_typ is ?i8 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = i8(parse_signed_int(raw, 8) or { return error('invalid value') })
				return
			} $else $if field.unaliased_typ is i16 || field.unaliased_typ is ?i16 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = i16(parse_signed_int(raw, 16) or {
					return error('invalid value')
				})
				return
			} $else $if field.unaliased_typ is i32 || field.unaliased_typ is ?i32 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = i32(parse_signed_int(raw, 32) or {
					return error('invalid value')
				})
				return
			} $else $if field.unaliased_typ is i64 || field.unaliased_typ is ?i64 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = parse_signed_int(raw, 64) or { return error('invalid value') }
				return
			} $else $if field.unaliased_typ is isize || field.unaliased_typ is ?isize {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = parse_signed_int(raw, int(sizeof(isize) * 8)) or {
					return error('invalid value')
				}
				return
			} $else $if field.unaliased_typ is f32 || field.unaliased_typ is ?f32 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = zig_fmt.parse_f32(raw) or { return error('invalid value') }
				return
			} $else $if field.unaliased_typ is f64 || field.unaliased_typ is ?f64 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = zig_fmt.parse_f64(raw) or { return error('invalid value') }
				return
			} $else $if field.unaliased_typ is $enum {
				if !has_value {
					return error('value required')
				}
				parse_enum_value(mut dst.$(field.name), raw)!
				return
			} $else $if field.unaliased_typ is $struct {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = parse_auto_struct(raw, defaults.$(field.name))!
				return
			} $else {
				return error('unsupported field type')
			}
		}
	}
	return error('invalid field')
}

fn parse_optional_custom[T](current ?T, value ?string) !T {
	mut parsed := current or { T{} }
	$for method in T.methods {
		$if method.name == 'parse_cli' {
			raw := if v := value {
				v
			} else {
				return error('value required')
			}
			parsed.$method(raw) or { return error('invalid value') }
			return parsed
		}
	}
	return error('unsupported field type')
}

fn parse_optional_enum[T](current ?T, raw string) !T {
	mut parsed := current or { T{} }
	parse_enum_value(mut parsed, raw)!
	return parsed
}

// parse_unsigned_int matches std.fmt.parseInt for an unsigned integer type.
// Unlike parseUnsigned, parseInt accepts signs, including -0 for unsigned.
pub fn parse_unsigned_int(raw string, bits int) !u64 {
	return parse_unsigned_int_base(raw, bits, 0)
}

// parse_unsigned_int_base is the explicit-base form of parse_unsigned_int.
pub fn parse_unsigned_int_base(raw string, bits int, base u8) !u64 {
	return zig_fmt.parse_int_unsigned(raw, bits, base)
}

// parse_signed_int matches std.fmt.parseInt for a signed integer type.
pub fn parse_signed_int(raw string, bits int) !i64 {
	return zig_fmt.parse_int_signed(raw, bits, 0)
}

fn parse_enum_value[T](mut out T, raw string) ! {
	$for enum_value in T.values {
		if raw == translated_identifier_name(enum_value.name) {
			out = enum_value.value
			return
		}
	}
	return error('invalid value')
}

// parse_auto_struct parses comma-separated key:value pairs. Missing fields
// inherit from default_value. V structs are always initialized, so this is the
// direct equivalent of Zig's explicit default-field pass.
pub fn parse_auto_struct[T](value string, default_value T) !T {
	mut result := default_value
	mut fields_set := map[string]bool{}
	mut splitter := comma_splitter.CommaSplitter.init(value)
	for {
		entry := splitter.next() or {
			if splitter.last_error.len > 0 {
				return error('invalid value')
			}
			break
		}
		colon := entry.index_u8(`:`)
		if colon < 0 {
			return error('invalid value')
		}
		key := entry[..colon].trim(whitespace)
		mut field_value := entry[colon + 1..].trim(whitespace)
		if field_value.len >= 2 && field_value[0] == `"` && field_value[field_value.len - 1] == `"` {
			field_value = decode_quoted_value(field_value) or { return error('invalid value') }
		}
		parse_into_field[T](mut result, key, field_value) or { return error('invalid value') }
		fields_set[key.replace('-', '_')] = true
	}

	// Zig distinguishes fields without a default expression from fields whose
	// default happens to be the type's zero value. V does not expose that bit
	// through `$for field in T.fields`, so translated required fields use the
	// `cli_required` attribute to retain the source distinction.
	$for field in T.fields {
		if field.attrs.contains('cli_required')
			&& translated_identifier_name(field.name) !in fields_set {
			return error('invalid value')
		}
	}
	return result
}

// parse_packed_struct translates Ghostty's packed all-boolean CLI structs.
// V does not distinguish packed layout here, so it works for any all-bool
// struct and retains the same textual representation.
pub fn parse_packed_struct[T](value string) !T {
	mut result := T{}
	if all := parse_bool(value) {
		$for field in T.fields {
			$if field.unaliased_typ is bool {
				result.$(field.name) = all
			} $else {
				return error('invalid packed struct field')
			}
		}
		return result
	}

	for raw_part in value.split(',') {
		mut part := raw_part.trim(whitespace)
		mut enabled := true
		if part.starts_with('no-') {
			part = part[3..]
			enabled = false
		}
		part = part.replace('-', '_')
		mut matched := false
		$for field in T.fields {
			$if field.unaliased_typ is bool {
				if translated_identifier_name(field.name) == part {
					result.$(field.name) = enabled
					matched = true
				}
			} $else {
				return error('invalid packed struct field')
			}
		}
		if !matched {
			return error('invalid value')
		}
	}
	return result
}

pub fn format_value_required[T](key string) string {
	return 'value required${format_values[T](key)}'
}

pub fn format_invalid_value[T](key string, value ?string) string {
	display := value or { '' }
	return 'invalid value "${display}"${format_values[T](key)}'
}

fn format_values[T](key string) string {
	normalized_key := key.replace('-', '_')
	defaults := T{}
	$for field in T.fields {
		if translated_identifier_name(field.name) == normalized_key {
			$if field.unaliased_typ is $enum {
				return enum_value_suffix(defaults.$(field.name))
			}
		}
	}
	return ''
}

fn enum_value_suffix[T](_ T) string {
	mut names := []string{}
	$for enum_value in T.values {
		names << translated_identifier_name(enum_value.name)
	}
	return ', valid values are: ${names.join(', ')}'
}

// V appends an underscore when translating source identifiers that are V
// keywords (`default` -> `default_`). CLI spelling retains the source name.
fn translated_identifier_name(name string) string {
	return if name.ends_with('_') { name[..name.len - 1] } else { name }
}

pub fn decode_quoted_value(value string) !string {
	if value.len < 2 || value[0] != `"` || value[value.len - 1] != `"` {
		return error('invalid value')
	}
	mut result := []u8{cap: value.len - 2}
	mut i := 1
	for i < value.len - 1 {
		if value[i] != `\\` {
			result << value[i]
			i++
			continue
		}
		i++
		if i >= value.len - 1 {
			return error('invalid value')
		}
		match value[i] {
			`n` {
				result << `\n`
			}
			`r` {
				result << `\r`
			}
			`t` {
				result << `\t`
			}
			`\\` {
				result << `\\`
			}
			`'` {
				result << `'`
			}
			`"` {
				result << `"`
			}
			`x` {
				if i + 2 >= value.len - 1 {
					return error('invalid value')
				}
				hi := hex_value(value[i + 1]) or { return error('invalid value') }
				lo := hex_value(value[i + 2]) or { return error('invalid value') }
				result << u8((hi << 4) | lo)
				i += 2
			}
			`u` {
				if i + 1 >= value.len - 1 || value[i + 1] != `{` {
					return error('invalid value')
				}
				i += 2
				mut codepoint := u32(0)
				mut digits := 0
				for i < value.len - 1 && value[i] != `}` {
					nibble := hex_value(value[i]) or { return error('invalid value') }
					codepoint = (codepoint << 4) | nibble
					digits++
					i++
				}
				if digits == 0 || i >= value.len - 1 || codepoint > 0x10ffff {
					return error('invalid value')
				}
				result << rune(codepoint).str().bytes()
			}
			else {
				return error('invalid value')
			}
		}

		i++
	}
	return result.bytestr()
}

fn hex_value(ch u8) ?u32 {
	if ch >= `0` && ch <= `9` {
		return u32(ch - `0`)
	}
	if ch >= `a` && ch <= `f` {
		return u32(ch - `a` + 10)
	}
	if ch >= `A` && ch <= `F` {
		return u32(ch - `A` + 10)
	}
	return none
}

// append_diagnostic returns true when T exposes a DiagnosticList field named
// diagnostics. V identifiers cannot begin with an underscore, so this is the
// language-equivalent of Ghostty's `_diagnostics` convention.
fn append_diagnostic[T](mut dst T, key string, message string, location diagnostics.Location) bool {
	mut appended := false
	$for field in T.fields {
		$if field.unaliased_typ is diagnostics.DiagnosticList {
			if field.name == 'diagnostics' {
				dst.$(field.name).append(diagnostics.Diagnostic{
					location: location
					key:      key
					message:  message
				})
				appended = true
			}
		}
	}
	return appended
}

// Parse boolean value from string.
// Returns true for "1", "t", "T", "true".
// Returns false for "0", "f", "F", "false".
pub fn parse_bool(v string) !bool {
	if v == '1' || v == 't' || v == 'T' || v == 'true' {
		return true
	}
	if v == '0' || v == 'f' || v == 'F' || v == 'false' {
		return false
	}
	return error('invalid value')
}

// An iterator that considers its location to be CLI args. It
// iterates through an underlying args slice and increments a counter
// to track the current CLI arg index.
//
// This also ignores any argument that starts with `+`. It assumes that
// actions were parsed out before this iterator was created.
pub struct ArgsIterator {
mut:
	// The underlying args.
	args []string
	// Our current index into the iterator. This is 1-indexed.
	// The 0 value is used to indicate that we haven't read any
	// values yet.
	index usize
}

// deinit mirrors ArgsIterator.deinit. The wrapped strings are owned by V's
// garbage collector, so there is no allocator state to release.
pub fn (mut self ArgsIterator) deinit() {
	self.args.clear()
	self.index = 0
}

pub fn ArgsIterator.new(args []string) ArgsIterator {
	return ArgsIterator{
		args: args
	}
}

// Create an args iterator for the process args. This skips argv0.
pub fn args_iterator() ArgsIterator {
	mut args := process_args_snapshot()
	if args.len > 0 {
		args.delete(0)
	}
	return ArgsIterator{
		args: args
	}
}

pub fn (mut self ArgsIterator) next() ?string {
	for self.index < usize(self.args.len) {
		value := self.args[int(self.index)]
		self.index += 1
		// We ignore any argument that starts with "+". This is used
		// to indicate actions and are expected to be parsed out before
		// this iterator is created.
		if value.len > 0 && value[0] == `+` {
			continue
		}
		return value
	}
	return none
}

// Returns a location for a diagnostic message.
pub fn (self ArgsIterator) location() diagnostics.Location {
	return diagnostics.CliLocation{
		index: self.index
	}
}

// Returns an iterator (implements "next") that reads CLI args by line.
// Each CLI arg is expected to be a single line. This is used to implement
// configuration files.
pub struct LineIterator {
pub:
	// Filepath that is used for diagnostics. This is only used for
	// diagnostic messages so it can be formatted however you want.
	// It is prefixed to the messages followed by the line number.
	filepath string
pub mut:
	// The current line that we're on. This is 1-indexed because
	// lines are generally 1-indexed in the real world. The value
	// can be zero if we haven't read any lines yet.
	line usize
mut:
	// The lines of input data.
	lines []string
	// Current position in lines.
	idx int
}

// The maximum size a single line can be. We don't expect any
// CLI arg to exceed this size. Can't wait to git blame this in
// like 4 years and be wrong about this.
pub const max_line_size = 4096

pub fn LineIterator.init(data string) LineIterator {
	return LineIterator{
		lines: data.split_into_lines()
	}
}

pub fn LineIterator.new_with_path(data string, filepath string) LineIterator {
	return LineIterator{
		lines:    data.split_into_lines()
		filepath: filepath
	}
}

pub fn (mut self LineIterator) next() ?string {
	for self.idx < self.lines.len {
		raw := self.lines[self.idx]
		self.idx += 1
		self.line += 1
		// The source stores the two-byte "--" prefix and the line in one
		// MAX_LINE_SIZE buffer. An oversized line ends iteration.
		if raw.len > max_line_size - 2 {
			self.idx = self.lines.len
			return none
		}
		mut entry := raw.trim(whitespace + '\r')

		// Ignore blank lines and comments
		if entry.len == 0 || entry[0] == `#` {
			continue
		}

		// Handle key = value format: trim whitespace around '='
		eq_pos := index_byte(entry, `=`)
		if eq_pos >= 0 {
			key := entry[..eq_pos].trim(whitespace)
			mut value := entry[eq_pos + 1..].trim(whitespace)

			// Detect a quoted string.
			if value.len >= 2 && value[0] == `"` && value[value.len - 1] == `"` {
				// Trim quotes since our CLI args processor expects
				// quotes to already be gone.
				value = value[1..value.len - 1]
			}

			entry = '${key}=${value}'
		}

		// We need to prepend '--' at the beginning so that we can
		// trick the CLI parser to treat it as CLI args.
		return '--${entry}'
	}
	return none
}

// Returns a location for a diagnostic message.
pub fn (self LineIterator) location() diagnostics.Location {
	// If we have no filepath then we have no location.
	if self.filepath.len == 0 {
		return diagnostics.NoneLocation{}
	}
	return diagnostics.FileLocation{
		path: self.filepath
		line: self.line
	}
}

// Collect all remaining items from the iterator into a slice.
pub fn (mut self LineIterator) collect() []string {
	mut result := []string{}
	for {
		item := self.next() or { break }
		result << item
	}
	return result
}

// An iterator valid for arg parsing from a slice.
pub struct SliceIterator {
	// The underlying slice of arguments.
	slice []string
mut:
	// Current position in the slice.
	idx int
}

// Construct a SliceIterator from a slice. Mirrors sliceIterator.
pub fn slice_iterator(slice []string) SliceIterator {
	return SliceIterator{
		slice: slice
	}
}

pub fn (mut self SliceIterator) next() ?string {
	if self.idx >= self.slice.len {
		return none
	}
	result := self.slice[self.idx]
	self.idx += 1
	return result
}

// Helper: find the first occurrence of a byte in a string.
// Returns -1 if not found.
fn index_byte(s string, c u8) int {
	for i := 0; i < s.len; i++ {
		if s[i] == c {
			return i
		}
	}
	return -1
}
