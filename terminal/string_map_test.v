module terminal

// Tests for StringMap.
// Translated from Ghostty's StringMap.zig tests.

// XTODO: All StringMap tests require oniguruma regex support and a working
// Screen with selectionString/selectLine. These are stubbed out until those
// dependencies are available.

fn test_string_map_basic() {
	// XTODO: Requires Screen.init, testWriteString, selectLine, selectionString
	// and oniguruma regex to be functional.
	//
	// Original test: creates a screen, writes "1ABCD2EFGH\n3IJKL",
	// selects a line, gets a StringMap via selectionString,
	// searches for regex "[A-B]{2}", and verifies match positions.
}

fn test_string_map_search_iterator_url_detection() {
	// XTODO: Requires oniguruma regex and URL regex pattern.
	//
	// Original test: creates a screen with "hello https://example.com/path world",
	// searches for URL regex, verifies the URL match spans x=6 to x=29.
}

fn test_string_map_search_iterator_url_with_click() {
	// XTODO: Requires oniguruma regex and URL regex pattern.
	//
	// Original test: creates a screen with "hello https://example.com world",
	// simulates clicking at x=14 ("example"), searches for URL regex,
	// and verifies the click position is within the URL match.
}
