# Longest Palindromic Substring

Given a string s, return the longest substring of s that is a palindrome.

A palindrome is a string that reads the same forward and backward.

If there are multiple palindromic substrings that have the same length, return any one of them.

Example 1:

`Input: s = "ababd"`
`Output: "bab" or "aba" or "bab"`

Example 2:

`Input: s = "abbc"`
`Output: "bb"`

Constraints:

- 1 <= s.length <= 1000
- s contains only digits and English letters

### Solution:

We are going to solve this with four method, first would be the brute force solution, second with Dynamic Programming, third would be with two pointers and lastly with Manacher's Algorithm.

###### Brute Force:

Python :

```python

class Solution:
    def longestPalindrome(self, s: str)-> str:

        res, resLen = "", 0

        for i in range(len(s)):
            for j in range(len(s)):
                l, r = i, j

                while l < r and s[l] == s[r]:
                    l += 1
                    r += 1

                if l >= r and resLen < (j-i +1):
                    res = s[i:j +1]
                    resLen = j-i+1
        return res
```

Dynamic Programming:

Intution:
### Intuition

Instead of re-checking the same substrings again and again, we **remember** whether a substring is a palindrome.

Let:

- `dp[i][j] = true` if the substring `s[i..j]` is a palindrome.

A substring `s[i..j]` is a palindrome when:

1. The end characters match: `s[i] == s[j]`
2. And the inside part is also a palindrome: `dp[i+1][j-1]`
    - **Special small cases:** if the length is 1, 2, or 3 (`j - i <= 2`), then matching ends is enough because the middle is empty or a single char.

We fill `dp` from **bottom to top** (i from n-1 down to 0) so that when we compute `dp[i][j]`, the value `dp[i+1][j-1]` is already known.

While filling, we keep track of the **best (longest) palindrome** seen so far.

### Algorithm

1. Let `n = len(s)`. Create a 2D table `dp[n][n]` initialized to `false`.
2. Keep `resIdx = 0` and `resLen = 0` for the best answer.
3. For `i` from `n-1` down to `0`:
    - For `j` from `i` up to `n-1`:
        - If `s[i] == s[j]` and (`j - i <= 2` OR `dp[i+1][j-1]` is true):
            - Mark `dp[i][j] = true`
            - If `(j - i + 1)` is bigger than `resLen`, update `resIdx` and `resLen`.
4. Return `s[resIdx : resIdx + resLen]`.
```python
class Solution:

	def longestPalindrome(self, s: str) -> str:

		resIndex, resLen = 0, 0

		n = len(s)

  

		dp = [[False] * n for _ in range(n)]

  

		for i in range(n-1, -1, -1):

			for j in range(i, n):

				if s[i] == s[j] and (j -i <= 2 or dp[i+1][j-1]):

					dp[i][j] = True

				if resLen < (j - i + 1):

					resIdx = i

					resLen = j - i + 1

		return s[resIdx : resIdx + resLen]
```

