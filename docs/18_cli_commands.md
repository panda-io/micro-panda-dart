# CLI Commands

The micro-panda compiler is invoked as `mpd` from the project root (where `mpd.yaml` lives).

```
mpd <command> [target] [options]
```

## Commands

### `gen` — Generate C only

Parses `.mpd` source files and writes the generated C file(s) to the `out/` directory.
**No compilation is performed.** Use this to inspect generated C without running a compiler.

```
mpd gen              # generate C for all targets
mpd gen <target>     # generate C for a specific target
```

Output: `out/<target>.c` (or the target's `out:` dir if overridden in mpd.yaml).

### `build` — Generate C and compile

Runs the full pipeline: parse → generate C → compile to executable (or run `build_cmd`).

```
mpd build            # build all targets
mpd build <target>   # build a specific target
```

### `run` — Build and run

Builds the target then immediately executes the output binary. Only meaningful for
host-native targets (not cross-compiled firmware).

```
mpd run <target>
```

### `clean` — Delete generated files

Removes the `out/` directory (generated C files) and the `bin/` directory (executables).
Per-target `out:` overrides are also cleaned.

```
mpd clean
```

## Options

| Flag | Description |
|---|---|
| `-v`, `--verbose` | Print each build step (files parsed, compiler command, etc.) |
| `-h`, `--help` | Show usage |

## Full workflow example

```
# 1. Inspect generated C first
mpd gen main -v

# 2. Build once satisfied
mpd build main

# 3. Run
mpd run main

# 4. Clean up
mpd clean
```

## Pipeline steps

For each target, the CLI executes these steps in order:

```
.mpd files
    │
    ▼  parse (Scanner + Parser)
  AST
    │
    ▼  generate (CGenerator)
  out/<target>.c
    │
    ├─ simple mode ──▶  cc [cflags] out/<target>.c -o <output>
    │
    └─ custom mode ──▶  build_cmd   (make, cmake, etc.)
```

`mpd gen` stops after writing `out/<target>.c`.
`mpd build` continues through to the compile/build step.
