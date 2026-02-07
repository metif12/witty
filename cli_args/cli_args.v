module cli_args

import strconv
import diagnostics

// TODO:
//   - Only `--long=value` format is accepted. Do we want to allow
//     `--long value`? Not currently allowed.

// For trimming
pub const whitespace = ' \t'

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
pub type CompatibilityHandler = fn (key string, value ?string) bool

// Parse the command line arguments from args into dst.
//
// dst must be a struct. The fields and their types will be used to determine
// the valid CLI flags. See the tests in this file as an example. For field
// types that are structs, the struct can implement the `parse_cli` function
// to do custom parsing.
//
// If the destination type has a field "_arena" of type `?ArenaAllocator`,
// an arena allocator will be created (or reused if set already) for any
// allocations. Allocations are necessary for certain types, like `[]const u8`.
// (Not applicable in V - V uses GC for memory management.)
//
// If the destination type has a field "_diagnostics", it must be of type
// "DiagnosticList" and any diagnostic messages will be added to that list.
// When diagnostics are present, only allocation errors will be returned.
// (XTODO: Not implemented - requires compile-time field detection.)
//
// If the destination type has a decl "compatibility", it must be of type
// std.StaticStringMap(CompatibilityHandler(T)), and it will be used to
// handle backwards compatibility for fields with the given name. The
// field name doesn't need to exist (so you can setup compatibility for
// removed fields). The value is a function that will be called when
// all other parsing fails for that field. If a field changes such that
// the old values would NOT error, then the caller should handle that
// downstream after parsing is done, not through this method.
// (XTODO: Not implemented - requires compile-time decl lookup.)
//
// Note: If the arena is already non-null, then it will be used. In this
// case, in the case of an error some memory might be leaked into the arena.
pub fn parse[T](mut dst T, args []string) ! {
	for arg in args {
		// XTODO: parseManuallyHook - V doesn't support checking for
		// method declarations at compile time (Zig's @hasDecl).
		// Do manual parsing if we have a hook for it.
		// if (@hasDecl(T, "parseManuallyHook")) {
		//     if (!try dst.parseManuallyHook(arena_alloc, arg, iter)) return;
		// }

		// XTODO: help flag detection - V doesn't support checking for
		// method declarations at compile time (Zig's @hasDecl).
		// If the destination supports help then we check for it, call
		// the help function and return.
		// if (@hasDecl(T, "help")) {
		//     if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
		//         try dst.help();
		//         return;
		//     }
		// }

		// If this doesn't start with "--" then it isn't a config
		// flag. We don't support positional arguments or configuration
		// values set with spaces so this is an error.
		if !arg.starts_with('--') {
			// XTODO: diagnostic tracking
			// if (comptime !canTrackDiags(T)) return Error.InvalidField;
			// try dst._diagnostics.append(arena_alloc, .{
			//     .key = try arena_alloc.dupeZ(u8, arg),
			//     .message = "invalid field",
			//     .location = try diags.Location.fromIter(iter, arena_alloc),
			// });
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
			// XTODO: compatibility handler fallback
			// If we get an error parsing a field, then we try to fall
			// back to compatibility handlers if able.
			// if (@hasDecl(T, "compatibility")) {
			//     if (T.compatibility.get(key)) |handler| {
			//         if (handler(dst, arena_alloc, key, value)) {
			//             break :err;
			//         }
			//     }
			// }

			// XTODO: diagnostic tracking
			// if (comptime !canTrackDiags(T)) return err;
			// ...format error messages and add diagnostics...
			return err
		}
	}
}

