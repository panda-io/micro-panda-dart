# Getting Started

> **Note:** This section will be expanded once the toolchain is ready (installation, project setup, build commands, etc.)

## What is Micro Panda?

Micro Panda (`.mpd`) is a statically-typed, systems programming language designed for microcontrollers and embedded systems. It compiles to C (first milestone) and will later support LLVM targets including RISC-V.

The syntax is Python-like: indentation defines scope, no braces required.

## Design Philosophy

| Principle | Description |
| ---------- | ------------- |
| **No heap** | There is no dynamic heap allocation. All memory is static or allocator-managed. |
| **Everything static** | All types, sizes, and lifetimes are known at compile time. |
| **No GC** | No garbage collector. Memory management is explicit via arena allocators. |
| **No surprises** | No hidden costs, no implicit copies of complex types, no runtime exceptions. |
| **Compile to C** | The primary target is C, making it portable to any MCU with a C compiler. |

## Key Concepts

- **Static allocation** — variables and objects live in static memory or on the stack.
- **Allocator** — a built-in arena allocator backed by a static byte array; reset it in bulk when done (no fragmentation).
- **References** — references are pointers with syntax sugar; class types are always passed by reference.
- **No inheritance, no interfaces** — use composition and tagged enums instead.
- **Visibility by naming** — identifiers starting with `_` are private; all others are public.

## Compilation Pipeline

```bash
*.mpd  →  Micro Panda Compiler  →  *.c  →  C Compiler  →  binary
                                              (future: LLVM / RISC-V)
```
