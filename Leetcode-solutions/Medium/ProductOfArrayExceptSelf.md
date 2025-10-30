# Product of Array Except self:

Given an integer array nums, return an array answer such that `answer[i]` is equal to the product of all the elements of nums except `nums[i]`.

The product of any prefix or suffix of nums is guaranteed to fit in a 32-bit integer.

You must write an algorithm that runs in O(n) time and without using the division operation.

    Example 1:

    Input: nums = [1,2,3,4]
    Output: [24,12,8,6]
    Example 2:

    Input: nums = [-1,1,0,-3,3]
    Output: [0,0,9,0,0]

Constraints:

    2 <= nums.length <= 105
    -30 <= nums[i] <= 30
    The input is generated such that answer[i] is guaranteed to fit in a 32-bit integer.

#### Brute Force:

lets start with the brute force:

```py

class Solution:
    def productExceptSelf(self, nums: List[int]) -> List[int]:
        n = len(nums)
        result = [1] * n
        for i in range(n):
            prod = 1
            for j in range(n):
                if i == j:
                    continue
                prod *= nums[j]
            result[i] = prod
        return result

```

##### Time Complexity O(n^2)

Initializing the result array with 1's. An outerloop to iterate over the value of the array and start a product for this with 1 for this i. Start an inner loop, iterate over all positions, skip multiplying the value at index. Multiply the running product with by `nums[j]`. Store the final product at index i `result[i]`. Return `result`

##### Optimized Solution - Prefix and suffix product

```py


class Solution:
    def productExceptSelf(self, nums: List[int]) -> List[int]:
        n = len(nums)
        result = [1] * n

        left = 1
        for i in range(n):
            result[i] *= left
            left *= nums[i]

        right = 1

        for i in range(n):

            result[i] *= right
            right *= nums[i]
        return result
```
