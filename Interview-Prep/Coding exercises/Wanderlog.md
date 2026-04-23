## 🛒 **Problem — Group Transactions**

### Problem Description

You are given a list of transactions, where each transaction is represented by the **name of an item** that was purchased.  
Your task is to count how many times each item appears, then return the list of items and their transaction counts — sorted by the following rules:

1. **Descending order of transaction count** (most transactions first).
2. If two or more items have the same count, sort them in **alphabetical order (ascending)** by item name.

Each output line should show the item name followed by a space and then the transaction count.

### Input Format

- The first line contains an integer **n** — the number of transactions.
- The next **n** lines each contain a string — the name of an item.

Constraints:

- 1≤n≤1051≤n≤105
- Each item name consists only of lowercase English letters (`a`–`z`)
- The length of each item name ≤ 10

### Example

transactions = ['notebook', 'notebook', 'mouse', 'keyboard', 'mouse']
There are two items with 2 transactions each: 'notebook' and 'mouse'. In alphabetical order, they are 'mouse', 'notebook'.
There is one item with 1 transaction: 'keyboard'.
The return array, sorted as required, is ['mouse 2', 'notebook 2', 'keyboard 1'].

### Function Description

Complete the function **groupTransactions** in the editor below.
**groupTransactions** has the following parameter(s):

- `string transactions[n]`: each `transactions[i]` denotes the item name in the iᵗʰ transaction
  **Returns:**
- `string[]`: an array of strings of `"item name[space]transaction count"` sorted as described

### Constraints

`1 ≤ n ≤ 10^5 1 ≤ length of transactions[i] ≤ 10 transactions[i] contains only lowercase English letters, ascii[a-z]`

### Input Format for Custom Testing

Input from stdin will be processed as follows and passed to the function.

The first line contains a single integer, **n**, the size of transactions.  
Each of the next **n** lines contains a string, the item name for `transactions[i]`.

### Sample Case 1

**Sample Input**

`4 bin can bin bin`

**Sample Output**

`bin 3 can 1`

**Explanation**

There is one item `'bin'` with 3 transactions.  
There is one item `'can'` with 1 transaction.  
The return array sorted descending by transaction count, then ascending by name is `['bin 3', 'can 1']`.

### Sample Case 2

**Sample Input**

`3 banana pear apple`

**Sample Output**

`apple 1 banana 1 pear 1`

**Explanation**

There is one item `'apple'` with 1 transaction.  
There is one item `'banana'` with 1 transaction.  
There is one item `'pear'` with 1 transaction.  
The return array sorted descending by transaction count, then ascending by name is `['apple 1', 'banana 1', 'pear 1']`.`

## 💻 **Problem 2 — Application Log Analysis**

### Problem Description

You are given an unordered list of log entries from an application.  
Each log entry has the format:

`"user_id timestamp action"`

- **user_id**: A numeric string (no leading zeros).
- **timestamp**: The time in seconds since the app was launched.
- **action**: Either `"sign-in"` or `"sign-out"`.
  Your task is to find all users who **signed out within** `maxSpan` seconds of signing in.

You must return (and print) the list of such user IDs, sorted in **ascending numeric order**.

### Input Format

- The first line contains an integer **n** — the number of log entries.
- The next **n** lines each contain one log entry in the format `"user_id timestamp action"`.
- The last line contains an integer **maxSpan**.

Constraints:

- 1≤n≤1051≤n≤105
- 1≤maxSpan≤1091≤maxSpan≤109
- Each user:
  - Signs in **at most once**
  - Signs out **at most once**
  - Has `sign-in timestamp < sign-out timestamp`
- Logs may appear in **any order**.
- The result will contain at least one user.

### Output Format

Print each user ID (as a string) that signed out within `maxSpan` seconds of signing in, in ascending numeric order — one per line.

### Example 1

**Input**

`6 99 1 sign-in 100 10 sign-in 50 20 sign-in 100 15 sign-out 50 26 sign-out 99 2 sign-out 5`

**Output**

`99 100`

### Example 2

**Input**

`4 60 12 sign-in 80 20 sign-out 10 20 sign-in 60 20 sign-out 100`

**Output**

`60`

