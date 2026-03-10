# Micro Panda Compiler — Claude Context

## What this project is
A compiler for **Micro Panda** — a small, statically-typed systems language that compiles to C.
Designed for embedded MCUs (ESP32, Cortex-M) and STDC hosted environments.

## Repository layout
```
micro-panda-dart/          ← compiler (Dart)
  bin/main.dart            ← CLI entry point
  lib/src/
    scanner/               ← tokeniser + preprocessor
    parser/                ← recursive-descent parser
    ast/                   ← AST nodes (expression, statement, declaration, type)
    validator/             ← type checker (walks AST, sets .type on expressions)
    generator/c/           ← C code generator
      generator.dart       ← main driver + name-resolution tables
      generator_declaration.dart  ← functions, classes, variables
      generator_expression.dart   ← expressions, extern templates
      generator_statement.dart    ← statements
  test/                    ← Dart unit tests (180 tests)
  docs/                    ← language reference (Markdown)
  install.sh               ← compiles + installs mpd to ~/.local/bin
  micro-panda/std/         ← standard library (micro panda source)
    mpd.yaml               ← project config
    src/                   ← stdlib modules
    resource/              ← test resource files (hello.txt, lines.txt)
```

## Docs (docs/)
| File | Topic |
|---|---|
| 01_getting_started.md | Hello world, project setup |
| 02_values.md | Literals and types |
| 03_variables.md | var / val / const |
| 04_operators.md | Arithmetic, bitwise, logical |
| 05_array.md | Slices (u8[]) and fixed arrays (u8[N]) |
| 06_enum.md | Plain and tagged enums |
| 07_loops_and_branch.md | if / while / for / break / continue |
| 08_match.md | Match expressions |
| 09_casting.md | Type casts: `i32(expr)` |
| 10_function.md | Functions, generics |
| 11_reference.md | References (&T) |
| 12_class.md | Classes and generics |
| 13_import_and_visibility.md | import, visibility, namespacing |
| 14_allocator.md | Allocator pattern |
| 15_annotations.md | @extern, @inline, @test, @include |
| 16_macro.md | Preprocessor |
| 17_project_settings.md | mpd.yaml |
| 18_cli_commands.md | mpd build / test / run |
| 19_generics.md | Generic classes and functions |

## Standard library (micro-panda/std/src/)
| Module | Contents |
|---|---|
| console.mpd | write_byte, print_str, print_bool, print_u*/i*/float/fixed, println |
| test.mpd | _test_begin/end/pass/fail, _report() — used by @test runner |
| memory.mpd | Allocator class; allocate<T>(): &T, allocate_array<T>(n): T[] |
| collection.mpd | ArrayList<T>, LinkedList<T> (pool-based), RingBuffer<T> |
| file.mpd | File class (wraps C FILE*); open/close/read_bytes/write_bytes/read_line/write_str/flush/seek/tell; mode consts READ/WRITE/APPEND etc. |
| math.mpd | PI/TAU/E consts; min/max/clamp/abs<T> (generic @inline); sin/cos/tan/asin/acos/atan/atan2/sqrt/pow/floor/ceil/round (float, wraps math.h); floor_fixed/ceil_fixed/round_fixed |
| string.mpd | equals, starts_with, ends_with, index_of; sub, trim_start, trim_end, trim; token, skip; parse_u32, parse_i32, format_u32, format_i32 |

## Language features
- **Primitives**: bool, i8–u64, float (32-bit), fixed (16.16 = int32_t). No f64. No implicit conversions.
- **fixed** literals: `1.5` = 98304 raw, `1.0` = 65536 raw. Mul/div uses int64_t intermediate.
- **Strings**: `u8[]` slices → C compound literal `(__Slice_uint8_t){ptr, size}`
- **Arrays**: `u8[]` = slice, `u8[N]` = fixed C array. NOT interchangeable.
- **Generics**: `class Foo<T>()` and `fun bar<T>(...)` — monomorphized per type-arg set.
  - `&T` return → type-erased to void* (erasable). `T` or `T[]` return → monomorphized.
  - Call-site: `min<i32>(a, b)` → generates `min_int32_t`.
  - Param types substituted before arg validation so `min<fixed>(1.5, 2.0)` works correctly.
