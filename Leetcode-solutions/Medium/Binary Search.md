You are given an `m x n` 2-D integer array `matrix` and an integer `target`.

- Each row in `matrix` is sorted in _non-decreasing_ order.
- The first integer of every row is greater than the last integer of the previous row.

Return `true` if `target` exists within `matrix` or `false` otherwise.

Can you write a solution that runs in `O(log(m * n))` time?

**Example 1:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/7ca61f56-00d4-4fa0-26cf-56809028ac00/public)

```java
Input: matrix = [[1,2,4,8],[10,11,12,13],[14,20,30,40]], target = 10

Output: true
```

**Example 2:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/f25f2085-ce04-4447-9cee-f0a66c32a300/public)

```java
Input: matrix = [[1,2,4,8],[10,11,12,13],[14,20,30,40]], target = 15

Output: false
```

**Constraints:**

- `m == matrix.length`
- `n == matrix[i].length`
- `1 <= m, n <= 100`
- `-10000 <= matrix[i][j], target <= 10000`

# Binary Search
### Intuition

Because each row of the matrix is sorted, and the rows themselves are sorted by their first and last elements, we can apply **binary search twice**:

1. **First search over the rows**  
    We find the single row where the target _could_ exist by comparing the target with the row's first and last elements.  
    Binary search helps us quickly narrow down to that one row.
    
2. **Then search inside that row**  
    Once the correct row is found, we perform a normal binary search within that row to check if the target is present.
    

This eliminates large portions of the matrix at each step and uses the sorted structure fully.

### Algorithm

1. Set `top = 0` and `bot = ROWS - 1`.
2. Binary search over the rows:
    - Let `row = (top + bot) // 2`.
    - If the target is greater than the last element of this row → move down (`top = row + 1`).
    - If the target is smaller than the first element → move up (`bot = row - 1`).
    - Otherwise → the target must be in this row; stop.
3. If no valid row is found, return `false`.
4. Now binary search within the identified row:
    - Use standard binary search to look for the target.
5. Return `true` if found, otherwise `false`.

```python

class Solution:
    def searchMatrix(self, matrix: List[List[int]], target: int) -> bool: 
        ROWS, COL = len(matrix), len(matrix[0])
        top, bot = 0, ROWS - 1
        while top <= bot:
            row = (top + bot ) // 2
            if target > matrix[row][-1]:
                top = row + 1
            elif target < matrix[row][0]:
                bot = row - 1
            else:
                break
        
        if not(top <= bot):
            return False

        row = (top + bot) // 2
        l , r = 0, COL - 1
        while l <= r:
            m = (l + r) //2 
            if target > matrix[row][m]:
                l = m + 1
            elif target < matrix[row][m]:
                r = m - 1
            else:
                return True
        return False
```


# Binary Search (One Pass)

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