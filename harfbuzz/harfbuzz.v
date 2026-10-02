module harfbuzz

// HarfBuzz text shaping library bindings.
//
// This module provides V bindings for the HarfBuzz text shaping library,
// used for converting Unicode text into positioned glyphs.
//
// HarfBuzz is the most commonly used text shaping engine. It handles
// complex text layout including ligatures, kerning, and right-to-left
// scripts.

// C compiler flags for HarfBuzz library.
$if managed_native ? {
	$if !system_harfbuzz ? {
		#flag -I@VMODROOT/.witty-build/include/harfbuzz
	}
	$if !system_freetype ? {
		#flag -I@VMODROOT/.witty-build/deps/freetype/include
	}
} $else {
	#flag darwin -I/opt/homebrew/include
	#flag darwin -I/opt/homebrew/include/harfbuzz
	#flag darwin -I/opt/homebrew/include/freetype2
	#flag darwin -L/opt/homebrew/lib
	#flag linux -I/usr/include/harfbuzz
	#flag linux -I/usr/include/freetype2
	#flag -lharfbuzz
}

#include <hb.h>
#include <hb-ft.h>

// === Opaque C types ===

@[typedef]
struct C.hb_buffer_t {}

@[typedef]
struct C.hb_font_t {}

@[typedef]
struct C.hb_face_t {}

@[typedef]
struct C.hb_blob_t {}

// === C struct field declarations (only fields we access) ===
// The actual struct layouts come from the #include'd header.

struct C.hb_glyph_info_t {
	codepoint u32
	mask      u32
	cluster   u32
	var1      u32
	var2      u32
}

struct C.hb_glyph_position_t {
	x_advance i32
	y_advance i32
	x_offset  i32
	y_offset  i32
	var       u32
}

struct C.hb_feature_t {
	tag   u32
	value u32
	start u32
	end   u32
}

// === C function declarations ===

// Buffer lifecycle
fn C.hb_buffer_create() &C.hb_buffer_t
fn C.hb_buffer_destroy(buffer &C.hb_buffer_t)
fn C.hb_buffer_reset(buffer &C.hb_buffer_t)

// Buffer properties
fn C.hb_buffer_set_content_type(buffer &C.hb_buffer_t, content_type u32)
fn C.hb_buffer_get_content_type(buffer &C.hb_buffer_t) u32
fn C.hb_buffer_set_cluster_level(buffer &C.hb_buffer_t, cluster_level u32)
fn C.hb_buffer_set_direction(buffer &C.hb_buffer_t, direction u32)
fn C.hb_buffer_get_direction(buffer &C.hb_buffer_t) u32
fn C.hb_buffer_set_script(buffer &C.hb_buffer_t, script u32)
fn C.hb_buffer_get_script(buffer &C.hb_buffer_t) u32
fn C.hb_buffer_set_language(buffer &C.hb_buffer_t, language voidptr)
fn C.hb_buffer_get_language(buffer &C.hb_buffer_t) voidptr

// Buffer content
fn C.hb_buffer_add(buffer &C.hb_buffer_t, codepoint u32, cluster u32)
fn C.hb_buffer_add_codepoints(buffer &C.hb_buffer_t, text &u32, text_length int, item_offset u32, item_length int)
fn C.hb_buffer_add_utf32(buffer &C.hb_buffer_t, text &u32, text_length int, item_offset u32, item_length int)
fn C.hb_buffer_add_utf16(buffer &C.hb_buffer_t, text &u16, text_length int, item_offset u32, item_length int)
fn C.hb_buffer_add_utf8(buffer &C.hb_buffer_t, text &u8, text_length int, item_offset u32, item_length int)
fn C.hb_buffer_add_latin1(buffer &C.hb_buffer_t, text &u8, text_length int, item_offset u32, item_length int)
fn C.hb_buffer_guess_segment_properties(buffer &C.hb_buffer_t)

