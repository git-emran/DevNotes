
You are given an `m x n` integer matrix `matrix` with the following two properties:

- Each row is sorted in non-decreasing order.
- The first integer of each row is greater than the last integer of the previous row.

Given an integer `target`, return `true` _if_ `target` _is in_ `matrix` _or_ `false` _otherwise_.

You must write a solution in `O(log(m * n))` time complexity.

**Example 1:**

![](https://assets.leetcode.com/uploads/2020/10/05/mat.jpg)

**Input:** matrix = [[1,3,5,7],[10,11,16,20],[23,30,34,60]], target = 3
**Output:** true

**Example 2:**

![](https://assets.leetcode.com/uploads/2020/10/05/mat2.jpg)

**Input:** matrix = [[1,3,5,7],[10,11,16,20],[23,30,34,60]], target = 13
**Output:** false

# Binary Search(one-pass)
### Intuition

Because the matrix is sorted row-wise and each row is sorted left-to-right, the entire matrix behaves like **one big sorted array**.  
If we imagine flattening the matrix into a single list, the order of elements doesn't change.

This means we can run **one binary search** from index `0` to `ROWS * COLS - 1`.  
For any mid index `m`, we can map it back to the matrix using:

- `row = m // COLS`
- `col = m % COLS`

This lets us access the correct matrix element without actually flattening the matrix.

### Algorithm

1. Treat the matrix as a single sorted array of size `ROWS * COLS`.
2. Set `l = 0` and `r = ROWS * COLS - 1`.
3. While `l <= r`:
    - Compute the middle index `m = (l + r) // 2`.
    - Convert `m` back to matrix coordinates:
        - `row = m // COLS`
        - `col = m % COLS`
    - Compare `matrix[row][col]` with the target:
        - If equal → return `true`.
        - If the value is smaller → search the right half (`l = m + 1`).
        - If larger → search the left half (`r = m - 1`).
4. If the loop ends with no match, return `false`.
```python

class Solution:
    def searchMatrix(self, matrix: List[List[int]], target: int) -> bool:
        ROW, COL = len(matrix), len(matrix[0])
        l, r = 0, ROW * COL - 1

        while l <=  r:
            m = l + (r - l) // 2
            row, col = m // COL, m % COL

            if target > matrix[row][col]:
                l = m + 1
            elif target < matrix[row][col]:
                r = m - 1
            else:
                return True
        return False
```