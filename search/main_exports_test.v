module search

fn test_search_namespace_aliases() {
	assert sizeof(Active) == sizeof(ActiveSearch)
	assert sizeof(PageList) == sizeof(PageListSearch)
	assert sizeof(Screen) == sizeof(ScreenSearch)
	assert sizeof(Viewport) == sizeof(ViewportSearch)
	assert sizeof(Thread) == sizeof(SearchThread)
}
