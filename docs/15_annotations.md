# Annotations

Annotations attach compile-time metadata to declarations or module-level blocks.
The compiler reads them and changes how code is generated.

## Syntax

```mpd
@annotation_name
fun my_function()

@annotation_name("template string")
fun my_function()
```

Annotations appear on their own line immediately before the declaration they apply to.
Multiple annotations can be stacked:

```mpd
@inline
@extern("sinf({x})")
fun sin(x: float): float
```

Template strings can span multiple lines using triple-quoted strings:

```mpd
@extern('''
    sinf({x})
''')
fun sin(x: float): float
```

---

## `@extern`

Marks a function as externally defined (a C library function, macro, or expression).
The compiler will **not** emit a prototype or definition for it.
Instead, every call site is expanded according to the template.

### No template — call by name

```mpd
@extern
fun tick()
```

A call `tick()` emits `tick()` in C unchanged.

### C rename

```mpd
@extern("malloc")
fun alloc(size: u32): &u8
```

A call `alloc(64)` emits `malloc(64)`.

### Template with named placeholders

Each `{paramName}` is replaced by the corresponding argument expression at the call site.

```mpd
@extern("sinf({x})")
fun sin(x: float): float

@extern("{buf}.ptr")
fun buf_ptr(buf: u8[]): &u8
```

For slice parameters, `{buf}.ptr` and `{buf}.size` access the pointer and length fields.

### Multi-statement templates

When a template contains multiple C statements (or preprocessor directives), use a
triple-quoted string. The first line starting with `#` signals a multi-statement block:
each line is emitted separately, with `;` appended to C lines that need it.

```mpd
@extern('''
    signal(SIGINT,  (void(*)(int)){handler});
    signal(SIGTERM, (void(*)(int)){handler});
    #ifndef _WIN32
    signal(SIGHUP,  (void(*)(int)){handler});
    #endif
''')
fun _watch_signals(handler: fun(i32))
```

When the template is a single C expression spanning multiple lines (e.g. a GCC
statement expression `({ ... })`), the entire block is treated as one expression and
gets a single trailing `;` at the call site:

```mpd
@extern('''({
    struct timespec __ts;
    clock_gettime(CLOCK_MONOTONIC, &__ts);
    (int64_t)__ts.tv_sec * 1000000LL + __ts.tv_nsec / 1000LL;
})''')
fun time_us(): i64
```

### Restrictions

- `@extern` functions cannot be used as function references (no stable C address).
- `@extern` with a zero-arg no-placeholder template (e.g. a global variable name or
  a `sizeof` expression) is emitted verbatim — useful for accessing C variables:

```mpd
@extern("__mp_argc")
fun _argc(): i32
```

---

## `@inline`

Emits `static inline` on both the prototype and the definition, letting the C compiler
inline each call site.

```mpd
@inline
fun min(a: i32, b: i32): i32
    if a < b
        return a
    return b
```

Generated C:

```c
static inline int32_t min(int32_t a, int32_t b) {
    if (a < b) return a;
    return b;
}
```

- Implies `static` linkage.
- `@inline` functions should not be used as function references (no stable address).

---

## `@test`

Marks a function as a test case. Test functions are collected by the test runner and
called automatically when you run `mpd test`.

```mpd
@test
fun test_add()
    assert(1 + 1 == 2)
```

- No parameters, no return value.
- `@test` suppresses the user `main()` — the test runner provides its own.
- Run all tests: `mpd test`
- Run a specific file: `mpd test my_test.mpd`

---

## `@raw`

Emits a raw C string verbatim at the top of the generated `.c` file, before any
declarations. Use this for `#include` directives and other file-level C preamble.

```mpd
@raw("#include <stdio.h>")
```

Triple-quoted strings are supported for multi-line blocks:

```mpd
@raw('''
#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif
''')
```

`@raw` can appear before any top-level declaration (or standalone). All `@raw` blocks
in a module are collected and emitted together after the standard `#include <stdint.h>`
/ `#include <stdbool.h>` / `#include <stddef.h>` preamble.
