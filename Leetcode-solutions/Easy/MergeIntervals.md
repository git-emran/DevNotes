#### Question:

Given an array of `intervals` where `intervals[i] = [starti, endi]`, merge all overlapping intervals, and return *an array of the non-overlapping intervals that cover all the intervals in the input*.

**Example 1:**

**Input:** intervals = `[[1,3],[2,6],[8,10],[15,18]]`
**Output:** `[[1,6],[8,10],[15,18]]`
**Explanation:** Since intervals `[1,3] and [2,6] overlap, merge them into [1,6]`

**Example 2:**

**Input:** intervals =`[[1,4],[4,5]]`
**Output:** `[[1,5]]`
**Explanation:** Intervals [1,4] and [4,5] are considered overlapping.

**Example 3:**

**Input:** intervals =`[[4,7],[1,4]]`
**Output:** `[[1,7]]`
**Explanation:** Intervals [1,4] and [4,7] are considered overlapping.

### Solution:

Algorithm:

- Start with the edge case first, where if the array is empty, we return empty.
- Sort the intervals array so that I can merge the intervals easily as the intervals going to be merged are kept side by side. Perform sort intervals by start time, and by end time if start is the same.

- let us open a memory for the new array that will be returned.
- Start a loop where we go through the intervals array, if the first interval is zero or the start time is less than the previous interval, then we add the current interval to the memory. Else replace the second index of the arrival with the bigger index between the merged and the end index.

##### Javascript:

```Javascript

 * @param {number[][]} intervals
 * @return {number[][]}
 */
var merge = function(intervals) {

	// Edge case
    if (intervals.length === 0) return []
	
	// Sorting the first index of the both intervals
    intervals.sort((a,b) => a[0] - b[0])

	// create a new node to store the array
    const merged = []

    for (const [start, end] of intervals ) {
        if (merged.length === 0 || start > merged[merged.length - 1][1]) {
             merged.push([start, end])
        } else {
            merged[merged.length - 1][1] = Math.max(merged[merged.length -1][1], end)
        }
    }

    return merged
}

```
