Suppose an array of length `n` sorted in ascending order is **rotated** between `1` and `n` times. For example, the array `nums = [0,1,2,4,5,6,7]` might become:

- `[4,5,6,7,0,1,2]` if it was rotated `4` times.
- `[0,1,2,4,5,6,7]` if it was rotated `7` times.

Notice that **rotating** an array `[a[0], a[1], a[2], ..., a[n-1]]` 1 time results in the array `[a[n-1], a[0], a[1], a[2], ..., a[n-2]]`.

Given the sorted rotated array `nums` of **unique** elements, return _the minimum element of this array_.

You must write an algorithm that runs in `O(log n) time`.

**Example 1:**

**Input:** nums = [3,4,5,1,2]
**Output:** 1
**Explanation:** The original array was [1,2,3,4,5] rotated 3 times.

**Example 2:**

**Input:** nums = [4,5,6,7,0,1,2]
**Output:** 0
**Explanation:** The original array was [0,1,2,4,5,6,7] and it was rotated 4 times.

**Example 3:**

**Input:** nums = [11,13,15,17]
**Output:** 11
**Explanation:** The original array was [11,13,15,17] and it was rotated 4 times. 

**Constraints:**

- `n == nums.length`
- `1 <= n <= 5000`
- `-5000 <= nums[i] <= 5000`
- All the integers of `nums` are **unique**.
- `nums` is sorted and rotated between `1` and `n` times.

## Binary Search (Lower Bound)

### Intuition

In a rotated sorted array, the minimum element is the **first element of the rotated portion**.  
Using binary search, we compare the middle value with the rightmost value:

- If `nums[mid] < nums[right]`, then the minimum lies **in the left half (including `mid`)**.
- Otherwise, the minimum lies **in the right half (excluding `mid`)**.

This behaves exactly like finding a **lower bound**, gradually shrinking the search space until only the minimum remains.

### Algorithm

1. Set `left = 0` and `right = n - 1`.
2. While `left < right`:
    - Compute `mid`.
    - If `nums[mid]` is less than `nums[right]`, move `right` to `mid` (minimum is on the left).
    - Otherwise, move `left` to `mid + 1` (minimum is on the right).
3. When the loop ends, `left` points to the smallest element.
4. Return `nums[left]`.


```python

class Solution:
    def findMin(self, nums: List[int]) -> int:
        l, r = 0, len(nums) - 1

        while l < r:
            m = l + (r - l) // 2

            if nums[m] < nums[r]:
                r = m
            else:
                l = m + 1
        return nums[l]
```

