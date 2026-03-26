# CLI Commands

The micro-panda compiler is invoked as `mpd` from the project root (where `mpd.yaml` lives).

```bash
mpd <command> [args] [options]
```

## Commands

### `init` — Create a new project

Creates `mpd.yaml` with a `main` target (using the `hosted-debug` template) and a stub `src/main.mpd`.

```bash
mpd init            # use current directory name as project name
mpd init <name>     # set an explicit project name
```

### `gen` — Generate C only

Parses `.mpd` source files and writes the generated C file.
**No compilation is performed.** Use this to inspect generated C or integrate with an external build system.

```bash
mpd gen              # generate C for all targets
mpd gen <target>     # generate C for a specific target
```

Output path is `out/<target>.c` by default, or the target's `out:` value if set.

### `build` — Generate C and compile

Runs the full pipeline: parse → generate C → compile to binary (or run `build_cmd`).

```bash
mpd build            # build all targets
mpd build <target>   # build a specific target
```

### `run` — Build and run

Builds the target then immediately executes the output binary.
Only meaningful for `type: bin` targets running on the host.

```bash
mpd run <target>
```

### `test` — Run tests

Compiles and executes all `*_test.mpd` files found in the target's `test:` folder.
Tests inherit the target's `cc` and `flags`.

```bash
mpd test             # test all targets that have a test: folder
mpd test <target>    # test a specific target
```

### `clean` — Delete generated files

Removes generated C files (`out/`) and compiled binaries (`bin/`).

```bash
mpd clean
```

### `target` — Manage targets

```bash
mpd target list                   # list available templates with descriptions
mpd target add <name> <template>  # append a new target to mpd.yaml
mpd target remove <name>          # remove a target from mpd.yaml
```

Available templates:

| Template | Description |
| --- | --- |
| `hosted-debug` | Desktop binary, debug build (gcc -g -O0) |
| `hosted-release` | Desktop binary, optimised release build (gcc -O2) |
| `esp32-debug` | ESP32 via ESP-IDF, debug build |
| `esp32-release` | ESP32 via ESP-IDF, release build |

## Options

| Flag | Description |
| --- | --- |
| `-C <dir>` | Project directory (where `mpd.yaml` lives). Defaults to cwd. |
| `-v`, `--verbose` | Print each build step (files parsed, compiler command, etc.) |
| `-h`, `--help` | Show usage |

## Typical workflow

```bash
# Create a new project
mkdir myapp && cd myapp
mpd init

# Add an ESP32 target
mpd target add esp32 esp32-release

# Inspect generated C
mpd gen main -v

# Build and run the hosted target
mpd build main
mpd run main

# Run tests
mpd test

# Clean up
mpd clean
```

## Pipeline

For each target, the CLI executes these steps in order:

```
.mpd files
    │
    ▼  parse + validate
  AST
    │
    ▼  generate (CGenerator)
  <out>.c
    │
    ├─ type: bin ────▶  cc [flags] <out>.c -o <output>
    │
    ├─ build_cmd ────▶  <build_cmd>   (idf.py, make, cmake…)
    │
    └─ type: c ──────▶  done (external build system takes over)
```

`mpd gen` stops after writing the C file.
`mpd build` continues through to the compile / build step.
