module main

import vaxis as v

fn main() {
	mut glyphs := v.BorderGlyphs(v.BorderCustom{
		glyphs: ['0', '1', '2', '3', '4', '5']!
	})
	copied := glyphs
	if mut glyphs is v.BorderCustom {
		glyphs.glyphs[0] = 'new'
	}
	if glyphs is v.BorderCustom { println(glyphs.glyphs[0]) }
	if copied is v.BorderCustom { println(copied.glyphs[0]) }
	mut where_ := v.BorderWhere(v.BorderLocations{})
	copied_where := where_
	if mut where_ is v.BorderLocations { where_.top = true }
	if where_ is v.BorderLocations { println(int(where_.top)) }
	if copied_where is v.BorderLocations { println(int(copied_where.top)) }
}
