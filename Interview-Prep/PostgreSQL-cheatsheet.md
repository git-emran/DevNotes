# PostgreSQL Interview Cheatsheet

 ## 1. Core Concepts

 - **PostgreSQL** is an object-relational database (ORDBMS) — supports relational + JSON/JSONB, arrays, custom types.
- **ACID**: Atomicity, Consistency, Isolation, Durability — guaranteed via WAL (Write-Ahead Log) and MVCC.
- **MVCC (Multi-Version Concurrency Control)**: readers never block writers and vice versa. Each row has hidden `xmin`/`xmax` transaction IDs; old row versions become "dead tuples" cleaned by `VACUUM`.

 ---

 ## 2. Data Definition (DDL)

 ```sql
CREATE TABLE employees (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       TEXT UNIQUE,
    department  TEXT,
    salary      NUMERIC(10,2) CHECK (salary > 0),
    manager_id  INTEGER REFERENCES employees(id),
    created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE employees ADD COLUMN active BOOLEAN DEFAULT true;
ALTER TABLE employees DROP COLUMN active;
ALTER TABLE employees RENAME COLUMN name TO full_name;
DROP TABLE employees;
```

 **Key constraints**: `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `NOT NULL`, `CHECK`, `DEFAULT`, `EXCLUDE`.

 **SERIAL vs IDENTITY**: `SERIAL` is legacy (creates an implicit sequence). Prefer SQL-standard:

 ```sql
id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
```

 ---

 ## 3. Data Manipulation (DML)

 ```sql
INSERT INTO employees (name, department, salary) VALUES ('Amy', 'Eng', 90000);

INSERT INTO employees (name, salary) VALUES ('Bo', 50000)
ON CONFLICT (email) DO UPDATE SET salary = EXCLUDED.salary;   -- UPSERT

UPDATE employees SET salary = salary * 1.1 WHERE department = 'Eng';

DELETE FROM employees WHERE active = false;

-- RETURNING clause (very Postgres-specific, loved in interviews)
DELETE FROM employees WHERE id = 5 RETURNING *;
```

 ---

 ## 4. Joins — know all of these cold

 | Join Type | Behavior |
| --- | --- |
| `INNER JOIN` | Only matching rows in both tables |
| `LEFT JOIN` | All left rows + matched right rows (NULL if no match) |
| `RIGHT JOIN` | All right rows + matched left rows |
| `FULL OUTER JOIN` | All rows from both, NULL where no match |
| `CROSS JOIN` | Cartesian product |
| `SELF JOIN` | Table joined to itself (e.g. employee → manager) |

 ```sql
-- Self join example: employee & their manager
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
```

 **LEFT JOIN vs subquery vs EXISTS**: `EXISTS` is often faster for existence checks because Postgres can short-circuit on first match.

 ---

 ## 5. Aggregation & Window Functions

 ```sql
-- GROUP BY + HAVING
SELECT department, AVG(salary)
FROM employees
GROUP BY department
HAVING AVG(salary) > 60000;

-- Window functions (classic interview topic)
SELECT name, department, salary,
       RANK()       OVER (PARTITION BY department ORDER BY salary DESC) AS rnk,
       DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS dense_rnk,
       ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn,
       LAG(salary)  OVER (PARTITION BY department ORDER BY salary) AS prev_salary,
       LEAD(salary) OVER (PARTITION BY department ORDER BY salary) AS next_salary,
       SUM(salary)  OVER (PARTITION BY department) AS dept_total
FROM employees;
```

 **RANK vs DENSE_RANK vs ROW_NUMBER**:

 - `ROW_NUMBER()` → always unique, no gaps.
- `RANK()` → ties share rank, gaps after ties (1,1,3).
- `DENSE_RANK()` → ties share rank, no gaps (1,1,2).

 **Classic interview question**: "Find the 2nd highest salary per department" → use `DENSE_RANK()` in a CTE, filter `WHERE rnk = 2`.

 ---

 ## 6. CTEs & Subqueries

 ```sql
