module sprite

// --- Original Ghostty Comments Start: src/font/sprite/draw/symbols_for_legacy_computing_supplement.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/font/sprite/draw/symbols_for_legacy_computing_supplement.zig
//
// Symbols for Legacy Computing Supplement | U+1CC00...U+1CEBF
// https://en.wikipedia.org/wiki/Symbols_for_Legacy_Computing_Supplement
//
// 𜰀 𜰁 𜰂 𜰃 𜰄 𜰅 𜰆 𜰇 𜰈 𜰉 𜰊 𜰋 𜰌 𜰍 𜰎 𜰏
// 𜰐 𜰑 𜰒 𜰓 𜰔 𜰕 𜰖 𜰗 𜰘 𜰙 𜰚 𜰛 𜰜 𜰝 𜰞 𜰟
// 𜰠 𜰡 𜰢 𜰣 𜰤 𜰥 𜰦 𜰧 𜰨 𜰩 𜰪 𜰫 𜰬 𜰭 𜰮 𜰯
// 𜰰 𜰱 𜰲 𜰳 𜰴 𜰵 𜰶 𜰷 𜰸 𜰹 𜰺 𜰻 𜰼 𜰽 𜰾 𜰿
// 𜱀 𜱁 𜱂 𜱃 𜱄 𜱅 𜱆 𜱇 𜱈 𜱉 𜱊 𜱋 𜱌 𜱍 𜱎 𜱏
// 𜱐 𜱑 𜱒 𜱓 𜱔 𜱕 𜱖 𜱗 𜱘 𜱙 𜱚 𜱛 𜱜 𜱝 𜱞 𜱟
// 𜱠 𜱡 𜱢 𜱣 𜱤 𜱥 𜱦 𜱧 𜱨 𜱩 𜱪 𜱫 𜱬 𜱭 𜱮 𜱯
// 𜱰 𜱱 𜱲 𜱳 𜱴 𜱵 𜱶 𜱷 𜱸 𜱹 𜱺 𜱻 𜱼 𜱽 𜱾 𜱿
// 𜲀 𜲁 𜲂 𜲃 𜲄 𜲅 𜲆 𜲇 𜲈 𜲉 𜲊 𜲋 𜲌 𜲍 𜲎 𜲏
// 𜲐 𜲑 𜲒 𜲓 𜲔 𜲕 𜲖 𜲗 𜲘 𜲙 𜲚 𜲛 𜲜 𜲝 𜲞 𜲟
// 𜲠 𜲡 𜲢 𜲣 𜲤 𜲥 𜲦 𜲧 𜲨 𜲩 𜲪 𜲫 𜲬 𜲭 𜲮 𜲯
// 𜲰 𜲱 𜲲 𜲳 𜲴 𜲵 𜲶 𜲷 𜲸 𜲹 𜲺 𜲻 𜲼 𜲽 𜲾 𜲿
// 𜳀 𜳁 𜳂 𜳃 𜳄 𜳅 𜳆 𜳇 𜳈 𜳉 𜳊 𜳋 𜳌 𜳍 𜳎 𜳏
// 𜳐 𜳑 𜳒 𜳓 𜳔 𜳕 𜳖 𜳗 𜳘 𜳙 𜳚 𜳛 𜳜 𜳝 𜳞 𜳟
// 𜳠 𜳡 𜳢 𜳣 𜳤 𜳥 𜳦 𜳧 𜳨 𜳩 𜳪 𜳫 𜳬 𜳭 𜳮 𜳯
// 𜳰 𜳱 𜳲 𜳳 𜳴 𜳵 𜳶 𜳷 𜳸 𜳹
// 𜴀 𜴁 𜴂 𜴃 𜴄 𜴅 𜴆 𜴇 𜴈 𜴉 𜴊 𜴋 𜴌 𜴍 𜴎 𜴏
// 𜴐 𜴑 𜴒 𜴓 𜴔 𜴕 𜴖 𜴗 𜴘 𜴙 𜴚 𜴛 𜴜 𜴝 𜴞 𜴟
// 𜴠 𜴡 𜴢 𜴣 𜴤 𜴥 𜴦 𜴧 𜴨 𜴩 𜴪 𜴫 𜴬 𜴭 𜴮 𜴯
// 𜴰 𜴱 𜴲 𜴳 𜴴 𜴵 𜴶 𜴷 𜴸 𜴹 𜴺 𜴻 𜴼 𜴽 𜴾 𜴿
// 𜵀 𜵁 𜵂 𜵃 𜵄 𜵅 𜵆 𜵇 𜵈 𜵉 𜵊 𜵋 𜵌 𜵍 𜵎 𜵏
// 𜵐 𜵑 𜵒 𜵓 𜵔 𜵕 𜵖 𜵗 𜵘 𜵙 𜵚 𜵛 𜵜 𜵝 𜵞 𜵟
// 𜵠 𜵡 𜵢 𜵣 𜵤 𜵥 𜵦 𜵧 𜵨 𜵩 𜵪 𜵫 𜵬 𜵭 𜵮 𜵯
// 𜵰 𜵱 𜵲 𜵳 𜵴 𜵵 𜵶 𜵷 𜵸 𜵹 𜵺 𜵻 𜵼 𜵽 𜵾 𜵿
// 𜶀 𜶁 𜶂 𜶃 𜶄 𜶅 𜶆 𜶇 𜶈 𜶉 𜶊 𜶋 𜶌 𜶍 𜶎 𜶏
// 𜶐 𜶑 𜶒 𜶓 𜶔 𜶕 𜶖 𜶗 𜶘 𜶙 𜶚 𜶛 𜶜 𜶝 𜶞 𜶟
// 𜶠 𜶡 𜶢 𜶣 𜶤 𜶥 𜶦 𜶧 𜶨 𜶩 𜶪 𜶫 𜶬 𜶭 𜶮 𜶯
// 𜶰 𜶱 𜶲 𜶳 𜶴 𜶵 𜶶 𜶷 𜶸 𜶹 𜶺 𜶻 𜶼 𜶽 𜶾 𜶿
// 𜷀 𜷁 𜷂 𜷃 𜷄 𜷅 𜷆 𜷇 𜷈 𜷉 𜷊 𜷋 𜷌 𜷍 𜷎 𜷏
// 𜷐 𜷑 𜷒 𜷓 𜷔 𜷕 𜷖 𜷗 𜷘 𜷙 𜷚 𜷛 𜷜 𜷝 𜷞 𜷟
// 𜷠 𜷡 𜷢 𜷣 𜷤 𜷥 𜷦 𜷧 𜷨 𜷩 𜷪 𜷫 𜷬 𜷭 𜷮 𜷯
// 𜷰 𜷱 𜷲 𜷳 𜷴 𜷵 𜷶 𜷷 𜷸 𜷹 𜷺 𜷻 𜷼 𜷽 𜷾 𜷿
// 𜸀 𜸁 𜸂 𜸃 𜸄 𜸅 𜸆 𜸇 𜸈 𜸉 𜸊 𜸋 𜸌 𜸍 𜸎 𜸏
// 𜸐 𜸑 𜸒 𜸓 𜸔 𜸕 𜸖 𜸗 𜸘 𜸙 𜸚 𜸛 𜸜 𜸝 𜸞 𜸟
// 𜸠 𜸡 𜸢 𜸣 𜸤 𜸥 𜸦 𜸧 𜸨 𜸩 𜸪 𜸫 𜸬 𜸭 𜸮 𜸯
// 𜸰 𜸱 𜸲 𜸳 𜸴 𜸵 𜸶 𜸷 𜸸 𜸹 𜸺 𜸻 𜸼 𜸽 𜸾 𜸿
// 𜹀 𜹁 𜹂 𜹃 𜹄 𜹅 𜹆 𜹇 𜹈 𜹉 𜹊 𜹋 𜹌 𜹍 𜹎 𜹏
// 𜹐 𜹑 𜹒 𜹓 𜹔 𜹕 𜹖 𜹗 𜹘 𜹙 𜹚 𜹛 𜹜 𜹝 𜹞 𜹟
// 𜹠 𜹡 𜹢 𜹣 𜹤 𜹥 𜹦 𜹧 𜹨 𜹩 𜹪 𜹫 𜹬 𜹭 𜹮 𜹯
// 𜹰 𜹱 𜹲 𜹳 𜹴 𜹵 𜹶 𜹷 𜹸 𜹹 𜹺 𜹻 𜹼 𜹽 𜹾 𜹿
// 𜺀 𜺁 𜺂 𜺃 𜺄 𜺅 𜺆 𜺇 𜺈 𜺉 𜺊 𜺋 𜺌 𜺍 𜺎 𜺏
// 𜺐 𜺑 𜺒 𜺓 𜺔 𜺕 𜺖 𜺗 𜺘 𜺙 𜺚 𜺛 𜺜 𜺝 𜺞 𜺟
// 𜺠 𜺡 𜺢 𜺣 𜺤 𜺥 𜺦 𜺧 𜺨 𜺩 𜺪 𜺫 𜺬 𜺭 𜺮 𜺯
// 𜺰 𜺱 𜺲 𜺳
//
// Octants
// Octant representation. We use the funny numeric string keys
// so its easier to parse the actual name used in the Symbols for
// Legacy Computing spec.
// Parse the octant data. This is all done at comptime so
// that this is static data that is embedded in the binary.
// Skip comments
// Octants are in the format "BLOCK OCTANT-1235". The numbers
// at the end are keys into our packed struct. Since we're
// at comptime we can metaprogram it all.
// Separated Block Quadrants
// 𜰡 𜰢 𜰣 𜰤 𜰥 𜰦 𜰧 𜰨 𜰩 𜰪 𜰫 𜰬 𜰭 𜰮 𜰯
// Struct laid out to match the codepoint order so we can cast from it.
// Twelfth and Quarter circle pieces.
// 𜰰 𜰱 𜰲 𜰳 𜰴 𜰵 𜰶 𜰷 𜰸 𜰹 𜰺 𜰻 𜰼 𜰽 𜰾 𜰿
//
// 𜰰𜰱𜰲𜰳
// 𜰴𜰵𜰶𜰷
// 𜰸𜰹𜰺𜰻
// 𜰼𜰽𜰾𜰿
//
// These are actually ellipses, sized to touch
// the edge of their enclosing set of cells.
// 𜰰 UPPER LEFT TWELFTH CIRCLE
// 𜰱 UPPER CENTRE LEFT TWELFTH CIRCLE
// 𜰲 UPPER CENTRE RIGHT TWELFTH CIRCLE
// 𜰳 UPPER RIGHT TWELFTH CIRCLE
// 𜰴 UPPER MIDDLE LEFT TWELFTH CIRCLE
// 𜰵 UPPER LEFT QUARTER CIRCLE
// 𜰶 UPPER RIGHT QUARTER CIRCLE
// 𜰷 UPPER MIDDLE RIGHT TWELFTH CIRCLE
// 𜰸 LOWER MIDDLE LEFT TWELFTH CIRCLE
// 𜰹 LOWER LEFT QUARTER CIRCLE
// 𜰺 LOWER RIGHT QUARTER CIRCLE
// 𜰻 LOWER MIDDLE RIGHT TWELFTH CIRCLE
// 𜰼 LOWER LEFT TWELFTH CIRCLE
// 𜰽 LOWER CENTRE LEFT TWELFTH CIRCLE
// 𜰾 LOWER CENTRE RIGHT TWELFTH CIRCLE
// 𜰿 LOWER RIGHT TWELFTH CIRCLE
// TODO: These two characters should be easy, but it's not clear how they're
//       meant to align with adjacent cells, what characters they're meant to
//       be used with:
//       - 1CC1F 𜰟 BOX DRAWINGS DOUBLE DIAGONAL UPPER RIGHT TO LOWER LEFT
//       - 1CC20 𜰠 BOX DRAWINGS DOUBLE DIAGONAL UPPER LEFT TO LOWER RIGHT
// 𜰛 BOX DRAWINGS LIGHT HORIZONTAL AND UPPER RIGHT
// 𜰜 BOX DRAWINGS LIGHT HORIZONTAL AND LOWER RIGHT
// 𜰝 BOX DRAWINGS LIGHT TOP AND UPPER LEFT
// 𜰞 BOX DRAWINGS LIGHT BOTTOM AND LOWER LEFT
// 𜸀 RIGHT HALF AND LEFT HALF WHITE CIRCLE
// 𜸁 LOWER HALF AND UPPER HALF WHITE CIRCLE
// 𜸋 LEFT HALF WHITE ELLIPSE
// 𜸌 RIGHT HALF WHITE ELLIPSE
// 𜸖 BOX DRAWINGS LIGHT VERTICAL AND TOP RIGHT
// 𜸗 BOX DRAWINGS LIGHT VERTICAL AND BOTTOM RIGHT
// 𜸘 BOX DRAWINGS LIGHT VERTICAL AND TOP LEFT
// 𜸙 BOX DRAWINGS LIGHT VERTICAL AND BOTTOM LEFT
// Separated Block Sextants
// Struct laid out to match the codepoint order so we can cast from it.
// Distribute any leftover height in to the middle row of blocks.
// Sixteenth Blocks
// 𜺐 UPPER LEFT ONE SIXTEENTH BLOCK
// 𜺑 UPPER CENTRE LEFT ONE SIXTEENTH BLOCK
// 𜺒 UPPER CENTRE RIGHT ONE SIXTEENTH BLOCK
// 𜺓 UPPER RIGHT ONE SIXTEENTH BLOCK
// 𜺔 UPPER MIDDLE LEFT ONE SIXTEENTH BLOCK
// 𜺕 UPPER MIDDLE CENTRE LEFT ONE SIXTEENTH BLOCK
// 𜺖 UPPER MIDDLE CENTRE RIGHT ONE SIXTEENTH BLOCK
// 𜺗 UPPER MIDDLE RIGHT ONE SIXTEENTH BLOCK
// 𜺘 LOWER MIDDLE LEFT ONE SIXTEENTH BLOCK
// 𜺙 LOWER MIDDLE CENTRE LEFT ONE SIXTEENTH BLOCK
// 𜺚 LOWER MIDDLE CENTRE RIGHT ONE SIXTEENTH BLOCK
// 𜺛 LOWER MIDDLE RIGHT ONE SIXTEENTH BLOCK
// 𜺜 LOWER LEFT ONE SIXTEENTH BLOCK
// 𜺝 LOWER CENTRE LEFT ONE SIXTEENTH BLOCK
// 𜺞 LOWER CENTRE RIGHT ONE SIXTEENTH BLOCK
// 𜺟 LOWER RIGHT ONE SIXTEENTH BLOCK
// 𜺠 RIGHT HALF LOWER ONE QUARTER BLOCK
// 𜺡 RIGHT THREE QUARTERS LOWER ONE QUARTER BLOCK
// 𜺢 LEFT THREE QUARTERS LOWER ONE QUARTER BLOCK
// 𜺣 LEFT HALF LOWER ONE QUARTER BLOCK
// 𜺤 LOWER HALF LEFT ONE QUARTER BLOCK
// 𜺥 LOWER THREE QUARTERS LEFT ONE QUARTER BLOCK
// 𜺦 UPPER THREE QUARTERS LEFT ONE QUARTER BLOCK
// 𜺧 UPPER HALF LEFT ONE QUARTER BLOCK
// 𜺨 LEFT HALF UPPER ONE QUARTER BLOCK
// 𜺩 LEFT THREE QUARTERS UPPER ONE QUARTER BLOCK
// 𜺪 RIGHT THREE QUARTERS UPPER ONE QUARTER BLOCK
// 𜺫 RIGHT HALF UPPER ONE QUARTER BLOCK
// 𜺬 UPPER HALF RIGHT ONE QUARTER BLOCK
// 𜺭 UPPER THREE QUARTERS RIGHT ONE QUARTER BLOCK
// 𜺮 LOWER THREE QUARTERS RIGHT ONE QUARTER BLOCK
// 𜺯 LOWER HALF RIGHT ONE QUARTER BLOCK
// Radius in pixels of the arc we need to draw.
// Position in pixels (rather than cells) for x/y
// Set the clip so we don't include anything outside of the cell.
// Coefficient for approximating a circular arc.
//
// --- Original Ghostty Comments End: src/font/sprite/draw/symbols_for_legacy_computing_supplement.zig

