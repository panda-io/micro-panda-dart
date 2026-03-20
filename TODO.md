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


### Self-hosted compiler + LLVM IR backend + JIT

The Dart compiler targets C only and serves as the bootstrap stage. The long-term goal
is a self-hosted Micro Panda compiler that targets LLVM IR, embeds `libLLVM`, and supports
both AOT compilation and JIT execution of `.mpd` scripts.

**The C backend is permanent.** Many MCU platforms (ESP32, Cortex-M, AVR, RISC-V) have
no LLVM backend or a limited one — C is the only viable compilation target there. The C
backend remains the default for all MCU targets and a valid option for hosted builds too.
LLVM IR is an additive backend for hosted platforms, not a replacement.

| Backend | MCU | Hosted | Use case |
|---|---|---|---|
| C | always | yes | Universal — every platform with a C compiler |
| LLVM IR (AOT) | no | yes | Optimized native binaries on desktop/server |
| LLVM JIT | no | yes | `mpd run` scripting, near-native speed |

**Roadmap:**

**Stage 1 — Bootstrap (current)**
The Dart compiler is the reference implementation. C is the only backend. All language
features are designed and validated here.

**Stage 2 — Self-hosted compiler**
Rewrite the compiler in Micro Panda itself. Compile it with the Dart compiler to produce
a native `mpd` binary. The Dart compiler becomes the bootstrap tool and can eventually
be retired.

```
micro-panda-dart (Dart)  →  compiles  →  mpd-native (Micro Panda)
mpd-native               →  compiles  →  mpd-native   (self-hosting confirmed)
```

Self-hosting validates the language — if Micro Panda can compile itself, it is mature
enough for serious use.

**Stage 3 — LLVM IR backend**
Add an LLVM IR code generator to the self-hosted compiler alongside the existing C backend.

```
.mpd  →  LLVM IR  →  llc / lld  →  native binary   (AOT)
```

Since Micro Panda has no GC, the IR backend is straightforward — types map directly:

| Micro Panda | LLVM IR |
|---|---|
| `i32`, `u8`, `bool` | `i32`, `i8`, `i1` |
| `float` / `fixed` | `float` / `i32` |
| struct / class | `%T = type { ... }` |
| `u8[]` slice | `{ i8*, i32 }` |
| `&T` reference | `T*` |

No stack maps, no write barriers, no GC intrinsics needed. `@raw` C blocks are the only
gap — compiled separately as `.c` → `.o` and linked into the module.

**Stage 4 — Embedded libLLVM + ORC JIT (`mpd run`)**
Link `libLLVM` directly into the self-hosted `mpd` binary. Use LLVM's ORC JIT to compile
IR to native code at runtime and execute `main()` in-process.

```
mpd run script.mpd  →  parse  →  LLVM IR  →  ORC JIT  →  execute
```

- Runs at full native speed — no interpreter, no GC pauses
- Statically typed + no boxing → significantly faster than CPython in practice
- `@extern` symbols resolve through ORC's dynamic linker automatically
- Import resolution for scripts: script directory → user lib → system lib → std

`libLLVM` adds ~15–30 MB to the binary but makes `mpd` entirely self-contained —
no external toolchain needed for the full write-run loop.

---

### Package / library management

Support declaring and fetching external library dependencies, with a layered resolution
order so libraries can be shared across projects.

**Import resolution order (innermost wins):**

| Level | Path | Notes |
|---|---|---|
| Project | `src/` | Current project source |
| Script | script's directory | For `mpd run script.mpd` (no `mpd.yaml`) |
| User | `~/.micro-panda/lib/` | Per-user installs, no sudo needed |
| System | `/usr/local/micro-panda/lib/` | Shared across users on the machine |
| Std | embedded in `mpd` binary | Always available |

**Dependency declaration in `mpd.yaml`:**
```yaml
deps:
  - url: https://github.com/example/mylib
    version: v1.2.0   # or @latest
```

`mpd` fetches and caches dependencies into `.micro-panda/lib/` on first build (project-local,
not shared). Use `mpd install --user` or `mpd install --system` to install a library to the
user or system level so it can be shared across projects.

**Why this is simpler than C libraries:**
Since libraries are plain `.mpd` source files (no compiled artifacts, no ABI to match),
version mismatches and binary compatibility are non-issues. A "library" is just a directory
of source that gets compiled together with the project.
