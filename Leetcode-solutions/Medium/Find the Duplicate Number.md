
MediumTopicsCompany TagsHints

You are given an array of integers `nums` containing `n + 1` integers. Each integer in `nums` is in the range `[1, n]` inclusive.

There is exactly **one repeated integer** in `nums`, and every other integer appears at most once.

Return the repeated integer.

**Example 1:**

```java
Input: nums = [1,2,3,2,2]

Output: 2
```

**Example 2:**

```java
Input: nums = [1,2,3,4,4]

Output: 4
```

Follow-up: Can you solve the problem **without** modifying the array `nums` and using O(1)O(1) extra space?

**Constraints:**

- `1 <= n <= 10,000`
- `nums.length == n + 1`
- `1 <= nums[i] <= n`

## 2. Hash Set

### Intuition

We can detect duplicates by remembering which numbers we have already seen.  
As we scan the array, each new number is checked:

- If it's **not in the set**, we add it.
- If it **is already in the set**, that number must be the duplicate.

A set gives constant-time lookup, so this approach is simple and efficient.

### Algorithm

1. Create an empty hash set `seen`.
2. Loop through each number in the array:
    - If the number is already in `seen`, return it (this is the duplicate).
    - Otherwise, insert the number into `seen`.
3. If no duplicate is found (should not happen in this problem), return `-1`.


Python:
```python

class Solution:
    def findDuplicate(self, nums: List[int]) -> int:
        seen = set()
        for num in nums:
            if num in seen:
                return num
            seen.add(num)
        return -1

```

C++:
```c++

class Solution {
public:
    int findDuplicate(std::vector<int>& nums) {
        unordered_set<int> seen;
        for (int num : nums) {
            if (seen.find(num) != seen.end()) {
                return num;
            }
            seen.insert(num);
        }
        return -1;
    }
};

```


