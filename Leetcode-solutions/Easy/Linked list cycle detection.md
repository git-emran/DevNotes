Given the beginning of a linked list `head`, return `true` if there is a cycle in the linked list. Otherwise, return `false`.

There is a cycle in a linked list if at least one node in the list can be visited again by following the `next` pointer.

Internally, `index` determines the index of the beginning of the cycle, if it exists. The tail node of the list will set it's `next` pointer to the `index-th` node. If `index = -1`, then the tail node points to `null` and no cycle exists.

**Note:** `index` is **not** given to you as a parameter.

**Example 1:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/3ecdbcfc-70fc-429a-4654-cf4f6a7dbe00/public)

```java
Input: head = [1,2,3,4], index = 1

Output: true
```

Explanation: There is a cycle in the linked list, where the tail connects to the 1st node (0-indexed).

**Example 2:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/89e6716c-9f65-46da-d7b2-f04a93269700/public)

```java
Input: head = [1,2], index = -1

Output: false
```
## Fast And Slow Pointers

### Intuition

We use two pointers moving through the list at different speeds:

- `slow` moves one step at a time
- `fast` moves two steps at a time

If the list has a cycle, the `fast` pointer will eventually "lap" the `slow` pointer, meaning they will meet at some node inside the cycle.

If the list has no cycle, the `fast` pointer will reach the end (`null`) and the loop stops.

This method is efficient and uses constant extra space.

### Algorithm

1. Initialize two pointers:
    - `slow = head`
    - `fast = head`
2. Move through the list:
    - `slow` moves one step.
    - `fast` moves two steps.
3. If at any point `slow == fast`, a cycle exists, return `true`.
4. If `fast` reaches the end (`null` or `fast.next` is `null`), no cycle exists, return `false`.
```python

# Definition for singly-linked list.
# class ListNode:
#     def __init__(self, val=0, next=None):
#         self.val = val
#         self.next = next

class Solution:
    def hasCycle(self, head: Optional[ListNode]) -> bool:
        slow, fast = head, head

        while fast and fast.next:
            slow = slow.next
            fast = fast.next.next

            if slow == fast:
                return True
        return False
        
```