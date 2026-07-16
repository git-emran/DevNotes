 # 1. Understanding the Data Source

Hacker News exposes a free, unauthenticated Firebase-backed API — no key needed:

- `https://hacker-news.firebaseio.com/v0/jobstories.json` → returns an array of **story IDs** (just numbers), most recent first
- `https://hacker-news.firebaseio.com/v0/item/{id}.json` → returns the full item for one ID

The gotcha: there's no single endpoint that returns full job objects. You get an ID list, then fan out N requests to fetch each item. This shapes your whole data-fetching strategy — you need pagination/batching or you'll fire off hundreds of requests on load.

 A job item looks like:

 json

```json
{
  "id": 41234567,
  "type": "job",
  "title": "Acme Inc is hiring a Senior React Engineer",
  "url": "https://acme.com/careers/senior-react",
  "text": "Optional HTML description if no url",
  "by": "acmehr",
  "time": 1720000000,
  "score": 1
}
```

 Note: some job posts have `url`, others only have `text` (an HTML snippet with the description inline).

## 2. Project Setup

 bash

```bash
npm create vite@latest hn-job-board -- --template react-ts
cd hn-job-board
npm install
```

 Folder structure:

 ```
src/
  api/
    hackernews.ts       # API layer, typed fetch functions
  types/
    job.ts              # shared TS types
  hooks/
    useJobStories.ts     # fetch + paginate IDs
    useJobDetails.ts      # batch-fetch item details
  components/
    JobBoard/
      JobBoard.tsx
      JobBoard.css
    JobCard/
      JobCard.tsx
      JobCard.css
    JobList/
      JobList.tsx
      JobList.css
    LoadMoreButton/
      LoadMoreButton.tsx
    Skeleton/
      Skeleton.tsx
      Skeleton.css
    ErrorState/
      ErrorState.tsx
  utils/
    time.ts              # relative time formatting
    stripHtml.ts          # sanitize job.text
  App.tsx
  main.tsx
  index.css               # global resets/variables
```

## 3. Types

 typescript

```typescript
// src/types/job.ts

export interface HNJobItem {
  id: number;
  type: 'job';
  title: string;
  url?: string;
  text?: string;
  by: string;
  time: number; // unix seconds
  score: number;
  deleted?: boolean;
  dead?: boolean;
}

// What we render — normalized, with a derived "domain" and safe description
export interface JobPost {
  id: number;
  title: string;
  url: string | null;
  domain: string | null;
  description: string | null;
  postedBy: string;
  postedAt: number;
}

export type FetchStatus = 'idle' | 'loading' | 'loading-more' | 'success' | 'error';
```

## 4. API Layer

 Keep raw fetch logic isolated so components never talk to `fetch` directly — makes testing and swapping data sources trivial later.

 typescript

```typescript
// src/api/hackernews.ts

const BASE_URL = 'https://hacker-news.firebaseio.com/v0';

export class HNApiError extends Error {
  public status?: number
  constructor(message: string, status: number) {
    super(message);
    this.name = 'HNApiError';
    this.status = 'status'
  }
}

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) {
    throw new HNApiError(`Request failed: ${res.statusText}`, res.status);
  }
  return res.json() as Promise<T>;
}

export function fetchJobStoryIds(): Promise<number[]> {
  return fetchJson<number[]>(`${BASE_URL}/jobstories.json`);
}

export function fetchItem(id: number): Promise<HNJobItem | null> {
  return fetchJson<HNJobItem | null>(`${BASE_URL}/item/${id}.json`);
}

// Fan out requests in controlled batches instead of Promise.all on 500 IDs at once
export async function fetchItemsBatched(
  ids: number[],
  batchSize = 20
): Promise<HNJobItem[]> {
  const results: HNJobItem[] = [];

  for (let i = 0; i < ids.length; i += batchSize) {
    const batch = ids.slice(i, i + batchSize);
    const items = await Promise.all(batch.map(fetchItem));
    for (const item of items) {
      if (item && !item.deleted && !item.dead) {
        results.push(item);
      }
    }
  }

  return results;
}
```

 Import from `types/job.ts` at the top — I omitted it above for brevity, add `import type { HNJobItem } from '../types/job';`.

 **Why batching matters:** `jobstories.json` can return 200+ IDs. Firing 200 simultaneous requests will get throttled by the browser (6 concurrent connections per origin in most browsers) and feels janky. Batching in groups of ~20 keeps things smooth and lets you show progressive results.

