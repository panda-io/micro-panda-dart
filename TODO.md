# TODO

## Compiler

### Windows MSVC support for `hosted/time.mpd`

Works on Linux, macOS, iOS, Android, Windows + MinGW, Windows + Clang.
MSVC is the only remaining unsupported target.

`time_us()` uses a GCC statement expression `({...})` which MSVC does not support.
A real C helper function would be needed for that case — deferred until there is an
actual MSVC build target.

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


### Package / library management

Allow a Micro Panda project to declare external library dependencies that are fetched
automatically at build time.

- Declare dependencies in `mpd.yaml` with a Git URL and optional version tag or `@latest`.
- `mpd` fetches and caches each library into `.micro-panda/lib/` on first build.
- Fetched libraries are resolved the same way as the standard library — project source
  takes precedence, then local libs, then std.
