module sprite

fn test_branch_node_packed_layout() {
	assert sizeof(BranchNode) == 1

	node := BranchNode.from_int(branch_node_up | branch_node_right | branch_node_down | branch_node_left | branch_node_filled)
	assert node.value == 0x1f
	assert node.up()
	assert node.right()
	assert node.down()
	assert node.left()
	assert node.filled()
	assert BranchNode.from_int(0x01).up()
	assert BranchNode.from_int(0x02).right()
	assert BranchNode.from_int(0x04).down()
	assert BranchNode.from_int(0x08).left()
	assert BranchNode.from_int(0x10).filled()

	empty := BranchNode.from_int(0)
	assert !empty.up()
	assert !empty.right()
	assert !empty.down()
	assert !empty.left()
	assert !empty.filled()
}
