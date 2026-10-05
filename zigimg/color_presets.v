module zigimg

// CIE 1931 2-degree white points.
pub const white_point_a = CIExyY{
	x: 0.44758
	y: 0.40745
}
pub const white_point_b = CIExyY{
	x: 0.34842
	y: 0.35161
}
pub const white_point_c = CIExyY{
	x: 0.31006
	y: 0.31616
}
pub const white_point_d50 = CIExyY{
	x: 0.34567
	y: 0.35850
}
pub const white_point_d55 = CIExyY{
	x: 0.33242
	y: 0.34743
}
pub const white_point_d65 = CIExyY{
	x: 0.31271
	y: 0.32902
}
pub const white_point_d75 = CIExyY{
	x: 0.29902
	y: 0.31485
}
pub const white_point_d93 = CIExyY{
	x: 0.28315
	y: 0.29711
}
pub const white_point_e = CIExyY{
	x: 0.33333
	y: 0.33333
}
pub const white_point_f1 = CIExyY{
	x: 0.31310
	y: 0.33727
}
pub const white_point_f2 = CIExyY{
	x: 0.37208
	y: 0.37529
}
pub const white_point_f3 = CIExyY{
	x: 0.40910
	y: 0.39430
}
pub const white_point_f4 = CIExyY{
	x: 0.44018
	y: 0.40329
}
pub const white_point_f5 = CIExyY{
	x: 0.31379
	y: 0.34531
}
pub const white_point_f6 = CIExyY{
	x: 0.37790
	y: 0.38835
}
pub const white_point_f7 = CIExyY{
	x: 0.31292
	y: 0.32933
}
pub const white_point_f8 = CIExyY{
	x: 0.34588
	y: 0.35875
}
pub const white_point_f9 = CIExyY{
	x: 0.37417
	y: 0.37281
}
pub const white_point_f10 = CIExyY{
	x: 0.34609
	y: 0.35986
}
pub const white_point_f11 = CIExyY{
	x: 0.38052
	y: 0.37713
}
pub const white_point_f12 = CIExyY{
	x: 0.43695
	y: 0.40441
}
pub const white_point_led_b1 = CIExyY{
	x: 0.4560
	y: 0.4078
}
pub const white_point_led_b2 = CIExyY{
	x: 0.4357
	y: 0.4012
}
pub const white_point_led_b3 = CIExyY{
	x: 0.3756
	y: 0.3723
}
pub const white_point_led_b4 = CIExyY{
	x: 0.3422
	y: 0.3502
}
pub const white_point_led_b5 = CIExyY{
	x: 0.3118
	y: 0.3236
}
pub const white_point_led_bh1 = CIExyY{
	x: 0.4474
	y: 0.4066
}
pub const white_point_led_rgb1 = CIExyY{
	x: 0.4557
	y: 0.4211
}
pub const white_point_led_v1 = CIExyY{
	x: 0.4560
	y: 0.4548
}
pub const white_point_led_v2 = CIExyY{
	x: 0.3781
	y: 0.3781
}

pub struct WhitePoints {
pub:
	a        CIExyY = white_point_a
	b        CIExyY = white_point_b
	c        CIExyY = white_point_c
	d50      CIExyY = white_point_d50
	d55      CIExyY = white_point_d55
	d65      CIExyY = white_point_d65
	d75      CIExyY = white_point_d75
	d93      CIExyY = white_point_d93
	e        CIExyY = white_point_e
	f1       CIExyY = white_point_f1
	f2       CIExyY = white_point_f2
	f3       CIExyY = white_point_f3
	f4       CIExyY = white_point_f4
	f5       CIExyY = white_point_f5
	f6       CIExyY = white_point_f6
	f7       CIExyY = white_point_f7
	f8       CIExyY = white_point_f8
	f9       CIExyY = white_point_f9
	f10      CIExyY = white_point_f10
	f11      CIExyY = white_point_f11
	f12      CIExyY = white_point_f12
	led_b1   CIExyY = white_point_led_b1
	led_b2   CIExyY = white_point_led_b2
	led_b3   CIExyY = white_point_led_b3
	led_b4   CIExyY = white_point_led_b4
	led_b5   CIExyY = white_point_led_b5
	led_bh1  CIExyY = white_point_led_bh1
	led_rgb1 CIExyY = white_point_led_rgb1
	led_v1   CIExyY = white_point_led_v1
	led_v2   CIExyY = white_point_led_v2
}

pub const bt601_ntsc = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.630
		y: 0.340
	}
	green:          CIExyY{
		x: 0.310
		y: 0.595
	}
	blue:           CIExyY{
		x: 0.155
		y: 0.070
	}
	white:          white_point_d65
	to_gamma:       rec601_to_gamma
	to_gamma_fast:  rec601_to_gamma_fast
	to_linear:      rec601_to_linear
	to_linear_fast: rec601_to_linear_fast
})

