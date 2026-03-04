# Arrays

## Declaration

Arrays are statically sized. The size must be a compile-time constant. No allocator is needed — the storage is created statically.

```python
var my_array: i32[10]       # array of 10 i32 values
var buffer: u8[256]         # byte buffer of 256 bytes
```

## Initialization

```python
var data = [1, 2, 3, 4, 5]  # inferred as i32[5]
```

## Accessing Elements

```python
my_array[0] = 42
var x := my_array[3]
```

## Length

```python
var len := my_array.size()
```

## Passing to Functions

When used as a function parameter, the size is not specified — the array is passed as a reference to its data along with its length metadata:

```python
fun process(another_array: i32[])
    var n := another_array.size()
```

> Arrays always carry their length. No need to pass the size separately.

## Memory Layout

An array value consists of:
1. A length field
2. Contiguous element storage

## Arrays of Class / Union Enum Types

Indexing an array of class or union enum types returns a **reference** (not a copy) to avoid struct copies:

```python
var expressions: Expression[10]

var expr1: &Expression = expressions[0]
var expr2: &Expression = expressions[1]
```

## Passing Arrays by Reference

To pass an array explicitly by reference (e.g. to allow modification):

```python
fun fill(buf: &u8[])
    buf[0] = 0xFF
```
