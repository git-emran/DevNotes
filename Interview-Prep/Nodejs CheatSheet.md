# Node.js Cheatsheet — Senior Developer Interview

 ## 1. Event Loop (the #1 thing you'll be asked to explain)

 ```
   ┌───────────────────────────┐
┌─>│           timers          │  setTimeout, setInterval
│  ├───────────────────────────┤
│  │     pending callbacks     │  I/O callbacks deferred to next loop
│  ├───────────────────────────┤
│  │       idle, prepare       │  internal
│  ├───────────────────────────┤
│  │           poll            │  retrieve new I/O events, execute I/O callbacks
│  ├───────────────────────────┤
│  │           check           │  setImmediate()
│  ├───────────────────────────┤
│  │      close callbacks      │  socket.on('close', ...)
│  └───────────────────────────┘
```

 - Node is **single-threaded** for JS execution but uses **libuv**'s thread pool (default 4 threads) for file I/O, DNS lookups, and some crypto operations.
- **Microtasks** (Promises, `process.nextTick`) run **between every phase**, not just at the end of the loop.
- `process.nextTick()` has higher priority than `Promise.then()` — it drains completely before promises.

 ```js
console.log('1');
setTimeout(() => console.log('2'), 0);
Promise.resolve().then(() => console.log('3'));
process.nextTick(() => console.log('4'));
console.log('5');
// Output: 1, 5, 4, 3, 2
```

 ## 2. Async Patterns

 ```js
// Callback (legacy)
fs.readFile('file.txt', (err, data) => { ... });

// Promise
fs.promises.readFile('file.txt').then(data => ...).catch(err => ...);

// async/await (preferred)
async function read() {
  try {
    const data = await fs.promises.readFile('file.txt');
  } catch (err) { ... }
}

// Parallel execution
const [a, b] = await Promise.all([fetchA(), fetchB()]);

// Promise.allSettled — doesn't short-circuit on rejection
const results = await Promise.allSettled([p1, p2]);

// Promise.race / Promise.any
await Promise.race([p1, p2]);   // first to settle (resolve or reject)
await Promise.any([p1, p2]);     // first to fulfill, ignores rejections unless all reject

// Sequential vs parallel — common interview trap
for (const url of urls) {
  await fetch(url);           // sequential, slow
}
await Promise.all(urls.map(fetch));  // parallel, fast
```

 ## 3. Streams (critical for senior-level questions)

 ```js
const { Readable, Writable, Transform, pipeline } = require('stream');

// 4 types: Readable, Writable, Duplex (both), Transform (modifies data)

// Backpressure — the key concept interviewers probe
readable.pipe(writable);   // pipe handles backpressure automatically

// Manual backpressure handling
readable.on('data', (chunk) => {
  if (!writable.write(chunk)) {
    readable.pause();
    writable.once('drain', () => readable.resume());
  }
});

// Modern approach: pipeline (handles errors + cleanup automatically)
const { pipeline } = require('stream/promises');
await pipeline(readableStream, transformStream, writableStream);

// Why streams matter: process large files without loading everything into memory
fs.createReadStream('huge.csv')
  .pipe(csvParser())
  .pipe(transformStream)
  .pipe(fs.createWriteStream('out.csv'));
```

 ## 4. Module Systems

 ```js
// CommonJS (default in .js unless package.json has "type": "module")
const fs = require('fs');
module.exports = { foo };

// ESM
import fs from 'fs';
export { foo };
export default bar;

// Key differences
// - CJS is synchronous, loaded at require-time; ESM is async, statically analyzable
// - CJS: require() can be called conditionally/anywhere; ESM imports are hoisted, top-level only
// - `this` in CJS module scope = module.exports; in ESM top-level `this` = undefined
// - __dirname/__filename don't exist in ESM — use:
import { fileURLToPath } from 'url';
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
```

 ## 5. Error Handling Patterns

 ```js
// Operational errors (expected, e.g. bad input) vs Programmer errors (bugs)

// Global handlers — safety nets, NOT a substitute for proper handling
process.on('uncaughtException', (err) => {
  logger.error(err);
  process.exit(1);   // recommended: crash and restart, don't try to "recover"
});
process.on('unhandledRejection', (reason) => {
  logger.error(reason);
  process.exit(1);
});

// Custom error classes
class AppError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

// Async error propagation in Express (pre-v5 gotcha)
app.get('/route', async (req, res, next) => {
  try {
    await doSomething();
  } catch (err) {
    next(err);   // must manually forward — Express doesn't catch async errors automatically pre-v5
  }
});
// Or wrap with a helper:
const asyncHandler = fn => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
```

 ## 6. Concurrency Model — Worker Threads vs Cluster vs Child Process

 | Approach | Use case | Memory | Communication |
