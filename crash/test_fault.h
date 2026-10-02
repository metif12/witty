#ifndef WITTY_SENTRY_TEST_FAULT_H
#define WITTY_SENTRY_TEST_FAULT_H
#include <stdint.h>
static void witty_sentry_test_fault(void) {
    *(volatile uint32_t *)(uintptr_t)1 = 1;
}
#endif
