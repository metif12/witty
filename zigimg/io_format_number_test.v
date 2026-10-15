module zigimg

fn test_number_format_defaults_and_mode_bases() {
	value := NumberFormat{}
	assert value.mode == .decimal && value.letter_case == .lower
	assert value.precision == none && value.width == none
	assert value.alignment == .right && value.fill == ` `
	assert NumberMode.decimal.base()? == u8(10)
	assert NumberMode.binary.base()? == u8(2)
	assert NumberMode.octal.base()? == u8(8)
	assert NumberMode.hex.base()? == u8(16)
	assert NumberMode.scientific.base() == none
}

fn test_number_conversion_and_copies_preserve_optional_values() {
	mut options := FormatOptions{
		precision: usize(0)
		width:     ~usize(0)
		alignment: .center
		fill:      u8(255)
	}
	mut number := options.to_number(.scientific, .upper)
	mut copy := number
	options.precision = none
	options.width = usize(0)
	options.fill = 0
	number.mode = .hex
	number.precision = none
	number.width = usize(1)
	number.alignment = .left
	assert copy.mode == .scientific && copy.letter_case == .upper
	assert copy.precision? == usize(0) && copy.width? == ~usize(0)
	assert copy.alignment == .center && copy.fill == u8(255)
	copy.precision = ~usize(0)
	copy.width = none
	copy.letter_case = .lower
	assert number.precision == none && number.width? == usize(1)
	assert number.mode.base()? == u8(16) && number.letter_case == .upper
	assert options.precision == none && options.width? == usize(0)
	assert options.fill == 0
	defaults := FormatOptions{}.to_number(.binary, .upper)
	assert defaults.mode == .binary && defaults.letter_case == .upper
	assert defaults.precision == none && defaults.width == none
	assert defaults.alignment == .right && defaults.fill == ` `
}
