# Variables

## Declarations

Micro Panda has three kinds of bindings:

| Keyword | Meaning |
| ---------- | ------------- |
| `var` | Mutable variable — can be reassigned |
| `val` | Immutable binding — cannot be reassigned after initialization |
| `const` | Compile-time constant |

## Syntax

```python
# Explicit type annotation
var my_int: i32 = 0
var my_float: float = 1.0

# Type inference with :=
var inferred := 42        # type is i32
val inferred_f := 1.5     # type is float

# Immutable — cannot reassign after initialization
val no_change: i32 = 1
no_change = 2             # compile error: cannot assign to 'val' binding

# Compile-time constant
const MAX_TASK = 8
```

## Type Inference

Use `:=` to let the compiler infer the type from the right-hand side.
Using `=` without a type annotation is a **compile error**.

```python
var x := 100          # OK — inferred as i32
var y := 3.14         # OK — inferred as float
var z = 100           # compile error — must use := or explicit type
```

## Default Types

When no type annotation is given and the literal has no explicit cast:

- Integer literal → `i32`
- Float literal → `float`

## val with References

`val` prevents *rebinding* — the binding itself cannot point to a different object.
It does **not** affect mutability of the pointed-to data: field writes and method calls
through a `val` reference are allowed.

```python
class Point(var x: i32, var y: i32)

fun f()
    var p := Point(1, 2)
    var q := Point(3, 4)
    val r: &Point = &p

    r.x = 10        # OK — mutating through the reference is fine
    r.push()        # OK — calling methods is fine
    r = &q          # compile error: cannot assign to 'val' binding 'r'
```

> **Note:** `val` is a compiler-level restriction only.
> The generated C code is identical for `val` and `var` — no `const` is added.

## Constants

`const` values are resolved entirely at compile time and have no runtime storage:

```python
const MAX_TASK   = 8
const BAUD_RATE  = 115200
const PI         = 3.14159
```