// Symbols for Legacy Computing Supplement | U+1CC00...U+1CEBF
// https://en.wikipedia.org/wiki/Symbols_for_Legacy_Computing_Supplement
//
// Translated from ghostty/src/font/sprite/draw/symbols_for_legacy_computing_supplement.zig

import sprite_types as font
import math

// ============================================================
// Octants | U+1CD00...U+1CDE5
// ============================================================

// Octant representation. The numeric field names correspond to
// the 8 octant positions used in the Symbols for Legacy Computing spec.
// Each octant divides the cell into a 2x4 grid:
//   1 2   (top row)
//   3 4   (upper-middle row)
//   5 6   (lower-middle row)
//   7 8   (bottom row)
struct Octant {
	value u8
}

fn Octant.from_int(value u8) Octant {
	return Octant{
		value: value
	}
}

fn (oct Octant) o1() bool {
	return oct.value & (u8(1) << 0) != 0
}

fn (oct Octant) o2() bool {
	return oct.value & (u8(1) << 1) != 0
}

fn (oct Octant) o3() bool {
	return oct.value & (u8(1) << 2) != 0
}

fn (oct Octant) o4() bool {
	return oct.value & (u8(1) << 3) != 0
}

fn (oct Octant) o5() bool {
	return oct.value & (u8(1) << 4) != 0
}

