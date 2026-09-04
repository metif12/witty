module datastruct

@[heap]
struct IntrusiveTestNode {
mut:
	data u32
	prev ?&IntrusiveTestNode
	next ?&IntrusiveTestNode
}

fn test_intrusive_doubly_linked_list() {
	mut list := IntrusiveDoublyLinkedList[IntrusiveTestNode]{}
	one := &IntrusiveTestNode{ data: 1 }
	two := &IntrusiveTestNode{ data: 2 }
	three := &IntrusiveTestNode{ data: 3 }
	four := &IntrusiveTestNode{ data: 4 }
	five := &IntrusiveTestNode{ data: 5 }

	list.append(two) // {2}
	list.append(five) // {2, 5}
	list.prepend(one) // {1, 2, 5}
	list.insert_before(five, four) // {1, 2, 4, 5}
	list.insert_after(two, three) // {1, 2, 3, 4, 5}

	mut forward := []u32{}
	mut current := list.first
	for {
		node := current or { break }
		forward << node.data
		current = node.next
	}
	assert forward == [u32(1), 2, 3, 4, 5]

	mut backward := []u32{}
	current = list.last
	for {
		node := current or { break }
		backward << node.data
		current = node.prev
	}
	assert backward == [u32(5), 4, 3, 2, 1]

	_ = list.pop_first() // {2, 3, 4, 5}
	_ = list.pop() // {2, 3, 4}
	list.remove(three) // {2, 4}
	assert list.first?.data == 2
	assert list.last?.data == 4
}
