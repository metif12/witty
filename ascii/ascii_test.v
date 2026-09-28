module ascii

fn test_ascii_case_comparison_preserves_non_ascii_bytes() {
	assert eql_ignore_case('HEl💩Lo!', 'hel💩lo!')
	assert !eql_ignore_case('hElLo!', 'hello! ')
	assert !eql_ignore_case('Khaki', 'khaki')
	assert !eql_ignore_case('İnf', 'inf')
}

fn test_ascii_index_of_ignore_case() {
	assert index_of_ignore_case('ExtraBold Italic', 'bold') or { -1 } == 5
	assert index_of_ignore_case('regular', '') or { -1 } == 0
	assert index_of_ignore_case('short', 'longer') == none
	assert index_of_ignore_case('Khaki', 'kh') == none
}

fn test_ascii_case_order() {
	assert order_ignore_case('Alpha', 'alpha') == 0
	assert order_ignore_case('a', 'BB') < 0
	assert order_ignore_case('bbb', 'BB') > 0
	assert order_ignore_case('İ', 'i') > 0
}

fn test_ascii_lower_string() {
	assert lower_string('AbC-123') == 'abc-123'
	assert lower_string('İnf') == 'İnf'
}
