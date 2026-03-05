# Arrays

Micro Panda has two array forms:

| Form | Syntax | C representation |
| --- | --- | --- |
| Fixed array | `T[N]` | `T name[N]` — inline storage |
| Slice | `T[]` | `struct { T* ptr; size_t size; }` — fat pointer |

---

## Fixed Arrays

Storage lives inline (on the stack or inside a struct). The size must be a compile-time constant.

```bash
var my_array: i32[10]       # 10 i32 values, inline
var buffer:   u8[256]       # 256-byte buffer, inline
```

`.size()` on a fixed array returns the compile-time literal:

```bash
var len := my_array.size()  # expands to the literal 10
```

---

## Slices

A slice is a fat pointer (pointer + length). Use `T[]` with no size:

```bash
fun process(data: u8[])
    var n := data.size()    # runtime .size field
    var b := data[0]        # data.ptr[0] in C
```

Only slices can be passed to functions (not fixed arrays). Fixed arrays convert to a slice implicitly at a call site.

---

## Subscript Semantics

| Element type | `arr[i]` returns |
| --- | --- |
| Scalar (`i32`, `u8`, …) | value (copy) |
| Class / struct | `&T` reference — no copy |

---

## .size()

```bash
var buf: u8[32]
var n := buf.size()         # compile-time 32

fun f(data: u8[])
    var n := data.size()    # runtime data.size field
```

---

## Address of an Element

Use `&` to take the address of an element:

```bash
var ptr: &u8 = &buf[4]     # pointer to 5th byte
```

---

## Arrays of Class Types

Indexing an array of struct/class types returns a **reference** to avoid a copy:

```bash
var expressions: Expr[10]
var e: &Expr = expressions[0]
```

---

## Array Initializer

```bash
var data := [1, 2, 3, 4, 5]   # inferred as i32[5]
```
