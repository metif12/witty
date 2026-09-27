module terminal

// Tests for point.v (translated from point.zig)

fn test_coordinate_eql() {
	c1 := Coordinate{ x: 10, y: 20 }
	c2 := Coordinate{ x: 10, y: 20 }
	c3 := Coordinate{ x: 5, y: 20 }
	assert c1.eql(c2)
	assert !c1.eql(c3)
}

fn test_coordinate_default() {
	c := Coordinate{}
	assert c.x == 0
	assert c.y == 0
}

fn test_point_new() {
	p := Point.new(.active, Coordinate{ x: 5, y: 10 })
	assert p.tag() == .active
	assert p.coord().x == 5
	assert p.coord().y == 10
}

fn test_point_coord() {
	p := Point.new(.viewport, Coordinate{ x: 42, y: 80 })
	c := p.coord()
	assert c.x == 42
	assert c.y == 80
}

fn test_point_tags() {
	assert sizeof(PointTag) == 1
	assert sizeof(Coordinate) == 8
	assert sizeof(PointActive) == sizeof(Coordinate)
	assert sizeof(PointViewport) == sizeof(Coordinate)
	assert sizeof(PointScreen) == sizeof(Coordinate)
	assert sizeof(PointHistory) == sizeof(Coordinate)
	assert u8(PointTag.active) == 0
	assert u8(PointTag.viewport) == 1
	assert u8(PointTag.screen) == 2
	assert u8(PointTag.history) == 3
	active := Point.new(.active, Coordinate{})
	viewport := Point.new(.viewport, Coordinate{})
	screen := Point.new(.screen, Coordinate{})
	history := Point.new(.history, Coordinate{})
	assert active is PointActive
	assert viewport is PointViewport
	assert screen is PointScreen
	assert history is PointHistory
}

fn test_point_default() {
	p := Point(PointActive{})
	assert p is PointActive
	assert p.coord().x == 0
	assert p.coord().y == 0
}
