module datastruct

fn test_array_list_collection_init_and_reset() {
	mut collection := ArrayListCollection.init[int](3, 4)
	defer { collection.deinit() }

	assert collection.lists.len == 3
	for list in collection.lists {
		assert list.len == 0
		assert list.cap >= 4
	}

	collection.lists[0] << 1
	collection.lists[1] << 2
	collection.lists[1] << 3
	capacities := collection.lists.map(it.cap)
	collection.reset()

	for i, list in collection.lists {
		assert list.len == 0
		assert list.cap == capacities[i]
	}
}

fn test_array_list_collection_deinit() {
	mut collection := ArrayListCollection.init[u8](2, 1)
	collection.deinit()
	assert collection.lists.len == 0
}
