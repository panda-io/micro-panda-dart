# Project Settings (mpd.yaml)

Every micro-panda project is configured by a single `mpd.yaml` file in the project root.
The CLI reads this file to discover sources, flags, and build targets.

## Minimal example

```yaml
name: my_project
version: 0.1.0

src: src/    # micro-panda source root  (default: src/)
out: out/    # generated C output dir   (default: out/)

targets:
  main:
    entry: main
    cc: gcc
    output: bin/app
```

## Full field reference

### Top-level fields

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | directory name | Project name |
| `version` | string | `0.1.0` | Project version |
| `src` | string | `src/` | Source root directory |
| `out` | string | `out/` | Default output dir for generated C files |
| `targets` | map | — | Named build targets (see below) |

### Target fields

| Field | Type | Description |
| --- | --- | --- |
| `entry` | string | Entry module name, e.g. `main` or `firmware/main` |
| `flags` | list | Micro-panda conditional compile flags (see [Preprocessor](#flags)) |
| `platform` | string | Platform hint, e.g. `linux-x64`, `arm-cortex-m4` |
| `cc` | string | C compiler binary name, e.g. `gcc`, `arm-none-eabi-gcc` |
| `cc_path` | string | Directory containing `cc` (optional; falls back to PATH) |
| `cflags` | list | Extra C compiler flags, e.g. `[-O2, -Wall]` |
| `out` | string | Override project-level output dir for this target |
| `output` | string | Final executable or binary path |
| `build_cmd` | string | Custom build command (replaces `cc`/`cflags`) |

## Build modes

### Simple mode — mpd drives compilation

Set `cc` (and optionally `cc_path`, `cflags`). The CLI generates C then calls the compiler directly.

```yaml
targets:
  main:
    entry: main
    platform: linux-x64
    cc: gcc
    cflags: [-O2, -Wall]
    flags: [release]
    output: bin/app

  debug:
    entry: main
    cc: gcc
    cflags: [-g, -O0]
    flags: [debug]
    output: bin/app_debug
```

### Multiple toolchains

Use `cc_path` when several compilers of the same name exist in different directories.

```yaml
targets:
  arm_firmware:
    entry: firmware/main
    platform: arm-cortex-m4
    cc: arm-none-eabi-gcc
    cc_path: /opt/arm-toolchain/bin
    cflags: [-mcpu=cortex-m4, -Os, -ffreestanding]
    flags: [release]
    output: bin/firmware.elf
```

### Custom mode — external build system

Set `build_cmd` instead of `cc`. The CLI generates C into `out:`, then runs the command.
Use this for SDKs with their own build system (Make, CMake, ESP-IDF, etc.).

```yaml
targets:
  esp_firmware:
    entry: firmware/main
    out: sdk/components/app/    # place generated C where SDK expects it
    build_cmd: make -C sdk/ -j4
    flags: [release, esp8266]
    output: sdk/build/firmware.bin
```

## Flags

The `flags` list is passed to the micro-panda preprocessor and controls `#if`/`#else`/`#end` blocks:

```yaml
flags: [debug, esp8266]
```

```python
#if debug
    log("debug mode")
#end

#if esp8266
    // esp-specific code
#end
```

Built-in conventions (not enforced, but recommended):

| Flag | Meaning |
|---|---|
| `debug` | Debug build |
| `release` | Release / optimised build |
| platform name | Target platform code paths |
