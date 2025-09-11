+ First checking if the char and bracket_map values are equal or not. If yes, append the char to stack
+ Else, if check if the stack is empty or last item of stack is not equal to  `bracket_map[char]` .
+ If it's true the return False.
+ And close the For loop by return empty `stack`

```python
class Solution:

def isValid(self, s: str) -> bool:
	stack = []
	bracket_map {')': '(', '}': '{', ']': '['}

	for char in s:
	
		if char in bracket_map.values():
	
			stack.append(char)
	
		elif char in bracket_map:
	
			if not stack or bracket_map[char] != stack.pop()
				return False
			
	return not Stack
```

##### Alternatively
```python
elif char in bracket_map.keys():
	if not stack or bracket_map[char] != stack.pop():
		return False

	
```

##### and Finally closing the for loop with
```python
return not stack or Empty stack
```