### 5. Normalizing Data

 typescript

```typescript
// src/utils/stripHtml.ts

// HN's `text` field contains raw HTML (mostly <p> and <a>).
// Strip tags for safe plain-text rendering without dangerouslySetInnerHTML.
export function stripHtml(html: string): string {
  const doc = new DOMParser().parseFromString(html, 'text/html');
  return doc.body.textContent?.trim() ?? '';
}
```

 typescript

```typescript
// src/utils/time.ts

export function timeAgo(unixSeconds: number): string {
  const seconds = Math.floor(Date.now() / 1000 - unixSeconds);
  const units: [number, string][] = [
    [31536000, 'year'],
    [2592000, 'month'],
    [86400, 'day'],
    [3600, 'hour'],
    [60, 'minute'],
  ];

  for (const [secondsInUnit, label] of units) {
    const value = Math.floor(seconds / secondsInUnit);
    if (value >= 1) return `${value} ${label}${value > 1 ? 's' : ''} ago`;
  }
  return 'just now';
}
```

 typescript

```typescript
// src/utils/normalizeJob.ts
import type { HNJobItem, JobPost } from '../types/job';
import { stripHtml } from './stripHtml';

export function normalizeJob(item: HNJobItem): JobPost {
  let domain: string | null = null;
  if (item.url) {
    try {
      domain = new URL(item.url).hostname.replace(/^www\./, '');
    } catch {
      domain = null;
    }
  }

  return {
    id: item.id,
    title: item.title,
    url: item.url ?? null,
    domain,
    description: item.text ? stripHtml(item.text) : null,
    postedBy: item.by,
    postedAt: item.time,
  };
}
```

 ### 6. Hooks — Pagination Strategy

 The clean approach: fetch the full ID list once (cheap — it's just numbers), then paginate by slicing IDs and fetching item details per page. This gives you real pagination without re-fetching the ID list.

 typescript

```typescript
// src/hooks/useJobBoard.ts
import { useState, useEffect, useCallback, useRef } from 'react';
import { fetchJobStoryIds, fetchItemsBatched, HNApiError } from '../api/hackernews';
import { normalizeJob } from '../utils/normalizeJob';
import type { JobPost, FetchStatus } from '../types/job';

const PAGE_SIZE = 20;

export function useJobBoard() {
  const [allIds, setAllIds] = useState<number[]>([]);
  const [jobs, setJobs] = useState<JobPost[]>([]);
  const [status, setStatus] = useState<FetchStatus>('idle');
  const [error, setError] = useState<string | null>(null);
  const cursorRef = useRef(0); // how many IDs we've consumed

  const loadInitialIds = useCallback(async () => {
    setStatus('loading');
    setError(null);
    try {
      const ids = await fetchJobStoryIds();
      setAllIds(ids);
      const firstPageIds = ids.slice(0, PAGE_SIZE);
      const items = await fetchItemsBatched(firstPageIds);
      setJobs(items.map(normalizeJob));
      cursorRef.current = PAGE_SIZE;
      setStatus('success');
    } catch (err) {
      setError(err instanceof HNApiError ? err.message : 'Something went wrong.');
      setStatus('error');
    }
  }, []);

  const loadMore = useCallback(async () => {
    if (status === 'loading-more') return;
    setStatus('loading-more');
    try {
      const nextIds = allIds.slice(cursorRef.current, cursorRef.current + PAGE_SIZE);
      const items = await fetchItemsBatched(nextIds);
      setJobs((prev) => [...prev, ...items.map(normalizeJob)]);
      cursorRef.current += PAGE_SIZE;
      setStatus('success');
    } catch (err) {
      setError(err instanceof HNApiError ? err.message : 'Failed to load more.');
      setStatus('error');
    }
  }, [allIds, status]);

  useEffect(() => {
    loadInitialIds();
  }, [loadInitialIds]);

  const hasMore = cursorRef.current < allIds.length;

  return { jobs, status, error, loadMore, hasMore, retry: loadInitialIds };
}
```

 This hook is the single source of truth for the board's data. Components stay dumb.

 ### 7. Components

 typescript

```typescript
// src/components/JobCard/JobCard.tsx
import type { JobPost } from '../../types/job';
import { timeAgo } from '../../utils/time';
import './JobCard.css';

interface JobCardProps {
  job: JobPost;
}

export function JobCard({ job }: JobCardProps) {
  const href = job.url ?? `https://news.ycombinator.com/item?id=${job.id}`;

  return (
    <article className="job-card">

        className="job-card__link"
        href={href}
        target="_blank"
        rel="noopener noreferrer"
      >
        <h3 className="job-card__title">{job.title}</h3>
      </a>

      {job.description && (
        <p className="job-card__description">
          {job.description.length > 180
            ? `${job.description.slice(0, 180)}…`
            : job.description}
        </p>
      )}

      <div className="job-card__meta">
        {job.domain && <span className="job-card__domain">{job.domain}</span>}
        <span className="job-card__dot" aria-hidden="true">·</span>
        <span className="job-card__time">{timeAgo(job.postedAt)}</span>
      </div>
    </article>
  );
}
```

 typescript

```typescript
// src/components/JobList/JobList.tsx
import type { JobPost } from '../../types/job';
import { JobCard } from '../JobCard/JobCard';
import { JobCardSkeleton } from '../Skeleton/Skeleton';
import './JobList.css';

