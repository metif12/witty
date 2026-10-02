module unicode

// Independent input comparison: dependency Table2 input was produced by
// unchanged uucode; the existing runtime Table3 output came from Ghostty.
fn test_pinned_uucode_buildtime_input_matches_original_output() {
	context := SymbolsGeneratorContext{}
	for cp in 0 .. 0x200000 {
		assert props_uucode(u32(cp)).eql(get(u32(cp))), 'property mismatch U+${cp:06X}'
		assert context.get(u32(cp))! == is_symbol(u32(cp)), 'symbol mismatch U+${cp:06X}'
	}
}