-- Common Table Expression
WITH dept_avg AS (
    SELECT department, AVG(salary) AS avg_sal
    FROM employees
    GROUP BY department
)
SELECT e.name, e.salary, d.avg_sal
FROM employees e
JOIN dept_avg d ON e.department = d.department
WHERE e.salary > d.avg_sal;

-- Recursive CTE (org chart / hierarchy — very common interview question)
WITH RECURSIVE org_chart AS (
    SELECT id, name, manager_id, 1 AS level
    FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id, oc.level + 1
    FROM employees e
    JOIN org_chart oc ON e.manager_id = oc.id
)
SELECT * FROM org_chart;
```

 ---

 ## 7. Indexes

 | Index Type | Use Case |
| --- | --- |
| `B-tree`(default) | Equality & range queries, most common |
| `Hash` | Equality only, rarely used |
| `GIN` | Full-text search, JSONB, arrays |
| `GiST` | Geometric data, full-text, nearest-neighbor |
| `BRIN` | Very large tables with naturally sorted data (e.g. time-series) |

 ```sql
CREATE INDEX idx_emp_dept ON employees(department);
CREATE UNIQUE INDEX idx_emp_email ON employees(email);
CREATE INDEX idx_emp_json ON employees USING GIN (metadata jsonb_path_ops);

-- Partial index
CREATE INDEX idx_active_emp ON employees(department) WHERE active = true;

-- Composite index — column order matters! Leftmost prefix rule
CREATE INDEX idx_emp_dept_sal ON employees(department, salary);
```

 **Interview gotcha**: an index on `(a, b)` helps queries filtering on `a` or `a AND b`, but NOT on `b` alone.

 ---

 ## 8. Query Planning & Performance

 ```sql
EXPLAIN SELECT * FROM employees WHERE department = 'Eng';
EXPLAIN ANALYZE SELECT * FROM employees WHERE department = 'Eng';
```

 - **Seq Scan** → full table scan (bad on large tables without filter selectivity).
- **Index Scan** → uses index, then fetches row from heap.
- **Index Only Scan** → satisfies query entirely from index (fastest).
- **Bitmap Heap Scan** → combines multiple indexes efficiently.

 **VACUUM & ANALYZE**:

 - `VACUUM` reclaims space from dead tuples (MVCC leftovers).
- `ANALYZE` updates planner statistics.
- `VACUUM FULL` rewrites the table (locks it — use cautiously).
- Autovacuum handles this automatically in most setups.

 ---

 ## 9. Transactions & Isolation

 ```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;   -- or ROLLBACK;
```

 **Isolation levels** (Postgres default: `READ COMMITTED`):

 | Level | Prevents |
| --- | --- |
| Read Uncommitted | (treated same as Read Committed in PG) |
| Read Committed | Dirty reads |
| Repeatable Read | Dirty + non-repeatable reads |
| Serializable | Dirty + non-repeatable + phantom reads |

 **Common concurrency problems to be able to explain**:

 - **Dirty read** — reading uncommitted data from another transaction.
- **Non-repeatable read** — re-reading a row gives a different value mid-transaction.
- **Phantom read** — re-running a query returns different rows.
- **Deadlock** — two transactions waiting on each other's locks (Postgres auto-detects & aborts one).

 ---

 ## 10. JSON / JSONB (Postgres specialty — often asked)

 ```sql
