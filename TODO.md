# TODO

## Compiler

### Windows MSVC support for `hosted/time.mpd`

`@include("unistd.h")` does not exist on MSVC. `usleep()` and `clock_gettime(CLOCK_MONOTONIC)`
are also POSIX-only and unavailable under MSVC.

Current workaround: works on Linux, macOS, iOS, Android, and Windows + MinGW/Clang.
MSVC is the only failing target.

What's needed:

- Generator support for multi-line `@include` emitting raw C (to allow `#ifdef _WIN32` guards
  around `#include` directives at the top of the generated file).
- `ExpressionStatement` handler needs to distinguish between a multi-statement preprocessor
  block (first line starts with `#`) and a single expression spanning multiple lines, so that
  `;` is added correctly in both cases.
- `time.mpd` externs updated to use `Sleep()` + `QueryPerformanceCounter` on MSVC.
- Note: `time_us()` uses a GCC statement expression `({...})` which MSVC does not support —
  a real C helper function may be needed for that case.

## Language

### Debugger / breakpoint support

Allow setting breakpoints and stepping through Micro Panda source in a debugger.

Options to investigate:

- Emit `#line <n> "<file>"` directives in generated C so GDB/LLDB map back to `.mpd` source.
- VS Code debug adapter (DAP) integration in the extension — launch/attach, set breakpoints,
  step, inspect variables.
- Possible intermediate: `@breakpoint` annotation or built-in `break()` that emits
  `__builtin_trap()` / `DebugBreak()` for crash-on-demand debugging.

## Tooling

### Revise `mpd.yaml` project config (after language is stable)

Current `mpd.yaml` is minimal and was designed early. Revisit once the language and build
pipeline are stable.

Things to consider:

- Structured target definitions (name, platform, entry, flags) instead of flat keys.
- Multiple targets in one file (e.g. `hosted` + `mcu32` builds from the same project).
- Explicit platform flag (`platform: hosted | mcu32 | mcu8`) rather than inferring from target.
- Dependency / library declarations for future package management.
- C compiler and linker overrides (cc, cflags, ldflags) per target.
- Output directory configuration.
