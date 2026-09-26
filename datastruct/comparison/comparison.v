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
		$for variant in T.variants {
			if old is variant {
				if new is variant {
					old_value := old
					new_value := new
					return deep_equal(old_value, new_value)
				}
				return false
			}
		}
		return false
	} $else $if T is $interface {
		// The sum type arm's variant loop instantiates this for every type
		// V reaches through `is`, including IError; interfaces have no `==`.
		panic('deep_equal: interfaces are not comparable')
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
		$for variant in T.variants {
			if expected is variant {
				if actual is variant {
					expected_value := expected
					actual_value := actual
					expect_approx_equal(expected_value, actual_value)!
					return
				}
				return error('TestExpectedApproxEqual')
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
