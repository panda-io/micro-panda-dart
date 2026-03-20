# Types and Literals

## Primitive Types

| Type | Description |
| ---------- | ------------- |
| `bool` | Boolean (`true` / `false`) |
| `i8` | 8-bit signed integer |
| `u8` | 8-bit unsigned integer |
| `i16` | 16-bit signed integer |
| `u16` | 16-bit unsigned integer |
| `i32` | 32-bit signed integer (default int) |
| `u32` | 32-bit unsigned integer |
| `i64` | 64-bit signed integer |
| `u64` | 64-bit unsigned integer |
| `float` | 32-bit float (default float) |
| `fixed` | 16.16 fixed-point number |
| `void` | No value / absent return type |

> **Strings** — there is no dedicated string type. Strings are `u8[]` slices.

## String Literals

Single-line strings use double quotes:

```mpd
val msg: u8[] = "hello, world"
```

Multi-line strings use triple quotes — either `'''` or `"""`:

```mpd
val sql := """
    SELECT *
    FROM users
    WHERE active = 1
"""

val help := '''
usage: myapp <command>
  run     start the server
  stop    stop the server
'''
```

Both forms produce a `u8[]` slice. Leading/trailing newlines are included as written.

Supported escape sequences:

| Escape | Meaning |
| --- | --- |
| `\n` | newline |
| `\r` | carriage return |
| `\t` | tab |
| `\\` | backslash |
| `\"` | double quote |
| `\'` | single quote |
| `\0` | null byte |

String literals compile to C compound literals:

```c
(__Slice_uint8_t){ "hello", 5 }
```

---

## Integer Literals

```mpd
const decimal_int    = 98222
const hex_int        = 0xff
const another_hex    = 0xFF
const octal_int      = 0o755
const binary_int     = 0b11110000
```

Underscores can be placed between digits as a visual separator:

```mpd
const one_billion  = 1_000_000_000
const binary_mask  = 0b1_1111_1111
const permissions  = 0o7_5_5
const big_address  = 0xFF80_0000_0000_0000
```

## Float Literals

```mpd
const another_float = 123.0

# Underscores as visual separator
const lightspeed = 299_792_458.000_000
const nanosecond = 0.000_000_001
```

## Default Types for Untyped Literals

When no type is specified:

- Integer literals default to `i32`
- Float literals default to `float`