// Buffer results
fn C.hb_buffer_get_length(buffer &C.hb_buffer_t) u32
fn C.hb_buffer_get_glyph_infos(buffer &C.hb_buffer_t, length &u32) &C.hb_glyph_info_t
fn C.hb_buffer_get_glyph_positions(buffer &C.hb_buffer_t, length &u32) &C.hb_glyph_position_t

// Shaping
fn C.hb_shape(font &C.hb_font_t, buffer &C.hb_buffer_t, features &C.hb_feature_t, num_features u32)

// Feature parsing
fn C.hb_feature_from_string(str &u8, len int, feature &C.hb_feature_t) int
fn C.hb_feature_to_string(feature &C.hb_feature_t, buf &u8, size u32)

// Language and version
fn C.hb_language_from_string(str &u8, len int) voidptr
fn C.hb_language_to_string(language voidptr) &char
fn C.hb_language_get_default() voidptr
fn C.hb_version(major &u32, minor &u32, micro &u32)
fn C.hb_version_atleast(major u32, minor u32, micro u32) int
fn C.hb_version_string() &char

// Font
fn C.hb_font_create(face &C.hb_face_t) &C.hb_font_t
fn C.hb_font_set_scale(font &C.hb_font_t, x_scale int, y_scale int)
fn C.hb_ft_face_create_referenced(ft_face voidptr) &C.hb_face_t
fn C.hb_ft_font_create_referenced(ft_face voidptr) &C.hb_font_t
fn C.hb_ft_font_set_funcs(font &C.hb_font_t)
fn C.hb_font_destroy(font &C.hb_font_t)

// Face
fn C.hb_face_destroy(face &C.hb_face_t)

// Blob
fn C.hb_blob_create_or_fail(data &u8, length u32, mode u32, user_data voidptr, destroy fn (voidptr)) &C.hb_blob_t
fn C.hb_blob_destroy(blob &C.hb_blob_t)
fn C.hb_blob_set_user_data(blob &C.hb_blob_t, key voidptr, data voidptr, destroy fn (voidptr), replace int) int
fn C.hb_blob_get_user_data(blob &C.hb_blob_t, key voidptr) voidptr

// === V enums matching HarfBuzz C enum values ===

// ContentType specifies the type of content in a buffer.
pub enum ContentType as u8 {
	invalid = 0
	// Buffer contains Unicode codepoints (before shaping).
	unicode = 1
	// Buffer contains glyph indices (after shaping).
	glyphs  = 2
}

// ClusterLevel controls the granularity of cluster tracking.
pub enum ClusterLevel as u8 {
	// Monotone graphemes: clusters merge across grapheme boundaries.
	monotone_graphemes  = 0
	// Monotone characters: clusters merge within grapheme boundaries.
	monotone_characters = 1
	// Characters: each codepoint maintains its own cluster.
	// This gives the most granularity, matching CoreText behavior.
	characters          = 2
	// Graphemes without monotonic cluster forcing.
	graphemes           = 3
}

// Direction specifies the text direction.
pub enum Direction as u8 {
	invalid = 0
	// Left to right.
	ltr     = 4
	// Right to left.
	rtl     = 5
	// Top to bottom.
	ttb     = 6
	// Bottom to top.
	bit     = 7
}

// MemoryMode controls whether HarfBuzz borrows, copies, or may mutate blob data.
pub enum MemoryMode as u8 {
	duplicate                  = 0
	readonly                   = 1
	writable                   = 2
	readonly_may_make_writable = 3
}

