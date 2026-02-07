module terminal

// x11_color.v - X11 color name lookup.
//
// Translated from Ghostty's terminal/x11_color.zig.
//
// The original uses an embedded rgb.txt file and comptime parsing.
// In V we use a lazily-initialized map with common X11 colors.
//
// XTODO: full X11 color table from rgb.txt not yet embedded.
// Currently includes the most commonly used colors and their
// case-insensitive aliases. The full rgb.txt has ~782 entries
// including numbered variants (e.g., snow1, snow2, etc.).

// x11_color_get looks up an X11 color name (case-insensitive).
// Returns the RGB value if found, or none if not found.
pub fn x11_color_get(name string) ?RGB {
	lower := name.to_lower()
	// Also try with spaces removed for compound names
	// (e.g., "medium spring green" -> "mediumspringgreen")
	no_spaces := lower.replace(' ', '')

	if lower in x11_color_map {
		return x11_color_map[lower]
	}
	if no_spaces in x11_color_map {
		return x11_color_map[no_spaces]
	}
	return none
}

// x11_color_map contains common X11 color name -> RGB mappings.
// All keys are stored in lowercase for case-insensitive lookup.
//
// XTODO: full X11 color table from rgb.txt not yet embedded.
// This subset includes the most commonly used X11/web colors.
const x11_color_map = {
	// Basic colors
	'white':                RGB{ r: 255, g: 255, b: 255 }
	'black':                RGB{ r: 0, g: 0, b: 0 }
	'red':                  RGB{ r: 255, g: 0, b: 0 }
	'green':                RGB{ r: 0, g: 255, b: 0 }
	'blue':                 RGB{ r: 0, g: 0, b: 255 }
	'yellow':               RGB{ r: 255, g: 255, b: 0 }
	'cyan':                 RGB{ r: 0, g: 255, b: 255 }
	'magenta':              RGB{ r: 255, g: 0, b: 255 }
	// Aliases
	'aqua':                 RGB{ r: 0, g: 255, b: 255 }
	'fuchsia':              RGB{ r: 255, g: 0, b: 255 }
	'lime':                 RGB{ r: 0, g: 255, b: 0 }
	// Grays
	'gray':                 RGB{ r: 190, g: 190, b: 190 }
	'grey':                 RGB{ r: 190, g: 190, b: 190 }
	'darkgray':             RGB{ r: 169, g: 169, b: 169 }
	'darkgrey':             RGB{ r: 169, g: 169, b: 169 }
	'lightgray':            RGB{ r: 211, g: 211, b: 211 }
	'lightgrey':            RGB{ r: 211, g: 211, b: 211 }
	'dimgray':              RGB{ r: 105, g: 105, b: 105 }
	'dimgrey':              RGB{ r: 105, g: 105, b: 105 }
	'silver':               RGB{ r: 192, g: 192, b: 192 }
	'gainsboro':            RGB{ r: 220, g: 220, b: 220 }
	'x11gray':              RGB{ r: 190, g: 190, b: 190 }
	'x11grey':              RGB{ r: 190, g: 190, b: 190 }
	'webgray':              RGB{ r: 128, g: 128, b: 128 }
	'webgrey':              RGB{ r: 128, g: 128, b: 128 }
	// Whites and near-whites
	'snow':                 RGB{ r: 255, g: 250, b: 250 }
	'ghostwhite':           RGB{ r: 248, g: 248, b: 255 }
	'whitesmoke':           RGB{ r: 245, g: 245, b: 245 }
	'floralwhite':          RGB{ r: 255, g: 250, b: 240 }
	'oldlace':              RGB{ r: 253, g: 245, b: 230 }
	'linen':                RGB{ r: 250, g: 240, b: 230 }
	'antiquewhite':         RGB{ r: 250, g: 235, b: 215 }
	'papayawhip':           RGB{ r: 255, g: 239, b: 213 }
	'blanchedalmond':       RGB{ r: 255, g: 235, b: 205 }
	'bisque':               RGB{ r: 255, g: 228, b: 196 }
	'peachpuff':            RGB{ r: 255, g: 218, b: 185 }
	'navajowhite':          RGB{ r: 255, g: 222, b: 173 }
	'moccasin':             RGB{ r: 255, g: 228, b: 181 }
	'cornsilk':             RGB{ r: 255, g: 248, b: 220 }
	'ivory':                RGB{ r: 255, g: 255, b: 240 }
	'lemonchiffon':         RGB{ r: 255, g: 250, b: 205 }
	'seashell':             RGB{ r: 255, g: 245, b: 238 }
	'honeydew':             RGB{ r: 240, g: 255, b: 240 }
	'mintcream':            RGB{ r: 245, g: 255, b: 250 }
	'azure':                RGB{ r: 240, g: 255, b: 255 }
	'aliceblue':            RGB{ r: 240, g: 248, b: 255 }
	'lavender':             RGB{ r: 230, g: 230, b: 250 }
	'lavenderblush':        RGB{ r: 255, g: 240, b: 245 }
	'mistyrose':            RGB{ r: 255, g: 228, b: 225 }
	// Blues
	'navy':                 RGB{ r: 0, g: 0, b: 128 }
	'navyblue':             RGB{ r: 0, g: 0, b: 128 }
	'midnightblue':         RGB{ r: 25, g: 25, b: 112 }
	'cornflowerblue':       RGB{ r: 100, g: 149, b: 237 }
	'darkslateblue':        RGB{ r: 72, g: 61, b: 139 }
	'slateblue':            RGB{ r: 106, g: 90, b: 205 }
	'mediumslateblue':      RGB{ r: 123, g: 104, b: 238 }
	'lightslateblue':       RGB{ r: 132, g: 112, b: 255 }
	'mediumblue':           RGB{ r: 0, g: 0, b: 205 }
	'royalblue':            RGB{ r: 65, g: 105, b: 225 }
	'dodgerblue':           RGB{ r: 30, g: 144, b: 255 }
	'deepskyblue':          RGB{ r: 0, g: 191, b: 255 }
	'skyblue':              RGB{ r: 135, g: 206, b: 235 }
	'lightskyblue':         RGB{ r: 135, g: 206, b: 250 }
	'steelblue':            RGB{ r: 70, g: 130, b: 180 }
	'lightsteelblue':       RGB{ r: 176, g: 196, b: 222 }
	'lightblue':            RGB{ r: 173, g: 216, b: 230 }
	'powderblue':           RGB{ r: 176, g: 224, b: 230 }
	// Cyans/Teals
	'paleturquoise':        RGB{ r: 175, g: 238, b: 238 }
	'darkturquoise':        RGB{ r: 0, g: 206, b: 209 }
	'mediumturquoise':      RGB{ r: 72, g: 209, b: 204 }
	'turquoise':            RGB{ r: 64, g: 224, b: 208 }
	'lightcyan':            RGB{ r: 224, g: 255, b: 255 }
	'cadetblue':            RGB{ r: 95, g: 158, b: 160 }
	'mediumaquamarine':     RGB{ r: 102, g: 205, b: 170 }
	'aquamarine':           RGB{ r: 127, g: 255, b: 212 }
	'teal':                 RGB{ r: 0, g: 128, b: 128 }
	'darkcyan':             RGB{ r: 0, g: 139, b: 139 }
	// Greens
	'darkgreen':            RGB{ r: 0, g: 100, b: 0 }
	'darkolivegreen':       RGB{ r: 85, g: 107, b: 47 }
	'darkseagreen':         RGB{ r: 143, g: 188, b: 143 }
	'seagreen':             RGB{ r: 46, g: 139, b: 87 }
	'mediumseagreen':       RGB{ r: 60, g: 179, b: 113 }
	'lightseagreen':        RGB{ r: 32, g: 178, b: 170 }
	'palegreen':            RGB{ r: 152, g: 251, b: 152 }
	'springgreen':          RGB{ r: 0, g: 255, b: 127 }
	'lawngreen':            RGB{ r: 124, g: 252, b: 0 }
	'x11green':             RGB{ r: 0, g: 255, b: 0 }
	'webgreen':             RGB{ r: 0, g: 128, b: 0 }
	'chartreuse':           RGB{ r: 127, g: 255, b: 0 }
	'mediumspringgreen':    RGB{ r: 0, g: 250, b: 154 }
	'greenyellow':          RGB{ r: 173, g: 255, b: 47 }
	'limegreen':            RGB{ r: 50, g: 205, b: 50 }
	'yellowgreen':          RGB{ r: 154, g: 205, b: 50 }
	'forestgreen':          RGB{ r: 34, g: 139, b: 34 }
	'olivedrab':            RGB{ r: 107, g: 142, b: 35 }
	'olive':                RGB{ r: 128, g: 128, b: 0 }
	// Yellows/Golds
	'darkkhaki':            RGB{ r: 189, g: 183, b: 107 }
	'khaki':                RGB{ r: 240, g: 230, b: 140 }
	'palegoldenrod':        RGB{ r: 238, g: 232, b: 170 }
	'lightgoldenrodyellow': RGB{ r: 250, g: 250, b: 210 }
	'lightyellow':          RGB{ r: 255, g: 255, b: 224 }
	'gold':                 RGB{ r: 255, g: 215, b: 0 }
	'lightgoldenrod':       RGB{ r: 238, g: 221, b: 130 }
	'goldenrod':            RGB{ r: 218, g: 165, b: 32 }
	'darkgoldenrod':        RGB{ r: 184, g: 134, b: 11 }
	// Browns
	'rosybrown':            RGB{ r: 188, g: 143, b: 143 }
	'indianred':            RGB{ r: 205, g: 92, b: 92 }
	'saddlebrown':          RGB{ r: 139, g: 69, b: 19 }
	'sienna':               RGB{ r: 160, g: 82, b: 45 }
	'peru':                 RGB{ r: 205, g: 133, b: 63 }
	'burlywood':            RGB{ r: 222, g: 184, b: 135 }
	'beige':                RGB{ r: 245, g: 245, b: 220 }
	'wheat':                RGB{ r: 245, g: 222, b: 179 }
	'sandybrown':           RGB{ r: 244, g: 164, b: 96 }
	'tan':                  RGB{ r: 210, g: 180, b: 140 }
	'chocolate':            RGB{ r: 210, g: 105, b: 30 }
	'firebrick':            RGB{ r: 178, g: 34, b: 34 }
	'brown':                RGB{ r: 165, g: 42, b: 42 }
	// Oranges/Salmons
	'darksalmon':           RGB{ r: 233, g: 150, b: 122 }
	'salmon':               RGB{ r: 250, g: 128, b: 114 }
	'lightsalmon':          RGB{ r: 255, g: 160, b: 122 }
	'orange':               RGB{ r: 255, g: 165, b: 0 }
	'darkorange':           RGB{ r: 255, g: 140, b: 0 }
	'coral':                RGB{ r: 255, g: 127, b: 80 }
	'lightcoral':           RGB{ r: 240, g: 128, b: 128 }
	'tomato':               RGB{ r: 255, g: 99, b: 71 }
	'orangered':            RGB{ r: 255, g: 69, b: 0 }
	// Pinks
	'hotpink':              RGB{ r: 255, g: 105, b: 180 }
	'deeppink':             RGB{ r: 255, g: 20, b: 147 }
	'pink':                 RGB{ r: 255, g: 192, b: 203 }
	'lightpink':            RGB{ r: 255, g: 182, b: 193 }
	'palevioletred':        RGB{ r: 219, g: 112, b: 147 }
	'mediumvioletred':      RGB{ r: 199, g: 21, b: 133 }
	'violetred':            RGB{ r: 208, g: 32, b: 144 }
	// Magentas/Purples
	'violet':               RGB{ r: 238, g: 130, b: 238 }
	'plum':                 RGB{ r: 221, g: 160, b: 221 }
	'orchid':               RGB{ r: 218, g: 112, b: 214 }
	'mediumorchid':         RGB{ r: 186, g: 85, b: 211 }
	'darkorchid':           RGB{ r: 153, g: 50, b: 204 }
	'darkviolet':           RGB{ r: 148, g: 0, b: 211 }
	'blueviolet':           RGB{ r: 138, g: 43, b: 226 }
	'purple':               RGB{ r: 160, g: 32, b: 240 }
	'x11purple':            RGB{ r: 160, g: 32, b: 240 }
	'webpurple':            RGB{ r: 128, g: 0, b: 128 }
	'mediumpurple':         RGB{ r: 147, g: 112, b: 219 }
	'thistle':              RGB{ r: 216, g: 191, b: 216 }
	// Maroons
	'maroon':               RGB{ r: 176, g: 48, b: 96 }
	'x11maroon':            RGB{ r: 176, g: 48, b: 96 }
	'webmaroon':            RGB{ r: 128, g: 0, b: 0 }
	// Slate
	'darkslategray':        RGB{ r: 47, g: 79, b: 79 }
	'darkslategrey':        RGB{ r: 47, g: 79, b: 79 }
	'slategray':            RGB{ r: 112, g: 128, b: 144 }
	'slategrey':            RGB{ r: 112, g: 128, b: 144 }
	'lightslategray':       RGB{ r: 119, g: 136, b: 153 }
	'lightslategrey':       RGB{ r: 119, g: 136, b: 153 }
	// Misc
	'indigo':               RGB{ r: 75, g: 0, b: 130 }
	'darkmagenta':          RGB{ r: 139, g: 0, b: 139 }
	'darkred':              RGB{ r: 139, g: 0, b: 0 }
	'darkblue':             RGB{ r: 0, g: 0, b: 139 }
}
