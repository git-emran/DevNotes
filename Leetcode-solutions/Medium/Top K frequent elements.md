Given an integer array `nums` and an integer `k`, return *the* `k` *most frequent elements*. You may return the answer in **any order**.

    **Example 1:**

    **Input:** nums = [1,1,1,2,2,3], k = 2

    **Output:** [1,2]

    **Example 2:**

    **Input:** nums = [1], k = 1

    **Output:** [1]

    **Example 3:**

    **Input:** nums = [1,2,1,2,1,2,3,1,3,2], k = 2

    **Output:** [1,2]

**Constraints:**

- `1 <= nums.length <= 105`
- `-104 <= nums[i] <= 104`
- `k` is in the range `[1, the number of unique elements in the array]`.
- It is **guaranteed** that the answer is **unique**.

**Follow up:** Your algorithm's time complexity must be better than `O(n log n)`, where n is the array's size.

```c++

class Solution  {
	public :

	vector<int> topKFrequent(vector<int>& nums, int k) {

		unordered_map<int, int> count;

		for (int n :nums){
			count[n]++;
		}

		vector<vector<int>> freq(nums.size()+1);

		for(const auto& entry: count){
			freq[entry.second].push_back(entry.first)
		}

		vector<int> res;
		for(int i = freq.size() - 1; i>0; --i){
			for(int n: freq[i]){
				res.push_back(n);
			}
			if (res.size() == k) {
				return res;
			}
		}
		return res;

	}
}

```

## Sorting

##### Intuition

- To find the `k` most frequent elements, we first need to know how often each number appears.
- Once we count the frequencies, we can sort the unique numbers based on how many times they occur.
- After sorting, the numbers with the highest frequencies will naturally appear at the end of the list.
- By taking the last `k` entries, we get the `k` most frequent elements.

This approach is easy to reason about:  
**count the frequencies → sort by frequency → take the top `k`.**

##### Algorithm

1. Create a hash map to store the frequency of each number.
2. Build a list of `[frequency, number]` pairs from the map.
3. Sort this list in ascending order based on frequency.
4. Create an empty result list.
5. Repeatedly pop from the end of the sorted list (highest frequency) and append the number to the result.
6. Stop when the result contains `k` elements.
7. Return the result list.

```python

class Solution:

	def topKFrequent(self, nums: List[int], k: int) -> List[int]:
	
		count = {}
		
		for num in nums:
			count[num] = 1 + count.get(num, 0)
			
		arr = []
		
		for cnt, num in count.items():
			arr.append([num, cnt])
		
		res = []
		while len(res) < k :
			res.append(res.pop()[1])
		return res
		

```



## Min-heap

### Intuition

After counting how often each number appears, we want to efficiently keep track of only the `k` most frequent elements.  
A **min-heap** is perfect for this because it always keeps the smallest element at the top.  
By pushing `(frequency, value)` pairs into the heap and removing the smallest whenever the heap grows beyond size `k`, we ensure that the heap always contains the top `k` most frequent elements.  
In the end, the heap holds exactly the `k` values with the highest frequencies.

### Algorithm

1. Build a frequency map that counts how many times each number appears.
2. Create an empty min-heap.
3. For each number in the frequency map:
    - Push `(frequency, number)` into the heap.
    - If the heap size becomes greater than `k`, pop once to remove the smallest frequency.
4. After processing all numbers, the heap contains the `k` most frequent elements.
5. Pop all elements from the heap and collect their numbers into the result list.
6. Return the result.

```python

class Solution:

	def topKFrequent(self, nums: List[int], k: int) -> List[int]:
		count = {}
		
		for num in nums:
			count[num] = 1 + count.get(num, 0)
			
		heap = []
		
		for num in count.keys():
		
	

```