// Script is the complete ISO 15924 tag set exposed by the pinned wrapper.
pub enum Script as u32 {
	common                 = 0x5a797979
	inherited              = 0x5a696e68
	unknown                = 0x5a7a7a7a
	arabic                 = 0x41726162
	armenian               = 0x41726d6e
	bengali                = 0x42656e67
	cyrillic               = 0x4379726c
	devanagari             = 0x44657661
	georgian               = 0x47656f72
	greek                  = 0x4772656b
	gujarati               = 0x47756a72
	gurmukhi               = 0x47757275
	hangul                 = 0x48616e67
	han                    = 0x48616e69
	hebrew                 = 0x48656272
	hiragana               = 0x48697261
	kannada                = 0x4b6e6461
	katakana               = 0x4b616e61
	lao                    = 0x4c616f6f
	latin                  = 0x4c61746e
	malayalam              = 0x4d6c796d
	oriya                  = 0x4f727961
	tamil                  = 0x54616d6c
	telugu                 = 0x54656c75
	thai                   = 0x54686169
	tibetan                = 0x54696274
	bopomofo               = 0x426f706f
	braille                = 0x42726169
	canadian_syllabics     = 0x43616e73
	cherokee               = 0x43686572
	ethiopic               = 0x45746869
	khmer                  = 0x4b686d72
	mongolian              = 0x4d6f6e67
	myanmar                = 0x4d796d72
	ogham                  = 0x4f67616d
	runic                  = 0x52756e72
	sinhala                = 0x53696e68
	syriac                 = 0x53797263
	thaana                 = 0x54686161
	yi                     = 0x59696969
	deseret                = 0x44737274
	gothic                 = 0x476f7468
	old_italic             = 0x4974616c
	buhid                  = 0x42756864
	hanunoo                = 0x48616e6f
	tagalog                = 0x54676c67
	tagbanwa               = 0x54616762
	cypriot                = 0x43707274
	limbu                  = 0x4c696d62
	linear_b               = 0x4c696e62
	osmanya                = 0x4f736d61
	shavian                = 0x53686177
	tai_le                 = 0x54616c65
	ugaritic               = 0x55676172
	buginese               = 0x42756769
	coptic                 = 0x436f7074
	glagolitic             = 0x476c6167
	kharoshthi             = 0x4b686172
	new_tai_lue            = 0x54616c75
	old_persian            = 0x5870656f
	syloti_nagri           = 0x53796c6f
	tifinagh               = 0x54666e67
	balinese               = 0x42616c69
	cuneiform              = 0x58737578
	nko                    = 0x4e6b6f6f
	phags_pa               = 0x50686167
	phoenician             = 0x50686e78
	carian                 = 0x43617269
	cham                   = 0x4368616d
	kayah_li               = 0x4b616c69
	lepcha                 = 0x4c657063
	lycian                 = 0x4c796369
	lydian                 = 0x4c796469
	ol_chiki               = 0x4f6c636b
	rejang                 = 0x526a6e67
	saurashtra             = 0x53617572
	sundanese              = 0x53756e64
	vai                    = 0x56616969
	avestan                = 0x41767374
	bamum                  = 0x42616d75
	egyptian_hieroglyphs   = 0x45677970
	imperial_aramaic       = 0x41726d69
	inscriptional_pahlavi  = 0x50686c69
	inscriptional_parthian = 0x50727469
	javanese               = 0x4a617661
	kaithi                 = 0x4b746869
	lisu                   = 0x4c697375
	meetei_mayek           = 0x4d746569
	old_south_arabian      = 0x53617262
	old_turkic             = 0x4f726b68
	samaritan              = 0x53616d72
	tai_tham               = 0x4c616e61
	tai_viet               = 0x54617674
	batak                  = 0x4261746b
	brahmi                 = 0x42726168
	mandaic                = 0x4d616e64
	chakma                 = 0x43616b6d
	meroitic_cursive       = 0x4d657263
	meroitic_hieroglyphs   = 0x4d65726f
	miao                   = 0x506c7264
	sharada                = 0x53687264
	sora_sompeng           = 0x536f7261
	takri                  = 0x54616b72
	bassa_vah              = 0x42617373
	caucasian_albanian     = 0x41676862
	duployan               = 0x4475706c
	elbasan                = 0x456c6261
	grantha                = 0x4772616e
	khojki                 = 0x4b686f6a
	khudawadi              = 0x53696e64
	linear_a               = 0x4c696e61
	mahajani               = 0x4d61686a
	manichaean             = 0x4d616e69
	mende_kikakui          = 0x4d656e64
	modi                   = 0x4d6f6469
	mro                    = 0x4d726f6f
	nabataean              = 0x4e626174
	old_north_arabian      = 0x4e617262
	old_permic             = 0x5065726d
	pahawh_hmong           = 0x486d6e67
	palmyrene              = 0x50616c6d
	pau_cin_hau            = 0x50617563
	psalter_pahlavi        = 0x50686c70
	siddham                = 0x53696464
	tirhuta                = 0x54697268
	warang_citi            = 0x57617261
	ahom                   = 0x41686f6d
	anatolian_hieroglyphs  = 0x486c7577
	hatran                 = 0x48617472
	multani                = 0x4d756c74
	old_hungarian          = 0x48756e67
	signwriting            = 0x53676e77
	adlam                  = 0x41646c6d
	bhaiksuki              = 0x42686b73
	marchen                = 0x4d617263
	osage                  = 0x4f736765
	tangut                 = 0x54616e67
	newa                   = 0x4e657761
	masaram_gondi          = 0x476f6e6d
	nushu                  = 0x4e736875
	soyombo                = 0x536f796f
	zanabazar_square       = 0x5a616e62
	dogra                  = 0x446f6772
	gunjala_gondi          = 0x476f6e67
	hanifi_rohingya        = 0x526f6867
	makasar                = 0x4d616b61
	medefaidrin            = 0x4d656466
	old_sogdian            = 0x536f676f
	sogdian                = 0x536f6764
	elymaic                = 0x456c796d
	nandinagari            = 0x4e616e64
	nyiakeng_puachue_hmong = 0x486d6e70
	wancho                 = 0x5763686f
	chorasmian             = 0x43687273
	dives_akuru            = 0x4469616b
	khitan_small_script    = 0x4b697473
	yezidi                 = 0x59657a69
	cypro_minoan           = 0x43706d6e
	old_uyghur             = 0x4f756772
	tangsa                 = 0x546e7361
	toto                   = 0x546f746f
	vithkuqi               = 0x56697468
	math                   = 0x5a6d7468
	invalid                = 0x00000000
}

