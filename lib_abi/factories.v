module lib_abi

import strings

// V does not synthesize types during compilation. These factories emit actual
// declarations before compilation, preserving lib/{enum,struct,union}.zig's
// reflection loops and selection rules. Generated C types carry the ABI; V
// declarations refer to them directly rather than copying their layouts.
pub enum Target {
	c
	native
}

pub enum TypeKind {
	scalar
	enumeration
	structure
	union_value
}

pub struct TypeRef {
pub:
	kind   TypeKind
	v_type string
	c_type string
	// Types with a source C declaration can supply their C projection.
	has_c    bool
	c_v_type string
	c_c_type string
	has_cval bool
}

// Capture the declaration checks performed by TaggedUnion's reflection loop.
// V has no nested type declarations, so the source Type.C projection is an
// explicit value; cval presence is reflected from the real native V type.
pub fn reflect_type[T](value T, c_type string, projection ?TypeRef) TypeRef {
	_ = value
	mut kind := TypeKind.scalar
	$if T is $enum { kind = .enumeration }
	$if T is $struct { kind = .structure }
	$if T is $sumtype { kind = .union_value }
	mut has_cval := false
	$for method in T.methods {
		$if method.name == 'cval' { has_cval = true }
	}
	if c := projection {
		return TypeRef{
			kind:     kind
			v_type:   typeof(value).name
			c_type:   c_type
			has_c:    true
			c_v_type: c.v_type
			c_c_type: c.c_type
			has_cval: has_cval
		}
	}
	return TypeRef{
		kind:     kind
		v_type:   typeof(value).name
		c_type:   c_type
		has_cval: has_cval
	}
}

pub struct EnumSpec {
pub:
	target Target
	name   string
	keys   []EnumKey
}

pub struct EnumKey {
pub:
	name    string
	removed bool
}

pub fn enum_factory_keys(target Target, name string, keys []?string) !Generated {
	mut fields := []EnumKey{cap: keys.len}
	for key in keys {
		if value := key {
			fields << EnumKey{
				name: value
			}
		} else {
			fields << EnumKey{
				removed: true
			}
		}
	}
	return enum_factory(EnumSpec{ target: target, name: name, keys: fields })!
}

pub struct StructField {
pub:
	name          string
	typ           TypeRef
	default_value string
	is_comptime   bool
	alignment     u64
}

pub struct StructSpec {
pub:
	target      Target
	name        string
	native_type string
	fields      []StructField
	is_tuple    bool
}

pub struct UnionField {
pub:
	name string
	// V sum types name variants by their type. This supplies the variant
	// corresponding to the source's named union field and explicit enum tag.
	variant string
	typ     TypeRef
	// The original payload itself by default, or its wrapper's value field.
	payload string = 'input'
}

pub struct TaggedUnionSpec {
pub:
	target      Target
	name        string
	native_type string
	tag_type    string
	padding     TypeRef
	fields      []UnionField
}

pub struct Generated {
pub:
	v_declarations string
	c_declarations string
}

fn v_name(name string) string {
	if name in ['type', 'union', 'enum', 'struct', 'match', 'select', 'fn', 'module', 'import',
		'mut', 'pub', 'return', 'in', 'as', 'is', 'map', 'none', 'or', 'lock', 'shared'] {
		return '@' + name
	}
	return name
}

fn c_field(typ string, name string) string {
	if bracket := typ.index('[') {
		return typ[..bracket].trim_space() + ' ' + name + typ[bracket..]
	}
	return typ + ' ' + name
}

fn (typ TypeRef) supports_declarations() bool {
	return typ.kind in [.enumeration, .structure, .union_value]
}

fn upper_first(value string) string {
	if value.len == 0 { return value }
	return value[..1].to_upper() + value[1..]
}

