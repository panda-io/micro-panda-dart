# Generics

Micro Panda supports generic functions with one or more type parameters.

## Syntax

```bash
fun name<T>(params): ReturnType
    body
```

Type parameters go between `<` and `>` after the function name.

## Example

```bash
fun identity<T>(ptr: &T): &T
    return ptr
```

## How It Compiles

Generic functions are **not** monomorphized. Instead, the compiler generates a single C function using `void*` for the generic return type and a hidden `size_t __sizeof_T` parameter for each type parameter.

```bash
fun allocate<T>(): &T
    val size := sizeof<T>()
    ...
```

Generates:

```c
void* Allocator_allocate(Allocator* this, size_t __sizeof_T) {
    const uint64_t size = __sizeof_T;
    ...
}
```

## Call Sites

```bash
val ptr := allocator.allocate<Point>()
```

Compiles to:

```c
Point* ptr = (Point*)Allocator_allocate(&allocator, sizeof(Point));
```

The compiler automatically:

1. Adds `sizeof(TypeArg)` as an extra argument
2. Casts the `void*` return to `TypeArg*`

## `sizeof<T>()`

Inside a generic function body, `sizeof<T>()` expands to the hidden `__sizeof_T` parameter:

```bash
fun alloc<T>(): &T
    val size := sizeof<T>()   # → __sizeof_T in C
```

Outside a generic body, `sizeof<T>()` (or `sizeof(T)`) emits `sizeof(T)` in C.

## Pointer Cast `&T(expr)`

Inside a generic body, `&T(expr)` casts `expr` to `void*`:

```bash
val ptr := &T(&buf[offset])   # → void* ptr = (void*)(&buf.ptr[offset]);
```

At the call site, the returned `void*` is cast to the concrete type.

## `null`

The `null` literal compiles to `NULL`:

```bash
fun alloc<T>(): &T
    return null       # → return NULL;
```

## Limitations

- Only functions support generics (not classes)
- Only one type parameter per function is currently recommended
- No type constraints or bounds
