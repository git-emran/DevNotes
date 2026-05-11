You are given an array of integers `nums` and an integer `k`. There is a sliding window of size `k` that starts at the left edge of the array. The window slides one position to the right until it reaches the right edge of the array.

Return a list that contains the maximum element in the window at each step.

**Example 1:**

```java
Input: nums = [1,2,1,0,4,2,6], k = 3

Output: [2,2,4,4,6]

Explanation:
Window position            Max
---------------           -----
[1  2  1] 0  4  2  6        2
 1 [2  1  0] 4  2  6        2
 1  2 [1  0  4] 2  6        4
 1  2  1 [0  4  2] 6        4
 1  2  1  0 [4  2  6]       6
```

**Constraints:**

- `1 <= nums.length <= 100,000`
- `-10,000 <= nums[i] <= 10,000`
- `1 <= k <= nums.length`

```python
```python

class Solution:
    def maxSlidingWindow(self, nums: List[int], k: int) -> List[int]:
        heap = []
        result = []

        for i in range(len(nums)):
            heapq.heappush(heap, (-nums[i], i))

            if i >= k - 1 :
                while heap[0][1] <= i - k :
                    heapq.heappop(heap)
                result.append(-heap[0][0])
        return result
```
```