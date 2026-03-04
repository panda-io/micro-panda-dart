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
# Explicit type annotation
var my_int: i32 = 0
var my_float: f32 = 1.0

# Type inference with :=
var inferred := 42        # type is i32
val inferred_f := 1.5     # type is f32

# Immutable — cannot reassign after initialization
val no_changed: i32 = 1
no_changed = 2            # compile error

# Compile-time constant
const MAX_TASK = 8
```

## Type Inference

Use `:=` to let the compiler infer the type from the right-hand side.
Using `=` without a type annotation is a **compile error**.

```python
var x := 100          # OK — inferred as i32
var y := 3.14         # OK — inferred as f32
var z = 100           # compile error — must use := or explicit type
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
