# Classes

## Declaration

```python
class ClassName(
    val x: i32,
    val y: i32)

    val another_member: i32 = 123

    fun member_function()
        do_something()
```

## Constructor Parameters

Parameters listed in the class declaration line become **member fields** when annotated with `val` or `var`. Parameters without these modifiers are local to the constructor only.

```python
class Point(
    val x: i32,    # becomes a field
    val y: i32)    # becomes a field
```

## Additional Members

Extra fields can be declared in the class body with a default value:

```python
class Counter(
    val start: i32)

    var count: i32 = 0     # additional member with default
    val max: i32 = 100
```

## Member Functions

Member functions are declared inside the class body using `fun`. Use `this` to access the instance explicitly, or access fields directly:

```python
class Counter(val start: i32)
    var count: i32 = 0

    fun reset()
        count = start

    fun increment()
        count++

    fun value() i32
        return count

    fun copy_from(other: &Counter)
        count = other.count
        start = this.start    # explicit this when needed
```

## Instantiation

There is no `new` keyword. Call the class name directly.

**Global scope only** — class instances created without an allocator live in static memory for the lifetime of the program:

```python
# Global scope — OK, static lifetime
val _vm := VM()
val _uart := UART(0x4001_1000)
```

Inside a function, you must use an allocator:

```python
fun setup()
    val allocator := Allocator(buffer)
    val p: &Point = allocator.allocate(sizeof(Point))
```

See [Allocator](14_allocator.md) for details.

## No Inheritance

Micro Panda has no inheritance. Use **composition** instead:

```python
class Engine(val rpm: i32)
    fun run()
        ...

class Car(val engine: &Engine)
    fun drive()
        engine.run()
```

## No Interfaces

There are no interfaces. Use **tagged enums** to achieve polymorphic dispatch:

```python
enum Shape
    Circle(radius: float)
    Rectangle(width: float, height: float)

fun area(shape: &Shape) float
    match shape
        Circle(r):
            return 3.14159 * r * r
        Rectangle(w, h):
            return w * h
```

## Multiple Classes Per File

Multiple class definitions can coexist in the same `.mpd` file.
