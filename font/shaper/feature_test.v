module shaper

// Tests for Feature.from_string parsing.
// This is not *complete* coverage of every possible
// combination of syntax, but it covers quite a few.

fn check_tag(tag [4]u8, s string) bool {
	return tag[0] == s[0] && tag[1] == s[1] && tag[2] == s[2] && tag[3] == s[3]
}

fn test_feature_from_string_tag_only() {
	// Specifying only a tag turns a feature on.
	feat := Feature.from_string('kern') or {
		assert false, 'expected valid feature for "kern"'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 1
}

fn test_feature_from_string_tag_only_with_trailing_comma() {
	feat := Feature.from_string('kern, ') or {
		assert false, 'expected valid feature for "kern, "'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 1
}

fn test_feature_from_string_tag_on() {
	feat := Feature.from_string('kern on') or {
		assert false, 'expected valid feature for "kern on"'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 1
}

fn test_feature_from_string_tag_on_trailing_comma() {
	feat := Feature.from_string('kern on, ') or {
		assert false, 'expected valid feature for "kern on, "'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 1
}

fn test_feature_from_string_plus_prefix() {
	// '+' prefix to explicitly enable feature.
	feat := Feature.from_string('+kern') or {
		assert false, 'expected valid feature for "+kern"'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 1
}

fn test_feature_from_string_plus_prefix_trailing_comma() {
	feat := Feature.from_string('+kern, ') or {
		assert false, 'expected valid feature for "+kern, "'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 1
}

fn test_feature_from_string_quoted_equals_one() {
	feat := Feature.from_string('"kern" = 1') or {
		assert false, 'expected valid feature for quoted kern=1'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 1
}

fn test_feature_from_string_quoted_equals_one_trailing_comma() {
	feat := Feature.from_string('"kern" = 1, ') or {
		assert false, 'expected valid feature for quoted kern=1 with comma'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 1
}

// Boolean settings (off)

fn test_feature_from_string_off() {
	feat := Feature.from_string('kern off') or {
		assert false, 'expected valid feature for "kern off"'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 0
}

fn test_feature_from_string_off_trailing_comma() {
	feat := Feature.from_string('kern off, ') or {
		assert false, 'expected valid feature for "kern off, "'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 0
}

fn test_feature_from_string_minus_prefix() {
	// '-' prefix to explicitly disable feature.
	feat := Feature.from_string("-'kern'") or {
		assert false, "expected valid feature for \"-'kern'\""
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 0
}

fn test_feature_from_string_minus_prefix_trailing_comma() {
	feat := Feature.from_string("-'kern', ") or {
		assert false, "expected valid feature for \"-'kern', \""
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 0
}

fn test_feature_from_string_quoted_equals_zero() {
	feat := Feature.from_string('"kern" = 0') or {
		assert false, 'expected valid feature for quoted kern=0'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 0
}

fn test_feature_from_string_quoted_equals_zero_trailing_comma() {
	feat := Feature.from_string('"kern" = 0, ') or {
		assert false, 'expected valid feature for quoted kern=0 with comma'
		return
	}
	assert check_tag(feat.tag,'kern')
	assert feat.value == 0
}

// Non-boolean settings

fn test_feature_from_string_integer_value() {
	feat := Feature.from_string('aalt=2') or {
		assert false, 'expected valid feature for "aalt=2"'
		return
	}
	assert check_tag(feat.tag,'aalt')
	assert feat.value == 2
}

fn test_feature_from_string_integer_value_trailing_comma() {
	feat := Feature.from_string('aalt=2, ') or {
		assert false, 'expected valid feature for "aalt=2, "'
		return
	}
	assert check_tag(feat.tag,'aalt')
	assert feat.value == 2
}

fn test_feature_from_string_quoted_space_integer() {
	feat := Feature.from_string("'aalt' 2") or {
		assert false, "expected valid feature for \"'aalt' 2\""
		return
	}
	assert check_tag(feat.tag,'aalt')
	assert feat.value == 2
}

fn test_feature_from_string_quoted_space_integer_trailing_comma() {
	feat := Feature.from_string("'aalt' 2, ") or {
		assert false, "expected valid feature for \"'aalt' 2, \""
		return
	}
	assert check_tag(feat.tag,'aalt')
	assert feat.value == 2
}

// Various ambiguous/error cases which should be none

fn test_feature_from_string_bad_number() {
	// "aalt=2x" has trailing non-digit characters
	result := Feature.from_string('aalt=2x')
	assert result == none
}

fn test_feature_from_string_tag_too_long() {
	// Tag is more than 4 characters (first 4 taken, rest causes issues)
	result := Feature.from_string('toolong')
	assert result == none
}

fn test_feature_from_string_tag_too_short() {
	// Tag is less than 4 characters
	result := Feature.from_string('sht')
	assert result == none
}

fn test_feature_from_string_minus_prefix_with_value() {
	// Redundant/conflicting: '-kern 1'
	result := Feature.from_string('-kern 1')
	assert result == none
}

fn test_feature_from_string_minus_prefix_with_on() {
	// Redundant/conflicting: '-kern on'
	result := Feature.from_string('-kern on')
	assert result == none
}

fn test_feature_from_string_empty() {
	result := Feature.from_string('')
	assert result == none
}

fn test_feature_from_string_comma_only() {
	result := Feature.from_string(',')
	assert result == none
}

// FeatureList tests

fn test_feature_list_from_string() {
	feats := FeatureList.from_string('kern, +liga, -calt, aalt=2')
	assert feats.features.len == 4

	assert check_tag(feats.features[0].tag,'kern')
	assert feats.features[0].value == 1

	assert check_tag(feats.features[1].tag,'liga')
	assert feats.features[1].value == 1

	assert check_tag(feats.features[2].tag,'calt')
	assert feats.features[2].value == 0

	assert check_tag(feats.features[3].tag,'aalt')
	assert feats.features[3].value == 2
}

fn test_feature_list_from_string_with_errors() {
	// Invalid entries should be skipped
	feats := FeatureList.from_string('kern, bad, +liga, sht, aalt=2')
	// "bad" is only 3 chars (too short), "sht" is 3 chars (too short)
	assert feats.features.len == 3

	assert check_tag(feats.features[0].tag,'kern')
	assert check_tag(feats.features[1].tag,'liga')
	assert check_tag(feats.features[2].tag,'aalt')
}

fn test_feature_list_append_from_string() {
	mut feats := FeatureList{}
	feats.append_from_string('kern')
	feats.append_from_string('+liga, -calt')
	assert feats.features.len == 3
}

fn test_feature_list_empty_string() {
	feats := FeatureList.from_string('')
	assert feats.features.len == 0
}

fn test_feature_str_boolean_on() {
	feat := Feature{
		tag: [u8(`k`), u8(`e`), u8(`r`), u8(`n`)]!
		value: 1
	}
	assert feat.str() == '+kern'
}

fn test_feature_str_boolean_off() {
	feat := Feature{
		tag: [u8(`k`), u8(`e`), u8(`r`), u8(`n`)]!
		value: 0
	}
	assert feat.str() == '-kern'
}

fn test_feature_str_integer_value() {
	feat := Feature{
		tag: [u8(`a`), u8(`a`), u8(`l`), u8(`t`)]!
		value: 2
	}
	assert feat.str() == 'aalt=2'
}

fn test_default_features() {
	assert default_features.len == 1
	assert check_tag(default_features[0].tag,'liga')
	assert default_features[0].value == 1
}
