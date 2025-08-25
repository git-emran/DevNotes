
Approaching with the two pointer method. Creating self.head and self.tail. Dividing self length by 2 and if left value doesn't match the right value return false, else turn left pointer to next and right pointer to prev.

```
   def is_palindrome(self): 
        if self.length <= 1:
            return True

        left = self.head
        right = self.tail

        for _ in range(self.length // 2):
            if left.value != right.value:
                return False
            left = left.next
            right = right.prev

        return True

```


#### Now with x : int :

Edge cases - 
+ Negative numbers are not palindromes. `x < 0 `
+ Numbers ending in zero cannot be palindromes unless they are zero. 

###### Reverse half of the Digits: 
+ Using a variable to store the `revertedNumber`
+ While ` x > revertedNumber` take each digits and store it in `revertedNumber`

###### Checking for palindromes :
+ For even digit numbers - `x == revertedNumber`
+ For odd digit numbers removing the middle 
 

```

class Solution: 

	def isPalindrome(self, x: int) -> bool:
	
		if x < 0 or (x % 10 == 0 and x != 0):
		
			return False
	
		reversed_digits = 0
	
	  
	
		while x > reversed_digits :
	
			reversed_digits = reversed_digits * 10 + x % 10
	
			x //= 10
	
	  
	
		return x == reversed_digits or x == reversed_digits // 10
```


