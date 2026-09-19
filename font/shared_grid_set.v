module font

import sync
import zig_fmt
import fontstyle

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

	// Font discovery is initialized lazily because Fontconfig/CoreText setup
	// is relatively expensive and some library users only use embedded faces.
	font_discover             Discover
	font_discover_initialized bool

	// Lock to protect multi-threaded access to the map.
	lock &sync.Mutex = unsafe { nil }
}

// Initialize a new SharedGridSet.
pub fn SharedGridSet.init() !SharedGridSet {
	font_lib := Library.init()!

	return SharedGridSet{
		font_lib: font_lib
		lock: sync.new_mutex()
	}
}

// deinit releases all resources owned by the SharedGridSet.
pub fn (mut self SharedGridSet) deinit() {
	for mut entry in self.grids {
		entry.key.deinit()
		entry.grid.deinit()
	}
	self.grids = []

	if self.font_discover_initialized {
		self.font_discover.deinit()
		self.font_discover_initialized = false
	}

	self.font_lib.deinit()
}

// Returns the number of cached grids.
pub fn (self &SharedGridSet) count() int {
	self.lock.lock()
	defer { self.lock.unlock() }
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

	self.lock.lock()
	defer { self.lock.unlock() }
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
	styles.set(.bold, config.font_style_bold.kind != .false_)
	styles.set(.italic, config.font_style_italic.kind != .false_)
	styles.set(.bold_italic, config.font_style_bold_italic.kind != .false_)

	// Init our resolver which just requires setting fields.
	resolver := CodepointResolver{
		collection: c
		styles: styles
		discover: self.discover()!
		codepoint_map: key.codepoint_map
	}

	sg := SharedGrid.init(resolver)!
	grid := &sg

	self.grids << ReffedGridEntry{
		key: key
		hashcode: hashcode
		grid: grid
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
		library: self.font_lib
		size: size
		freetype_load_flags: key.freetype_load_flags
	}

	mut c := Collection.init()
	c.load_options = load_options
	c.metric_modifiers = key.metric_modifiers

	// Search configured families in priority order for every style.
	mut disco := self.discover()!
	for style in [Style.regular, .bold, .italic, .bold_italic] {
		for desc in key.descriptors_for_style(style) {
			if face := discover_loaded_face(disco, desc, self.font_lib, load_options) {
				c.add(face, AddOptions{
					style: style
					fallback: false
					size_adjustment: .none_
				})!
				continue
			}

			// Variable fonts sometimes omit the bold/italic symbolic trait even
			// though their axes can produce the requested style. Retry without
			// the trait filter in that case, exactly as Ghostty does.
			if style != .regular && desc.variations.len > 0 {
				mut retry := desc.clone()
				retry.bold = false
				retry.italic = false
				if face := discover_loaded_face(disco, retry, self.font_lib, load_options) {
					c.add(face, AddOptions{
						style: style
						fallback: false
						size_adjustment: .none_
					})!
				}
			}
		}
	}

	// Complete our styles to ensure we have something to satisfy every
	// possible style request. We do this before adding our built-in font
	// because we want to ensure our built-in styles are fallbacks to
	// the configured styles.
	c.complete_styles(config.font_synthetic_style)!

	// Our built-in font will be used as a backup
	_ = c.add(Face.init_mem(self.font_lib, embedded_variable, load_options.face_options())!, AddOptions{
		style: .regular
		fallback: true
		size_adjustment: default_fallback_adjustment
	})!

	// Bold variant with weight=700
	bold_idx := c.add(Face.init_mem(self.font_lib, embedded_variable, load_options.face_options())!, AddOptions{
		style: .bold
		fallback: true
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
		style: .italic
		fallback: true
		size_adjustment: default_fallback_adjustment
	})!

	// Bold-italic variant with weight=700
	bold_italic_idx := c.add(Face.init_mem(self.font_lib, embedded_variable_italic, load_options.face_options())!, AddOptions{
		style: .bold_italic
		fallback: true
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
		style: .regular
		fallback: true
		// No size adjustment for the symbols font.
		size_adjustment: .none_
	})!

	// Prefer the platform emoji face on macOS. Other targets use the
	// bundled color and text emoji faces.
	$if macos {
		if face := discover_loaded_face(disco, Descriptor{
			family: 'Apple Color Emoji'
			size: size.points
		}, self.font_lib, load_options) {
			c.add(face, AddOptions{
				style: .regular
				fallback: true
				size_adjustment: .none_
			})!
		}
	} $else {
		_ = c.add(Face.init_mem(self.font_lib, embedded_emoji, load_options.face_options())!, AddOptions{
			style: .regular
			fallback: true
			size_adjustment: .none_
		})!
		_ = c.add(Face.init_mem(self.font_lib, embedded_emoji_text, load_options.face_options())!, AddOptions{
			style: .regular
			fallback: true
			size_adjustment: .none_
		})!
	}

	return c
}

