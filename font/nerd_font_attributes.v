// This is a generated file, produced by nerd_font_codegen.py
// DO NOT EDIT BY HAND!
//
// This file provides info extracted from the nerd fonts patcher script,
// specifying the scaling/positioning attributes of various glyphs.
module font

// Get the constraint for the provided codepoint.
pub fn get_constraint(cp u32) ?Constraint {
	if cp == 0x2630 {
		return Constraint{
			size: .cover
			height: .icon
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_left: 0.05
			pad_right: 0.05
			pad_top: 0.05
			pad_bottom: 0.05
		}
	} else if cp >= 0x276c && cp <= 0x276d {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_top: 0.15
			pad_bottom: 0.15
			relative_width: 0.7142857142857143
			relative_height: 0.8910614525139665
			relative_x: 0.1428571428571428
			relative_y: 0.0349162011173184
		}
	} else if cp >= 0x276e && cp <= 0x276f {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_top: 0.15
			pad_bottom: 0.15
			relative_width: 0.9885714285714285
			relative_height: 0.8910614525139665
			relative_x: 0.0057142857142857
			relative_y: 0.0125698324022346
		}
	} else if cp >= 0x2770 && cp <= 0x2771 {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_top: 0.15
			pad_bottom: 0.15
		}
	} else if (cp >= 0xe0a0 && cp <= 0xe0a3) || cp == 0xe0cf {
		return Constraint{
			size: .fit_cover1
			align_horizontal: .center1
			align_vertical: .center1
		}
	} else if cp == 0xe0b0 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
			pad_left: -0.03
			pad_right: -0.03
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.7
		}
	} else if cp == 0xe0b1 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
			max_xy_ratio: 0.7
		}
	} else if cp == 0xe0b2 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: -0.03
			pad_right: -0.03
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.7
		}
	} else if cp == 0xe0b3 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
			max_xy_ratio: 0.7
		}
	} else if cp == 0xe0b4 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
			pad_left: -0.03
			pad_right: -0.03
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.59
		}
	} else if cp == 0xe0b5 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
			max_xy_ratio: 0.5
		}
	} else if cp == 0xe0b6 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: -0.03
			pad_right: -0.03
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.59
		}
	} else if cp == 0xe0b7 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
			max_xy_ratio: 0.5
		}
	} else if cp == 0xe0b8 || cp == 0xe0bc {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
			pad_left: -0.025
			pad_right: -0.025
			pad_top: -0.005
			pad_bottom: -0.005
		}
	} else if cp == 0xe0b9 || cp == 0xe0bd {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
		}
	} else if cp == 0xe0ba || cp == 0xe0be {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: -0.025
			pad_right: -0.025
			pad_top: -0.005
			pad_bottom: -0.005
		}
	} else if cp == 0xe0bb || cp == 0xe0bf {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
		}
	} else if cp == 0xe0c0 || cp == 0xe0c8 {
		return Constraint{
			size: .stretch
			align_horizontal: .start
			align_vertical: .center1
			pad_left: -0.025
			pad_right: -0.025
			pad_top: -0.005
			pad_bottom: -0.005
		}
	} else if cp == 0xe0c1 {
		return Constraint{
			size: .stretch
			align_horizontal: .start
			align_vertical: .center1
		}
	} else if cp == 0xe0c2 || cp == 0xe0ca {
		return Constraint{
			size: .stretch
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: -0.025
			pad_right: -0.025
			pad_top: -0.005
			pad_bottom: -0.005
		}
	} else if cp == 0xe0c3 {
		return Constraint{
			size: .stretch
			align_horizontal: .end_
			align_vertical: .center1
		}
	} else if cp == 0xe0c4 {
		return Constraint{
			size: .stretch
			align_horizontal: .start
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			max_xy_ratio: 0.86
		}
	} else if cp == 0xe0c5 {
		return Constraint{
			size: .stretch
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			max_xy_ratio: 0.86
		}
	} else if cp == 0xe0c6 {
		return Constraint{
			size: .stretch
			align_horizontal: .start
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			max_xy_ratio: 0.78
		}
	} else if cp == 0xe0c7 {
		return Constraint{
			size: .stretch
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			max_xy_ratio: 0.78
		}
	} else if cp == 0xe0cc {
		return Constraint{
			size: .stretch
			align_horizontal: .start
			align_vertical: .center1
			pad_left: -0.01
			pad_right: -0.01
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.85
		}
	} else if cp == 0xe0cd {
		return Constraint{
			size: .stretch
			align_horizontal: .start
			align_vertical: .center1
			max_xy_ratio: 0.865
		}
	} else if cp == 0xe0ce || (cp >= 0xe0d0 && cp <= 0xe0d1) {
		return Constraint{
			size: .fit_cover1
			align_horizontal: .start
			align_vertical: .center1
		}
	} else if cp == 0xe0d2 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
			pad_left: -0.01
			pad_right: -0.01
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.7
		}
	} else if cp == 0xe0d4 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: -0.01
			pad_right: -0.01
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.7
		}
	} else if cp == 0xe0d6 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
			pad_left: -0.025
			pad_right: -0.025
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.7
		}
	} else if cp == 0xe0d7 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: -0.025
			pad_right: -0.025
			pad_top: -0.005
			pad_bottom: -0.005
			max_xy_ratio: 0.7
		}
	} else if cp == 0xe300 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8984375000000000
			relative_y: 0.0986328125000000
		}
	} else if cp == 0xe301 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8798828125000000
			relative_y: 0.1171875000000000
		}
	} else if cp == 0xe302 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7646484375000000
			relative_y: 0.2314453125000000
		}
	} else if cp == 0xe303 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8789062500000000
			relative_y: 0.1171875000000000
		}
	} else if cp == 0xe304 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9755859375000000
			relative_y: 0.0244140625000000
		}
	} else if cp == 0xe305 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9960937500000000
			relative_y: 0.0019531250000000
		}
	} else if cp == 0xe306 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9863281250000000
			relative_y: 0.0097656250000000
		}
	} else if cp == 0xe307 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9951171875000000
			relative_y: 0.0039062500000000
		}
	} else if cp == 0xe308 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9785156250000000
			relative_y: 0.0195312500000000
		}
	} else if cp == 0xe309 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9736328125000000
			relative_y: 0.0214843750000000
		}
	} else if cp == 0xe30a || cp == 0xe35f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9648437500000000
			relative_y: 0.0302734375000000
		}
	} else if cp == 0xe30b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8437500000000000
			relative_y: 0.1513671875000000
		}
	} else if cp == 0xe30c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8027343750000000
			relative_y: 0.1835937500000000
		}
	} else if cp == 0xe30d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7753906250000000
			relative_y: 0.1083984375000000
		}
	} else if cp == 0xe30e || cp == 0xe365 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9833984375000000
			relative_y: 0.0166015625000000
		}
	} else if cp == 0xe30f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9716796875000000
			relative_y: 0.0263671875000000
		}
	} else if cp == 0xe310 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6621093750000000
			relative_y: 0.0986328125000000
		}
	} else if cp == 0xe311 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6425781250000000
			relative_y: 0.1171875000000000
		}
	} else if cp == 0xe312 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5322265625000000
			relative_y: 0.2314453125000000
		}
	} else if cp == 0xe313 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6416015625000000
			relative_y: 0.1181640625000000
		}
	} else if cp == 0xe314 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7382812500000000
			relative_y: 0.0195312500000000
		}
	} else if cp == 0xe315 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6787109375000000
			relative_y: 0.1357421875000000
		}
	} else if cp == 0xe316 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7480468750000000
			relative_y: 0.0097656250000000
		}
	} else if cp == 0xe317 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7529296875000000
			relative_y: 0.0048828125000000
		}
	} else if cp == 0xe318 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7314453125000000
			relative_y: 0.0263671875000000
		}
	} else if cp == 0xe319 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7402343750000000
			relative_y: 0.0195312500000000
		}
	} else if cp == 0xe31a || cp == 0xe35e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7294921875000000
			relative_y: 0.0283203125000000
		}
	} else if cp == 0xe31b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6074218750000000
			relative_y: 0.1503906250000000
		}
	} else if cp == 0xe31c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7363281250000000
			relative_y: 0.0224609375000000
		}
	} else if cp == 0xe31d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7460937500000000
			relative_y: 0.0126953125000000
		}
	} else if cp == 0xe31e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.2675781250000000
			relative_y: 0.3310546875000000
		}
	} else if cp == 0xe31f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7363281250000000
			relative_y: 0.0986328125000000
		}
	} else if cp == 0xe320 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7177734375000000
			relative_y: 0.1171875000000000
		}
	} else if cp == 0xe321 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8085937500000000
			relative_y: 0.0253906250000000
		}
	} else if cp == 0xe322 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7509765625000000
			relative_y: 0.0839843750000000
		}
	} else if cp == 0xe323 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8281250000000000
			relative_y: 0.0097656250000000
		}
	} else if cp == 0xe324 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8349609375000000
		}
	} else if cp == 0xe325 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8154296875000000
			relative_y: 0.0214843750000000
		}
	} else if cp == 0xe326 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8144531250000000
			relative_y: 0.0195312500000000
		}
	} else if cp == 0xe327 || cp == 0xe361 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8076171875000000
			relative_y: 0.0273437500000000
		}
	} else if cp == 0xe328 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6845703125000000
			relative_y: 0.1503906250000000
		}
	} else if cp == 0xe329 || cp == 0xe367 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8173828125000000
			relative_y: 0.0175781250000000
		}
	} else if cp == 0xe32a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8105468750000000
			relative_y: 0.0263671875000000
		}
	} else if cp == 0xe32b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5175781250000000
			relative_y: 0.2421875000000000
		}
	} else if cp == 0xe32c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6992187500000000
			relative_y: 0.1005859375000000
		}
	} else if cp == 0xe32d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6787109375000000
			relative_y: 0.1201171875000000
		}
	} else if cp == 0xe32e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5654296875000000
			relative_y: 0.2324218750000000
		}
	} else if cp == 0xe32f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7714843750000000
			relative_y: 0.0273437500000000
		}
	} else if cp == 0xe330 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7148437500000000
			relative_y: 0.0830078125000000
		}
	} else if cp == 0xe331 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7919921875000000
			relative_y: 0.0097656250000000
		}
	} else if cp == 0xe332 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7871093750000000
			relative_y: 0.0126953125000000
		}
	} else if cp == 0xe333 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7714843750000000
			relative_y: 0.0263671875000000
		}
	} else if cp == 0xe334 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7773437500000000
			relative_y: 0.0195312500000000
		}
	} else if cp == 0xe335 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7714843750000000
			relative_y: 0.0283203125000000
		}
	} else if cp == 0xe336 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6503906250000000
			relative_y: 0.1503906250000000
		}
	} else if cp == 0xe337 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7753906250000000
			relative_y: 0.0234375000000000
		}
	} else if cp == 0xe338 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7792968750000000
			relative_y: 0.0185546875000000
		}
	} else if cp == 0xe339 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8445945945945946
		}
	} else if cp == 0xe33a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5283203125000000
			relative_y: 0.2324218750000000
		}
	} else if cp == 0xe33b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5449218750000000
			relative_y: 0.2148437500000000
		}
	} else if cp >= 0xe33c && cp <= 0xe33d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5273437500000000
			relative_y: 0.2324218750000000
		}
	} else if cp == 0xe33e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.3293918918918919
			relative_y: 0.6706081081081081
		}
	} else if cp == 0xe33f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5200000000000000
			relative_y: 0.2707692307692308
		}
	} else if cp == 0xe340 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8307692307692308
			relative_y: 0.0861538461538462
		}
	} else if cp == 0xe341 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8327702702702703
			relative_y: 0.0050675675675676
		}
	} else if cp == 0xe344 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5307692307692308
			relative_y: 0.2092307692307692
		}
	} else if cp == 0xe345 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5332112630208333
			relative_y: 0.2040934244791667
		}
	} else if cp == 0xe347 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8307692307692308
			relative_y: 0.1246153846153846
		}
	} else if cp == 0xe349 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5307967032967034
			relative_y: 0.2615384615384616
		}
	} else if cp == 0xe34c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8659995118379302
			relative_y: 0.1340004881620698
		}
	} else if cp == 0xe34d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9890163534293386
			relative_y: 0.0002440810349036
		}
	} else if cp == 0xe34f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5751953125000000
			relative_y: 0.1142578125000000
		}
	} else if cp == 0xe351 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6533203125000000
			relative_y: 0.1328125000000000
		}
	} else if cp == 0xe352 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5215384615384615
			relative_y: 0.2846153846153846
		}
	} else if cp == 0xe353 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8308012820512821
			relative_y: 0.1230448717948718
		}
	} else if (cp >= 0xe354 && cp <= 0xe356) || (cp >= 0xe358 && cp <= 0xe359) {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9935233160621761
			relative_y: 0.0025906735751295
		}
	} else if cp == 0xe357 || cp == 0xe3a9 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9961139896373057
		}
	} else if cp == 0xe35a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9935233160621761
			relative_y: 0.0012953367875648
		}
	} else if cp == 0xe35b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9987046632124352
			relative_y: 0.0012953367875648
		}
	} else if cp == 0xe360 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7695312500000000
			relative_y: 0.0302734375000000
		}
	} else if cp == 0xe362 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9902343750000000
			relative_y: 0.0097656250000000
		}
	} else if cp == 0xe363 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7900390625000000
			relative_y: 0.0097656250000000
		}
	} else if cp == 0xe364 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8251953125000000
			relative_y: 0.0097656250000000
		}
	} else if cp == 0xe366 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7832031250000000
			relative_y: 0.0166015625000000
		}
	} else if cp == 0xe369 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.4902343750000000
			relative_y: 0.2548828125000000
		}
	} else if cp == 0xe36b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9333658774713205
			relative_y: 0.0266048328044911
		}
	} else if cp == 0xe36c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7076171875000000
			relative_y: 0.1083984375000000
		}
	} else if cp == 0xe36d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8427734375000000
			relative_y: 0.0625000000000000
		}
	} else if cp == 0xe36e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7529721467391304
			relative_y: 0.0956606657608696
		}
	} else if cp == 0xe36f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6835937500000000
			relative_y: 0.1250000000000000
		}
	} else if cp == 0xe370 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8642578125000000
			relative_y: 0.0625000000000000
		}
	} else if cp == 0xe371 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6103515625000000
			relative_y: 0.1933593750000000
		}
	} else if cp == 0xe372 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7949218750000000
			relative_y: 0.0576171875000000
		}
	} else if cp == 0xe373 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8652343750000000
			relative_y: 0.0058593750000000
		}
	} else if cp == 0xe374 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.3154296875000000
			relative_y: 0.2861328125000000
		}
	} else if cp == 0xe375 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6772460937500000
			relative_y: 0.1303710937500000
		}
	} else if cp == 0xe376 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6992187500000000
			relative_y: 0.1337890625000000
		}
	} else if cp == 0xe377 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7314453125000000
			relative_y: 0.1552734375000000
		}
	} else if cp == 0xe378 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7314453125000000
			relative_y: 0.1542968750000000
		}
	} else if cp == 0xe379 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5751953125000000
			relative_y: 0.1826171875000000
		}
	} else if cp == 0xe37a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5263671875000000
			relative_y: 0.2285156250000000
		}
	} else if cp == 0xe37b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5751953125000000
			relative_y: 0.1835937500000000
		}
	} else if cp == 0xe37d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9003906250000000
			relative_y: 0.0957031250000000
		}
	} else if cp == 0xe37e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6015625000000000
			relative_y: 0.2324218750000000
		}
	} else if cp == 0xe37f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5200000000000000
			relative_y: 0.2784615384615385
		}
	} else if cp == 0xe380 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5200000000000000
			relative_y: 0.2630769230769231
		}
	} else if (cp >= 0xe38e && cp <= 0xe391) || cp == 0xe394 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4990253411306043
			relative_height: 0.9987012987012988
			relative_x: 0.4996751137102014
		}
	} else if cp >= 0xe392 && cp <= 0xe393 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4996751137102014
			relative_height: 0.9987012987012988
			relative_x: 0.4990253411306043
		}
	} else if cp == 0xe395 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5471085120207927
			relative_height: 0.9987012987012988
			relative_x: 0.4515919428200130
		}
	} else if cp == 0xe396 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5945419103313840
			relative_height: 0.9987012987012988
			relative_x: 0.4041585445094217
		}
	} else if cp == 0xe397 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6426250812215725
			relative_x: 0.3573749187784275
		}
	} else if cp == 0xe398 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6900584795321637
			relative_x: 0.3099415204678362
		}
	} else if cp == 0xe399 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7381416504223521
			relative_x: 0.2618583495776478
		}
	} else if cp == 0xe39a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7855750487329435
			relative_x: 0.2144249512670565
		}
	} else if cp == 0xe39b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9987004548408057
			relative_height: 0.9987012987012988
		}
	} else if cp == 0xe39c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8323586744639376
			relative_height: 0.9935064935064936
		}
	} else if cp == 0xe39d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7855750487329435
			relative_height: 0.9948051948051948
		}
	} else if cp == 0xe39e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7381416504223521
			relative_height: 0.9961038961038962
		}
	} else if cp == 0xe39f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6907082521117609
			relative_height: 0.9961038961038962
		}
	} else if cp == 0xe3a0 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6426250812215725
			relative_height: 0.9961038961038962
		}
	} else if cp == 0xe3a1 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5945419103313840
			relative_height: 0.9974025974025974
		}
	} else if (cp >= 0xe3a2 && cp <= 0xe3a3) || cp == 0xe3a5 || (cp >= 0xe3a7 && cp <= 0xe3a8) {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4990253411306043
			relative_height: 0.9987012987012988
		}
	} else if cp == 0xe3a4 || cp == 0xe3a6 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4996751137102014
			relative_height: 0.9987012987012988
		}
	} else if cp == 0xe3aa {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9902343750000000
			relative_y: 0.0078125000000000
		}
	} else if cp == 0xe3ab {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7900390625000000
			relative_y: 0.0058593750000000
		}
	} else if cp == 0xe3ac {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8251953125000000
			relative_y: 0.0078125000000000
		}
	} else if cp == 0xe3ad {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7519531250000000
			relative_y: 0.0068359375000000
		}
	} else if cp == 0xe3ae {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6152343750000000
			relative_y: 0.2324218750000000
		}
	} else if cp == 0xe3af || cp == 0xe3b3 || (cp >= 0xe3b5 && cp <= 0xe3bb) {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9986072423398329
			relative_y: 0.0013927576601671
		}
	} else if cp >= 0xe3b0 && cp <= 0xe3b2 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9958217270194986
			relative_y: 0.0041782729805014
		}
	} else if cp == 0xe3c1 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6590187942396876
			relative_y: 0.1349768123016842
		}
	} else if cp == 0xe3c2 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7939956065413717
		}
	} else if is_nerd_font_icon(cp) {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
		}
	} else if cp == 0xea61 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7513020833333334
			relative_height: 0.9291573452647278
			relative_x: 0.0846354166666667
			relative_y: 0.0708426547352722
		}
	} else if cp == 0xea7d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8394854586129754
			relative_height: 0.8751387347391787
			relative_x: 0.0917225950782998
			relative_y: 0.0416204217536071
		}
	} else if cp == 0xea99 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9395973154362416
			relative_height: 0.4778024417314096
			relative_x: 0.0302013422818792
			relative_y: 0.2269700332963374
		}
	} else if cp == 0xea9a || cp == 0xeaa1 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7673378076062640
			relative_height: 0.8523862375138734
			relative_x: 0.1526845637583893
			relative_y: 0.0754716981132075
		}
	} else if cp == 0xea9b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8590604026845637
			relative_height: 0.7613762486126526
			relative_x: 0.0721476510067114
			relative_y: 0.0871254162042175
		}
	} else if cp == 0xea9c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8590604026845637
			relative_height: 0.7574916759156493
			relative_x: 0.0721476510067114
			relative_y: 0.0832408435072142
		}
	} else if cp == 0xea9d || cp == 0xeaa0 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4082774049217002
			relative_height: 0.5077691453940066
			relative_x: 0.2863534675615212
			relative_y: 0.2763596004439512
		}
	} else if cp >= 0xea9e && cp <= 0xea9f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5117449664429530
			relative_height: 0.4051054384017758
			relative_x: 0.2136465324384788
			relative_y: 0.3068812430632630
		}
	} else if cp == 0xeaa2 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8061116965226555
			relative_height: 0.9438247156716689
			relative_x: 0.0679662802950474
			relative_y: 0.0147523709167545
		}
	} else if cp == 0xeab4 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9945482866043613
			relative_height: 0.5264797507788161
			relative_y: 0.2024922118380062
		}
	} else if cp == 0xeab5 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5264797507788161
			relative_height: 0.9945482866043613
			relative_x: 0.2024922118380062
			relative_y: 0.0054517133956386
		}
	} else if cp == 0xeab6 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5264797507788161
			relative_height: 0.9945482866043613
			relative_x: 0.2710280373831775
		}
	} else if cp == 0xeab7 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9945482866043613
			relative_height: 0.5264797507788161
			relative_x: 0.0054517133956386
			relative_y: 0.2710280373831775
		}
	} else if cp >= 0xead4 && cp <= 0xead5 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7069825436408977
			relative_x: 0.1483790523690773
		}
	} else if cp == 0xead6 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8780760626398211
			relative_y: 0.0687919463087248
		}
	} else if cp == 0xeb43 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7335766423357665
			relative_height: 0.9996188152778837
			relative_x: 0.1991657977059437
			relative_y: 0.0003811847221163
		}
	} else if cp == 0xeb6e || cp == 0xeb71 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.4954604409857328
			relative_y: 0.2522697795071336
		}
	} else if cp == 0xeb6f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4973958333333333
			relative_x: 0.2493489583333333
		}
	} else if cp == 0xeb70 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4973958333333333
			relative_height: 0.9961089494163424
			relative_x: 0.2493489583333333
			relative_y: 0.0038910505836576
		}
	} else if cp == 0xeb8a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.3468834688346883
			relative_height: 0.3353615785256410
			relative_x: 0.2642276422764228
			relative_y: 0.3313050881410256
		}
	} else if cp == 0xeb9a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8740779768177028
			relative_height: 0.9438247156716689
			relative_x: 0.0679662802950474
			relative_y: 0.0147523709167545
		}
	} else if cp == 0xebd5 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9322210636079249
			relative_height: 0.9318897917604415
			relative_y: 0.0681102082395584
		}
	} else if cp == 0xebd6 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9996446423917936
			relative_y: 0.0003553576082064
		}
	} else if cp == 0xec07 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.3495911047345768
			relative_height: 0.3355179398148149
			relative_x: 0.2615335565120357
			relative_y: 0.3311487268518519
		}
	} else if cp == 0xec0b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9327424400417101
			relative_height: 0.9996188152778837
			relative_y: 0.0003811847221163
		}
	} else if cp == 0xec0c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8008342022940563
			relative_x: 0.1991657977059437
		}
	} else if cp == 0xee00 || cp == 0xee03 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .end_
			align_vertical: .center1
			pad_left: -0.025
			pad_right: -0.025
			pad_top: -0.005
			pad_bottom: -0.005
			relative_width: 0.8681172291296625
			relative_height: 0.8626692456479691
			relative_x: 0.1314387211367673
			relative_y: 0.0686653771760155
		}
	} else if cp == 0xee01 || cp == 0xee04 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_left: -0.05
			pad_right: -0.05
			pad_top: -0.005
			pad_bottom: -0.005
			relative_height: 0.8626692456479691
			relative_y: 0.0686653771760155
		}
	} else if cp == 0xee02 || cp == 0xee05 {
		return Constraint{
			size: .stretch
			max_constraint_width: 1
			align_horizontal: .start
			align_vertical: .center1
			pad_left: -0.025
			pad_right: -0.025
			pad_top: -0.005
			pad_bottom: -0.005
			relative_width: 0.8685612788632326
			relative_height: 0.8626692456479691
			relative_y: 0.0686653771760155
		}
	} else if cp == 0xee06 {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			relative_width: 0.7059415911379657
			relative_height: 0.2234524408656266
			relative_x: 0.1470292044310171
			relative_y: 0.7765475591343735
		}
	} else if cp == 0xee07 {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			relative_width: 0.5000000000000000
			relative_height: 0.7498741821841973
			relative_x: 0.5000000000000000
			relative_y: 0.2501258178158027
		}
	} else if cp == 0xee08 {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			relative_width: 0.6299093655589124
			relative_height: 0.8535480624056366
			relative_x: 0.3700906344410876
		}
	} else if cp == 0xee09 {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			relative_height: 0.4997483643683945
		}
	} else if cp == 0xee0a {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			relative_width: 0.6299093655589124
			relative_height: 0.8535480624056366
		}
	} else if cp == 0xee0b {
		return Constraint{
			size: .cover
			max_constraint_width: 1
			align_horizontal: .center1
			align_vertical: .center1
			pad_left: 0.015
			pad_right: 0.015
			pad_top: 0.015
			pad_bottom: 0.015
			relative_width: 0.5000000000000000
			relative_height: 0.7498741821841973
			relative_y: 0.2501258178158027
		}
	} else if cp == 0xf005 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9999664113932554
			relative_y: 0.0000335886067446
		}
	} else if cp >= 0xf026 && cp <= 0xf027 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9786184354605580
			relative_y: 0.0103951316192896
		}
	} else if cp == 0xf02b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9758052740827267
			relative_y: 0.0238869355863696
		}
	} else if cp >= 0xf031 && cp <= 0xf033 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9987922705314010
			relative_y: 0.0006038647342995
		}
	} else if cp == 0xf035 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9989935587761675
			relative_y: 0.0004025764895330
		}
	} else if cp == 0xf044 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9925925925925926
		}
	} else if cp == 0xf046 || (cp >= 0xf153 && cp <= 0xf154) || cp == 0xf158 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8751322751322751
			relative_y: 0.0624338624338624
		}
	} else if cp == 0xf048 || cp == 0xf04a || cp == 0xf04e || cp == 0xf051 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8577706898990622
			relative_y: 0.0711892586341537
		}
	} else if cp == 0xf049 || cp == 0xf050 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8579450878868969
			relative_y: 0.0710148606463189
		}
	} else if cp == 0xf04b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9997041418532618
			relative_y: 0.0002958581467381
		}
	} else if cp >= 0xf04c && cp <= 0xf04d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8572940020656472
			relative_y: 0.0713404035569438
		}
	} else if cp == 0xf04f {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7138835298072554
			relative_y: 0.1433479295317200
		}
	} else if cp == 0xf052 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9999748091795350
		}
	} else if cp >= 0xf060 && cp <= 0xf061 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8567975830815709
			relative_y: 0.0719033232628399
		}
	} else if cp == 0xf063 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9987915407854985
			relative_y: 0.0006042296072508
		}
	} else if cp == 0xf077 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5700483091787439
			relative_y: 0.2862318840579710
		}
	} else if cp == 0xf078 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5700483091787439
			relative_y: 0.1437198067632850
		}
	} else if cp == 0xf07e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.4989429175475687
			relative_y: 0.2505285412262157
		}
	} else if cp == 0xf089 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9998488512696494
			relative_y: 0.0001511487303507
		}
	} else if cp >= 0xf0a4 && cp <= 0xf0a5 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7502645502645503
			relative_y: 0.1248677248677249
		}
	} else if cp == 0xf0d7 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.4281400966183575
			relative_y: 0.2053140096618357
		}
	} else if cp == 0xf0d8 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.4281400966183575
			relative_y: 0.3472222222222222
		}
	} else if cp == 0xf0d9 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7140772371750631
			relative_y: 0.1333462732919255
		}
	} else if cp == 0xf0da {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7140396210163651
			relative_y: 0.1333838894506235
		}
	} else if cp == 0xf0dc {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
		}
	} else if cp == 0xf0dd {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			relative_height: 0.4275362318840580
			relative_y: 0.0012077294685990
		}
	} else if cp == 0xf0de {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			relative_height: 0.4287439613526570
			relative_y: 0.5712560386473430
		}
	} else if (cp >= 0xf100 && cp <= 0xf101) || (cp >= 0xf104 && cp <= 0xf105) {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8573155985489722
			relative_y: 0.0713422007255139
		}
	} else if cp == 0xf102 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9286577992744861
			relative_y: 0.0713422007255139
		}
	} else if cp == 0xf103 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9286577992744861
		}
	} else if cp >= 0xf106 && cp <= 0xf107 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.5000000000000000
			relative_y: 0.2853688029020556
		}
	} else if cp == 0xf130 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9998602571268865
		}
	} else if cp == 0xf141 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.2593984962406015
			relative_y: 0.3696741854636592
		}
	} else if cp == 0xf156 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8752505446623093
			relative_y: 0.0623155929038282
		}
	} else if cp == 0xf157 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8756468797564688
			relative_y: 0.0624338624338624
		}
	} else if cp == 0xf159 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8756067947646895
			relative_y: 0.0623492063492063
		}
	} else if cp == 0xf175 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9989423585404548
			relative_y: 0.0005288207297726
		}
	} else if cp >= 0xf177 && cp <= 0xf178 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6250661025912215
			relative_y: 0.1877313590692755
		}
	} else if cp == 0xf182 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9998046921689268
		}
	} else if cp == 0xf221 || (cp >= 0xf224 && cp <= 0xf226) || cp == 0xf228 || cp == 0xf22a || cp == 0xf22c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9994854643684076
		}
	} else if cp == 0xf222 || cp == 0xf227 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.8746819883943630
			relative_y: 0.0624017379870223
		}
	} else if cp == 0xf229 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9370837263813853
			relative_y: 0.0624017379870223
		}
	} else if cp == 0xf22b || cp == 0xf22d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6874767744332962
			relative_y: 0.1560043449675557
		}
	} else if (cp >= 0xf255 && cp <= 0xf256) || cp == 0xf25a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9993997599039616
		}
	} else if cp == 0xf257 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7810124049619848
			relative_y: 0.0935945806894186
		}
	} else if cp == 0xf258 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.7498142113988452
			relative_y: 0.1247927742525582
		}
	} else if cp == 0xf25b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.9975006099019084
		}
	} else if cp == 0xf416 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_height: 0.6090604026845637
			relative_y: 0.2119686800894855
		}
	} else if cp == 0xf424 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5019531250000000
			relative_height: 0.5755033557046980
			relative_x: 0.2480468750000000
			relative_y: 0.2108501118568233
		}
	} else if cp == 0xf431 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6240234375000000
			relative_height: 0.7695749440715883
			relative_x: 0.2031250000000000
			relative_y: 0.1420581655480984
		}
	} else if cp == 0xf432 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6718750000000000
			relative_height: 0.7147651006711410
			relative_x: 0.1875000000000000
			relative_y: 0.1610738255033557
		}
	} else if cp == 0xf433 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6240234375000000
			relative_height: 0.7695749440715883
			relative_x: 0.2041015625000000
			relative_y: 0.0883668903803132
		}
	} else if cp == 0xf434 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6718750000000000
			relative_height: 0.7147651006711410
			relative_x: 0.1406250000000000
			relative_y: 0.1599552572706935
		}
	} else if cp == 0xf438 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.2436523437500000
			relative_height: 0.4560546875000000
			relative_x: 0.3813476562500000
			relative_y: 0.2719726562500000
		}
	} else if cp == 0xf43e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5029296875000000
			relative_height: 0.5755033557046980
			relative_x: 0.2500000000000000
			relative_y: 0.2136465324384788
		}
	} else if cp == 0xf443 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7500000000000000
			relative_x: 0.1250000000000000
		}
	} else if (cp >= 0xf444 && cp <= 0xf445) || cp == 0xf4c3 || cp == 0xf51d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5000000000000000
			relative_height: 0.5000000000000000
			relative_x: 0.2500000000000000
			relative_y: 0.2500000000000000
		}
	} else if cp == 0xf44a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.2436523437500000
			relative_height: 0.4560546875000000
			relative_x: 0.3750000000000000
			relative_y: 0.2719726562500000
		}
	} else if cp == 0xf44b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4560546875000000
			relative_height: 0.2436523437500000
			relative_x: 0.2719726562500000
			relative_y: 0.3188476562500000
		}
	} else if cp == 0xf45c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5019531250000000
			relative_height: 0.5749440715883669
			relative_x: 0.2480468750000000
			relative_y: 0.2114093959731544
		}
	} else if cp == 0xf460 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.3593750000000000
			relative_height: 0.6240234375000000
			relative_x: 0.3750000000000000
			relative_y: 0.1884765625000000
		}
	} else if cp == 0xf461 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6237816764132553
			relative_height: 0.9988851727982163
			relative_x: 0.1881091617933723
		}
	} else if cp == 0xf467 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5639648437500000
			relative_height: 0.5649414062500000
			relative_x: 0.2187500000000000
			relative_y: 0.2177734375000000
		}
	} else if cp == 0xf46c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5039062500000000
			relative_height: 0.5771812080536913
			relative_x: 0.2490234375000000
			relative_y: 0.2091722595078300
		}
	} else if cp == 0xf470 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9926757812500000
			relative_height: 0.2690429687500000
			relative_y: 0.6865234375000000
		}
	} else if cp == 0xf476 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8732325694783033
			relative_x: 0.0633837152608484
		}
	} else if cp == 0xf47a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.5843079922027290
			relative_height: 0.9509476031215162
			relative_x: 0.2066276803118908
			relative_y: 0.0234113712374582
		}
	} else if cp >= 0xf47b && cp <= 0xf47c {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.6250000000000000
			relative_height: 0.3593750000000000
			relative_x: 0.1875000000000000
			relative_y: 0.3281250000000000
		}
	} else if cp == 0xf47d {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.3593750000000000
			relative_height: 0.6240234375000000
			relative_x: 0.2656250000000000
			relative_y: 0.1875000000000000
		}
	} else if cp == 0xf47e {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.4560546875000000
			relative_height: 0.2436523437500000
			relative_x: 0.2719726562500000
			relative_y: 0.3750000000000000
		}
	} else if cp == 0xf48b {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7187500000000000
			relative_height: 0.0937500000000000
			relative_x: 0.1250000000000000
			relative_y: 0.4687500000000000
		}
	} else if cp == 0xf493 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8313840155945419
			relative_height: 0.9509476031215162
			relative_x: 0.0843079922027290
			relative_y: 0.0234113712374582
		}
	} else if cp == 0xf49a {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.8727450024378351
			relative_x: 0.0633837152608484
		}
	} else if cp == 0xf4ef || cp == 0xf4f2 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.7142857142857143
			relative_x: 0.1428571428571428
		}
	} else if cp == 0xf4f0 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9642857142857143
			relative_height: 0.7407407407407407
			relative_y: 0.1111111111111111
		}
	} else if cp == 0xf4f1 {
		return Constraint{
			size: .fit_cover1
			height: .icon
			align_horizontal: .center1
			align_vertical: .center1
			relative_width: 0.9642857142857143
			relative_height: 0.7407407407407407
			relative_x: 0.0357142857142857
			relative_y: 0.1111111111111111
		}
	}
	return none
}

