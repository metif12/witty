module comparison

enum TestColor {
	red
	green
	blue
}

struct TestPoint {
	x int
	y int
}

struct TestOuter {
	point TestPoint
	name  string
	port  ?int
}

struct TestCustomOuter {
	custom TestCustom
}

struct TestCustom {
	value int
}

fn (self TestCustom) equal(other TestCustom) bool {
	return self.value % 10 == other.value % 10
}

struct ApproxMetrics {
	width  f32
	height f64
	count  int
}

type TestValue = f32 | int | string

type TestEqualValue = int | string

fn (self TestEqualValue) equal(other TestEqualValue) bool {
	if self is int && other is int {
		return self % 10 == (other as int) % 10
	}
	if self is string && other is string {
		return self.len == (other as string).len
	}
	return false
}

fn test_deep_equal_scalars_and_strings() {
	assert deep_equal(true, true)
	assert !deep_equal(true, false)
	assert deep_equal(i32(42), i32(42))
	assert !deep_equal(i32(42), i32(43))
	assert deep_equal(f64(3.14159), f64(3.14159))
	assert !deep_equal(f64(3.14159), f64(3.14158))
	assert deep_equal(TestColor.red, TestColor.red)
	assert !deep_equal(TestColor.red, TestColor.green)
	assert deep_equal('hello', 'hello')
	assert !deep_equal('hello', 'world')
}

fn test_deep_equal_options_arrays_and_structs() {
	assert deep_equal(?int(none), ?int(none))
	assert deep_equal(?int(42), ?int(42))
	assert !deep_equal(?int(none), ?int(42))
	assert !deep_equal(?int(42), ?int(43))
	assert deep_equal(?TestPoint(TestPoint{ x: 1, y: 2 }), ?TestPoint(TestPoint{ x: 1, y: 2 }))
	assert !deep_equal(?TestPoint(TestPoint{ x: 1, y: 2 }), ?TestPoint(TestPoint{ x: 1, y: 3 }))
	assert deep_equal([3]int{init: 2}, [3]int{init: 2})
	assert !deep_equal([1, 2, 3], [1, 2, 4])
	assert deep_equal([TestPoint{ x: 1, y: 2 }], [TestPoint{ x: 1, y: 2 }])
	assert !deep_equal([TestPoint{ x: 1, y: 2 }], [TestPoint{ x: 1, y: 3 }])
	assert deep_equal(TestOuter{
		point: TestPoint{ x: 1, y: 2 }
		name: 'app'
		port: 8080
	}, TestOuter{
		point: TestPoint{ x: 1, y: 2 }
		name: 'app'
		port: 8080
	})
}

fn test_deep_equal_uses_equal_method() {
	assert deep_equal(TestCustom{ value: 5 }, TestCustom{ value: 15 })
	assert !deep_equal(TestCustom{ value: 5 }, TestCustom{ value: 6 })
	assert deep_equal(?TestCustom(TestCustom{ value: 5 }), ?TestCustom(TestCustom{ value: 15 }))
	assert deep_equal(TestCustomOuter{ custom: TestCustom{ value: 5 } }, TestCustomOuter{
		custom: TestCustom{ value: 15 }
	})
}

fn test_deep_equal_sumtype() {
	assert deep_equal(TestValue(int(42)), TestValue(int(42)))
	assert !deep_equal(TestValue(int(42)), TestValue(int(43)))
	assert !deep_equal(TestValue(int(42)), TestValue(f32(42)))
	assert deep_equal(TestValue('abc'), TestValue('abc'))
	assert deep_equal(TestEqualValue(int(5)), TestEqualValue(int(25)))
	assert !deep_equal(TestEqualValue(int(5)), TestEqualValue(int(6)))
	assert deep_equal(TestEqualValue('abc'), TestEqualValue('xyz'))
}

fn test_expect_approx_equal_floats_arrays_and_structs() ! {
	expect_approx_equal(f32(10.0), f32(10.000001))!
	expect_approx_equal(f64(10.0), f64(10.00000001))!
	expect_approx_equal([f32(1.0), 0.0], [f32(1.000001), 0.0])!
	expect_approx_equal(ApproxMetrics{
		width: 1.0
		height: 2.0
		count: 3
	}, ApproxMetrics{
		width: 0.999999
		height: 2.000000001
		count: 3
	})!
}

fn test_expect_approx_equal_options_and_sumtypes() ! {
	expect_approx_equal(?f32(1.0), ?f32(1.000001))!
	expect_approx_equal(?f32(none), ?f32(none))!
	expect_approx_equal(TestValue(f32(10.0)), TestValue(f32(10.000001)))!
}

fn test_expect_approx_equal_reports_difference() {
	expect_approx_equal(f32(1.0), f32(2.0)) or {
		assert err.msg() == 'TestExpectedApproxEqual'
		return
	}
	assert false, 'expected approximate comparison to fail'
}
