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

### Debugger support — `#line` directives (Option A)

Emit `#line <n> "<file.mpd>"` directives in generated C so GDB/LLDB automatically map
stack frames, breakpoints, and variable locations back to `.mpd` source. No custom DAP
server needed — the existing C/C++ debugger in VS Code handles everything.

- Emit `#line` at the start of each function body and before each statement
- Works for hosted builds (GDB/LLDB) and MCU builds (OpenOCD + GDB on ESP32/Cortex-M)
- Variable names in the debugger will be C-mangled (`__mp_foo`) — acceptable for now
- The VS Code extension side (DAP client config) is tracked in micro-panda-vscode TODO

## Tooling

### Build-system integration: platform templates and component auto-update

#### Platform templates (`mpd init <platform>`)

Users must manually write boilerplate to call `mpd gen` and wire the generated C into
their build system. The CLI should generate this instead.

```sh
mpd init idf     # ESP-IDF (CMake)
mpd init pico    # RP2040 pico-sdk (CMake)
mpd init stm32   # STM32 CubeMX-generated project (CMake)
```

All three are CMake-based, so the template structure is similar — the differences are
in the register macro (`idf_component_register` vs `target_sources` / `add_executable`)
and the two-phase model (IDF runs CMakeLists.txt in script mode before build mode).

Each template should:
- Run `mpd gen <target>` at configure time so the generated `.c` exists on first build
- Re-run incrementally when any `.mpd` source or `mpd.yaml` changes (`add_custom_command`)
- Guard side effects with `if(NOT CMAKE_SCRIPT_MODE_FILE)` where needed (IDF)

Templates embedded in the `mpd` binary (same approach as stdlib).

**PlatformIO** — deferred. PlatformIO manages its own build pipeline well; users only
need `build_cmd: pio run` in `mpd.yaml`. No template needed, no deep integration.

#### Auto-update `REQUIRES` / `lib_deps` from imported deps

When the user imports `i2c::*` or `spi::*` from the esp32 dep, the IDF
`idf_component_register REQUIRES` must include `esp_driver_i2c`, `esp_driver_spi`, etc.
Currently the user adds these manually — easy to forget and hard to debug.

**Proposed: `idf_requires:` field in dep `mpd.yaml`**

```yaml
# micro-panda-esp32/mpd.yaml
idf_requires:
  i2c: [esp_driver_i2c]
  spi: [esp_driver_spi]
  gpio: [esp_driver_gpio]
  pwm: [esp_driver_ledc]
  adc: [esp_adc]
```

After `mpd gen`, the CLI could:
1. Collect `idf_requires` entries for all imported dep modules
2. Update the `REQUIRES` line in `main/CMakeLists.txt` in-place
3. Or print a warning: "add esp_driver_i2c to idf_component_register REQUIRES"

Same concept for PlatformIO: `pio_lib_deps:` field maps modules to `lib_deps` entries.

---

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


### Compiler handoff to Panda

The Dart compiler is the permanent bootstrap stage. C is the only backend — this is a
final decision (not all 32-bit MCU platforms support LLVM well; C is the universal target).

Once the `panda` language is mature, it will take over hosting the `micro-panda` compiler,
replacing the Dart bootstrap. No self-hosted `micro-panda` compiler step — Panda does it.

```
Dart   →  mpd (current bootstrap)
panda  →  mpd (future, once panda is ready)
```

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
