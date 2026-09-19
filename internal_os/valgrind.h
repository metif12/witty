#ifndef WITTY_INTERNAL_OS_VALGRIND_H
#define WITTY_INTERNAL_OS_VALGRIND_H

#include <stdint.h>

/*
 * Runtime Valgrind probe translated from Zig 0.15.2 std.valgrind.
 *
 * Valgrind recognizes the otherwise inert instruction sequence below and
 * replaces the default result with the nesting level. Native execution leaves
 * the result as zero. The request number is VG_USERREQ__RUNNING_ON_VALGRIND.
 */
static inline uintptr_t witty_running_on_valgrind(void) {
    volatile uintptr_t args[6] = {4097, 0, 0, 0, 0, 0};
    volatile uintptr_t result = 0;

#if (defined(__GNUC__) || defined(__clang__)) && defined(__x86_64__)
    __asm__ volatile(
        "rolq $3, %%rdi ; rolq $13, %%rdi\n\t"
        "rolq $61, %%rdi ; rolq $51, %%rdi\n\t"
        "xchgq %%rbx, %%rbx"
        : "=d"(result)
        : "a"(&args[0]), "0"((uintptr_t)0)
        : "cc", "memory");
#elif (defined(__GNUC__) || defined(__clang__)) && defined(__i386__)
    __asm__ volatile(
        "roll $3, %%edi ; roll $13, %%edi\n\t"
        "roll $29, %%edi ; roll $19, %%edi\n\t"
        "xchgl %%ebx, %%ebx"
        : "=d"(result)
        : "a"(&args[0]), "0"((uintptr_t)0)
        : "cc", "memory");
#elif (defined(__GNUC__) || defined(__clang__)) && defined(__aarch64__)
    __asm__ volatile(
        "mov x3, %1\n\t"
        "mov x4, %2\n\t"
        "ror x12, x12, #3 ; ror x12, x12, #13\n\t"
        "ror x12, x12, #51 ; ror x12, x12, #61\n\t"
        "orr x10, x10, x10\n\t"
        "mov %0, x3"
        : "=r"(result)
        : "r"((uintptr_t)0), "r"(&args[0])
        : "cc", "memory", "x3", "x4");
#elif (defined(__GNUC__) || defined(__clang__)) && defined(__arm__)
    __asm__ volatile(
        "mov r3, %1\n\t"
        "mov r4, %2\n\t"
        "mov r12, r12, ror #3 ; mov r12, r12, ror #13\n\t"
        "mov r12, r12, ror #29 ; mov r12, r12, ror #19\n\t"
        "orr r10, r10, r10\n\t"
        "mov %0, r3"
        : "=r"(result)
        : "r"((uintptr_t)0), "r"(&args[0])
        : "cc", "memory", "r3", "r4");
#elif (defined(__GNUC__) || defined(__clang__)) && defined(__mips__) && _MIPS_SIM == _ABI64
    __asm__ volatile(
        "move $11, %1\n\t"
        "move $12, %2\n\t"
        "dsll $0, $0, 3 ; dsll $0, $0, 13\n\t"
        "dsll $0, $0, 29 ; dsll $0, $0, 19\n\t"
        "or $13, $13, $13\n\t"
        "move %0, $11"
        : "=r"(result)
        : "r"((uintptr_t)0), "r"(&args[0])
        : "$11", "$12", "memory");
#elif (defined(__GNUC__) || defined(__clang__)) && defined(__mips__)
    __asm__ volatile(
        "move $11, %1\n\t"
        "move $12, %2\n\t"
        "srl $0, $0, 13\n\t"
        "srl $0, $0, 29\n\t"
        "srl $0, $0, 3\n\t"
        "srl $0, $0, 19\n\t"
        "or $13, $13, $13\n\t"
        "move %0, $11"
        : "=r"(result)
        : "r"((uintptr_t)0), "r"(&args[0])
        : "$11", "$12", "memory");
#elif (defined(__GNUC__) || defined(__clang__)) && (defined(__powerpc64__) || defined(__powerpc__))
    __asm__ volatile(
        "mr 3, %1\n\t"
        "mr 4, %2\n\t"
#if defined(__powerpc64__)
        "rotldi 0, 0, 3 ; rotldi 0, 0, 13\n\t"
        "rotldi 0, 0, 61 ; rotldi 0, 0, 51\n\t"
#else
        "rlwinm 0, 0, 3, 0, 31 ; rlwinm 0, 0, 13, 0, 31\n\t"
        "rlwinm 0, 0, 29, 0, 31 ; rlwinm 0, 0, 19, 0, 31\n\t"
#endif
        "or 1, 1, 1\n\t"
        "mr %0, 3"
        : "=b"(result)
        : "b"((uintptr_t)0), "b"(&args[0])
        : "cc", "memory", "r3", "r4");
#elif (defined(__GNUC__) || defined(__clang__)) && defined(__riscv) && __riscv_xlen == 64
    __asm__ volatile(
        "mv a3, %1\n\t"
        "mv a4, %2\n\t"
        ".option push\n\t"
        ".option norvc\n\t"
        "srli zero, zero, 3\n\t"
        "srli zero, zero, 13\n\t"
        "srli zero, zero, 51\n\t"
        "srli zero, zero, 61\n\t"
        "or a0, a0, a0\n\t"
        ".option pop\n\t"
        "mv %0, a3"
        : "=r"(result)
        : "r"((uintptr_t)0), "r"(&args[0])
        : "memory", "a3", "a4");
#elif (defined(__GNUC__) || defined(__clang__)) && defined(__s390x__)
    __asm__ volatile(
        "lgr 2, %1\n\t"
        "lgr 3, %2\n\t"
        "lr 15, 15\n\t"
        "lr 1, 1\n\t"
        "lr 2, 2\n\t"
        "lr 3, 3\n\t"
        "lr 2, 2\n\t"
        "lgr %0, 3"
        : "=d"(result)
        : "a"(&args[0]), "0"((uintptr_t)0)
        : "cc", "2", "3", "memory");
#else
    (void)args;
#endif

    return result;
}

#endif