// === V wrapper types ===

// Language wraps HarfBuzz's interned BCP-47 language handle.
pub struct Language {
	handle voidptr = unsafe { nil }
}

pub fn Language.from_string(value string) Language {
	return Language{
		handle: C.hb_language_from_string(value.str, value.len)
	}
}

pub fn (language Language) to_string() string {
	ptr := C.hb_language_to_string(language.handle)
	return if isnil(ptr) { '' } else { unsafe { cstring_to_vstring(ptr) } }
}

pub fn Language.get_default() Language {
	return Language{
		handle: C.hb_language_get_default()
	}
}

pub struct Version {
pub:
	major u32
	minor u32
	micro u32
}

pub fn version() Version {
	mut result := Version{}
	C.hb_version(&result.major, &result.minor, &result.micro)
	return result
}

pub fn version_at_least(required Version) bool {
	return C.hb_version_atleast(required.major, required.minor, required.micro) != 0
}

pub fn version_string() string {
	ptr := C.hb_version_string()
	return if isnil(ptr) { '' } else { unsafe { cstring_to_vstring(ptr) } }
}

// GlyphInfo matches the complete native hb_glyph_info_t layout.
pub struct GlyphInfo {
pub:
	codepoint u32
	mask      u32
	cluster   u32
	var1      u32
	var2      u32
}

// GlyphPosition matches the complete native hb_glyph_position_t layout.
pub struct GlyphPosition {
pub:
	x_advance i32
	y_advance i32
	x_offset  i32
	y_offset  i32
	var       u32
}

// Feature represents a single OpenType font feature setting for shaping.
pub struct Feature {
pub mut:
	// The 4-byte OpenType feature tag as a big-endian u32.
	tag u32
	// The value of the feature (0 = disabled, 1 = enabled, or higher).
	value u32
	// Start index in the buffer where this feature applies.
	start u32
	// End index in the buffer where this feature applies.
	end u32
}

