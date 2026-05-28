Given an array of integers `nums` which is sorted in ascending order, and an integer `target`, write a function to search `target` in `nums`. If `target` exists, then return its index. Otherwise, return `-1`.

You must write an algorithm with `O(log n)` runtime complexity.

**Example 1:**

**Input:** nums = [-1,0,3,5,9,12], target = 9
**Output:** 4
**Explanation:** 9 exists in nums and its index is 4

**Example 2:**

**Input:** nums = [-1,0,3,5,9,12], target = 2
**Output:** -1
**Explanation:** 2 does not exist in nums so return -1o

# Stack Iterative: 
### Intuition

Binary search checks the middle element of a sorted array and decides which half to discard.  
Instead of using recursion, the iterative approach keeps shrinking the search range using a loop.  
We adjust the left and right pointers until we either find the target or the pointers cross, meaning the target isn’t present.

### Algorithm
1. Initialize two pointers:
    - `l = 0` (start of array)
    - `r = len(nums) - 1` (end of array)
2. While `l <= r`:
    - Compute `m = l + (r - l) // 2` (safe midpoint).
    - If `nums[m] == target`, return `m`.
    - If `nums[m] < target`, move search to the right half: update `l = m + 1`.
    - If `nums[m] > target`, move search to the left half: update `r = m - 1`.
3. If the loop ends without finding the target, return `-1`.

```python

class Solution:
    def search(self, nums: List[int], target: int) -> int:
        l, r = 0, len(nums) - 1

        while l <= r:
            m = l + ((r - l) // 2)
            if nums[m] > target:
                r = m - 1
            elif nums[m] < target:
                l = m + 1
            else:
               return m 
        return -1 
```