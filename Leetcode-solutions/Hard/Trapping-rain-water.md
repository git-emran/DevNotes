# Trapping rain water

[LeetCode Link](https://leetcode.com/problems/trapping-rain-water/description/)

### Given n non-negative integers representing an elevation map where the width of each bar is 1, compute how much water it can trap after raining.

Example:
Given [0,1,0,2,1,0,1,3,2,1,2,1], return 6.


#### Approach:

- We use a two pointer approach to solve this problem.
- Initialize the two pointers from the very left and right of the array.
- While left pointer is less than right pointer, if `left_max` is less than `right_max`, add water, which the substracting difference between `left_max` , and current index and we move the pointer. Set the `left_max` to the highest number between the left max and the current right index. Else we do the exactly same with the right pointer and move the pointer also set the right max as the max number between `right_max` and current left index.

```python

class Solution:
    def trap(self, height: List[int]) -> int:
        i = 0
        water = 0
        left_max = height[0]
        j = len(height) - 1
        right_max = height[j]

        while i < j:
            if left_max <= right_max:
                water += left_max - height[i]
                i += 1
                left_max = max(left_max, height[i])
            else:
                water += right_max - height[j]
                j -= 1
                right_max = max(right_max, height[j])

        return water

```
