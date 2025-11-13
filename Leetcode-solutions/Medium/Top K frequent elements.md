Given an integer array `nums` and an integer `k`, return _the_ `k` _most frequent elements_. You may return the answer in **any order**.

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