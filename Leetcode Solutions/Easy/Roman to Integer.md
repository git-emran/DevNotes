
Roman numerals are represented by seven different symbols: `I`, `V`, `X`, `L`, `C`, `D` and `M`.

##### Edge case: 
+ What happens when user enters something like MIVXXV where there 

> Using Python `zip(s, s[1:])` to explicitly turn strings into pairs
##### Solving using Greedy logic: 

* To convert - we need to take `s: string` as a parameter
* Creating an empty result variable. `result = 0`
* Take in the `roman` as an dictionary
* Then making a loop with a & b variables and split the given integer in explicit pairs using
  `for a,b in zip(s, s[1:]):`
* Next step is to check if `roman[a]` list is less than `roman[b]`, if yes return the result by subtracting `roman [a]` from the result. Else add it. 
* Final return structure should look like - 
   `response + roman[s[-1]]`
+ Adding result at the end of the list.


```
class Solution:

	def romanToInt(self, s: str) -> int:

	result = 0

	roman = {
	
	'I': 1,
	
	'V': 5,
	
	'X': 10,
	
	'L': 50,
	
	'C': 100,
	
	'D': 500,
	
	'M': 1000
	
	}

	for a, b in zip(s, s[1:]):

		if roman[a] < roman[b]:

			result -= roman[a]

		else:

			result += roman[a]

	return result + roman[s[-1]]
```