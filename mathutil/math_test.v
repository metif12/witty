module mathutil

fn test_ortho2d() {
	m := ortho2d(0, 800, 600, 0)
	assert m[0] > 0.0024 && m[0] < 0.0026
	assert m[5] < -0.003 && m[5] > -0.004
	assert m[10] == -1
	assert m[15] == 1
}
