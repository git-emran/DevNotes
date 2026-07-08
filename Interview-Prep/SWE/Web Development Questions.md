# 📌 50 Senior Web Developer Interview Questions & Answers

---

## 🟢 Core JavaScript & Frontend (10)

**1. What are the differences between `var`, `let`, and `const` in JavaScript?**

- `var`: Function-scoped, hoisted, allows re-declaration. Can cause bugs.
- `let`: Block-scoped, hoisted but not initialized until runtime, can be reassigned but not redeclared.
- `const`: Block-scoped, must be initialized, cannot be reassigned.  
   👉 Best practice: Use `const` by default, `let` when you need reassignment, avoid `var`.

**2. Can you explain event delegation in JavaScript?**  
Event delegation is when you attach a single event listener to a parent element instead of each child. The event “bubbles up” through the DOM, and the handler can check the target.  
✅ Example: Instead of attaching click handlers to 100 buttons, attach one handler to the parent and detect clicks.  
👉 Benefits: Better performance, memory efficient, works with dynamically added elements.

**3. How does the JavaScript event loop work?**

- **Call Stack**: Executes synchronous code.
- **Task Queue (Callback Queue)**: Stores async callbacks (`setTimeout`, DOM events).
- **Microtask Queue**: Stores promises & mutation observers. Runs before task queue.  
   👉 Order: Stack → Microtasks → Tasks → Render.  
   This ensures promises resolve before regular callbacks.

**4. Difference between synchronous and asynchronous code?**

- **Synchronous**: Blocks execution until finished. (e.g., `for loop`, `alert`)
- **Asynchronous**: Non-blocking, allows execution to continue (`setTimeout`, `fetch`, promises).  
   👉 Async improves performance and UX by avoiding freezes.

**5. What is the difference between `==` and `===` in JavaScript?**

- `==`: Loose equality, performs type coercion. (`"5" == 5 → true`).
- `===`: Strict equality, checks both type and value. (`"5" === 5 → false`).  
   👉 Best practice: Always use `===` unless you explicitly want coercion.

**6. How does React’s Virtual DOM improve performance?**

- React creates a lightweight Virtual DOM copy of the UI.
- On state change, React diffs the old vs. new Virtual DOM (reconciliation).
- Only updates changed nodes in the real DOM.  
   👉 Benefit: Faster rendering since direct DOM manipulation is costly.

**7. What are React hooks, and why are they important?**  
Hooks let you use state and lifecycle features in functional components.

- `useState`: local state
- `useEffect`: lifecycle (componentDidMount, etc.)
- `useMemo`, `useCallback`: performance optimizations  
   👉 Hooks simplify code, avoid class components, and promote reusability.

**8. How do you optimize React app performance?**

- Use `React.memo` to prevent unnecessary re-renders.
- Use `useMemo` / `useCallback` for expensive operations.
- Code splitting with dynamic imports.
- Virtualize long lists (`react-window`).
- Avoid inline functions in render.

**9. Difference between REST and GraphQL?**

- **REST**: Multiple endpoints, over-fetching/under-fetching issues.
- **GraphQL**: Single endpoint, client defines shape of data, no over-fetching.  
   👉 Use REST for simple APIs, GraphQL for complex, data-heavy UIs.

**10. Explain CORS (Cross-Origin Resource Sharing).**  
CORS is a security feature in browsers that restricts requests between different origins.

- Without CORS headers, cross-domain requests fail.
- Server must set headers like:
  `Access-Control-Allow-Origin: https://example.com`

👉 Prevents malicious sites from accessing private APIs.

---

## 🟡 **Back-End & Databases (10)**

**11. What is the difference between monolithic and microservices architecture?**

- **Monolithic**: Single codebase, easier to start, harder to scale.
- **Microservices**: Independent services communicating via APIs, easier to scale, harder to manage.  
   👉 Senior developers often recommend microservices for large teams and scaling needs.

---

**12. How does Node.js handle concurrency with a single thread?**  
Node.js uses an **event-driven non-blocking I/O model**.

- Single-threaded event loop.
- Offloads heavy tasks to worker threads/libuv.  
   👉 Enables handling thousands of concurrent connections efficiently.