fn (oct Octant) o6() bool {
	return oct.value & (u8(1) << 5) != 0
}

fn (oct Octant) o7() bool {
	return oct.value & (u8(1) << 6) != 0
}

fn (oct Octant) o8() bool {
	return oct.value & (u8(1) << 7) != 0
}

// octant_min and octant_max define the codepoint range for octants.
const octant_min = u32(0x1cd00)
const octant_max = u32(0x1cde5)

// octant_table is the real octant lookup table, translated from ghostty's
// octants.txt embed (parsed at translation time). Each entry corresponds to
// a codepoint from octant_min to octant_max (U+1CD00..U+1CDE5, 230 entries).
// The octant name format is "BLOCK OCTANT-1235" where the trailing digits
// indicate which octants are filled (1..8). We weren't able to discern a
// mathematical pattern for these, hence the explicit table.
const octant_table = [
	Octant.from_int(0x04),
	Octant.from_int(0x06),
	Octant.from_int(0x07),
	Octant.from_int(0x08),
	Octant.from_int(0x09),
	Octant.from_int(0x0b),
	Octant.from_int(0x0c),
	Octant.from_int(0x0d),
	Octant.from_int(0x0e),
	Octant.from_int(0x10),
	Octant.from_int(0x11),
	Octant.from_int(0x12),
	Octant.from_int(0x13),
	Octant.from_int(0x15),
	Octant.from_int(0x16),
	Octant.from_int(0x17),
	Octant.from_int(0x18),
	Octant.from_int(0x19),
	Octant.from_int(0x1a),
	Octant.from_int(0x1b),
	Octant.from_int(0x1c),
	Octant.from_int(0x1d),
	Octant.from_int(0x1e),
	Octant.from_int(0x1f),
	Octant.from_int(0x20),
	Octant.from_int(0x21),
	Octant.from_int(0x22),
	Octant.from_int(0x23),
	Octant.from_int(0x24),
	Octant.from_int(0x25),
	Octant.from_int(0x26),
	Octant.from_int(0x27),
	Octant.from_int(0x29),
	Octant.from_int(0x2a),
	Octant.from_int(0x2b),
	Octant.from_int(0x2c),
	Octant.from_int(0x2d),
	Octant.from_int(0x2e),
	Octant.from_int(0x2f),
	Octant.from_int(0x30),
	Octant.from_int(0x31),
	Octant.from_int(0x32),
	Octant.from_int(0x33),
	Octant.from_int(0x34),
	Octant.from_int(0x35),
	Octant.from_int(0x36),
	Octant.from_int(0x37),
	Octant.from_int(0x38),
	Octant.from_int(0x39),
	Octant.from_int(0x3a),
	Octant.from_int(0x3b),
	Octant.from_int(0x3c),
	Octant.from_int(0x3d),
	Octant.from_int(0x3e),
	Octant.from_int(0x41),
	Octant.from_int(0x42),
	Octant.from_int(0x43),
	Octant.from_int(0x44),
	Octant.from_int(0x45),
	Octant.from_int(0x46),
	Octant.from_int(0x47),
	Octant.from_int(0x48),
	Octant.from_int(0x49),
	Octant.from_int(0x4a),
	Octant.from_int(0x4b),
	Octant.from_int(0x4c),
	Octant.from_int(0x4d),
	Octant.from_int(0x4e),
	Octant.from_int(0x4f),
	Octant.from_int(0x51),
	Octant.from_int(0x52),
	Octant.from_int(0x53),
	Octant.from_int(0x54),
	Octant.from_int(0x56),
	Octant.from_int(0x57),
	Octant.from_int(0x58),
	Octant.from_int(0x59),
	Octant.from_int(0x5b),
	Octant.from_int(0x5c),
	Octant.from_int(0x5d),
	Octant.from_int(0x5e),
	Octant.from_int(0x60),
	Octant.from_int(0x61),
	Octant.from_int(0x62),
	Octant.from_int(0x63),
	Octant.from_int(0x64),
	Octant.from_int(0x65),
	Octant.from_int(0x66),
	Octant.from_int(0x67),
	Octant.from_int(0x68),
	Octant.from_int(0x69),
	Octant.from_int(0x6a),
	Octant.from_int(0x6b),
	Octant.from_int(0x6c),
	Octant.from_int(0x6d),
	Octant.from_int(0x6e),
	Octant.from_int(0x6f),
	Octant.from_int(0x70),
	Octant.from_int(0x71),
	Octant.from_int(0x72),
	Octant.from_int(0x73),
	Octant.from_int(0x74),
	Octant.from_int(0x75),
	Octant.from_int(0x76),
	Octant.from_int(0x77),
	Octant.from_int(0x78),
	Octant.from_int(0x79),
	Octant.from_int(0x7a),
	Octant.from_int(0x7b),
	Octant.from_int(0x7c),
	Octant.from_int(0x7d),
	Octant.from_int(0x7e),
	Octant.from_int(0x7f),
	Octant.from_int(0x81),
	Octant.from_int(0x82),
	Octant.from_int(0x83),
	Octant.from_int(0x84),
	Octant.from_int(0x85),
	Octant.from_int(0x86),
	Octant.from_int(0x87),
	Octant.from_int(0x88),
	Octant.from_int(0x89),
	Octant.from_int(0x8a),
	Octant.from_int(0x8b),
	Octant.from_int(0x8c),
	Octant.from_int(0x8d),
	Octant.from_int(0x8e),
	Octant.from_int(0x8f),
	Octant.from_int(0x90),
	Octant.from_int(0x91),
	Octant.from_int(0x92),
	Octant.from_int(0x93),
	Octant.from_int(0x94),
	Octant.from_int(0x95),
	Octant.from_int(0x96),
	Octant.from_int(0x97),
	Octant.from_int(0x98),
	Octant.from_int(0x99),
	Octant.from_int(0x9a),
	Octant.from_int(0x9b),
	Octant.from_int(0x9c),
	Octant.from_int(0x9d),
	Octant.from_int(0x9e),
	Octant.from_int(0x9f),
	Octant.from_int(0xa1),
	Octant.from_int(0xa2),
	Octant.from_int(0xa3),
	Octant.from_int(0xa4),
	Octant.from_int(0xa6),
	Octant.from_int(0xa7),
	Octant.from_int(0xa8),
	Octant.from_int(0xa9),
	Octant.from_int(0xab),
	Octant.from_int(0xac),
	Octant.from_int(0xad),
	Octant.from_int(0xae),
	Octant.from_int(0xb0),
	Octant.from_int(0xb1),
	Octant.from_int(0xb2),
	Octant.from_int(0xb3),
	Octant.from_int(0xb4),
	Octant.from_int(0xb5),
	Octant.from_int(0xb6),
	Octant.from_int(0xb7),
	Octant.from_int(0xb8),
	Octant.from_int(0xb9),
	Octant.from_int(0xba),
	Octant.from_int(0xbb),
	Octant.from_int(0xbc),
	Octant.from_int(0xbd),
	Octant.from_int(0xbe),
	Octant.from_int(0xbf),
	Octant.from_int(0xc1),
	Octant.from_int(0xc2),
	Octant.from_int(0xc3),
	Octant.from_int(0xc4),
	Octant.from_int(0xc5),
	Octant.from_int(0xc6),
	Octant.from_int(0xc7),
	Octant.from_int(0xc8),
	Octant.from_int(0xc9),
	Octant.from_int(0xca),
	Octant.from_int(0xcb),
	Octant.from_int(0xcc),
	Octant.from_int(0xcd),
	Octant.from_int(0xce),
	Octant.from_int(0xcf),
	Octant.from_int(0xd0),
	Octant.from_int(0xd1),
	Octant.from_int(0xd2),
	Octant.from_int(0xd3),
	Octant.from_int(0xd4),
	Octant.from_int(0xd5),
	Octant.from_int(0xd6),
	Octant.from_int(0xd7),
	Octant.from_int(0xd8),
	Octant.from_int(0xd9),
	Octant.from_int(0xda),
	Octant.from_int(0xdb),
	Octant.from_int(0xdc),
	Octant.from_int(0xdd),
	Octant.from_int(0xde),
	Octant.from_int(0xdf),
	Octant.from_int(0xe0),
	Octant.from_int(0xe1),
	Octant.from_int(0xe2),
	Octant.from_int(0xe3),
	Octant.from_int(0xe4),
	Octant.from_int(0xe5),
	Octant.from_int(0xe6),
	Octant.from_int(0xe7),
	Octant.from_int(0xe8),
	Octant.from_int(0xe9),
	Octant.from_int(0xea),
	Octant.from_int(0xeb),
	Octant.from_int(0xec),
	Octant.from_int(0xed),
	Octant.from_int(0xee),
	Octant.from_int(0xef),
	Octant.from_int(0xf1),
	Octant.from_int(0xf2),
	Octant.from_int(0xf3),
	Octant.from_int(0xf4),
	Octant.from_int(0xf6),
	Octant.from_int(0xf7),
	Octant.from_int(0xf8),
	Octant.from_int(0xf9),
	Octant.from_int(0xfb),
	Octant.from_int(0xfd),
	Octant.from_int(0xfe),
]

