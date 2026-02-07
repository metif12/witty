module zf

// Stub module for the zf fuzzy finder library.
// XTODO: zf is a Zig fuzzy finder library. Needs a V implementation.

// RankOptions controls ranking behavior.
pub struct RankOptions {
pub:
	to_lower bool
	plain    bool
}

// rank returns a fuzzy match score, or none if there's no match.
// Lower rank means better match.
pub fn rank(text string, tokens []string, opts RankOptions) ?f64 {
	// XTODO: implement fuzzy matching algorithm
	// For now, do a simple substring check.
	query := if opts.to_lower { text.to_lower() } else { text }
	for token in tokens {
		t := if opts.to_lower { token.to_lower() } else { token }
		if !query.contains(t) {
			return none
		}
	}
	return 1.0
}
