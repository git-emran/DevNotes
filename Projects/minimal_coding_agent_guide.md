# Production-Ready Minimal Coding Agent Guide (Verified)

 This is a corrected version of the original guide. Every code block below has been actually run (tool logic executed directly; API calls verified against the real `google-genai` SDK with a mocked network layer, since that's the only part that needs your API key). Five real bugs were fixed — see **What was fixed** at the bottom for the details if you're curious. The short version:

 - `python-dotenv` was installed but `load_dotenv()` was never called, so your `.env` file was silently ignored.
- Step 3 defined a function but never called it, and referenced `client` / `AGENT_TOOLS` that didn't exist in that snippet — running it as-is would `NameError`.
- The biggest one: passing raw Python functions as `tools=` turns on the SDK's **automatic function calling**, which silently executes your tools *inside* `send_message()` before your own loop ever sees them. That defeats the entire point of a hand-rolled ReAct loop with visible logs — it had to be explicitly disabled.
- `agent.py` defined `run_production_agent` but never called it — `python agent.py` did nothing.
- When the model requested more than one tool call in a turn, the loop sent each result back in a separate `send_message()` call instead of batching them into one message — the documented/correct pattern batches them.

 Each step below is now a **complete, standalone file** you can save and run on its own to see it work, rather than a fragment.

 ---

 ## Workspace & Project Setup

 ### Directory Structure

 ```text
minimal-agent/
│
├── workspace/                  # 🔒 Sandboxed directory (agent files live here)
│   └── .gitkeep
│
├── .env                        # Environment variables (API Key)
├── tools.py                    # The 4 sandboxed file tools (shared by every step)
├── step1_hello.py              # Step 1 — connectivity check
├── step3_single_step.py        # Step 3 — one tool-call round trip
├── agent.py                    # Step 4 — full multi-step ReAct loop
├── app.py                      # Step 5 — Gradio web UI
├── requirements.txt
└── README.md
```

 ### Installation & Prerequisites

 ```bash
# 1. Create and activate a virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 2. Create requirements.txt
cat <<EOT > requirements.txt
google-genai
gradio
python-dotenv
EOT

# 3. Install dependencies
pip install -r requirements.txt
```

 Set up your `.env` file with a free key from [Google AI Studio](https://aistudio.google.com/):

 ```env
GEMINI_API_KEY=your_free_gemini_api_key_here
```

 > **A note on the model name.** This guide pins `gemini-2.5-flash`, which is confirmed free-tier-eligible and correct as of writing. Google has announced the Gemini 2.5 line (including `gemini-2.5-flash`) is scheduled to shut down **October 16, 2026**, so if you're reading this after that date, swap the model name in `tools.py`'s sibling files for whatever is current — check [ai.google.dev/gemini-api/docs/models](https://ai.google.dev/gemini-api/docs/models). The alias `gemini-flash-latest` always points at Google's current default Flash model if you'd rather not track version numbers, at the cost of Google being able to change model behavior under you without notice beyond a 2-week email.

 ---

 ## Architecture Overview

 ```
 ┌─────────────────────────────────────────────────────────┐
 │                  Gradio UI (app.py)                     │
 └────────────────────────────┬────────────────────────────┘
                              │ User Prompt / Logs
                              ▼
 ┌─────────────────────────────────────────────────────────┐
 │               ReAct Loop Manager (agent.py)             │
 └──────┬──────────────────────────────────────────▲───────┘
        │ Tool Calls                               │ Tool Results
        ▼                                          │
 ┌──────────────┐     Sandboxed Execution    ┌─────┴───────┐
 │ Gemini API   │ ─────────────────────────► │  workspace/ │
 └──────────────┘                            └─────────────┘
```

 ---

 ## Step 1: Base Connectivity Check (`step1_hello.py`)

 Verifies your API key works and that the SDK is wired up correctly, before anything else. `load_dotenv()` is what actually reads your `.env` file — it was missing from the original guide despite `python-dotenv` being installed.

 ```python
import os
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()  # reads GEMINI_API_KEY from your .env file

def run_hello_agent(prompt: str):
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise ValueError("GEMINI_API_KEY is not set. Add it to your .env file.")
    client = genai.Client(api_key=key)  # created inside the function, not at import time

    system_instruction = "You are a minimal file operations agent. Focus on precise file tasks."

    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.0  # 💡 deterministic tool execution
        )
    )
    print("Agent Response:", response.text)

if __name__ == "__main__":
    run_hello_agent("Say hello and state your capability.")
```

 **Run it:** `python step1_hello.py` → you should see a one-line greeting printed to the terminal.

 > **Why the client moved inside the function:** the original guide built the `genai.Client(...)` at module import time. If `GEMINI_API_KEY` isn't set yet, that crashes with a raw SDK stack trace the instant you import the file — before your own error handling ever runs. Building it lazily, inside the function, with an explicit check first, gives a readable error instead and lets other files safely `import` this module without a key present.

 ---

 ## Step 2: Sandboxed File Tools (`tools.py`)

 This is now its own importable module — every later step (`step3`, `agent.py`, `app.py`) imports from it instead of redefining the same four functions. `_get_safe_path` guards against directory traversal attacks (e.g. `../../etc/passwd`).

 ```python
"""Sandboxed file tools the agent is allowed to use."""
import os

WORKSPACE_DIR = os.path.abspath("./workspace")
os.makedirs(WORKSPACE_DIR, exist_ok=True)

def _get_safe_path(rel_path: str) -> str:
    """Ensure the agent cannot escape the workspace directory (path traversal protection)."""
    safe_base = os.path.abspath(WORKSPACE_DIR)
    target_path = os.path.abspath(os.path.join(safe_base, rel_path))
    if not target_path.startswith(safe_base):
        raise PermissionError(f"Access denied: '{rel_path}' is outside workspace.")
    return target_path

def create_file(path: str, content: str = "") -> str:
    """Creates a new file with optional content."""
    full_path = _get_safe_path(path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content)
    return f"File created successfully at: {path}"

def read_file(path: str) -> str:
    """Reads the contents of an existing file."""
    full_path = _get_safe_path(path)
    if not os.path.exists(full_path):
        return f"Error: File '{path}' does not exist."
    with open(full_path, "r", encoding="utf-8") as f:
        return f.read()

def write_file(path: str, content: str) -> str:
    """Overwrites or updates content in an existing file."""
    full_path = _get_safe_path(path)
    if not os.path.exists(full_path):
        return f"Error: File '{path}' does not exist. Use create_file first."
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content)
    return f"File '{path}' updated successfully."

def delete_file(path: str) -> str:
    """Deletes a specified file."""
    full_path = _get_safe_path(path)
    if not os.path.exists(full_path):
        return f"Error: File '{path}' does not exist."
    os.remove(full_path)
    return f"File '{path}' deleted successfully."

TOOL_MAP = {
    "create_file": create_file,
    "read_file": read_file,
    "write_file": write_file,
    "delete_file": delete_file,
}
AGENT_TOOLS = [create_file, read_file, write_file, delete_file]

if __name__ == "__main__":
    # Quick self-test so you can run `python tools.py` and see every
    # tool actually work — no API key needed for this step.
    print(create_file("demo.txt", "first draft"))
    print("Contents:", read_file("demo.txt"))
    print(write_file("demo.txt", "revised draft"))
    print("Contents after write:", read_file("demo.txt"))
    print(delete_file("demo.txt"))
    print("Read after delete:", read_file("demo.txt"))
    try:
        _get_safe_path("../outside.txt")
    except PermissionError as e:
        print("Path traversal correctly blocked:", e)
```

 **Run it:** `python tools.py` → prints the result of each tool call in sequence, including the traversal guard rejecting a `../` path. This is the part of the guide that needs no API key at all, so it's a good first sanity check that your workspace/permissions are set up right.

 > **The original guide's Step 2 only defined these functions and never called any of them** — there was nothing to run to confirm they worked. The `__main__` block above is new.

 ---

 ## Step 3: One Tool-Call Round Trip (`step3_single_step.py`)

 Before building the full multi-step loop, this step shows a single request → tool call → tool result → follow-up response cycle, so you can see each part of the mechanism in isolation.

 ```python
import os
from dotenv import load_dotenv
from google import genai
from google.genai import types
from tools import AGENT_TOOLS, TOOL_MAP

load_dotenv()

def run_agent_single_step(prompt: str, api_key: str = None):
    key = api_key or os.environ.get("GEMINI_API_KEY")
    if not key:
        raise ValueError("GEMINI_API_KEY is not set. Add it to your .env file or pass api_key explicitly.")
    client = genai.Client(api_key=key)

    chat = client.chats.create(
        model="gemini-2.5-flash",
        config=types.GenerateContentConfig(
            tools=AGENT_TOOLS,
            temperature=0.0,
            # Passing raw Python functions as `tools` turns on automatic
            # function calling by default — the SDK would run the tool
            # itself, inside send_message(), and we'd never see the
            # intermediate call below. This turns that off so *we* control
            # execution.
            automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
        ),
    )

    response = chat.send_message(prompt)

    if not response.function_calls:
        print("Agent response (no tool needed):", response.text)
        return

    call = response.function_calls[0]
    print(f"Agent requested tool call: {call.name}({dict(call.args)})")

    result = TOOL_MAP[call.name](**dict(call.args))
    print("Tool result:", result)

    follow_up = chat.send_message(
        [types.Part.from_function_response(name=call.name, response={"result": result})]
    )
    print("Agent's final response:", follow_up.text)

if __name__ == "__main__":
    run_agent_single_step("Create a file named notes.txt containing 'first note'.")
```

 **Run it:** `python step3_single_step.py` → prints the tool the model asked for, the tool's result, and the model's closing summary — then check `workspace/notes.txt` actually exists with that content.

 > **The original guide's Step 3 snippet would not run at all.** It referenced `client`, `types`, and `AGENT_TOOLS`, none of which existed in that code block, and it defined `run_agent_single_step` but never called it. This version is self-contained and ends with an actual call.

 ---

 ## Step 4: Multi-Turn ReAct Execution Loop (`agent.py`)

 The full loop: reason → call tool(s) → feed results back → repeat until the model stops requesting tools. Save this as `agent.py`.

 ```python
import os
from dotenv import load_dotenv
from google import genai
from google.genai import types
from tools import AGENT_TOOLS, TOOL_MAP, WORKSPACE_DIR

load_dotenv()

MODEL_NAME = "gemini-2.5-flash"

def run_production_agent(user_prompt: str, api_key: str = None, max_iterations: int = 10):
    """Executes multi-step reasoning and action loops until completion."""
    key = api_key or os.environ.get("GEMINI_API_KEY")
    if not key:
        raise ValueError("GEMINI_API_KEY is not set. Add it to your .env file or pass api_key explicitly.")
    client = genai.Client(api_key=key)

    system_instruction = """
    You are an autonomous file management agent operating in a sandboxed directory.
    You have access to 4 tools: create_file, read_file, write_file, delete_file.

    Rules:
    1. Read existing files before editing them when performing updates.
    2. Execute one clear action at a time.
    3. Conclude with a clear text summary when all tasks are complete.
    """

    chat = client.chats.create(
        model=MODEL_NAME,
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            tools=AGENT_TOOLS,
            temperature=0.0,
            automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
        ),
    )

    response = chat.send_message(user_prompt)

    for iteration in range(max_iterations):
        if not response.function_calls:
            return response.text

        print(f"--- Iteration {iteration + 1} ---")
        response_parts = []
        for call in response.function_calls:
            tool_name = call.name
            tool_args = dict(call.args)
            print(f"  -> {tool_name}({tool_args})")

            if tool_name in TOOL_MAP:
                try:
                    result = TOOL_MAP[tool_name](**tool_args)
                except Exception as e:
                    result = f"Execution Error: {str(e)}"
            else:
                result = f"Error: Tool '{tool_name}' does not exist."

            print(f"  <- {result}")
            response_parts.append(
                types.Part.from_function_response(name=tool_name, response={"result": result})
            )

        # All tool results from this turn are sent back together, in one
        # message — the model expects one response per call it made in
        # that turn, delivered together.
        response = chat.send_message(response_parts)

    return "Task timed out or exceeded maximum steps."

if __name__ == "__main__":
    result = run_production_agent(
        "Create a file named hello.txt containing 'Hello from the agent!', "
        "then read it back to confirm its contents."
    )
    print("\n=== FINAL AGENT OUTPUT ===")
    print(result)
```

 **Run it:** `python agent.py` → prints each iteration's tool call and result as it happens, then the model's final summary. Check `workspace/hello.txt` afterward.

 > **Two fixes here vs. the original:** (1) the original `agent.py` defined `run_production_agent` but never called it anywhere in the file, so `python agent.py` produced no output at all — the `if __name__ == "__main__":` block above is new. (2) When a turn contains more than one tool call, the original sent each result back in its own separate `chat.send_message()` call inside the loop; that only reliably works for single-call turns. This version collects every result from a turn into one list and sends them together in a single message, which is the documented pattern and is what was verified to actually work end-to-end (tested with a mocked two-tool-call turn — file created and read correctly, final text returned).

 ---

 ## Step 5: Adding the Web UI Layer (`app.py`)

 Save this file as `app.py`. It streams the same per-step logs into a Gradio UI, alongside a live workspace file explorer.

 ```python
import os
import gradio as gr
from google import genai
from google.genai import types
from agent import AGENT_TOOLS, TOOL_MAP, WORKSPACE_DIR, MODEL_NAME

def get_workspace_files():
    file_list = []
    for root, _, files in os.walk(WORKSPACE_DIR):
        for file in files:
            rel_path = os.path.relpath(os.path.join(root, file), WORKSPACE_DIR)
            file_list.append(rel_path)
    return file_list if file_list else ["(Workspace is empty)"]

def execute_agent_task(user_prompt: str, api_key: str):
    key = api_key or os.environ.get("GEMINI_API_KEY")
    if not key:
        yield "Error: Gemini API key is required.", "\n".join(get_workspace_files())
        return

    client = genai.Client(api_key=key)
    logs = [f"Starting task: '{user_prompt}'"]
    yield "\n".join(logs), "\n".join(get_workspace_files())

    system_instruction = """
    You are an autonomous minimal coding agent.
    You manage files in a safe workspace using tools: create_file, read_file, write_file, delete_file.
    Always read existing content before updating files. Provide clear summaries when done.
    """

    try:
        chat = client.chats.create(
            model=MODEL_NAME,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                tools=AGENT_TOOLS,
                temperature=0.0,
                automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
            ),
        )

        response = chat.send_message(user_prompt)

        for step in range(10):
            if not response.function_calls:
                logs.append(f"\nTask complete:\n{response.text}")
                yield "\n".join(logs), "\n".join(get_workspace_files())
                return

            response_parts = []
            for call in response.function_calls:
                t_name = call.name
                t_args = dict(call.args)
                logs.append(f"\n[Step {step + 1}] Executing `{t_name}` with args: {t_args}")
                yield "\n".join(logs), "\n".join(get_workspace_files())

                if t_name in TOOL_MAP:
                    try:
                        res = TOOL_MAP[t_name](**t_args)
                    except Exception as err:
                        res = f"Execution Error: {str(err)}"
                else:
                    res = f"Error: Unknown tool '{t_name}'"

                logs.append(f"Result: {res}")
                yield "\n".join(logs), "\n".join(get_workspace_files())

                response_parts.append(
                    types.Part.from_function_response(name=t_name, response={"result": res})
                )

            response = chat.send_message(response_parts)

        logs.append("\nMax iteration steps reached.")
        yield "\n".join(logs), "\n".join(get_workspace_files())

    except Exception as e:
        logs.append(f"\nError: {str(e)}")
        yield "\n".join(logs), "\n".join(get_workspace_files())

# Gradio Web UI Layout
with gr.Blocks(title="Minimal Coding Agent") as demo:
    gr.Markdown("# Minimal Production Coding Agent")
    gr.Markdown("A free, sandboxed agent capable of creating, reading, writing, and deleting workspace files.")

    with gr.Row():
        with gr.Column(scale=2):
            api_key_input = gr.Textbox(
                label="Gemini API Key",
                placeholder="Paste key (or rely on GEMINI_API_KEY env var)",
                type="password",
                value=os.environ.get("GEMINI_API_KEY", "")
            )
            prompt_input = gr.Textbox(
                label="Task Prompt",
                placeholder="e.g. Create a script main.py that prints Hello World, then read it.",
                lines=3
            )
            submit_btn = gr.Button("Run Agent", variant="primary")

        with gr.Column(scale=1):
            workspace_box = gr.Textbox(
                label="Workspace File Explorer",
                value="\n".join(get_workspace_files()),
                lines=8,
                interactive=False
            )
            refresh_btn = gr.Button("Refresh Workspace View")

    logs_box = gr.Textbox(label="Agent Execution Logs", lines=15, interactive=False)

    submit_btn.click(
        fn=execute_agent_task,
        inputs=[prompt_input, api_key_input],
        outputs=[logs_box, workspace_box]
    )

    refresh_btn.click(
        fn=lambda: "\n".join(get_workspace_files()),
        outputs=workspace_box
    )

if __name__ == "__main__":
    demo.launch()
```

 **Run it:**

 ```bash
python app.py
```

 Then open `http://localhost:7860`. Type a task, hit **Run Agent**, and watch the log box fill in step by step while the file explorer panel updates.

 > **Fix here:** same automatic-function-calling and result-batching issues as `agent.py`, since this file duplicates that loop for the UI. It now imports `MODEL_NAME` from `agent.py` too, so the model name only needs to be changed in one place.

 ---

 ## Production Checklist & Best Practices

 1. **Load your `.env` file.** Installing `python-dotenv` doesn't do anything by itself — call `load_dotenv()` before reading `os.environ`, once per entrypoint file.
2. **Disable automatic function calling when you're hand-rolling the loop.** If you pass raw Python functions as `tools=` to the SDK, it will execute them itself by default. Set `automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True)` in `GenerateContentConfig` any time you want to see, log, or gate each tool call yourself.
3. **Batch multi-call turns into one message.** If a turn produces more than one `function_call`, collect all the corresponding `Part.from_function_response(...)` results into a single list and send them together in one `chat.send_message([...])` call.
4. **Build clients lazily, inside functions.** Constructing `genai.Client()` at module import time means a missing API key crashes on `import`, before your own error handling runs. Check for the key and construct the client inside the function that needs it.
5. **Path Traversal Protection:** Always sanitize inputs with `os.path.abspath` and verify containment inside your target directory.
6. **Deterministic Outputs:** Keep temperature at `0.0` to avoid unpredictable formatting in tool arguments.
7. **Graceful Error Recovery:** Catch tool execution errors and report them directly to the model as strings. LLMs are proficient at adjusting their actions upon seeing error output.
8. **Zero API Cost (for now):** Gemini 2.5 Flash's free tier keeps this free to build and run — but see the model-name note near the top of this guide about its October 2026 shutdown.

 ---

 ## What was fixed (summary)

 All five items below were confirmed against the real `google-genai` SDK (installed and introspected) and, for the parts that don't need a live API call, actually executed:

 | # | Issue in the original | Where | Fix |
| --- | --- | --- | --- |
| 1 | `python-dotenv`installed but`load_dotenv()`never called | throughout | added`load_dotenv()`to every entrypoint file |
| 2 | Step 2 defined tools but never ran any of them | Step 2 | added a`__main__`self-test block; ran it — works |
| 3 | Step 3 referenced undefined`client`/`AGENT_TOOLS`/`types`and never called its own function | Step 3 | rewrote as a self-contained, runnable file |
| 4 | Raw-function`tools=`silently enables automatic function calling, bypassing the hand-written loop entirely | Steps 3, 4, 5 | explicitly set`automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True)` |
| 5 | `agent.py`defined`run_production_agent`but never called it (`python agent.py`did nothing) | Step 4 | added`__main__`block that calls it and prints the result |
| 6 | Multi-call turns sent one`send_message()`per tool result instead of batching | Steps 4, 5 | collect all`Part.from_function_response(...)`into one list, send once per turn — verified with a mocked two-call turn |
| 7 | `genai.Client()`built at module import time crashes the whole file on missing key | Steps 1, 3 | moved client construction inside the function, behind an explicit key check |

 Everything that doesn't require a live network call (the four file tools, the loop's control flow and batching, the traversal guard) was actually executed during this review, not just read — including a mocked two-tool-call turn that confirmed the batching fix produces a real file and a correct final response.