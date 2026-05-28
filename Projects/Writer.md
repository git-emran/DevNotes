*Live Version: 2.0*


Current Worklog:

* Inline code must be rendered with a text weight of medium in preview mode
* When "/" is pressed, a context menu should appear right above the cursor , the context menu is exactly the menu that appears when I right click on the mouse in the editor. 
* Kanban:
  When clicked on "add task" input field, the input field expands and should have additional options
   Tasks in the  board when clicked should open a left panel where there is a header with task name , flag and priority level, description of the task 

62042



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


---

### Step 1: Pushing Your Local Code to GitHub

First, you need to save and upload the changes you have made locally (like the update manager we just built) to your GitHub repository.

1. **Open your Terminal** (you can use your system terminal or the terminal integrated in VS Code).
2. **Navigate to your project root folder** if you are not already there:
    
    bash
    
    cd /Users/emranhossain/portfolio-projects/simple-notes
    
3. **Verify the files that changed** by running:
    
    bash
    
    git status
    
    _You will see the list of modified files highlighted in red._
4. **Stage (prepare) the changes** for saving:
    
    bash
    
    git add .
    
5. **Commit the changes** with a meaningful message (describing what you did):
    
    bash
    
    git commit -m "feat: implement rolling auto-updates and release notes system"
    
6. **Push the changes** to your remote GitHub repository:
    
    bash
    
    git push origin main
    
    _This securely uploads your local commits to GitHub!_

---

### Step 2: Packaging Your App for Release

To let users download and run the new version of Writer, you must package the code into a distribution format (like a `.dmg` or `.zip` file for macOS).

1. In your terminal, **change directory into the `writer` subfolder** where the compiler scripts live:
    
    bash
    
    cd writer
    
2. **Compile and package the application**:
    - For **macOS** (e.g., generating a `.dmg` installer or `.app` bundle):
        
        bash
        
        npm run package:mac
        
    - For **Linux**:
        
        bash
        
        npm run package:linux
        
    - For **Windows**:
        
        bash
        
        npm run package:win
        
3. **Locate your packaged assets**:
    - Once the command finishes, look in the newly created **`writer/dist`** folder.
    - You will find files like `Writer-2.0.1.dmg` (macOS), `Writer-2.0.1.AppImage` (Linux), or similar installable packages, alongside `latest-mac.yml` or `latest.yml` files (which are crucial metadata files generated by the builder for the auto-updater).

---

### Step 3: Making the Release on GitHub

Since our auto-updater watches your GitHub Releases page, you will publish your updates there.

1. **Open your web browser** and go to your GitHub repository page: `https://github.com/git-emran/simple-notes`
2. Look on the right side of the page and click on **Releases** (or click **Draft a new release** if you have never created one before).
3. **Configure the Release Details**:
    - **Tag version**: Click the dropdown and type a tag corresponding to your `package.json` version (for example, `v2.0.1`). Click "Create new tag: v2.0.1".
    - **Target**: Leave this as the `main` branch.
    - **Release title**: Enter a friendly title (for example, `Writer v2.0.1 - The Rolling Update Release`).
4. **Write your Release Notes (Description)**:
    - This is where you write what is new in markdown! You can write a bulleted list of features.
    - _Example Release Note:_
        
        markdown
        
        ## What's New in Writer v2.0.1
        
        ### 🚀 Auto-Updates
        
        - Implemented rolling auto-updates with background download progress indicators.
        
        - Added dynamic release notes visual modals.
        
        ### 📊 Obsidian-style Table Editing
        
        - Enjoy Obsidian-level interactive tables with cell tab-navigation, auto-formatting, and folding elements.
        
        ### 📂 Nested Folder Scaling
        
        - Tree view icons scale dynamically in depth to save space.
        
5. **Upload the Packaged App Assets**:
    - Scroll down to the **"Attach binaries by dropping them here..."** box.
    - Drag and drop the built assets from your `writer/dist` folder:
        - **macOS:** Drop both `Writer-2.0.1.dmg` (or your zip) **and** the `latest-mac.yml` file.
        - **Windows/Linux:** Drop the installable files (e.g. `.exe` or `.AppImage`) **and** the `latest.yml` file.
        - _The `.yml` files are critically important because the auto-updater downloads them first to read the file size and cryptographic signature hashes._
6. **Publish**:
    - Ensure "Set as the latest release" is checked.
    - Click the green **Publish release** button!

---

### Step 4: Gating and Gaining Control of the Update Rollout

We built a custom **phased rollout gating system** to let you roll out your update to a small percentage of users first (e.g., 25%) to ensure there are no bugs before rolling it out to 100% of your users.

At the root level of your repository `/Users/emranhossain/portfolio-projects/simple-notes`, we can keep a small configuration file named `rollout.json`. Here is how you use it:

1. **Create or open the `rollout.json` file** at the root of your folder:
    
    json
    
    {
    
      "version": "2.0.1",
    
      "rolloutPercentage": 25
    
    }
    
2. **What this does**:
    - When your app starts, it checks this file on GitHub.
    - Users are assigned a random permanent "bucket number" from $1$ to $100$ when they install Writer.
    - If a user's bucket number is $\le 25$, they will automatically get notified of the update and it will download in the background.
    - If a user is above $25$, the update is "gated" (hidden) for them, keeping them safe in case of unforeseen bugs.
3. **To roll it out to more users**:
    - Simply edit `rollout.json` to change `"rolloutPercentage": 50` or `"rolloutPercentage": 100`.
    - Commit and push that change to GitHub (`git add rollout.json`, `git commit`, `git push`).
    - The remaining users will instantly become eligible and start updating on their next launch!

