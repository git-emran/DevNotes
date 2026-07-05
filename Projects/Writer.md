
## Bottom Line

**Not quite production-ready, but the core is genuinely good.** The feature depth is impressive — autosave queuing, compartment reconfiguration, scroll sync, the HTML→Markdown clipboard pipeline — these are all done thoughtfully. There are no catastrophic flaws.

Here's what's actually holding it back:

---

### 🔴 Real Bugs (fix these)

~~**1. `SectionWrapper` is defined inline inside `MarkdownPreview`** This is the most impactful bug. It's a stateful component created as a new function on every render, so React unmounts and remounts it on every debounced preview update (every 300ms of typing). The collapse state resets on each keystroke. It needs to be lifted out of the component body.~~

~~**2. `generateId` duplicates aren't handled** Two `## Overview` headings get the same DOM ID. The TOC scroll-to-heading silently targets the wrong one.~~

---

### 🟠 Structural Issues

**![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/react-ts.svg)

MarkdownEditor.tsx is a 1,554-line God Component.** It mixes the editor lifecycle, AI generation (with file tree traversal), PDF export, drag-resize, FAB timer, scroll sync, and note metadata — all in one component with 30+ state variables. This makes it effectively untestable and risky to refactor. The fix is splitting into custom hooks (`useEditorLifecycle`, `useAiGeneration`, `useSplitViewSync`).

---

### 🟡 Minor Issues

- No error boundary around ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/react-ts.svg)

  MarkdownPreview.tsx — a bad mermaid diagram or malformed rehype AST will white-screen the panel
- The `aiProgress` bar is a fake asymptotic animation that stalls at 92% for long requests
- Two `eslint-disable react-hooks/exhaustive-deps` comments on effects that have real missing deps
- Heavy `any` usage in the preview component where `hast` types exist

---

### Priority Order

1. Fix `SectionWrapper` inline definition (behavior bug)
2. Fix duplicate heading IDs in `generateId`
3. Add an error boundary
4. Split the God Component into hooks