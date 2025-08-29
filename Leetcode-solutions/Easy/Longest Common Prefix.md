
Find the longest common characters in a list of words

##### Edge case
+ If there is no `strs` return an empty "" string.

##### Solution
+ For everything in range of length of the strings



```
class Solution:

	def longestCommonPrefix(self, strs: List[str]) -> str:
	
		//edge cases first
		if not strs
			return "
		for i in range(len(strs[0][1:])):
			char = strs[0][i]
			for word in strs[1:]:
				if i >= len(word) or word[i] != char:
					return strs[0][:i]
		return strs[0]
		

```