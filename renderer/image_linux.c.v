module renderer

// The OpenGL specialization of image upload and drawing (image.zig is generic over
// the compile-time selected GraphicsAPI).

fn (mut self Image) upload(api &OpenGLAPI) ! {
	self.prep_for_upload()!
	pending := self.get_pending() or { return error('image has no pending data') }
	texture := GLTexture.init(api.image_texture_options(.rgba, true), pending.width, pending.height, pending.data_slice())!
	self.deinit()
	self = ImageReady{ texture: texture }
}

pub fn (mut self ImageRenderState) draw(api &OpenGLAPI, pipeline GLPipeline, mut pass GLRenderPass, placement_type DrawPlacements) {
	placements := match placement_type {
		.kitty_below_bg {
			self.kitty_placements[..int(self.kitty_bg_end)]
		}
		.kitty_below_text {
			start := int(self.kitty_bg_end)
			end := int(self.kitty_text_end)
			self.kitty_placements[start..end]
		}
		.kitty_above_text {
			start := int(self.kitty_text_end)
			self.kitty_placements[start..]
		}
		.overlay { self.overlay_placements }
	}
	for placement in placements {
		entry := self.images[image_key(placement.image_id)] or { continue }
		texture := match entry.image {
			ImageReady, ImageUnloadReady { entry.image.texture }
			else { continue }
		}
		if texture.id == 0 {
			continue
		}
		vertex := ImageVertex{
			grid_pos: [f32(placement.x), f32(placement.y)]!
			cell_offset: [f32(placement.cell_offset_x), f32(placement.cell_offset_y)]!
			source_rect: [f32(placement.source_x), f32(placement.source_y),
				f32(placement.source_width), f32(placement.source_height)]!
			dest_size: [f32(placement.width), f32(placement.height)]!
		}
		mut buffer := GLBuffer.init_fill(api.image_buffer_options(), [vertex]) or { continue }
		pass.step(GLRenderStep{
			pipeline: pipeline
			buffers: [buffer]
			textures: [texture]
			draw: GLDraw{
				primitive: .triangle_strip
				vertex_count: 4
			}
		})
		buffer.deinit()
	}
}
