module font

// This structure contains a set of SharedGrid structures keyed by
// unique font configuration.
//
// Most terminals (surfaces) will share the same font configuration.
// This structure allows expensive font information such as
// the font atlas, glyph cache, font faces, etc. to be shared.
//
// This structure is thread-safe when the operations are documented
// as thread-safe.
//
// Translated from ghostty/src/font/SharedGridSet.zig

// ============================================================
// SharedGridSet
// ============================================================

// SharedGridSet manages a set of SharedGrid instances keyed by font
// configuration. It allows multiple surfaces with the same font config
// to share a single SharedGrid.
pub struct SharedGridSet {
pub mut:
	// The map of font configurations to SharedGrid instances.
	grids []ReffedGridEntry

	// The font library that is used for all font groups.
	font_lib Library

	// Font discovery mechanism.
	// XTODO: use real Discover type when available.
	font_discover voidptr = unsafe { nil }

	// Lock to protect multi-threaded access to the map.
	// XTODO: use sync.Mutex when V has one; for now single-threaded.
}

// Initialize a new SharedGridSet.
pub fn SharedGridSet.init() !SharedGridSet {
	font_lib := Library.init()!

	return SharedGridSet{
		font_lib: font_lib
	}
}

// deinit releases all resources owned by the SharedGridSet.
pub fn (mut self SharedGridSet) deinit() {
	for mut entry in self.grids {
		entry.key.deinit()
		entry.grid.deinit()
	}
	self.grids = []

	// XTODO: deinit font_discover if non-null

	self.font_lib.deinit()
}

// Returns the number of cached grids.
pub fn (self &SharedGridSet) count() int {
	// XTODO: use lock for thread safety
	return self.grids.len
}

// Initialize a SharedGrid for the given font configuration. If the
// SharedGrid is not present it will be initialized with a ref count of
// 1. If it is present, the ref count will be incremented.
//
// This is NOT thread-safe.
//
// The returned data (key and grid) should never be freed. The memory is
// owned by the set and will be freed when the ref count reaches zero.
pub fn (mut self SharedGridSet) ref(config &GridSetDerivedConfig, font_size DesiredSize) !(GridSetKey, &SharedGrid) {
	mut key := GridSetKey.init(config, font_size)

	// XTODO: use lock for thread safety
	hashcode := key.hashcode()

	// Check if we already have a grid for this config
	for mut entry in self.grids {
		if entry.hashcode == hashcode {
			// We can deinit the key because we found a cached value.
			key.deinit()

			// Increment our ref count and return the cache
			entry.ref_count += 1
			return entry.key, entry.grid
		}
	}

	// A new font config, initialize the cache.

	// Build our collection.
	mut c := self.collection(&key, font_size, config)!

	// Setup our enabled/disabled styles
	mut styles := StyleStatus.init_fill(true)
	styles.set(.bold, config.font_style_bold != .false_)
	styles.set(.italic, config.font_style_italic != .false_)
	styles.set(.bold_italic, config.font_style_bold_italic != .false_)

	// Init our resolver which just requires setting fields.
	resolver := CodepointResolver{
		collection:   c
		styles:       styles
		codepoint_map: key.codepoint_map
	}

	sg := SharedGrid.init(resolver)!
	grid := &sg

	self.grids << ReffedGridEntry{
		key:       key
		hashcode:  hashcode
		grid:      grid
		ref_count: 1
	}

	return key, grid
}

