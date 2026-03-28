# The Panda Language Family

A family of statically-typed systems languages sharing the same syntax style and philosophy,
each targeting a different domain and memory model.

---

## Family Members

| Language | Domain | Memory model | Backend |
|---|---|---|---|
| **pico-panda** | Tiny bytecode VM, embedded scripting | VM-managed | Custom bytecode |
| **micro-panda** | MCU + hosted systems, bare-metal | Manual (no GC, no RC) | C only (permanent) |
| **panda** | Modern PC applications | Reference counting (ARC), no GC | LLVM IR only |

---

## pico-panda

A tiny stack-based bytecode VM designed to run on severely constrained hardware.
Source files compile to bytecode via the `ppd` tool.
The VM is itself written in `micro-panda`, so it compiles to C and can be embedded
in any host application — Godot, SDL2, bare-metal firmware, or any C-compatible environment.

Use when you need a safe, sandboxed scripting layer on a device with kilobytes of RAM.

---

## micro-panda

A small, pragmatic systems language that compiles to C.
Designed for microcontrollers (ESP32, Cortex-M, AVR, RISC-V) and STDC hosted environments.

**Key properties:**

- Statically typed, no implicit conversions
- No GC, no reference counting — programmer manages memory explicitly
- Compiles to readable C — works with any C toolchain
- Minimal runtime — suitable for bare-metal with no OS

**C is the only backend, and that is a permanent decision.**
Not all 32-bit MCU platforms support LLVM well. C is the universal compilation target
that works everywhere — from a $2 microcontroller to a hosted desktop build.
`micro-panda` does not need LLVM and will not pursue it.

**Compiler roadmap:**

1. Dart compiler (current) — bootstrap stage
2. Once `panda` is mature, the `panda` compiler hosts both `micro-panda` and `panda`

---

## panda

A modern systems language for PC platforms. No C intermediary — LLVM IR is the only
and native target from day one.

**Key properties:**

- Same syntax style and philosophy as `micro-panda`
- Automatic memory management via reference counting (ARC) — no GC, no manual free
- Modern language features not constrained by what C can express (closures, sum types, etc.)
- LLVM IR only — full optimization pipeline, cross-compilation, sanitizers out of the box
- Targets modern platforms: Linux, macOS, Windows — not MCUs

**Why LLVM-only:**
`panda` is designed purely around what is right for the language. Features that don't
map cleanly to C — closures, sum types, first-class RC semantics, write barriers —
fit naturally at the IR level. LLVM is mature on all modern PC platforms.

**Why no GC:**
Reference counting gives automatic memory safety without GC pauses. Combined with LLVM's
optimization passes, `panda` programs run at near-native speed.

**Bootstrap path:**

```plaintext
Dart   →  micro-panda compiler  (C backend, current)
Dart   →  panda compiler        (LLVM IR backend, initial bootstrap)

Once panda is mature:
panda  →  micro-panda compiler  (replaces Dart bootstrap)
panda  →  panda compiler        (self-hosted)
```

Each stage builds on the previous — no wasted work.

---

## pico-panda compiler

The pico-panda compiler is written in `micro-panda`. This is an important design point:
the compiler source is Micro-Panda, which generates C, which can be compiled and linked
into any host:

- **Godot** — embed pico-panda as a scripting engine alongside GDScript
- **SDL2** — a standalone game or app with a pico-panda scripting layer
- **ESP32 / bare-metal** — a programmable device that runs pico-panda programs from flash

The C output is self-contained and portable — no VM binary to distribute separately.

---

## Shared philosophy

- **Simple, readable syntax** — consistent across all three languages
- **No hidden costs** — what you write is what runs; no invisible GC, no runtime surprises
- **C interop** — `@extern` for calling C functions and libraries directly
- **Portable** — from a 256 KB microcontroller to a desktop server
- **Small toolchain** — single binary compilers; no complex build systems required

---

## Domain map

```plaintext
256 KB MCU, no OS          →  micro-panda  (C backend, bare-metal)
Embedded scripting layer   →  pico-panda   (bytecode VM, sandboxed, C-embeddable)
Desktop / server app       →  panda        (LLVM IR, ARC, modern ergonomics)
Hosted CLI / tooling       →  micro-panda  (C backend, simple and portable)
```

---

## The name

**panda** — simple, memorable, and a natural progression from `micro-panda`.
The family shares a name because it shares a lineage: same syntax style, same philosophy,
built on each other's foundations.