pub fn enum_factory(spec EnumSpec) !Generated {
	mut v := strings.new_builder(128)
	mut c := strings.new_builder(128)
	count := spec.keys.filter(!it.removed).len
	if count == 0 {
		if spec.target == .native { return error('Enum native backing range underflow') }
		// Zig permits an empty exhaustive C enum. C/V reject empty enum
		// declarations, so preserve its int ABI with an alias and no keys.
		return Generated{
			v_declarations: 'pub type ${spec.name} = i32\n'
			c_declarations: 'typedef int ${spec.name};\n'
		}
	}
	// std.math.IntFittingRange(0, fields_i - 1). V's integer storage begins
	// at u8; retaining the exact logical bit count documents that adaptation.
	mut bits := 0
	for (u64(1) << bits) <= u64(count - 1) {
		bits++
	}
	backing := if spec.target == .c {
		'i32'
	} else if bits <= 8 {
		'u8'
	} else if bits <= 16 {
		'u16'
	} else if bits <= 32 {
		'u32'
	} else {
		'u64'
	}
	v.writeln('// Logical source backing bits: ${if spec.target == .c { 32 } else { bits }}.')
	v.writeln('pub enum ${spec.name} as ${backing} {')
	if spec.target == .c { c.writeln('typedef enum ${spec.name} {') }
	mut fields_i := 0
	mut holes := 0
	for key in spec.keys {
		if key.removed {
			if spec.target == .c { holes++ }
			continue
		}
		if key.name.len == 0 { return error('Enum field name is empty') }
		value := fields_i + holes
		v.writeln('\t${v_name(key.name)} = ${value}')
		if spec.target == .c { c.writeln('\t${spec.name}_${key.name} = ${value},') }
		fields_i++
	}
	v.writeln('}\n')
	if spec.target == .c { c.writeln('} ${spec.name};\n') }
	return Generated{
		v_declarations: v.str()
		c_declarations: c.str()
	}
}

pub fn struct_factory(spec StructSpec) !Generated {
	if spec.target == .native {
		return Generated{
			v_declarations: 'pub type ${spec.name} = ${spec.native_type}\n'
		}
	}
	if spec.is_tuple { return error('extern tuples are not supported') }
	mut v := strings.new_builder(128)
	mut c := strings.new_builder(128)
	c.writeln('typedef struct ${spec.name} {')
	v.writeln('pub struct C.${spec.name} {\npub mut:')
	for field in spec.fields {
		if field.is_comptime { return error('extern struct fields cannot be marked comptime') }
		field_name := field.name
		alignment := if field.alignment == 0 { '' } else { 'WITTY_ABI_ALIGN(${field.alignment}) ' }
		c.writeln('\t${alignment}${c_field(field.typ.c_type, field_name)};')
		default_value := if field.default_value.len == 0 { '' } else { ' = ' + field.default_value }
		// Struct preserves the original field type. Nested C projections are
		// selected by TaggedUnion, never by this structural factory.
		v.writeln('\t${v_name(field_name)} ${field.typ.v_type}${default_value}')
	}
	c.writeln('} ${spec.name};\n')
	v.writeln('}\npub type ${spec.name} = C.${spec.name}\n')
	v.writeln('pub const ${spec.name.to_lower()}_is_tuple = ${spec.is_tuple}')
	return Generated{
		v_declarations: v.str()
		c_declarations: c.str()
	}
}

