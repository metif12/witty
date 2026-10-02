module lib_abi

struct ReflectionNested {
	value u32
}

fn (value ReflectionNested) cval() u32 {
	return value.value
}

enum ReflectionEnum {
	value
}
type ReflectionUnion = ReflectionNested | u32

fn test_reflect_type_matches_source_declaration_kinds() {
	projection := TypeRef{
		v_type: 'u32'
		c_type: 'uint32_t'
	}
	scalar := reflect_type(u32(1), 'uint32_t', projection)
	assert scalar.kind == .scalar
	assert !scalar.supports_declarations()
	nested := reflect_type(ReflectionNested{}, 'NativeNested', projection)
	assert nested.kind == .structure
	assert nested.has_c && nested.has_cval
	assert nested.c_v_type == 'u32'
	assert reflect_type(ReflectionEnum.value, 'Enum', none).kind == .enumeration
	assert reflect_type(ReflectionUnion(u32(1)), 'Union', none).kind == .union_value
}

fn test_optional_keys_preserve_c_holes_and_compact_native_values() {
	mut keys := []?string{}
	keys << ?string('a')
	keys << ?string(none)
	keys << ?string('b')
	c := enum_factory_keys(.c, 'Tag', keys) or { panic(err) }
	native := enum_factory_keys(.native, 'Tag', keys) or { panic(err) }
	assert c.v_declarations.contains('b = 2')
	assert native.v_declarations.contains('b = 1')
	assert native.v_declarations.contains('Logical source backing bits: 1')
}

fn test_struct_keeps_native_field_type_instead_of_nested_c_projection() {
	result := struct_factory(StructSpec{
		target: .c
		name:   'Wrapper'
		fields: [
			StructField{
				name: 'nested'
				typ:  TypeRef{
					kind:     .structure
					v_type:   'NativeNested'
					c_type:   'NativeNested'
					has_c:    true
					c_v_type: 'NestedC'
					c_c_type: 'NestedC'
				}
			},
		]
	}) or { panic(err) }
	assert result.c_declarations.contains('NativeNested nested;')
	assert result.v_declarations.contains('nested NativeNested')
}

fn test_struct_matches_source_compiler_rejections_for_extern_fields() {
	if _ := struct_factory(StructSpec{ target: .c, name: 'Tuple', is_tuple: true }) { assert false
	 }
	if _ := struct_factory(StructSpec{
		target: .c
		name:   'Comptime'
		fields: [StructField{ name: 'constant', is_comptime: true }]
	})
	{ assert false
	 }
	result := struct_factory(StructSpec{
		target:      .native
		name:        'Native'
		native_type: 'Tuple'
		is_tuple:    true
		fields:      [StructField{ name: 'constant', is_comptime: true }]
	}) or { panic(err) }
	assert result.v_declarations == 'pub type Native = Tuple\n'
}
