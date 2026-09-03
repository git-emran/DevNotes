# Production-Ready Minimal Coding Agent Guide

This guide walks you through building an autonomous, production-ready, minimal coding agent completely for free. The agent operates within a sandboxed file system and is capable of four core file operations: creating, reading, writing, and deleting files.

We use **Python** and the **`google-genai`** SDK targeting the **Gemini 2.5 Flash** model (which offers a robust free tier). Finally, we implement a lightweight web UI using **Gradio**.

---

## Workspace & Project Setup

### Directory Structure

To keep the project clean, secure, and production-ready, structure your repository as follows:

```text
minimal-agent/
│
├── workspace/                  # 🔒 Sandboxed directory (agent files live here)
│   └── .gitkeep                # Keeps directory in source control
│
├── .env                        # Environment variables (API Key)
├── agent.py                    # Standalone Agent Core & ReAct Loop
├── app.py                      # Production Gradio Web UI App
├── requirements.txt            # Project Dependencies
└── README.md                   # Setup & Documentation
```

### Installation & Prerequisites

Create a virtual environment and install the required free libraries:

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

## Step 1: Base ReAct Loop (Hello World)

In this initial step, we set up our connection to the Gemini API and execute a simple call to verify credentials and frame the agent's identity using system instructions.

```python
import os
from google import genai
from google.genai import types

# 💡 TIP: Gemini 2.5 Flash offers a generous free tier for development.
# Obtain a free key at https://aistudio.google.com/
client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))

def run_hello_agent(prompt: str):
    # System instructions frame the agent's persona and strict operational boundaries
    system_instruction = "You are a minimal file operations agent. Focus on precise file tasks."
    
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.0  # 💡 TIP: Set temperature to 0.0 for deterministic tool execution
        )
    )
    print("Agent Response:", response.text)

if __name__ == "__main__":
    run_hello_agent("Say hello and state your capability.")
```

> **Key takeaway:** Always set `temperature=0.0` when building tool-using agents to minimize hallucinated parameters or unexpected reasoning branches.

---

## Step 2: Defining Sandboxed File Tools

Security is vital for agents with local system access. We implement a sandboxed path resolver `_get_safe_path` that guards against Directory Traversal attacks (e.g., `../../etc/passwd`).

```python
import os

# Define a sandboxed workspace directory for safety
WORKSPACE_DIR = os.path.abspath("./workspace")
os.makedirs(WORKSPACE_DIR, exist_ok=True)

def _get_safe_path(rel_path: str) -> str:
    """Ensure the agent cannot escape the target workspace directory (Path Traversal Protection)."""
    safe_base = os.path.abspath(WORKSPACE_DIR)
    target_path = os.path.abspath(os.path.join(safe_base, rel_path))
    
    # 💡 TIP: Always validate that the target path starts with the workspace root
    if not target_path.startswith(safe_base):
        raise PermissionError(f"Access denied: '{rel_path}' is outside workspace.")
    return target_path

# --- AGENT TOOLS ---

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

# Map tool names to functions for dynamic invocation
TOOL_MAP = {
    "create_file": create_file,
    "read_file": read_file,
    "write_file": write_file,
    "delete_file": delete_file
}
```

> **Key takeaway:** Docstrings on your tool functions double as tool descriptions for the LLM. Keep them clear and concise.

---

## Step 3: Binding Tools to the Agent

We connect our standard Python functions to Gemini's native function calling interface via `GenerateContentConfig`.

```python
# NEW: Build list of executable tools directly from functions
AGENT_TOOLS = [create_file, read_file, write_file, delete_file]

def run_agent_single_step(prompt: str):
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
        config=types.GenerateContentConfig(
            # NEW: Pass functions into tools array
            tools=AGENT_TOOLS,
            temperature=0.0
        )
    )
    
    # NEW: Check if the model requested a function call
    if response.function_calls:
        for call in response.function_calls:
            print(f"Agent requested tool call: {call.name}({call.args})")
    else:
        print("Agent response:", response.text)
```

---

## Step 4: Multi-Turn ReAct Execution Loop (`agent.py`)

A true production agent runs in a continuous loop: reasoning about the step, invoking tools, capturing outputs, and feeding those back into conversation memory until completion. Save this file as `agent.py`.

