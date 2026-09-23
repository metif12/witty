module zf

// V translation of Ghostty's pinned zf 0.10.3 dependency.

// RankOptions controls ranking behavior.
pub struct RankOptions {
pub:
	// to_lower converts candidate bytes to lowercase while ranking. As in zf,
	// callers are responsible for lowercasing the tokens.
	to_lower bool = true
	// plain disables the filepath-specific filename and strict-path algorithms.
	plain bool
}

// RankTokenOptions controls ranking of one token.
pub struct RankTokenOptions {
pub:
	to_lower    bool
	strict_path bool
	filename    ?string
}

struct PathIterator {
	str string
mut:
	index int
}

fn (mut iter PathIterator) next() ?string {
	if iter.index >= iter.str.len {
		return none
	}

	start := iter.index
	if is_separator(iter.str[iter.index]) {
		iter.index++
		return iter.str[start..iter.index]
	}

	for iter.index < iter.str.len {
		if is_separator(iter.str[iter.index]) {
			return iter.str[start..iter.index]
		}
		iter.index++
	}
	return iter.str[start..]
}

struct ScanResult {
	rank  f64
	index int
}

fn is_separator(byte u8) bool {
	$if windows {
		return byte == `\\`
	} $else {
		return byte == `/`
	}
}

// has_separator reports whether str contains the platform path separator.
pub fn has_separator(str string) bool {
	for byte in str.bytes() {
		if is_separator(byte) {
			return true
		}
	}
	return false
}

// segment_len scans left and right for the length of the path segment at index.
pub fn segment_len(str string, index int) int {
	if is_separator(str[index]) {
		return 1
	}
	mut start := index
	mut end := index
	for start > 0 {
		if is_separator(str[start - 1]) {
			break
		}
		start--
	}
	for end < str.len && !is_separator(str[end]) {
		end++
	}
	return end - start
}

fn ascii_lower(byte u8) u8 {
	if byte >= `A` && byte <= `Z` {
		return byte + (`a` - `A`)
	}
	return byte
}

// index_of mirrors zf's byte search: in insensitive mode only the candidate
// is folded, because the public API requires callers to lowercase tokens.
fn index_of(str string, start_index int, value u8, case_sensitive bool) ?int {
	mut i := start_index
	for i < str.len {
		matches := if case_sensitive { str[i] == value } else { ascii_lower(str[i]) == value }
		if matches {
			return i
		}
		i++
	}
	return none
}

fn is_start_of_word(byte u8) bool {
	return is_separator(byte) || byte == `_` || byte == `-` || byte == `.` || byte == ` `
}

// scan_to_end is the core zf ranking algorithm.
fn scan_to_end(str string, token string, start_index int, case_sensitive bool, strict_path bool) ?ScanResult {
	mut rank_value := 1.0
	mut last_index := start_index
	mut last_sequential := false

	if start_index > 0 && !is_start_of_word(str[start_index - 1]) {
		rank_value += 2.0
	}

	for c in token.bytes() {
		idx := index_of(str, last_index + 1, c, case_sensitive) or { return none }
		if strict_path && has_separator(str[last_index..idx + 1]) {
			return none
		}

		if idx == last_index + 1 {
			if !last_sequential {
				last_sequential = true
				rank_value += 1.0
			}
		} else {
			if !is_start_of_word(str[idx - 1]) {
				rank_value += 2.0
			}
			last_sequential = false
			rank_value += f64(idx - last_index)
		}
		last_index = idx
	}

	return ScanResult{
		rank: rank_value
		index: last_index + 1
	}
}

fn basename(path string) string {
	if path.len == 0 {
		return path
	}
	mut end := path.len
	for end > 0 && is_separator(path[end - 1]) {
		end--
	}
	if end == 0 {
		return path[path.len - 1..]
	}
	mut start := end
	for start > 0 && !is_separator(path[start - 1]) {
		start--
	}
	return path[start..end]
}

