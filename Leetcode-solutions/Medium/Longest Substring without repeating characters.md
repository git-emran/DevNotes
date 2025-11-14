# Longest Substring Without Repeating Characters

Given a string s, find the length of the longest substring without duplicate characters.

    Example 1:

    Input: s = "abcabcbb"
    Output: 3
    Explanation: The answer is "abc", with the length of 3. Note that "bca" and "cab" are also correct answers.
    Example 2:

    Input: s = "bbbbb"
    Output: 1
    Explanation: The answer is "b", with the length of 1.
    Example 3:

    Input: s = "pwwkew"
    Output: 3
    Explanation: The answer is "wke", with the length of 3.
    Notice that the answer must be a substring, "pwke" is a subsequence and not a substring.kk

    Constraints:

    0 <= s.length <= 5 * 104
    s consists of English letters, digits, symbols and spaces.

##### Solution

```c++

class Solution {
public:

    int lengthOfLongestSubstring (string s) {
        unordered_map<char, int> mp;
        int res = 0, l = 0;

        for(int i = 0; i < s.size(); i++) {
            if(mp.find(s[r] != mp.end())){
                l = max(mp[s[r]] + 1 , l);
            }
            max[s[r]] = r;
            res = max(res, r - l + 1);
        }
        return res;
    }
}
```
