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
		'reference_overflow' {
			quantizer.root_node.reference_count = 0xffffffff
			quantizer.root_node.add_color(zigimg.Rgb24{}, 8, mut quantizer) or { panic(err) }
		}
		'average_cast' {
			quantizer.root_node.red = 256
			quantizer.root_node.reference_count = 1
			quantizer.root_node.get_color()
		}
		'color_level' {
			quantizer.root_node.get_palette_index(zigimg.Rgb24{}, 8) or { panic(err) }
		}
		else {
			panic('unknown case')
		}
	}

	eprintln('UNEXPECTED: quantizer returned')
}
