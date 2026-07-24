# Python Interview Cheatsheet

 ## 1. Data Types & Basics

 ```python
# Numbers
x = 5          # int
y = 5.0        # float
z = 5 + 2j     # complex

# Type conversion
int("5")       # 5
str(5)         # "5"
float("5.5")   # 5.5

# Common operators
7 // 2   # 3  (floor division)
7 % 2    # 1  (modulo)
2 ** 10  # 1024 (exponent)
```

 ## 2. Strings

 ```python
s = "hello world"
s.upper()              # "HELLO WORLD"
s.split()               # ['hello', 'world']
s.replace("h", "H")     # "Hello world"
s[::-1]                 # reverse string
s.strip()               # remove leading/trailing whitespace
"".join(["a", "b"])     # "ab"
s.find("wor")           # index or -1
f"{s} has {len(s)} chars"  # f-strings

# Check types
s.isalpha(), s.isdigit(), s.isalnum()
```

 ## 3. Lists

 ```python
lst = [3, 1, 4, 1, 5]

lst.append(9)          # add to end
lst.insert(0, 100)      # insert at index
lst.pop()                # remove & return last
lst.pop(0)               # remove & return index 0
lst.remove(1)            # remove first occurrence of value
lst.sort()               # in-place sort
sorted(lst, reverse=True)  # new sorted list
lst.reverse()             # in-place reverse

# Slicing
lst[1:3]     # elements 1,2
lst[:-1]     # all but last
lst[::2]     # every other element

# List comprehension
squares = [x**2 for x in range(10)]
evens = [x for x in range(20) if x % 2 == 0]

# Useful builtins
len(lst), max(lst), min(lst), sum(lst)
```

 ## 4. Dictionaries

 ```python
d = {"a": 1, "b": 2}

d.get("c", 0)         # default value if missing
d.setdefault("c", 0)  # set if missing, return value
d.keys(), d.values(), d.items()
d.pop("a")             # remove and return value

# Iterate
for k, v in d.items():
    print(k, v)

# Dict comprehension
squares = {x: x**2 for x in range(5)}

# Counting pattern
from collections import Counter
freq = Counter("aabbbc")   # Counter({'b': 3, 'a': 2, 'c': 1})
```

 ## 5. Sets & Tuples

 ```python
s = {1, 2, 3}
s.add(4)
s.union({5,6})
s.intersection({2,3,7})
s.difference({2})

t = (1, 2, 3)   # immutable
a, b, c = t     # unpacking
```

 ## 6. Tuples/Sets — Common Uses in Interviews

 ```python
# Swap variables
a, b = b, a

# Multiple return values
def min_max(lst):
    return min(lst), max(lst)
```

 ## 7. Collections Module

 ```python
from collections import defaultdict, deque, Counter, OrderedDict

# defaultdict - avoid KeyError
graph = defaultdict(list)
graph["a"].append("b")

# deque - O(1) append/pop both ends (use for queues/BFS)
dq = deque([1, 2, 3])
dq.appendleft(0)
dq.popleft()

# Counter - frequency counting
Counter([1,1,2,3]).most_common(2)  # [(1, 2), (2, 1)]
```

 ## 8. Functions

 ```python
def add(a, b=10, *args, **kwargs):
    return a + b

# Lambda
square = lambda x: x ** 2

# map / filter / reduce
list(map(lambda x: x*2, [1,2,3]))
list(filter(lambda x: x % 2 == 0, [1,2,3,4]))
from functools import reduce
reduce(lambda a, b: a + b, [1,2,3,4])  # 10

# Decorators (basic pattern)
def timer(func):
    def wrapper(*args, **kwargs):
        result = func(*args, **kwargs)
        return result
    return wrapper
```

 ## 9. Classes / OOP

 ```python
class Animal:
    def __init__(self, name):
        self.name = name

    def speak(self):
        return f"{self.name} makes a sound"

class Dog(Animal):
    def speak(self):
        return f"{self.name} barks"

# Common dunder methods
class Point:
    def __init__(self, x, y):
        self.x, self.y = x, y
    def __repr__(self):
        return f"Point({self.x}, {self.y})"
    def __eq__(self, other):
        return self.x == other.x and self.y == other.y
```

 ## 10. Sorting with Keys

 ```python
people = [("Alice", 30), ("Bob", 25)]
sorted(people, key=lambda p: p[1])              # by age
sorted(people, key=lambda p: -p[1])              # descending
sorted(strings, key=len)                          # by length

import heapq
heapq.heapify(lst)          # min-heap in place
heapq.heappush(lst, 5)
heapq.heappop(lst)          # smallest element
heapq.nlargest(3, lst)
heapq.nsmallest(3, lst)
```

 ## 11. Common Algorithm Patterns

 **Two Pointers**

 ```python
def two_sum_sorted(arr, target):
    l, r = 0, len(arr) - 1
    while l < r:
        s = arr[l] + arr[r]
        if s == target:
            return [l, r]
        elif s < target:
            l += 1
        else:
            r -= 1
    return []
```

 **Sliding Window**

 ```python
def max_sum_subarray(arr, k):
    window_sum = sum(arr[:k])
    max_sum = window_sum
    for i in range(k, len(arr)):
        window_sum += arr[i] - arr[i - k]
        max_sum = max(max_sum, window_sum)
    return max_sum
```

 **BFS (using deque)**

 ```python
from collections import deque

def bfs(graph, start):
    visited = {start}
    queue = deque([start])
    order = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    return order
```

 **DFS (recursive)**

 ```python
def dfs(graph, node, visited=None):
    if visited is None:
        visited = set()
    visited.add(node)
    for neighbor in graph[node]:
        if neighbor not in visited:
            dfs(graph, neighbor, visited)
    return visited
```

 **Binary Search**

 ```python
def binary_search(arr, target):
    lo, hi = 0, len(arr) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1
```

 **Dynamic Programming (memoization)**

 ```python
from functools import lru_cache

@lru_cache(maxsize=None)
def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)
```

 ## 12. Big-O Cheat Sheet

 | Structure | Access | Search | Insert | Delete |