// Initialize discovery once for the lifetime of the set. Fontconfig in
// particular is not safe to repeatedly tear down and initialize.
fn (mut self SharedGridSet) discover() !&Discover {
	if !self.font_discover_initialized {
		self.font_discover = Discover.init()
		self.font_discover_initialized = true
	}
	return &self.font_discover
}

// Resolve a descriptor and eagerly load the first usable result. Ghostty can
// retain native discovery charset objects for deferred matching; Witty keeps
// the same lookup order but loads here so the complete face charmap is
// available on every backend.
fn discover_loaded_face(disco &Discover, desc Descriptor, library Library, load_options LoadOptions) ?Face {
	mut it := disco.discover(desc) or { return none }
	defer { it.deinit() }
	for {
		mut deferred := it.next() or { return none }
		face := deferred.load(library, load_options.face_options()) or {
			deferred.deinit()
			continue
		}
		deferred.deinit()
		return face
	}
	return none
}

// Decrement the ref count for the given key. If the ref count is zero,
// the grid will be deinitialized and removed from the map.
pub fn (mut self SharedGridSet) deref(key GridSetKey) {
	self.lock.lock()
	defer { self.lock.unlock() }
	hashcode := key.hashcode()

	for i, mut entry in self.grids {
		if entry.hashcode == hashcode {
			assert entry.ref_count >= 1

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
	font_family                    []string
	font_family_bold               []string
	font_family_italic             []string
	font_family_bold_italic        []string
	font_style                     fontstyle.FontStyle
	font_style_bold                fontstyle.FontStyle
	font_style_italic              fontstyle.FontStyle
	font_style_bold_italic         fontstyle.FontStyle
	font_variation                 []Variation
	font_variation_bold            []Variation
	font_variation_italic          []Variation
	font_variation_bold_italic     []Variation
	font_codepoint_map             CodepointMap
	font_synthetic_style           FontSyntheticStyle
	adjust_cell_width              ?MetricsModifier
	adjust_cell_height             ?MetricsModifier
	adjust_font_baseline           ?MetricsModifier
	adjust_underline_position      ?MetricsModifier
	adjust_underline_thickness     ?MetricsModifier
	adjust_strikethrough_position  ?MetricsModifier
	adjust_strikethrough_thickness ?MetricsModifier
	adjust_overline_position       ?MetricsModifier
	adjust_overline_thickness      ?MetricsModifier
	adjust_cursor_thickness        ?MetricsModifier
	adjust_cursor_height           ?MetricsModifier
	adjust_box_thickness           ?MetricsModifier
	adjust_icon_height             ?MetricsModifier
	freetype_load_flags            FreetypeLoadFlags = freetype_load_flags_default
}

// deinit releases resources.
pub fn (mut self GridSetDerivedConfig) deinit() {
	// In V, garbage collection handles memory.
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
	// offsets[int(Style.bold) - 1] to
	// offsets[int(Style.bold)].
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
			family: family
			style: config_src.font_style.name_value()
			size: font_size.points
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
			family: family
			style: bold_style
			size: font_size.points
			bold: bold_style == none
			variations: config_src.font_variation_bold
		}
	}

	// Italic family descriptors
	for family in config_src.font_family_italic {
		italic_style := config_src.font_style_italic.name_value()
		descriptors << Descriptor{
			family: family
			style: italic_style
			size: font_size.points
			italic: italic_style == none
			variations: config_src.font_variation_italic
		}
	}

	// Bold-italic family descriptors
	for family in config_src.font_family_bold_italic {
		bi_style := config_src.font_style_bold_italic.name_value()
		descriptors << Descriptor{
			family: family
			style: bi_style
			size: font_size.points
			bold: bi_style == none
			italic: bi_style == none
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
		descriptors: descriptors
		style_offsets: [regular_offset, bold_offset, italic_offset, bold_italic_offset]!
		codepoint_map: codepoint_map
		metric_modifiers: metric_modifiers
		font_size: font_size
		freetype_load_flags: config_src.freetype_load_flags
	}
}

// deinit releases resources.
pub fn (mut self GridSetKey) deinit() {
	// In V, garbage collection handles memory.
}

// Get the descriptors for the given font style that can be
// used with discovery.
pub fn (self &GridSetKey) descriptors_for_style(style Style) []Descriptor {
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
	mut hasher := SourceHash{}

	// Hash font size using its exact source bit representation.
	hasher.put_f32(self.font_size.points)
	hasher.put_u16(self.font_size.xdpi)
	hasher.put_u16(self.font_size.ydpi)

	// Hash descriptors directly into the same stream.
	hasher.put_u64(u64(self.descriptors.len))
	for d in self.descriptors {
		d.hash_into(mut hasher)
	}

	self.codepoint_map.hash_into(mut hasher)

	hasher.put_u64(u64(self.metric_modifiers.count()))

	// Ghostty hashes this packed struct as one byte in declaration order.
	hasher.put_u8(self.freetype_load_flags.int_val())

	// Hash metric modifier values
	if self.metric_modifiers.count() > 0 {
		$for enum_value in MetricsKey.values {
			mk := enum_value.value
			if m := self.metric_modifiers.get(mk) {
				hasher.put_u8(u8(mk))
				m.hash_into(mut hasher)
			}
		}
	}

	return hasher.final()
}

// ============================================================
// MetricsKey
// ============================================================

// MetricsKey is an enum of all the available metrics keys that
// can be modified by metric modifiers.
pub enum MetricsKey as u8 {
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
	cursor_thickness
	cursor_height
	icon_height
	icon_height_single
	face_width
	face_height
	face_y
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
	percent f64
	// The absolute delta value. Used when is_percent == false.
	absolute i32
}

// format_entry is Metrics.Modifier.formatEntry. Percent modifiers store a
// multiplier, so the configuration value converts it back to a delta percent.
pub fn (m MetricsModifier) format_entry() string {
	if m.is_percent {
		value := (m.percent - 1.0) * 100.0
		if value == f64(i64(value)) {
			return '${i64(value)}%'
		}
		return '${value}%'
	}
	return m.absolute.str()
}

// hash returns a hash value for this modifier.
pub fn (m MetricsModifier) hash() u64 {
	mut hasher := SourceHash{}
	m.hash_into(mut hasher)
	return hasher.final()
}

// hash_into hashes the active tagged-union payload exactly as Ghostty does.
fn (m MetricsModifier) hash_into(mut hasher SourceHash) {
	if m.is_percent {
		hasher.put_u8(0)
		hasher.put_f64(m.percent)
		return
	}
	hasher.put_u8(1)
	hasher.put_i32(m.absolute)
}

// parse parses a modifier value. If the value ends in "%" it is assumed to be
// a percent, otherwise the value is parsed as an integer.
//
// A percent modifier stores the multiplier: "20%" -> 1.2, "-20%" -> 0.8, and
// any value <= -100% clamps to 0.
pub fn MetricsModifier.parse(input string) !MetricsModifier {
	if input.len == 0 {
		return error('invalid format')
	}

	if input[input.len - 1] == `%` {
		mut percent := zig_fmt.parse_f64(input[0..input.len - 1]) or {
			return error('invalid format')
		}
		percent /= 100.0

		if percent <= -1.0 {
			return MetricsModifier{
				is_percent: true
				percent: 0
			}
		}
		return MetricsModifier{
			is_percent: true
			percent: 1.0 + percent
		}
	}

	n := parse_metrics_i32(input) or { return error('invalid format') }
	return MetricsModifier{
		is_percent: false
		absolute: n
	}
}

// Direct translation of `std.fmt.parseInt(i32, input, 10)`.
fn parse_metrics_i32(input string) ?i32 {
	return i32(zig_fmt.parse_int_signed(input, 32, 10) or { return none })
}

// apply applies this modifier to an unsigned integer value, matching the Zig
// Modifier.apply semantics for unsigned integers.
pub fn (m MetricsModifier) apply(v u32) u32 {
	return metrics_modifier_apply_u32(m, v)
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
