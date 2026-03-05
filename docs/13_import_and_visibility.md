# Import and Visibility

## Module System

Micro Panda has no namespaces or packages. Like Dart, the file path is the module path.

---

## Importing

### Import a whole module

The last path segment becomes the qualifier:

```python
import util.math

var result := math::min(1, 2)
```

### Import a specific symbol

```python
import util.math::min

var result := min(1, 2)
```

### Import with alias

Alias a module:

```python
import util.math as m

var result := m::min(1, 2)
```

Alias a symbol:

```python
import util.math::min as minimum

var result := minimum(1, 2)
```

---

## Visibility

There are no `public` / `private` keywords. Visibility is determined by the name:

| Name | Visibility |
| ------ | ------------ |
| `my_function` | Public |
| `_my_function` | Private (starts with `_`) |
| `my_var` | Public |
| `_my_var` | Private (starts with `_`) |

This applies to functions, variables, constants, classes, and enum types.

```python
fun public_function()         # accessible from other files
    ...

fun _private_helper()         # only accessible within this file
    ...

var _internal_state: i32 = 0  # private variable
```
