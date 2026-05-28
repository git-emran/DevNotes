iven an array of integers `heights` representing the histogram's bar height where the width of each bar is `1`, return _the area of the largest rectangle in the histogram_.

**Example 1:**

![447](https://assets.leetcode.com/uploads/2021/01/04/histogram.jpg)

**Input:** heights = [2,1,5,6,2,3]
**Output:** 10
**Explanation:** The above is a histogram where width of each bar is 1.
The largest rectangle is shown in the red area, which has an area = 10 units.

**Example 2:**

![170](https://assets.leetcode.com/uploads/2021/01/04/histogram-1.jpg)

**Input:** heights = [2,4]
**Output:** 4

**Constraints:**

- `1 <= heights.length <= 105`
- `0 <= heights[i] <= 104`


# Brute Force
### Intuition

For every bar, we try to treat it as the **shortest bar** in the rectangle.  
To find how wide this rectangle can extend, we look **left** and **right** until we hit a bar shorter than the current one.  
The width between these two boundaries gives the largest rectangle where this bar is the limiting height.  
We repeat this for every bar and keep track of the maximum rectangle found.

### Algorithm

1. Let `maxArea` store the largest rectangle found.
2. For each index `i`:
    - Let `height` be the height of the current bar.
    - Expand to the **right** until you find a bar shorter than `height`.
    - Expand to the **left** while bars are not shorter than `height`.
    - Compute the width between the boundaries.
    - Update `maxArea` with `height * width`.
3. Return `maxArea`.

```python

class Solution:
    def largestRectangleArea(self, heights: List[int]) -> int:
        n = len(heights)
        maxarea = 0
        for i in range(n):
            height = heights[i]

            right_pointer = i
            while right_pointer < n and heights[right_pointer] >= height:
                right_pointer += 1

            left_pointer = i
            while left_pointer >= 0 and heights[left_pointer] >= height:
                left_pointer -= 1
            
            right_pointer -= 1
            left_pointer += 1
            maxarea = max(maxarea, height * (right_pointer - left_pointer + 1))
        return maxarea
        



```

# Stack (Optimal):
### Intuition

We want, for every bar, to know how wide it can stretch while still being the **shortest bar** in that rectangle.

A monotonic stack helps with this:

- We keep a stack of indices where the bar heights are in **increasing order**.
- As long as the next bar is **taller or equal**, we keep pushing indices.
- When we see a **shorter** bar, it means the bar on top of the stack can’t extend further to the right:
    - We pop it and treat it as the height of a rectangle.
    - Its width goes from the new top of the stack + 1 up to the current index − 1.

To make sure every bar eventually gets popped and processed, we run the loop one extra step with a “virtual” bar of height 0 at the end.  
Each bar is pushed and popped at most once, so this is both optimal and clean.

### Algorithm

1. Initialize:
    - `maxArea = 0`
    - An empty stack to store indices of bars (with heights in increasing order).
2. Loop `i` from `0` to `n` (inclusive):
    - While the stack is not empty **and** either:
        - `i == n` (we're past the last bar, acting like height `0`), or
        - `heights[i]` is **less than or equal** to the height at the top index of the stack:
            - Pop the top index; let its height be `h`.
            - Compute the width:
                - If the stack is empty, width = `i` (it extends from `0` to `i - 1`).
                - Otherwise, width = `i - stack.top() - 1`.
            - Update `maxArea` with `h * width`.
    - Push the current index `i` onto the stack.
3. After the loop, `maxArea` holds the largest rectangle area. Return it.

```python

class Solution:
    def largestRectangleArea(self, heights: List[int]) -> int:
        n = len(heights)
        maxarea = 0
        stack = []
        for i in range(n + 1):
            while stack and (i == n or heights[stack[-1]] >= heights[i]):
                height = heights[stack.pop()]
                width = i if not stack else i - stack[-1] -1
                maxarea = max(maxarea, height * width)
            stack.append(i)

        return maxarea
        
```