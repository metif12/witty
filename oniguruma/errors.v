module oniguruma

// ErrorKind is the exhaustive error set from pkg/oniguruma/errors.zig. V
// errors carry an integer code rather than a compile-time error-set type, so
// the enum value is stored in IError.code().
pub enum ErrorKind {
	mismatch = 1
	no_support_config
	abort
	memory
	type_bug
	parser_bug
	stack_bug
	undefined_bytecode
	unexpected_bytecode
	match_stack_limit_over
	parse_depth_limit_over
	retry_limit_in_match_over
	retry_limit_in_search_over
	subexp_call_limit_in_search_over
	default_encoding_is_not_set
	specified_encoding_cant_convert_to_wide_char
	fail_to_initialize
	invalid_argument
	end_pattern_at_left_brace
	end_pattern_at_left_bracket
	empty_char_class
	premature_end_of_char_class
	end_pattern_at_escape
	end_pattern_at_meta
	end_pattern_at_control
	meta_code_syntax
	control_code_syntax
	char_class_value_at_end_of_range
	char_class_value_at_start_of_range
	unmatched_range_specifier_in_char_class
	target_of_repeat_operator_not_specified
	target_of_repeat_operator_invalid
	nested_repeat_operator
	unmatched_close_parenthesis
	end_pattern_with_unmatched_parenthesis
	end_pattern_in_group
	undefined_group_option
	invalid_group_option
	invalid_posix_bracket_type
	invalid_look_behind_pattern
	invalid_repeat_range_pattern
	too_big_number
	too_big_number_for_repeat_range
	upper_smaller_than_lower_in_repeat_range
	empty_range_in_char_class
	mismatch_code_length_in_class_range
	too_many_multi_byte_ranges
	too_short_multi_byte_string
	too_big_backref_number
	invalid_backref
	numbered_backref_or_call_not_allowed
	too_many_captures
	too_long_wide_char_value
	undefined_operator
	empty_group_name
	invalid_group_name
	invalid_char_in_group_name
	undefined_name_reference
	undefined_group_reference
	multiplex_defined_name
	multiplex_definition_name_call
	never_ending_recursion
	group_number_over_for_capture_history
	invalid_char_property_name
	invalid_if_else_syntax
	invalid_absent_group_pattern
	invalid_absent_group_generator_pattern
	invalid_callout_pattern
	invalid_callout_name
	undefined_callout_name
	invalid_callout_body
	invalid_callout_tag_name
	invalid_callout_arg
	invalid_code_point_value
	invalid_wide_char_value
	too_big_wide_char_value
	not_supported_encoding_combination
	invalid_combination_of_options
	too_many_user_defined_objects
	too_long_property_name
	very_inefficient_pattern
	library_is_not_initialized
	unknown
}

fn C.witty_onig_error_kind(code int) int

// convert_error returns nonnegative Oniguruma results and translates every
// negative result into the corresponding Ghostty error-set member.
pub fn convert_error(code int) !int {
	if code >= 0 {
		return code
	}
	kind := unsafe { ErrorKind(C.witty_onig_error_kind(code)) }
	message := if kind == .mismatch { mismatch_error } else { kind.str() }
	return error_with_code(message, int(kind))
}

pub fn error_kind_of(err IError) ?ErrorKind {
	if err.code() < int(ErrorKind.mismatch) || err.code() > int(ErrorKind.unknown) {
		return none
	}
	return unsafe { ErrorKind(err.code()) }
}

pub fn is_error(err IError, expected ErrorKind) bool {
	actual := error_kind_of(err) or { return false }
	return actual == expected
}

// ensure_init is the testing helper from pkg/oniguruma/testing.zig.
pub fn ensure_init() ! {
	init([.utf8])!
}