// Builds the Collection for the given configuration key and
// initial font size.
fn (mut self SharedGridSet) collection(key &GridSetKey, size DesiredSize, config &GridSetDerivedConfig) !Collection {
	// A quick note on memory management:
	// - font_lib is owned by the SharedGridSet
	// - metric_modifiers is owned by the key which is freed only when
	//   the ref count for this grid reaches zero.
	load_options := LoadOptions{
		library:             self.font_lib
		size:                size
		freetype_load_flags: key.freetype_load_flags
	}

	mut c := Collection.init()
	c.load_options = load_options
	c.metric_modifiers = key.metric_modifiers

	// XTODO: Search for fonts using discovery (fontconfig / CoreText).
	// When Discover != void:
	//   - For each style (regular, bold, italic, bold_italic):
	//     - Get descriptors from key.descriptors_for_style(style)
	//     - Use discovery to find matching fonts
	//     - Add deferred faces to collection
	//   - If style != regular and desc.variations.len > 0 and font not found:
	//     - Retry with bold=false, italic=false
	//
	// For now, discovery is not available so we skip this step.

	// Complete our styles to ensure we have something to satisfy every
	// possible style request. We do this before adding our built-in font
	// because we want to ensure our built-in styles are fallbacks to
	// the configured styles.
	c.complete_styles(config.font_synthetic_style)!

	// Our built-in font will be used as a backup
	_ = c.add(Face.init_mem(self.font_lib, embedded_variable, load_options.face_options())!, AddOptions{
		style:           .regular
		fallback:        true
		size_adjustment: default_fallback_adjustment
	})!

	// Bold variant with weight=700
	bold_idx := c.add(Face.init_mem(self.font_lib, embedded_variable, load_options.face_options())!, AddOptions{
		style:           .bold
		fallback:        true
		size_adjustment: default_fallback_adjustment
	})!
	mut bold_face := c.get_face(bold_idx)!
	bold_face.set_variations([Variation{
		id: VariationId{
			value: u32(`w`) << 24 | u32(`g`) << 16 | u32(`h`) << 8 | u32(`t`)
		}
		value: 700
	}], load_options.face_options())!

	// Italic variant
	_ = c.add(Face.init_mem(self.font_lib, embedded_variable_italic, load_options.face_options())!, AddOptions{
		style:           .italic
		fallback:        true
		size_adjustment: default_fallback_adjustment
	})!

	// Bold-italic variant with weight=700
	bold_italic_idx := c.add(Face.init_mem(self.font_lib, embedded_variable_italic, load_options.face_options())!, AddOptions{
		style:           .bold_italic
		fallback:        true
		size_adjustment: default_fallback_adjustment
	})!
	mut bold_italic_face := c.get_face(bold_italic_idx)!
	bold_italic_face.set_variations([Variation{
		id: VariationId{
			value: u32(`w`) << 24 | u32(`g`) << 16 | u32(`h`) << 8 | u32(`t`)
		}
		value: 700
	}], load_options.face_options())!

	// Nerd-font symbols fallback.
	_ = c.add(Face.init_mem(self.font_lib, embedded_symbols_nerd_font, load_options.face_options())!, AddOptions{
		style:           .regular
		fallback:        true
		// No size adjustment for the symbols font.
		size_adjustment: .none_
	})!

	// XTODO: On macOS, always search for and add the Apple Emoji font
	// as our preferred emoji font for fallback. We do this in case
	// people add other emoji fonts to their system, we always want to
	// prefer the official one. Users can override this by explicitly
	// specifying a font-family for emoji.
	// Requires CoreText discovery to be available.

	// Emoji fallback. We don't include this on Mac since Mac is expected
	// to always have the Apple Emoji available on the system.
	// XTODO: conditionally include based on platform detection.
	_ = c.add(Face.init_mem(self.font_lib, embedded_emoji, load_options.face_options())!, AddOptions{
		style:           .regular
		fallback:        true
		// No size adjustment for emojis.
		size_adjustment: .none_
	})!
	_ = c.add(Face.init_mem(self.font_lib, embedded_emoji_text, load_options.face_options())!, AddOptions{
		style:           .regular
		fallback:        true
		// No size adjustment for emojis.
		size_adjustment: .none_
	})!

	return c
}

// Decrement the ref count for the given key. If the ref count is zero,
// the grid will be deinitialized and removed from the map.
pub fn (mut self SharedGridSet) deref(key GridSetKey) {
	// XTODO: use lock for thread safety
	hashcode := key.hashcode()

	for i, mut entry in self.grids {
		if entry.hashcode == hashcode {
			assert(entry.ref_count >= 1)

			// If we have more than one reference, decrement and return.
			if entry.ref_count > 1 {
				self.grids[i].ref_count -= 1
				return
			}

			// We are at a zero ref count so deinit the group and remove.
			self.grids[i].key.deinit()
			self.grids[i].grid.deinit()
			self.grids.delete(i)
			return
		}
	}
}

