Given a string `s`, return _the number of **palindromic substrings** in it_.

A string is a **palindrome** when it reads the same backward as forward.

A **substring** is a contiguous sequence of characters within the string.

**Example 1:**

**Input:** s = "abc"
**Output:** 3
**Explanation:** Three palindromic strings: "a", "b", "c".

**Example 2:**

**Input:** s = "aaa"
**Output:** 6
**Explanation:** Six palindromic strings: "a", "a", "a", "aa", "aa", "aaa".

**Constraints:**

- `1 <= s.length <= 1000`
- `s` consists of lowercase English letters.o

### Two Pointers ( Brute):
### Algorithm

1. Initialize `res = 0`
2. For each index `i` in the string:
    - **Odd-length palindromes**
        - Set `l = i`, `r = i`
        - While `l >= 0`, `r < n`, and `s[l] == s[r]`:
            - Increment `res`
            - Expand: `l--`, `r++`
    - **Even-length palindromes**
        - Set `l = i`, `r = i + 1`
        - While `l >= 0`, `r < n`, and `s[l] == s[r]`:
            - Increment `res`
            - Expand: `l--`, `r++`
3. Return `res`
```python
class Solution:
    def countSubstrings(self, s: str) -> int:
        res = 0

        for i in range(len(s)):
            # odd length
            l, r = i, i
            while l >= 0 and r < len(s) and s[l] == s[r]:
                res += 1
                l -= 1
                r += 1

            # even length
            l, r = i, i + 1
            while l >= 0 and r < len(s) and s[l] == s[r]:
                res += 1
                l -= 1
                r += 1

        return res
```


### Two pointers optimal
### Intuition

Every palindromic substring can be identified by **expanding from its center**.

There are only **two possible centers** for any palindrome:

1. A **single character** → odd-length palindromes
2. The **gap between two characters** → even-length palindromes

Instead of duplicating logic for both cases, we extract the expansion logic into a helper function (`countPali`).  
This keeps the solution **clean, reusable, and optimal**.

For each index `i`, we:

- Count palindromes centered at `(i, i)`
- Count palindromes centered at `(i, i + 1)`

Each successful expansion corresponds to **one valid palindrome**.

### Algorithm

1. Initialize `res = 0`
2. For each index `i` in the string:
    - Add palindromes from **odd center**: `countPali(s, i, i)`
    - Add palindromes from **even center**: `countPali(s, i, i + 1)`
3. In `countPali(s, l, r)`:
    - While `l >= 0`, `r < n`, and `s[l] == s[r]`:
        - Increment `res`
        - Expand outward: `l--`, `r++`
4. Return total count


```python

class Solution:

	def countSubstrings(self, s: str) -> int:
			
		res = 0
		for i in range(len(s)):
			res += self.countPali(s, i, i)
			res += self.countPali(s, i, i+1)
		return res
		
	def countPali(self, s, l, r):
		res = 0
		while l >= 0 and r < len(s) and s[l] == s[r]:
			res += 1
			l -= 1
			r += 1

		return res
```
