
Given an `m x n` grid of characters `board` and a string `word`, return `true` _if_ `word` _exists in the grid_.
The word can be constructed from letters of sequentially adjacent cells, where adjacent cells are horizontally or vertically neighboring. The same letter cell may not be used more than once.


Solution:
```c++
	#include <vector>

	#include <string>

	using namespace std;

	 

	class Solution {

	public:

	    bool exist(vector<vector<char>>& board, string word) {

	        int m = board.size();

	        int n = board[0].size();

	        int W = word.size();

	 

	        if (m == 1 && n == 1) {

	            return board[0][0] == word[0];

	        }

	 

	        vector<vector<bool>> visited(m, vector<bool>(n, false));

	 

	        for (int i = 0; i < m; ++i) {

	            for (int j = 0; j < n; ++j) {

	                if (backtrack(board, word, i, j, 0, visited)) {

	                    return true;

	                }

	            }

	        }

	 

	        return false;

	    }

	 

	private:

	    bool backtrack(vector<vector<char>>& board, string& word, int i, int j, int index, vector<vector<bool>>& visited) {

	        if (index == word.size()) return true;

	 

	        if (i < 0 || j < 0 || i >= board.size() || j >= board[0].size() || visited[i][j] || board[i][j] != word[index]) {

	            return false;

	        }

	 

	        visited[i][j] = true;

	 

	        bool found = backtrack(board, word, i + 1, j, index + 1, visited) ||

	                     backtrack(board, word, i - 1, j, index + 1, visited) ||

	                     backtrack(board, word, i, j + 1, index + 1, visited) ||

	                     backtrack(board, word, i, j - 1, index + 1, visited);

	 

	        visited[i][j] = false;

	        return found;

	    }

	};

	 
```


```python

	class Solution:

	    def exist(self, board: List[List[str]], word: str) -> bool:

	        m = len(board)

	        n = len(board[0])

	        W = len(word)

	 

	        if m == 1 and n == 1:

	            return board[0][0] == word

	 

	        def backtrack(pos, index):

	            i, j = pos

	 

	            if index == W:

	                return True

	 

	            if board[i][j] != word[index]:

	                return False

	 

	            char = board[i][j]

	            board[i][j] = "#"

	 

	            for i_off, j_off in [(0, 1), (1, 0), (0, -1), (-1, 0)]:

	                r, c = i + i_off, j + j_off

	 

	                if 0 <= r < m and 0 <= c < n:

	                    if backtrack((r, c), index + 1):

	                        return True

	 

	            board[i][j] = char

	            return False

	 

	        for i in range(m):

	            for j in range(n):

	                if backtrack((i, j), 0):

	                    return True

	 

	        return False

	 

	# Time Complexity: O((m*n)^2)

	# Space Complexity: O(W)

	 
```