---

**13. Difference between SQL and NoSQL databases?**

- **SQL (Relational)**: Structured schema, ACID transactions, good for financial apps. (PostgreSQL, MySQL)
- **NoSQL (Non-relational)**: Flexible schema, horizontal scaling, great for unstructured data. (MongoDB, DynamoDB)  
   👉 Choice depends on data structure & scaling needs.

---

**14. Explain database indexing. Why is it important?**  
Indexes are special lookup tables that speed up queries.

- Without index → Full table scan (slow).
- With index → Quick lookup (fast).  
   👉 Tradeoff: Indexes speed reads but slow writes & use extra storage.

---

**15. What is an ORM, and do you recommend using one?**  
ORM (Object-Relational Mapping) allows querying the database using objects instead of SQL.

- Pros: Faster dev, less boilerplate, DB-agnostic.
- Cons: Performance overhead, complex queries harder.  
   👉 Use ORM for standard apps, raw SQL for high-performance queries.

---

**16. Explain JWT (JSON Web Token) authentication.**

- JWTs are encoded tokens containing user data and signatures.
- Stored on client-side (localStorage/cookies).
- Sent with each request to validate identity.  
   👉 Advantage: Stateless, scalable.  
   👉 Risk: Token theft → always use HTTPS & short expiry.

---

**17. Difference between session-based and token-based authentication?**

- **Session-based**: Server stores session in DB, client gets a cookie. Not scalable for large apps.
- **Token-based (JWT)**: Server issues a signed token, client stores it, server only validates signature. More scalable.

---

**18. How do you prevent SQL injection?**

- Always use parameterized queries (`?` placeholders).
- Never concatenate user input into SQL strings.
- Use ORM safeguards.  
   👉 Example (Node + MySQL):

`db.query("SELECT * FROM users WHERE id = ?", [userId])`

---

**19. Explain CAP theorem in distributed databases.**  
CAP = Consistency, Availability, Partition Tolerance.

- Can only guarantee **2 out of 3**.
- **CP**: Strong consistency but may sacrifice availability (e.g., MongoDB with replica sets).
- **AP**: Always available but eventual consistency (e.g., DynamoDB, Cassandra).

---

**20. How do you scale a web application?**

- Vertical scaling (bigger servers).
- Horizontal scaling (more servers + load balancing).
- Use caching (Redis, CDN).
- DB replication & sharding.
- Asynchronous processing (queues like RabbitMQ, Kafka).

---

# 📌 50 Senior Web Developer Interview Questions & Answers

---

## 🟢 **Core JavaScript & Frontend (10)**

**1. What are the differences between `var`, `let`, and `const` in JavaScript?**

- `var`: Function-scoped, hoisted, redeclaration allowed. Can cause bugs.
- `let`: Block-scoped, hoisted but uninitialized, can be reassigned.
- `const`: Block-scoped, must be initialized, cannot be reassigned.  
   👉 Best practice: Use `const` by default, `let` when necessary, avoid `var`.

---

**2. Can you explain event delegation in JavaScript?**  
Event delegation means attaching a single event listener to a parent instead of each child. Events bubble up to the parent, which checks the event target.  
👉 Benefits: Better performance, works for dynamically added elements.

---

**3. How does the JavaScript event loop work?**

- **Call Stack** → executes sync code.
- **Microtask Queue** → promises, mutation observers.
- **Task Queue** → `setTimeout`, DOM events.  
   👉 Order: Stack → Microtasks → Tasks → Render.

---

**4. Difference between synchronous and asynchronous code?**

- **Sync**: Blocks execution (e.g., `alert`).
- **Async**: Non-blocking (`setTimeout`, `fetch`).  
   👉 Async keeps UI responsive.

---

**5. What is the difference between `==` and `===`?**

- `==`: Loose equality, type coercion (`"5" == 5 → true`).
- `===`: Strict equality, no coercion (`"5" === 5 → false`).  
   👉 Use `===` by default.

---

**6. How does React’s Virtual DOM improve performance?**

