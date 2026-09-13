module gtk

fn test_compute_fraction_clamps_out_of_range_progress() {
	assert compute_fraction(100) == 1.0
	assert compute_fraction(255) == 1.0
	assert compute_fraction(0) == 0.0
	assert compute_fraction(50) == 0.5
}
