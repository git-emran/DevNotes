You are given an integer array `heights` where `heights[i]` represents the height of the ithith bar.

You may choose any two bars to form a container. Return the _maximum_ amount of water a container can store.

**Example 1:**

```java
Input: height = [1,7,2,5,4,7,3,6]

Output: 36
```

**Example 2:**

```java
Input: height = [2,2,2]

Output: 4
```

**Constraints:**

- `2 <= height.length <= 1000`
- `0 <= height[i] <= 1000`


---
#### Two Pointers:

##### Intuition
Using two pointers lets us efficiently search for the maximum area without checking every pair.  
We start with the widest container (left at start, right at end).  
The height is limited by the shorter line, so to potentially increase the area, we must move the pointer at the shorter line inward.  
Moving the taller line never helps because it keeps the height the same but reduces the width.  
By always moving the shorter side, we explore all meaningful possibilities.

##### Algorithm
1. Initialize two pointers:
    - `l = 0`
    - `r = len(heights) - 1`
2. Set `res = 0` to store the maximum area.
3. While `l < r`:
    - Compute the current area:  
        `area = min(heights[l], heights[r]) * (r - l)`
    - Update `res` with the maximum area so far.
    - Move the pointer at the shorter height:
        - If `heights[l] <= heights[r]`, move `l` right.
        - Otherwise, move `r` left.
4. Return `res` after the pointers meet.

```python
	class Solution:
		def maxArea(self, height: List[int]) -> int:
			l, r = 0, len(height) - 1
			res = 0
			while l < r:
				area = min(height[l], height[r]) * (r - l)
				res = max(res, area)
				if height[l] <= height[r]:
					l += 1
				else:
					r -= 1
			return res
```