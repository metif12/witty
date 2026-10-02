#ifndef WITTY_EXEC_WINDOWS_PATH_H
#define WITTY_EXEC_WINDOWS_PATH_H
#include <windows.h>
#include <winternl.h>
// ABI prefix of Zig std.os.windows.RTL_USER_PROCESS_PARAMETERS. The SDK
// exposes its leading fields as opaque Reserved1/Reserved2 arrays.
typedef struct {
 ULONG AllocationSize, Size, Flags, DebugFlags;
 HANDLE ConsoleHandle;
 ULONG ConsoleFlags;
 HANDLE hStdInput, hStdOutput, hStdError;
 struct { UNICODE_STRING DosPath; HANDLE Handle; } CurrentDirectory;
} WittyExecProcessParameters;
static HANDLE witty_exec_cwd_handle(void) {
 return ((WittyExecProcessParameters*)NtCurrentTeb()->ProcessEnvironmentBlock->ProcessParameters)->CurrentDirectory.Handle;
}
NTSYSAPI ULONG NTAPI RtlGetFullPathName_U(PCWSTR, ULONG, PWSTR, PWSTR*);
NTSYSAPI NTSTATUS NTAPI NtQueryAttributesFile(POBJECT_ATTRIBUTES, PFILE_BASIC_INFORMATION);
#endif
