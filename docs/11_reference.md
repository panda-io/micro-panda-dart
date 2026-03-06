# References

References are pointers with syntax sugar. They always refer to a valid, statically-allocated object — there is no null reference.

## Taking a Reference

Use `&` to take the address of a variable:

```python
var int32: i32 = 123
var int32_ref: &i32 = &int32

# Mutate through reference
int32_ref = 456        # int32 is now 456
```

## Reference Types

Prefix any type with `&` to get its reference type:

```python
&i32          # reference to i32
&Device       # reference to Device
&Expression   # reference to Expression
```

## Passing Rules

### Scalar types (`bool`, `i8`–`u64`, `float`, `f64`, `fixed`)

Can be passed **by value** or **by reference**:

```python
fun double(x: i32) i32
    return x * 2

fun increment(x: &i32)
    x += 1
```

### Class types and tagged enums

Must **always** be passed by reference. There are no implicit struct copies.

```python
fun process(expr: &Expression)
    match expr
        Binary(left, op, right):
            ...
```

## References from Array Indexing

Indexing an array of class or tagged enum types returns a **reference** — not a copy:

```python
var expressions: Expression[10]

var expr1: &Expression = expressions[0]
var expr2: &Expression = expressions[1]
```

This avoids copying large structs when iterating or accessing elements.

## Null References

> **Status: TBD** — Whether references can be null and what the syntax looks like is not yet decided. Optional/nullable semantics will be designed once the core language is working.