// get_octant returns the octant pattern for the given codepoint by
// indexing in to octant_table.
fn get_octant(cp u32) Octant {
	return octant_table[cp - octant_min]
}

// draw_1cd00_1cde5 draws octant characters (U+1CD00..U+1CDE5).
// Octants divide the cell into a 2x4 grid of blocks.
pub fn draw_1cd00_1cde5(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	oct := get_octant(cp)
	if oct.o1() {
		fill(metrics, mut canvas, .zero, .half_, .zero, .one_quarter)
	}
	if oct.o2() {
		fill(metrics, mut canvas, .half_, .full, .zero, .one_quarter)
	}
	if oct.o3() {
		fill(metrics, mut canvas, .zero, .half_, .one_quarter, .two_quarters)
	}
	if oct.o4() {
		fill(metrics, mut canvas, .half_, .full, .one_quarter, .two_quarters)
	}
	if oct.o5() {
		fill(metrics, mut canvas, .zero, .half_, .two_quarters, .three_quarters)
	}
	if oct.o6() {
		fill(metrics, mut canvas, .half_, .full, .two_quarters, .three_quarters)
	}
	if oct.o7() {
		fill(metrics, mut canvas, .zero, .half_, .three_quarters, .end_)
	}
	if oct.o8() {
		fill(metrics, mut canvas, .half_, .full, .three_quarters, .end_)
	}
}