interface JobListProps {
  jobs: JobPost[];
  isInitialLoading: boolean;
}

export function JobList({ jobs, isInitialLoading }: JobListProps) {
  if (isInitialLoading) {
    return (
      <div className="job-list">
        {Array.from({ length: 6 }).map((_, i) => (
          <JobCardSkeleton key={i} />
        ))}
      </div>
    );
  }

  if (jobs.length === 0) {
    return <p className="job-list__empty">No job postings found right now.</p>;
  }

  return (
    <div className="job-list">
      {jobs.map((job) => (
        <JobCard key={job.id} job={job} />
      ))}
    </div>
  );
}
```

 typescript

```typescript
// src/components/ErrorState/ErrorState.tsx
interface ErrorStateProps {
  message: string;
  onRetry: () => void;
}

export function ErrorState({ message, onRetry }: ErrorStateProps) {
  return (
    <div className="error-state">
      <p>{message}</p>
      <button onClick={onRetry}>Try again</button>
    </div>
  );
}
```

 typescript

```typescript
// src/components/Skeleton/Skeleton.tsx
import './Skeleton.css';

export function JobCardSkeleton() {
  return (
    <div className="skeleton-card" aria-hidden="true">
      <div className="skeleton-line skeleton-line--title" />
      <div className="skeleton-line skeleton-line--body" />
      <div className="skeleton-line skeleton-line--meta" />
    </div>
  );
}
```

 typescript

```typescript
// src/components/JobBoard/JobBoard.tsx
import { useJobBoard } from '../../hooks/useJobBoard';
import { JobList } from '../JobList/JobList';
import { ErrorState } from '../ErrorState/ErrorState';
import './JobBoard.css';

export function JobBoard() {
  const { jobs, status, error, loadMore, hasMore, retry } = useJobBoard();

  const isInitialLoading = status === 'loading' && jobs.length === 0;

  return (
    <div className="job-board">
      <header className="job-board__header">
        <h1>HN Job Board</h1>
        <p>Latest job postings from Hacker News</p>
      </header>

      {status === 'error' && jobs.length === 0 ? (
        <ErrorState message={error ?? 'Failed to load jobs.'} onRetry={retry} />
      ) : (
        <>
          <JobList jobs={jobs} isInitialLoading={isInitialLoading} />

          {hasMore && (
            <button
              className="job-board__load-more"
              onClick={loadMore}
              disabled={status === 'loading-more'}
            >
              {status === 'loading-more' ? 'Loading…' : 'Load more jobs'}
            </button>
          )}
        </>
      )}
    </div>
  );
}
```

 typescript

```typescript
// src/App.tsx
import { JobBoard } from './components/JobBoard/JobBoard';

function App() {
  return <JobBoard />;
}