- React keeps a lightweight Virtual DOM.
- On state changes → diffs old vs. new → updates only changed parts of real DOM.  
   👉 Reduces expensive DOM manipulations.

---

**7. What are React hooks, and why are they important?**  
Hooks let functional components use state/lifecycle:

- `useState`, `useEffect`, `useMemo`, `useCallback`.  
   👉 Simplifies logic, improves reusability, avoids classes.

---

**8. How do you optimize React app performance?**

- `React.memo`, `useMemo`, `useCallback`.
- Virtualize long lists (`react-window`).
- Code splitting & lazy loading.
- Avoid unnecessary re-renders.

---

**9. Difference between REST and GraphQL?**

- **REST**: Multiple endpoints, may over/under-fetch.
- **GraphQL**: Single endpoint, clients request exact data needed.  
   👉 REST = simple, GraphQL = flexible.

---

**10. Explain CORS.**  
CORS prevents cross-domain requests without permission.  
Server must add headers:

`Access-Control-Allow-Origin: https://example.com`

👉 Protects APIs from unauthorized use.

---

## 🟡 **Back-End & Databases (10)**

**11. Monolithic vs. Microservices?**

- **Monolithic**: Single codebase, simple but hard to scale.
- **Microservices**: Independent services, scalable, but complex.

---

**12. How does Node.js handle concurrency with a single thread?**

- Uses event-driven, non-blocking I/O.
- Heavy tasks → worker threads/libuv.  
   👉 Can handle thousands of requests.

---

**13. SQL vs. NoSQL?**

- **SQL**: Structured schema, ACID, great for relational data.
- **NoSQL**: Flexible schema, horizontal scaling, good for unstructured data.

---

**14. What is a database index?**  
Special data structure that speeds up queries.  
👉 Tradeoff: Faster reads, slower writes, extra storage.

---

**15. What is an ORM? Pros & cons?**

- Maps objects to DB tables.
- Pros: Faster dev, less boilerplate.
- Cons: Overhead, complex queries harder.

---

**16. Explain JWT authentication.**

- Encoded token with user info + signature.
- Stored client-side, sent with each request.  
   👉 Stateless, scalable, but must secure storage.

---

**17. Session-based vs. Token-based auth?**

- **Session**: Server stores session, client gets cookie. Hard to scale.
- **Token (JWT)**: Client stores token, server only validates signature. Scalable.

---

**18. How to prevent SQL injection?**

- Use parameterized queries / prepared statements.

`db.query("SELECT * FROM users WHERE id = ?", [id])`

- Avoid string concatenation.

---

**19. Explain CAP theorem.**

- **Consistency, Availability, Partition Tolerance** → can only guarantee 2.
- CP → MongoDB, AP → Cassandra.

---

**20. How to scale a web app?**

- Vertical scaling (bigger servers).
- Horizontal scaling (load balancers).
- Caching (Redis, CDN).
- DB sharding & replication.
- Queues (Kafka, RabbitMQ).

---

## 🔵 **System Design & Performance (10)**

**21. How would you design a scalable URL shortener?**

- API → generates unique short key.
- Store mapping in DB (SQL/NoSQL).
- Cache in Redis for fast lookups.
- Use hash + base62 encoding.
- Handle scaling with sharding + CDN.

---

**22. How to optimize web app performance?**

- Minify CSS/JS.
- Use CDN.
- Lazy load images.
- Cache aggressively.
- Optimize DB queries.

---

**23. Difference between horizontal and vertical scaling?**

- **Vertical**: Add more CPU/RAM to single server.
- **Horizontal**: Add more servers + load balancing.

---

**24. How to handle high traffic APIs?**

- Load balancer (NGINX).
- Caching with Redis.
- DB replication.
- Rate limiting & throttling.
- Async jobs for heavy tasks.

---

**25. What is load balancing, and why is it important?**  
Distributes traffic across servers to prevent overload.  
👉 Improves availability, scalability, and fault tolerance.

---

**26. Explain CDN and why it’s useful.**  
CDN = Content Delivery Network, caches static files in edge locations.  
👉 Reduces latency, speeds up global access.

---

