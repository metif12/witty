module main

import os
import zigimg

fn main() {
	assert os.args.len == 2
	mut quantizer := zigimg.OctTreeQuantizer.init()
	mut storage := []zigimg.Rgba32{len: 1}
	match os.args[1] {
		'palette_capacity' {
			quantizer.add_color(zigimg.Rgb24{ r: 255 }) or { panic(err) }
			quantizer.add_color(zigimg.Rgb24{ g: 255 }) or { panic(err) }
			quantizer.make_palette(2, mut storage)
		}
		'repeated_reduction' {
			quantizer.add_color(zigimg.Rgb24{ r: 10, g: 20, b: 30 }) or { panic(err) }
			quantizer.add_color(zigimg.Rgb24{ r: 11, g: 21, b: 31 }) or { panic(err) }
			quantizer.make_palette(1, mut storage)
			quantizer.make_palette(0, mut storage)
		}
		'component_overflow' {
			quantizer.root_node.red = 0xffffffff
			quantizer.root_node.add_color(zigimg.Rgb24{ r: 1 }, 8, mut quantizer) or { panic(err) }
		}
		'green_overflow' {
			quantizer.root_node.green = 0xffffffff
			quantizer.root_node.add_color(zigimg.Rgb24{ g: 1 }, 8, mut quantizer) or { panic(err) }
		}
		'blue_overflow' {
			quantizer.root_node.blue = 0xffffffff
			quantizer.root_node.add_color(zigimg.Rgb24{ b: 1 }, 8, mut quantizer) or { panic(err) }
		}
		'reference_overflow' {
			quantizer.root_node.reference_count = 0xffffffff
			quantizer.root_node.add_color(zigimg.Rgb24{}, 8, mut quantizer) or { panic(err) }
		}
		'average_cast' {
			quantizer.root_node.red = 256
			quantizer.root_node.reference_count = 1
			quantizer.root_node.get_color()
		}
		'green_average_cast' {
			quantizer.root_node.green = 256
			quantizer.root_node.reference_count = 1
			quantizer.root_node.get_color()
		}
		'blue_average_cast' {
			quantizer.root_node.blue = 256
			quantizer.root_node.reference_count = 1
			quantizer.root_node.get_color()
		}
		'zero_average' { quantizer.root_node.get_color() }
		'color_level' {
			quantizer.root_node.get_palette_index(zigimg.Rgb24{}, 8) or {
				eprintln('UNEXPECTED: returned error ${err}')
				return
			}
		}
		'negative_color_level' {
			quantizer.root_node.get_palette_index(zigimg.Rgb24{}, -1) or {
				eprintln('UNEXPECTED: returned error ${err}')
				return
			}
		}
		'negative_level' {
			mut node := zigimg.OctTreeNode{}
			quantizer.add_level_node(-1, mut node)
		}
		'high_level' {
			mut node := zigimg.OctTreeNode{}
			quantizer.add_level_node(8, mut node)
		}
		'leaf_count_underflow' {
			mut node := quantizer.allocate_node() or { panic(err) }
			node.children[0] = quantizer.allocate_node() or { panic(err) }
			node.children[1] = quantizer.allocate_node() or { panic(err) }
			quantizer.levels[7] = node
			quantizer.make_palette(0, mut storage)
		}
		'palette_context_capacity' {
			quantizer.root_node.reference_count = 1
			mut context := zigimg.OctTreePaletteContext{ palette: unsafe { storage }, palette_index: 1, color_count: 2 }
			quantizer.root_node.make_palette(mut context)
		}
		else {
			panic('unknown case')
		}
	}

	eprintln('UNEXPECTED: quantizer returned')
}
