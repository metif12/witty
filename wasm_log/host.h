#ifndef WITTY_WASM_LOG_HOST_H
#define WITTY_WASM_LOG_HOST_H
#include <stddef.h>
__attribute__((import_module("env"), import_name("log")))
extern void ghostty_wasm_host_log(const unsigned char *ptr, size_t len);
#endif