**27. How do you handle state in a distributed system?**

- Store sessions in Redis or DB instead of local memory.
- Use sticky sessions only if needed.
- Prefer stateless design with JWTs.

---

**28. Difference between optimistic and pessimistic locking?**

- **Optimistic**: Assume no conflicts, check version before update.
- **Pessimistic**: Lock rows before update.  
   👉 Optimistic = better for read-heavy apps.

---

**29. What’s the difference between caching at the client, CDN, and server?**

- **Client-side**: Browser stores files.
- **CDN**: Edge servers cache static files.
- **Server-side**: Cache DB queries/results in Redis.

---

**30. How would you design a real-time chat app?**

- WebSockets for real-time communication.
- Redis pub/sub or Kafka for message delivery.
- Store messages in DB.
- Scale horizontally with load balancers.

---

## 🟣 **Security (10)**

**31. Common web security vulnerabilities?**

- XSS, CSRF, SQL Injection, SSRF, Clickjacking.

---

**32. How to prevent XSS?**

- Escape user input in HTML.
- Use CSP (Content Security Policy).
- Avoid `innerHTML`.

---

**33. How to prevent CSRF?**

- Use anti-CSRF tokens.
- SameSite cookies.
- Double-submit cookies pattern.

---

**34. How do HTTPS and TLS secure communication?**

- TLS encrypts data in transit.
- Ensures confidentiality, integrity, authenticity.

---

**35. Difference between hashing and encryption?**

- **Hashing**: One-way, used for passwords.
- **Encryption**: Two-way, reversible with a key.

---

**36. How do you store passwords securely?**

- Hash with bcrypt/argon2.
- Use salt + pepper.
- Never store plaintext.

---

**37. What is a man-in-the-middle (MITM) attack?**  
Attacker intercepts communication.  
👉 Prevent via HTTPS + certificate pinning.

---

**38. How to secure APIs?**

- Use HTTPS.
- JWT/OAuth for authentication.
- Rate limiting.
- Input validation.

---

**39. Difference between OAuth and JWT?**

- **OAuth**: Authorization framework, allows third-party access.
- **JWT**: Token format, can be used inside OAuth.

---

**40. What is CORS preflight request?**  
Browser sends `OPTIONS` request before cross-origin call.  
Server responds with allowed methods/headers.

---

## 🟠 **DevOps, Testing, Leadership (10)**

**41. CI/CD – what is it and why important?**

- **CI**: Frequent integration with automated tests.
- **CD**: Automated deployment pipeline.  
   👉 Ensures fast, reliable releases.

---

**42. What’s the difference between unit, integration, and e2e tests?**

- **Unit**: Test functions in isolation.
- **Integration**: Test modules working together.
- **E2E**: Test entire workflow (e.g., login → checkout).

---

**43. How do you handle logging & monitoring?**

- Use centralized logging (ELK, Datadog).
- Metrics (Prometheus, Grafana).
- Alerts for failures.

---

**44. What’s Docker and why use it?**

- Containers package app + dependencies.  
   👉 Ensures consistency across environments.

---

**45. What is Kubernetes?**

- Container orchestration system.
- Manages scaling, load balancing, rolling updates.

---

**46. Difference between Agile and Waterfall?**

- **Waterfall**: Sequential phases, rigid.
- **Agile**: Iterative, flexible, customer feedback-driven.

---

**47. How do you mentor junior developers?**

- Pair programming, code reviews.
- Encourage best practices.
- Provide learning resources.
- Give ownership of tasks.

---

**48. What’s your process for debugging production issues?**

- Reproduce issue.
- Check logs/monitoring.
- Rollback if critical.
- Hotfix & deploy.
- Post-mortem analysis.

---

**49. How do you ensure code quality in a large team?**

- Code reviews.
- Linting & formatting (ESLint, Prettier).
- Automated tests.
- CI/CD pipelines.

---

**50. What’s the hardest technical decision you’ve made as a senior dev?**  
👉 Here you tell a **real story**: e.g., migrating monolith → microservices, switching DBs, handling scaling issues.

- Show trade-offs.
- Show business impact.
- Show leadership.
