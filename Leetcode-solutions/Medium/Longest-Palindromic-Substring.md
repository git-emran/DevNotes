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
