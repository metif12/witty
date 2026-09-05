module internal_hash

struct WyhashTestVector {
	seed     u64
	expected u64
	input    string
}

fn test_zig_0_15_2_wyhash_vectors() {
	vectors := [
		WyhashTestVector{0, 0x0409638ee2bde459, ''},
		WyhashTestVector{1, 0xa8412d091b5fe0a9, 'a'},
		WyhashTestVector{2, 0x32dd92e4b2915153, 'abc'},
		WyhashTestVector{3, 0x8619124089a3a16b, 'message digest'},
		WyhashTestVector{4, 0x7a43afb61d7f5f40, 'abcdefghijklmnopqrstuvwxyz'},
		WyhashTestVector{5, 0xff42329b90e50d58, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'},
		WyhashTestVector{6, 0xc39cab13b115aad3, '12345678901234567890123456789012345678901234567890123456789012345678901234567890'},
	]
	for vector in vectors {
		assert wyhash(vector.input.bytes(), vector.seed) == vector.expected
	}
}
