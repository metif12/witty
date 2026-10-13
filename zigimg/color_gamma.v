module zigimg

pub fn apply_gamma(value f32, gamma f32) f32 {
	return color_pow_f32(value, f32(1) / gamma)
}

pub fn remove_gamma(value f32, gamma f32) f32 {
	return color_pow_f32(value, gamma)
}

pub struct GammaFunctionsParameters {
pub mut:
	alpha            f32
	beta             f32
	delta            f32
	gamma            f32 = 1
	transition_point f32
	display_gamma    f32 = 1
}

// V represents the source's compile-time namespace factory as a typed value.
pub struct NonLinearGammaTransferFunctions {
pub:
	parameters GammaFunctionsParameters @[required]
}

pub fn (transfer NonLinearGammaTransferFunctions) to_gamma(value f32) f32 {
	params := transfer.parameters
	if value <= params.beta { return value * params.delta }
	product := params.alpha * color_pow_f32(value, f32(1) / params.gamma)
	return product - (params.alpha - f32(1))
}

pub fn (transfer NonLinearGammaTransferFunctions) to_gamma_fast(value f32) f32 {
	return apply_gamma(value, transfer.parameters.display_gamma)
}

pub fn (transfer NonLinearGammaTransferFunctions) to_linear(value f32) f32 {
	params := transfer.parameters
	if value <= params.transition_point { return value / params.delta }
	return color_pow_f32((value + (params.alpha - f32(1))) / params.alpha, params.gamma)
}

pub fn (transfer NonLinearGammaTransferFunctions) to_linear_fast(value f32) f32 {
	return remove_gamma(value, transfer.parameters.display_gamma)
}

pub struct CurveGammaTransferFunctions {
pub:
	gamma f32 @[required]
}

pub fn (transfer CurveGammaTransferFunctions) to_gamma(value f32) f32 {
	return apply_gamma(value, transfer.gamma)
}

pub fn (transfer CurveGammaTransferFunctions) to_gamma_fast(value f32) f32 {
	return apply_gamma(value, transfer.gamma)
}

pub fn (transfer CurveGammaTransferFunctions) to_linear(value f32) f32 {
	return remove_gamma(value, transfer.gamma)
}

pub fn (transfer CurveGammaTransferFunctions) to_linear_fast(value f32) f32 {
	return remove_gamma(value, transfer.gamma)
}

pub const srgb_transfer_functions = NonLinearGammaTransferFunctions{
	parameters: GammaFunctionsParameters{
		alpha:            f32(1.055)
		beta:             f32(0.0031308)
		delta:            f32(12.92)
		gamma:            f32(12.0 / 5.0)
		transition_point: f32(0.04045)
		display_gamma:    f32(2.2)
	}
}

pub const rec601_transfer_functions = NonLinearGammaTransferFunctions{
	parameters: GammaFunctionsParameters{
		alpha:            f32(1.099)
		beta:             f32(0.004)
		delta:            f32(4.5)
		gamma:            f32(20.0 / 9.0)
		transition_point: f32(0.018)
		display_gamma:    f32(2.2)
	}
}

pub const rec709_transfer_functions = NonLinearGammaTransferFunctions{
	parameters: GammaFunctionsParameters{
		alpha:            f32(1.099)
		beta:             f32(0.004)
		delta:            f32(4.5)
		gamma:            f32(20.0 / 9.0)
		transition_point: f32(0.018)
		display_gamma:    f32(2.2)
	}
}

pub const bt2020_transfer_functions = NonLinearGammaTransferFunctions{
	parameters: GammaFunctionsParameters{
		alpha:            f32(1.0993)
		beta:             f32(0.004)
		delta:            f32(4.5)
		gamma:            f32(20.0 / 9.0)
		transition_point: f32(0.0181)
		display_gamma:    f32(2.2)
	}
}

