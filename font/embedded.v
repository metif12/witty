module font

// Fonts that can be embedded with Ghostty. Note they are only actually
// embedded in the binary if they are referenced by the code, so fonts
// used for tests will not result in the final binary being larger.
//
// Be careful to ensure that any fonts you embed are licensed for
// redistribution and include their license as necessary.
//
// Translated from ghostty/src/font/embedded.zig
//
// XTODO: V cannot @embedFile like Zig. These are empty byte array stubs
// that need to be replaced with real embedded font data. Options include:
//   1. Read font files at runtime from a known path
//   2. Use V's $embed_file() compile-time embedding
//   3. Use a build step to generate V source with byte literals
// For now, all constants are empty []u8 placeholders.

// Default fonts that we prefer for Ghostty.
pub const embedded_variable = []u8{}
pub const embedded_variable_italic = []u8{}

// Symbols-only nerd font.
pub const embedded_symbols_nerd_font = []u8{}

// Static jetbrains mono faces, currently unused.
pub const embedded_regular = []u8{}
pub const embedded_bold = []u8{}
pub const embedded_italic = []u8{}
pub const embedded_bold_italic = []u8{}

// Emoji fonts
pub const embedded_emoji = []u8{}
pub const embedded_emoji_text = []u8{}

// Fonts below are ONLY used for testing.

// Fonts with general properties
pub const embedded_arabic = []u8{}

// A font for testing which is patched with nerd font symbols.
pub const embedded_test_nerd_font = []u8{}

// Specific font families below:
pub const embedded_code_new_roman = []u8{}
pub const embedded_inconsolata = []u8{}
pub const embedded_geist_mono = []u8{}
pub const embedded_jetbrains_mono = []u8{}
pub const embedded_julia_mono = []u8{}

// Cozette is a unique font because it embeds some emoji characters
// but has a text presentation.
pub const embedded_cozette = []u8{}

// Monaspace has weird ligature behaviors we want to test in our shapers
// so we embed it here.
pub const embedded_monaspace_neon = []u8{}

// Terminus TTF is a scalable font with bitmap glyphs at various sizes.
pub const embedded_terminus_ttf = []u8{}

// Spleen is a monospaced bitmap font available in multiple formats.
// Used for testing bitmap font support across different file formats.
pub const embedded_spleen_bdf = []u8{}
pub const embedded_spleen_pcf = []u8{}
pub const embedded_spleen_otb = []u8{}
