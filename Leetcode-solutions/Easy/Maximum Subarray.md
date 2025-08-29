Given an integer array nums, find the subarray with the largest sum, and return its sum.

> Topics: Divide and Conquer, Dynamic Programming

### Solve using Kedane's Algorithm

Some Exmaple :

```
Example 1:

Input: nums = [-2,1,-3,4,-1,2,1,-5,4]
Output: 6
Explanation: The subarray [4,-1,2,1] has the largest sum 6.
Example 2:

Input: nums = [1]
Output: 1
Explanation: The subarray [1] has the largest sum 1.
Example 3:

Input: nums = [5,4,-1,7,8]
Output: 23
Explanation: The subarray [5,4,-1,7,8] has the largest sum 23.

```

#### Algorithm

1. Let's use Kedanes algorithm. We'll track `currentSum` and `maxSum`.
2. At each step, we add the current number to `currentSum`.
3. If `currentSum` exceeds the `maxSum` we update the `maxSum`.
4. If `currentSum` goes negative we update it to 0.
5. The Final `maxSum` is 6 from `[4, -1, 2, 1]`

> The Time complexity here is `o(n)` since we go through the array once.

##### Solution

```javascript
/**
 * @param {number[]} nums
 * @return {number}
 */
var maxSubArray = function (nums) {
  let maxSum = -Infinity;
  let currentSum = 0;

  for (const num of nums) {
    currentSum += num;

    if (currentSum > maxSum) {
      maxSum = currentSum;
    }

    if (currentSum < 0) {
      currentSum = 0;
    }
  }

  return maxSum;
};
```

Another way to solve it by comparing..

```javascript
var maxSubArray = function (nums) {
  let maxSum = -Infinity;

  let currentSum = 0;

  for (let num of nums) {
    currentSum = Math.max(num, currentSum + num);

    maxSum = Math.max(currentSum, maxSum);
  }

  return maxSum;
};
```
