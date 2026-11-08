Within a binary tree, a node `x` is considered **good** if the path from the root of the tree to the node `x` contains no nodes with a value greater than the value of node `x`

Given the root of a binary tree `root`, return the number of **good** nodes within the tree.

**Example 1:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/9bf374f1-71fe-469e-2840-5d223d9d1b00/public)

```java
Input: root = [2,1,1,3,null,1,5]

Output: 3
```

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/8df65da7-abac-4948-9a92-0bc7a8dda100/public)

**Example 2:**

```java
Input: root = [1,2,-1,3,4]

Output: 4
```

**Constraints:**

- `1 <= number of nodes in the tree <= 100,000`
- `-100 <= Node.val <= 100`


```python
# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:
    def goodNodes(self, root: TreeNode) -> int

  
```


