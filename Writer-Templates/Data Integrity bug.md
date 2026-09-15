## Report

- User report (link, quote, or summary)
- Related reports (github, forum, etc.)

## Symptom

- What field/data is wrong, missing, or stale?
- Does it happen every time, or only for certain records/paths?

## Investigation

- Are there multiple code paths that write (or derive) this same field? Do they agree on its representation?
- Is a `null`/`undefined`/empty-string distinction being conflated or compared with strict equality (`===`)?
- Is this field computed/derived — does every save path recompute it, or does one path skip it?
- Does this run in more than one process/environment (e.g. renderer vs. main, client vs. server)? Do they all behave the same way?
- Can you find existing records with the wrong data and identify what they have in common?

## Root Cause

## Fix

## Data Migration

- Do existing records need a one-time fix/backfill?

> # !Example
>
> ## Report
>
> (internal finding — no external report; found while reviewing the local HTTP server's note-save path)
>
> ## Symptom
>
> `numOfTasks`/`numOfCheckedTasks` are wrong (stuck at whatever the API client sent, often `0`) for notes saved through the local HTTP server (main process) — but correct for notes saved through the editor (renderer). Happens every time for that one path, never for the other.
>
> ## Investigation
>
> `ModelNote` is a shared model saved from both the renderer (editor/Redux flow) and the main process (`local-http-server.ts`). Task counting depends on `countNumberOfTasks`, a renderer-only util that needs `global.inkdrop`/`markdownRenderer` — so `Note.save()` only recomputes counts when running in the renderer:
>
> ```ts title="src/shared/models/note.ts"
> async save() {
>   // recomputes numOfTasks/numOfCheckedTasks only when global.BROWSER is true
>   // -> main-process (local-http-server) saves skip this
> }
> ```
>
> ## Root Cause
>
> The task-count recompute in `Note.save()` was gated on `global.BROWSER`, because its only counter implementation depended on renderer-only globals. The main-process save path (local HTTP server) skipped the recompute entirely, leaving stale/default counts.
>
> ## Fix
>
> Made the counter process-agnostic (parses with `mdast-util-from-markdown` + GFM, no DOM/renderer dependency) and called it unconditionally from `Note.save()`:
>
> ```ts title="src/shared/models/note.ts"
> const { numOfTasks, numOfCheckedTasks } = countNumberOfTasks(this.body)
> this.numOfTasks = numOfTasks
> this.numOfCheckedTasks = numOfCheckedTasks
> ```
>
> ## Data Migration
>
> No backfill needed — existing notes get correct counts the next time they're saved from either process; nothing was corrupted downstream, just displayed stale until the next save.
