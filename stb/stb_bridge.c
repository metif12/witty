#include "stb_bridge.h"

/* Keep stb_image_resize v1 private to this translation unit. V's graphics
 * modules use stb_image_resize2 in their generated C, and the two versions
 * intentionally reuse public symbol and enum names. */
#define STB_IMAGE_RESIZE_STATIC
#define STBIR_ASSERT(x) ((void)0)
#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize.h"

int witty_stbir_resize_uint8(
    const unsigned char *input_pixels, int input_w, int input_h,
    int input_stride_in_bytes, unsigned char *output_pixels, int output_w,
    int output_h, int output_stride_in_bytes, int num_channels) {
  return stbir_resize_uint8_generic(
      input_pixels, input_w, input_h, input_stride_in_bytes, output_pixels,
      output_w, output_h, output_stride_in_bytes, num_channels, -1, 0,
      STBIR_EDGE_CLAMP, STBIR_FILTER_BOX, STBIR_COLORSPACE_LINEAR, NULL);
}
