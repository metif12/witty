module freetype

import os

const test_font_path = os.join_path(@VMODROOT, 'font', 'res', 'JetBrainsMono-Regular.ttf')

fn test_error_conversion() {
	int_to_error(0)!
	mut caught := false
	int_to_error(0x40) or {
		caught = true
		assert error_kind_of(err) == .out_of_memory
		assert err.code() == error_to_int(.out_of_memory)
	}
	assert caught
	int_to_error(0x18) or {
		assert error_kind_of(err) == .unknown_freetype_error
		return
	}
	assert false
}

fn test_tag_roundtrip() {
	tag := Tag.init('wght')
	assert tag.value == 0x77676874
	assert tag.str() == 'wght'
}

fn test_enum_values_match_freetype() {
	assert u32(Encoding.none) == 0
	assert u32(Encoding.ms_symbol) == 0x73796d62
	assert u32(Encoding.unicode) == 0x756e6963
	assert u32(Encoding.apple_roman) == 0x61726d6e
	assert u32(RenderMode.normal) == 0
	assert u32(RenderMode.sdf) == 5
	assert int(SfntTag.head) == 0
	assert int(SfntTag.maxp) == 1
	assert int(SfntTag.pclt) == 6
}

fn test_load_flags_all_bits_and_targets() {
	assert sizeof(LoadFlags) == 4
	mut flags := LoadFlags{}
	assert flags.to_int() == 0
	flags.set_no_scale(true)
	assert flags.to_int() == 1 << 0
	flags = LoadFlags{}
	flags.set_no_hinting(true)
	assert flags.to_int() == 1 << 1
	flags = LoadFlags{}
	flags.set_render(true)
	assert flags.to_int() == 1 << 2
	flags = LoadFlags{}
	flags.set_no_bitmap(true)
	assert flags.to_int() == 1 << 3
	flags = LoadFlags{}
	flags.set_vertical_layout(true)
	assert flags.to_int() == 1 << 4
	flags = LoadFlags{}
	flags.set_force_autohint(true)
	assert flags.to_int() == 1 << 5
	flags = LoadFlags{}
	flags.set_crop_bitmap(true)
	assert flags.to_int() == 1 << 6
	flags = LoadFlags{}
	flags.set_pedantic(true)
	assert flags.to_int() == 1 << 7
	flags = LoadFlags{}
	flags.set_advance_only(true)
	assert flags.to_int() == 1 << 8
	flags = LoadFlags{}
	flags.set_ignore_global_advance_width(true)
	assert flags.to_int() == 1 << 9
	flags = LoadFlags{}
	flags.set_no_recurse(true)
	assert flags.to_int() == 1 << 10
	flags = LoadFlags{}
	flags.set_ignore_transform(true)
	assert flags.to_int() == 1 << 11
	flags = LoadFlags{}
	flags.set_monochrome(true)
	assert flags.to_int() == 1 << 12
	flags = LoadFlags{}
	flags.set_linear_design(true)
	assert flags.to_int() == 1 << 13
	flags = LoadFlags{}
	flags.set_sbits_only(true)
	assert flags.to_int() == 1 << 14
	flags = LoadFlags{}
	flags.set_no_autohint(true)
	assert flags.to_int() == 1 << 15
	flags = LoadFlags{}
	flags.set_color(true)
	assert flags.to_int() == 1 << 20
	flags = LoadFlags{}
	flags.set_compute_metrics(true)
	assert flags.to_int() == 1 << 21
	flags = LoadFlags{}
	flags.set_bitmap_metrics_only(true)
	assert flags.to_int() == 1 << 22
	flags = LoadFlags{}
	flags.set_svg_only(true)
	assert flags.to_int() == 1 << 23
	flags = LoadFlags{}
	flags.set_no_svg(true)
	assert flags.to_int() == 1 << 24

	for target in [LoadTarget.normal, .light, .mono, .lcd, .lcd_v] {
		flags = LoadFlags{}
		flags.set_target(target)
		assert flags.target() == target
		assert flags.to_int() == i32(u32(target) << 16)
	}

	all := LoadFlags.from_int(0x01f4ffff)
	assert all.no_scale()
	assert all.no_hinting()
	assert all.render()
	assert all.no_bitmap()
	assert all.vertical_layout()
	assert all.force_autohint()
	assert all.crop_bitmap()
	assert all.pedantic()
	assert all.advance_only()
	assert all.ignore_global_advance_width()
	assert all.no_recurse()
	assert all.ignore_transform()
	assert all.monochrome()
	assert all.linear_design()
	assert all.sbits_only()
	assert all.no_autohint()
	assert all.target() == .lcd_v
	assert all.color()
	assert all.compute_metrics()
	assert all.bitmap_metrics_only()
	assert all.svg_only()
	assert all.no_svg()
}

fn test_library_version_and_face_surface() {
	mut library := Library.init()!
	defer { library.deinit() }
	version := library.version()
	assert version.major > 1
	mut version_buf := []u8{len: 32}
	assert version.to_string(mut version_buf)!.starts_with('${version.major}.')

	mut face := library.init_face(test_font_path, 0)!
	defer { face.deinit() }
	face.select_charmap(.unicode)!
	face.set_char_size(12, 0, 0, 0)!
	assert !face.has_fixed_sizes()
	assert face.is_scalable()
	assert face.get_char_index(u32(`A`)) != none
	assert face.has_sfnt_table(Tag.init('head'))
	assert !face.has_sfnt_table(Tag.init('zzzz'))
	assert face.get_sfnt_table_os2() != none
	table := face.load_sfnt_table(Tag.init('head'))!
	assert table.has_value
	assert table.data.len > 0

	matrix := Matrix{
		xx: 1 << 16
		yy: 1 << 16
	}
	delta := Vector{}
	face.set_transform(&matrix, &delta)
	face.set_transform(none, none)
}

fn test_mul_fix_uses_source_width() {
	assert mul_fix(2, 1 << 16) == 2
}
