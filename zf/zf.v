module zf

// V port of ghostty's vendored zf fuzzy finder (natecraddock/zf).
// See pkg/zf/src/filter.zig for the reference implementation.

// Scoring constants, faithful to zf's filter.zig.
const default_score = 1.0
const bonus_boundary = 8.0
const bonus_head = 10.0
const bonus_camel = 8.0
const bonus_consecutive = 12.0
const bonus_first_char_multiplier = 10.0

// RankOptions controls ranking behavior.
pub struct RankOptions {
pub:
	// to_lower performs case-insensitive matching (smart-case is handled by
	// the caller lowering the query; here it forces case folding).
	to_lower bool
	// plain disables the filename bonus (treats the candidate as plain text
	// rather than a path).
	plain bool
}

// rank returns a fuzzy match score for `text` against all `tokens`, or none if
// any token fails to match. Lower rank means a better match.
//
// When `opts.plain` is set the candidate is treated as literal text: tokens
// must appear as contiguous substrings (no fuzzy skipping) and no filename
// bonus is applied. Otherwise zf's sequential fuzzy matching is used, and the
// basename of the candidate receives a filename bonus.
pub fn rank(text string, tokens []string, opts RankOptions) ?f64 {
	if opts.plain {
		return rank_plain(text, tokens, opts.to_lower)
	}

	filename := basename(text)

	mut total := 0.0
	for token in tokens {
		if r := rank_token(text, filename, token, opts.to_lower) {
			total += r
		} else {
			return none
		}
	}
	return total
}

// rank_plain requires every token to be a contiguous substring of `text`.
fn rank_plain(text string, tokens []string, to_lower bool) ?f64 {
	haystack := if to_lower { text.to_lower() } else { text }

	mut total := 0.0
	for token in tokens {
		needle := if to_lower { token.to_lower() } else { token }
		idx := haystack.index(needle) or { return none }
		// Prefer earlier / word-boundary matches: a small positional cost.
		total += default_score + f64(idx)
	}
	return total
}

// basename returns the final path component of `path`.
fn basename(path string) string {
	if path.len == 0 {
		return path
	}
	// Strip a single trailing slash before searching for the last separator.
	mut end := path.len
	if path[end - 1] == `/` {
		end--
	}
	if end == 0 {
		return path
	}
	mut start := end
	for start > 0 && path[start - 1] != `/` {
		start--
	}
	return path[start..end]
}

// index_of finds `token` inside `str` starting at `start`, matching characters
// in order. Returns the byte range [start, end) of the match, or none.
// This mirrors zf's sequential (fuzzy) character matching.
struct Range {
	start int
	end   int
}

fn index_of_seq(str string, token string, start int, to_lower bool) ?Range {
	if token.len == 0 {
		return none
	}
	mut str_i := start
	mut tok_i := 0
	mut first := -1
	for str_i < str.len && tok_i < token.len {
		if char_eq(str[str_i], token[tok_i], to_lower) {
			if first < 0 {
				first = str_i
			}
			tok_i++
		}
		str_i++
	}
	if tok_i < token.len {
		return none
	}
	return Range{
		start: first
		end:   str_i
	}
}

// char_eq compares two bytes, optionally case-insensitively.
fn char_eq(a u8, b u8, to_lower bool) bool {
	if a == b {
		return true
	}
	if to_lower {
		return to_lower_byte(a) == to_lower_byte(b)
	}
	return false
}

fn to_lower_byte(c u8) u8 {
	if c >= `A` && c <= `Z` {
		return c + 32
	}
	return c
}

// is_boundary reports whether the character at `str[i]` begins a word,
// i.e. the previous char is a separator or the case transitions
// (camelCase boundary).
fn char_class(c u8) int {
	if c >= `a` && c <= `z` {
		return 1 // lower
	}
	if c >= `A` && c <= `Z` {
		return 2 // upper
	}
	if c >= `0` && c <= `9` {
		return 3 // digit
	}
	return 0 // separator/other
}

// bonus_for computes the boundary bonus for matching character at index `i`
// in `str`, based on the previous character.
fn bonus_for(str string, i int) f64 {
	cur := char_class(str[i])
	if i == 0 {
		if cur != 0 {
			return bonus_head
		}
		return 0.0
	}
	prev := char_class(str[i - 1])
	// Transition from a separator/non-alnum into an alnum: word boundary.
	if prev == 0 && cur != 0 {
		return bonus_boundary
	}
	// camelCase boundary: lower/digit -> upper.
	if (prev == 1 || prev == 3) && cur == 2 {
		return bonus_camel
	}
	return 0.0
}

// rank_token computes the rank of a single token against `str`, using the
// filename (if any) for the filename bonus. Lower is better; none means no match.
fn rank_token(str string, filename string, token string, to_lower bool) ?f64 {
	if str.len == 0 || token.len == 0 {
		return none
	}

	// Ensure the token appears in order at all; also gives us a starting point.
	first_range := index_of_seq(str, token, 0, to_lower) or { return none }

	// Compute the best (minimum) rank by trying each possible starting position
	// for the first token character, matching the remaining characters greedily
	// while tracking gaps, boundary bonuses, and consecutive-run bonuses.
	mut best := max_f64()

	mut start := first_range.start
	for start < str.len {
		// Only consider starts where the first char matches.
		if !char_eq(str[start], token[0], to_lower) {
			start++
			continue
		}
		if r := score_from(str, token, start, to_lower) {
			if r < best {
				best = r
			}
		}
		start++
	}

	if best == max_f64() {
		return none
	}

	// Filename bonus: if the token also matches within the basename, the match
	// is more relevant, so reduce (improve) the rank.
	if filename.len > 0 {
		if _ := index_of_seq(filename, token, 0, to_lower) {
			best /= 2.0
		}
	}

	return best
}

// score_from matches `token` against `str` beginning at `start` (str[start]
// must equal token[0]) and returns the accumulated rank, or none if the full
// token cannot be matched in order from here.
fn score_from(str string, token string, start int, to_lower bool) ?f64 {
	mut total := 0.0
	mut tok_i := 0
	mut str_i := start
	mut last_match := -2 // index in str of the previously matched char

	for str_i < str.len && tok_i < token.len {
		if char_eq(str[str_i], token[tok_i], to_lower) {
			// Base cost for this matched character.
			mut char_rank := default_score

			// Gap penalty: distance from the previous matched character.
			if last_match >= 0 {
				gap := str_i - last_match - 1
				char_rank += f64(gap)
			}

			// Reward matches at word boundaries.
			bonus := bonus_for(str, str_i)

			// Reward consecutive matches (no gap since previous match).
			mut consecutive := 0.0
			if last_match >= 0 && str_i - last_match == 1 {
				consecutive = bonus_consecutive
			}

			// The first character of the token weighs more heavily so that
			// boundary/head starts are strongly preferred.
			if tok_i == 0 {
				char_rank = char_rank - (bonus * bonus_first_char_multiplier)
			} else {
				char_rank = char_rank - bonus - consecutive
			}

			total += char_rank
			last_match = str_i
			tok_i++
		}
		str_i++
	}

	if tok_i < token.len {
		return none
	}
	return total
}

fn max_f64() f64 {
	return 1.7976931348623157e308
}