fn rank_token_impl(str string, filename ?string, token string, case_sensitive bool, strict_path bool) ?f64 {
	if str.len == 0 || token.len == 0 {
		return none
	}

	mut best_rank := ?f64(none)
	if strict_path {
		mut iter := PathIterator{
			str: token
		}
		mut start := 0
		for {
			segment := iter.next() or { break }
			mut search_index := start
			mut found := false
			for {
				start_index := index_of(str, search_index, segment[0], case_sensitive) or { break }
				search_index = start_index + 1
				scan := scan_to_end(str, segment[1..], start_index, case_sensitive, true) or {
					continue
				}
				path_segment_len := segment_len(str, start_index)
				coverage := 1.0 - (f64(segment.len) / f64(path_segment_len))
				rank_value := coverage * scan.rank
				if current := best_rank {
					best_rank = current + rank_value
				} else {
					best_rank = rank_value
				}
				start = scan.index
				found = true
				break
			}
			if !found {
				return none
			}
		}
		return best_rank
	}

	if filename_value := filename {
		mut search_index := 0
		for {
			start_index := index_of(filename_value, search_index, token[0], case_sensitive) or {
				break
			}
			search_index = start_index + 1
			scan := scan_to_end(filename_value, token[1..], start_index, case_sensitive, false) or { break }
			if current := best_rank {
				if scan.rank < current {
					best_rank = scan.rank
				}
			} else {
				best_rank = scan.rank
			}
		}

		if mut current := best_rank {
			current /= 2.0
			if token.len == filename_value.len {
				current /= 2.0
			} else {
				coverage := 1.0 - (f64(token.len) / f64(filename_value.len))
				current *= coverage
			}
			return current
		}
	}

	mut search_index := 0
	for {
		start_index := index_of(str, search_index, token[0], case_sensitive) or { break }
		search_index = start_index + 1
		scan := scan_to_end(str, token[1..], start_index, case_sensitive, false) or { break }
		if current := best_rank {
			if scan.rank < current {
				best_rank = scan.rank
			}
		} else {
			best_rank = scan.rank
		}
	}
	return best_rank
}

// rank returns the sum of each token's best score, or none if any token fails.
pub fn rank(str string, tokens []string, opts RankOptions) ?f64 {
	filename := if opts.plain { ?string(none) } else { ?string(basename(str)) }
	mut sum := 0.0
	for token in tokens {
		strict_path := !opts.plain && has_separator(token)
		if token_rank := rank_token_impl(str, filename, token, !opts.to_lower, strict_path) {
			sum += token_rank
		} else {
			return none
		}
	}
	return sum
}

// rank_token ranks one token with the same options as zf's library API.
pub fn rank_token(str string, token string, opts RankTokenOptions) ?f64 {
	return rank_token_impl(str, opts.filename, token, !opts.to_lower, opts.strict_path)
}

fn append_bounded(mut values []int, value int, limit int) {
	if values.len < limit {
		values << value
	}
}

fn append_all_bounded(mut values []int, source []int, limit int) {
	for value in source {
		append_bounded(mut values, value, limit)
	}
}

fn scan_to_end_highlight(str string, token string, start_index int, offset int, mut matched []int, case_sensitive bool, strict_path bool) ?ScanResult {
	mut rank_value := 1.0
	mut last_index := start_index
	mut last_sequential := false

	if start_index > 0 && !is_start_of_word(str[start_index - 1]) {
		rank_value += 2.0
	}

	for c in token.bytes() {
		idx := index_of(str, last_index + 1, c, case_sensitive) or { return none }
		if strict_path && has_separator(str[last_index..idx + 1]) {
			return none
		}

		append_bounded(mut matched, idx + offset, 1024)
		if idx == last_index + 1 {
			if !last_sequential {
				last_sequential = true
				rank_value += 1.0
			}
		} else {
			if !is_start_of_word(str[idx - 1]) {
				rank_value += 2.0
			}
			last_sequential = false
			rank_value += f64(idx - last_index)
		}
		last_index = idx
	}

	return ScanResult{
		rank: rank_value
		index: last_index + 1
	}
}

