#ifndef WITTY_STB_BRIDGE_H
#define WITTY_STB_BRIDGE_H

int witty_stbir_resize_uint8(
    const unsigned char *input_pixels, int input_w, int input_h,
    int input_stride_in_bytes, unsigned char *output_pixels, int output_w,
    int output_h, int output_stride_in_bytes, int num_channels);

#endif