pub fn tagged_union_factory(spec TaggedUnionSpec) !Generated {
	mut v := strings.new_builder(256)
	mut c := strings.new_builder(256)
	v.writeln('pub type ${spec.name}Zig = ${spec.native_type}')
	v.writeln('pub type ${spec.name}Tag = ${spec.tag_type}')
	for field in spec.fields {
		// Source Value(tag) resolves the native payload type, even for C.
		v.writeln('pub type ${spec.name}${upper_first(field.name)}Value = ${field.typ.v_type}')
	}
	if spec.target == .native {
		// The source native target exposes zero-size placeholder types. C's
		// empty-struct extension retains zero size under V's C backend.
		c.writeln('typedef struct ${spec.name}C {} ${spec.name}C;\ntypedef struct ${spec.name}CValue {} ${spec.name}CValue;')
		v.writeln('pub struct C.${spec.name}C {}\npub type ${spec.name}C = C.${spec.name}C\npub struct C.${spec.name}CValue {}\npub type ${spec.name}CValue = C.${spec.name}CValue\n')
		return Generated{
			v_declarations: v.str()
			c_declarations: c.str()
		}
	}
	c.writeln('typedef union ${spec.name}CValue {')
	v.writeln('pub union C.${spec.name}CValue {\npub mut:')
	for field in spec.fields {
		v_type := if field.typ.supports_declarations() && field.typ.has_c {
			field.typ.c_v_type
		} else {
			field.typ.v_type
		}
		c_type := if field.typ.supports_declarations() && field.typ.has_c {
			field.typ.c_c_type
		} else {
			field.typ.c_type
		}
		if c_type == 'void' {
			c.writeln('\tuint8_t ${field.name}[0];')
			v.writeln('\t${v_name(field.name)} [0]u8')
		} else {
			c.writeln('\t${c_field(c_type, field.name)};')
			v.writeln('\t${v_name(field.name)} ${v_type}')
		}
	}
	c.writeln('\t${c_field(spec.padding.c_type, '_padding')};\n} ${spec.name}CValue;')
	v.writeln('\t_padding ${spec.padding.v_type}\n}\npub type ${spec.name}CValue = C.${spec.name}CValue')
	c.writeln('WITTY_ABI_ASSERT(sizeof(${spec.name}CValue) == sizeof(${spec.padding.c_type}), "TaggedUnion CValue size does not match expected fixed size");')
	c.writeln('typedef struct ${spec.name}C {\n\t${spec.tag_type} tag;\n\t${spec.name}CValue value;\n} ${spec.name}C;\n')
	v.writeln('pub struct C.${spec.name}C {\npub mut:\n\ttag ${spec.tag_type}\n\tvalue ${spec.name}CValue\n}\npub type ${spec.name}C = C.${spec.name}C')
	v.writeln('pub fn ${spec.name.to_lower()}_cval(input ${spec.native_type}) ${spec.name}C {\n\tmatch input {')
	for field in spec.fields {
		payload := if field.typ.supports_declarations() && field.typ.has_cval {
			'(${field.payload}).cval()'
		} else {
			field.payload
		}
		value := if field.typ.c_type == 'void' {
			'${spec.name}CValue{}'
		} else {
			'${spec.name}CValue{${v_name(field.name)}: ${payload}}'
		}
		v.writeln('\t\t${field.variant} { return ${spec.name}C{tag: .${v_name(field.name)}, value: ${value}} }')
	}
	v.writeln('\t}\n}\n')
	return Generated{
		v_declarations: v.str()
		c_declarations: c.str()
	}
}

pub struct Schema {
pub:
	module_name string
	native_v    string
	native_c    string
	enums       []EnumSpec
	structs     []StructSpec
	unions      []TaggedUnionSpec
}

pub fn generate(schema Schema, header_path string) !Generated {
	mut v := strings.new_builder(512)
	mut c := strings.new_builder(512)
	v.writeln('// Generated by source-equivalent lib_abi factories.\nmodule ${schema.module_name}\n\n#include "${header_path}"\n')
	c.writeln('#ifndef WITTY_GENERATED_ABI_H\n#define WITTY_GENERATED_ABI_H\n#include <stdint.h>\n#include <stddef.h>\n#ifdef __cplusplus\n#define WITTY_ABI_ALIGN(n) alignas(n)\n#define WITTY_ABI_ASSERT(c,m) static_assert(c,m)\n#else\n#define WITTY_ABI_ALIGN(n) _Alignas(n)\n#define WITTY_ABI_ASSERT(c,m) _Static_assert(c,m)\n#endif\n')
	v.writeln(schema.native_v)
	c.writeln(schema.native_c)
	for spec in schema.enums {
		result := enum_factory(spec)!
		v.write_string(result.v_declarations)
		c.write_string(result.c_declarations)
	}
	for spec in schema.structs {
		result := struct_factory(spec)!
		v.write_string(result.v_declarations)
		c.write_string(result.c_declarations)
	}
	for spec in schema.unions {
		result := tagged_union_factory(spec)!
		v.write_string(result.v_declarations)
		c.write_string(result.c_declarations)
	}
	c.writeln('#endif')
	return Generated{
		v_declarations: v.str()
		c_declarations: c.str()
	}
}
