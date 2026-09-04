module kitty

fn test_transmission_command() {
	input := 'f=24,s=10,v=20'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Transmission
	v := command.control as Transmission
	assert !v.is_query
	assert v.format_ == .rgb
	assert v.width == 10
	assert v.height == 20
}

fn test_transmission_ignores_m_if_medium_is_not_direct() {
	input := 'a=t,t=t,m=1'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Transmission
	v := command.control as Transmission
	assert v.medium == .temporary_file
	assert !v.more_chunks
}

fn test_transmission_respects_m_if_medium_is_direct() {
	input := 'a=t,t=d,m=1'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Transmission
	v := command.control as Transmission
	assert v.medium == .direct
	assert v.more_chunks
}

fn test_query_command() {
	input := 'i=31,s=1,v=1,a=q,t=d,f=24;QUFBQQ'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Transmission
	v := command.control as Transmission
	assert v.is_query
	assert v.medium == .direct
	assert v.width == 1
	assert v.height == 1
	assert v.image_id == 31
	assert command.data == 'AAAA'.bytes()
}

fn test_display_command() {
	input := 'a=p,U=1,i=31,c=80,r=120'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Display
	v := command.control as Display
	assert v.columns == 80
	assert v.rows == 120
	assert v.image_id == 31
}

fn test_delete_command() {
	input := 'a=d,d=p,x=3,y=4'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is FullDelete
	fd := command.control as FullDelete
	assert fd.kind == .intersect_cell
	assert fd.data is DeleteIntersectCell
	dv := fd.data as DeleteIntersectCell
	assert !dv.delete
	assert dv.x == 3
	assert dv.y == 4
}

fn test_no_control_data() {
	input := ';QUFBQQ'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Transmission
	assert command.data == 'AAAA'.bytes()
}

fn test_invalid_base64_payload() {
	Parser.parse_string(';AA!A') or {
		assert err.msg().contains('InvalidData')
		return
	}
	assert false, 'expected invalid payload data'
}

fn test_ignore_unknown_keys_long() {
	input := 'f=24,s=10,v=20,hello=world'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Transmission
	v := command.control as Transmission
	assert v.format_ == .rgb
	assert v.width == 10
	assert v.height == 20
}

fn test_ignore_very_long_values() {
	// Very long value should overflow and be treated as 0
	input := 'f=24,s=10,v=2000000000000000000000000000000000000000'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Transmission
	v := command.control as Transmission
	assert v.format_ == .rgb
	assert v.width == 10
	// Very long value overflows the accumulator and gets ignored
	assert v.height == 0
}

fn test_response_encode_nothing_without_id_or_image_number() {
	r := Response{}
	assert r.encode() == ''
}

fn test_response_encode_with_only_image_id() {
	r := Response{ id: 4 }
	assert r.encode() == '\x1b_Gi=4;OK\x1b\\'
}

fn test_response_encode_with_only_image_number() {
	r := Response{ image_number: 4 }
	assert r.encode() == '\x1b_GI=4;OK\x1b\\'
}

fn test_response_encode_with_image_id_and_number() {
	r := Response{ id: 12, image_number: 4 }
	assert r.encode() == '\x1b_Gi=12,I=4;OK\x1b\\'
}

fn test_delete_range_command_1() {
	input := 'a=d,d=r,x=3,y=4'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is FullDelete
	fd := command.control as FullDelete
	assert fd.kind == .range
	assert fd.data is DeleteRange
	range_ := fd.data as DeleteRange
	assert !range_.delete
	assert range_.first == 3
	assert range_.last == 4
}

fn test_delete_range_command_2() {
	input := 'a=d,d=R,x=5,y=11'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is FullDelete
	fd := command.control as FullDelete
	assert fd.kind == .range
	assert fd.data is DeleteRange
	range_ := fd.data as DeleteRange
	assert range_.delete
	assert range_.first == 5
	assert range_.last == 11
}

fn test_delete_range_command_3() {
	// x > y should fail
	input := 'a=d,d=R,x=5,y=4'
	Parser.parse_string(input) or { return }
	assert false, 'expected error'
}

fn test_delete_range_command_4() {
	// Missing y should fail
	input := 'a=d,d=R,x=5'
	Parser.parse_string(input) or { return }
	assert false, 'expected error'
}

fn test_delete_range_command_5() {
	// Missing x should fail
	input := 'a=d,d=R,y=5'
	Parser.parse_string(input) or { return }
	assert false, 'expected error'
}

fn test_ensure_large_negative_values() {
	input := 'a=p,i=1,z=-2000000000'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Display
	v := command.control as Display
	assert v.image_id == 1
	assert v.z == -2000000000
}

fn test_ensure_proper_overflow_error_for_u32() {
	input := 'a=p,i=10000000000'
	Parser.parse_string(input) or {
		assert err.msg().contains('Overflow')
		return
	}
	assert false, 'expected overflow error'
}

fn test_ensure_proper_overflow_error_for_i32() {
	input := 'a=p,i=1,z=-9999999999'
	Parser.parse_string(input) or {
		assert err.msg().contains('Overflow')
		return
	}
	assert false, 'expected overflow error'
}

fn test_all_i32_values_z() {
	// 'z' (usually z-axis values)
	input := 'a=p,i=1,z=-1'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Display
	v := command.control as Display
	assert v.image_id == 1
	assert v.z == -1
}

fn test_all_i32_values_h() {
	// 'H' (relative placement, horizontal offset)
	input := 'a=p,i=1,H=-1'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Display
	v := command.control as Display
	assert v.image_id == 1
	assert v.horizontal_offset == -1
}

fn test_all_i32_values_v() {
	// 'V' (relative placement, vertical offset)
	input := 'a=p,i=1,V=-1'
	command := Parser.parse_string(input) or { panic(err) }

	assert command.control is Display
	v := command.control as Display
	assert v.image_id == 1
	assert v.vertical_offset == -1
}