pub const bt601_pal = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.640
		y: 0.330
	}
	green:          CIExyY{
		x: 0.290
		y: 0.600
	}
	blue:           CIExyY{
		x: 0.150
		y: 0.060
	}
	white:          white_point_d65
	to_gamma:       rec601_to_gamma
	to_gamma_fast:  rec601_to_gamma_fast
	to_linear:      rec601_to_linear
	to_linear_fast: rec601_to_linear_fast
})

pub const bt709 = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.6400
		y: 0.3300
	}
	green:          CIExyY{
		x: 0.3000
		y: 0.6000
	}
	blue:           CIExyY{
		x: 0.1500
		y: 0.0600
	}
	white:          white_point_d65
	to_gamma:       rec709_to_gamma
	to_gamma_fast:  rec709_to_gamma_fast
	to_linear:      rec709_to_linear
	to_linear_fast: rec709_to_linear_fast
})

pub const srgb = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.6400
		y: 0.3300
	}
	green:          CIExyY{
		x: 0.3000
		y: 0.6000
	}
	blue:           CIExyY{
		x: 0.1500
		y: 0.0600
	}
	white:          white_point_d65
	to_gamma:       srgb_to_gamma
	to_gamma_fast:  srgb_to_gamma_fast
	to_linear:      srgb_to_linear
	to_linear_fast: srgb_to_linear_fast
})

pub const dcip3_display = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.680
		y: 0.320
	}
	green:          CIExyY{
		x: 0.265
		y: 0.690
	}
	blue:           CIExyY{
		x: 0.150
		y: 0.060
	}
	white:          white_point_d65
	to_gamma:       srgb_to_gamma
	to_gamma_fast:  srgb_to_gamma_fast
	to_linear:      srgb_to_linear
	to_linear_fast: srgb_to_linear_fast
})

pub const dcip3_theater = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.680
		y: 0.320
	}
	green:          CIExyY{
		x: 0.265
		y: 0.690
	}
	blue:           CIExyY{
		x: 0.150
		y: 0.060
	}
	white:          CIExyY{
		x: 0.314
		y: 0.351
	}
	to_gamma:       dcip3_to_gamma
	to_gamma_fast:  dcip3_to_gamma_fast
	to_linear:      dcip3_to_linear
	to_linear_fast: dcip3_to_linear_fast
})

pub const dcip3_aces = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.680
		y: 0.320
	}
	green:          CIExyY{
		x: 0.265
		y: 0.690
	}
	blue:           CIExyY{
		x: 0.150
		y: 0.060
	}
	white:          CIExyY{
		x: 0.32168
		y: 0.33767
	}
	to_gamma:       dcip3_to_gamma
	to_gamma_fast:  dcip3_to_gamma_fast
	to_linear:      dcip3_to_linear
	to_linear_fast: dcip3_to_linear_fast
})

pub const bt2020 = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.708
		y: 0.292
	}
	green:          CIExyY{
		x: 0.170
		y: 0.797
	}
	blue:           CIExyY{
		x: 0.131
		y: 0.046
	}
	white:          white_point_d65
	to_gamma:       bt2020_to_gamma
	to_gamma_fast:  bt2020_to_gamma_fast
	to_linear:      bt2020_to_linear
	to_linear_fast: bt2020_to_linear_fast
})

pub const adobe_rgb = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.6400
		y: 0.3300
	}
	green:          CIExyY{
		x: 0.2100
		y: 0.7100
	}
	blue:           CIExyY{
		x: 0.1500
		y: 0.0600
	}
	white:          white_point_d65
	to_gamma:       adobe_rgb_to_gamma
	to_gamma_fast:  adobe_rgb_to_gamma_fast
	to_linear:      adobe_rgb_to_linear
	to_linear_fast: adobe_rgb_to_linear_fast
})

pub const adobe_wide_gamut_rgb = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.7347
		y: 0.2653
	}
	green:          CIExyY{
		x: 0.1152
		y: 0.8264
	}
	blue:           CIExyY{
		x: 0.1566
		y: 0.0177
	}
	white:          white_point_d50
	to_gamma:       adobe_rgb_to_gamma
	to_gamma_fast:  adobe_rgb_to_gamma_fast
	to_linear:      adobe_rgb_to_linear
	to_linear_fast: adobe_rgb_to_linear_fast
})

pub const prophoto_rgb = RgbColorspace.init(RgbColorspaceInitArgs{
	red:            CIExyY{
		x: 0.734699
		y: 0.265301
	}
	green:          CIExyY{
		x: 0.159597
		y: 0.840403
	}
	blue:           CIExyY{
		x: 0.036598
		y: 0.000105
	}
	white:          white_point_d50
	to_gamma:       prophoto_rgb_to_gamma
	to_gamma_fast:  prophoto_rgb_to_gamma_fast
	to_linear:      prophoto_rgb_to_linear
	to_linear_fast: prophoto_rgb_to_linear_fast
})

pub struct DCIP3 {
pub:
	display RgbColorspace = dcip3_display
	theater RgbColorspace = dcip3_theater
	aces    RgbColorspace = dcip3_aces
}
