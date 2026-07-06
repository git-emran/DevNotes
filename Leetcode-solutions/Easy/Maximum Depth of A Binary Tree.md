Given the `root` of a binary tree, return *its maximum depth*.

A binary tree's **maximum depth** is the number of nodes along the longest path from the root node down to the farthest leaf node.

**Example 1:**
![](https://assets.leetcode.com/uploads/2020/11/26/tmp-tree.jpg)
Input: root = [3,9,20,null,null,15,7]
Output: 3

**Example 2:**
Input: root = [1,null,2]
Output: 2

**Constraints:**
- The number of nodes in the tree is in the range `[0, 104]`.
- `-100 <= Node.val <= 100`


# 3. Breadth First Search

### **Intuition**

Breadth-First Search (BFS) processes the tree level by level.
This makes it a perfect fit for computing the **maximum depth** because:

- Every iteration of BFS processes one entire level of the tree.
- So each completed level corresponds to increasing the depth by 1.

We simply count **how many levels** we traverse until the queue becomes empty.

Think of the queue like a moving frontier:

- Start with the root → depth = 1
- Add its children → depth = 2
- Add their children → depth = 3
- Continue until no nodes remain.

The number of BFS layers processed is exactly the depth of the tree.

---

### **Algorithm**

1. If the tree is empty (`root == null`), return `0`.
2. Initialize a queue and push the `root`.
3. Initialize `level = 0`.
4. While the queue is not empty:
  - Determine the number of nodes at the current level (`size = len(queue)`).
  - Process all `size` nodes:
    - Pop from the queue.
    - Push their left and right children if they exist.
  - After processing the entire level, increment `level`.
5. Return `level` when the queue becomes empty.


```python

# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:
    def maxDepth(self, root: Optional[TreeNode]) -> int:
        q = deque()

        if root:
            q.append(root)

        level = 0

        while q:
            for i in range(len(q)):
                node = q.popleft()
                if node.left:
                    q.append(node.left)
                if node.right:
                    q.append(node.right)
            level += 1
        return level

```