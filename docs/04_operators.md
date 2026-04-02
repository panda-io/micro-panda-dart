# Operators

## Arithmetic

| Operator | Description |
| ---------- | ------------- |
| `+` | Addition |
| `-` | Subtraction / unary negation |
| `*` | Multiplication |
| `/` | Division |
| `%` | Remainder |

## Bitwise

| Operator | Description |
| ---------- | ------------- |
| `&` | Bitwise AND |
| `\|` | Bitwise OR |
| `^` | Bitwise XOR |
| `~` | Bitwise complement (unary) |
| `<<` | Left shift |
| `>>` | Right shift |

## Comparison

| Operator | Description |
| ---------- | ------------- |
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

## Logical

| Operator | Description |
| ---------- | ------------- |
| `&&` | Logical AND |
| `\|\|` | Logical OR |
| `!` | Logical NOT (unary) |

## Assignment

| Operator | Description |
| ---------- | ------------- |
| `=` | Assign |
| `+=` | Add and assign |
| `-=` | Subtract and assign |
| `*=` | Multiply and assign |
| `/=` | Divide and assign |
| `%=` | Remainder and assign |
| `&=` | Bitwise AND and assign |
| `\|=` | Bitwise OR and assign |
| `^=` | Bitwise XOR and assign |
| `<<=` | Left shift and assign |
| `>>=` | Right shift and assign |

## Increment / Decrement

| Operator | Description |
| ---------- | ------------- |
| `++` | Increment by 1 |
| `--` | Decrement by 1 |

## Other

| Operator | Description |
| ---------- | ------------- |
| `&` (prefix) | Take reference (address-of) |
| `.` | Member access |
| `[]` | Index access |
| `()` | Call / grouping |

## Line continuation

Newlines inside `(` `)` and `[` `]` are ignored, so expressions can span multiple lines:

```mpd
var palette: u8[] = [
  0x00, 0x11, 0x22,
  0x33, 0x44, 0x55,
]

var result: i32 = foo(
  very_long_arg_a,
  very_long_arg_b,
)
```

Any indentation on continuation lines is allowed and has no effect on the block structure.
