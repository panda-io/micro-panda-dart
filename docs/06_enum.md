# Enums

Micro Panda has three kinds of enums.

---

## 1. Plain Enum

Simple named constants. Values start at 0 and increment automatically.

```python
enum Color
    Red
    Green
    Blue
```

Usage:

```python
var c: Color = Color.Red
```

---

## 2. Value Enum

Each variant has an explicit integer value assigned.

```python
enum OpCode
    Add = 1
    Sub = 2
    Mul = 3
    Div = 4
```

Usage:

```python
var op: OpCode = OpCode.Add
```

---

## 3. Tagged Enum (Union Enum)

Variants carry data. This is similar to Rust enums or algebraic data types. Each variant defines its own fields.

```python
enum Expression
    Binary(left: &Expression, op: OpCode, right: &Expression)
    Unary(op: OpCode, exp: &Expression)
```

Usage:

```python
var expr: &Expression = ...

match expr
    Binary(left, op, right):
        ...
    Unary(op, exp):
        ...
```

> Tagged enum values must always be handled by reference (`&Expression`) because their size varies by variant. See [References](11_reference.md) and [Match](08_match.md) for details.
