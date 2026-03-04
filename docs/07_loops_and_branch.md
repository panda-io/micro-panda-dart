# Loops and Branches

Micro Panda uses indentation to define blocks — no braces or `end` keywords.

---

## if / else

```python
if condition
    do_something()
else
    do_something_else()
```

Chained conditions:

```python
if x < 0
    handle_negative()
else if x == 0
    handle_zero()
else
    handle_positive()
```

---

## while

```python
while true
    do_something()

while count < MAX
    count++
```

---

## for — range loop

Iterates over a half-open range `[start, end)`:

```python
for i in range(0, 10)
    print(i)        # prints 0 through 9
```

---

## for — iterate collection

Iterate over items in an array:

```python
var data = [1, 2, 3, 4, 5]

for item in data
    print(item)
```

Iterate with index:

```python
for index, item in data
    print(index, item)
```

---

## break / continue

```python
while true
    if done
        break
    if skip
        continue
    process()
```
