# Loops and Branches

Micro Panda uses indentation to define blocks — no braces or `end` keywords.

---

## if / else

```mpd
if condition
    do_something()
else
    do_something_else()
```

Chained conditions:

```mpd
if x < 0
    handle_negative()
else if x == 0
    handle_zero()
else
    handle_positive()
```

---

## while

```mpd
while true
    do_something()

while count < MAX
    count++
```

---

## for — range loop

Iterates over a half-open range `[start, end)`:

```mpd
for i in range(0, 10)
    print(i)        # prints 0 through 9
```

---

## for — iterate collection

Iterate over items in an array or slice (by value):

```mpd
for item in data
    print(item)
```

Iterate with index:

```mpd
for index, item in data
    print(index, item)
```

### Reference iteration

Use `&` to iterate by reference, so the loop variable is a pointer to each element. This allows mutating elements in place:

```mpd
// clear all elements
for &item in data
    item = 0

// or with explicit type annotation
for item: &Handler in handlers
    item.active = false
```

Reference iteration works on both fixed arrays and slices. The loop variable has type `&T` (pointer to element), so field access uses `item.field` which compiles to `item->field`.

---

## break / continue

```mpd
while true
    if done
        break
    if skip
        continue
    process()
```
