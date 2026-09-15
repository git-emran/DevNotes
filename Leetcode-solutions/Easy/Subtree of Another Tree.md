# Subtree of Another Tree

EasyTopicsCompany TagsHints

Given the roots of two binary trees `root` and `subRoot`, return `true` if there is a subtree of `root` with the same structure and node values of `subRoot` and `false` otherwise.

A subtree of a binary tree `tree` is a tree that consists of a node in `tree` and all of this node's descendants. The tree `tree` could also be considered as a subtree of itself.

**Example 1:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/2991a77a-9664-46ed-528d-019e392f7400/public)

```java
Input: root = [1,2,3,4,5], subRoot = [2,4,5]

Output: true
```

**Example 2:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/ae6114cb-23a0-457f-c441-0a82b7a58500/public)

```java
Input: root = [1,2,3,4,5,null,null,6], subRoot = [2,4,5]

Output: false
```

**Constraints:**

- The number of nodes in the `root` tree is in the range `[1, 2000]`.
- The number of nodes in the `subRoot` tree is in the range `[1, 1000]`.
- `-10^4 <= root.val <= 10^4`
- `-10^4 <= subRoot.val <= 10^4`


## Prerequisites

Before attempting this problem, you should be comfortable with:

- **Binary Tree Structure** - Understanding node structure with left/right children and how to traverse trees
- **Depth First Search (DFS)** - Used to traverse every node in the main tree and compare subtrees recursively
- **Tree Comparison** - Checking if two trees are structurally identical with matching values at each node


## 1. Depth First Search (DFS)

### Intuition

To check whether one tree is a subtree of another, we do two things:

1. **Walk through every node** of the main tree (`root`) using DFS.
2. At each node, **check if the subtree starting here is exactly the same** as `subRoot`.

So for every node in the big tree:

- If its value matches `subRoot`'s root, we compare both subtrees fully.
- If they are identical, `subRoot` is a subtree.
- Otherwise, continue searching on the left and right children.

The helper `sameTree` simply checks whether two trees match **exactly**, node-for-node.

### Algorithm

1. If `subRoot` is empty → return `true` (empty tree is always a subtree).
2. If `root` is empty but `subRoot` is not → return `false`.
3. At the current `root` node:
  - If `sameTree(root, subRoot)` is `true`, return `true`.
4. Recursively check:
  - `isSubtree(root.left, subRoot)`
  - `isSubtree(root.right, subRoot)`
5. Return `true` if either side returns `true`.

**sameTree(root1, root2):**

1. If both nodes are `null` → return `true`.
2. If only one is `null` → return `false`.
3. If values differ → return `false`.
4. Recursively check left children and right children.

```python

# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:   
    def isSubtree(self, root: Optional[TreeNode], subRoot: Optional[TreeNode]) -> bool:
      
        
```