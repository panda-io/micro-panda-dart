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

Member functions are declared inside the class body using `fun`. They have implicit access to the instance's fields:

```python
class Counter(val start: i32)
    var count: i32 = 0

    fun reset()
        count = start

    fun increment()
        count++

    fun value() i32
        return count
```

## Instantiation

There is no `new` keyword. Call the class name directly:

```python
val p: &Point = Point(10, 20)
```

Classes are always held by reference. For allocator-based instantiation (e.g. when creating multiple instances at runtime), see [Allocator](14_allocator.md).

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
    Circle(radius: f32)
    Rectangle(width: f32, height: f32)

fun area(shape: &Shape) f32
    match shape
        Circle(r):
            return 3.14159 * r * r
        Rectangle(w, h):
            return w * h
```

## Multiple Classes Per File

Multiple class definitions can coexist in the same `.mpd` file.
