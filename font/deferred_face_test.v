module font

import os

fn test_deferred_face_codepoint_coverage() {
	face := DeferredFace{
		codepoints: {
			u32(`A`): true
			u32(`B`): false
		}
	}

	assert face.has_codepoint(u32(`A`), none)
	assert !face.has_codepoint(u32(`B`), none)
	assert !face.has_codepoint(u32(`C`), none)
}

fn test_deferred_face_load_missing_path_errors() {
	lib := Library.init()!
	defer {
		mut l := lib
		l.deinit()
	}
	face := DeferredFace{
		path: os.join_path(os.temp_dir(), 'witty-missing-font.ttf')
	}

	if _ := face.load(lib, FaceOptions{}) {
		assert false, 'expected missing deferred font path to error'
	}
}