// ============================================================
// ReffedGridEntry
// ============================================================

// Ref-counted SharedGrid entry in the map.
struct ReffedGridEntry {
mut:
	key       GridSetKey
	hashcode  u64
	grid      &SharedGrid = unsafe { nil }
	ref_count u32
}

// ============================================================
// GridSetDerivedConfig
// ============================================================

// This is the configuration required to create a key without having
// to keep the full Ghostty configuration around.
//
// In the original Zig code, this uses Zig's arena allocator and
// config-specific repeatable types. In V, we use simpler types.
pub struct GridSetDerivedConfig {
pub mut:
	font_family             []string
	font_family_bold        []string
	font_family_italic      []string
	font_family_bold_italic []string
	font_style              GridSetFontStyleConfig = .default_
	font_style_bold         GridSetFontStyleConfig = .default_
	font_style_italic       GridSetFontStyleConfig = .default_
	font_style_bold_italic  GridSetFontStyleConfig = .default_
	font_variation             []Variation
	font_variation_bold        []Variation
	font_variation_italic      []Variation
	font_variation_bold_italic []Variation
	font_codepoint_map      CodepointMap
	font_synthetic_style    FontSyntheticStyle
	adjust_cell_width             ?MetricsModifier
	adjust_cell_height            ?MetricsModifier
	adjust_font_baseline          ?MetricsModifier
	adjust_underline_position     ?MetricsModifier
	adjust_underline_thickness    ?MetricsModifier
	adjust_strikethrough_position ?MetricsModifier
	adjust_strikethrough_thickness ?MetricsModifier
	adjust_overline_position      ?MetricsModifier
	adjust_overline_thickness     ?MetricsModifier
	adjust_cursor_thickness       ?MetricsModifier
	adjust_cursor_height          ?MetricsModifier
	adjust_box_thickness          ?MetricsModifier
	adjust_icon_height            ?MetricsModifier
	freetype_load_flags     FreetypeLoadFlags = freetype_load_flags_default
}

// deinit releases resources.
pub fn (mut self GridSetDerivedConfig) deinit() {
	// In V, garbage collection handles memory.
}

// GridSetFontStyleConfig mirrors the config FontStyle which can be
// "default" (use the face's own style name) or "false" (disabled) or
// a specific style name string.
pub enum GridSetFontStyleConfig {
	// Use the default style from the font's style name.
	default_
	// The style is explicitly disabled.
	false_
}

// name_value returns the style name if configured, or none for default.
pub fn (s GridSetFontStyleConfig) name_value() ?string {
	return match s {
		.default_ { none }
		.false_ { none }
	}
}

// ============================================================
// GridSetKey
// ============================================================

// The key used to uniquely identify a font configuration.
pub struct GridSetKey {
pub mut:
	// The descriptors used for all the fonts added to the
	// initial group, including all styles. This is hashed
	// in order so the order matters. All users of the struct
	// should ensure that the order is consistent.
	descriptors []Descriptor

	// These are the offsets into the descriptors array for
	// each style. For example, bold is from
	// offsets[int(FontStyle.bold) - 1] to
	// offsets[int(FontStyle.bold)].
	style_offsets [4]int

	// The codepoint map configuration.
	codepoint_map CodepointMap

	// The metric modifier set configuration.
	metric_modifiers MetricsModifierSet

	// The configured font size for this key. We don't use this
	// directly but it is used as part of the hash for the
	// font grid.
	font_size DesiredSize = DesiredSize{
		points: 12
	}

	// The freetype load flags configuration, only non-void if the
	// freetype backend is enabled.
	freetype_load_flags FreetypeLoadFlags = freetype_load_flags_default
}

