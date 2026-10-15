module zigimg

pub enum FloatRenderMode {
	scientific
	decimal
}

pub struct FloatRenderOptions {
pub mut:
	mode      FloatRenderMode = .scientific
	precision ?usize
}

pub fn float_format_buffer_size[T](mode FloatRenderMode) int {
	$if T.unaliased_typ is f32 || T.unaliased_typ is f64 {
		if mode == .scientific { return 53 }
		$if T.unaliased_typ is f32 {
			return 55
		} $else {
			return 347
		}
	} $else {
		$compile_error('float_format_buffer_size requires f32 or f64')
	}
}

// Two u64 limbs supply the exact products used by Source's u128 intermediates.
fn float_ryu_multiply(a u64, b u64) (u64, u64) {
	mask := u64(0xffffffff)
	a0, a1 := a & mask, a >> 32
	b0, b1 := b & mask, b >> 32
	w0 := a0 * b0
	t := a1 * b0 + (w0 >> 32)
	w1 := (t & mask) + a0 * b1
	hi := a1 * b1 + (t >> 32) + (w1 >> 32)
	lo := ((w1 & mask) << 32) | (w0 & mask)
	return hi, lo
}

fn float_ryu_mul_shift(m u64, low u64, high u64, shift int) u64 {
	if shift <= 64 { panic('reached unreachable code') }
	if shift >= 128 { return 0 }
	carry, _ := float_ryu_multiply(m, low)
	mut upper, lower := float_ryu_multiply(m, high)
	mut sum := u64(0)
	if carry > ~u64(0) - lower {
		sum = carry - (~u64(0) - lower) - 1
		upper++
	} else {
		sum = lower + carry
	}
	amount := shift - 64
	if upper >> amount != 0 { panic('integer does not fit in destination type') }
	return (sum >> amount) | (upper << (64 - amount))
}

fn float_ryu_pow5_bits(e int) int {
	return int((u64(e) * u64(163391164108059)) >> 46) + 1
}

fn float_ryu_multiple5(n u64, power int) bool {
	mut value := n
	mut count := 0
	for value > 0 {
		if value % 5 != 0 { return count >= power }
		count++
		value /= 5
	}
	return 0 >= power
}

fn float_ryu_multiple2(n u64, power int) bool {
	return n & ((u64(1) << power) - 1) == 0
}

pub fn float_to_decimal[T](value T) FloatDecimal64 {
	$if T.unaliased_typ is f32 || T.unaliased_typ is f64 {
		mut raw := u64(0)
		mut fractional := 52
		mut exponent_bits := 11
		$if T.unaliased_typ is f32 {
			raw = u64(unsafe { *(&u32(&value)) })
			fractional = 23
			exponent_bits = 8
		} $else {
			raw = unsafe { *(&u64(&value)) }
		}
		bias := (1 << (exponent_bits - 1)) - 1
		sign := raw >> (fractional + exponent_bits) != 0
		fraction := raw & ((u64(1) << fractional) - 1)
		exponent := int((raw >> fractional) & u64((1 << exponent_bits) - 1))
		if exponent == 0 && fraction == 0 {
			return FloatDecimal64{
				mantissa: 0
				exponent: 0
				sign:     sign
			}
		}
		if exponent == (1 << exponent_bits) - 1 {
			return FloatDecimal64{
				mantissa: fraction
				exponent: 2147483647
				sign:     sign
			}
		}
		effective_exponent := if exponent == 0 { 1 } else { exponent }
		e2 := effective_exponent - bias - fractional - 2
		m2 := if exponent == 0 { fraction } else { (u64(1) << fractional) | fraction }
		accept_bounds := m2 & 1 == 0
		mv := 4 * m2
		mm_shift := if fraction != 0 || exponent == 0 { u64(1) } else { u64(0) }
		mut vr := u64(0)
		mut vp := u64(0)
		mut vm := u64(0)
		mut e10 := 0
		mut vm_zeros := false
		mut vr_zeros := false
		if e2 >= 0 {
			q := int((u64(e2) * u64(169464822037455)) >> 49) - if e2 > 3 { 1 } else { 0 }
			e10 = q
			k := 125 + float_ryu_pow5_bits(q) - 1
			i := -e2 + q + k
			low, high := float_ryu_pow5_inv_split[q * 2], float_ryu_pow5_inv_split[q * 2 + 1]
			vr = float_ryu_mul_shift(mv, low, high, i)
			vp = float_ryu_mul_shift(mv + 2, low, high, i)
			vm = float_ryu_mul_shift(mv - 1 - mm_shift, low, high, i)
			if q <= 21 {
				if mv % 5 == 0 {
					vr_zeros = float_ryu_multiple5(mv, q)
				} else if accept_bounds {
					vm_zeros = float_ryu_multiple5(mv - 1 - mm_shift, q)
				} else if float_ryu_multiple5(mv + 2, q) {
					vp--
				}
			}
		} else {
			q := int((u64(-e2) * u64(196742565691928)) >> 48) - if -e2 > 1 { 1 } else { 0 }
			e10 = q + e2
			i := -e2 - q
			k := float_ryu_pow5_bits(i) - 125
			j := q - k
			low, high := float_ryu_pow5_split[i * 2], float_ryu_pow5_split[i * 2 + 1]
			vr = float_ryu_mul_shift(mv, low, high, j)
			vp = float_ryu_mul_shift(mv + 2, low, high, j)
			vm = float_ryu_mul_shift(mv - 1 - mm_shift, low, high, j)
			if q <= 1 {
				vr_zeros = true
				if accept_bounds {
					vm_zeros = mm_shift == 1
				} else {
					vp--
				}
			} else if q < 63 {
				vr_zeros = float_ryu_multiple2(mv, q)
			}
		}
		mut removed := 0
		mut last := u64(0)
		for vp / 10 > vm / 10 {
			vm_zeros = vm_zeros && vm % 10 == 0
			vr_zeros = vr_zeros && last == 0
			last = vr % 10
			vr /= 10
			vp /= 10
			vm /= 10
			removed++
		}
		if vm_zeros {
			for vm % 10 == 0 {
				vr_zeros = vr_zeros && last == 0
				last = vr % 10
				vr /= 10
				vp /= 10
				vm /= 10
				removed++
			}
		}
		if vr_zeros && last == 5 && vr % 2 == 0 { last = 4 }
		up := (vr == vm && (!accept_bounds || !vm_zeros)) || last >= 5
		return FloatDecimal64{
			mantissa: vr + if up { u64(1) } else { u64(0) }
			exponent: e10 + removed
			sign:     sign
		}
	} $else {
		$compile_error('float_to_decimal requires f32 or f64')
	}
}

pub fn render_float[T](mut buffer []u8, value T, options FloatRenderOptions) ![]u8 {
	decimal := float_to_decimal[T](value)
	return match options.mode {
		.scientific { format_float_scientific(mut buffer, decimal, options.precision) }
		.decimal { format_float_decimal(mut buffer, decimal, options.precision) }
	}
}
