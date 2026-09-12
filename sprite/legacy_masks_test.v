module sprite

fn test_smooth_mosaic_packed_layout() {
	assert sizeof(SmoothMosaic) == 2

	outline := smooth_mosaic_from('###', '###', '###', '###')
	assert outline.value == 0x0129
	assert outline.tl()
	assert !outline.ul()
	assert !outline.ll()
	assert outline.bl()
	assert !outline.bc()
	assert outline.br()
	assert !outline.lr()
	assert !outline.ur()
	assert outline.tr()
	assert !outline.tc()

	first := smooth_mosaic_from('...', '...', '#..', '##.')
	assert first.value == 0x001c
}

fn test_sextants_packed_layout() {
	assert sizeof(Sextants) == 1
	all := Sextants.from_int(0x3f)
	assert all.tl()
	assert all.tr()
	assert all.ml()
	assert all.mr()
	assert all.bl()
	assert all.br()

	assert Sextants.from_int(0x01).tl()
	assert Sextants.from_int(0x02).tr()
	assert Sextants.from_int(0x04).ml()
	assert Sextants.from_int(0x08).mr()
	assert Sextants.from_int(0x10).bl()
	assert Sextants.from_int(0x20).br()
}

fn test_octant_packed_lookup_layout() {
	assert sizeof(Octant) == 1
	assert octant_table.len == int(octant_max - octant_min + 1)
	assert octant_table[0].value == 0x04
	assert octant_table[octant_table.len - 1].value == 0xfe

	all := Octant.from_int(0xff)
	assert all.o1()
	assert all.o2()
	assert all.o3()
	assert all.o4()
	assert all.o5()
	assert all.o6()
	assert all.o7()
	assert all.o8()
}
