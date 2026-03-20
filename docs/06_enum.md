# Enums

Micro Panda has three kinds of enums.

---

## 1. Plain Enum

Simple named constants. Values start at 0 and increment automatically.

```mpd
enum Color
    Red
    Green
    Blue
```

Usage:

```mpd
var c: Color = Color.Red
```

---

## 2. Value Enum

Each variant has an explicit integer value assigned.

```mpd
enum OpCode
    Add = 1
    Sub = 2
    Mul = 3
    Div = 4
```

Usage:

```mpd
var op: OpCode = OpCode.Add
```

---

## 3. Tagged Enum (Union Enum)

Variants carry data. This is similar to Rust enums or algebraic data types. Each variant defines its own fields.

```mpd
enum Expression
    Binary(left: &Expression, op: OpCode, right: &Expression)
    Unary(op: OpCode, exp: &Expression)
```

Construction (by variant name):

```mpd
var e: Expression
e = Expression.Binary(&left, op, &right)
e = Expression.Unary(op, &exp)
```

Matching (destructuring binds field values to local names):

```mpd
match expr
    Binary(left, op, right):
        ...
    Unary(op, exp):
        ...
```

> Recursive tagged enums use `&T` fields (e.g. `left: &Expression`) so the struct size stays fixed. The outer variable can be a value type (`var e: Expression`) or a reference (`var e: &Expression`) depending on usage. See [Match](08_match.md) for details.
