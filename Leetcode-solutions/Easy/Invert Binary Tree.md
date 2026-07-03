# Invert Binary Tree

EasyTopicsCompany TagsHints

You are given the root of a binary tree `root`. Invert the binary tree and return its root.

**Example 1:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/ac124ee6-207f-41f6-3aaa-dfb35815f200/public)

```java
Input: root = [1,2,3,4,5,6,7]

Output: [1,3,2,7,6,5,4]
```

**Example 2:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/e39e8d4f-9946-4f99-ee3d-0d4df08d4d00/public)

```java
Input: root = [3,2,1]

Output: [3,1,2]
```

**Example 3:**

```java
Input: root = []

Output: []
```

**Constraints:**

- `0 <= The number of nodes in the tree <= 100`.
- `-100 <= Node.val <= 100`



## 1. Breadth First Search

###  BFS Intuition

To invert (mirror) a binary tree, every node must swap its **left** and **right** children. Using **Breadth-First Search (BFS)**, we process the tree level-by-level:

- Start from the root.
- For each node, **swap** its children.
- Then push the (new) left and right children into the queue.
- Continue until every node has been processed.

This approach ensures that every node is visited exactly once and inverted immediately when encountered.

---

### BFS Algorithm

1. If the tree is empty, return `null`.
2. Initialize a queue and insert the `root` node.
3. While the queue is not empty:
  - Remove the front node.
  - Swap its `left` and `right` children.
  - If the `left` child exists, add it to the queue.
  - If the `right` child exists, add it to the queue.
4. After all nodes are processed, return the `root` as the inverted tree.


```python

# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:
  def invertTree(self, root: Optional[TreeNode]) -> Optional[TreeNode]:

    if not root:
      return None

    stack = [root]

    while stack:
      node = stack.pop()
      node.left, node.right = node.right, node.left

      if node.left:
        stack.append(node.left)
        
      if node.right:
        stack.append(node.right)
    
    return root

```