// ============================================================
// Separated Block Quadrants | U+1CC21...U+1CC2F
// ============================================================

// draw_1cc21_1cc2f draws separated block quadrant characters.
// These are quadrant blocks with gaps between them.
pub fn draw_1cc21_1cc2f(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = metrics

	// Struct laid out to match the codepoint order so we can cast from it.
	quad := Quads.from_int(u8(cp - 0x1cc20) & quads_mask)

	gap := i32(if width / 12 > 1 { width / 12 } else { u32(1) })

	mid_gap_x := gap * 2 + i32(width % 2)
	mid_gap_y := gap * 2 + i32(height % 2)

	w := (i32(width) - gap * 2 - mid_gap_x) / 2
	h := (i32(height) - gap * 2 - mid_gap_y) / 2

	if quad.tl() {
		canvas.box(
			gap,
			gap,
			gap + w,
			gap + h,
			.on,
		)
	}
	if quad.tr() {
		canvas.box(
			gap + w + mid_gap_x,
			gap,
			gap + w + mid_gap_x + w,
			gap + h,
			.on,
		)
	}
	if quad.bl() {
		canvas.box(
			gap,
			gap + h + mid_gap_y,
			gap + w,
			gap + h + mid_gap_y + h,
			.on,
		)
	}
	if quad.br() {
		canvas.box(
			gap + w + mid_gap_x,
			gap + h + mid_gap_y,
			gap + w + mid_gap_x + w,
			gap + h + mid_gap_y + h,
			.on,
		)
	}
}

// ============================================================
// Twelfth and Quarter circle pieces | U+1CC30...U+1CC3F
// ============================================================

