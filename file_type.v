// Translated from Ghostty's file_type.zig
//
// This is a helper for detecting file types based on magic bytes.
//
// Ref: https://en.wikipedia.org/wiki/List_of_file_signatures

module main

import ascii

// FileType represents detected image file formats.
pub enum FileType {
	// JPEG image file.
	jpeg
	// PNG image file.
	png
	// GIF image file.
	gif
	// BMP image file.
	bmp
	// QOI image file.
	qoi
	// WebP image file.
	webp
	// Unknown file format.
	unknown
}

// Signature represents a magic byte signature for file type detection.
// A value of -1 in the pattern means "any byte" (wildcard).
struct Signature {
	pattern []i16
}

// TypeDetail holds the file type, its magic byte signatures, and known extensions.
struct TypeDetail {
	typ  FileType
	sigs []Signature
	exts []string
}

// Table of known file type signatures and extensions.
const type_details = [
	TypeDetail{
		typ:  .jpeg
		sigs: [
			Signature{
				pattern: [i16(0xFF), 0xD8, 0xFF, 0xDB]
			},
			Signature{
				pattern: [i16(0xFF), 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
					0x01]
			},
			Signature{
				pattern: [i16(0xFF), 0xD8, 0xFF, 0xEE]
			},
			Signature{
				pattern: [i16(0xFF), 0xD8, 0xFF, 0xE1, -1, -1, 0x45, 0x78, 0x69, 0x66, 0x00,
					0x00]
			},
			Signature{
				pattern: [i16(0xFF), 0xD8, 0xFF, 0xE0]
			},
		]
		exts: ['.jpg', '.jpeg', '.jfif']
	},
	TypeDetail{
		typ:  .png
		sigs: [
			Signature{
				pattern: [i16(0x89), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
			},
		]
		exts: ['.png']
	},
	TypeDetail{
		typ:  .gif
		sigs: [
			Signature{
				pattern: [i16(0x47), 0x49, 0x46, 0x38, 0x37, 0x61]
			},
			Signature{
				pattern: [i16(0x47), 0x49, 0x46, 0x38, 0x39, 0x61]
			},
		]
		exts: ['.gif']
	},
	TypeDetail{
		typ:  .bmp
		sigs: [
			Signature{
				pattern: [i16(0x42), 0x4D]
			},
		]
		exts: ['.bmp']
	},
	TypeDetail{
		typ:  .qoi
		sigs: [
			Signature{
				pattern: [i16(0x71), 0x6F, 0x69, 0x66]
			},
		]
		exts: ['.qoi']
	},
	TypeDetail{
		typ:  .webp
		sigs: [
			Signature{
				pattern: [i16(0x52), 0x49, 0x46, 0x46, -1, -1, -1, -1, 0x57, 0x45, 0x42, 0x50]
			},
		]
		exts: ['.webp']
	},
]

// Detect file type based on the magic bytes at the start of the provided
// file contents. Returns .unknown if no known signature matches.
pub fn detect(contents []u8) FileType {
	for td in type_details {
		for sig in td.sigs {
			if contents.len >= sig.pattern.len {
				mut matched := true
				for i, s in sig.pattern {
					if s >= 0 && contents[i] != u8(s) {
						matched = false
						break
					}
					// s == -1 means wildcard (any byte matches)
				}
				if matched {
					return td.typ
				}
			}
		}
	}
	return .unknown
}

// Guess file type from its extension. Case-insensitive comparison.
// Returns .unknown if no known extension matches.
pub fn guess_from_extension(extension string) FileType {
	for td in type_details {
		for ext in td.exts {
			if ascii.eql_ignore_case(extension, ext) {
				return td.typ
			}
		}
	}
	return .unknown
}
