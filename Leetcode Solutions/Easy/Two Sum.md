

#### What is Two Sum: 
	It's objective is to find out the two indexes which adds up to the target
	

Example:

Example 1	
**Input:** nums = [2,7,11,15], target = 9
**Output:** [0,1]
**Explanation:** Because nums[0] + nums[1] == 9, we return [0, 1].	

**Example 2:**
**Input:** nums = [3,2,4], target = 6	
**Output:** [1,2]


+ First approach should be the **Brute Force** Method: Where You go through the each element x to find out if there is another value equals to  target - x . 
+ Second approach : 
  
  <pre>class Solution:
    def twoSum(self, numbers: List[int], target_sum: int) -> List[int]:
        seen_numbers = {}  # key: number, value: index

        for current_index in range(len(numbers)):
            current_number = numbers[current_index]
            needed_number = target_sum - current_number

            if needed_number in seen_numbers:
                return [seen_numbers[needed_number], current_index]

            seen_numbers[current_number] = current_index </pre>


  
