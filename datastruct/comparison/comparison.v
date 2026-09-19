module comparison

import math

// deep_equal recursively compares the same set of value categories as
// Ghostty's deepEqual helper. Structs may override the recursive comparison
// with an `equal` method.
pub fn deep_equal[T](old T, new T) bool {
	$if T.unaliased_typ is string {
		return old == new
	} $else $if T is $option {
		return optional_deep_equal(old, new)
	} $else $if T is $array {
		if old.len != new.len {
			return false
		}
		for i in 0 .. old.len {
			if !deep_equal(old[i], new[i]) {
				return false
			}
		}
		return true
	} $else $if T is $struct {
		$for method in T.methods {
			$if method.name == 'equal' {
				return old.$method(new)
			}
		}
		$for field in T.fields {
			$if field.is_map {
				if old.$(field.name) != new.$(field.name) {
					return false
				}
			} $else $if field.is_option {
				if !optional_deep_equal(old.$(field.name), new.$(field.name)) {
					return false
				}
			} $else {
				old_field := old.$(field.name)
				new_field := new.$(field.name)
				if !deep_equal(old_field, new_field) {
					return false
				}
			}
		}
		return true
	} $else $if T is $sumtype {
		$for method in T.methods {
			$if method.name == 'equal' {
				return old.$method(new)
			}
		}
		// V's sum-type equality first compares the active tag and then the
		// payload, which is the same recursive union behavior used upstream.
		return old == new
	} $else {
		return old == new
	}
}

// Keeping the optional in the parameter type lets V specialize the payload
// before compiling the `or` expressions. This is equivalent to deepEqual's
// optional child recursion and avoids treating the generic T itself as the
// optional payload.
fn optional_deep_equal[T](old ?T, new ?T) bool {
	old_value := old or { return new == none }
	new_value := new or { return false }
	return deep_equal(old_value, new_value)
}

// expect_approx_equal recursively checks approximate relative equality for
// floating-point values and exact deep equality for all other leaves. Its
// float tolerance is sqrt(machine epsilon), matching Ghostty.
pub fn expect_approx_equal[T](expected T, actual T) ! {
	$if T is f32 {
		if !approx_equal_relative(f64(expected), f64(actual), 0.00034526698300124393) {
			return error('TestExpectedApproxEqual')
		}
	} $else $if T is f64 {
		if !approx_equal_relative(expected, actual, math.sqrt(math.epsilon)) {
			return error('TestExpectedApproxEqual')
		}
	} $else $if T is $option {
		optional_expect_approx_equal(expected, actual)!
	} $else $if T is $array {
		if expected.len != actual.len {
			return error('TestExpectedApproxEqual')
		}
		for i in 0 .. expected.len {
			expect_approx_equal(expected[i], actual[i])!
		}
	} $else $if T is $struct {
		$for field in T.fields {
			expected_field := expected.$(field.name)
			actual_field := actual.$(field.name)
			expect_approx_equal(expected_field, actual_field)!
		}
	} $else $if T is $sumtype {
		if expected == actual {
			return
		}
		$for variant in expected.variants {
			if expected is variant {
				if !(actual is variant) {
					return error('TestExpectedApproxEqual')
				}
				$if variant.typ is f32 {
					expect_approx_equal(expected as f32, actual as f32)!
				} $else $if variant.typ is f64 {
					expect_approx_equal(expected as f64, actual as f64)!
				} $else {
					return error('TestExpectedApproxEqual')
				}
				return
			}
		}
		return error('TestExpectedApproxEqual')
	} $else {
		if !deep_equal(expected, actual) {
			return error('TestExpectedApproxEqual')
		}
	}
}

fn optional_expect_approx_equal[T](expected ?T, actual ?T) ! {
	expected_value := expected or {
		if _actual := actual {
			return error('TestExpectedApproxEqual')
		} else {
			return
		}
	}
	actual_value := actual or { return error('TestExpectedApproxEqual') }
	expect_approx_equal(expected_value, actual_value)!
}

fn approx_equal_relative(expected f64, actual f64, tolerance f64) bool {
	if expected == actual {
		return true
	}
	difference := math.abs(expected - actual)
	scale := math.max(math.abs(expected), math.abs(actual))
	return difference <= scale * tolerance
}
