# Annotations

Annotations attach compile-time metadata to declarations. The compiler reads them
and changes how code is generated.

## Syntax

```
@annotation_name
fun my_function()

@annotation_name("template string")
fun my_function()
```

Annotations appear on their own line immediately before the declaration they apply to.
Multiple annotations can be stacked:

```
@extern("assert($condition)")
fun assert_true(condition: bool)
```

## `@extern`

Marks a function as externally defined (e.g. a C library function or macro).
The compiler will **not** emit a prototype or definition for it.
Instead, every call site is transformed according to the template rule.

### No template — call by function name

```
@extern
fun tick()
```

A call `tick()` emits `tick()` in C unchanged.

### C rename — no `$` placeholders

```
@extern("malloc")
fun alloc(size: u32) &u8
```

A call `alloc(64)` emits `malloc(64)`.

### Template with named placeholders

```
@extern("assert($condition)")
fun assert_true(condition: bool)

@extern("assert($a == $b)")
fun assert_i32_equal(a: i32, b: i32)
```

Each `$paramName` in the template is replaced by the corresponding argument expression.

| Call | C output |
|---|---|
| `assert_true(x > 0)` | `assert((x > 0))` |
| `assert_i32_equal(result, 42)` | `assert(result == 42)` |

## Future annotations (planned)

| Annotation | Intended use |
|---|---|
| `@test` | Mark test functions; collected by the test runner |
| `@inline` | Emit `static inline` |
| `@packed` | Emit `__attribute__((packed))` on a struct |

## Annotation type definitions (future — self-hosting)

When the micro panda compiler is rewritten in micro panda itself, annotation types
will be declared with `@interface`:

```
@interface
extern
    template: u8[]

@interface
test
```

The compiler will validate annotation usage against these definitions.
Until then, the set of known annotations is built into the Dart compiler.
