# Match

`match` is Micro Panda's pattern matching statement. It replaces `switch` and provides exhaustive matching for enums.

---

No colon after the `match` expression. Each arm ends with `:` as a separator between the pattern and its body.

## Match on Integer / Value

```python
match op_code
    0x01:
        return left + right
    0x02:
        return left - right
```

---

## Match on Plain Enum

```python
enum Color
    Red
    Green
    Blue

match color
    Color.Red:
        return "red"
    Color.Green:
        return "green"
    Color.Blue:
        return "blue"
    _:
        return "unknown"
```

The `_` arm is the wildcard / default case.

---

## Match on Tagged Enum (Destructuring)

Tagged enum variants can be destructured directly in the match arm, binding their fields to local variables:

```python
enum Expression
    Binary(left: &Expression, op: OpCode, right: &Expression)
    Unary(op: OpCode, exp: &Expression)

match expression
    Binary(left, op, right):
        print(left, op, right)
    Unary(op, exp):
        print(op, exp)
```

The field names in the pattern become local variable bindings for that arm's body.

---

## Exhaustiveness

The compiler checks that all variants are covered. Use `_` to handle remaining cases.