pub fn Feature.from_string(value string) ?Feature {
	mut c_feature := C.hb_feature_t{}
	if C.hb_feature_from_string(value.str, value.len, &c_feature) == 0 {
		return none
	}
	return Feature{
		tag:   c_feature.tag
		value: c_feature.value
		start: c_feature.start
		end:   c_feature.end
	}
}

pub fn (feature &Feature) to_string(mut buf []u8) {
	if buf.len == 0 {
		return
	}
	c_feature := C.hb_feature_t{
		tag:   feature.tag
		value: feature.value
		start: feature.start
		end:   feature.end
	}
	C.hb_feature_to_string(&c_feature, &u8(buf.data), u32(buf.len))
}

// Global start constant: feature applies from the beginning of the buffer.
pub const feature_global_start = u32(0)

// Global end constant: feature applies to the end of the buffer.
pub const feature_global_end = u32(0xFFFFFFFF)

// === Buffer ===

// Buffer is a HarfBuzz buffer for text shaping.
// The buffer holds Unicode codepoints before shaping and
// glyph indices with positions after shaping. It is reused
// across multiple shaping calls to avoid allocations.
pub struct Buffer {
pub mut:
	ptr &C.hb_buffer_t = unsafe { nil }
}

// create allocates a new HarfBuzz buffer.
pub fn Buffer.create() !Buffer {
	p := C.hb_buffer_create()
	if p == unsafe { nil } {
		return error('failed to create HarfBuzz buffer')
	}
	return Buffer{
		ptr: p
	}
}

// destroy releases the buffer and all associated resources.
pub fn (mut b Buffer) destroy() {
	if b.ptr != unsafe { nil } {
		C.hb_buffer_destroy(b.ptr)
		b.ptr = unsafe { nil }
	}
}

// reset clears the buffer contents while retaining the buffer object.
// Unicode properties, segment properties, and flags are not cleared.
pub fn (mut b Buffer) reset() {
	C.hb_buffer_reset(b.ptr)
}

// set_content_type sets the content type of the buffer.
pub fn (mut b Buffer) set_content_type(ct ContentType) {
	C.hb_buffer_set_content_type(b.ptr, u32(ct))
}

pub fn (b &Buffer) get_content_type() ContentType {
	return unsafe { ContentType(C.hb_buffer_get_content_type(b.ptr)) }
}

// set_cluster_level sets the cluster level for the buffer.
// Setting to .characters gives the most granularity for cluster tracking.
pub fn (mut b Buffer) set_cluster_level(level ClusterLevel) {
	C.hb_buffer_set_cluster_level(b.ptr, u32(level))
}

// set_direction sets the text direction for the buffer.
pub fn (mut b Buffer) set_direction(dir Direction) {
	C.hb_buffer_set_direction(b.ptr, u32(dir))
}

pub fn (b &Buffer) get_direction() Direction {
	return unsafe { Direction(C.hb_buffer_get_direction(b.ptr)) }
}

pub fn (mut b Buffer) set_script(script Script) {
	C.hb_buffer_set_script(b.ptr, u32(script))
}

pub fn (b &Buffer) get_script() Script {
	return unsafe { Script(C.hb_buffer_get_script(b.ptr)) }
}

pub fn (mut b Buffer) set_language(language Language) {
	C.hb_buffer_set_language(b.ptr, language.handle)
}

pub fn (b &Buffer) get_language() Language {
	return Language{
		handle: C.hb_buffer_get_language(b.ptr)
	}
}

// add adds a single Unicode codepoint to the buffer with a cluster value.
// The cluster value is used to associate the codepoint with its source position.
pub fn (mut b Buffer) add(codepoint u32, cluster u32) {
	C.hb_buffer_add(b.ptr, codepoint, cluster)
}

pub fn (mut b Buffer) add_codepoints(text []u32) {
	ptr := if text.len == 0 { &u32(unsafe { nil }) } else { unsafe { &text[0] } }
	C.hb_buffer_add_codepoints(b.ptr, ptr, text.len, 0, text.len)
}