- **Casting**: `i32(expr)`, `u8(val)` — emits `(int32_t)(expr)` in C.
- **const**: `const PI := 3.14` (infer), `const MAX: i32 = 100` (explicit), `const S = "r"` (compat).
- **@extern**: `@extern("sinf({x})")` — `{paramName}` placeholders, `{buf}.ptr/.size` for slice fields.
- **@inline**: emits `static inline` on prototype and definition.
- **@test**: generates test runner main(); suppresses user main().
- **assert(expr)**: built-in, captures source text + file + line number.
- **.size()**: on slices/fixed arrays returns u32 (known to validator).

## Namespace / C name mangling
- Module `console`, function `print_str` → `console__print_str`
- Private names (`_foo`) → `static` linkage
- Generic specialization: `Allocator_allocate_array` + `_uint8_t` → `Allocator_allocate_array_uint8_t`
- `_setupModuleContext(mod)` builds per-module lookup tables before emitting each module.
- Specific symbol import (`import file::READ`): checks if symbol is var → `_localVarMap`; else → `_localCallMap`.

## Build and test commands
```bash
# Dart unit tests (run from repo root)
dart test                         # 180 tests

# Rebuild + install mpd binary
./install.sh                      # installs to ~/.local/bin/mpd

# Integration tests (run from micro-panda/std/)
mpd test                          # auto-discovers *_test.mpd
mpd test string_test.mpd          # specific file
```
Test binary cwd = project rootDir (`micro-panda/std/`), so resource paths are `resource/hello.txt`.

## Key pipeline files
| File | Role |
|---|---|
| lib/src/scanner/scanner.dart | Tokeniser |
| lib/src/parser/parser.dart | Entry; delegates to parser_*.dart parts |
| lib/src/parser/parser_declaration.dart | var/val/const/fun/class parsing |
| lib/src/parser/parser_statement.dart | Statements |
| lib/src/parser/parser_expression.dart | Expressions |
| lib/src/ast/expression/expression_invocation.dart | Call validation + type inference (generic subst here) |
| lib/src/ast/expression/expression_binary.dart | Binary op type checking |
| lib/src/ast/context.dart | Validation context, typesCompatible(), error reporting |
| lib/src/ast/type/type.dart | Base Type class + static singletons (Type.typeU32 etc.) |
| lib/src/generator/c/generator.dart | Main generator; _setupModuleContext, monomorphization |
| lib/src/generator/c/generator_declaration.dart | Emit functions/classes/vars; _emitFunctionDefSpecialized |
| lib/src/generator/c/generator_expression.dart | Emit expressions; _applyExtern for @extern templates |

## Important design decisions
- No implicit numeric conversions — use explicit casts `i32(x)`.
- No function overloading — use generics or distinct names.
- Bit manipulation on `fixed`: hex literals scale as fixed-point. Use `-1.0` as mask for floor (= 0xFFFF0000 as int32_t).
- ESP32 IDF VFS uses same C FILE* API as STDC — no conditional compilation needed in file.mpd.
- Trig: wrap `sinf/cosf` etc. (float). Game-specific fixed-point trig lookup table is separate (future).
- const `:=` added this session for type inference consistency with var/val.

## VSCode extension
Path: `/Users/sang/Dev/panda-io/micro-panda-vscode`
- `src/extension.ts` — activates MicroPandaTestRunner
- `src/testRunner.ts` — VS Code Testing API; watches *_test.mpd, runs `mpd test <absPath>`
- Build: `npm install && npm run compile`
- Pack: `./pack.sh`
- Setting: `microPanda.mpdPath` (default `"mpd"`)
