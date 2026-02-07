| #   | Question                                                                      | Category              | Detailed Answer / Approach                                                                                                                                                                                                                                                                                                                              |
| --- | ----------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Explain the time and space complexity of quicksort.                           | Algorithms            | Average time complexity: O(n log n). Worst case: O(n²) if pivot is poorly chosen. Space complexity: O(log n) due to recursion stack. Key idea: Partition the array around a pivot, recursively sort partitions. Use randomized pivot to reduce worst case.                                                                                              |
| 2   | How does a hash table work? What are collision resolution techniques?         | Data Structures       | A hash table maps keys to indices via a hash function. Collisions occur when multiple keys map to the same index. Resolution techniques: chaining (linked lists at each bucket), open addressing (probing methods like linear, quadratic, or double hashing). Load factor affects performance, typically keep it under 0.7.                             |
| 3   | Describe the difference between a process and a thread.                       | Systems               | A process is an independent execution unit with its own memory space; threads are lightweight and share the same process memory. Threads within a process can communicate easily, processes require inter-process communication (IPC). Threads improve efficiency with parallelism.                                                                     |
| 4   | Implement a function to detect a cycle in a linked list.                      | Coding                | Use Floyd’s Tortoise and Hare algorithm: use two pointers, one moving one step and another moving two steps. If they meet, a cycle exists. Time: O(n), Space: O(1).                                                                                                                                                                                     |
| 5   | Explain Big-O notation and give examples of O(1), O(n), O(log n), O(n²).      | Algorithms            | Big-O describes the upper bound on an algorithm’s running time or space requirements in terms of input size. Examples: O(1) constant time like array access; O(n) linear time like linear search; O(log n) logarithmic time like binary search; O(n²) quadratic time like bubble sort.                                                                  |
| 6   | What is dynamic programming? How is it different from recursion?              | Algorithms            | Dynamic programming stores solutions to subproblems to avoid recomputation (memoization or tabulation), making it efficient for overlapping subproblems. Recursion solves problems top-down but can be inefficient if subproblems overlap. Example: Fibonacci, knapsack problem.                                                                        |
| 7   | Explain CAP theorem in distributed systems.                                   | Systems               | CAP theorem states that a distributed system can only provide two of the following three guarantees at the same time: Consistency (all nodes see the same data), Availability (every request receives a response), Partition Tolerance (system continues working despite network failures). You must design based on your priority between C, A, and P. |
| 8   | How does garbage collection work in Java?                                     | Systems               | Java uses automatic garbage collection to reclaim memory. Common algorithms: Mark-and-Sweep, generational GC (young and old generations). Objects no longer reachable are marked and collected. GC pauses can occur; JVM tuning can optimize pauses.                                                                                                    |
| 9   | Write code to implement LRU cache.                                            | Coding                | Use a combination of a doubly linked list and a hashmap. The hashmap stores keys to nodes in the linked list, which keeps track of usage order. On access, move node to front; on insertion, evict least recently used from tail if capacity exceeded. O(1) time for get and put operations.                                                            |
| 10  | Describe the differences between TCP and UDP.                                 | Networking            | TCP is connection-oriented, reliable, ordered, and error-checked. UDP is connectionless, faster, but no guarantee of delivery or order. TCP suitable for data integrity (web, email), UDP for speed (video streaming, gaming).                                                                                                                          |
| 11  | What are deadlocks? How can they be prevented?                                | Systems               | Deadlock occurs when processes wait indefinitely for resources held by each other. Necessary conditions: mutual exclusion, hold and wait, no preemption, circular wait. Prevention: remove one condition (e.g., use resource ordering, avoid hold and wait, allow preemption). Detection and recovery are alternative approaches.                       |
| 12  | Explain the difference between SQL and NoSQL databases.                       | Databases             | SQL databases are relational, structured, and use schemas with ACID transactions (e.g., MySQL, PostgreSQL). NoSQL databases are schema-less, designed for scalability and flexible data models (document, key-value, graph, column-family stores) (e.g., MongoDB, Cassandra). Choose based on use case.                                                 |
| 13  | Write a function to merge two sorted linked lists.                            | Coding                | Use two pointers traversing each list, compare values, append smaller to a new list, advance that pointer. Continue until both lists are exhausted. Time: O(n + m), space: O(1) or O(n+m) if returning new nodes.                                                                                                                                       |
| 14  | How do you find the middle of a linked list?                                  | Coding                | Use two pointers: slow pointer moves 1 step, fast pointer moves 2 steps. When fast pointer reaches the end, slow pointer is at the middle. Time: O(n), Space: O(1).                                                                                                                                                                                     |
| 15  | What is a mutex and semaphore?                                                | Systems               | Mutex is a lock allowing one thread access to a resource at a time (binary semaphore). Semaphore can allow multiple threads up to a count. Both are synchronization primitives for concurrency control to avoid race conditions.                                                                                                                        |
| 16  | Describe how HTTPS works.                                                     | Networking            | HTTPS uses TLS/SSL to encrypt communication between client and server. It involves certificate-based authentication, symmetric encryption for data transfer, and asymmetric encryption for key exchange. Protects data integrity and privacy.                                                                                                           |
| 17  | Explain what a RESTful API is.                                                | Systems/Design        | RESTful APIs follow REST principles: stateless, client-server, cacheable, uniform interface, layered system. Use HTTP methods (GET, POST, PUT, DELETE) to manipulate resources represented by URLs.                                                                                                                                                     |
| 18  | Implement a function to check if two strings are anagrams.                    | Coding                | Count frequency of each character in both strings using a hashmap or array. Compare counts; if equal, they are anagrams. Time: O(n), space: O(1) for fixed charset.                                                                                                                                                                                     |
| 19  | What are the SOLID principles?                                                | Design                | SOLID stands for: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion. These principles improve code maintainability, extensibility, and modularity.                                                                                                                                                   |
| 20  | Explain the difference between an abstract class and an interface.            | OOP                   | Abstract class can have both implemented and abstract methods; interfaces define only method signatures (Java 8+ allows default methods). A class can inherit only one abstract class but can implement multiple interfaces. Abstract classes are for shared base implementation; interfaces for contract definitions.                                  |
| 21  | Write code to implement binary search on a sorted array.                      | Coding                | Use two pointers (low, high). Calculate mid = (low + high) / 2. Compare mid value to target. Move low or high accordingly. Loop until found or low > high. Time: O(log n), Space: O(1).                                                                                                                                                                 |
| 22  | How do you handle memory leaks in your code?                                  | Systems               | Avoid by proper resource management (e.g., closing connections, freeing memory). Use tools like Valgrind, profilers. In managed languages, minimize lingering references. In C/C++, use smart pointers or manual delete carefully.                                                                                                                      |
| 23  | Explain map, reduce, and filter functions in functional programming.          | Programming Paradigms | Map applies a function to each element in a list, reduce aggregates list elements to a single value, filter returns elements that satisfy a predicate. Useful for clean, declarative data processing.                                                                                                                                                   |
| 24  | Describe how to design a URL shortening service like [bit.ly](http://bit.ly). | System Design         | Key components: API to generate short URLs, DB to store mapping, hashing or base62 encoding, caching, analytics. Handle collisions, scaling, database partitioning, expiration policies, security (rate limiting).                                                                                                                                      |
| 25  | What is tail recursion? Why is it important?                                  | Algorithms            | Tail recursion is a recursive call that is the last operation in a function, allowing compilers to optimize by reusing the stack frame, avoiding stack overflow. Important for efficient recursion.                                                                                                                                                     |
| 26  | Write code to find the first non-repeating character in a string.             | Coding                | Use a hashmap to count character frequency, then iterate the string and return the first char with count 1. Time: O(n), Space: O(1) for charset.                                                                                                                                                                                                        |
| 27  | Explain differences between synchronous and asynchronous programming.         | Systems               | Synchronous blocks execution until complete; asynchronous allows other tasks to run while waiting for completion (callbacks, promises, async/await). Asynchronous improves responsiveness and efficiency.                                                                                                                                               |
| 28  | Describe garbage collection pauses and how to minimize them.                  | Systems               | GC pauses occur when JVM halts application to reclaim memory. Minimize with tuning heap size, using generational GC, incremental and concurrent collectors, avoiding large objects in young generation, profiling to detect memory leaks.                                                                                                               |
| 29  | What is a race condition? How can it be prevented?                            | Systems               | Race condition happens when multiple threads access shared data simultaneously causing inconsistent results. Prevent using synchronization (mutexes, locks), atomic operations, or designing thread-safe code.                                                                                                                                          |
| 30  | Write code to reverse a linked list.                                          | Coding                | Use three pointers: prev, current, next. Iterate list, reverse pointers by setting current.next = prev, move prev and current forward. Time: O(n), Space: O(1).                                                                                                                                                                                         |
| 31  | What are the different types of joins in SQL?                                 | Databases             | INNER JOIN returns matching rows, LEFT JOIN returns all left rows + matching right rows (NULL if no match), RIGHT JOIN vice versa, FULL OUTER JOIN returns all rows with NULL where no matches. CROSS JOIN returns Cartesian product.                                                                                                                   |
| 32  | Explain the concept of eventual consistency.                                  | Distributed Systems   | Eventual consistency means that updates will propagate to all replicas eventually, so data becomes consistent over time, suitable for high availability systems sacrificing immediate consistency.                                                                                                                                                      |
| 33  | Describe binary trees and binary search trees.                                | Data Structures       | Binary tree: each node has up to two children. BST: left child < node < right child. BST allows efficient search, insertion, deletion in O(log n) average time.                                                                                                                                                                                         |
| 34  | Write code to detect if a binary tree is a valid BST.                         | Coding                | Use recursion with min/max value constraints for each node. Validate left subtree < node < right subtree. Time: O(n), Space: O(h).                                                                                                                                                                                                                      |
| 35  | What is a deadlock? How is it detected and resolved?                          | Systems               | Deadlock is a cyclic dependency among processes holding resources. Detected by wait-for graphs or timeouts. Resolved by killing processes, rolling back, or resource preemption. Prevention avoids deadlock by removing one of the necessary conditions.                                                                                                |
| 36  | Explain the difference between shallow copy and deep copy.                    | Programming           | Shallow copy copies object references; deep copy duplicates objects recursively, so changes to the copy don’t affect the original. Important when working with mutable nested data.                                                                                                                                                                     |
| 37  | How does a binary heap work? What are its operations and complexities?        | Data Structures       | Binary heap is a complete binary tree used for priority queues. Min-heap or max-heap properties. Operations: insert O(log n), extract-min/max O(log n), peek O(1). Implemented using arrays.                                                                                                                                                            |
| 38  | Write code for inorder, preorder, and postorder tree traversal.               | Coding                | Recursive or iterative (using stack) traversals: inorder (left-root-right), preorder (root-left-right), postorder (left-right-root). Time: O(n).                                                                                                                                                                                                        |
| 39  | What is memoization?                                                          | Algorithms            | Optimization technique to cache function results for expensive recursive calls to avoid recomputation, improving performance (example: Fibonacci).                                                                                                                                                                                                      |
| 40  | Explain how a TCP three-way handshake works.                                  | Networking            | Client sends SYN, server replies SYN-ACK, client sends ACK. Connection established ensuring both sides ready for communication.                                                                                                                                                                                                                         |
| 41  | What are the pros and cons of microservices?                                  | System Design         | Pros: Scalability, independent deploys, fault isolation, tech heterogeneity. Cons: Increased complexity, network latency, data consistency, operational overhead.                                                                                                                                                                                       |
| 42  | Explain different sorting algorithms and when to use each.                    | Algorithms            | QuickSort: average O(n log n), in-place, fast; MergeSort: stable, O(n log n), needs extra space; HeapSort: O(n log n), in-place; Bubble/Insertion: simple but O(n²), used for small data sets. Use stable sort if order matters.                                                                                                                        |
| 43  | Describe how you would design a rate limiter.                                 | System Design         | Options: Token bucket, leaky bucket, fixed window counters, sliding window logs. Store counters per user/IP, limit requests per time unit. Implement using in-memory stores like Redis for distributed systems.                                                                                                                                         |
| 44  | What is a race condition and how to prevent it in multithreading?             | Systems               | Multiple threads access shared resources without proper synchronization causing inconsistent results. Prevent using mutexes, locks, atomic operations, or thread-safe data structures.                                                                                                                                                                  |
| 45  | Write code to detect a palindrome linked list.                                | Coding                | Find middle with slow/fast pointers, reverse second half, compare two halves for equality, restore list if needed. Time: O(n), Space: O(1).                                                                                                                                                                                                             |
| 46  | What is the difference between concurrency and parallelism?                   | Systems               | Concurrency: multiple tasks progress but not necessarily at the same time (interleaved). Parallelism: multiple tasks execute simultaneously on multiple processors.                                                                                                                                                                                     |
| 47  | Explain the producer-consumer problem and its solution.                       | Systems               | Synchronization problem where producers generate data and consumers use it. Solutions: using bounded buffers, semaphores, mutexes, condition variables to avoid race conditions and deadlocks.                                                                                                                                                          |
| 48  | Describe the function of a load balancer.                                     | System Design         | Distributes incoming network traffic across multiple servers to ensure no single server is overwhelmed, improves availability, scalability. Techniques include round-robin, least connections, IP hash.                                                                                                                                                 |
| 49  | What are ACID properties in databases?                                        | Databases             | Atomicity (all or nothing), Consistency (DB remains valid), Isolation (concurrent transactions don't interfere), Durability (committed transactions persist). Guarantees reliable transaction processing.                                                                                                                                               |
| 50  | Write code to find the kth largest element in an unsorted array.              | Coding                | Use a min-heap of size k or QuickSelect algorithm (average O(n)). QuickSelect partitions array like quicksort but recurses into one side only.                                                                                                                                                                                                          |
| 51  | How would you detect a loop in a directed graph?                              | Algorithms            | Use DFS with recursion stack (visited + recursion stack sets). If you revisit a node in the recursion stack, a cycle exists. Time: O(V+E).                                                                                                                                                                                                              |
| 52  | Explain the difference between optimistic and pessimistic locking.            | Databases             | Pessimistic locking blocks other transactions immediately (locking resources), optimistic locking checks for conflicts before commit, assuming conflicts are rare. Optimistic locking uses versioning or timestamps.                                                                                                                                    |
| 53  | What is a trie? What are its use cases?                                       | Data Structures       | Trie is a prefix tree used to store strings for efficient retrieval. Common uses: autocomplete, spell checking, IP routing. Time complexity for search is O(m) where m is length of the key.                                                                                                                                                            |
| 54  | Describe how consistent hashing works.                                        | System Design         | Maps both servers and keys to a hash ring. Keys are assigned to the nearest server clockwise. When nodes join/leave, only a subset of keys need to be remapped, minimizing cache misses or rebalancing. Useful in distributed caches.                                                                                                                   |
| 55  | What are the differences between a stack and a queue?                         | Data Structures       | Stack: LIFO (Last In First Out), operations push/pop. Queue: FIFO (First In First Out), operations enqueue/dequeue. Stacks used for recursion, expression evaluation; queues for task scheduling.                                                                                                                                                       |
| 56  | Write code to implement a queue using two stacks.                             | Coding                | ==Use two stacks: stack1 for enqueue, stack2 for dequeue==. On dequeue, if stack2 empty, pop all elements from stack1 to stack2. Amortized O(1) per operation.                                                                                                                                                                                          |
| 57  | What is the difference between a mutex and a semaphore?                       | Systems               | Mutex: binary lock for mutual exclusion, only one holder at a time. Semaphore: allows multiple concurrent holders up to a count. Mutexes prevent race conditions; semaphores manage resource pools.                                                                                                                                                     |
| 58  | Explain the difference between vertical and horizontal scaling.               | System Design         | Vertical scaling: adding resources to a single machine (CPU, RAM). Horizontal scaling: adding more machines/nodes to distribute load. Horizontal scaling better for availability and fault tolerance.                                                                                                                                                   |
| 59  | What is a binary search tree? How do you insert and delete nodes?             | Data Structures       | BST: left < node < right. Insert by comparing keys recursively until leaf. Delete has three cases: leaf node, node with one child, node with two children (replace with inorder successor). Time: O(h).                                                                                                                                                 |
| 60  | Describe the difference between REST and GraphQL.                             | Systems/Design        | REST: fixed endpoints, multiple requests, over-fetching or under-fetching data. GraphQL: single endpoint, client specifies exactly what data is needed, reduces bandwidth. GraphQL allows better client flexibility but more complex server implementation.                                                                                             |
| 61  | How do you prevent SQL injection?                                             | Security              | Use parameterized queries/prepared statements, input validation, ORM frameworks. Never concatenate raw user input into queries.                                                                                                                                                                                                                         |
| 62  | What is a thread pool? Why use it?                                            | Systems               | A thread pool manages a fixed number of threads reused to execute multiple tasks, reducing thread creation overhead and improving resource management.                                                                                                                                                                                                  |
| 63  | Write code to implement a depth-first search on a graph.                      | Algorithms            | Use recursion or stack. Visit node, mark visited, recursively visit neighbors. Time: O(V + E).                                                                                                                                                                                                                                                          |
| 64  | Explain the difference between a process and a thread.                        | Systems               | Process: independent memory, expensive context switch. Thread: lightweight, shares process memory, faster context switch. Threads enable parallelism within a process.                                                                                                                                                                                  |
| 65  | What is the observer pattern? When would you use it?                          | Design Patterns       | Defines a one-to-many dependency; observers get notified on state changes of the subject. Used in event systems, MVC architectures, GUI frameworks.                                                                                                                                                                                                     |
| 66  | Write code to find the lowest common ancestor in a BST.                       | Coding                | If both nodes less than root, recurse left; both greater, recurse right; else root is LCA. Time: O(h).                                                                                                                                                                                                                                                  |
| 67  | Explain differences between stack memory and heap memory.                     | Systems               | Stack: stores local variables, fixed size, fast allocation/deallocation. Heap: dynamic memory for objects, slower, managed by GC or manually freed. Stack is thread-local, heap shared.                                                                                                                                                                 |
| 68  | How would you detect and fix a memory leak in C++?                            | Systems               | Use tools like Valgrind to detect leaks. Fix by ensuring every new/delete pair matches, use smart pointers (unique_ptr, shared_ptr), avoid cyclic references.                                                                                                                                                                                           |
| 69  | What is a bloom filter? How does it work?                                     | Data Structures       | Probabilistic data structure to test set membership with false positives but no false negatives. Uses multiple hash functions and a bit array. Space efficient for large datasets.                                                                                                                                                                      |
| 70  | Explain eventual consistency vs strong consistency.                           | Distributed Systems   | Strong consistency means immediate synchronization after updates; eventual consistency means updates propagate asynchronously, data may be stale temporarily but eventually consistent. Tradeoff between latency and correctness.                                                                                                                       |
| 71  | What are design patterns? Name some common ones.                              | Design                | Reusable solutions to common design problems. Examples: Singleton, Factory, Observer, Strategy, Decorator, Adapter, Command, Proxy. They improve code maintainability and flexibility.                                                                                                                                                                  |
| 72  | Write code to flatten a nested list.                                          | Coding                | Use recursion or stack to traverse nested lists and append elements to result list. Handle arbitrary nesting. Time depends on total elements.                                                                                                                                                                                                           |
| 73  | Describe how a garbage collector works in Python.                             | Systems               | Python uses reference counting and cyclic garbage collector for unreachable cycles. When reference count drops to zero, object is deallocated. Cyclic GC periodically detects reference cycles.                                                                                                                                                         |
| 74  | What is the difference between a linked list and an array?                    | Data Structures       | Array: fixed size, random access O(1), contiguous memory. Linked list: dynamic size, sequential access O(n), non-contiguous memory, easy insert/delete. Use arrays for fast lookup, linked lists for frequent insertions.                                                                                                                               |
| 75  | How does a DNS server work?                                                   | Networking            | DNS resolves domain names to IP addresses via hierarchical queries: root, TLD, authoritative servers. Clients cache responses. Uses UDP mostly, TCP for larger responses.                                                                                                                                                                               |
| 76  | What is a race condition? Give an example.                                    | Systems               | Occurs when multiple threads access shared data concurrently without synchronization, causing inconsistent state. Example: incrementing shared counter without locks can lose increments.                                                                                                                                                               |
| 77  | Explain the principle of least privilege.                                     | Security              | Users/processes should have the minimum privileges necessary to perform tasks, reducing risk of accidental or malicious damage.                                                                                                                                                                                                                         |
| 78  | Write code to implement a stack using queues.                                 | Coding                | Use two queues. On push, enqueue in queue1. On pop, dequeue all but last from queue1 to queue2, dequeue last from queue1 (top element). Swap queues. Amortized O(n) pop.                                                                                                                                                                                |
| 79  | Describe the actor model in concurrent programming.                           | Systems               | Actors are independent entities communicating via message passing, avoid shared state and locks, suitable for scalable distributed systems (e.g., Erlang, Akka).                                                                                                                                                                                        |
| 80  | What is sharding? How is it used in databases?                                | Databases             | Partitioning data horizontally across multiple machines to scale read/write throughput. Each shard holds a subset of data (based on user ID range, hash, etc). Reduces load per DB node.                                                                                                                                                                |
| 81  | Explain the difference between horizontal and vertical partitioning.          | Databases             | Horizontal partitioning (sharding): split rows across tables. Vertical partitioning: split columns across tables. Both improve performance/scalability but suit different use cases.                                                                                                                                                                    |
| 82  | What are the differences between REST and SOAP?                               | Systems               | REST is lightweight, stateless, uses HTTP verbs and JSON/XML. SOAP is protocol-based, heavier, uses XML, supports formal contracts (WSDL), built-in error handling. REST preferred for web/mobile APIs.                                                                                                                                                 |
| 83  | How do you implement a singleton pattern?                                     | Design Patterns       | Private constructor, static instance variable, public method to get instance, ensure thread safety (double-checked locking or eager initialization). Guarantees one instance per JVM.                                                                                                                                                                   |
| 84  | What is a race condition? How would you debug it?                             | Systems               | Occurs when unsynchronized access causes unpredictable behavior. Debug with logging, thread analyzers, tools like ThreadSanitizer, use synchronization to fix.                                                                                                                                                                                          |
| 85  | Write code to find the maximum subarray sum (Kadane’s algorithm).             | Algorithms            | Initialize current_sum and max_sum to first element. Iterate array: current_sum = max(num, current_sum + num), max_sum = max(max_sum, current_sum). Time: O(n).                                                                                                                                                                                         |
| 86  | What is the difference between a process and a thread?                        | Systems               | Process: independent execution with own memory; thread: smaller unit sharing process memory. Threads enable parallelism with less overhead.                                                                                                                                                                                                             |
| 87  | Explain the observer design pattern.                                          | Design Patterns       | Defines a subscription mechanism to notify multiple observers about state changes in a subject. Used in event-driven systems and MVC.                                                                                                                                                                                                                   |
| 88  | What are functional programming principles?                                   | Programming Paradigm  | Immutability, pure functions (no side effects), first-class functions, higher-order functions, function composition. Benefits include easier testing and concurrency.                                                                                                                                                                                   |
| 89  | Write code to implement merge sort.                                           | Algorithms            | Recursively split array in halves, sort each half, merge sorted halves. Time: O(n log n), space: O(n). Stable sort.                                                                                                                                                                                                                                     |
| 90  | What are mutexes and semaphores?                                              | Systems               | Mutexes: binary locks for mutual exclusion. Semaphores: counters controlling access to multiple resources. Used for synchronization in concurrency.                                                                                                                                                                                                     |
| 91  | Explain a deadlock and how to avoid it.                                       | Systems               | Deadlock: cyclic resource waiting. Avoid by resource ordering, avoiding hold-and-wait, or allowing preemption. Detection possible via wait-for graphs.                                                                                                                                                                                                  |
| 92  | What is a trie? Give a use case.                                              | Data Structures       | Trie stores strings in prefix tree structure for efficient prefix queries, autocomplete, or spell-checking.                                                                                                                                                                                                                                             |
| 93  | How would you design a chat system?                                           | System Design         | Components: user management, messaging servers, message queues, persistent storage, push notifications, presence service. Handle scalability, consistency, ordering, offline delivery.                                                                                                                                                                  |
| 94  | Describe different database indexing types.                                   | Databases             | B-tree indexes for range queries, hash indexes for equality, bitmap indexes for low-cardinality columns. Indexes speed up queries but slow writes and increase storage.                                                                                                                                                                                 |
| 95  | Write code to implement a min stack.                                          | Coding                | Use two stacks: one for values, one for current minimums. On push, compare with current min, push accordingly. Pop both stacks. O(1) getMin.                                                                                                                                                                                                            |
| 96  | What is tail call optimization?                                               | Algorithms            | Compiler optimization where last function call reuses current stack frame to prevent stack growth in recursive calls, making recursion efficient.                                                                                                                                                                                                       |
| 97  | Explain distributed caching and cache invalidation strategies.                | System Design         | Caches distributed across nodes to reduce DB load. Strategies: write-through, write-back, time-to-live (TTL), manual invalidation, cache aside. Tradeoffs between consistency and performance.                                                                                                                                                          |
| 98  | What is a load balancer? How does it work?                                    | System Design         | Distributes incoming traffic to multiple servers based on algorithms (round-robin, least connections, IP hash), improving availability and fault tolerance.                                                                                                                                                                                             |
| 99  | Write code for breadth-first search on a graph.                               | Algorithms            | Use queue, mark visited nodes, enqueue neighbors. Time: O(V+E). Used for shortest path in unweighted graphs.                                                                                                                                                                                                                                            |
| 100 | Describe CAP theorem. What trade-offs does it highlight?                      | Distributed Systems   | CAP theorem states that in distributed systems you can only have two out of Consistency, Availability, and Partition tolerance at the same time. It highlights trade-offs in system design choices.                                                                                                                                                     |

---

# 🐍 Python Deep Knowledge (25 Questions)

### 26. **What are Python decorators and how do they work?**

**Answer:**

Functions that wrap other functions to extend behavior.

```
py
Copy code
def decorator(fn):
    def wrapper(*args, **kwargs):
        print("Before")
        return fn(*args, **kwargs)
    return wrapper

```

### 27. **Explain the difference between `@staticmethod` and `@classmethod`.**

**Answer:**

- `staticmethod`: no `self` or `cls`
- `classmethod`: gets class as first argument

### 28. **What is the GIL in Python?**

**Answer:**

Global Interpreter Lock — only one thread runs Python bytecode at a time. Limits true parallelism in CPython.

### 29. **What is a Python generator and when do you use it?**

**Answer:**

A function that yields values one at a time. Used for memory-efficient iteration.

### 30. **Difference between `deepcopy()` and `copy()` in Python?**

**Answer:**

`copy()` = shallow

`deepcopy()` = copies all nested objects

### 31. **Explain duck typing in Python.**

**Answer:**

“If it walks like a duck…” — object’s behavior matters more than its type.



### 32. **What are Python descriptors?**

**Answer:**

Objects that define custom access logic via `__get__`, `__set__`, `__delete__`.


### 33. **What is the Singleton pattern in Python?**

**Answer:**

```
py
Copy code
class Singleton:
    _instance = None
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

```


### 34. **How do Python context managers work?**

**Answer:**

With `__enter__` and `__exit__`. Used in `with` blocks.

```
py
Copy code
with open("file.txt") as f:
    data = f.read()

```

### 35. **Difference between `is` and `==`?**

**Answer:**

- `is`: identity comparison
- `==`: value comparison

### 36. **What are metaclasses?**

**Answer:**

They define how classes are created.

Used for logging, validation, or singleton control at the class level.

### 37. **What is the Strategy pattern in Python?**

**Answer:**

Define a family of algorithms, encapsulate each one.

```
py
Copy code
class Strategy:
    def execute(self): pass

class Fast(Strategy):
    def execute(self): return "fast"

class Slow(Strategy):
    def execute(self): return "slow"

```

### 38. **What are list comprehensions and their benefits?**

**Answer:**

More concise and efficient than loops.

```
py
Copy code
squares = [x*x for x in range(10)]

```

### 39. **What is a Python iterator and iterable?**

**Answer:**

Iterable implements `__iter__`; iterator implements `__next__`.

### 40. **What is dependency injection and how do you achieve it in Python?**

**Answer:**

Injecting required objects into a class instead of hardcoding them.

```
py
Copy code
class Service:
    def __init__(self, repo): self.repo = repo

```

### 41. **Explain Python’s `property()` function.**

**Answer:**

Used to create managed attributes.

```
py
Copy code
class User:
    def __init__(self, name): self._name = name
    @property
    def name(self): return self._name

```

### 42. **What is method resolution order (MRO)?**

**Answer:**

The order in which Python resolves methods when multiple inheritance is involved.


### 43. **Difference between abstract class and interface (Python style)?**

**Answer:**

Abstract classes use `ABC`; no true interfaces in Python, but can simulate with base classes.


### 44. **What is a coroutine in Python?**

**Answer:**

A function declared with `async def` that can await other coroutines.



### 45. **How does Python manage memory?**

**Answer:**

- Reference counting
- Garbage collection
- Object pools (for small integers, strings)


### 46. **Explain the Facade pattern in Python.**

**Answer:**

Provides a simplified interface to a complex system.


### 47. **What’s the use of `__slots__`?**

**Answer:**

Limits the attributes a class can have. Saves memory in large object sets.


### 48. **How do you design a plugin architecture in Python?**

**Answer:**

Use dynamic imports (`importlib`), interfaces, and discovery patterns.


### 49. **What is a mixin and when should you use one?**

**Answer:**

A reusable class used to “mix in” behavior to other classes without inheritance trees.


### 50. **Explain command pattern with a Python example.**

**Answer:**

Encapsulate requests as objects, letting you parameterize and queue actions.

Navigating a software engineering interview at the 4-5 year mark is a different beast than the entry-level "solve this LeetCode Easy" phase. At this stage, Big Tech (Google, Amazon, Meta, etc.) expects you to move beyond _how_ to code and into the realm of _why_ we build things a certain way. They want to see you weigh trade-offs like a seasoned pro.

Here are 50 high-impact questions and punchy answers tailored for a Mid-to-Senior level interview.

---

# Specialized Questions
### 🏗️ Section 1: System Design & Architecture

_At 5 years, you aren't just a coder; you're an architect in training. Focus on scalability and reliability._

1. **How would you design a rate limiter for a distributed system?**
    
    - **Answer:** Use a sliding window algorithm with Redis to track request counts. Redis is ideal because it's fast and shared across all application nodes.
        
2. **Explain the CAP Theorem and how it affects your choice of database.**
    
    - **Answer:** CAP states you can only have two of: Consistency, Availability, and Partition Tolerance. In a distributed web app, you almost always choose Partition Tolerance and then decide between C (SQL) or A (NoSQL/DynamoDB) based on the use case.
        
3. **What is "Eventual Consistency"? When is it acceptable?**
    
    - **Answer:** It’s a model where data will be consistent "eventually" but might differ across nodes for a short time. Acceptable in social media feeds (likes/comments) but unacceptable in banking transactions.
        
4. **How do you handle a "Thundering Herd" problem?**
    
    - **Answer:** Use jitter (adding randomness to retry timers) and caching layers with expiration times that aren't perfectly aligned to prevent everything from hitting the DB at once.
        
5. **Describe the difference between L4 and L7 Load Balancing.**
    
    - **Answer:** L4 operates at the Transport layer (IP/Port), making it fast. L7 operates at the Application layer (HTTP/Headers/Cookies), allowing for smarter routing (e.g., sending `/images` to one server and `/api` to another).
        
6. **When would you choose Microservices over a Monolith?**
    
    - **Answer:** When the team size grows, or when specific services need to scale independently (e.g., a CPU-heavy video processor vs. a lightweight user-profile service).
        
7. **How do you design for "High Availability"?**
    
    - **Answer:** Eliminate Single Points of Failure (SPOF) using multi-region deployments, redundant databases, and automated health checks with failover.
        
8. **What is Sharding, and what are its risks?**
    
    - **Answer:** It’s horizontal partitioning of data across multiple DBs. Risks include complex joins across shards and the "hot shard" problem where one node gets more traffic than others.
        
9. **How would you design a URL shortener like Bitly?**
    
    - **Answer:** Use a base62 encoding of a unique ID. Store mappings in a NoSQL DB for speed. Use a cache for frequently accessed short URLs.
        
10. **Explain the "Circuit Breaker" pattern.**
    
    - **Answer:** It prevents a system from repeatedly trying an operation that's likely to fail. Once failures cross a threshold, the "circuit opens," and calls fail immediately to allow the struggling service to recover.
        

---

## ☁️ Section 2: Cloud Computing & Infrastructure

_Amazon and Google love asking about managed services and cost-efficiency._

11. **What is the difference between IaaS, PaaS, and SaaS?**
    
    - **Answer:** IaaS (AWS EC2) gives you the virtual hardware. PaaS (Heroku/Elastic Beanstalk) gives you a platform to run code. SaaS (Gmail/Salesforce) is the finished software product.
        
12. **Why use Serverless (AWS Lambda) instead of an EC2 instance?**
    
    - **Answer:** Lambda is great for event-driven, intermittent tasks. It scales automatically and you only pay for execution time, whereas EC2 runs (and costs) 24/7.
        
13. **What is "Infrastructure as Code" (IaC)?**
    
    - **Answer:** Managing infrastructure via scripts (Terraform/CloudFormation) rather than manual console clicks. It ensures environments are reproducible and version-controlled.
        
14. **How do you manage secrets in the cloud?**
    
    - **Answer:** Never hardcode. Use services like AWS Secrets Manager or HashiCorp Vault, and inject them into the environment at runtime.
        
15. **Explain "Blue-Green" deployment.**
    
    - **Answer:** Maintaining two identical production environments. You deploy to "Green," test it, and then switch the load balancer from "Blue" to "Green" for zero downtime.
        
16. **What is a VPC, and why do you need one?**
    
    - **Answer:** A Virtual Private Cloud is an isolated section of a cloud provider’s network. It allows you to define private subnets to hide DBs and internal services from the public internet.
        
17. **How would you migrate a legacy on-prem app to the cloud?**
    
    - **Answer:** Choose a strategy: Rehosting (Lift-and-shift), Replatforming (small tweaks), or Refactoring (rewriting for cloud-native features).
        
18. **What is a "Sticky Session" in load balancing?**
    
    - **Answer:** It ensures a user stays connected to the same server for the duration of their session. Generally avoided in modern stateless architectures.
        

---

## 🔐 Section 3: Security & Performance

_Security is everyone's job now, not just the "Security Team."_

19. **What are the top 3 OWASP vulnerabilities?**
    
    - **Answer:** Broken Access Control, Cryptographic Failures, and Injection (like SQLi).
        
20. **How do you prevent SQL Injection?**
    
    - **Answer:** Use parameterized queries (prepared statements) and ORMs that handle sanitization automatically.
        
21. **Explain the difference between JWT and Session-based auth.**
    
    - **Answer:** Sessions are stored on the server (stateful). JWTs are stored on the client and contain all necessary info (stateless). JWTs are better for microservices.
        
22. **How does "Cross-Site Scripting" (XSS) work?**
    
    - **Answer:** An attacker injects malicious scripts into a web page viewed by other users. Prevent it by escaping output and using Content Security Policies (CSP).
        
23. **What is "Defense in Depth"?**
    
    - **Answer:** Layering multiple security controls (firewalls, encryption, MFA, least-privilege IAM) so that if one fails, others are still in place.
        
24. **How would you optimize a slow database query?**
    
    - **Answer:** Use `EXPLAIN ANALYZE` to find the bottleneck, check for missing indexes, and ensure you aren't doing N+1 queries in your application logic.
        
25. **What is a CDN and how does it improve performance?**
    
    - **Answer:** A Content Delivery Network caches static assets (images, JS) on edge servers geographically closer to the user, reducing latency.
        
26. **Explain "Lazy Loading."**
    
    - **Answer:** Delaying the loading of non-critical resources (like images below the fold) until they are actually needed by the user.
        

---

## 🥞 Section 4: Full Stack & Modern Development

_Being "Full Stack" at this level means understanding the bridge between the browser and the server._

27. **What is the "Event Loop" in JavaScript?**
    
    - **Answer:** It allows JS to perform non-blocking I/O operations by offloading tasks to the browser/system and picking them up from the callback queue once finished.
        
28. **Compare React's Virtual DOM to the real DOM.**
    
    - **Answer:** The Virtual DOM is a lightweight copy. React calculates the minimal number of changes needed (diffing) and updates the real DOM only once, which is much faster.
        
29. **What is "Middleware" in a backend framework (like Express or Django)?**
    
    - **Answer:** Functions that have access to the request and response objects, used for tasks like logging, authentication, or parsing JSON.
        
30. **Explain the difference between REST and GraphQL.**
    
    - **Answer:** REST is resource-based with fixed endpoints. GraphQL is query-based, allowing the client to request exactly the data it needs in one call.
        
31. **What are "Web Components"?**
    
    - **Answer:** A suite of technologies allowing you to create reusable, encapsulated custom HTML tags that work across any framework.
        
32. **How do you handle "State Management" in a large frontend app?**
    
    - **Answer:** Use tools like Redux, MobX, or Context API. The goal is to have a "Single Source of Truth" to prevent UI inconsistencies.
        
33. **What is SSR (Server-Side Rendering) vs. CSR (Client-Side Rendering)?**
    
    - **Answer:** SSR renders the initial page on the server (better for SEO/fast first paint). CSR renders everything in the browser (better for "app-like" feel after initial load).
        
34. **What is the difference between WebSockets and Long Polling?**
    
    - **Answer:** WebSockets provide a full-duplex, persistent connection for real-time data. Long Polling is a hack where the server holds a request open until it has data to send.
        
35. **How do you ensure your frontend is accessible (A11y)?**
    
    - **Answer:** Use semantic HTML tags, provide Alt text for images, ensure high color contrast, and test with screen readers.
        
36. **What is a "Polyfill"?**
    
    - **Answer:** A piece of code used to provide modern functionality on older browsers that do not natively support it.
        
37. **What is the difference between `interface` and `type` in TypeScript?**
    
    - **Answer:** Interfaces are generally for defining object shapes and support "declaration merging." Types are more flexible for unions, intersections, and primitives.
        
38. **Explain the "Single Responsibility Principle" (SRP).**
    
    - **Answer:** A class or function should have one, and only one, reason to change. It keeps code modular and testable.
        

---

## 🤝 Section 5: Behavioral & Professional Challenges

_The "Soft Skills" part where they check if you're a leader or a headache._

39. **Tell me about a time you disagreed with a technical decision. How did you handle it?**
    
    - **Answer:** Use the STAR method. Focus on how you presented data-backed alternatives but ultimately committed to the team's decision once made ("Disagree and Commit").
        
40. **How do you handle technical debt?**
    
    - **Answer:** Acknowledge it isn't always bad. I track it in the backlog and advocate for "scout rule" coding (leave the codebase cleaner than you found it) and dedicated "refactor sprints."
        
41. **Describe a time you handled a production outage.**
    
    - **Answer:** Focus on your calm under pressure, how you prioritized restoration of service over finding the "culprit," and the post-mortem you led to prevent it from happening again.
        
42. **How do you mentor junior developers?**
    
    - **Answer:** Through empathetic code reviews, pair programming, and "teaching them how to fish" by pointing them toward resources rather than just giving the answer.
        
43. **What do you do if a project is falling behind schedule?**
    
    - **Answer:** Communicate early. Identify the "Critical Path." I’d suggest cutting non-essential features (MVP approach) or re-evaluating the timeline with stakeholders rather than just working 80 hours/week.
        
44. **Tell me about a time you failed.**
    
    - **Answer:** Be honest. Pick a real technical or process mistake, explain what you learned, and—most importantly—how you changed your behavior to never repeat it.
        
45. **How do you keep your skills up to date?**
    
    - **Answer:** Mention specific newsletters, tech blogs (like Netflix TechBlog), or personal projects. Show curiosity about _why_ new tech is emerging.
        
46. **How do you approach a codebase you’ve never seen before?**
    
    - **Answer:** I start by running the tests. Then I trace a single user flow (like "Login") from the UI through the backend to the DB to understand the architecture.
        
47. **What is your process for a code review?**
    
    - **Answer:** I look for architectural flaws and security issues first, then readability. I use "I" statements ("I find this confusing") rather than "You" statements ("You wrote this poorly").
        
48. **How do you handle a "Difficult" teammate?**
    
    - **Answer:** I try to find common ground. Usually, "difficult" people are just frustrated. I focus on clear communication and alignment on the project's goals.
        
49. **Why do you want to work _here_?**
    
    - **Answer:** Avoid "generic" answers. Mention a specific engineering challenge the company faces (e.g., "I'm fascinated by how [Company] handles real-time logistics at scale").
        
50. **Where do you see yourself in 5 years?**
    
    - **Answer:** Express a desire for growth—whether that’s becoming a Staff Engineer (technical depth) or an Engineering Manager (people leadership).
        