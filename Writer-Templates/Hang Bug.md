
## Report

- User report (link, quote, or summary)
- Related reports (github, forum, etc.)

## Symptom

- What's frozen (the whole app, one window, one interaction)?
- Does it recover on its own, or stay stuck until force-quit?
- Any error in the console/logs, even if it seems unrelated?

## Environment

- Platform:
- Platform version:
- App version:

## Investigation

- Can you capture a CPU profile or thread/stack sample while it's hung?
- Which specific interaction triggers it? Does it still hang with that interaction isolated?
- What have you ruled out so far, and why?
- Is there a synchronous/blocking call on the main thread (a large loop, heavy computation, a remote/IPC call)?
- Does it still happen with related features disabled one at a time?
- Could this be caused by a framework/library/runtime version — does upgrading (or pinning to a different version) change the behavior?
- Does attaching a profiler or debugger change whether it reproduces (a sign of a timing-sensitive Heisenbug)?
- Can you build a minimal, standalone reproduction outside the full app?
- Is something re-rendering or recomputing more than necessary (a missing memoization)?

## Root Cause

## Workaround

## Fix

- Confirmed with the reporter?
