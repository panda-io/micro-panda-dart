# Memory and Allocator

## Everything is Static

Micro Panda has no heap. All memory is either:

- **Static storage** — global variables, arrays declared at module scope
- **Arena allocator** — backed by a static byte buffer you supply

There is no `malloc`, no `free` for individual objects, and no garbage collector.

---

## Static Variables

Scalars and arrays declared at module scope live in static memory:

```bash
val max_tasks: i32 = 8
var buffer: u8[1024]
```

---

## Allocator

`Allocator` is a generic arena allocator. It allocates objects from a byte slice and can be reset entirely at once.

### Implementation

```bash
class Allocator(val _memory: u8[])
    var _cursor: i32 = 0

    fun allocate<T>(): &T
        val size := sizeof<T>()
        if _cursor + size > _memory.size()
            return null
        val ptr := &T(&_memory[_cursor])
        _cursor += size
        return ptr
```

### Setup

```bash
var cache: u8[1024]
val allocator := Allocator(cache)
```

### Allocating Objects

```bash
val device := allocator.allocate<Device>()   # returns &Device or null
```

`sizeof<T>()` returns the byte size of type `T` at compile time. The generic call automatically passes it to the allocator.

### Checking for Null

```bash
val node := allocator.allocate<Node>()
if node == null
    // out of memory
```

---

## `sizeof<T>()`

Returns the byte size of a type at compile time:

```bash
val s := sizeof<i32>()     # 4
val s := sizeof<Point>()   # sizeof(struct Point) in C
```

Classic form also accepted:

```bash
val s := sizeof(i32)
```

---

## Usage Pattern

```bash
var task_pool: u8[4096]
val pool := Allocator(task_pool)

fun run_tasks()
    val t1 := pool.allocate<Task>()
    val t2 := pool.allocate<Task>()

    if t1 != null
        t1.run()
    if t2 != null
        t2.run()
```

---

## Arrays and Allocator

Arrays do not require an allocator — their storage is declared statically:

```bash
var expressions: Expr[10]   # static, no allocator needed
```
