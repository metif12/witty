#ifndef WITTY_THREAD_POOL_WINDOWS_H
#define WITTY_THREAD_POOL_WINDOWS_H

#include <windows.h>
#include <winternl.h>

/* MinGW's SDK headers omit the ntdll address-wait declarations. */
NTSYSAPI NTSTATUS NTAPI RtlWaitOnAddress(volatile VOID *address, PVOID expected,
                                         SIZE_T size, PLARGE_INTEGER timeout);
NTSYSAPI VOID NTAPI RtlWakeAddressSingle(PVOID address);
NTSYSAPI VOID NTAPI RtlWakeAddressAll(PVOID address);

#endif
