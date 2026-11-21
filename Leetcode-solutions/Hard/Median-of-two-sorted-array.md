
## Problem
You are given two integer arrays nums1 and nums2 of size m and n respectively, where each is sorted in ascending order. Return the median value among all elements of the two arrays.

Your solution should run in 
O(log(m+n)) time.


Example 1:

Input: nums1 = [1,2], nums2 = [3]
Output: 2.0
Explanation: Among [1, 2, 3] the median is 2.


Example 2:

Input: nums1 = [1,3], nums2 = [2,4]
Output: 2.5
Explanation: Among [1, 2, 3, 4] the median is (2 + 3) / 2 = 2.5.


### Brute Force
Intuition:
- The simplest way to find the median of two sorted arrays is to combine them into one array and then sort it.
Once everything is merged and sorted, finding the median becomes straightforward:

- If the total number of elements is odd → the middle element is the median.
- If even → the median is the average of the two middle elements.
- This method is easy to understand but does not take advantage of the fact that the input arrays are already sorted.
