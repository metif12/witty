module simd

fn test_index_of() {
	assert index_of('hello'.bytes(), ` `) == none
	assert index_of('hi lo'.bytes(), ` `) or { -1 } == 2
	assert index_of('XXXXX XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\nXXXXXXXXXXXX XXXXXXXXXXX XXXXXXXXXXXXXXX'.bytes(), ` `) or { -1 } == 5
	assert index_of('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\nXXXXXXXXXXXX XXXXXXXXXXX XXXXXXXXXXXXXXX'.bytes(), ` `) or { -1 } == 53
}
