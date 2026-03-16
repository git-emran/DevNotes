MediumTopicsCompany TagsHints

You are given a `9 x 9` Sudoku board `board`. A Sudoku board is valid if the following rules are followed:

1. Each row must contain the digits `1-9` without duplicates.
2. Each column must contain the digits `1-9` without duplicates.
3. Each of the nine `3 x 3` sub-boxes of the grid must contain the digits `1-9` without duplicates.

Return `true` if the Sudoku board is valid, otherwise return `false`

Note: A board does not need to be full or be solvable to be valid.

**Example 1:**

![](https://imagedelivery.net/CLfkmk9Wzy8_9HRyug4EVA/0be40c5d-2d18-42b8-261b-13ca50de4100/public)

```java
Input: board =
[["1","2",".",".","3",".",".",".","."],
 ["4",".",".","5",".",".",".",".","."],
 [".","9","8",".",".",".",".",".","3"],
 ["5",".",".",".","6",".",".",".","4"],
 [".",".",".","8",".","3",".",".","5"],
 ["7",".",".",".","2",".",".",".","6"],
 [".",".",".",".",".",".","2",".","."],
 [".",".",".","4","1","9",".",".","8"],
 [".",".",".",".","8",".",".","7","9"]]

Output: true
```


**Example 2:**

```java
Input: board =
[["1","2",".",".","3",".",".",".","."],
 ["4",".",".","5",".",".",".",".","."],
 [".","9","1",".",".",".",".",".","3"],
 ["5",".",".",".","6",".",".",".","4"],
 [".",".",".","8",".","3",".",".","5"],
 ["7",".",".",".","2",".",".",".","6"],
 [".",".",".",".",".",".","2",".","."],
 [".",".",".","4","1","9",".",".","8"],
 [".",".",".",".","8",".",".","7","9"]]

Output: false
```

Explanation: There are two 1's in the top-left 3x3 sub-box.

**Constraints:**

- `board.length == 9`
- `board[i].length == 9`
- `board[i][j]` is a digit `1-9` or `'.'`.p

---

# Solution
#### Prerequisites

Before attempting this problem, you should be comfortable with:

- **Hash Sets** - Used to track seen digits in rows, columns, and boxes for duplicate detection
- **2D Array Traversal** - Understanding how to iterate through a 9x9 grid and compute box indices
- **Bit Manipulation** - The optimized solution uses bitmasks to represent seen digits compactly

---

## 1. Brute Force

### Intuition

A valid Sudoku board must follow three rules:

1. Each **row** can contain digits `1–9` at most once.
2. Each **column** can contain digits `1–9` at most once.
3. Each **3×3 box** can contain digits `1–9` at most once.

We can directly check all these conditions one by one.  
For every row, every column, and every 3×3 box, we keep a set of seen digits and make sure no number appears twice.  
If we ever find a duplicate in any of these three checks, the board is invalid.

### Algorithm

1. **Check all rows**:
    
    - For each row index `row` from `0` to `8`:
        - Create an empty set `seen`.
        - For each column index `i` from `0` to `8`:
            - Skip if the cell is `"."`.
            - If the value is already in `seen`, return `false`.
            - Otherwise, add it to `seen`.
2. **Check all columns**:
    
    - For each column index `col` from `0` to `8`:
        - Create an empty set `seen`.
        - For each row index `i` from `0` to `8`:
            - Skip if the cell is `"."`.
            - If the value is already in `seen`, return `false`.
            - Otherwise, add it to `seen`.
3. **Check all 3×3 boxes**:
    
    - Number the 3×3 boxes from `0` to `8`.
    - For each `square`:
        - Create an empty set `seen`.
        - For `i` in `0..2` and `j` in `0..2`:
            - Compute:
                - `row = (square // 3) * 3 + i`
                - `col = (square % 3) * 3 + j`
            - Skip if the cell is `"."`.
            - If the value is already in `seen`, return `false`.
            - Otherwise, add it to `seen`.
4. If all rows, columns, and 3×3 boxes pass these checks without duplicates, return `true`.

```python

class Solution:
    def isValidSudoku(self, board: List[List[str]]) -> bool:
        for row in range(9):
            seen = set()
            for i in range(9):
                if board[row][i] == ".":
                    continue
                if board[row][i] in seen:
                    return False
                seen.add(board[row][i])

        for col in range(9):
            seen = set()
            for i in range(9):
                if board[i][col] == ".":
                    continue
                if board[i][col] in seen:
                    return False
                seen.add(board[i][col])

        for square in range(9):
            seen = set()
            for i in range(3):
                for j in range(3):
                    row = (square//3) * 3 + i
                    col = (square % 3) * 3 + j
                    if board[row][col] == ".":
                        continue
                    if board[row][col] in seen:
                        return False
                    seen.add(board[row][col])
        return True
```
---



## 2. Hash Set (One Pass)

### Intuition

Instead of checking rows, columns, and 3×3 boxes separately, we can validate the entire Sudoku board in **one single pass**.  
For each cell, we check whether the digit has already appeared in:

1. the same **row**
2. the same **column**
3. the same **3×3 box**

We track these using three hash sets:

- `rows[r]` keeps digits seen in row `r`
- `cols[c]` keeps digits seen in column `c`
- `squares[(r // 3, c // 3)]` keeps digits in the 3×3 box

If a digit appears again in any of these places, the board is invalid.

### Algorithm

1. Create three hash maps of sets:
    
    - `rows` to track digits in each row
    - `cols` to track digits in each column
    - `squares` to track digits in each 3×3 sub-box, keyed by `(r // 3, c // 3)`
2. Loop through every cell in the board:
    
    - Skip the cell if it contains `"."`.
    - Let `val` be the digit in the cell.
    - If `val` is already in:
        - `rows[r]` → duplicate in the row
        - `cols[c]` → duplicate in the column
        - `squares[(r // 3, c // 3)]` → duplicate in the 3×3 box  
            Then return `false`.
3. Otherwise, add the digit to all three sets:
    
    - `rows[r]`
    - `cols[c]`
    - `squares[(r // 3, c // 3)]`
4. If the whole board is scanned without detecting duplicates, return `true`.

```python

class Solution:
    def isValidSudoku(self, board: List[List[str]]) -> bool:
        cols = defaultdict(set)
        rows = defaultdict(set)
        squares = defaultdict(set)

        for r in range(9):
            for c in range(9):
                if board[r][c] == ".":
                    continue
                if ( board[r][c] in rows[r]
                    or board[r][c] in cols[c]
                    or board[r][c] in squares[(r // 3, c // 3)]):
                    return False

                cols[c].add(board[r][c])
                rows[r].add(board[r][c])
                squares[(r // 3, c // 3)].add(board[r][c])

        return True
```

---

## 3. Bitmask

### Intuition

Every digit from `1` to `9` can be represented using a single bit in an integer.  
For example, digit `1` uses bit `0`, digit `2` uses bit `1`, …, digit `9` uses bit `8`.  
This means we can track which digits have appeared in a row, column, or 3×3 box using just **one integer per row/column/box** instead of a hash set.

When we encounter a digit, we compute its bit position and check:

- if that bit is already set in the row → duplicate in row
- if that bit is already set in the column → duplicate in column
- if that bit is already set in the box → duplicate in box

If none of these checks fail, we “turn on” that bit to mark the digit as seen.  
This approach is both memory efficient and fast.

### Algorithm

1. Create three arrays of size 9:
    
    - `rows[i]` stores bits for digits seen in row `i`
    - `cols[i]` stores bits for digits seen in column `i`
    - `squares[i]` stores bits for digits seen in 3×3 box `i`
2. Loop through each cell `(r, c)` of the board:
    
    - Skip if the cell contains `"."`.
    - Convert the digit to a bit index: `val = int(board[r][c]) - 1`.
    - Compute the mask: `mask = 1 << val`.
3. Check for duplicates:
    
    - If `mask` is already set in `rows[r]`, return `false`.
    - If `mask` is already set in `cols[c]`, return `false`.
    - If `mask` is already set in `squares[(r // 3) * 3 + (c // 3)]`, return `false`.
4. Mark the digit as seen:
    
    - `rows[r] |= mask`
    - `cols[c] |= mask`
    - `squares[(r // 3) * 3 + (c // 3)] |= mask`
5. If all cells are processed without conflicts, return `true`.
    

Example - Dry Run

  

```python
class Solution:
    def isValidSudoku(self, board: List[List[str]]) -> bool:
        rows = [0] * 9
        cols = [0] * 9
        squares = [0] * 9

        for r in range(9):
            for c in range(9):
                if board[r][c] == ".":
                    continue

                val = int(board[r][c]) - 1
                if (1 << val) & rows[r]:
                    return False
                if (1 << val) & cols[c]:
                    return False
                if (1 << val) & squares[(r // 3) * 3 + (c // 3)]:
                    return False

                rows[r] |= (1 << val)
                cols[c] |= (1 << val)
                squares[(r // 3) * 3 + (c // 3)] |= (1 << val)

        return True
```

### Time & Space Complexity

- Time complexity: O(n2)O(n2)
- Space complexity: O(n)O(n)

---

## Common Pitfalls

### Wrong Box Index Calculation

The 3x3 box index formula `(r // 3) * 3 + (c // 3)` is easy to get wrong. A common mistake is using `(r // 3, c // 3)` as a tuple key but forgetting integer division, or computing `r // 3 + c // 3` which doesn't uniquely identify boxes.

```python
# Wrong: doesn't uniquely identify boxes
box_idx = r // 3 + c // 3  # Box (0,1) and (1,0) both give 1
# Correct: unique box index 0-8
box_idx = (r // 3) * 3 + c // 3
```

### Not Skipping Empty Cells

Empty cells are represented by `"."` and should be skipped entirely. Forgetting to check for empty cells before processing will cause errors or incorrect duplicate detection.

### Checking Validity vs Solvability

This problem only checks if the current board state is valid, not whether the puzzle is solvable. A board with no duplicates is valid even if it's impossible to complete.

### Processing the Same Cell Multiple Times

When iterating through the board, make sure each cell is only processed once. Some implementations accidentally check the same digit multiple times when validating rows, columns, and boxes separately.