// Convenience function to create a compatibility handler that
// renames a field from `from` to `to`.
// XTODO: This requires compile-time field validation (@hasField)
// and function pointer generation which V doesn't support in the
// same way as Zig's comptime. The concept is preserved but the
// implementation would need to be done differently in V.
// pub fn compatibility_renamed[T](to string) CompatibilityHandler {
//     return fn (key string, value ?string) bool {
//         // Would need to call parse_into_field with the renamed field
//         return false
//     }
// }

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
		if field.name.len > 0 && field.name[0] != `_` && field.name == normalized_key {
			// If the value is empty string (set but empty string),
			// then we reset the value to the default.
			if has_value && raw.len == 0 {
				// XTODO: Resetting to compile-time default values is not
				// fully supported in V's $for. In Zig, this uses
				// field.default_value_ptr to reset the field to the
				// struct's default value. For now, we just return.
				// If the field type has an `init` method, we would call it:
				// if (canHaveDecls and @hasDecl(Field, "init")) {
				//     try @field(dst, field.name).init(alloc);
				//     return;
				// }
				return
			}

			// No parseCLI, magic the value based on the type.
			// XTODO: If the field type has a `parse_cli` method, we would
			// call that instead. V doesn't support compile-time method
			// detection (@hasDecl) in $for context.
			// if (canHaveDecls and @hasDecl(Field, "parseCLI")) { ... }

			$if field.typ is string {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = raw
				return
			} $else $if field.typ is bool {
				bool_str := if has_value { raw } else { 't' }
				dst.$(field.name) = parse_bool(bool_str)!
				return
			} $else $if field.typ is u8 {
				if !has_value {
					return error('value required')
				}
				n := strconv.atoi(raw) or { return error('invalid value') }
				dst.$(field.name) = u8(n)
				return
			} $else $if field.typ is u16 {
				if !has_value {
					return error('value required')
				}
				n := strconv.atoi(raw) or { return error('invalid value') }
				dst.$(field.name) = u16(n)
				return
			} $else $if field.typ is u32 {
				if !has_value {
					return error('value required')
				}
				n := strconv.atoi(raw) or { return error('invalid value') }
				dst.$(field.name) = u32(n)
				return
			} $else $if field.typ is u64 {
				if !has_value {
					return error('value required')
				}
				n := strconv.atoi(raw) or { return error('invalid value') }
				dst.$(field.name) = u64(n)
				return
			} $else $if field.typ is int {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = strconv.atoi(raw) or {
					return error('invalid value')
				}
				return
			} $else $if field.typ is i8 {
				if !has_value {
					return error('value required')
				}
				n := strconv.atoi(raw) or { return error('invalid value') }
				dst.$(field.name) = i8(n)
				return
			} $else $if field.typ is i16 {
				if !has_value {
					return error('value required')
				}
				n := strconv.atoi(raw) or { return error('invalid value') }
				dst.$(field.name) = i16(n)
				return
			} $else $if field.typ is i64 {
				if !has_value {
					return error('value required')
				}
				n := strconv.atoi(raw) or { return error('invalid value') }
				dst.$(field.name) = i64(n)
				return
			} $else $if field.typ is f32 {
				if !has_value {
					return error('value required')
				}
				f := strconv.atof64(raw) or { return error('invalid value') }
				dst.$(field.name) = f32(f)
				return
			} $else $if field.typ is f64 {
				if !has_value {
					return error('value required')
				}
				dst.$(field.name) = strconv.atof64(raw) or {
					return error('invalid value')
				}
				return
			} $else {
				// XTODO: Unsupported field types include:
				// - Enums (requires string-to-enum conversion,
				//   Zig uses std.meta.stringToEnum)
				// - Optional fields (requires unwrapping the inner type,
				//   Zig uses @typeInfo(.optional).child)
				// - Structs with parseCLI method (requires @hasDecl)
				// - Auto-layout structs (requires recursive key:value parsing
				//   via CommaSplitter)
				// - Tagged unions (requires runtime union construction,
				//   Zig uses @unionInit)
				// - Packed structs (V doesn't have packed structs)
				return error('unsupported field type')
			}
		}
	}
	return error('invalid field')
}

// XTODO: parseTaggedUnion - Requires runtime union construction which
// V doesn't support in the same way as Zig's @unionInit.
// The Zig version:
// 1. Finds the colon separator to split tag:value
// 2. Uses inline for to iterate union fields
// 3. Matches the tag string to a field name
// 4. Handles void types (no value needed)
// 5. Creates a temporary struct and parses the value into it
// 6. Constructs the union with @unionInit
// pub fn parse_tagged_union[T](v string) !T { ... }

// XTODO: parseAutoStruct - Requires CommaSplitter for key:value pairs
// and compile-time field tracking (StaticBitSet) which V doesn't have.
// The Zig version:
// 1. Starts with undefined result
// 2. Tracks which fields were set with a bitset
// 3. Splits input by commas using CommaSplitter
// 4. Finds key:value pairs and parses each field
// 5. Validates all required fields were set
// 6. Fills in defaults for optional fields
// pub fn parse_auto_struct[T](v string, default_ ?T) !T { ... }

// XTODO: parsePackedStruct - V doesn't have packed structs.
// The Zig version:
// 1. Tries to parse standalone boolean ("true"/"false")
// 2. Splits by commas
// 3. Handles "no-" prefix for negation
// 4. Sets individual bool fields
// pub fn parse_packed_struct[T](v string) !T { ... }

// XTODO: formatValueRequired - Requires compile-time field iteration
// to find valid enum values for a given field name.
// fn format_value_required[T](key string) string { ... }

// XTODO: formatInvalidValue - Similar to formatValueRequired.
// fn format_invalid_value[T](key string, value ?string) string { ... }

// XTODO: formatValues - Requires compile-time enum field iteration.
// fn format_values[T](key string) string { ... }

// Returns true if this type can track diagnostics.
// XTODO: In Zig this checks @hasField(T, "_diagnostics") at compile time.
// V's $for could potentially check this but it's not implemented yet.
// fn can_track_diags[T]() bool { ... }

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
	// The underlying args.
	args []string
mut:
	// Our current index into the iterator. This is 1-indexed.
	// The 0 value is used to indicate that we haven't read any
	// values yet.
	index int
}

pub fn ArgsIterator.new(args []string) ArgsIterator {
	return ArgsIterator{
		args: args
	}
}

pub fn (mut self ArgsIterator) next() ?string {
	for self.index < self.args.len {
		value := self.args[self.index]
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
	line int
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

pub fn LineIterator.new(data string) LineIterator {
	return LineIterator{
		lines: data.split_into_lines()
	}
}

pub fn LineIterator.new_with_path(data string, filepath string) LineIterator {
	return LineIterator{
		lines: data.split_into_lines()
		filepath: filepath
	}
}

pub fn (mut self LineIterator) next() ?string {
	for self.idx < self.lines.len {
		mut entry := self.lines[self.idx].trim(whitespace + '\r')
		self.idx += 1
		self.line += 1

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
pub fn (self LineIterator) location() ?diagnostics.Location {
	// If we have no filepath then we have no location.
	if self.filepath.len == 0 {
		return none
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

// Construct a SliceIterator from a slice.
pub fn SliceIterator.new(slice []string) SliceIterator {
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