SELECT data->>'name' AS name FROM users WHERE data->>'age' = '30';   -- json/jsonb text extraction
SELECT data->'address'->>'city' FROM users;                          -- nested
SELECT * FROM users WHERE data @> '{"active": true}';                -- containment
CREATE INDEX idx_users_data ON users USING GIN (data);
```

 `JSONB` (binary, indexable, slightly slower to write) is almost always preferred over `JSON` (text, preserves formatting, no indexing).

 ---

 ## 11. Normalization (theory question staple)

 - **1NF**: atomic columns, no repeating groups.
- **2NF**: 1NF + no partial dependency on a composite key.
- **3NF**: 2NF + no transitive dependency (non-key columns depend only on the key).
- **Denormalization** is a deliberate performance trade-off — be ready to discuss when you'd do it (read-heavy analytics, avoiding expensive joins).

 ---

 ## 12. Common "Gotcha" Interview Questions

 1. **Why use `NUMERIC` over `FLOAT` for money?** → `FLOAT` is binary approximate; `NUMERIC` is exact decimal.
2. **What's the difference between `TRUNCATE`, `DELETE`, `DROP`?**
  - `DELETE` — row-by-row, logged, triggers fire, can `WHERE`/rollback.
  - `TRUNCATE` — fast, resets identity, minimal logging, can't `WHERE`.
  - `DROP` — removes the table/object entirely.
3. **How does Postgres handle `NULL` in comparisons?** → `NULL = NULL` is `NULL` (not true). Use `IS NULL` / `IS NOT NULL`. `NULL` values are excluded from most aggregates except `COUNT(*)`.
4. **What is a sequence and how does `SERIAL` use it?** → Auto-incrementing counter object; `SERIAL` creates one implicitly and ties it to the column default.
5. **Difference between `UNION` and `UNION ALL`?** → `UNION` dedupes (implicit sort/hash, slower); `UNION ALL` keeps duplicates (faster).
6. **What's a materialized view?** ```sql
   CREATE MATERIALIZED VIEW mv_dept_summary ASSELECT department, COUNT(*), AVG(salary) FROM employees GROUP BY department;REFRESH MATERIALIZED VIEW mv_dept_summary;
   ```

   Physically stores results (fast reads, stale until refreshed) vs a regular `VIEW` (always live, re-runs query each time).
7. **Row-level locking**: `SELECT ... FOR UPDATE` locks selected rows to prevent concurrent modification — key for building things like a booking system or queue.
8. **What is connection pooling and why does Postgres need it?** → Each Postgres connection is a full OS process (relatively expensive); tools like **PgBouncer** multiplex many client connections onto fewer DB connections.

 ---

 ## 13. Quick Syntax Reference

 ```sql
-- String functions
SELECT CONCAT(first, ' ', last), UPPER(name), LOWER(name), LENGTH(name);
SELECT * FROM employees WHERE name ILIKE '%smith%';   -- case-insensitive LIKE

-- Date/time
SELECT NOW(), CURRENT_DATE, AGE(NOW(), created_at);
SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '7 days';

-- COALESCE / NULLIF
SELECT COALESCE(nickname, first_name) AS display_name FROM employees;

-- Array
SELECT ARRAY[1,2,3], unnest(ARRAY[1,2,3]);
```

 ---

 ## 14. Things to Say Out Loud If Asked "Why Postgres?"

 - Strong standards compliance (SQL:2016+ features), extensibility (custom types, `CREATE EXTENSION` e.g. `PostGIS`, `pg_trgm`, `pgvector`).
- MVCC for high concurrency without heavy locking.
- Native JSONB gives it a document-store option without leaving relational guarantees.
- Excellent for both OLTP and light analytics; horizontally scalable via extensions like Citus.


# Scenario Based Question


 Each question is framed the way an interviewer would actually ask it — a real situation, not just theory — followed by the answer/approach.

 ---

 ### 1. Your app is slow on a query filtering `WHERE status = 'pending'` on a 10M-row table. How do you diagnose and fix it?

 Run `EXPLAIN ANALYZE` on the query first — don't guess. If it shows a `Seq Scan` with high cost, check selectivity: if `pending` is a small fraction of rows, add a plain or **partial index**:

 ```sql