// draw_1cc30_1cc3f draws twelfth and quarter circle piece characters.
// These are actually ellipses, sized to touch the edge of their
// enclosing set of cells.
pub fn draw_1cc30_1cc3f(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	match cp {
		// UPPER LEFT TWELFTH CIRCLE
		0x1cc30 { circle_piece(mut canvas, width, height, metrics, 0, 0, 2, 2, .tl)! }
		// UPPER CENTRE LEFT TWELFTH CIRCLE
		0x1cc31 { circle_piece(mut canvas, width, height, metrics, 1, 0, 2, 2, .tl)! }
		// UPPER CENTRE RIGHT TWELFTH CIRCLE
		0x1cc32 { circle_piece(mut canvas, width, height, metrics, 2, 0, 2, 2, .tr)! }
		// UPPER RIGHT TWELFTH CIRCLE
		0x1cc33 { circle_piece(mut canvas, width, height, metrics, 3, 0, 2, 2, .tr)! }
		// UPPER MIDDLE LEFT TWELFTH CIRCLE
		0x1cc34 { circle_piece(mut canvas, width, height, metrics, 0, 1, 2, 2, .tl)! }
		// UPPER LEFT QUARTER CIRCLE
		0x1cc35 { circle_piece(mut canvas, width, height, metrics, 0, 0, 1, 1, .tl)! }
		// UPPER RIGHT QUARTER CIRCLE
		0x1cc36 { circle_piece(mut canvas, width, height, metrics, 1, 0, 1, 1, .tr)! }
		// UPPER MIDDLE RIGHT TWELFTH CIRCLE
		0x1cc37 { circle_piece(mut canvas, width, height, metrics, 3, 1, 2, 2, .tr)! }
		// LOWER MIDDLE LEFT TWELFTH CIRCLE
		0x1cc38 { circle_piece(mut canvas, width, height, metrics, 0, 2, 2, 2, .bl)! }
		// LOWER LEFT QUARTER CIRCLE
		0x1cc39 { circle_piece(mut canvas, width, height, metrics, 0, 1, 1, 1, .bl)! }
		// LOWER RIGHT QUARTER CIRCLE
		0x1cc3a { circle_piece(mut canvas, width, height, metrics, 1, 1, 1, 1, .br)! }
		// LOWER MIDDLE RIGHT TWELFTH CIRCLE
		0x1cc3b { circle_piece(mut canvas, width, height, metrics, 3, 2, 2, 2, .br)! }
		// LOWER LEFT TWELFTH CIRCLE
		0x1cc3c { circle_piece(mut canvas, width, height, metrics, 0, 3, 2, 2, .bl)! }
		// LOWER CENTRE LEFT TWELFTH CIRCLE
		0x1cc3d { circle_piece(mut canvas, width, height, metrics, 1, 3, 2, 2, .bl)! }
		// LOWER CENTRE RIGHT TWELFTH CIRCLE
		0x1cc3e { circle_piece(mut canvas, width, height, metrics, 2, 3, 2, 2, .br)! }
		// LOWER RIGHT TWELFTH CIRCLE
		0x1cc3f { circle_piece(mut canvas, width, height, metrics, 3, 3, 2, 2, .br)! }
		else { panic('unreachable') }
	}
}

// ============================================================
// Box Drawings supplement | U+1CC1B...U+1CC1E
// ============================================================

// TODO: These two characters should be easy, but it's not clear how they're
//       meant to align with adjacent cells, what characters they're meant to
//       be used with:
//       - 1CC1F BOX DRAWINGS DOUBLE DIAGONAL UPPER RIGHT TO LOWER LEFT
//       - 1CC20 BOX DRAWINGS DOUBLE DIAGONAL UPPER LEFT TO LOWER RIGHT

// draw_1cc1b_1cc1e draws box drawing supplement characters.
pub fn draw_1cc1b_1cc1e(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	w := i32(width)
	h := i32(height)
	t := i32(metrics.box_thickness)
	match cp {
		// BOX DRAWINGS LIGHT HORIZONTAL AND UPPER RIGHT
		0x1cc1b {
			lines_char(metrics, mut canvas, Lines.from_int(0x44))
			canvas.box(w - t, 0, w, h / 2, .on)
		}

		// BOX DRAWINGS LIGHT HORIZONTAL AND LOWER RIGHT
		0x1cc1c {
			lines_char(metrics, mut canvas, Lines.from_int(0x44))
			canvas.box(w - t, h / 2, w, h, .on)
		}

		// BOX DRAWINGS LIGHT TOP AND UPPER LEFT
		0x1cc1d {
			canvas.box(0, 0, w, t, .on)
			canvas.box(0, 0, t, h / 2, .on)
		}

		// BOX DRAWINGS LIGHT BOTTOM AND LOWER LEFT
		0x1cc1e {
			canvas.box(0, h - t, w, h, .on)
			canvas.box(0, h / 2, t, h, .on)
		}
		else { panic('unreachable') }
	}
}

// ============================================================
// Circles | U+1CE00, U+1CE01, U+1CE0B, U+1CE0C
// ============================================================

// RIGHT HALF AND LEFT HALF WHITE CIRCLE
pub fn draw_1ce00(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height
	draw_circle(metrics, mut canvas, align_left, false)
	draw_circle(metrics, mut canvas, align_right, false)
}

// LOWER HALF AND UPPER HALF WHITE CIRCLE
pub fn draw_1ce01(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height
	draw_circle(metrics, mut canvas, align_top, false)
	draw_circle(metrics, mut canvas, align_bottom, false)
}

// LEFT HALF WHITE ELLIPSE
pub fn draw_1ce0b(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	circle_piece(mut canvas, width, height, metrics, 0, 0, 1, 0.5, .tl)!
	circle_piece(mut canvas, width, height, metrics, 0, 0, 1, 0.5, .bl)!
}

// RIGHT HALF WHITE ELLIPSE
pub fn draw_1ce0c(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	circle_piece(mut canvas, width, height, metrics, 1, 0, 1, 0.5, .tr)!
	circle_piece(mut canvas, width, height, metrics, 1, 0, 1, 0.5, .br)!
}

// ============================================================
// Box Drawings vertical + top/bottom | U+1CE16...U+1CE19
// ============================================================

