Given the root of a binary tree, imagine yourself standing on the right side of it, return the values of the nodes you can see ordered from top to bottom.


Example 1:

Input: root = [1,2,3,null,5,null,4]

Output: [1,3,4]

Example 2:

Input: root = [1,2,3,4,null,null,null,5]

Output: [1,3,4,5]


Example 3:

Input: root = [1,null,3]

Output: [1,3]

Example 4:

Input: root = []

Output: []

 

Constraints:

The number of nodes in the tree is in the range [0, 100].
-100 <= Node.val <= 100

## Depth First Search Intuition

To see the right side of a tree, at each depth we only care about the first node we encounter when looking from the right.

If we perform DFS by visiting:
- Right child first, then
- Left child

...then the first node we reach at every depth is the visible right-side node.

We store that node the moment we first reach that depth.

### Algorithm
- Create an empty list res to store the right-side values.
- Define a dfs function that takes a node and its depth.
- In the dfs:
- If the node is null → return.
- If depth == len(res) → this is the first node at this depth → append its value.
- Recursively visit the right child first.
- Then recursively visit the left child.
- Start dfs from the root at depth 0.
- Return res.

## Solution

```py

# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:
    def rightSideView(self, root: Optional[TreeNode]) -> List[int]:
        res = []

        def dfs(node, depth): 
            if node is None:
                return
            if depth == len(res):
                res.append(node.val)
            dfs(node.right, depth+1)
            dfs(node.left, depth+1)
        dfs(root, 0)
        return res

```

*Time and Space complexity: O(n), O(n)*



## Breadth First Search

### Intuition
In BFS we explore the tree level by level.
If we look at each level from left to right, the last node we encounter at that level is the one visible from the right side.

So for every level:

- Traverse all nodes.
- Remember the rightmost node.
- Add it to the answer.

### Algorithm
- If the tree is empty → return an empty list.
- Initialize a queue with the root.
- While the queue is not empty:
- Determine how many nodes are in the current level (level_size).
- For each node in the level:
- Pop it from the queue.
- Update rightmost_node to this node.
- Push its left child, then right child (if they exist).
- After finishing the level, append rightmost_node's value to the result.
- Return the result list.

```py


# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right

class Solution:
    def rightSideView(self, root: Optional[TreeNode]) -> List[int]:
        q = deque([root])



```