CREATE INDEX idx_orders_pending ON orders(status) WHERE status = 'pending';
```

 A partial index is smaller and faster than a full index when you only ever query one value. If `status` has few distinct values overall (low cardinality), a plain B-tree index may not even get used — the planner might correctly prefer a seq scan.

 ---

 ### 2. Two requests try to decrement the same product's inventory at the same time. How do you prevent overselling?

 Use row-level locking inside a transaction:

 ```sql
BEGIN;
SELECT stock FROM products WHERE id = 42 FOR UPDATE;
-- app checks stock > 0
UPDATE products SET stock = stock - 1 WHERE id = 42;
COMMIT;
```

 `FOR UPDATE` locks the row so the second transaction blocks until the first commits. Alternative: an atomic conditional update with no explicit lock needed —

 ```sql
UPDATE products SET stock = stock - 1 WHERE id = 42 AND stock > 0 RETURNING stock;
```

 Check `RETURNING` rowcount in the app; if 0 rows returned, sale fails.

 ---

 ### 3. You need to insert a row, or update it if it already exists (e.g. syncing a user profile from an external system). How?

 `UPSERT` via `ON CONFLICT`:

 ```sql
INSERT INTO users (email, name, last_synced)
VALUES ('amy@x.com', 'Amy', now())
ON CONFLICT (email)
DO UPDATE SET name = EXCLUDED.name, last_synced = EXCLUDED.last_synced;
```

 Requires a unique constraint/index on `email` for `ON CONFLICT` to target.

 ---

 ### 4. A migration needs to add a `NOT NULL` column to a table with 50M existing rows without locking it for minutes. What's the safe approach?

 Adding a column with a constant `DEFAULT` is fast in modern Postgres (11+) — it's metadata-only, no table rewrite. The risky part is `NOT NULL` with no default on existing data. Safe pattern:

 ```sql
ALTER TABLE big_table ADD COLUMN status TEXT DEFAULT 'active';   -- fast, no rewrite
ALTER TABLE big_table ALTER COLUMN status SET NOT NULL;          -- still needs a full scan to verify, but no rewrite
```

 For truly massive tables, add the column nullable, backfill in batches, then add a `CHECK (status IS NOT NULL) NOT VALID` followed by `VALIDATE CONSTRAINT` to avoid a long exclusive lock.

 ---

 ### 5. Your reporting dashboard runs a heavy aggregate query every page load and it's killing the DB. How do you fix it without changing the query logic?

 Use a **materialized view** and refresh it on a schedule (cron / pg_cron) instead of computing live:

 ```sql
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT date_trunc('day', created_at) AS day, SUM(amount) AS total
FROM orders GROUP BY 1;

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_sales;  -- needs a unique index to run CONCURRENTLY
```

 Dashboard reads become O(1) lookups on the materialized view instead of scanning/aggregating live data.

 ---

 ### 6. You need to find duplicate rows (e.g. duplicate emails) and delete all but one of each. How?

 ```sql
DELETE FROM users a
USING users b
WHERE a.id < b.id
AND a.email = b.email;
```

 Or with window functions (often clearer):

 ```sql
DELETE FROM users
WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
    FROM users
  ) t WHERE rn > 1
);
```

 ---

 ### 7. A long-running report query is blocking other queries on the same table. What do you check and how do you handle it?

 Check active locks and blocking sessions:

 ```sql
SELECT pid, query, state, wait_event_type
FROM pg_stat_activity
WHERE state != 'idle';

SELECT * FROM pg_locks WHERE NOT granted;
```

 If it's genuinely blocking (e.g. an `ALTER TABLE` waiting behind a long transaction), you may need to `pg_terminate_backend(pid)` the offending session. Longer-term: run heavy reports against a **read replica** rather than the primary, and keep DDL changes in low-traffic windows.

 ---

 ### 8. You're storing flexible, schema-varying attributes on a `products` table (different products have different specs). Column-per-attribute doesn't scale. What's the Postgres-native solution?

 Use a `JSONB` column:

 ```sql
