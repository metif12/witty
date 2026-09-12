module cli_args

import diagnostics

// Test structs (V doesn't have anonymous structs like Zig)

struct SimpleTestData {
mut:
	a   string
	b   bool
	b_f bool = true
}

struct QuotedValueData {
mut:
	a u8
	b string
}

struct DefaultResetData {
mut:
	a u8 = 42
	b bool
}

struct BoolTestData {
mut:
	a bool
}

struct UnsignedTestData {
mut:
	val u8
}

struct IntegerWidthsData {
mut:
	u8_value    u8
	u16_value   u16
	u32_value   u32
	u64_value   u64
	usize_value usize
	i8_value    i8
	i16_value   i16
	i32_value   i32
	i64_value   i64
	isize_value isize
}

struct FloatTestData {
mut:
	val   f64
	val32 f32
}

struct PositionalTestData {
mut:
	a u8 = 42
}

struct StringTestData {
mut:
	a string
}

enum EnumTestValue {
	one
	two_words
}

struct EnumTestData {
mut:
	value EnumTestValue
}

struct OptionalTestData {
mut:
	text    ?string
	count   ?u16
	enabled ?bool
}

struct AutoStructValue {
mut:
	count int @[cli_required]
	name  string = 'default'
}

struct AutoStructData {
mut:
	value AutoStructValue
}

struct CustomParsedValue {
mut:
	value string
}

fn (mut c CustomParsedValue) parse_cli(input string) ! {
	c.value = input.to_upper()
}

struct CustomParsedData {
mut:
	value CustomParsedValue
}

struct OptionalCustomParsedData {
mut:
	value ?CustomParsedValue
}

struct InitializedValue {
mut:
	value string
}

fn (mut value InitializedValue) init() ! {
	value.value = 'HELLO!'
}

struct InitializedData {
mut:
	value InitializedValue
}

struct PackedBoolData {
mut:
	a bool
	b bool = true
}

struct DiagnosticTestData {
mut:
	a           string
	diagnostics diagnostics.DiagnosticList
}

struct InternalFieldTestData {
mut:
	visible  bool
	internal bool @[cli_internal]
}

struct HookTestData {
mut:
	manual      string
	help_called bool
	compat      bool
}

struct KeywordFieldTestData {
mut:
	default_ bool
}

enum OptionalEnumValue {
	one
	two
}

struct OptionalEnumTestData {
mut:
	value ?OptionalEnumValue
}

fn (mut h HookTestData) parse_manually_hook(arg string) bool {
	if arg == '-e' {
		h.manual = arg
		return true
	}
	return false
}

fn (mut h HookTestData) help() {
	h.help_called = true
}

fn (mut h HookTestData) compatibility(key string, value string) bool {
	if key == 'old' && value == 'yes' {
		h.compat = true
		return true
	}
	return false
}

// --- parse_bool tests ---

fn test_parse_bool_true_values() {
	assert parse_bool('1')! == true
	assert parse_bool('t')! == true
	assert parse_bool('T')! == true
	assert parse_bool('true')! == true
}

fn test_parse_bool_false_values() {
	assert parse_bool('0')! == false
	assert parse_bool('f')! == false
	assert parse_bool('F')! == false
	assert parse_bool('false')! == false
}

fn test_parse_bool_invalid() {
	if _ := parse_bool('yes') {
		assert false, 'expected error'
	} else {
		assert err.msg() == 'invalid value'
	}
	if _ := parse_bool('no') {
		assert false, 'expected error'
	} else {
		assert err.msg() == 'invalid value'
	}
}

// --- parse: simple ---

fn test_parse_simple() {
	mut data := SimpleTestData{}
	parse[SimpleTestData](mut data, ['--a=42', '--b', '--b_f=false'])!
	assert data.a == '42'
	assert data.b == true
	assert data.b_f == false
}

fn test_parse_maps_v_keyword_suffix_to_source_name() {
	mut data := KeywordFieldTestData{}
	parse[KeywordFieldTestData](mut data, ['--default'])!
	assert data.default_
}

fn test_parse_optional_enum() {
	mut data := OptionalEnumTestData{}
	parse[OptionalEnumTestData](mut data, ['--value=two'])!
	assert data.value? == .two
}