// init creates a GridSetKey from a DerivedConfig and font size.
pub fn GridSetKey.init(config_src &GridSetDerivedConfig, font_size DesiredSize) GridSetKey {
	mut descriptors := []Descriptor{}

	// Regular family descriptors
	for family in config_src.font_family {
		descriptors << Descriptor{
			family:     family
			style:      config_src.font_style.name_value()
			size:       font_size.points
			variations: config_src.font_variation
		}
	}

	// Bold family descriptors
	// In all the styled cases below, we prefer to specify an exact
	// style via the `font-style` configuration. If a style is not
	// specified, we use the discovery mechanism to search for a
	// style category such as bold, italic, etc. We can't specify both
	// because the latter will restrict the search to only that. If
	// a user says `font-style = italic` for the bold face for example,
	// no results would be found if we restrict to ALSO searching for
	// italic.
	for family in config_src.font_family_bold {
		bold_style := config_src.font_style_bold.name_value()
		descriptors << Descriptor{
			family:     family
			style:      bold_style
			size:       font_size.points
			bold:       bold_style == none
			variations: config_src.font_variation_bold
		}
	}

	// Italic family descriptors
	for family in config_src.font_family_italic {
		italic_style := config_src.font_style_italic.name_value()
		descriptors << Descriptor{
			family:     family
			style:      italic_style
			size:       font_size.points
			italic:     italic_style == none
			variations: config_src.font_variation_italic
		}
	}

	// Bold-italic family descriptors
	for family in config_src.font_family_bold_italic {
		bi_style := config_src.font_style_bold_italic.name_value()
		descriptors << Descriptor{
			family:     family
			style:      bi_style
			size:       font_size.points
			bold:       bi_style == none
			italic:     bi_style == none
			variations: config_src.font_variation_bold_italic
		}
	}

	// Setup the codepoint map
	codepoint_map := if config_src.font_codepoint_map.entries.len > 0 {
		config_src.font_codepoint_map.clone()
	} else {
		CodepointMap{}
	}

	// Metric modifiers
	mut metric_modifiers := MetricsModifierSet{}
	if m := config_src.adjust_cell_width {
		metric_modifiers.put(.cell_width, m)
	}
	if m := config_src.adjust_cell_height {
		metric_modifiers.put(.cell_height, m)
	}
	if m := config_src.adjust_font_baseline {
		metric_modifiers.put(.cell_baseline, m)
	}
	if m := config_src.adjust_underline_position {
		metric_modifiers.put(.underline_position, m)
	}
	if m := config_src.adjust_underline_thickness {
		metric_modifiers.put(.underline_thickness, m)
	}
	if m := config_src.adjust_strikethrough_position {
		metric_modifiers.put(.strikethrough_position, m)
	}
	if m := config_src.adjust_strikethrough_thickness {
		metric_modifiers.put(.strikethrough_thickness, m)
	}
	if m := config_src.adjust_overline_position {
		metric_modifiers.put(.overline_position, m)
	}
	if m := config_src.adjust_overline_thickness {
		metric_modifiers.put(.overline_thickness, m)
	}
	if m := config_src.adjust_cursor_thickness {
		metric_modifiers.put(.cursor_thickness, m)
	}
	if m := config_src.adjust_cursor_height {
		metric_modifiers.put(.cursor_height, m)
	}
	if m := config_src.adjust_box_thickness {
		metric_modifiers.put(.box_thickness, m)
	}
	if m := config_src.adjust_icon_height {
		metric_modifiers.put(.icon_height, m)
	}

	regular_offset := config_src.font_family.len
	bold_offset := regular_offset + config_src.font_family_bold.len
	italic_offset := bold_offset + config_src.font_family_italic.len
	bold_italic_offset := italic_offset + config_src.font_family_bold_italic.len

	return GridSetKey{
		descriptors:     descriptors
		style_offsets:   [regular_offset, bold_offset, italic_offset, bold_italic_offset]!
		codepoint_map:   codepoint_map
		metric_modifiers: metric_modifiers
		font_size:       font_size
		freetype_load_flags: config_src.freetype_load_flags
	}
}

// deinit releases resources.
pub fn (mut self GridSetKey) deinit() {
	// In V, garbage collection handles memory.
}

