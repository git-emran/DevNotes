*Live Version: 2.0*


Current Worklog:
 - Table should be responsive in preview mode, meaning a certain minimum width set for each cell and the height should be responsive, also the whole table should fit into the window size in a responsive way. 
 - Whenever any folder opens in the file tree, the expand all button should switch to collapse all button.



*Backlog:* 
##### From "Disposable Notes" to "Context Chunks"
- **Future Vision:** Imagine an "Export to Context" button where your scattered Markdown notes are automatically indexed for your local LLM or Agent, allowing it to "know" your workflow without you ever having to explain it
 


# Strategic Roadmap: From Note-Taking to Agent Operations

This document outlines the vision for evolving **Writr** from a premium markdown editor into a high-octane workspace where AI agents and humans orchestrate complex operations.

## Vision Statement

To build the "Command Center for the Agentic Era"—a workspace where knowledge is not just stored, but executable, and where AI agents have the context and tools they need to perform autonomous work.

---

## Phase 1: The Modern Knowledge Hub (Refinement)

_Focus: Visual excellence and structured knowledge._

- **Graph Visualization**: A dynamic, interactive network view of note relationships using bi-directional links (e.g., `[[note-link]]`).
- **Plugin Architecture**: A robust API for third-party extensions (themes, syntax highlighters, custom commands).
- **Canvas/Whiteboard Mode**: A spatial workspace for brainstorming where notes can be pinned, connected, and grouped visually.
- **Structured Metadata**: Advancing beyond simple tags to Frontmatter-based "Properties" (dates, numbers, select lists) that can be queried.

## Phase 2: Actionable Intelligence (Internal Capabilities)

_Focus: Transitioning from static text to executable workflows._

- **Executable Code Blocks**: Integrating a runtime (like a built-in terminal or sandboxed JS) to run code directly within markdown files.
- **MCP (Model Context Protocol) Integration**: Native support for MCP servers, allowing the app to act as a host that provides agents with access to local tools (DBs, APIs, Filesystem).
- **Workflow Templates**: Pre-defined markdown structures for common agent tasks (e.g., Code Review, Research Report, Incident Log).
- **Real-time AI Autocomplete**: Moving from "Write with AI" modals to inline ghost text and context-aware suggestions.

## Phase 3: Agent Orchestration (The Stepping Stone)

_Focus: Enabling agents to run operations._

### 1. The Agent's "Long-Term Memory"

The app becomes the primary interface for an agent's knowledge base. By exposing a local API, agents can search, retrieve, and synthesize information from the entire workspace.

### 2. Task & Operation Management

- **Visual Task Queues**: A Kanban or Timeline view that pulls from markdown tasks across all notes.
- **Agent Status Dashboard**: A specialized view showing active agent processes, their current focus, and recent "outputs" (artifacts).
- **Human-in-the-Loop (HITL) Checkpoints**: Structured "Approval" blocks in markdown that pause an agent's operation until a human interacts with the UI.

### 3. Artifact-Driven Operations

Agents don't just "chat"; they "produce". The app will prioritize the creation of stable, versioned artifacts (Specs, Code, Docs) that agents can iterate on recursively.

---

## Technical Foundations for Agents

To make this app a viable platform for agents, we must implement:

1. **Headless Mode / CLI**: Allow agents to interact with the workspace without the GUI.
2. **Semantic Search**: Vector indexing of all markdown content for RAG (Retrieval-Augmented Generation).
3. **Agentic Logging**: Moving beyond "logs" to "traces"—visualizing the step-by-step reasoning of an agent within the note it's working on.