fn test_parse_enum_uses_source_tag_spelling() {
	mut data := EnumTestData{}
	parse[EnumTestData](mut data, ['--value=two_words'])!
	assert data.value == .two_words
	if _ := parse[EnumTestData](mut data, ['--value=two-words']) {
		assert false, 'enum tags retain their source underscores'
	} else {
		assert err.msg() == 'invalid value'
	}
}

fn test_diagnostics_storage_is_not_a_cli_field() {
	mut data := DiagnosticTestData{}
	parse[DiagnosticTestData](mut data, ['--diagnostics=value'])!
	items := data.diagnostics.items()
	assert items.len == 1
	assert items[0].key == 'diagnostics'
	assert items[0].message == 'unknown field'
}

fn test_internal_fields_are_not_cli_fields() {
	mut data := InternalFieldTestData{}
	parse[InternalFieldTestData](mut data, ['--visible'])!
	assert data.visible
	if _ := parse[InternalFieldTestData](mut data, ['--internal']) {
		assert false, 'internal parser state must not become a CLI option'
	} else {
		assert err.msg() == 'invalid field'
	}
}

// --- parse: simple reparsing ---

fn test_parse_reparsing() {
	mut data := SimpleTestData{}
	parse[SimpleTestData](mut data, ['--a=42', '--b', '--b_f=false'])!
	assert data.a == '42'
	assert data.b == true
	assert data.b_f == false

	// Reparsing works
	parse[SimpleTestData](mut data, ['--a=84'])!
	assert data.a == '84'
	assert data.b == true
	assert data.b_f == false
}

// --- parse: quoted value ---

fn test_parse_quoted_value() {
	// Quoted values: the quotes are part of the arg string from the shell,
	// so by the time we see the value, quotes are already stripped.
	mut data := QuotedValueData{}
	parse[QuotedValueData](mut data, ['--a=42', '--b=hello!'])!
	assert data.a == u8(42)
	assert data.b == 'hello!'
}

// --- parse: empty value resets to default ---

fn test_parse_empty_value_resets() {
	mut data := DefaultResetData{}
	data.a = 7
	data.b = true
	parse[DefaultResetData](mut data, ['--a=', '--b='])!
	assert data.a == u8(42)
	assert data.b == false
}

fn test_parse_into_field_enum() {
	mut data := EnumTestData{}
	parse_into_field[EnumTestData](mut data, 'value', 'two_words')!
	assert data.value == .two_words
	if _ := parse_into_field[EnumTestData](mut data, 'value', 'missing') {
		assert false, 'expected invalid enum value'
	} else {
		assert err.msg() == 'invalid value'
	}
}

fn test_parse_into_field_optional_scalars() {
	mut data := OptionalTestData{}
	parse[OptionalTestData](mut data, ['--text=hello', '--count=42', '--enabled'])!
	assert data.text or { '' } == 'hello'
	assert data.count or { 0 } == 42
	assert data.enabled or { false }
}

fn test_parse_into_field_auto_struct() {
	mut data := AutoStructData{}
	parse_into_field[AutoStructData](mut data, 'value', 'count:42,name:"hello, world"')!
	assert data.value.count == 42
	assert data.value.name == 'hello, world'

	parsed := parse_auto_struct('count:7', AutoStructValue{})!
	assert parsed.count == 7
	assert parsed.name == 'default'

	if _ := parse_auto_struct('', AutoStructValue{}) {
		assert false, 'expected missing required field to fail'
	} else {
		assert err.msg() == 'invalid value'
	}
	if _ := parse_into_field[AutoStructData](mut data, 'value', 'name:hello') {
		assert false, 'expected missing required field to fail'
	} else {
		assert err.msg() == 'invalid value'
	}
}

fn test_parse_into_field_custom_parser() {
	mut data := CustomParsedData{}
	parse_into_field[CustomParsedData](mut data, 'value', 'hello')!
	assert data.value.value == 'HELLO'
}

fn test_parse_into_field_optional_custom_parser() {
	mut data := OptionalCustomParsedData{}
	parse_into_field[OptionalCustomParsedData](mut data, 'value', 'hello')!
	assert (data.value or { CustomParsedValue{} }).value == 'HELLO'

	parse_into_field[OptionalCustomParsedData](mut data, 'value', 'world')!
	assert (data.value or { CustomParsedValue{} }).value == 'WORLD'
}

