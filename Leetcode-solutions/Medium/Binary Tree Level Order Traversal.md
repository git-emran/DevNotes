Given the `root` of a binary tree, return *the level order traversal of its nodes' values*. (i.e., from left to right, level by level).

**Example 1:**

![](https://assets.leetcode.com/uploads/2021/02/19/tree1.jpg)```
Input: root = [3,9,20,null,null,15,7]
Output: [[3],[9,20],[15,7]]
```

**Example 2:**

```
Input: root = [1]
Output: [[1]]

```

**Example 3:**

```
Input: root = []
Output: []

```

**Constraints:**

- The number of nodes in the tree is in the range `[0, 2000]`.

```


## Solution:
### 1. Depth First Search

### Intuition

Level order traversal means visiting the tree **level by level**, from top to bottom.
With DFS, instead of using a queue, we use **recursion** and pass the current depth.
Each time we reach a node:

- If this is the first time visiting this depth, create a new list for that level.
- Add the node's value to the list for that depth.
- Recursively explore left and right children with `depth + 1`.

### Algorithm

1. Maintain an empty list `res` where `res[d]` stores all nodes at depth `d`.
2. Define a recursive function `dfs(node, depth)`:
  - If `node` is `null`, return.
  - If `res` has no list for this depth, append a new empty list.
  - Append the node's value to `res[depth]`.
  - Recurse on `node.left` with `depth + 1`.
  - Recurse on `node.right` with `depth + 1`.
3. Call `dfs(root, 0)`.
4. Return `res`.

```python

# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:
    def levelOrder(self, root: Optional[TreeNode]) -> List[List[int]]:
        res = []

        def dfs(node, depth):
            if not node:
                return None
            if len(res) == depth:
                res.append([])

            res[depth].append(node.val)
            dfs(node.left, depth + 1)
            dfs(node.right, depth + 1)

        dfs(root, 0)
        return res


```


### 2.Breadth First Search
### Intuition

Level order traversal visits a tree **level by level**, from left to right.
BFS naturally fits this because it processes nodes in the order they appear using a **queue**.

The idea:

- Push the root into the queue.
- Repeatedly remove nodes from the queue, these form the current level.
- Add their children into the queue, these will form the next level.
- Continue until the queue is empty.

This ensures every node is visited in perfect level-order.

### Algorithm

1. If the tree is empty, return an empty list.
2. Create a queue and push the root.
3. While the queue is not empty:
  - Let `qLen` be the number of nodes currently in the queue (these nodes form one full level).
  - Create an empty list `level`.
  - Repeat `qLen` times:
    - Pop a node from the queue.
    - Add its value to `level`.
    - Push its left and right children if they exist.
  - Append `level` to the result list.
4. Return the result list containing all levels.


```python

# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:
    def levelOrder(self, root: Optional[TreeNode]) -> List[List[int]]:
        res = []

        q = collections.deque()
        q.append(root)

        while q:
            qLen = len(q)
            level = []
            for i in range(qLen):
                node = q.popleft()
                if node:
                    level.append(node.val)
                    q.append(node.left)
                    q.append(node.right)
            if level:
                res.append(level)

        return res

```