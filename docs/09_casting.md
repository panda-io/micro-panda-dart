# Type Casting

All type conversions in Micro Panda are **explicit**. There are no implicit numeric conversions.

## Syntax

Use the target type as a function call:

```python
target_type(value)
```

## Integer Casting

```python
var int32: i32 = 123

var int64 := i64(int32)   # widen to 64-bit
var int16 := i16(int32)   # narrow to 16-bit (truncates)
var uint  := u32(int32)   # signed → unsigned
```

## Float Casting

```python
var float32: float = 1.0

var float64 := f64(float32)   # widen to 64-bit
```

## Integer ↔ Float

```python
var f := float(42)       # integer to float
var i := i32(3.14)     # float to integer (truncates)
```

## Notes

- Narrowing conversions (e.g. `i32` → `i16`) truncate the value — no runtime check.
- There are no implicit promotions. Mixed-type expressions must cast explicitly.
