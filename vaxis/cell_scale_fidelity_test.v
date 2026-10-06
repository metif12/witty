module vaxis

fn test_cell_scale_mutation_preserves_independent_packed_fields_and_copies() {
	mut original := CellScale.init(7, 0, 15, .center)
	copy := original
	original.set_scale(0)
	assert original.scale() == 0 && original.numerator() == 0
	assert original.denominator() == 15 && original.vertical_alignment() == .center
	original.set_numerator(15)
	original.set_denominator(0)
	original.set_vertical_alignment(.bottom)
	assert original.bits() == u16((15 << 3) | (1 << 11))
	assert original.eql(CellScale.init(0, 15, 0, .bottom))
	assert copy.eql(CellScale.init(7, 0, 15, .center))
	assert !original.eql(copy)
}

fn test_cell_scale_raw_alignment_is_distinct_from_numeric_enum_construction() {
	mut raw := CellScale.from_bits(0x1fff)
	assert raw.scale() == 7 && raw.numerator() == 15 && raw.denominator() == 15
	assert u8(raw.vertical_alignment()) == 3
	raw.set_scale(1)
	assert raw.bits() == 0x1ff9
	mut other := CellScale{}
	other.set_vertical_alignment(raw.vertical_alignment())
	assert other.bits() == 0x1889
	assert other.eql(CellScale.init(1, 1, 1, raw.vertical_alignment()))
	assert VerticalAlignment.from_int(0) == .top
	assert VerticalAlignment.from_int(1) == .bottom
	assert VerticalAlignment.from_int(2) == .center
}

fn test_cell_scale_embedded_cell_mutation_and_default_round_trip() {
	mut cell := Cell{}
	copy := cell
	cell.scale.set_numerator(13)
	cell.scale.set_denominator(7)
	cell.scale.set_vertical_alignment(.center)
	assert cell.scale.eql(CellScale.init(1, 13, 7, .center))
	assert copy.scale.eql(CellScale{})
	assert CellScale{}.bits() == 0x89
	assert CellScale.from_bits(CellScale{}.bits()).eql(CellScale{})
}
