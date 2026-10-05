#ifndef WITTY_SIMD_STORE_PREFIX_H
#define WITTY_SIMD_STORE_PREFIX_H
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
static uint16_t *witty_simd_observed;
static void witty_simd_trace(void) {
    printf("TRACE:%04x,%04x,%04x,%04x\n", witty_simd_observed[0],
           witty_simd_observed[1], witty_simd_observed[2], witty_simd_observed[3]);
    fflush(NULL);
}
static void witty_simd_observe(uint16_t *value) {
    witty_simd_observed = value;
    atexit(witty_simd_trace);
}
#endif