```python
import os
from google import genai
from google.genai import types

WORKSPACE_DIR = os.path.abspath("./workspace")
os.makedirs(WORKSPACE_DIR, exist_ok=True)

def _get_safe_path(rel_path: str) -> str:
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
    return f"File created: {path}"

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
    return f"File '{path}' updated."

def delete_file(path: str) -> str:
    """Deletes a specified file."""
    full_path = _get_safe_path(path)
    if not os.path.exists(full_path):
        return f"Error: File '{path}' does not exist."
    os.remove(full_path)
    return f"File '{path}' deleted."

TOOL_MAP = {
    "create_file": create_file,
    "read_file": read_file,
    "write_file": write_file,
    "delete_file": delete_file
}
AGENT_TOOLS = [create_file, read_file, write_file, delete_file]

def run_production_agent(user_prompt: str, api_key: str = None, max_iterations: int = 10):
    """Executes multi-step reasoning and action loops until completion."""
    key = api_key or os.environ.get("GEMINI_API_KEY")
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
        model="gemini-2.5-flash",
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            tools=AGENT_TOOLS,
            temperature=0.0
        )
    )

    response = chat.send_message(user_prompt)

    for iteration in range(max_iterations):
        if not response.function_calls:
            return response.text

        for call in response.function_calls:
            tool_name = call.name
            tool_args = call.args
            
            if tool_name in TOOL_MAP:
                try:
                    result = TOOL_MAP[tool_name](**tool_args)
                except Exception as e:
                    result = f"Execution Error: {str(e)}"
            else:
                result = f"Error: Tool '{tool_name}' non-existent."

            response = chat.send_message(
                types.Part.from_function_response(
                    name=tool_name,
                    response={"result": result}
                )
            )

    return "Task timed out or exceeded maximum steps."
```

---

## Step 5: Adding the Web UI Layer (`app.py`)

Save this file as `app.py`. It integrates with `agent.py`, adding live streaming logs and an interactive file workspace explorer.

```python
import os
import gradio as gr
from google import genai
from google.genai import types
from agent import AGENT_TOOLS, TOOL_MAP, WORKSPACE_DIR

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
    logs = [f"🚀 Starting task: '{user_prompt}'"]
    yield "\n".join(logs), "\n".join(get_workspace_files())

    system_instruction = """
    You are an autonomous minimal coding agent.
    You manage files in a safe workspace using tools: create_file, read_file, write_file, delete_file.
    Always read existing content before updating files. Provide clear summaries when done.
    """

    try:
        chat = client.chats.create(
            model="gemini-2.5-flash",
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                tools=AGENT_TOOLS,
                temperature=0.0
            )
        )

        response = chat.send_message(user_prompt)

        for step in range(10):
            if not response.function_calls:
                logs.append(f"\n✅ Task Complete:\n{response.text}")
                yield "\n".join(logs), "\n".join(get_workspace_files())
                return

            for call in response.function_calls:
                t_name = call.name
                t_args = call.args
                logs.append(f"\n⚙️ [Step {step+1}] Executing `{t_name}` with args: {t_args}")
                yield "\n".join(logs), "\n".join(get_workspace_files())

                if t_name in TOOL_MAP:
                    try:
                        res = TOOL_MAP[t_name](**t_args)
                    except Exception as err:
                        res = f"Execution Error: {str(err)}"
                else:
                    res = f"Error: Unknown tool '{t_name}'"

                logs.append(f"📥 Result: {res}")
                yield "\n".join(logs), "\n".join(get_workspace_files())

                response = chat.send_message(
                    types.Part.from_function_response(
                        name=t_name,
                        response={"result": res}
                    )
                )

        logs.append("\n⚠️ Max iteration steps reached.")
        yield "\n".join(logs), "\n".join(get_workspace_files())

    except Exception as e:
        logs.append(f"\n❌ Error: {str(e)}")
        yield "\n".join(logs), "\n".join(get_workspace_files())

# Gradio Web UI Layout
with gr.Blocks(title="Minimal Coding Agent") as demo:
    gr.Markdown("# 🤖 Minimal Production Coding Agent")
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

---

## Running the Application

To start the UI app, run:

```bash
python app.py
```

Then open `http://localhost:7860` in your browser.

---

## Production Checklist & Best Practices

1. **Path Traversal Protection:** Always sanitize inputs with `os.path.abspath` and verify containment inside your target directory.
2. **Deterministic Outputs:** Keep temperature at `0.0` to avoid unpredictable formatting in tool arguments.
3. **Graceful Error Recovery:** Catch tool execution errors and report them directly to the model as strings. LLMs are proficient at adjusting their actions upon seeing error output.
4. **Zero API Cost:** Leveraging Gemini 2.5 Flash's free tier keeps building and running this agent 100% free.
