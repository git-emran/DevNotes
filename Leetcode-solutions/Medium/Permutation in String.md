
You are given two strings `s1` and `s2`.

Return `true` if `s2` contains a permutation of `s1`, or `false` otherwise. That means if a permutation of `s1` exists as a substring of `s2`, then return `true`.

Both strings only contain lowercase letters.

**Example 1:**

```java
Input: s1 = "abc", s2 = "lecabee"

Output: true
```

Explanation: The substring `"cab"` is a permutation of `"abc"` and is present in `"lecabee"`.

**Example 2:**

```java
Input: s1 = "abc", s2 = "lecaabee"

Output: false
```

**Constraints:**

- `1 <= s1.length, s2.length <= 1000`


---
# Sliding Window

### Intuition

Since a permutation of `s1` must have the **same character counts**, we can use a fixed-size sliding window over `s2` whose length is exactly `len(s1)`.  
We maintain two frequency arrays:

- one for `s1`
- one for the current window in `s2`

If these two arrays ever match, the window is a valid permutation.  
As we slide the window forward, we update counts by removing the left character and adding the new right character — no need to rebuild the counts each time.  
This makes the solution fast and efficient.

### Algorithm

1. If `s1` is longer than `s2`, return `false`.
2. Build character frequency arrays for:
    - `s1`
    - the first window of `s2` of size `len(s1)`
3. Count how many positions match between the two arrays (`matches`).
4. Slide the window from left to right across `s2`:
    - At each step, add the new right character and update counts/matches.
    - Remove the left character and update counts/matches.
    - If at any time `matches == 26`, return `true`.
5. After finishing the loop, return whether `matches == 26`.

```python

class Solution:

	def checkInclusion(self, s1: str, s2: str) -> bool:
	
		if len(s1) > len(s2):
			return False
			
		s1Count, s2Count = [0] * 26, [0] * 26
		
		for i in range(len(s1)):
			s1Count[ord(s1[i]) - ord('a')] += 1
			s2Count[ord(s2[i]) - ord('a')] += 1
		matches = 0
		
		for i in range(26):
		
			matches += (1 if s1Count[i] == s2Count[i] else 0)
		
		l = 0
		
		for r in range(len(s1), len(s2)):
			if matches == 26:
				return True
			
			index = ord(s2[r]) - ord('a')
			s2Count[index] += 1
			if s1Count[index] == s2Count[index]:
				matches += 1
			
			elif s1Count[index] + 1 == s2Count[index]:
				matches -= 1
				
			index = ord(s2[l]) - ord('a')
			s2Count[index] -= 1
			
			if s1Count[index] == s2Count[index]:
				matches += 1
			elif s1Count[index] - 1 == s2Count[index]:
				matches -= 1
				
			l += 1
		return matches == 26
```