use @fprintf[I32](stream: Pointer[U8] tag, fmt: Pointer[U8] tag, ...)
use @pony_os_stderr[Pointer[U8]]()
use @exit[None](code: I32)

primitive _Unreachable
  """
  Panic primitive for code paths that should never execute.

  Prints location to stderr and terminates the process.
  """
  fun apply(loc: SourceLoc = __loc) =>
    @fprintf(@pony_os_stderr(),
      "Unreachable at %s:%lu. Please open an issue at https://github.com/ponylang/livery/issues\n"
        .cstring(),
      loc.file().cstring(), loc.line())
    @exit(1)
