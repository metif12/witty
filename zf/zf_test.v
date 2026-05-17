module zf

fn test_rank_plain_requires_substring() {
	assert rank('Monokai Classic', ['kai'], RankOptions{
		plain: true
	}) or { -1 } >= 0
	assert rank('Monokai Classic', ['mnc'], RankOptions{
		plain: true
	}) == none
}

fn test_rank_fuzzy_matches_ordered_characters() {
	score := rank('Monokai Classic', ['mnc'], RankOptions{
		to_lower: true
	}) or {
		assert false, 'expected fuzzy match'
		return
	}

	assert score < 100
	assert rank('Monokai Classic', ['czm'], RankOptions{
		to_lower: true
	}) == none
}

fn test_rank_prefers_compact_matches() {
	compact := rank('abc', ['abc'], RankOptions{}) or {
		assert false, 'expected compact match'
		return
	}
	spread := rank('a very broad c', ['abc'], RankOptions{}) or {
		assert false, 'expected spread match'
		return
	}

	assert compact < spread
}