// draw_1ce16_1ce19 draws box drawing vertical with top/bottom right/left.
pub fn draw_1ce16_1ce19(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	w := i32(width)
	h := i32(height)
	t := i32(metrics.box_thickness)
	match cp {
		// BOX DRAWINGS LIGHT VERTICAL AND TOP RIGHT
		0x1ce16 {
			lines_char(metrics, mut canvas, Lines.from_int(0x11))
			canvas.box(w / 2, 0, w, t, .on)
		}

		// BOX DRAWINGS LIGHT VERTICAL AND BOTTOM RIGHT
		0x1ce17 {
			lines_char(metrics, mut canvas, Lines.from_int(0x11))
			canvas.box(w / 2, h - t, w, h, .on)
		}

		// BOX DRAWINGS LIGHT VERTICAL AND TOP LEFT
		0x1ce18 {
			lines_char(metrics, mut canvas, Lines.from_int(0x11))
			canvas.box(0, 0, w / 2, t, .on)
		}

		// BOX DRAWINGS LIGHT VERTICAL AND BOTTOM LEFT
		0x1ce19 {
			lines_char(metrics, mut canvas, Lines.from_int(0x11))
			canvas.box(0, h - t, w / 2, h, .on)
		}
		else { panic('unreachable') }
	}
}

// ============================================================
// Separated Block Sextants | U+1CE51...U+1CE8F
// ============================================================

// draw_1ce51_1ce8f draws separated block sextant characters.
// These are sextant blocks (2x3 grid) with gaps between them.
pub fn draw_1ce51_1ce8f(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = metrics

	// Struct laid out to match the codepoint order so we can cast from it.
	sex := Sextants.from_int(u8(cp - 0x1ce50) & 0x3f)

	gap := i32(if width / 12 > 1 { width / 12 } else { u32(1) })

	mid_gap_x := gap * 2 + i32(width % 2)
	y_extra := i32(height % 3)
	mid_gap_y := gap * 2 + y_extra / 2

	w := (i32(width) - gap * 2 - mid_gap_x) / 2
	h := (i32(height) - gap * 2 - mid_gap_y * 2) / 3
	// Distribute any leftover height in to the middle row of blocks.
	h_m := i32(height) - gap * 2 - mid_gap_y * 2 - h * 2

	if sex.tl() {
		canvas.box(
			gap,
			gap,
			gap + w,
			gap + h,
			.on,
		)
	}
	if sex.tr() {
		canvas.box(
			gap + w + mid_gap_x,
			gap,
			gap + w + mid_gap_x + w,
			gap + h,
			.on,
		)
	}
	if sex.ml() {
		canvas.box(
			gap,
			gap + h + mid_gap_y,
			gap + w,
			gap + h + mid_gap_y + h_m,
			.on,
		)
	}
	if sex.mr() {
		canvas.box(
			gap + w + mid_gap_x,
			gap + h + mid_gap_y,
			gap + w + mid_gap_x + w,
			gap + h + mid_gap_y + h_m,
			.on,
		)
	}
	if sex.bl() {
		canvas.box(
			gap,
			gap + h + mid_gap_y + h_m + mid_gap_y,
			gap + w,
			gap + h + mid_gap_y + h_m + mid_gap_y + h,
			.on,
		)
	}
	if sex.br() {
		canvas.box(
			gap + w + mid_gap_x,
			gap + h + mid_gap_y + h_m + mid_gap_y,
			gap + w + mid_gap_x + w,
			gap + h + mid_gap_y + h_m + mid_gap_y + h,
			.on,
		)
	}
}

// ============================================================
// Sixteenth Blocks | U+1CE90...U+1CEAF
// ============================================================

