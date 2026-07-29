# Findings

- `navigator.clipboard.writeText()` copies the text to the clipboard from the web.
- 


## Improvements

The input field doesn't clear immediately when pressing Enter because **`setInput("")` is called inside `mutationFn`**, which only runs *after* the network request succeeds (or during the async execution of the mutation), rather than synchronously when the key event triggers.

Here is the flow currently happening:

1. You press Enter $\rightarrow$ `onKeyDown` fires $\rightarrow$ calls `sendMessage({ text: input })`.
2. `useMutation` triggers `mutationFn`.
3. JavaScript waits for `client.messages.post(...)` to complete.
4. Finally, `setInput("")` runs inside `mutationFn` after the network roundtrip.

Additionally, the **SEND** button has an issue where it attempts to send `input` even when `input.trim()` is empty (unlike your `onKeyDown` handler which checks `input.trim()`).

### The Fix

Move the state reset (`setInput("")`) into an **`onMutate`** callback (for optimistic state updates) or clear it synchronously in the event handlers before firing the mutation.

Here is the updated code snippet with the fixes applied:

TypeScript

```
// 1. Update the mutation definition:
const { mutate: sendMessage, isPending } = useMutation({
  mutationFn: async ({ text }: { text: string }) => {
    await client.messages.post({ sender: username, text }, { query: { roomId } })
  },
})

const handleSend = () => {
  const trimmed = input.trim()
  if (!trimmed || isPending) return

  const messageText = trimmed
  setInput("") // Clear immediately in UI thread
  sendMessage({ text: messageText })
  inputRef.current?.focus()
}
```

And update your JSX to use `handleSend`:

TypeScript

```
<input
  ref={inputRef} // Don't forget to attach the ref here!
  autoFocus
  type="text"
  value={input}
  onKeyDown={(e) => {
    if (e.key === "Enter") {
      e.preventDefault()
      handleSend()
    }
  }}
  placeholder="Type message..."
  onChange={(e) => setInput(e.target.value)}
  className="w-full bg-black border focus:border-zinc-700 focus:outline-none transition-colors placeholder:text-zinc-700 py-3 pl-8 pr-4 text-sm"
/>

<button
  onClick={handleSend}
  disabled={!input.trim() || isPending}
  className="bg-zinc-800 text-zinc-400 px-6 text-sm font-bold hover:text-zinc-200 transition-all disabled:opacity-50 cursor-pointer disabled:cursor-not-allowed"
>
  SEND
</button>
```

### Key Improvements Made:

- **Immediate Feedback:** `setInput("")` executes synchronously on keypress/click so the UI clears instantly without waiting on the network latency.
- **Attached `inputRef`:** Attached `ref={inputRef}` to your `<input>` element (it was missing from the jsx tag in your snippet).
- **Prevent Default:** Added `e.preventDefault()` on `Enter` to prevent unintended form submissions or caret jumps.
- **DRY Logic:** Consolidated input validation and execution into a single helper (`handleSend`).