| --- | --- | --- | --- |
| `worker_threads` | CPU-bound JS work (parsing, hashing) | Shared (SharedArrayBuffer possible) | postMessage |
| `cluster` | Scale across CPU cores for HTTP servers | Separate processes | IPC |
| `child_process` | Run external commands/scripts | Separate processes | IPC/stdio |

 ```js
const { Worker } = require('worker_threads');
const worker = new Worker('./heavy-task.js', { workerData: { n: 40 } });
worker.on('message', (result) => console.log(result));

// Cluster — one process per CPU core, load-balanced by the OS
const cluster = require('cluster');
if (cluster.isPrimary) {
  for (let i = 0; i < os.cpus().length; i++) cluster.fork();
} else {
  app.listen(3000);
}
```

 ## 7. Memory Management & Performance

 ```js
// Common memory leak sources
// 1. Global variables accumulating data
// 2. Uncleared timers/intervals holding closures
// 3. Detached event listeners (add without remove)
// 4. Growing caches without eviction (use LRU)
// 5. Closures capturing large objects unintentionally

// Inspecting memory
node --inspect app.js         // Chrome DevTools profiling
process.memoryUsage()         // { rss, heapTotal, heapUsed, external }

// V8 heap snapshot for leak diagnosis
node --inspect --expose-gc app.js

// Buffer vs string — Buffers are raw binary, more memory-efficient for binary data
Buffer.from('hello', 'utf8');
Buffer.alloc(10);   // zero-filled buffer of 10 bytes
```

 ## 8. Express / API Layer Fundamentals

 ```js
// Middleware order matters — executes top to bottom
app.use(express.json());              // body parser
app.use(helmet());                     // security headers
app.use(cors());                        // CORS
app.use(rateLimiter);                    // throttling
app.use('/api', router);
app.use(errorHandler);                    // must be LAST, 4 args (err, req, res, next)

// Middleware signature
function mw(req, res, next) {
  // ...
  next();          // must call to continue, or send a response
}

// Error-handling middleware (Express identifies by arity = 4)
function errorHandler(err, req, res, next) {
  res.status(err.statusCode || 500).json({ error: err.message });
}
```

 ## 9. Security Essentials (senior-level expectation)

 ```js
// - Never trust user input: validate & sanitize (joi, zod, express-validator)
// - Parameterized queries only — never string-concat SQL
// - helmet() for secure headers (CSP, HSTS, X-Frame-Options)
// - Rate limiting on auth endpoints (express-rate-limit)
// - bcrypt/argon2 for password hashing, never plain SHA/MD5
// - JWT: keep access tokens short-lived, use refresh token rotation, store in httpOnly cookies (not localStorage, to reduce XSS risk)
// - CORS: explicit allow-list, not '*' with credentials
// - Environment secrets via env vars / secret manager, never committed
// - npm audit / Snyk for dependency vulnerabilities

const bcrypt = require('bcrypt');
const hash = await bcrypt.hash(password, 12);   // 12 = cost factor
const valid = await bcrypt.compare(password, hash);
```

 ## 10. Testing

 ```js
// Jest / Vitest common patterns
describe('UserService', () => {
  beforeEach(() => { jest.clearAllMocks(); });

  it('should create a user', async () => {
    const mockRepo = { save: jest.fn().mockResolvedValue({ id: 1 }) };
    const service = new UserService(mockRepo);
    const user = await service.create({ name: 'A' });
    expect(user.id).toBe(1);
    expect(mockRepo.save).toHaveBeenCalledWith({ name: 'A' });
  });
});

// Supertest for HTTP integration tests
const request = require('supertest');
await request(app).post('/users').send({ name: 'A' }).expect(201);
```

 ## 11. Common Gotchas

 ```js
// `this` binding in regular functions vs arrow functions
const obj = {
  name: 'x',
  regular() { return this.name; },     // `this` = obj
  arrow: () => this.name,               // `this` = enclosing scope (often undefined)
};

// Closures in loops (var vs let)
for (var i = 0; i < 3; i++) { setTimeout(() => console.log(i), 0); }  // 3,3,3
for (let i = 0; i < 3; i++) { setTimeout(() => console.log(i), 0); }  // 0,1,2

// Event emitter memory leak warning
emitter.setMaxListeners(20);   // default is 10, warns if exceeded (usually signals a leak)

// require() caching — modules are cached after first require
// mutating an exported object affects all importers

// Floating promises — a very common senior-level code review flag
someAsyncFn();               // BAD: unhandled rejection risk
await someAsyncFn();          // or: someAsyncFn().catch(handleErr);

// setImmediate vs setTimeout(fn, 0)
// setImmediate always runs in the 'check' phase after I/O callbacks;
// setTimeout(0) may fire before or after depending on context (main module vs I/O cycle)
```

 ## 12. Architecture & Senior-Level Talking Points

 - **Horizontal scaling**: stateless services behind a load balancer; session state in Redis, not in-process memory.