// Helper for the large catch-all nerd font icon range check.
fn is_nerd_font_icon(cp u32) bool {
	if (cp >= 0x23fb && cp <= 0x23fe) || cp == 0x2665 || cp == 0x26a1 {
		return true
	}
	if cp == 0x2b58 || (cp >= 0xe000 && cp <= 0xe00a) || (cp >= 0xe200 && cp <= 0xe2a9) {
		return true
	}
	if (cp >= 0xe342 && cp <= 0xe343) || cp == 0xe346 || cp == 0xe348 {
		return true
	}
	if (cp >= 0xe34a && cp <= 0xe34b) || cp == 0xe34e || cp == 0xe350 {
		return true
	}
	if (cp >= 0xe35c && cp <= 0xe35d) || cp == 0xe368 || cp == 0xe36a {
		return true
	}
	if cp == 0xe37c || (cp >= 0xe381 && cp <= 0xe38d) || cp == 0xe3b4 {
		return true
	}
	if (cp >= 0xe3bc && cp <= 0xe3c0) || (cp >= 0xe3c3 && cp <= 0xe3e3) || (cp >= 0xe5fa && cp <= 0xe6b8) {
		return true
	}
	if (cp >= 0xe700 && cp <= 0xe8ef) || cp == 0xea60 || (cp >= 0xea62 && cp <= 0xea7c) {
		return true
	}
	if (cp >= 0xea7e && cp <= 0xea88) || (cp >= 0xea8a && cp <= 0xea8c) || (cp >= 0xea8f && cp <= 0xea98) {
		return true
	}
	if (cp >= 0xeaa3 && cp <= 0xeab3) || (cp >= 0xeab8 && cp <= 0xeac7) || cp == 0xeac9 {
		return true
	}
	if (cp >= 0xeacc && cp <= 0xead3) || (cp >= 0xead7 && cp <= 0xeb09) || (cp >= 0xeb0b && cp <= 0xeb42) {
		return true
	}
	if (cp >= 0xeb44 && cp <= 0xeb4e) || (cp >= 0xeb50 && cp <= 0xeb6d) || (cp >= 0xeb72 && cp <= 0xeb89) {
		return true
	}
	if (cp >= 0xeb8b && cp <= 0xeb99) || (cp >= 0xeb9b && cp <= 0xebd4) || (cp >= 0xebd7 && cp <= 0xec06) {
		return true
	}
	if (cp >= 0xec08 && cp <= 0xec0a) || (cp >= 0xec0d && cp <= 0xec1e) || (cp >= 0xed00 && cp <= 0xedff) {
		return true
	}
	if (cp >= 0xee0c && cp <= 0xefce) || (cp >= 0xf000 && cp <= 0xf004) || (cp >= 0xf006 && cp <= 0xf025) {
		return true
	}
	if (cp >= 0xf028 && cp <= 0xf02a) || (cp >= 0xf02c && cp <= 0xf030) || cp == 0xf034 {
		return true
	}
	if (cp >= 0xf036 && cp <= 0xf043) || cp == 0xf045 || cp == 0xf047 {
		return true
	}
	if (cp >= 0xf053 && cp <= 0xf05f) || cp == 0xf062 || (cp >= 0xf064 && cp <= 0xf076) {
		return true
	}
	if (cp >= 0xf079 && cp <= 0xf07d) || (cp >= 0xf07f && cp <= 0xf088) || (cp >= 0xf08a && cp <= 0xf0a3) {
		return true
	}
	if (cp >= 0xf0a6 && cp <= 0xf0d6) || cp == 0xf0db || (cp >= 0xf0df && cp <= 0xf0ff) {
		return true
	}
	if (cp >= 0xf108 && cp <= 0xf12f) || (cp >= 0xf131 && cp <= 0xf140) || (cp >= 0xf142 && cp <= 0xf152) {
		return true
	}
	if cp == 0xf155 || (cp >= 0xf15a && cp <= 0xf174) || cp == 0xf176 {
		return true
	}
	if (cp >= 0xf179 && cp <= 0xf181) || (cp >= 0xf183 && cp <= 0xf220) || cp == 0xf223 {
		return true
	}
	if (cp >= 0xf22e && cp <= 0xf254) || cp == 0xf259 || (cp >= 0xf25c && cp <= 0xf381) {
		return true
	}
	if (cp >= 0xf400 && cp <= 0xf415) || (cp >= 0xf417 && cp <= 0xf423) || (cp >= 0xf425 && cp <= 0xf430) {
		return true
	}
	if (cp >= 0xf435 && cp <= 0xf437) || (cp >= 0xf439 && cp <= 0xf43d) || (cp >= 0xf43f && cp <= 0xf442) {
		return true
	}
	if (cp >= 0xf446 && cp <= 0xf449) || (cp >= 0xf44c && cp <= 0xf45b) || (cp >= 0xf45d && cp <= 0xf45f) {
		return true
	}
	if (cp >= 0xf462 && cp <= 0xf466) || (cp >= 0xf468 && cp <= 0xf46b) || (cp >= 0xf46d && cp <= 0xf46f) {
		return true
	}
	if (cp >= 0xf471 && cp <= 0xf475) || (cp >= 0xf477 && cp <= 0xf479) || (cp >= 0xf47f && cp <= 0xf48a) {
		return true
	}
	if (cp >= 0xf48c && cp <= 0xf492) || (cp >= 0xf494 && cp <= 0xf499) || (cp >= 0xf49b && cp <= 0xf4c2) {
		return true
	}
	if (cp >= 0xf4c4 && cp <= 0xf4ee) || (cp >= 0xf4f3 && cp <= 0xf51c) || (cp >= 0xf51e && cp <= 0xf533) {
		return true
	}
	if cp >= 0xf0001 && cp <= 0xf1af0 {
		return true
	}
	return false
}