fn test_parse_into_field_empty_value_uses_init() {
	mut data := InitializedData{}
	parse_into_field[InitializedData](mut data, 'value', '')!
	assert data.value.value == 'HELLO!'
}

fn test_parse_packed_struct() {
	all := parse_packed_struct[PackedBoolData]('true')!
	assert all.a
	assert all.b

	selected := parse_packed_struct[PackedBoolData]('a,no-b')!
	assert selected.a
	assert !selected.b
}

fn test_format_enum_values() {
	assert format_value_required[EnumTestData]('value') == 'value required, valid values are: one, two_words'
	assert format_invalid_value[EnumTestData]('value', 'bad') == 'invalid value "bad", valid values are: one, two_words'
}

fn test_parse_tracks_diagnostics_and_continues() {
	mut data := DiagnosticTestData{}
	parse[DiagnosticTestData](mut data, ['--what', 'positional', '--a=42'])!
	assert data.a == '42'
	items := data.diagnostics.items()
	assert items.len == 2
	assert items[0].key == 'what'
	assert items[0].message == 'unknown field'
	assert items[0].location is diagnostics.CliLocation
	if items[0].location is diagnostics.CliLocation {
		assert items[0].location.index == 1
	}
	assert items[1].key == 'positional'
	assert items[1].message == 'invalid field'
}

fn test_parse_skips_actions_without_losing_diagnostic_position() {
	mut data := DiagnosticTestData{}
	parse[DiagnosticTestData](mut data, ['+show-face', '--missing=value'])!
	items := data.diagnostics.items()
	assert items.len == 1
	assert items[0].format() == 'cli:2:missing: unknown field'
}

fn test_parse_manual_help_and_compatibility_hooks() {
	mut manual := HookTestData{}
	parse[HookTestData](mut manual, ['-e', '--old=yes'])!
	assert manual.manual == '-e'
	assert manual.compat

	mut help := HookTestData{}
	parse[HookTestData](mut help, ['--help', '--old=yes'])!
	assert help.help_called
	assert !help.compat
}

fn test_compatibility_renamed() {
	mut data := BoolTestData{}
	assert compatibility_renamed[BoolTestData](mut data, 'a', 'true')
	assert data.a
	assert !compatibility_renamed[BoolTestData](mut data, 'missing', 'true')
}

// --- parse: positional arguments are invalid ---

fn test_parse_positional_args_invalid() {
	mut data := PositionalTestData{}
	if _ := parse[PositionalTestData](mut data, ['--a=84', 'what']) {
		assert false, 'expected error'
	} else {
		assert err.msg() == 'invalid field'
	}
	// The first valid arg should have been parsed before the error.
	assert data.a == u8(84)
}

// --- parse: unknown field is invalid ---
// This is the non-diagnostic-tracking branch of Ghostty's
// "parse: diagnostic tracking" test. When the destination type cannot
// track diagnostics (canTrackDiags == false), an unknown "--field"
// returns error.InvalidField. The witty parser has no diagnostics list,
// so it always takes this branch.

fn test_parse_unknown_field_invalid() {
	mut data := StringTestData{}
	if _ := parse[StringTestData](mut data, ['--what', '--a=42']) {
		assert false, 'expected error'
	} else {
		assert err.msg() == 'invalid field'
	}
}

// --- parseIntoField: ignore underscore-prefixed fields ---
// NOTE: V doesn't allow struct field names starting with `_`,
// so this test is unnecessary. The Zig version uses `_` prefix
// to mark internal fields (like `_arena`, `_diagnostics`).

// --- parseIntoField: string ---

fn test_parse_into_field_string() {
	mut data := StringTestData{}
	parse_into_field[StringTestData](mut data, 'a', '42')!
	assert data.a == '42'
}

// --- parseIntoField: bool ---

fn test_parse_into_field_bool_true() {
	mut data := BoolTestData{}

	// True values
	parse_into_field[BoolTestData](mut data, 'a', '1')!
	assert data.a == true
	parse_into_field[BoolTestData](mut data, 'a', 't')!
	assert data.a == true
	parse_into_field[BoolTestData](mut data, 'a', 'T')!
	assert data.a == true
	parse_into_field[BoolTestData](mut data, 'a', 'true')!
	assert data.a == true
}