export default App;
```

 ### 8. Vanilla CSS

 Global variables first — this keeps every component's CSS consistent without a framework:

 css

```css
/* src/index.css */
:root {
  --color-bg: #fafafa;
  --color-surface: #ffffff;
  --color-border: #e5e5e5;
  --color-text: #1a1a1a;
  --color-text-muted: #6b6b6b;
  --color-accent: #ff6600; /* HN orange */
  --color-accent-hover: #e55a00;
  --radius-sm: 6px;
  --radius-md: 10px;
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 16px;
  --space-4: 24px;
  --space-5: 32px;
  --font-sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  background: var(--color-bg);
  color: var(--color-text);
  font-family: var(--font-sans);
  -webkit-font-smoothing: antialiased;
}
```

 css

```css
/* src/components/JobBoard/JobBoard.css */
.job-board {
  max-width: 720px;
  margin: 0 auto;
  padding: var(--space-5) var(--space-3);
}

.job-board__header {
  margin-bottom: var(--space-4);
}

.job-board__header h1 {
  font-size: 1.75rem;
  margin: 0 0 var(--space-1);
}

.job-board__header p {
  color: var(--color-text-muted);
  margin: 0;
}

.job-board__load-more {
  display: block;
  width: 100%;
  margin-top: var(--space-4);
  padding: var(--space-3);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text);
  font-size: 0.95rem;
  cursor: pointer;
  transition: background 0.15s ease, border-color 0.15s ease;
}

.job-board__load-more:hover:not(:disabled) {
  background: #f5f5f5;
  border-color: #d0d0d0;
}

.job-board__load-more:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
```

 css

```css
/* src/components/JobList/JobList.css */
.job-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.job-list__empty {
  color: var(--color-text-muted);
  text-align: center;
  padding: var(--space-5) 0;
}
```

 css

```css
/* src/components/JobCard/JobCard.css */
.job-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: var(--space-3);
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.job-card:hover {
  border-color: #d0d0d0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.job-card__link {
  text-decoration: none;
  color: inherit;
}

.job-card__title {
  margin: 0 0 var(--space-2);
  font-size: 1.05rem;
  font-weight: 600;
  line-height: 1.4;
}

.job-card__link:hover .job-card__title {
  color: var(--color-accent);
}

.job-card__description {
  margin: 0 0 var(--space-2);
  color: var(--color-text-muted);
  font-size: 0.9rem;
  line-height: 1.5;
}

.job-card__meta {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  font-size: 0.8rem;
  color: #999;
}

.job-card__domain {
  color: var(--color-accent);
  font-weight: 500;
}
```

 css

```css
/* src/components/Skeleton/Skeleton.css */
.skeleton-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: var(--space-3);
}

.skeleton-line {
  background: linear-gradient(90deg, #eee 25%, #f5f5f5 50%, #eee 75%);
  background-size: 200% 100%;
  animation: shimmer 1.4s infinite;
  border-radius: var(--radius-sm);
  margin-bottom: var(--space-2);
}

.skeleton-line--title { height: 18px; width: 70%; }
.skeleton-line--body { height: 14px; width: 100%; }
.skeleton-line--meta { height: 12px; width: 40%; margin-bottom: 0; }

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

 css

```css
/* Error state — can live in a global file or its own module */
.error-state {
  text-align: center;
  padding: var(--space-5) 0;
  color: var(--color-text-muted);
}

.error-state button {
  margin-top: var(--space-2);
  padding: var(--space-2) var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  cursor: pointer;
}
```

 ### 9. Things Worth Knowing Before You Ship This

 **Rate limiting**: The HN Firebase API has no documented hard limit but is known to throttle abusive traffic. Batching at 15–20 concurrent requests per page is a safe, empirically-used pattern in the HN developer community.

 **Stale/deleted jobs**: Some IDs in `jobstories.json` resolve to `null` or items with `deleted: true`. The `fetchItemsBatched` filter above already strips these — don't skip that check or you'll render blank cards.

 **Caching**: Since `jobstories.json` doesn't change every second, consider caching it in `sessionStorage` with a short TTL (e.g., 5 minutes) to avoid re-fetching the same list on every mount during dev/testing.

 **Real infinite scroll instead of a button**: Swap the "Load more" button for an `IntersectionObserver` watching a sentinel `<div>` at the bottom of the list, calling `loadMore()` when it enters the viewport. Happy to write that variant if you want it.

 **Testing**: Since `api/hackernews.ts` is the only place touching `fetch`, mocking it in tests (Vitest + MSW) is straightforward — components and hooks never need to know about the network layer.