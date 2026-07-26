# Python Interview Cheatsheet — Written Test Edition

 *Built for written/quiz-style Python tests: core syntax, gotchas, output-prediction traps, and the "why" behind each answer.*

 ---

 ## 1. Mutable vs. Immutable Types

 **Immutable:** `int`, `float`, `str`, `tuple`, `bool`, `frozenset` **Mutable:** `list`, `dict`, `set`, custom objects (by default)

 ```python
def add_item(item, bucket=[]):   # classic trap
    bucket.append(item)
    return bucket

print(add_item(1))  # [1]
print(add_item(2))  # [1, 2]  <- surprise! default args are evaluated ONCE
```

 **Fix:** use `bucket=None` and `bucket = bucket or []` inside the function.

 ---

 ## 2. `==` vs. `is`

 - `==` compares **values**.
- `is` compares **identity** (same object in memory).

 ```python
a = [1, 2]
b = [1, 2]
a == b   # True
a is b   # False
```

 Small ints (-5 to 256) and short strings are cached by CPython, so `is` can *look* True for them — never rely on this.

 ---

 ## 3. List Comprehension vs. Generator Expression

 ```python
squares_list = [x**2 for x in range(5)]   # builds the whole list in memory
squares_gen  = (x**2 for x in range(5))   # lazy, one value at a time
```

 **Clever framing:** "A list comprehension hands you the whole cake; a generator hands you one slice at a time when you ask."

 ---

 ## 4. `*args` and `**kwargs`

 ```python
def f(*args, **kwargs):
    print(args)    # tuple of positional args
    print(kwargs)  # dict of keyword args

f(1, 2, x=3, y=4)  # (1, 2)  {'x': 3, 'y': 4}
```

 Order in a function signature: `positional, *args, keyword-only, **kwargs`.

 ---

 ## 5. Shallow Copy vs. Deep Copy

 ```python
import copy
a = [[1, 2], [3, 4]]
b = a.copy()          # or list(a) — shallow
c = copy.deepcopy(a)  # deep

b[0][0] = 99
print(a)  # [[99, 2], [3, 4]] <- inner list is shared!
c[0][0] = -1
print(a)  # unaffected
```

 ---

 ## 6. Decorators

 A decorator is a function that wraps another function to extend its behavior without modifying its code.

 ```python
def timer(func):
    def wrapper(*args, **kwargs):
        print(f"Calling {func.__name__}")
        return func(*args, **kwargs)
    return wrapper

@timer
def greet(name):
    return f"Hi {name}"
```

 `@timer` above `def greet` is just sugar for `greet = timer(greet)`.

 ---

 ## 7. Generators & `yield`

 ```python
def counter(n):
    for i in range(n):
        yield i

gen = counter(3)
next(gen)  # 0
next(gen)  # 1
```

 `yield` pauses execution and preserves local state between calls — this is what makes generators memory-efficient for large or infinite sequences.

 ---

 ## 8. `*args` unpacking / iterable unpacking

 ```python
a, *rest = [1, 2, 3, 4]
print(a, rest)   # 1 [2, 3, 4]

first, *middle, last = [1, 2, 3, 4, 5]
print(first, middle, last)  # 1 [2, 3, 4] 5
```

 ---

 ## 9. String Formatting

 ```python
name, age = "Sam", 30
f"{name} is {age}"          # f-string (preferred)
"{} is {}".format(name, age)
"%s is %d" % (name, age)    # legacy
```

 ---

 ## 10. `range()`, `enumerate()`, `zip()`

 ```python
for i, val in enumerate(["a", "b", "c"], start=1):
    print(i, val)   # 1 a / 2 b / 3 c

for x, y in zip([1, 2], ["a", "b"]):
    print(x, y)     # 1 a / 2 b
```

 `zip` stops at the **shortest** iterable — a common gotcha with mismatched lengths.

 ---

 ## 11. Exception Handling

 ```python
try:
    1 / 0
except ZeroDivisionError as e:
    print(f"Caught: {e}")
else:
    print("Runs if no exception")
finally:
    print("Always runs")
```

 Catch specific exceptions first — a bare `except:` swallows everything, including `KeyboardInterrupt`.

 ---

 ## 12. Custom Exceptions

 ```python
class InsufficientFundsError(Exception):
    pass

def withdraw(balance, amount):
    if amount > balance:
        raise InsufficientFundsError("Not enough funds")
    return balance - amount
```

 ---

 ## 13. `*` Args Ordering / Keyword-Only Arguments

 ```python
def f(a, b, *, c):   # c MUST be passed by keyword
    return a + b + c

f(1, 2, c=3)   # OK
f(1, 2, 3)     # TypeError
```

 ---

 ## 14. OOP: `self`, `__init__`, Class vs. Instance Attributes

 ```python
class Dog:
    species = "Canis familiaris"   # class attribute — shared

    def __init__(self, name):
        self.name = name            # instance attribute — unique per object

d1 = Dog("Rex")
d2 = Dog("Fido")
Dog.species = "Wolf"
print(d1.species, d2.species)  # Wolf Wolf (shared!)
```

 ---

 ## 15. Inheritance & `super()`

 ```python
class Animal:
    def speak(self):
        return "..."

class Dog(Animal):
    def speak(self):
        return super().speak() + " Woof!"
```

 ---

 ## 16. `@staticmethod` vs `@classmethod` vs instance method

 ```python
class MyClass:
    def instance_method(self):    # needs an instance, gets self
        return "instance"

    @classmethod
    def class_method(cls):        # gets the class, not instance
        return "class"

    @staticmethod
    def static_method():          # gets neither — just a namespaced function
        return "static"
```

 ---

 ## 17. `__str__` vs `__repr__`

 `__str__` is for a human-readable/print-friendly output. `__repr__` is for an unambiguous, developer-facing output — ideally something that could recreate the object. If `__str__` isn't defined, Python falls back to `__repr__`.

 ---

 ## 18. Dictionary Comprehension & `.get()`

 ```python
squares = {x: x**2 for x in range(5)}
d = {"a": 1}
d.get("b", 0)     # 0 — no KeyError
d["b"]            # KeyError!
```

 ---

 ## 19. Sorting: `sort()` vs `sorted()`

 ```python
lst = [3, 1, 2]
lst.sort()             # in-place, returns None
new_lst = sorted(lst)  # returns a new list

people = [{"name": "A", "age": 30}, {"name": "B", "age": 25}]
sorted(people, key=lambda p: p["age"])
```

 ---

 ## 20. `lambda` Functions

 ```python
square = lambda x: x ** 2
add = lambda a, b: a + b
```

 Use for short, throwaway functions — passed to `sorted()`, `map()`, `filter()`. Avoid for anything needing a docstring or multiple statements.

 ---

 ## 21. `map()`, `filter()`, `reduce()`

 ```python
from functools import reduce
nums = [1, 2, 3, 4]
list(map(lambda x: x * 2, nums))     # [2, 4, 6, 8]
list(filter(lambda x: x % 2 == 0, nums))  # [2, 4]
reduce(lambda a, b: a + b, nums)     # 10
```

 ---

 ## 22. `*` Unpacking in Function Calls

 ```python
def add(a, b, c):
    return a + b + c

nums = [1, 2, 3]
add(*nums)          # unpacks list as positional args

d = {"a": 1, "b": 2, "c": 3}
add(**d)             # unpacks dict as keyword args
```

 ---

 ## 23. GIL (Global Interpreter Lock)

 The GIL allows only one thread to execute Python bytecode at a time, even on multi-core machines. **Threading** is still useful for I/O-bound work (waiting on network/disk), but for CPU-bound parallelism you need **multiprocessing** (separate processes, separate memory, no GIL contention).

 **Clever framing:** "The GIL doesn't stop concurrency — it stops CPU-bound parallelism. I/O-bound threads are fine because they spend their time waiting, not computing."

 ---

 ## 24. Context Managers (`with`)

 ```python
class FileManager:
    def __enter__(self):
        print("Opening")
        return self
    def __exit__(self, exc_type, exc_val, exc_tb):
        print("Closing")
        return False   # False = don't suppress exceptions

with FileManager() as fm:
    print("Working")
```

 `__exit__` runs even if an exception is raised inside the `with` block — this is why `with open(...)` is preferred over manual `open()`/`close()`.

 ---

 ## 25. Truthy / Falsy Values

 Falsy: `0`, `0.0`, `""`, `[]`, `{}`, `set()`, `None`, `False` Everything else is truthy — including `"0"` (non-empty string) and `[0]` (non-empty list).

 ---

 ## 26. `is None` vs `== None`

 Always prefer `if x is None:` — `is` checks identity against the singleton `None` object and can't be fooled by an overridden `__eq__`.

 ---

 ## 27. Sets and their operations

 ```python
a = {1, 2, 3}
b = {2, 3, 4}
a | b   # union {1,2,3,4}
a & b   # intersection {2,3}
a - b   # difference {1}
a ^ b   # symmetric difference {1,4}
```

 ---

 ## 28. Slicing Tricks

 ```python
s = "hello world"
s[::-1]     # reverse: "dlrow olleh"
s[::2]      # every 2nd char
lst[:3]     # first 3
lst[-3:]    # last 3
```

 ---

 ## 29. `try`/`except`/`else`/`finally` Execution Order Gotcha

 ```python
def f():
    try:
        return 1
    finally:
        print("finally runs even after return!")

f()  # prints "finally runs even after return!" then returns 1
```

 ---

 ## 30. Common Output-Prediction Traps

 ```python
# Trap 1: late binding closures
funcs = [lambda: i for i in range(3)]
print([f() for f in funcs])  # [2, 2, 2] not [0, 1, 2]

# Trap 2: chained comparisons
print(1 < 2 < 3)   # True — equivalent to (1<2) and (2<3)

# Trap 3: integer division
print(7 // 2)      # 3
print(7 / 2)        # 3.5
print(-7 // 2)      # -4 (floors toward negative infinity, not zero!)

# Trap 4: mutable default in class
class C:
    items = []
    def add(self, x):
        self.items.append(x)  # shared across ALL instances if not in __init__
```

 ---

 ### Quick recall table

 | Topic | One-line hook |
| --- | --- |
| Mutable default args | Evaluated once, at definition time |
| `is`vs`==` | Identity vs. value |
| List comp vs generator | Whole cake vs. one slice |
| GIL | Blocks CPU parallelism, not I/O concurrency |
| `__str__`vs`__repr__` | Human-readable vs. dev-unambiguous |
| Shallow vs deep copy | Shared inner objects vs. fully independent |
| `finally` | Always runs, even after`return` |
| Floor division`//` | Rounds toward negative infinity |