fn test_parse_into_field_bool_false() {
	mut data := BoolTestData{}

	// False values
	parse_into_field[BoolTestData](mut data, 'a', '0')!
	assert data.a == false
	parse_into_field[BoolTestData](mut data, 'a', 'f')!
	assert data.a == false
	parse_into_field[BoolTestData](mut data, 'a', 'F')!
	assert data.a == false
	parse_into_field[BoolTestData](mut data, 'a', 'false')!
	assert data.a == false
}

// --- parseIntoField: unsigned numbers ---

fn test_parse_into_field_unsigned() {
	mut data := UnsignedTestData{}
	parse_into_field[UnsignedTestData](mut data, 'val', '1')!
	assert data.val == u8(1)
}

fn test_parse_into_field_integer_bases_and_widths() {
	mut data := IntegerWidthsData{}
	parse_into_field[IntegerWidthsData](mut data, 'u8_value', '0x2a')!
	parse_into_field[IntegerWidthsData](mut data, 'u16_value', '0o52')!
	parse_into_field[IntegerWidthsData](mut data, 'u32_value', '0b101010')!
	parse_into_field[IntegerWidthsData](mut data, 'u64_value', '42')!
	parse_into_field[IntegerWidthsData](mut data, 'usize_value', '0x2a')!
	parse_into_field[IntegerWidthsData](mut data, 'i8_value', '-0x2a')!
	parse_into_field[IntegerWidthsData](mut data, 'i16_value', '-0o52')!
	parse_into_field[IntegerWidthsData](mut data, 'i32_value', '-0b101010')!
	parse_into_field[IntegerWidthsData](mut data, 'i64_value', '-9223372036854775808')!
	parse_into_field[IntegerWidthsData](mut data, 'isize_value', '-0x2a')!
	assert data.u8_value == 42
	assert data.u16_value == 42
	assert data.u32_value == 42
	assert data.u64_value == 42
	assert data.usize_value == 42
	assert data.i8_value == -42
	assert data.i16_value == -42
	assert data.i32_value == -42
	assert data.i64_value == min_i64
	assert data.isize_value == -42

	if _ := parse_into_field[IntegerWidthsData](mut data, 'u8_value', '256') {
		assert false, 'expected u8 overflow to fail'
	} else {
		assert err.msg() == 'invalid value'
	}
	if _ := parse_into_field[IntegerWidthsData](mut data, 'i8_value', '-129') {
		assert false, 'expected i8 overflow to fail'
	} else {
		assert err.msg() == 'invalid value'
	}
	if _ := parse_into_field[IntegerWidthsData](mut data, 'i64_value', '9223372036854775808') {
		assert false, 'expected i64 positive overflow to fail'
	} else {
		assert err.msg() == 'invalid value'
	}
	if _ := parse_into_field[IntegerWidthsData](mut data, 'i64_value', '-9223372036854775809') {
		assert false, 'expected i64 negative overflow to fail'
	} else {
		assert err.msg() == 'invalid value'
	}
}

fn test_parse_into_field_integer_grammar_matches_zig() {
	mut data := IntegerWidthsData{}
	parse_into_field[IntegerWidthsData](mut data, 'u8_value', '+0x2a')!
	assert data.u8_value == 42
	parse_into_field[IntegerWidthsData](mut data, 'u8_value', '-0')!
	assert data.u8_value == 0
	parse_into_field[IntegerWidthsData](mut data, 'u8_value', '010')!
	assert data.u8_value == 10
	parse_into_field[IntegerWidthsData](mut data, 'u8_value', '1__0')!
	assert data.u8_value == 10
	parse_into_field[IntegerWidthsData](mut data, 'i16_value', '-0x1__0')!
	assert data.i16_value == -16

	for invalid in ['_10', '10_', '0x_10', '0x10_', '0x', '-1'] {
		if _ := parse_into_field[IntegerWidthsData](mut data, 'u8_value', invalid) {
			assert false, 'expected ${invalid} to fail'
		} else {
			assert err.msg() == 'invalid value'
		}
	}
}

// --- parseIntoField: floats ---

