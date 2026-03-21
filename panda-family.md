# The Panda Language Family

A family of statically-typed systems languages sharing the same syntax style and philosophy,
each targeting a different domain and memory model.

---

## Family Members

| Language | Domain | Memory model | Backend |
|---|---|---|---|
| **pico-panda** | Tiny bytecode VM, embedded scripting | VM-managed | Custom bytecode |
| **micro-panda** | MCU + hosted systems, bare-metal | Manual (no GC, no RC) | C (permanent), LLVM IR (hosted) |
| **panda** | Modern systems applications | Reference counting (ARC), no GC | LLVM IR only |

---

## pico-panda

A tiny stack-based bytecode VM designed to run on severely constrained hardware.
`.ppd` source files compile to `.ppbc` bytecode via the `ppd` tool.
The VM is itself written in `micro-panda` and can be embedded in any host application.

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

**The C backend is permanent.** Many MCU platforms have no LLVM backend or a limited one.
C is the only viable universal compilation target, and `micro-panda` will always support it.

**Long-term roadmap:**

1. Dart compiler (current) — bootstrap stage, C backend only
2. Self-hosted compiler — rewritten in `micro-panda`, validated by compiling itself
3. LLVM IR backend — added to the self-hosted compiler for hosted platforms (AOT + JIT)
4. Embedded `libLLVM` + ORC JIT — `mpd run script.mpd` with near-native speed

---

## panda

A modern systems language born with LLVM. No C intermediary — LLVM IR is the only and
native target from day one.

**Key properties:**
- Same syntax style and philosophy as `micro-panda`
- Automatic memory management via reference counting (ARC) — no GC, no manual free
- Designed for applications where ergonomics matter alongside performance
- LLVM IR only — full optimization pipeline, cross-compilation, sanitizers out of the box

**Why LLVM-only:**
Targeting LLVM IR instead of C removes C's constraints entirely. Language features that
don't map cleanly to C — closures, sum types, first-class RC semantics, write barriers,
retain/release — all fit naturally at the IR level. `panda` can be designed purely around
what is right for the language, not what C can express.

**Why no GC:**
Reference counting gives automatic memory safety without GC pauses. Combined with LLVM's
optimization passes, `panda` programs run at near-native speed — significantly faster than
GC languages and Python in practice.

**Bootstrap path:**
`panda` is written in `micro-panda` and compiled via the `micro-panda` LLVM IR backend.
No separate bootstrap toolchain needed.

```plaintext
micro-panda (Dart)         →  C only, initial bootstrap
micro-panda (self-hosted)  →  C + LLVM IR, validates the language
panda compiler             →  written in micro-panda, targets LLVM IR
panda (self-hosted)        →  compiles itself
```

Each stage builds on the previous — no wasted work.

---

## Shared philosophy

- **Simple, readable syntax** — consistent across all three languages
- **No hidden costs** — what you write is what runs; no invisible GC, no runtime surprises
- **C interop** — `@extern` for calling C functions and libraries directly
- **Portable** — from a 256 KB microcontroller to a desktop server
- **Small toolchain** — `mpd` is a single binary; no complex build systems required

---

## Domain map

```plaintext
256 KB MCU, no OS          →  micro-panda  (C backend, bare-metal)
Embedded scripting layer   →  pico-panda   (bytecode VM, sandboxed)
Desktop / server app       →  panda        (LLVM IR, ARC, modern ergonomics)
Hosted CLI / tooling       →  micro-panda or panda  (both work)
```

---

## The name

**panda** — simple, memorable, and a natural progression from `micro-panda`.
The family shares a name because it shares a lineage: same syntax style, same philosophy,
built on each other's foundations.
