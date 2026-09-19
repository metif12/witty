#include "stb_bridge.h"

/* Match Ghostty's stb.c image decoder configuration. Keep stb symbols private
 * because V's graphics modules may compile a separate stb implementation. */
#define STB_IMAGE_STATIC
#define STBI_ONLY_PNG
#define STBI_MAX_DIMENSIONS 131072
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

unsigned char *witty_stbi_load_from_memory(
    const unsigned char *buffer, int len, int *x, int *y,
    int *channels_in_file, int desired_channels) {
  return stbi_load_from_memory(buffer, len, x, y, channels_in_file,
                               desired_channels);
}

void witty_stbi_image_free(void *retval_from_stbi_load) {
  stbi_image_free(retval_from_stbi_load);
}

/* Keep stb_image_resize v1 private to this translation unit. V's graphics
 * modules use stb_image_resize2 in their generated C, and the two versions
 * intentionally reuse public symbol and enum names. */
#define STB_IMAGE_RESIZE_STATIC
#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize.h"

int witty_stbir_resize_uint8(
    const unsigned char *input_pixels, int input_w, int input_h,
    int input_stride_in_bytes, unsigned char *output_pixels, int output_w,
    int output_h, int output_stride_in_bytes, int num_channels) {
  return stbir_resize_uint8(
      input_pixels, input_w, input_h, input_stride_in_bytes, output_pixels,
      output_w, output_h, output_stride_in_bytes, num_channels);
}
