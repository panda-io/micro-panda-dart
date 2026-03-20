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


### `mpd run` — script mode via embedded TCC

Allow running a `.mpd` file directly without a separate compile step, similar to
`python script.py`.

```
mpd run script.mpd
```

**Approach:** embed [libtcc](https://bellard.org/tcc/) (Tiny C Compiler) inside the `mpd`
binary. The pipeline becomes:

1. Parse + validate `.mpd` → emit C source (in memory, no file written)
2. Hand the C source to libtcc → compile to native code in milliseconds
3. libtcc relocates and executes `main()` in-process

libtcc is small (~200 KB), has a clean C API, and compiles fast enough that startup feels
instant for small programs. Output runs slower than gcc/clang-optimized code, but that is
acceptable for scripts and tools.

**Challenges:**
- `@raw` blocks and `@extern` symbols that reference external C headers need those headers
  to be available at JIT time — same as normal C compilation.
- stdlib `@extern` functions must be registered in libtcc's symbol table before execution.
- libtcc does not support all platforms (ARM support is limited; RISC-V missing).

**Benefit:** zero external toolchain dependency for hosted scripting — `mpd` becomes
self-contained for the full write-run loop.

---

### LLVM IR backend + JIT execution

A more powerful long-term alternative to the C backend, enabling both ahead-of-time
optimized compilation and in-process JIT execution.

**AOT path:**
```
.mpd → LLVM IR → llc / lld → native binary
```
Produces highly optimized output via LLVM's full optimization pipeline (same as Clang).

**JIT path (`mpd run` with LLVM):**
```
.mpd → LLVM IR → ORC JIT → execute in-process
```
LLVM's ORC JIT compiles IR to native code at runtime with near-zero overhead. Runs at
full native speed — no interpreter, no GC pauses.

**Why this is interesting:**
- Single backend covers scripting, AOT release builds, and cross-compilation.
- `@extern` symbols resolve through the JIT's dynamic linker — no special registration needed
  for symbols already in the process (libc, etc.).
- Enables future features: profile-guided optimization, LTO, sanitizers.

**Challenges:**
- Significant backend to build: every type, operator, struct, and calling convention must
  be expressed in LLVM IR.
- `@raw` C blocks have no IR equivalent — would need to be pre-compiled to `.o` and loaded
  as a JIT object.
- Embedding LLVM adds ~15–30 MB to the `mpd` binary (or require LLVM as an external dep).

**Suggested roadmap:**
1. Ship `mpd run` via embedded libtcc first (quick win, scripting feel today).
2. Build LLVM IR backend as a separate target (`mpd build --target llvm`).
3. Wire ORC JIT into `mpd run` as an opt-in once the IR backend is stable.

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
