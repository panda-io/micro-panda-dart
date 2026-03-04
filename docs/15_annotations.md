# Annotations

> **Status: Planned — next milestone**

Annotations allow the compiler to generate code based on metadata attached to declarations. The goal is to enable declarative patterns (similar to Spring Boot annotations) without runtime reflection.

## Planned Syntax

```python
@annotation_name
fun my_function()
    ...

@annotation_name(param: value)
class MyClass(val x: i32)
    ...
```

## Intended Use Cases

- Auto-generating register maps for peripherals
- Generating dispatch tables
- Marking interrupt handlers
- Build-time code generation driven by metadata

Details will be defined in a later milestone.