fn highlight_token_impl(str string, filename ?string, token string, case_sensitive bool, strict_path bool, max_matches int) []int {
	if str.len == 0 || token.len == 0 {
		return []
	}

	mut best_rank := ?f64(none)
	mut matched := []int{cap: if token.len < 1024 { token.len } else { 1024 }}
	mut best_matched := []int{cap: max_matches}

	if strict_path {
		mut iter := PathIterator{
			str: token
		}
		mut start := 0
		for {
			segment := iter.next() or { break }
			mut search_index := start
			mut found := false
			for {
				start_index := index_of(str, search_index, segment[0], case_sensitive) or { break }
				search_index = start_index + 1
				append_bounded(mut matched, start_index, 1024)
				scan := scan_to_end_highlight(str, segment[1..], start_index, 0, mut matched, case_sensitive, true) or {
					matched.clear()
					continue
				}
				path_segment_len := segment_len(str, start_index)
				coverage := 1.0 - (f64(segment.len) / f64(path_segment_len))
				rank_value := coverage * scan.rank
				if current := best_rank {
					best_rank = current + rank_value
				} else {
					best_rank = rank_value
				}
				start = scan.index
				append_all_bounded(mut best_matched, matched, max_matches)
				found = true
				break
			}
			if !found {
				return []
			}
			matched.clear()
		}
		return best_matched
	}

	if filename_value := filename {
		offset := str.len - filename_value.len - if is_separator(str[str.len - 1]) { 1 } else { 0 }
		mut search_index := 0
		for {
			start_index := index_of(filename_value, search_index, token[0], case_sensitive) or {
				break
			}
			search_index = start_index + 1
			append_bounded(mut matched, start_index + offset, 1024)
			scan := scan_to_end_highlight(filename_value, token[1..], start_index, offset, mut matched, case_sensitive, false) or { break }
			if current := best_rank {
				if scan.rank < current {
					best_rank = scan.rank
					best_matched.clear()
					append_all_bounded(mut best_matched, matched, max_matches)
				}
			} else {
				best_rank = scan.rank
				append_all_bounded(mut best_matched, matched, max_matches)
			}
			matched.clear()
		}
		if best_rank != none {
			return best_matched
		}
	}

	matched.clear()
	mut search_index := 0
	for {
		start_index := index_of(str, search_index, token[0], case_sensitive) or { break }
		search_index = start_index + 1
		append_bounded(mut matched, start_index, 1024)
		scan := scan_to_end_highlight(str, token[1..], start_index, 0, mut matched, case_sensitive, false) or { break }
		if current := best_rank {
			if scan.rank < current {
				best_rank = scan.rank
				best_matched.clear()
				append_all_bounded(mut best_matched, matched, max_matches)
			}
		} else {
			best_rank = scan.rank
			append_all_bounded(mut best_matched, matched, max_matches)
		}
		matched.clear()
	}
	return best_matched
}

// highlight writes match indices into matches and returns the populated slice.
pub fn highlight(str string, tokens []string, mut matches []int, opts RankOptions) []int {
	filename := if opts.plain { ?string(none) } else { ?string(basename(str)) }
	mut index := 0
	for token in tokens {
		strict_path := !opts.plain && has_separator(token)
		matched := highlight_token_impl(str, filename, token, !opts.to_lower, strict_path, matches.len - index)
		for value in matched {
			matches[index] = value
			index++
		}
	}
	return matches[..index]
}

// highlight_token writes match indices for one token into matches.
pub fn highlight_token(str string, token string, mut matches []int, opts RankTokenOptions) []int {
	matched := highlight_token_impl(str, opts.filename, token, !opts.to_lower, opts.strict_path, matches.len)
	for i, value in matched {
		matches[i] = value
	}
	return matches[..matched.len]
}