// draw_1ce90_1ceaf draws sixteenth block characters.
// These divide the cell into a 4x4 grid of blocks.
pub fn draw_1ce90_1ceaf(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height
	q := fraction_quarters
	match cp {
		// UPPER LEFT ONE SIXTEENTH BLOCK
		0x1ce90 { fill(metrics, mut canvas, q[0], q[1], q[0], q[1]) }
		// UPPER CENTRE LEFT ONE SIXTEENTH BLOCK
		0x1ce91 { fill(metrics, mut canvas, q[1], q[2], q[0], q[1]) }
		// UPPER CENTRE RIGHT ONE SIXTEENTH BLOCK
		0x1ce92 { fill(metrics, mut canvas, q[2], q[3], q[0], q[1]) }
		// UPPER RIGHT ONE SIXTEENTH BLOCK
		0x1ce93 { fill(metrics, mut canvas, q[3], q[4], q[0], q[1]) }
		// UPPER MIDDLE LEFT ONE SIXTEENTH BLOCK
		0x1ce94 { fill(metrics, mut canvas, q[0], q[1], q[1], q[2]) }
		// UPPER MIDDLE CENTRE LEFT ONE SIXTEENTH BLOCK
		0x1ce95 { fill(metrics, mut canvas, q[1], q[2], q[1], q[2]) }
		// UPPER MIDDLE CENTRE RIGHT ONE SIXTEENTH BLOCK
		0x1ce96 { fill(metrics, mut canvas, q[2], q[3], q[1], q[2]) }
		// UPPER MIDDLE RIGHT ONE SIXTEENTH BLOCK
		0x1ce97 { fill(metrics, mut canvas, q[3], q[4], q[1], q[2]) }
		// LOWER MIDDLE LEFT ONE SIXTEENTH BLOCK
		0x1ce98 { fill(metrics, mut canvas, q[0], q[1], q[2], q[3]) }
		// LOWER MIDDLE CENTRE LEFT ONE SIXTEENTH BLOCK
		0x1ce99 { fill(metrics, mut canvas, q[1], q[2], q[2], q[3]) }
		// LOWER MIDDLE CENTRE RIGHT ONE SIXTEENTH BLOCK
		0x1ce9a { fill(metrics, mut canvas, q[2], q[3], q[2], q[3]) }
		// LOWER MIDDLE RIGHT ONE SIXTEENTH BLOCK
		0x1ce9b { fill(metrics, mut canvas, q[3], q[4], q[2], q[3]) }
		// LOWER LEFT ONE SIXTEENTH BLOCK
		0x1ce9c { fill(metrics, mut canvas, q[0], q[1], q[3], q[4]) }
		// LOWER CENTRE LEFT ONE SIXTEENTH BLOCK
		0x1ce9d { fill(metrics, mut canvas, q[1], q[2], q[3], q[4]) }
		// LOWER CENTRE RIGHT ONE SIXTEENTH BLOCK
		0x1ce9e { fill(metrics, mut canvas, q[2], q[3], q[3], q[4]) }
		// LOWER RIGHT ONE SIXTEENTH BLOCK
		0x1ce9f { fill(metrics, mut canvas, q[3], q[4], q[3], q[4]) }

		// RIGHT HALF LOWER ONE QUARTER BLOCK
		0x1cea0 { fill(metrics, mut canvas, q[2], q[4], q[3], q[4]) }
		// RIGHT THREE QUARTERS LOWER ONE QUARTER BLOCK
		0x1cea1 { fill(metrics, mut canvas, q[1], q[4], q[3], q[4]) }
		// LEFT THREE QUARTERS LOWER ONE QUARTER BLOCK
		0x1cea2 { fill(metrics, mut canvas, q[0], q[3], q[3], q[4]) }
		// LEFT HALF LOWER ONE QUARTER BLOCK
		0x1cea3 { fill(metrics, mut canvas, q[0], q[2], q[3], q[4]) }
		// LOWER HALF LEFT ONE QUARTER BLOCK
		0x1cea4 { fill(metrics, mut canvas, q[0], q[1], q[2], q[4]) }
		// LOWER THREE QUARTERS LEFT ONE QUARTER BLOCK
		0x1cea5 { fill(metrics, mut canvas, q[0], q[1], q[1], q[4]) }
		// UPPER THREE QUARTERS LEFT ONE QUARTER BLOCK
		0x1cea6 { fill(metrics, mut canvas, q[0], q[1], q[0], q[3]) }
		// UPPER HALF LEFT ONE QUARTER BLOCK
		0x1cea7 { fill(metrics, mut canvas, q[0], q[1], q[0], q[2]) }
		// LEFT HALF UPPER ONE QUARTER BLOCK
		0x1cea8 { fill(metrics, mut canvas, q[0], q[2], q[0], q[1]) }
		// LEFT THREE QUARTERS UPPER ONE QUARTER BLOCK
		0x1cea9 { fill(metrics, mut canvas, q[0], q[3], q[0], q[1]) }
		// RIGHT THREE QUARTERS UPPER ONE QUARTER BLOCK
		0x1ceaa { fill(metrics, mut canvas, q[1], q[4], q[0], q[1]) }
		// RIGHT HALF UPPER ONE QUARTER BLOCK
		0x1ceab { fill(metrics, mut canvas, q[2], q[4], q[0], q[1]) }
		// UPPER HALF RIGHT ONE QUARTER BLOCK
		0x1ceac { fill(metrics, mut canvas, q[3], q[4], q[0], q[2]) }
		// UPPER THREE QUARTERS RIGHT ONE QUARTER BLOCK
		0x1cead { fill(metrics, mut canvas, q[3], q[4], q[0], q[3]) }
		// LOWER THREE QUARTERS RIGHT ONE QUARTER BLOCK
		0x1ceae { fill(metrics, mut canvas, q[3], q[4], q[1], q[4]) }
		// LOWER HALF RIGHT ONE QUARTER BLOCK
		0x1ceaf { fill(metrics, mut canvas, q[3], q[4], q[2], q[4]) }
		else { panic('unreachable') }
	}
}

// ============================================================
// circle_piece helper
// ============================================================

// circle_piece draws a piece of an ellipse (arc) within the cell.
// The x, y parameters specify the position in cells (can be fractional
// for multi-cell characters), and w, h specify the radius multipliers.
// The corner determines which quadrant of the ellipse to draw.
fn circle_piece(mut canvas Canvas, width u32, height u32, metrics font.Metrics, x f64, y f64, w f64, h f64, corner Corner) ! {
	// Radius in pixels of the arc we need to draw.
	wdth := f64(width) * w
	hght := f64(height) * h

	// Position in pixels (rather than cells) for x/y
	xp := f64(width) * x
	yp := f64(height) * y

	// Set the clip so we don't include anything outside of the cell.
	canvas.clip_left = canvas.padding_x
	canvas.clip_right = canvas.padding_x
	canvas.clip_top = canvas.padding_y
	canvas.clip_bottom = canvas.padding_y

	// Coefficient for approximating a circular arc.
	c := (math.sqrt2 - 1.0) * 4.0 / 3.0
	cw := c * wdth
	ch := c * hght

	thick := f64(metrics.box_thickness)
	ht := thick * 0.5

	mut path := canvas.static_path(2)

	match corner {
		.tl {
			path.move_to(wdth - xp, ht - yp)
			path.curve_to(wdth - cw - xp, ht - yp, ht - xp, hght - ch - yp, ht - xp, hght - yp)
		}
		.tr {
			path.move_to(wdth - xp, ht - yp)
			path.curve_to(wdth + cw - xp, ht - yp, wdth * 2 - ht - xp, hght - ch - yp, wdth * 2 - ht - xp, hght - yp)
		}
		.bl {
			path.move_to(ht - xp, hght - yp)
			path.curve_to(ht - xp, hght + ch - yp, wdth - cw - xp, hght * 2 - ht - yp, wdth - xp, hght * 2 - ht - yp)
		}
		.br {
			path.move_to(wdth * 2 - ht - xp, hght - yp)
			path.curve_to(wdth * 2 - ht - xp, hght + ch - yp, wdth + cw - xp, hght * 2 - ht - yp, wdth - xp, hght * 2 - ht - yp)
		}
	}

	canvas.stroke_path(path.wrapped_path, StrokeOptions{
		line_cap_mode: .butt
		line_width: f64(metrics.box_thickness)
	}, .on)!
}
