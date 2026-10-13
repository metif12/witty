module main

import os
import strings
import zigimg as p

fn scalar(raw u32) f32 {
	return unsafe { *(&f32(&raw)) }
}

fn raw(value f32) u32 {
	return unsafe { *(&u32(&value)) }
}

fn params(kind int) p.GammaFunctionsParameters {
	if kind == 0 { return p.GammaFunctionsParameters{} }
	v := raw_params[kind]
	return p.GammaFunctionsParameters{
		alpha:            scalar(v[0])
		beta:             scalar(v[1])
		delta:            scalar(v[2])
		gamma:            scalar(v[3])
		transition_point: scalar(v[4])
		display_gamma:    scalar(v[5])
	}
}

fn record(mut out strings.Builder, value p.GammaFunctionsParameters) {
	$for field in p.GammaFunctionsParameters.fields {
		v := value.$(field.name)
		out.write_string('${raw(v)},')
	}
	out.write_string('|')
}

fn changed(value p.GammaFunctionsParameters, field_index int, replacement u32) p.GammaFunctionsParameters {
	mut result := value
	mut index := 0
	$for field in p.GammaFunctionsParameters.fields {
		if index == field_index { result.$(field.name) = scalar(replacement) }
		index++
	}
	return result
}

fn methods(mut out strings.Builder, nonlinear p.NonLinearGammaTransferFunctions, curve p.CurveGammaTransferFunctions, value f32, initial p.GammaFunctionsParameters) {
	results := [nonlinear.to_gamma(value), nonlinear.to_gamma_fast(value),
		nonlinear.to_linear(value), nonlinear.to_linear_fast(value),
		curve.to_gamma(value), curve.to_gamma_fast(value), curve.to_linear(value),
		curve.to_linear_fast(value), p.apply_gamma(value, initial.gamma),
		p.remove_gamma(value, initial.gamma), p.apply_gamma(value, initial.display_gamma),
		p.remove_gamma(value, initial.display_gamma)]
	for result in results {
		bits := raw(result)
		canonical := if bits & 0x7fffffff > 0x7f800000 { u32(0x7fc00000) } else { bits }
		out.write_string('${canonical},')
	}
	out.write_string('|')
}

fn main() {
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut out := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		initial := params(fields[0].int())
		nonlinear := p.NonLinearGammaTransferFunctions{
			parameters: initial
		}
		curve := p.CurveGammaTransferFunctions{
			gamma: initial.gamma
		}
		mut original := initial
		mut copy := original
		mut returned := original
		operation := fields[1].int()
		field := fields[2].int()
		replacement := fields[3].u32()
		value := scalar(fields[4].u32())
		match operation {
			0 {}
			1 {
				copy = changed(copy, field, replacement)
			}
			2 {
				original = changed(original, field, replacement)
			}
			3 {
				copy = changed(copy, field, replacement)
				returned = changed(copy, field, raw(initial.alpha))
				copy = original
			}
			else {
				panic('invalid operation')
			}
		}

		record(mut out, original)
		record(mut out, copy)
		record(mut out, returned)
		methods(mut out, nonlinear, curve, value, initial)
		copied_nonlinear := nonlinear
		copied_curve := curve
		methods(mut out, copied_nonlinear, copied_curve, value, initial)
		out.write_string('\n')
	}
	print(out.str())
}
