module benchmark

fn benchmark_signpost_begin(ptr voidptr) BenchmarkSignpost {
	_ = ptr
	return BenchmarkSignpost{}
}

fn (mut self BenchmarkSignpost) end() {}
