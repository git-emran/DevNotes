## Symptom

- User report (link, quote, or summary)
- How often does it happen? (always / sometimes / rarely)
- Related reports (github, forum, etc.)
- Timeline / flow of events leading up to the bug (if known)

## Environment

- Platform:
- Platform version:
- App version:

## Investigation

- What are the two (or more) operations that might be racing?
- Is something (DB, cache, config) being read before it's marked ready/loaded? What event or flag should it wait on instead (e.g. `onLocalDBLoad`, `cacheReady`)?
- Could messages/events (webhooks, IPC, sync) be arriving or processing out of order?
- Is there an `await`/`setTimeout`/async gap where state can change underneath you?
- Does it only reproduce on one machine/platform, or everywhere?
- Does adding an artificial delay, or disabling a feature/extension, change the frequency?
- Trace the actual sequence of events step by step — where do they interleave?

## Root Cause
Cause by what?:
Is it replicable?:
Issue in full details:

## Fix
