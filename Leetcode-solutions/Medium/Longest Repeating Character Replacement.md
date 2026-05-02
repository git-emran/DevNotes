MediumTopicsCompany TagsHints

You are given a string `s` consisting of only uppercase english characters and an integer `k`. You can choose up to `k` characters of the string and replace them with any other uppercase English character.

After performing at most `k` replacements, return the length of the longest substring which contains only one distinct character.

**Example 1:**

```java
Input: s = "XYYX", k = 2

Output: 4
```

Explanation: Either replace the 'X's with 'Y's, or replace the 'Y's with 'X's.

**Example 2:**

```java
Input: s = "AAABABB", k = 1

Output: 5
```

**Constraints:**

- `1 <= s.length <= 1000`
- `0 <= k <= s.length`



## Sliding Window (Optimal)

### Intuition

We want the longest window where we can make all characters the same using at most `k` replacements.  
The key insight is that the window is valid as long as:

**window size – count of the most frequent character ≤ k**

Why?  
Because the characters that _aren't_ the most frequent are the ones we would need to replace.

So while expanding the window, we track:

- the frequency of each character,
- the most frequent character inside the window (`maxf`).

If the window becomes invalid, we shrink it from the left.  
This gives us one clean sliding window pass.

### Algorithm

1. Create a frequency map `count` and initialize `l = 0`, `maxf = 0`, and `res = 0`.
2. Move the right pointer `r` across the string:
    - Update the frequency of `s[r]`.
    - Update `maxf` with the highest frequency seen so far.
3. If the window is invalid (`window size - maxf > k`):
    - Shrink the window from the left and adjust counts.
4. Update the result with the valid window size.
5. Return `res` at the end.


```python


class Solution:

	def characterReplacement(self, s: str, k: int) -> int:
		count = {}
		l = 0
		most_frequent = 0
		res = 0
		
		for r in range(len(s)):
			count[s[r]] = 1 + count.get(s[r], 0)
			most_frequent = max(most_frequent, count[s[r]])
			
			while (r-l+1) - most_frequent > k:
				count[s[l]] = count[s[l]] - 1
				l += 1
				
		res = max(res, r-l+1)
		
		return res
```