pub fn (mut b Buffer) add_utf32(text []u32) {
	ptr := if text.len == 0 { &u32(unsafe { nil }) } else { unsafe { &text[0] } }
	C.hb_buffer_add_utf32(b.ptr, ptr, text.len, 0, text.len)
}

pub fn (mut b Buffer) add_utf16(text []u16) {
	ptr := if text.len == 0 { &u16(unsafe { nil }) } else { unsafe { &text[0] } }
	C.hb_buffer_add_utf16(b.ptr, ptr, text.len, 0, text.len)
}

pub fn (mut b Buffer) add_utf8(text []u8) {
	ptr := if text.len == 0 { &u8(unsafe { nil }) } else { unsafe { &text[0] } }
	C.hb_buffer_add_utf8(b.ptr, ptr, text.len, 0, text.len)
}

pub fn (mut b Buffer) add_latin1(text []u8) {
	ptr := if text.len == 0 { &u8(unsafe { nil }) } else { unsafe { &text[0] } }
	C.hb_buffer_add_latin1(b.ptr, ptr, text.len, 0, text.len)
}

// guess_segment_properties fills in missing buffer properties
// (direction, script, language) based on the buffer contents.
pub fn (mut b Buffer) guess_segment_properties() {
	C.hb_buffer_guess_segment_properties(b.ptr)
}

// get_length returns the number of items in the buffer.
pub fn (b &Buffer) get_length() u32 {
	return C.hb_buffer_get_length(b.ptr)
}

// get_glyph_infos returns the glyph information array from the buffer.
// Before shaping, codepoints are Unicode values. After shaping, they are glyph indices.
pub fn (b &Buffer) get_glyph_infos() []GlyphInfo {
	mut length := u32(0)
	ptr := C.hb_buffer_get_glyph_infos(b.ptr, &length)
	if ptr == unsafe { nil } || length == 0 {
		return []
	}
	mut result := []GlyphInfo{}
	unsafe {
		result.data = voidptr(ptr)
		result.len = int(length)
		result.cap = int(length)
		result.flags = .nogrow | .noshrink | .nofree
	}
	return result
}

// get_glyph_positions returns the glyph position array from the buffer.
// Returns none if positions are not available (e.g., before shaping).
pub fn (b &Buffer) get_glyph_positions() ?[]GlyphPosition {
	mut length := u32(0)
	ptr := C.hb_buffer_get_glyph_positions(b.ptr, &length)
	if ptr == unsafe { nil } {
		return none
	}
	if length == 0 {
		return []
	}
	mut result := []GlyphPosition{}
	unsafe {
		result.data = voidptr(ptr)
		result.len = int(length)
		result.cap = int(length)
		result.flags = .nogrow | .noshrink | .nofree
	}
	return result
}

// === Blob ===

// Blob wraps binary data with HarfBuzz reference-counted lifetime management.
pub struct Blob {
pub mut:
	ptr &C.hb_blob_t = unsafe { nil }
}

// create wraps data according to mode. Callers must retain borrowed data for
// readonly modes; duplicate copies it immediately.
pub fn Blob.create(data []u8, mode MemoryMode) !Blob {
	if u64(data.len) > u64(0xffffffff) {
		return error('HarfBuzz blob data exceeds the u32 length limit')
	}
	data_ptr := if data.len == 0 { &u8(unsafe { nil }) } else { unsafe { &data[0] } }
	blob := C.hb_blob_create_or_fail(data_ptr, u32(data.len), u32(mode), unsafe { nil },
		unsafe { nil })
	if blob == unsafe { nil } {
		return error('failed to create HarfBuzz blob')
	}
	return Blob{
		ptr: blob
	}
}

// destroy releases the blob and any user data owned by it.
pub fn (mut b Blob) destroy() {
	if b.ptr != unsafe { nil } {
		C.hb_blob_destroy(b.ptr)
		b.ptr = unsafe { nil }
	}
}