// Get the descriptors for the given font style that can be
// used with discovery.
pub fn (self &GridSetKey) descriptors_for_style(style FontStyle) []Descriptor {
	idx := int(style)
	start := if idx == 0 { 0 } else { self.style_offsets[idx - 1] }
	end := self.style_offsets[idx]
	if start >= self.descriptors.len || end > self.descriptors.len || start > end {
		return []
	}
	return self.descriptors[start..end]
}

// hashcode returns a hash code that can be used to uniquely identify
// this font configuration.
pub fn (self &GridSetKey) hashcode() u64 {
	mut state := u64(0)

	// Hash font size
	state = state * 31 + u64(u32(self.font_size.points * 1000.0))
	state = state * 31 + u64(self.font_size.xdpi)
	state = state * 31 + u64(self.font_size.ydpi)

	// Hash descriptors
	state = state * 31 + u64(self.descriptors.len)
	for d in self.descriptors {
		state = state * 31 + d.hashcode()
	}

	// Hash codepoint map
	state = state * 31 + self.codepoint_map.hashcode()

	// Hash metric modifiers
	state = state * 31 + u64(self.metric_modifiers.count())

	// Hash freetype load flags
	state = state * 31 + u64(if self.freetype_load_flags.hinting { 1 } else { 0 })
	state = state * 31 + u64(if self.freetype_load_flags.force_autohint { 1 } else { 0 })
	state = state * 31 + u64(if self.freetype_load_flags.autohint { 1 } else { 0 })
	state = state * 31 + u64(if self.freetype_load_flags.monochrome { 1 } else { 0 })
	state = state * 31 + u64(if self.freetype_load_flags.light { 1 } else { 0 })

	// Hash metric modifier values
	if self.metric_modifiers.count() > 0 {
		for mk in [MetricsKey.cell_width, .cell_height, .cell_baseline,
			.underline_position, .underline_thickness,
			.strikethrough_position, .strikethrough_thickness,
			.overline_position, .overline_thickness,
			.box_thickness, .cursor_height, .icon_height,
			.cursor_thickness] {
			if m := self.metric_modifiers.get(mk) {
				state = state * 31 + u64(int(mk))
				state = state * 31 + m.hash()
			}
		}
	}

	return state
}

// ============================================================
// MetricsKey
// ============================================================

// MetricsKey is an enum of all the available metrics keys that
// can be modified by metric modifiers.
pub enum MetricsKey {
	cell_width
	cell_height
	cell_baseline
	underline_position
	underline_thickness
	strikethrough_position
	strikethrough_thickness
	overline_position
	overline_thickness
	box_thickness
	cursor_height
	cursor_thickness
	icon_height
}

// ============================================================
// MetricsModifier
// ============================================================

// A modifier to apply to a metrics value. The modifier value represents
// a delta, so percent is a percentage to change, not a percentage of.
// For example, "20%" is 20% larger, not 20% of the value. Likewise,
// an absolute value of "20" is 20 larger, not literally 20.
pub struct MetricsModifier {
pub:
	// If true, this is a percent modifier; otherwise absolute.
	is_percent bool
	// The percentage value (1.2 = 20% increase). Used when is_percent == true.
	percent    f64
	// The absolute delta value. Used when is_percent == false.
	absolute   i32
}

// hash returns a hash value for this modifier.
pub fn (m MetricsModifier) hash() u64 {
	if m.is_percent {
		return u64(u32(m.percent * 100000.0))
	}
	return u64(u32(m.absolute) + 0x80000000)
}

// ============================================================
// MetricsModifierSet
// ============================================================

// MetricsModifierSet maps metrics keys to modifiers.
pub struct MetricsModifierSet {
mut:
	entries map[int]MetricsModifier
}

// put adds or replaces a modifier for the given key.
pub fn (mut self MetricsModifierSet) put(key MetricsKey, val MetricsModifier) {
	self.entries[int(key)] = val
}

// get returns the modifier for the given key, or none if not set.
pub fn (self &MetricsModifierSet) get(key MetricsKey) ?MetricsModifier {
	if int(key) in self.entries {
		return self.entries[int(key)]
	}
	return none
}

// count returns the number of modifiers in the set.
pub fn (self &MetricsModifierSet) count() int {
	return self.entries.len
}
