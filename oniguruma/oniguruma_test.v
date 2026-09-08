module oniguruma

fn test_option_bit_order() {
	assert Options{ extend: true }.int() == u32(2)
}

fn test_convert_error() {
	assert convert_error(42)! == 42
	assert error_string(-1)!.len > 0
	if _ := convert_error(-123456) {
		assert false, 'expected unknown error'
	} else {
		assert is_error(err, .unknown)
	}
}

fn test_ensure_init() {
	ensure_init()!
}

fn test_all_linked_encoding_constants() {
	init([.ascii, .iso_8859_1, .iso_8859_2, .iso_8859_3, .iso_8859_4, .iso_8859_5, .iso_8859_6,
		.iso_8859_7, .iso_8859_8, .iso_8859_9, .iso_8859_10, .iso_8859_11, .iso_8859_13, .iso_8859_14,
		.iso_8859_15, .iso_8859_16, .utf8, .utf16_be, .utf16_le, .utf32_be, .utf32_le, .euc_jp,
		.euc_tw, .euc_kr, .euc_cn, .sjis, .koi8_r, .cp1251, .big5, .gb18030])!
	deinit()
	assert int(Encoding.koi8) == 26
}

fn test_all_syntax_constants() {
	init([.utf8])!
	defer { deinit() }
	for syntax in [Syntax.default_, .asis, .posix_basic, .posix_extended, .emacs, .grep, .gnu_regex,
		.java, .perl, .perl_ng, .ruby, .oniguruma] {
		mut regex := Regex.init('foo', Options{}, .utf8, syntax, none)!
		regex.deinit()
	}
}

fn test_regex_error_info() {
	init([.utf8])!
	defer { deinit() }
	mut info := ErrorInfo{}
	if _ := Regex.init('(', Options{}, .utf8, .default_, &info) {
		assert false, 'expected invalid regex'
	} else {
		assert error_kind_of(err) != none
		assert info.encoding == .utf8
	}
}

fn test_regex_search_and_mismatch() {
	init([.utf8])!
	defer { deinit() }
	mut regex := Regex.init('foo', Options{}, .utf8, .default_, none)!
	defer { regex.deinit() }
	mut region := regex.search('hello foo bar', Options{})!
	defer { region.deinit() }
	assert region.count() == 1
	assert region.starts() == [6]
	assert region.ends() == [9]
	if _ := regex.search('hello', Options{}) {
		assert false, 'expected mismatch'
	} else {
		assert is_error(err, .mismatch)
	}
}
