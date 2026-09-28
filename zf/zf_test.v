module zf

fn assert_rank(expected f64, actual ?f64) {
	value := actual or {
		assert false, 'expected a match with rank ${expected}'
		return
	}
	assert value == expected
}

fn test_path_iterator() {
	mut iter := PathIterator{
		str: 'src/data/b.v'
	}
	assert iter.next()? == 'src'
	assert iter.next()? == '/'
	assert iter.next()? == 'data'
	assert iter.next()? == '/'
	assert iter.next()? == 'b.v'
	assert iter.next() == none
}

fn test_segment_len() {
	assert segment_len('a', 0) == 1
	assert segment_len('/a', 1) == 1
	assert segment_len('/a/', 1) == 1
	assert segment_len('src/main.v', 0) == 3
	assert segment_len('src/main.v', 2) == 3
	assert segment_len('src/main.v', 5) == 6
	assert segment_len('a/b', 1) == 1
}

fn test_basename_matches_pinned_zig_path_semantics() {
	assert basename('') == ''
	assert basename('/') == ''
	assert basename('///') == ''
	assert basename('/aaa/') == 'aaa'
	assert basename('basename.ext//') == 'basename.ext'

	$if windows {
		assert basename('C:') == ''
		assert basename('C:\\') == ''
		assert basename('C:\\dir\\base.ext') == 'base.ext'
		assert basename('C:/dir/base.ext') == 'base.ext'
		assert basename('C:base.ext') == 'base.ext'
	} $else {
		assert basename('C:') == 'C:'
		assert basename('\\dir\\base.ext') == '\\dir\\base.ext'
	}
}

fn test_rank_matches_pinned_zf_scores() {
	assert_rank(4.0, rank('Monokai Classic', ['kai'], RankOptions{
		to_lower: true
		plain: true
	}))
	// Plain mode disables path handling; it does not disable fuzzy matching.
	assert_rank(11.0, rank('Monokai Classic', ['mnc'], RankOptions{
		to_lower: true
		plain: true
	}))
	assert_rank(2.0, rank('abc', ['abc'], RankOptions{
		to_lower: true
		plain: true
	}))
	assert_rank(14.0, rank('a very broad c', ['abc'], RankOptions{
		to_lower: true
		plain: true
	}))
	assert_rank(4.4, rank('Monokai Classic', ['mnc'], RankOptions{
		to_lower: true
	}))
	assert_rank(0.5, rank('path/to/file.ext', ['file'], RankOptions{
		to_lower: true
	}))
	assert_rank(1.9090909090909092, rank('src/config/__init__.py', ['con/i'], RankOptions{
		to_lower: true
	}))
}

fn test_rank_library_interface() {
	assert rank('abcdefg', ['a', 'z'], RankOptions{}) == none
	assert rank('abcdefg', ['a', 'b'], RankOptions{}) != none
	assert rank('abcdefg', ['a', 'B'], RankOptions{
		to_lower: false
	}) == none
	assert rank('aBcdefg', ['a', 'B'], RankOptions{
		to_lower: false
	}) != none
	assert rank('a/path/to/file', ['zig'], RankOptions{}) == none
	assert rank('a/path/to/file', ['path', 'file'], RankOptions{}) != none

	assert rank_token('abcdefg', 'a', RankTokenOptions{}) != none
	assert rank_token('abcdefg', 'z', RankTokenOptions{}) == none
	assert rank_token('abcdefG', 'G', RankTokenOptions{
		to_lower: false
	}) != none
	assert rank_token('abcdefg', 'A', RankTokenOptions{
		to_lower: false
	}) == none
	assert rank_token('a/path/to/file', 'file', RankTokenOptions{
		filename: 'file'
	}) != none
	assert rank_token('a/path/to/file', 'zig', RankTokenOptions{
		filename: 'file'
	}) == none

	// zf folds only the candidate: callers must lowercase insensitive tokens.
	assert rank_token('abcdefg', 'A', RankTokenOptions{
		to_lower: true
	}) == none
	assert rank('', ['a'], RankOptions{}) == none
	assert rank_token('', 'a', RankTokenOptions{}) == none
	assert rank('a', [''], RankOptions{}) == none
	assert rank_token('a', '', RankTokenOptions{}) == none
}

fn test_rank_strict_path() {
	assert rank_token('a/b', 'ab', RankTokenOptions{
		strict_path: true
	}) == none
	assert rank_token('a/b/c', 'abc', RankTokenOptions{
		strict_path: true
	}) == none
	assert rank_token('a/b/c', 'a/c', RankTokenOptions{
		strict_path: true
	}) != none
	assert rank_token('src/config/__init__.py', 'con/i', RankTokenOptions{
		strict_path: true
	}) != none
	assert rank_token('./app/models/foo/bar/baz.rb', 'a/m/f/b/baz', RankTokenOptions{
		strict_path: true
	}) != none
}

fn test_highlight_library_interface() {
	mut matches := []usize{len: 128}
	assert highlight('abcdef', ['a', 'f'], mut matches, RankOptions{}) == [usize(0), 5]
	assert highlight('abcdeF', ['a', 'F'], mut matches, RankOptions{
		to_lower: false
	}) == [usize(0), 5]
	assert highlight('a/path/to/file', ['path', 'file'], mut matches, RankOptions{}) == [
		usize(2),
		3,
		4,
		5,
		10,
		11,
		12,
		13,
	]
	assert highlight('lib/ziglyph/zig.mod', ['ziglyph'], mut matches, RankOptions{}) == [
		usize(4),
		5,
		6,
		7,
		8,
		9,
		10,
	]

	assert highlight_token('abcdef', 'a', mut matches, RankTokenOptions{}) == [usize(0)]
	assert highlight_token('abcdeF', 'F', mut matches, RankTokenOptions{
		to_lower: false
	}) == [usize(5)]
	assert highlight_token('a/path/to/file', 'file', mut matches, RankTokenOptions{
		filename: 'file'
	}) == [usize(10), 11, 12, 13]
	assert highlight_token('s/', 's', mut matches, RankTokenOptions{
		filename: 's'
	}) == [usize(0)]
	assert highlight_token('/this/is/path/not/a/file/', 'file', mut matches, RankTokenOptions{
		filename: 'file'
	}) == [usize(20), 21, 22, 23]

	assert highlight('ababab', ['aab'], mut matches, RankOptions{}) == [usize(0), 2, 3]
	assert highlight('abbbbbabab', ['aab'], mut matches, RankOptions{}) == [usize(6), 8, 9]
	assert highlight('abcdefg', ['acg'], mut matches, RankOptions{}) == [usize(0), 2, 6]
	assert highlight('__init__.py', ['initpy'], mut matches, RankOptions{}) == [usize(2), 3, 4,
		5, 9, 10]
}

fn test_highlight_respects_output_buffer() {
	mut matches := []usize{len: 4}
	assert highlight('abcd', ['ab', 'cd', 'abcd'], mut matches, RankOptions{}) == [usize(0),
		1, 2, 3]
	assert highlight('wxyz', ['wxy', 'xyz'], mut matches, RankOptions{}) == [usize(0), 1,
		2, 1]
}