ALTER TABLE products ADD COLUMN specs JSONB;
CREATE INDEX idx_products_specs ON products USING GIN (specs);

SELECT * FROM products WHERE specs @> '{"color": "red"}';
SELECT specs->>'weight_kg' FROM products WHERE id = 1;
```

 Keep core queryable/relational fields (price, category) as real columns, and only push the truly variable data into JSONB — don't put everything in JSONB just because you can.

 ---

 ### 9. You need an "audit trail" — every change to a `payments` table should be logged automatically, without relying on the application layer to remember to log it. How?

 Use a trigger + audit table:

 ```sql
CREATE TABLE payments_audit (id SERIAL, payment_id INT, changed_at TIMESTAMPTZ DEFAULT now(), old_data JSONB, new_data JSONB, op TEXT);

CREATE OR REPLACE FUNCTION log_payment_change() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO payments_audit(payment_id, old_data, new_data, op)
  VALUES (COALESCE(NEW.id, OLD.id), to_jsonb(OLD), to_jsonb(NEW), TG_OP);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payments_audit
AFTER INSERT OR UPDATE OR DELETE ON payments
FOR EACH ROW EXECUTE FUNCTION log_payment_change();
```

 This guarantees logging happens at the DB level regardless of which app/service writes to the table.

 ---

 ### 10. Your table has grown to 500M rows of time-series data (e.g. sensor logs) and queries are getting slow even with indexes. What's the scaling strategy?

 **Partitioning** — usually by time range:

 ```sql
CREATE TABLE sensor_logs (id BIGSERIAL, sensor_id INT, reading NUMERIC, logged_at TIMESTAMPTZ)
PARTITION BY RANGE (logged_at);

CREATE TABLE sensor_logs_2026_08 PARTITION OF sensor_logs
FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
```

 Queries filtered by date only scan relevant partitions ("partition pruning"). Old partitions can be dropped or archived cheaply instead of running a slow `DELETE`.

 ---

 ### 11. You need pagination on an endpoint returning millions of rows, but `OFFSET 100000 LIMIT 20` is getting slower the deeper you paginate. Why, and what's better?

 `OFFSET` still scans and discards all skipped rows — it doesn't jump to a position. Use **keyset (cursor) pagination** instead:

 ```sql
SELECT * FROM posts WHERE created_at < $last_seen_created_at
ORDER BY created_at DESC LIMIT 20;
```

 This uses the index directly to seek to the right spot, with consistent performance regardless of page depth.

 ---

 ### 12. A colleague wrote a query that works fine in dev but times out in production with the same data volume claimed. What's your first move?

 Compare `EXPLAIN ANALYZE` output between environments — production may have stale statistics. Run:

 ```sql
ANALYZE table_name;
```

 Stale planner statistics (e.g. after a big bulk load without autovacuum catching up) can cause Postgres to pick a bad plan (e.g. seq scan instead of index scan, or a bad join order). Also check that prod actually has the same indexes as dev — migrations sometimes get missed.

 ---

 ### 13. You need to run a data backfill/migration script on a huge table but can't afford to lock it or spike load. How do you batch it safely?

 Update in small chunks with a loop, committing between batches:

 ```sql
DO $$
DECLARE affected INT;
BEGIN
  LOOP
    UPDATE orders SET status = 'archived'
    WHERE id IN (SELECT id FROM orders WHERE status = 'old' LIMIT 1000);
    GET DIAGNOSTICS affected = ROW_COUNT;
    EXIT WHEN affected = 0;
    COMMIT;
  END LOOP;
END $$;
```

 Small transactions avoid long lock hold times and huge WAL/replication lag spikes, and let autovacuum keep up.

 ---

 ### 14. Two services both write to the same `accounts` table and you're occasionally seeing deadlocks under load. How do you prevent them?

 Deadlocks usually come from transactions locking rows in **inconsistent order**. Fix by always acquiring locks in a consistent order (e.g. always by ascending `id`):

 ```sql