- **Graceful shutdown**: handle `SIGTERM`, drain in-flight requests, close DB connections before exit.

 ```js
process.on('SIGTERM', async () => {
  server.close(() => process.exit(0));
  await db.close();
});
```

 - **12-factor app principles**: config via env vars, stateless processes, disposability, logs as event streams.
- **Observability**: structured logging (pino/winston), distributed tracing (OpenTelemetry), metrics (Prometheus).
- **Caching strategy**: cache-aside vs write-through, TTL vs explicit invalidation, cache stampede protection.
- **Rate limiting & circuit breakers**: protect downstream services (e.g. `opossum` for circuit breaking).
- **Database connection pooling**: reuse connections; size the pool relative to concurrent load, not infinitely.
- **Idempotency**: for POST/PUT operations in distributed systems (idempotency keys) to safely handle retries.
- **N+1 query problem**: a common review flag in ORM-heavy code — use eager loading / DataLoader batching.

 ## 13. Package Manager & Tooling Essentials

 ```bash
npm ci                 # clean install from package-lock.json (use in CI, not `npm install`)
npm audit fix           # patch known vulnerabilities
npx <package>            # run a package without installing globally

# package.json semver ranges
"^1.2.3"   # compatible with 1.x.x (>=1.2.3 <2.0.0)
"~1.2.3"   # patch-level only (>=1.2.3 <1.3.0)
"1.2.3"    # exact
```

 ## 14. Quick Reference: Things You Should Be Able to Explain Live

 - Difference between `process.nextTick`, microtasks, and macrotasks — and the exact ordering.
- Why blocking the event loop (e.g. sync CPU-heavy code) tanks throughput for *all* requests.
- When to reach for worker threads vs horizontal scaling vs offloading to a queue (BullMQ/RabbitMQ/SQS).
- Difference between `TypeError`, unhandled rejections, and process crashes — and how each should be handled.
- Trade-offs of monorepo vs polyrepo, and why (npm/yarn/pnpm workspaces).
- How Node resolves modules (`node_modules` lookup algorithm, package.json `exports` field).