fn test_parse_into_field_float() {
	mut data := FloatTestData{}
	parse_into_field[FloatTestData](mut data, 'val', '1')!
	assert data.val == f64(1.0)
	parse_into_field[FloatTestData](mut data, 'val', '0x1_f.p1')!
	assert data.val == 62
	parse_into_field[FloatTestData](mut data, 'val32', '0_1.25e1')!
	assert data.val32 == f32(12.5)
	for invalid in [' 1', '1 ', '1__0', '1e_2'] {
		parse_into_field[FloatTestData](mut data, 'val', invalid) or {
			assert err.msg() == 'invalid value'
			continue
		}
		assert false, 'expected ${invalid} to fail'
	}
}

// --- parseIntoField: hyphen to underscore conversion ---

fn test_parse_into_field_hyphen_conversion() {
	mut data := SimpleTestData{}
	// CLI uses hyphens, V struct fields use underscores
	parse_into_field[SimpleTestData](mut data, 'b-f', 'false')!
	assert data.b_f == false
}

// --- ArgsIterator ---

fn test_args_iterator() {
	mut iter := ArgsIterator.new(['--what', '+list-things', '--a=42'])
	// Should return --what (regular arg)
	assert iter.next()? == '--what'
	first_location := iter.location()
	assert first_location is diagnostics.CliLocation
	assert first_location.index == 1
	// Should skip +list-things (action prefix)
	assert iter.next()? == '--a=42'
	second_location := iter.location()
	assert second_location is diagnostics.CliLocation
	assert second_location.index == 3
	// No more args
	assert iter.next() == none
	assert iter.next() == none
}

// --- LineIterator ---

fn test_line_iterator_basic() {
	mut iter := LineIterator.new('A\nB=42\nC\n\n# A comment\nD\n\n  # An indented comment\n  E\n\n# A quoted string with whitespace\nF=  "value "')
	assert iter.next()? == '--A'
	assert iter.next()? == '--B=42'
	assert iter.next()? == '--C'
	assert iter.next()? == '--D'
	assert iter.next()? == '--E'
	assert iter.next()? == '--F=value '
	assert iter.next() == none
	assert iter.next() == none
}

fn test_line_iterator_end_in_newline() {
	mut iter := LineIterator.new('A\n\n')
	assert iter.next()? == '--A'
	assert iter.next() == none
	assert iter.next() == none
}

fn test_line_iterator_spaces_around_equals() {
	mut iter := LineIterator.new('A = B\n\n')
	assert iter.next()? == '--A=B'
	assert iter.next() == none
	assert iter.next() == none
}

fn test_line_iterator_no_value() {
	mut iter := LineIterator.new('A = \n\n')
	assert iter.next()? == '--A='
	assert iter.next() == none
}

fn test_line_iterator_crlf() {
	mut iter := LineIterator.new('A\r\nB = C\r\n')
	assert iter.next()? == '--A'
	assert iter.next()? == '--B=C'
	assert iter.next() == none
	assert iter.next() == none
}

fn test_line_iterator_location() {
	mut iter := LineIterator.new_with_path('A\nB\n', 'test.conf')
	_ := iter.next()? // consume A
	_ := iter.next()? // consume B

	loc := iter.location()
	match loc {
		diagnostics.FileLocation {
			assert loc.path == 'test.conf'
			assert loc.line == 2
		}
		else {
			assert false, 'expected FileLocation'
		}
	}
}

fn test_line_iterator_no_filepath_no_location() {
	mut iter := LineIterator.new('A\n')
	_ := iter.next()?

	loc := iter.location()
	assert loc is diagnostics.NoneLocation
}

fn test_line_iterator_stops_at_maximum_buffer_size() {
	mut accepted := LineIterator.new('a'.repeat(max_line_size - 2))
	assert (accepted.next() or { '' }).len == max_line_size
	mut oversized := LineIterator.new('a'.repeat(max_line_size - 1) + '\nB')
	assert oversized.next() == none
}

// --- SliceIterator ---

fn test_slice_iterator() {
	mut iter := SliceIterator.new(['a', 'b', 'c'])
	assert iter.next()? == 'a'
	assert iter.next()? == 'b'
	assert iter.next()? == 'c'
	assert iter.next() == none
	assert iter.next() == none
}

fn test_slice_iterator_empty() {
	mut iter := SliceIterator.new([])
	assert iter.next() == none
}
