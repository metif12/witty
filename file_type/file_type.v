module file_type

import ascii

const type_details = [
	TypeDetail{
		typ: .jpeg
		sigs: [
			Signature{ pattern: [i16(0xff), 0xd8, 0xff, 0xdb] },
			Signature{
				pattern: [i16(0xff), 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00,
					0x01]
			},
			Signature{ pattern: [i16(0xff), 0xd8, 0xff, 0xee] },
			Signature{
				pattern: [i16(0xff), 0xd8, 0xff, 0xe1, -1, -1, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00]
			},
			Signature{ pattern: [i16(0xff), 0xd8, 0xff, 0xe0] },
		]
		exts: [
			'.jpg',
			'.jpeg',
			'.jfif',
		]
	},
	TypeDetail{
		typ: .png
		sigs: [
			Signature{ pattern: [i16(0x89), 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] },
		]
		exts: [
			'.png',
		]
	},
	TypeDetail{
		typ: .gif
		sigs: [
			Signature{ pattern: [i16(`G`), i16(`I`), i16(`F`), i16(`8`), i16(`7`), i16(`a`)] },
			Signature{ pattern: [i16(`G`), i16(`I`), i16(`F`), i16(`8`), i16(`9`), i16(`a`)] },
		]
		exts: [
			'.gif',
		]
	},
	TypeDetail{
		typ: .bmp
		sigs: [
			Signature{ pattern: [i16(`B`), i16(`M`)] },
		]
		exts: [
			'.bmp',
		]
	},
	TypeDetail{
		typ: .qoi
		sigs: [
			Signature{ pattern: [i16(`q`), i16(`o`), i16(`i`), i16(`f`)] },
		]
		exts: [
			'.qoi',
		]
	},
	TypeDetail{
		typ: .webp
		sigs: [
			Signature{
				pattern: [i16(`R`), i16(`I`), i16(`F`), i16(`F`), -1, -1, -1, -1, i16(`W`), i16(`E`),
					i16(`B`), i16(`P`)]
			},
		]
		exts: [
			'.webp',
		]
	},
]

struct Signature {
	// A negative value translates a null signature byte (a wildcard).
	pattern []i16
}

struct TypeDetail {
	typ  FileType
	sigs []Signature
	exts []string
}

// FileType is a helper for detecting file types based on magic bytes.
//
// Ref: https://en.wikipedia.org/wiki/List_of_file_signatures
pub enum FileType as u8 {
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

// detect detects the file type from the magic bytes at the start of contents.
pub fn FileType.detect(contents []u8) FileType {
	for detail in type_details {
		for signature in detail.sigs {
			if contents.len < signature.pattern.len {
				continue
			}
			mut matched := true
			for i, expected in signature.pattern {
				if expected >= 0 && contents[i] != u8(expected) {
					matched = false
					break
				}
			}
			if matched {
				return detail.typ
			}
		}
	}
	return .unknown
}

// guess_from_extension guesses the file type from a case-insensitive extension.
pub fn FileType.guess_from_extension(extension string) FileType {
	for detail in type_details {
		for ext in detail.exts {
			if ascii.eql_ignore_case(extension, ext) {
				return detail.typ
			}
		}
	}
	return .unknown
}
