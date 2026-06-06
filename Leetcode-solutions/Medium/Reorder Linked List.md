You are given the head of a singly linked-list.

The positions of a linked list of `length = 7` for example, can intially be represented as:

`[0, 1, 2, 3, 4, 5, 6]`

Reorder the nodes of the linked list to be in the following order:

`[0, 6, 1, 5, 2, 4, 3]`

Notice that in the general case for a list of `length = n` the nodes are reordered to be in the following order:

`[0, n-1, 1, n-2, 2, n-3, ...]`

You may not modify the values in the list's nodes, but instead you must reorder the nodes themselves.

**Example 1:**

```java
Input: head = [2,4,6,8]

Output: [2,8,4,6]
```

**Example 2:**

```java
Input: head = [2,4,6,8,10]

Output: [2,10,4,8,6]
```

**Constraints:**

- `1 <= Length of the list <= 1000`.
- `1 <= Node.val <= 1000`


---
## 1. Brute Force

### Intuition

To reorder the linked list in the pattern:

**L0 → Ln → L1 → L(n−1) → L2 → ...**

A straightforward approach is to **store all nodes in an array**.  
Once stored, we can easily access nodes from both the start and end using two pointers.  
By alternately linking nodes from the front (index `i`) and back (index `j`), we can reshape the list in the required order.

### Algorithm

1. Traverse the linked list and push every node into an array called `nodes`.
2. Initialize two pointers:
    - `i = 0` (start)
    - `j = len(nodes) - 1` (end)
3. While `i < j`:
    - Link `nodes[i].next` to `nodes[j]`; increment `i`.
    - If `i >= j`, break the loop.
    - Link `nodes[j].next` to `nodes[i]`; decrement `j`.
4. After the loop, set `nodes[i].next = None` to terminate the list.
5. The reordered list is constructed in-place.o

```python
# Definition for singly-linked list.
# class ListNode:
#     def __init__(self, val=0, next=None):
#         self.val = val
#         self.next = next

class Solution:
    def reorderList(self, head: Optional[ListNode]) -> None:
        if not head:
            return
        
        nodes = []
        cur = head

        while cur:
            nodes.append(cur)
            cur = cur.next
        
        i, j = 0, len(nodes) - 1
        while i < j:
            nodes[i].next = nodes[j]
            i += 1
            if i >= j:
                break
            nodes[j].next = nodes[i]
            j -= 1

        nodes[i].next = None
```
