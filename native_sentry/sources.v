module native_sentry

const breakpad_common = [
	'src/common/convert_UTF.cc',
	'src/common/md5.cc',
	'src/common/string_conversion.cc',
]!

const breakpad_common_linux = [
	'src/common/linux/elf_core_dump.cc',
	'src/common/linux/elfutils.cc',
	'src/common/linux/file_id.cc',
	'src/common/linux/guid_creator.cc',
	'src/common/linux/linux_libc_support.cc',
	'src/common/linux/memory_mapped_file.cc',
	'src/common/linux/safe_readlink.cc',
	'src/common/linux/scoped_pipe.cc',
	'src/common/linux/scoped_tmpfile.cc',
	'src/common/linux/breakpad_getcontext.S',
]!

const breakpad_common_apple = [
	'src/common/mac/arch_utilities.cc',
	'src/common/mac/file_id.cc',
	'src/common/mac/macho_id.cc',
	'src/common/mac/macho_utilities.cc',
	'src/common/mac/macho_walker.cc',
	'src/common/mac/string_utilities.cc',
]!

const breakpad_common_mac = [
	'src/common/mac/MachIPC.mm',
	'src/common/mac/bootstrap_compat.cc',
]!

const breakpad_client_linux = [
	'src/client/minidump_file_writer.cc',
	'src/client/linux/crash_generation/crash_generation_client.cc',
	'src/client/linux/crash_generation/crash_generation_server.cc',
	'src/client/linux/dump_writer_common/thread_info.cc',
	'src/client/linux/dump_writer_common/ucontext_reader.cc',
	'src/client/linux/handler/exception_handler.cc',
	'src/client/linux/handler/minidump_descriptor.cc',
	'src/client/linux/log/log.cc',
	'src/client/linux/microdump_writer/microdump_writer.cc',
	'src/client/linux/minidump_writer/linux_core_dumper.cc',
	'src/client/linux/minidump_writer/linux_dumper.cc',
	'src/client/linux/minidump_writer/linux_ptrace_dumper.cc',
	'src/client/linux/minidump_writer/minidump_writer.cc',
	'src/client/linux/minidump_writer/pe_file.cc',
]!

const breakpad_client_apple = [
	'src/client/minidump_file_writer.cc',
	'src/client/mac/handler/breakpad_nlist_64.cc',
	'src/client/mac/handler/dynamic_images.cc',
	'src/client/mac/handler/minidump_generator.cc',
]!

const breakpad_client_mac = [
	'src/client/mac/handler/exception_handler.cc',
	'src/client/mac/crash_generation/crash_generation_client.cc',
]!

const breakpad_client_ios = [
	'src/client/ios/exception_handler_no_mach.cc',
	'src/client/ios/handler/ios_exception_minidump_generator.mm',
	'src/client/mac/crash_generation/ConfigFile.mm',
	'src/client/mac/handler/protected_memory_allocator.cc',
]!

const sentry_common = [
	'src/sentry_alloc.c',
	'src/sentry_backend.c',
	'src/sentry_core.c',
	'src/sentry_database.c',
	'src/sentry_envelope.c',
	'src/sentry_info.c',
	'src/sentry_json.c',
	'src/sentry_logger.c',
	'src/sentry_options.c',
	'src/sentry_os.c',
	'src/sentry_random.c',
	'src/sentry_ratelimiter.c',
	'src/sentry_scope.c',
	'src/sentry_session.c',
	'src/sentry_slice.c',
	'src/sentry_string.c',
	'src/sentry_sync.c',
	'src/sentry_transport.c',
	'src/sentry_utils.c',
	'src/sentry_uuid.c',
	'src/sentry_value.c',
	'src/sentry_tracing.c',
	'src/path/sentry_path.c',
	'src/transports/sentry_disk_transport.c',
	'src/transports/sentry_function_transport.c',
	'src/unwinder/sentry_unwinder.c',
	'vendor/mpack.c',
]!