| --- | --- | --- | --- | --- |
| List | O(1) | O(n) | O(n) | O(n) |
| Dict/Set (hash) | O(1)* | O(1)* | O(1)* | O(1)* |
| Deque | O(n) | O(n) | O(1)** | O(1)** |
| Heap | O(1) min | O(n) | O(log n) | O(log n) |

 * average case ** at either end

 | Sorting | Best | Average | Worst | Space |
| --- | --- | --- | --- | --- |
| Timsort (Python's`sort`) | O(n) | O(n log n) | O(n log n) | O(n) |
| Quicksort | O(n log n) | O(n log n) | O(n²) | O(log n) |
| Mergesort | O(n log n) | O(n log n) | O(n log n) | O(n) |

 ## 13. Gotchas Interviewers Like to Probe

 ```python
# Mutable default argument trap
def bad(x, lst=[]):   # DON'T - shared across calls
    lst.append(x)
    return lst

def good(x, lst=None):
    if lst is None:
        lst = []
    lst.append(x)
    return lst

# Shallow vs deep copy
import copy
a = [[1,2], [3,4]]
b = a.copy()            # shallow - nested lists shared
c = copy.deepcopy(a)    # deep - fully independent

# is vs ==
a = [1,2,3]
b = [1,2,3]
a == b   # True (value equality)
a is b   # False (different objects)

# Integer caching (-5 to 256 are cached singletons)
a = 256; b = 256
a is b   # True
a = 257; b = 257
a is b   # False (implementation detail, don't rely on it)
```

 ## 14. Quick Syntax Reference

 ```python
# List/dict/set unpacking
first, *rest = [1, 2, 3, 4]     # first=1, rest=[2,3,4]
a, *_, last = [1,2,3,4,5]        # a=1, last=5

# Ternary
x = "even" if n % 2 == 0 else "odd"

# Enumerate & zip
for i, val in enumerate(lst):
    pass
for a, b in zip(list1, list2):
    pass

# String formatting
f"{value:.2f}"     # 2 decimal places
f"{num:,}"          # thousands separator
f"{num:>10}"        # right-align width 10

# Context managers
with open("file.txt") as f:
    data = f.read()

# Exception handling
try:
    risky()
except (ValueError, KeyError) as e:
    print(e)
finally:
    cleanup()
```

 ## 15. Time Complexity of Common Built-ins

 ```python
len(lst)          # O(1)
lst[i]             # O(1)
i in lst           # O(n)
i in dict/set       # O(1) average
lst.append(x)       # O(1) amortized
lst.pop()            # O(1)
lst.pop(0)            # O(n)
lst.sort()             # O(n log n)
"".join(lst)            # O(n)
```

 ---

 ## 16. More Gotchas (High-Frequency Interview Traps)

 ```python
# Late-binding closures — classic loop trap
funcs = [lambda: i for i in range(3)]
[f() for f in funcs]        # [2, 2, 2] NOT [0, 1, 2]
# Fix: bind i as a default argument
funcs = [lambda i=i: i for i in range(3)]
[f() for f in funcs]        # [0, 1, 2]

# Modifying a list while iterating over it — skips elements
nums = [1, 2, 3, 4, 5]
for n in nums:
    if n % 2 == 0:
        nums.remove(n)      # BUG: index shifts, elements get skipped
# Fix: iterate over a copy, or build a new list
nums = [n for n in nums if n % 2 != 0]

# Chained comparisons (Python allows this — surprises people from other langs)
1 < 2 < 3        # True  (equivalent to 1<2 and 2<3)
1 < 2 > 0        # True

# `and`/`or` return operands, not booleans
x = None
y = x or "default"     # "default"
z = 5 and "yes"         # "yes" (returns last truthy operand)

# String immutability — every "modification" makes a new object
s = "hello"
s += " world"    # creates a new string, doesn't mutate in place

# Floating point precision
0.1 + 0.2 == 0.3         # False! (0.30000000000000004)
round(0.1 + 0.2, 2) == 0.3   # True

# Multiple assignment shares reference for mutable objects
a = b = []
a.append(1)
b            # [1] — a and b point to the same list

# 2D list initialization trap
grid = [[0] * 3] * 3     # WRONG: 3 references to the SAME inner list
grid[0][0] = 1
grid                       # [[1,0,0],[1,0,0],[1,0,0]] — all rows changed!
# Fix:
grid = [[0] * 3 for _ in range(3)]

# Truthy/falsy values
bool(0), bool(""), bool([]), bool({}), bool(None)   # all False
bool(0.0), bool(" "), bool([0])                       # False, True, True

# `==` vs `is` with small integers/strings (CPython interning — don't rely on it)
a = "hello"; b = "hello"
a is b     # True (interned, implementation detail)

# Default arguments evaluated ONCE at function definition time
import time
def log(msg, t=time.time()):   # t is fixed at def time, not call time
    print(msg, t)

# Variable scope — UnboundLocalError trap
x = 10
def f():
    print(x)       # NameError-like error actually raised here:
    x = 20          # Python sees x is assigned in f, treats it as local throughout
# f()  -> UnboundLocalError
# Fix: use `global x` or `nonlocal x` if you need to reassign the outer variable
```

 ## 17. Generators & Iterators

 ```python
# Generator function — lazy evaluation, memory efficient
def gen(n):
    for i in range(n):
        yield i

g = gen(5)
next(g)          # 0
list(g)           # [1,2,3,4] (consumes rest)

# Generator expression vs list comprehension
sum(x**2 for x in range(1000000))   # O(1) memory
sum([x**2 for x in range(1000000)]) # builds full list in memory first

# A generator can only be iterated once
g = (x for x in range(3))
list(g)   # [0, 1, 2]
list(g)   # [] — already exhausted

# yield vs return
def counter():
    i = 0
    while True:
        yield i
        i += 1
# vs a normal function that returns once and exits

# Custom iterator protocol
class Range:
    def __init__(self, n):
        self.n = n
        self.i = 0
    def __iter__(self):
        return self
    def __next__(self):
        if self.i >= self.n:
            raise StopIteration
        self.i += 1
        return self.i - 1
```

 ## 18. `*args`, `**kwargs`, and Unpacking

 ```python
def f(*args, **kwargs):
    print(args)    # tuple
    print(kwargs)  # dict

f(1, 2, a=3, b=4)   # args=(1,2), kwargs={'a':3,'b':4}

# Unpacking when calling
def add(a, b, c):
    return a + b + c
nums = [1, 2, 3]
add(*nums)                 # unpack list as positional args
d = {"a": 1, "b": 2, "c": 3}
add(**d)                    # unpack dict as keyword args

# Merging dicts (3.9+)
d1 = {"a": 1}; d2 = {"b": 2}
merged = d1 | d2            # {'a': 1, 'b': 2}
merged = {**d1, **d2}       # same result, works pre-3.9

# Merging lists
combined = [*list1, *list2]
```

 ## 19. Scope: The LEGB Rule

 ```python
# Local -> Enclosing -> Global -> Built-in
x = "global"

def outer():
    x = "enclosing"
    def inner():
        nonlocal_demo = x   # finds x in enclosing scope
        print(x)
    inner()

# global keyword
count = 0
def increment():
    global count
    count += 1
```

 ## 20. Common "Explain This" Interview Questions

 - **What's the GIL?** The Global Interpreter Lock lets only one thread execute Python bytecode at a time in CPython. Threads help with I/O-bound work; use `multiprocessing` (not `threading`) for CPU-bound parallelism.
- **List vs tuple?** Lists are mutable, tuples are immutable — tuples are hashable (can be dict keys/set elements) if all contents are hashable; lists cannot.
- **`__init__` vs `__new__`?** `__new__` creates the instance (rarely overridden); `__init__` initializes it after creation.
- **Deep copy vs shallow copy?** Shallow copies the outer container only, nested objects are still shared references; deep copy recursively copies everything.
- **What is duck typing?** "If it walks like a duck and quacks like a duck" — Python cares about an object's behavior/interface, not its declared type.
- **Difference between `@staticmethod` and `@classmethod`?** `staticmethod` takes no implicit first arg; `classmethod` takes `cls` and can access/modify class state.
- **What does `self` do?** Refers to the instance; Python passes it automatically when calling a method on an instance.

 ```python
class Demo:
    count = 0    # class variable, shared across all instances

    def __init__(self, name):
        self.name = name         # instance variable
        Demo.count += 1

    @staticmethod
    def utility(x):
        return x * 2

    @classmethod
    def from_string(cls, s):
        return cls(s)
```

 ## 21. `itertools` Essentials (fast, memory-efficient combinatorics)

 ```python
from itertools import permutations, combinations, product, chain, groupby

list(permutations([1,2,3], 2))   # all ordered pairs
list(combinations([1,2,3], 2))   # all unordered pairs
list(product([1,2], [3,4]))       # cartesian product
list(chain([1,2], [3,4]))          # flatten iterables: [1,2,3,4]

# groupby needs sorted input on the grouping key
data = [1,1,2,2,3]
[(k, list(g)) for k, g in groupby(data)]
```

 ## 22. Recursion & Stack Depth

 ```python
import sys
sys.getrecursionlimit()      # default 1000
sys.setrecursionlimit(5000)  # increase if truly needed (rare in interviews —
                              # usually a sign to convert to iteration instead)

# Tail-call-style pattern (Python does NOT optimize tail calls, unlike some langs)
def factorial(n, acc=1):
    if n <= 1:
        return acc
    return factorial(n - 1, acc * n)   # still uses O(n) stack frames in Python
```

 ## 23. Quick Reference: What to Say Out Loud in an Interview

 - State the **brute force** approach first, then optimize — interviewers want to see your thought process.
- Always clarify **input constraints** (empty input? duplicates? negative numbers? sorted?) before coding.
- Narrate time and space complexity **as you write**, not just at the end.
- Test your solution mentally against an **edge case** (empty list, single element, all same values) before saying "done."
- If stuck, talk about the **data structure** that fits the access pattern you need (hash map for O(1) lookup, heap for k-largest/smallest, stack for matching/nesting, deque for sliding window).