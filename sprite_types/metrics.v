module sprite_types

// AtlasRegion is the cycle-free value shared by the font atlas and sprite
// canvas. Ghostty declares this as Atlas.Region; keeping the value here lets
// Canvas.write_atlas retain its source ownership without introducing the
// font -> sprite -> font module cycle that V rejects.
pub struct AtlasRegion {
pub mut:
	x      u32
	y      u32
	width  u32
	height u32
}

// Metrics is the dependency-neutral subset of font grid metrics consumed by
// Ghostty's built-in sprite drawing functions. Keeping this value type outside
// both font and sprite lets font invoke the real sprite renderer without an
// import cycle.
pub struct Metrics {
pub mut:
	cell_width              u32
	cell_height             u32
	cell_baseline           u32
	underline_position      u32
	underline_thickness     u32
	strikethrough_position  u32
	strikethrough_thickness u32
	overline_position       i32
	overline_thickness      u32
	box_thickness           u32
	cursor_thickness        u32 = 1
	cursor_height           u32
	icon_height             f64
	icon_height_single      f64
	face_width              f64
	face_height             f64
	face_y                  f64
}

pub fn default_grid_metrics(cell_width u32, cell_height u32) Metrics {
	return Metrics{
		cell_width:              cell_width
		cell_height:             cell_height
		underline_position:      cell_height
		underline_thickness:     2
		strikethrough_position:  cell_height / 2
		strikethrough_thickness: 1
		overline_thickness:      1
		box_thickness:           1
		cursor_thickness:        1
		cursor_height:           cell_height
		icon_height:             f64(cell_height)
		icon_height_single:      f64(cell_height)
		face_width:              f64(cell_width)
		face_height:             f64(cell_height)
	}
}
