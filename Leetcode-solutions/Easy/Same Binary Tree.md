# Same Binary Tree

EasyTopicsCompany TagsHints

Given the roots of two binary trees `p` and `q`, return `true` if the trees are **equivalent**, otherwise return `false`.

Two binary trees are considered **equivalent** if they share the exact same structure and the nodes have the same values.

**Example 1:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/e78fc10c-4692-471f-5261-61e9be4f3a00/public)

```java
Input: p = [1,2,3], q = [1,2,3]

Output: true
```

**Example 2:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/0b0ee764-c643-46ff-cb3f-86ce8b58ab00/public)

```java
Input: p = [4,7], q = [4,null,7]

Output: false
```

**Example 3:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/4d811f95-0488-490b-1f4f-fc5489df0f00/public)

```java
Input: p = [1,2,3], q = [1,3,2]

Output: false
```

**Constraints:**

- `0 <= The number of nodes in both trees <= 100`.
- `-100 <= Node.val <= 100`


## Depth First Search

### Intuition

Two binary trees are the same if:

1. Their structure is identical.
2. Their corresponding nodes have the same values.

So at every position:

- If both nodes are `null` → they match.
- If one is `null` but the other isn't → mismatch.
- If both exist but values differ → mismatch.
- Otherwise, compare their left subtrees and right subtrees recursively.

This is a direct structural + value-based DFS comparison.

### Algorithm

1. If both `p` and `q` are `null`, return `true`.
2. If only one is `null`, return `false`.
3. If their values differ, return `false`.
4. Recursively compare:
  - `p.left` with `q.left`
  - `p.right` with `q.right`
5. Return `true` only if both subtree comparisons are `true`.

```python

# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right
class Solution:
    def isSameTree(self, p: Optional[TreeNode], q: Optional[TreeNode]) -> bool:
        if not p and not q :
            return True
        
        if p and q and p.val == q.val:
            return self.isSameTree(p.left, q.left) and self.isSameTree(p.right, q.right)
            
        return False
        
        
```


## Breadth First Search

### Intuition

BFS (level-order traversal) lets us compare the two trees **level by level**.
We maintain two queues—one for each tree. At every step, we remove a pair of nodes
that should match:

- If both nodes are `null`, they match → continue.
- If only one is `null`, or their values differ → trees are not the same.
- If they match, we push their children into their respective queues
  **in the same order**: left child first, then right child.

### Algorithm

1. Initialize two queues:
  - `q1` containing the root of the first tree.
  - `q2` containing the root of the second tree.
2. While both queues are non-empty:
  - Pop one node from each queue: `nodeP`, `nodeQ`.
  - If both are `null`, continue.
  - If only one is `null`, return `false`.
  - If their values differ, return `false`.
  - Enqueue their children:
    - Left children of both trees.
    - Right children of both trees.
3. After BFS completes with no mismatch, return `true`.

```python
# Definition for a binary tree node.
# class TreeNode:
#     def __init__(self, val=0, left=None, right=None):
#         self.val = val
#         self.left = left
#         self.right = right
class Solution:
    def isSameTree(self, p: Optional[TreeNode], q: Optional[TreeNode]) -> bool:
        q1 = deque([p])
        q2 = deque([q])

        while q1 and q2:
            for _ in range(len(q1)):
                nodeP = q1.popleft()
                nodeQ = q2.popleft()
                
                if nodeP is None and nodeQ is None:
                    continue

                if nodeP is None or nodeQ is None or nodeP.val != nodeQ.val:
                    return False
                q1.append(nodeP.left)
                q1.append(nodeP.right)
                q2.append(nodeQ.left)
                q2.append(nodeQ.right)

        return True
```


