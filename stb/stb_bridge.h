#ifndef WITTY_STB_BRIDGE_H
#define WITTY_STB_BRIDGE_H

unsigned char *witty_stbi_load_from_memory(
    const unsigned char *buffer, int len, int *x, int *y,
    int *channels_in_file, int desired_channels);

void witty_stbi_image_free(void *retval_from_stbi_load);

int witty_stbir_resize_uint8(
    const unsigned char *input_pixels, int input_w, int input_h,
    int input_stride_in_bytes, unsigned char *output_pixels, int output_w,
    int output_h, int output_stride_in_bytes, int num_channels);

#endif
