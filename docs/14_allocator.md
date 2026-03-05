# Memory and Allocator

## Everything is Static

Micro Panda has no heap. All memory is either:

- **Static storage** — global variables, arrays declared at module scope
- **Stack-like allocator** — an arena allocator backed by a static byte buffer

There is no `malloc`, no `free` for individual objects, and no garbage collector.

---

## Static Variables

Scalars and arrays declared at module scope live in static memory:

```python
val max_tasks: i32 = 8
var buffer: u8[1024]
```

---

## Holding References vs Values

- **Scalar types** — can be held by value or by reference.
- **Class types** — always held by reference. There are no class values, only class references.

```python
import device::Device

val my_device: &Device = Device()
```

---

## Allocator

The `Allocator` is a built-in arena allocator. It allocates objects from a static byte array and can be **reset entirely** at once — no fragmentation, no per-object free.

### Setup

```python
val cache: u8[1024]
val allocator := Allocator(cache)
```

### Allocating Objects

```python
val device: &Device = allocator.allocate(sizeof(Device))
```

`sizeof(T)` returns the size of type `T` in bytes at compile time.

### Freeing

```python
allocator.free()   # resets the entire arena — all allocated objects become invalid
```

Use this when you are done with a group of objects and want to reclaim the full buffer for reuse.

---

## Usage Pattern

```python
val task_pool: u8[4096]
val pool := Allocator(task_pool)

fun run_tasks()
    val t1: &Task = pool.allocate(sizeof(Task))
    val t2: &Task = pool.allocate(sizeof(Task))

    t1.run()
    t2.run()

    pool.free()   # reclaim all task memory at once
```

---

## Arrays and Allocator

Arrays do not require an allocator — their storage is declared statically:

```python
var expressions: Expression[10]   # static, no allocator needed
```

To pass an array to a function by reference:

```python
fun fill(buf: &u8[])
    buf[0] = 0xFF
```
