module main

import zigimg as z

fn main() {
	for seed in [u16(0), 1, 7, 65535] {
		mut gray := z.PngTrnsProcessor{
			trns_data: z.PngTrnsGray{
				value: seed
			}
		}
		copied := gray
		match mut gray.trns_data {
			z.PngTrnsGray { gray.trns_data.value = 33 }
			else { panic('wrong arm') }
		}

		println('G|${seed}|${(gray.trns_data as z.PngTrnsGray).value}|${(copied.trns_data as z.PngTrnsGray).value}')
		mut rgb := z.PngTrnsProcessor{
			trns_data: z.PngTrnsRGB{
				color: z.Rgb48{
					r: seed
					g: 7
					b: 65535
				}
			}
		}
		rgb_copy := rgb
		match mut rgb.trns_data {
			z.PngTrnsRGB { rgb.trns_data.color.r = 33 }
			else { panic('wrong arm') }
		}

		println('R|${seed}|${(rgb.trns_data as z.PngTrnsRGB).color.r}|${(rgb_copy.trns_data as z.PngTrnsRGB).color.r}|${(rgb_copy.trns_data as z.PngTrnsRGB).color.b}')
		mut alpha := [u8(seed), 17]
		mut indexed := z.PngTrnsProcessor{
			trns_data: z.PngTrnsIndexAlpha{
				data: unsafe { alpha[..] }
			}
		}
		index_copy := indexed
		match mut indexed.trns_data {
			z.PngTrnsIndexAlpha { indexed.trns_data.data = unsafe { indexed.trns_data.data[..1] } }
			else { panic('wrong arm') }
		}

		alpha[0] = 33
		println('I|${seed}|${(indexed.trns_data as z.PngTrnsIndexAlpha).data.len}|${(index_copy.trns_data as z.PngTrnsIndexAlpha).data.len}|${(index_copy.trns_data as z.PngTrnsIndexAlpha).data[0]}')
	}
}