pub const prophoto_rgb_transfer_functions = NonLinearGammaTransferFunctions{
	parameters: GammaFunctionsParameters{
		alpha:            f32(1)
		beta:             f32(0.001953125)
		delta:            f32(16)
		gamma:            f32(9.0 / 5.0)
		transition_point: f32(0.031248)
		display_gamma:    f32(1.8)
	}
}

pub const dcip3_transfer_functions = CurveGammaTransferFunctions{
	gamma: f32(13.0 / 5.0)
}

pub const adobe_rgb_transfer_functions = CurveGammaTransferFunctions{
	gamma: f32(563.0 / 256.0)
}

fn srgb_to_gamma(value f32) f32 {
	return srgb_transfer_functions.to_gamma(value)
}

fn srgb_to_gamma_fast(value f32) f32 {
	return srgb_transfer_functions.to_gamma_fast(value)
}

fn srgb_to_linear(value f32) f32 {
	return srgb_transfer_functions.to_linear(value)
}

fn srgb_to_linear_fast(value f32) f32 {
	return srgb_transfer_functions.to_linear_fast(value)
}

fn rec601_to_gamma(value f32) f32 {
	return rec601_transfer_functions.to_gamma(value)
}

fn rec601_to_gamma_fast(value f32) f32 {
	return rec601_transfer_functions.to_gamma_fast(value)
}

fn rec601_to_linear(value f32) f32 {
	return rec601_transfer_functions.to_linear(value)
}

fn rec601_to_linear_fast(value f32) f32 {
	return rec601_transfer_functions.to_linear_fast(value)
}

fn rec709_to_gamma(value f32) f32 {
	return rec709_transfer_functions.to_gamma(value)
}

fn rec709_to_gamma_fast(value f32) f32 {
	return rec709_transfer_functions.to_gamma_fast(value)
}

fn rec709_to_linear(value f32) f32 {
	return rec709_transfer_functions.to_linear(value)
}

fn rec709_to_linear_fast(value f32) f32 {
	return rec709_transfer_functions.to_linear_fast(value)
}

fn bt2020_to_gamma(value f32) f32 {
	return bt2020_transfer_functions.to_gamma(value)
}

fn bt2020_to_gamma_fast(value f32) f32 {
	return bt2020_transfer_functions.to_gamma_fast(value)
}

fn bt2020_to_linear(value f32) f32 {
	return bt2020_transfer_functions.to_linear(value)
}

fn bt2020_to_linear_fast(value f32) f32 {
	return bt2020_transfer_functions.to_linear_fast(value)
}

fn prophoto_rgb_to_gamma(value f32) f32 {
	return prophoto_rgb_transfer_functions.to_gamma(value)
}

fn prophoto_rgb_to_gamma_fast(value f32) f32 {
	return prophoto_rgb_transfer_functions.to_gamma_fast(value)
}

fn prophoto_rgb_to_linear(value f32) f32 {
	return prophoto_rgb_transfer_functions.to_linear(value)
}

fn prophoto_rgb_to_linear_fast(value f32) f32 {
	return prophoto_rgb_transfer_functions.to_linear_fast(value)
}

fn dcip3_to_gamma(value f32) f32 {
	return dcip3_transfer_functions.to_gamma(value)
}

fn dcip3_to_gamma_fast(value f32) f32 {
	return dcip3_transfer_functions.to_gamma_fast(value)
}

fn dcip3_to_linear(value f32) f32 {
	return dcip3_transfer_functions.to_linear(value)
}

fn dcip3_to_linear_fast(value f32) f32 {
	return dcip3_transfer_functions.to_linear_fast(value)
}

fn adobe_rgb_to_gamma(value f32) f32 {
	return adobe_rgb_transfer_functions.to_gamma(value)
}

fn adobe_rgb_to_gamma_fast(value f32) f32 {
	return adobe_rgb_transfer_functions.to_gamma_fast(value)
}

fn adobe_rgb_to_linear(value f32) f32 {
	return adobe_rgb_transfer_functions.to_linear(value)
}

fn adobe_rgb_to_linear_fast(value f32) f32 {
	return adobe_rgb_transfer_functions.to_linear_fast(value)
}