BEGIN;
SELECT * FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;
-- do transfer logic
COMMIT;
```

 Postgres also auto-detects deadlocks and aborts one transaction (`deadlock_timeout`), so the app should catch that error and retry — but reducing lock-order inconsistency is the real fix.

 ---

 ### 15. You accidentally ran an `UPDATE` without a `WHERE` clause in production. What do you do, and how could this have been prevented?

 Immediate: if still in an open transaction, `ROLLBACK`. If already committed, restore from the most recent backup/WAL archive using **point-in-time recovery (PITR)** to just before the bad statement. Prevention: never run ad-hoc writes directly against prod — use a tool/psql setting that requires `WHERE` confirmation, always wrap manual changes in an explicit `BEGIN`, review, then `COMMIT`, and restrict direct prod write access.

 ---

 ### 16. Your `SELECT COUNT(*)` on a large table is surprisingly slow. Why, and what are the alternatives?

 Because of MVCC, Postgres has no cached row count — it must visibility-check each row against the current transaction, effectively a full scan. Alternatives depending on need:

 - Approximate count from planner stats (good enough for UI display):

 ```sql
SELECT reltuples::bigint FROM pg_class WHERE relname = 'orders';
```

 - Maintain a running counter in a separate table via triggers if exact real-time counts matter often.

 ---

 ### 17. You need full-text search on a `articles` table (title + body) without adding Elasticsearch. Can Postgres do this well?

 Yes — native full-text search with `tsvector`/`tsquery`:

 ```sql
ALTER TABLE articles ADD COLUMN search_vector TSVECTOR;
UPDATE articles SET search_vector = to_tsvector('english', title || ' ' || body);
CREATE INDEX idx_articles_search ON articles USING GIN (search_vector);

SELECT * FROM articles WHERE search_vector @@ to_tsquery('english', 'postgres & performance');
```

 For most apps this is enough; reach for a dedicated search engine only when you need advanced ranking/relevance tuning, typo tolerance, or huge scale.

 ---

 ### 18. A `SERIAL` primary key table had rows bulk-deleted and re-inserted, and now IDs have huge gaps or the sequence is out of sync after a manual data load. What's happening and how do you fix the sequence?

 Sequences never reuse values (by design — safe under concurrency), so gaps from deletes are normal and not a bug. If a manual `INSERT ... id=...` bypassed the sequence, resync it:

 ```sql
SELECT setval('orders_id_seq', (SELECT MAX(id) FROM orders));
```

 ---

 ### 19. You want to guarantee a `discount_code` is used at most N times total, safely under concurrent redemptions. How do you enforce that at the DB level, not just in app code?

 Use an atomic conditional update, not a read-then-write:

 ```sql
UPDATE discount_codes
SET uses = uses + 1
WHERE code = 'SUMMER10' AND uses < max_uses
RETURNING uses;
```

 If 0 rows are returned, the code is exhausted — reject in the app. Doing a `SELECT` to check `uses < max_uses` first and then updating separately is a race condition under concurrency; the single atomic `UPDATE ... WHERE` closes that gap.

 ---

 ### 20. You need to connect thousands of short-lived serverless function invocations to Postgres without exhausting connections. What's the standard fix?

 Each Postgres connection is a real OS backend process — expensive, with a hard `max_connections` ceiling. Put a **connection pooler** (e.g. PgBouncer) in front of Postgres in `transaction` pooling mode, so many client connections share a small pool of actual DB connections. Also consider Postgres-native solutions like Supabase's pooler or RDS Proxy if on managed infra.

 ---

 **Tip for the interview**: for almost every scenario question, the strongest answer format is: *(1) name the mechanism* (locking, MVCC, partitioning, pooling, etc.), *(2) show a short code snippet*, *(3) mention the trade-off*. That structure signals you understand the "why," not just the syntax.