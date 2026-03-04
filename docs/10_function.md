# Functions

## Syntax

```python
fun function_name(param1: Type1, param2: Type2) ReturnType
    body
```

- `fun` declares a function.
- Parameters use `name: Type` syntax.
- The return type comes after the parameter list.
- **No colon** after the function signature — indentation opens the body.
- The body is indented — no braces or `end`.

## Void Functions

If a function returns nothing, the return type can be omitted:

```python
fun greet(name: u8[])
    print(name)

# Equivalent explicit form
fun greet(name: u8[]) void
    print(name)
```

## Return Values

```python
fun add(x: i32, y: i32) i32
    return x + y

fun max(a: f32, b: f32) f32
    if a > b
        return a
    return b
```

## Multiple Parameters

```python
fun configure(address: u32, baud: u32, bits: u8) bool
    # ...
    return true
```

## Calling Functions

```python
var result := add(1, 2)
configure(0x4001_1000, 115200, 8)
```

## Scope

Indentation defines the function body. The first line at the same or lesser indentation as `fun` ends the function.

```python
fun foo()
    var x := 1
    var y := 2
    return x + y

# This line is outside foo
var z := foo()
```
