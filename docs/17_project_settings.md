# Project Settings (mpd.yaml)

Every micro-panda project is configured by a single `mpd.yaml` file in the project root.
The CLI reads this file to discover sources, flags, and build targets.

## Minimal example

```yaml
name: my_project
version: 0.1.0

targets:
  main:
    entry: main
    src: src/
    type: bin
    flags: [DEBUG, HOSTED]
    output: bin/main
    cc:
      bin: gcc
      flags: [-g, -O0, -Wall]
```

## Full field reference

### Top-level fields

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | directory name | Project name |
| `version` | string | `0.1.0` | Project version |
| `targets` | map | — | Named build targets (see below) |
| `deps` | list | `[]` | Git-based dependencies (see [Dependencies](#dependencies)) |

### Target fields

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `entry` | string | yes | Entry module name, e.g. `main` or `firmware/main` |
| `type` | string | yes | `bin` — compile to binary; `c` — generate C only |
| `src` | string | no | Source folder for this target (default: `src/`) |
| `test` | string | no | Test files folder; enables `mpd test` for this target |
| `flags` | list | no | Micro-panda conditional compile flags (see [Flags](#flags)) |
| `out` | string | no | Output C file path, e.g. `main/esp32.c` (default: `out/<name>.c`) |
| `output` | string | no | Final executable path (used by `type: bin` targets) |
| `build_cmd` | string | no | Shell command run after C generation, e.g. `idf.py build` |
| `cc` | map | no | C compiler settings (see below) — required for `type: bin` |
| `gen` | map | no | Code-generation settings (see below) |

### `cc:` sub-node

C compiler settings. Used when `type: bin` or `build_cmd` is absent.

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `bin` | string | `gcc` | Compiler executable name |
| `path` | string | — | Directory containing `bin` (falls back to PATH if omitted) |
| `flags` | list | `[]` | Extra compiler flags, e.g. `[-O2, -Wall]` |

### `gen:` sub-node

Code-generation settings.

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `entry` | string | `main` | C entry function name (use `app_main` for ESP-IDF targets) |

## Target types

### `type: bin` — mpd drives compilation

mpd generates C then calls the compiler directly using the `cc:` settings.

```yaml
targets:
  main:
    entry: main
    src: src/
    type: bin
    flags: [DEBUG, HOSTED]
    output: bin/main
    cc:
      bin: gcc
      flags: [-g, -O0, -Wall]

  release:
    entry: main
    src: src/
    type: bin
    flags: [HOSTED]
    output: bin/main
    cc:
      bin: gcc
      flags: [-O2, -Wall]
```

### `type: c` — generate C only (external build system)

mpd writes the C file; an external tool (CMake, ESP-IDF, etc.) handles compilation.
Set `build_cmd` to run after generation when using `mpd build`.

```yaml
targets:
  esp32:
    entry: main
    src: src/
    out: main/esp32.c
    type: c
    flags: [MCU32]
    build_cmd: idf.py build
    gen:
      entry: app_main
```

### Multiple toolchains

Use `cc.path` when the compiler is not on PATH.

```yaml
targets:
  arm:
    entry: firmware/main
    src: src/
    type: bin
    flags: [MCU32]
    output: bin/firmware.elf
    cc:
      bin: arm-none-eabi-gcc
      path: /opt/arm-toolchain/bin
      flags: [-mcpu=cortex-m4, -Os, -ffreestanding]
```

## Tests

Set `test:` to a folder path to enable `mpd test` for that target.
Test files are discovered as `*_test.mpd` under that folder.
Tests inherit the target's `cc` and `flags` directly.

```yaml
targets:
  main:
    entry: main
    src: src/
    test: test/
    type: bin
    flags: [DEBUG, HOSTED]
    output: bin/main
    cc:
      bin: gcc
      flags: [-g, -O0, -Wall]
```

## Flags

The `flags` list is passed to the micro-panda preprocessor and controls `#if`/`#else`/`#end` blocks:

```yaml
flags: [DEBUG, MCU32]
```

```mpd
#if DEBUG
    log("debug mode")
#end

#if MCU32
    // MCU-specific code
#end
```

Built-in conventions (not enforced, but recommended):

| Flag | Meaning |
| --- | --- |
| `DEBUG` | Debug build |
| `HOSTED` | Running on a desktop OS (Linux / macOS / Windows) |
| `MCU32` | 32-bit microcontroller target |

## Dependencies

Git-based libraries are declared as a list under `deps:`.

```yaml
deps:
  - https://github.com/panda-io/led-driver@0.1.0
  - https://github.com/panda-io/udisplay@latest
```

Each entry is a URL with a version suffix after `@`. Use `@latest` to pull the default branch HEAD.

### How deps are fetched

- `mpd build` / `mpd gen` / `mpd test` — fetch missing deps on first use; skip if already cached.
- `mpd update` — force re-fetch all deps.
- Deps are cloned into `.micro-panda/deps/<name>/` where `<name>` comes from the dep's own `mpd.yaml` `name:` field.

### Lock file

`.micro-panda/deps.lock` records the resolved git commit for every dep.
Commit this file to make builds reproducible. Add `.micro-panda/deps/` to `.gitignore`.

### Importing from a dep

The dep's `name:` in its `mpd.yaml` is the import prefix. A dep named `led_driver` with a file at `src/pwm.mpd` is imported as:

```mpd
import led_driver.pwm
import led_driver.pwm::*
```

Within a dep, internal imports use bare names as usual (`import pwm`) — no prefix needed.
The dep author does not need to change import syntax when publishing.

### Library requirements

Every library intended for reuse must have a valid `name:` in its `mpd.yaml`.
The name must be a valid micro-panda identifier (start with a letter or `_`, alphanumeric and `_` only).
The tool validates this on first fetch and fails with a clear error if it is missing or invalid.
