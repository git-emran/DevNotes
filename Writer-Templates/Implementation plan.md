## Requirements

- What's being changed, and why?
- What's explicitly out of scope?
- Related notes or prior art (link them):

## Related notes

* * *

> # !Instructions
> 
> ## Planning Steps
> 
> 1. **Analyze the request** and restate requirements in clear terms
> 2. **Ground the plan** in relevant codebase patterns when the repo is available
> 3. **Break down into phases** with specific, actionable steps
> 4. **Identify dependencies** between components
> 5. **Assess risks** and potential blockers
> 6. **Estimate complexity** (High/Medium/Low)
> 


## Requirements Restatement

## Current State

- What does the code actually do today? (verify against source, don't assume)

```js filename="example.js" title="Current implementation" line=30
if (isMacOS()) {
  enableFeature()
} else {
  // not supported on this platform yet
}
```

## Decisions Needed

1. [ ] Where more than one reasonable approach exists: state your recommendation and why, then confirm before implementing.

## Implementation Phases

### Phase 1: 

### Phase 2: 

## Dependencies

- New libraries, APIs, or services this requires (or note if none):

## Risks

- **HIGH / MEDIUM / LOW — Risk description**: Risk details and mitigation plan.

## Estimated Complexity

- Per phase:
- Total:

## Status

- [ ] **Phase 1**: 
- [ ] **Phase 2**: 

## Outcome

> # !Example
>
> ## Requirements
>
> - The `import-markdown` plugin's UX is backwards — it opens a select-notebook dialog before the native file picker, then shows a separate progress dialog. Merge `select-book-dialog.tsx` + `progress-dialog.tsx` into one wizard-style dialog (native pick → scanning → stats → notebook → progress).
> - Out of scope: adding folder import support on Windows/Linux (Electron can't combine `openFile` + `openDirectory` there).
>
> ## Related notes
>
> (none — first design pass on this UX, not a follow-up to a prior bug/idea note)
>
> * * *
>
> ## Requirements Restatement
>
> Reorder the flow to pick files **first**, then walk the user through a single wizard-style `Dialog` with four in-place steps — Scanning → Stats → Select Notebook → Progress — replacing the two separate dialog components with one. The wizard opens immediately after the picker returns and shows live scan progress while the selection is measured.
>
> ## Current State
>
> The command shows the notebook-select dialog **first**, and only opens the native picker inside that dialog's callback — backwards from the desired flow. There are also two separate `useModal()` instances, with the progress dialog stacking on top of the still-open notebook dialog during scanning.
>
> ```tsx filename="src/index.tsx" line=28 title="Notebook is chosen BEFORE the native picker opens"
> const handleNotebookSelected = useCallback(
>   async (destBookId: string | null) => {
>     const { filePaths } = await openImportDialog({
>       isFolderOnly: destBookId === null
>     })
>     ...
> ```
>
> ## Decisions Needed
>
> 1. [x] **Cross-platform picker mode:** Electron can't combine `openFile` + `openDirectory` on Windows/Linux — only macOS supports both. Recommend keeping today's live behavior (macOS: files+folders; Win/Linux: files-only), since folder import on Win/Linux is already unreachable — zero regression. Confirmed before implementing.
> 2. [x] **Notebook step: confirm vs. auto-advance:** `NotebookListBar` has no controlled "selected" prop, so a row click can't stay visually highlighted. Recommend capture-then-confirm (row click stores the notebook, an Import button commits) over auto-advancing on click. Confirmed before implementing.
>
> ## Implementation Phases
>
> ### Phase 1: Merged wizard dialog component
>
> - **Files**: `src/import-wizard-dialog.tsx`, `styles/import-wizard-dialog.css`
> - **Action**: Build one `Dialog` with a `switch (step)` selecting content + actions for scanning/stats/notebook/progress (see the step union sketched below); merge the two old stylesheets under a new root class
>
> ```ts filename="src/import-wizard-dialog.tsx" line=1 title="Proposed step union for the merged wizard"
> type WizardStep = 'scanning' | 'stats' | 'notebook' | 'progress'
> // oversized-file errors render within 'stats'; importError renders within 'progress'
> // 'scanning' and 'progress' share one status-line renderer, parameterized by label (Decisions Needed #4)
> ```
>
> - **Why**: A single dialog instance is required for the wizard; scanning and progress share one status-line renderer to minimize new UI surface
> - **Verify**: Manually render each step in isolation and confirm its content and actions
>
> ### Phase 2: Reorder orchestration in index.tsx
>
> - **Files**: `src/index.tsx`
> - **Action**: Replace the two `useModal()` calls with one (see the state shape sketched below); add `step`/`filePaths`/`totalSize`/`selectedBookId` state; call `openImportDialog()` first, open the dialog immediately at `scanning`, then transition through `stats` → `notebook` → `progress`
>
> ```ts filename="src/index.tsx" line=21 title="Proposed state shape, replacing the two separate useModal() instances above"
> const wizardDialog = useModal()
> const [step, setStep] = useState<WizardStep>('scanning')
> const [filePaths, setFilePaths] = useState<string[]>([])
> const [totalSize, setTotalSize] = useState(0)
> const [selectedBookId, setSelectedBookId] = useState<string | null>(null)
> ```
>
> - **Why**: Implements "files first" — the wizard opens immediately and shows live scan progress
> - **Verify**: `npm run dev`, trigger the import command, confirm the dialog opens before scanning and advances through all four steps
> - **Dependencies**: Phase 1's wizard dialog component
> - **Risk**: Low
>
> ## Dependencies
>
> - None — reuses `Dialog` and `NotebookListBar` already exposed via `getEnv().components.classes`; no new npm packages
>
> ## Risks
>
> - **MEDIUM — Async scan may not paint**: Converting `checkSizeOfFiles` to async could still fail to paint if it doesn't yield to a real event-loop macrotask (a microtask-only yield wouldn't repaint). Mitigate with real async I/O (`await fsp.stat` / `await glob(...)`) so each item hits a macrotask boundary, and throttle progress updates (~50-100ms) to avoid render thrash.
>
> ## Estimated Complexity
>
> - Per phase: Phase 1 (Medium — new component + merged styles), Phase 2 (Low — state machine wiring)
> - Total: Medium — roughly a day including manual cross-platform picker checks and scan-progress verification
>
> ## Status
>
> - [x] **Phase 1**: Merged wizard dialog component — split into five files (one orchestrator + one component per step) instead of a single `switch`, per user request to reduce complexity
> - [ ] **Phase 2**: Reorder orchestration in index.tsx
>
> ## Outcome
>
> Completed. All phases shipped; `format`/`lint`/`typecheck`/`build` pass and the tree is clean. Notable deviations, all driven by user requests along the way: the wizard split into five files instead of one `switch`-based component, and the scan never gained live per-file progress — the user judged it fast enough without one after seeing it in practice.

