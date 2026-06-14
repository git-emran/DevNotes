
# Problem
You are given the head of a linked list of length `n`. Unlike a singly linked list, each node contains an additional pointer `random`, which may point to any node in the list, or `null`.

Create a **deep copy** of the list.

The deep copy should consist of exactly `n` **new** nodes, each including:

- The original value `val` of the copied node
- A `next` pointer to the new node corresponding to the `next` pointer of the original node
- A `random` pointer to the new node corresponding to the `random` pointer of the original node

Note: None of the pointers in the new list should point to nodes in the original list.

_Return the head of the copied linked list._

In the examples, the linked list is represented as a list of `n` nodes. Each node is represented as a pair of `[val, random_index]` where `random_index` is the index of the node (0-indexed) that the `random` pointer points to, or `null` if it does not point to any node.

**Example 1:**


```java
Input: head = [[3,null],[7,3],[4,0],[5,1]]

Output: [[3,null],[7,3],[4,0],[5,1]]
```

**Example 2:**


```java
Input: head = [[1,null],[2,2],[3,2]]

Output: [[1,null],[2,2],[3,2]]
```

**Constraints:**

- `0 <= n <= 100`
- `-100 <= Node.val <= 100`
- Node values are not guaranteed to be unique.
- `random` is `null` or is pointing to some node in the linked list.


## 1. Recursion + Hash Map

### Intuition

We must create a deep copy of a linked list where each node has both `next` and `random` pointers.  
The main difficulty: multiple nodes may point to the same `random` node, so we must ensure each original node is copied **exactly once**.

A hash map helps us remember the copied version of each original node.  
Using recursion, we:

- copy the current node,
- store it in the map,
- recursively copy its `next`,
- link its `random` using the map.

### Algorithm

1. If the current node is `null`, return `null`.
2. If the node is already copied (exists in the map), return the stored copy.
3. Create a new copy node and store it in the map.
4. Recursively copy the `next` pointer.
5. Set the `random` pointer using the map.
6. Return the copied node.

```python

"""
# Definition for a Node.
class Node:
    def __init__(self, x: int, next: 'Node' = None, random: 'Node' = None):
        self.val = int(x)
        self.next = next
        self.random = random
"""

class Solution:
    def __init__(self):
        self.map = {}

    def copyRandomList(self, head: 'Optional[Node]') -> 'Optional[Node]':
        if head is None:
            return None
        if head in self.map:
            return self.map[head]

        copy = Node(head.val)
        self.map[head] = copy
        copy.next = self.copyRandomList(head.next)
        copy.random = self.map.get(head.random)
        return copy
```


## 2. Hash Map (Two Pass)

### Intuition

We want to copy a linked list where each node has both `next` and `random` pointers.  
The challenge is that the `random` pointer can point anywhere — forward, backward, or even `None`.  
So we must ensure every original node is copied **exactly once**, and all pointers are reconnected correctly.

A simple solution:

- **Pass 1:** Create a copy of every node (just values), and store the mapping:  
    `original_node → copied_node`
- **Pass 2:** Use this map to connect `next` and `random` pointers for each copied node.

This guarantees all pointers are valid and no node is duplicated.

### Algorithm

1. Create a hash map `oldToCopy`, mapping each original node to its copied node.  
    Include `null -> null` for convenience.
2. First pass: iterate through the original list
    - Create a copy of each node.
    - Store the mapping in `oldToCopy`.
3. Second pass: iterate again
    - Set `copy.next` using `oldToCopy[original.next]`.
    - Set `copy.random` using `oldToCopy[original.random]`.
4. Return the copied version of the head using `oldToCopy[head]`.


```python

"""
# Definition for a Node.
class Node:
    def __init__(self, x: int, next: 'Node' = None, random: 'Node' = None):
        self.val = int(x)
        self.next = next
        self.random = random
"""

class Solution:
    def copyRandomList(self, head: 'Optional[Node]') -> 'Optional[Node]':
        oldToCopy = {None: None}

        cur = head
        while cur:
            copy = Node(cur.val)
            oldToCopy[cur] = copy
            cur = cur.next
        
        cur = head
        while cur:
            copy = oldToCopy[cur]
            copy.next = oldToCopy[cur.next]
            copy.random = oldToCopy[cur.random]
            cur = cur.next
        return oldToCopy[head]

```