// set_user_data attaches data to a caller-owned key. The optional callback is
// invoked by HarfBuzz when the value is replaced or the blob is destroyed.
pub fn (b Blob) set_user_data(key voidptr, data voidptr, destroy ?fn (voidptr), replace bool) bool {
	replace_int := if replace { 1 } else { 0 }
	if destroy_fn := destroy {
		return C.hb_blob_set_user_data(b.ptr, key, data, destroy_fn, replace_int) > 0
	}
	return C.hb_blob_set_user_data(b.ptr, key, data, unsafe { nil }, replace_int) > 0
}

// get_user_data returns the value associated with key, if any.
pub fn (b Blob) get_user_data(key voidptr) voidptr {
	return C.hb_blob_get_user_data(b.ptr, key)
}

// === Font ===

// Font represents a HarfBuzz font object.
// Wraps an hb_font_t handle for use with the shaping API.
pub struct Font {
pub mut:
	ptr &C.hb_font_t = unsafe { nil }
}

// create creates a HarfBuzz font from a face.
pub fn Font.create(face &Face) !Font {
	fnt := C.hb_font_create(face.ptr)
	if fnt == unsafe { nil } {
		return error('failed to create HarfBuzz font')
	}
	return Font{
		ptr: fnt
	}
}

// create_freetype creates a HarfBuzz font which references an FT_Face.
// HarfBuzz configures its scale and glyph callbacks from the current
// FreeType face size, matching hb_ft_font_create_referenced.
pub fn Font.create_freetype(ft_face voidptr) !Font {
	if isnil(ft_face) {
		return error('cannot create HarfBuzz font from a null FreeType face')
	}
	fnt := C.hb_ft_font_create_referenced(ft_face)
	if fnt == unsafe { nil } {
		return error('failed to create HarfBuzz FreeType font')
	}
	return Font{
		ptr: fnt
	}
}

// set_scale sets the font's horizontal and vertical scale.
pub fn (f Font) set_scale(x u32, y u32) {
	if x > u32(0x7fffffff) || y > u32(0x7fffffff) {
		panic('HarfBuzz font scale exceeds the signed 32-bit limit')
	}
	C.hb_font_set_scale(f.ptr, int(x), int(y))
}

// set_freetype_funcs installs HarfBuzz's FreeType font callbacks.
pub fn (f Font) set_freetype_funcs() {
	C.hb_ft_font_set_funcs(f.ptr)
}

// destroy releases the font object.
pub fn (mut f Font) destroy() {
	if f.ptr != unsafe { nil } {
		C.hb_font_destroy(f.ptr)
		f.ptr = unsafe { nil }
	}
}

// === Face ===

// Face represents a HarfBuzz face object (a single font face from a font file).
pub struct Face {
pub mut:
	ptr &C.hb_face_t = unsafe { nil }
}

// create_freetype creates a HarfBuzz face which retains the FT_Face.
pub fn Face.create_freetype(ft_face voidptr) !Face {
	if isnil(ft_face) {
		return error('cannot create HarfBuzz face from a null FreeType face')
	}
	face := C.hb_ft_face_create_referenced(ft_face)
	if face == unsafe { nil } {
		return error('failed to create HarfBuzz FreeType face')
	}
	return Face{
		ptr: face
	}
}

// destroy releases the face object.
pub fn (mut f Face) destroy() {
	if f.ptr != unsafe { nil } {
		C.hb_face_destroy(f.ptr)
		f.ptr = unsafe { nil }
	}
}

// === Shaping ===

// shape performs text shaping on the buffer using the given font and features.
// After this call, the buffer's codepoints are replaced with glyph indices
// and positions become available via get_glyph_positions().
pub fn shape(fnt Font, buf Buffer, features []Feature) {
	if features.len == 0 {
		C.hb_shape(fnt.ptr, buf.ptr, unsafe { nil }, 0)
	} else {
		mut c_feats := []C.hb_feature_t{len: features.len}
		for i, f in features {
			c_feats[i] = C.hb_feature_t{
				tag:   f.tag
				value: f.value
				start: f.start
				end:   f.end
			}
		}
		unsafe { C.hb_shape(fnt.ptr, buf.ptr, &c_feats[0], u32(features.len)) }
	}
}
