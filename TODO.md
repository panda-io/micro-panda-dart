# TODO

## Compiler

### Windows MSVC support for `hosted/time.mpd`

Works on Linux, macOS, iOS, Android, Windows + MinGW, Windows + Clang.
MSVC is the only remaining unsupported target.

`time_us()` uses a GCC statement expression `({...})` which MSVC does not support.
A real C helper function would be needed for that case — deferred until there is an
actual MSVC build target.

## Language

### MCU platform: `@service`, `@task`, `@interrupt` annotations

Annotations for structured MCU/RTOS programming, targeting ESP32/FreeRTOS initially.

#### `@service` — compile-time managed singletons

```
@service
class Wifi
    var _connected: bool = false

    __init()
        wifi_driver_init()

@service
class MqttClient
    var _wifi: &Wifi
    var _connected: bool = false

    __init(wifi: &Wifi)
        _wifi = wifi
        _wifi.connect()
```

**Rules:**
- One global instance per `@service` class, zero-constructed at startup
- `__init(deps...)` is the framework lifecycle hook — compiler calls it, user does not
- `__init` params must all be `@service` types — compiler error otherwise (framework can
  only inject what it manages)
- Two-phase startup: zero-construct ALL services first, then call `__init` in dependency
  order — guarantees all service pointers are valid (non-null) before any `__init` runs
- Dependency order resolved by topological sort of `__init` signatures
- Circular dependency → compile-time error
- Generated getter per service: `fun wifi() &Wifi` returning `&g_wifi`
- `__init` on a non-`@service` class → compile error

**Remove constructor params from class syntax** (`class Foo(x: int)` zero-inits and
ignores args — misleading). All fields go in the class body. Constructor params are
replaced by `__init` for `@service` classes.

#### `@task` — FreeRTOS tasks

```
@task(stack=4096, priority=5)
fun sensor_loop()
    while true
        var v: int = adc_read(0)
        signal_send(SIGNAL_SENSOR_DATA, v)
        sleep_ms(50)
```

- Creates a FreeRTOS task wrapping the function
- `stack` and `priority` configurable via annotation params
- Tasks can SEND signals to the main task but do not have their own signal dispatcher (v1)
- Tasks can read `@service` singletons freely (they're globals)

#### `@interrupt` — deferred ISR via signal

```
@interrupt(GPIO_NUM_4, RISING)
fun on_button()
    // runs on main task, not in ISR context
    gpio_toggle(LED_PIN)
```

- Framework generates a real ISR that calls `xQueueSendFromISR` to post a signal
- User's function runs as a deferred handler on the main task — no ISR restrictions
- User never writes ISR-unsafe code
- Covers ~90% of use cases (buttons, sensors, GPIO events)

#### `@isr` — raw interrupt service routine

```
@isr
fun on_dma_done()
    dma_clear_interrupt_flag()       // must clear or ISR fires again immediately
    notify(render_task)              // xTaskNotifyFromISR — FreeRTOS task notification
    portYIELD_FROM_ISR(...)          // yield if higher-priority task was woken
```

- Generated C gets `IRAM_ATTR` automatically (ESP32 requires ISR code in IRAM)
- Runs immediately in interrupt context — user is responsible for ISR safety
- No blocking, no heap, only `FromISR` FreeRTOS variants
- Full power of Micro-Panda available: `asm()`, `@extern` for `FromISR` APIs
- Use cases: encoder counting, ultrasonic timing, DMA completion, bit-bang protocols

#### `notify` / `wait` — FreeRTOS task notifications

Inter-task and ISR-to-task synchronization. Distinct from the panda-boot signal system
(`signal_send` dispatches on the main task event bus — `notify`/`wait` are low-level
FreeRTOS primitives for direct task coordination).

```
// Render pipeline example:
// Main task writes back buffer, render task copies to DMA, ISR signals completion.

@task(stack=4096, priority=10)
fun render_task()
    while true
        wait()                   // ulTaskNotifyTake — blocks until notified
        copy_buffer_to_dma()
        dma_start()

@isr
fun on_dma_done()
    dma_clear_flag()
    notify(render_task)          // xTaskNotifyFromISR — wakes render_task
```

Maps to FreeRTOS task notifications — lightest-weight primitive (no separate object,
one 32-bit slot per task). Clear naming split:

| | Scope | Mechanism | Use |
|---|---|---|---|
| `signal_send` | main task only | panda-boot event bus | game logic, app events |
| `notify` / `wait` | any task / ISR | FreeRTOS task notification | system-level sync |

#### Main task (`app_main`)

`@signal`, `@tick`, `@interval` handlers all run on the main task (the FreeRTOS task
that calls `app_main`). The main task runs a `while(true) { xQueueReceive(...) }` event
loop. On ESP-IDF, FreeRTOS is already running before `app_main` is called — no
"before/after RTOS" split to handle.

#### `mpd.yaml` target additions needed

```yaml
targets:
  esp32:
    entry: main
    flags: [MCU, ESP32]
    gen_c_only: true      # stop after C emission, don't invoke gcc
    entry_fn: app_main    # emit void app_main() instead of int main()
    output: out/app.c
```

---

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

### Project config file for user overrides and HAL selection

Libraries like `pwm`, `i2c`, `spi` have compile-time constants (e.g. `PWM_MAX_CHANNELS`)
that differ by chip variant. Currently these live in a `config.mpd` inside the library,
which the user cannot easily override without editing library source.

**Idea:** a non-`.mpd` config file at the project root (e.g. `mpd.config` or a `[config]`
section in `mpd.yaml`) that injects named constants into the build — no `.mpd` parsing
needed, just key=value pairs the compiler exposes as module-level `const` or C `#define`.

```yaml
# mpd.yaml
config:
  PWM_MAX_CHANNELS: 8      # override lib default (6 for C3, 8 for ESP32/S2/S3)
  I2C_MAX_DEVICES: 4
```

**HAL consideration:** the config file could also declare which HAL implementation to use
per peripheral, decoupling the library API from the chip-specific driver:

```yaml
hal:
  pwm: ledc          # ESP32 LEDC (default)
  i2c: esp_idf       # ESP-IDF I2C master driver
  uart: esp_idf
```

The compiler maps `hal.pwm = ledc` to `import pwm_ledc as pwm` (or similar), so the
application code stays chip-agnostic.

Deferred until the language and build pipeline are stable. Module-resolution-based
shadowing (app `src/config.mpd` overrides lib `config.mpd`) is an alternative but
requires file-path namespacing in the import resolver — also deferred.

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
