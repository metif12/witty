module x11rgb

fn test_complete_x11_color_lookup() {
	assert get('nosuchcolor') == none
	assert get('white')? == RGB{ r: 255, g: 255, b: 255 }
	assert get('medium spring green')? == RGB{ r: 0, g: 250, b: 154 }
	assert get('FoReStGReEn')? == RGB{ r: 34, g: 139, b: 34 }
	assert get('lawngreen')? == RGB{ r: 124, g: 252, b: 0 }
	assert entries().len > 700
}
