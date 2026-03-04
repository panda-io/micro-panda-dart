# Variables

## Declarations

Micro Panda has three kinds of bindings:

| Keyword | Meaning |
|---------|---------|
| `var` | Mutable variable |
| `val` | Immutable binding — cannot be reassigned after initialization |
| `const` | Compile-time constant |

## Syntax

```python
# Explicit type
var my_int: i32 = 0
var my_float: f32 = 1.0

# Immutable binding
val no_changed = 1
no_changed = 2  # compile error

# Type inference with :=
var inferred := 42        # type is i32
val inferred_f := 1.5     # type is f32

# Compile-time constant
const MAX_TASK = 8
```

## Type Inference

Use `:=` to let the compiler infer the type from the right-hand side:

```python
var x := 100          # i32
var y := 3.14         # f32
val name := u8[64]    # u8 array of 64 bytes
```

## Default Types

When no type annotation is given and the literal has no explicit cast:

- Integer literal → `i32`
- Float literal → `f32`

## Constants

`const` values are resolved entirely at compile time and have no runtime storage:

```python
const MAX_TASK   = 8
const BAUD_RATE  = 115200
const PI         = 3.14159
```
