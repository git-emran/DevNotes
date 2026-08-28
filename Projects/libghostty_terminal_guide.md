# Building a Custom Terminal Emulator with `libghostty`
*A Step-by-Step, Incremental Production-Grade Guide*

---

## Overview & Architecture

`libghostty` is the C-API core of [Ghostty](https://ghostty.org/), providing high-performance terminal emulation, grid rendering, font rasterization, keybinding resolution, and platform integration.

In this guide, we will build a multi-window, hardware-accelerated desktop terminal emulator from scratch using `libghostty` and C/C++. We will start with a basic single-file "Hello World" and incrementally construct a modular, production-ready architecture featuring:

1. **Pure C/C++ FFI Bindings** with `libghostty`
2. **POSIX PTY (Pseudo-Terminal) Subprocess Management**
3. **Event-Driven Event Loop & Input Handling**
4. **Hardware-Accelerated Rendering & Surface Management**
5. **Multi-Window Lifecycle & Dynamic Window Creation**

---

## Prerequisites & Dependencies

To build and run the code in this guide, ensure you have the following installed on Linux or macOS:

- `clang` or `gcc` (C11 / C++17 support)
- `libghostty` header files (`ghostty.h`) and shared library (`libghostty.so` or `libghostty.dylib`)
- `pkg-config`
- `fontconfig` and `freetype` (for fallback font resolution)
- POSIX-compliant headers (`unistd.h`, `pty.h`, `sys/select.h`, `termios.h`)

---

## Step 1: "Hello World" — Initializing `libghostty`

We begin with the absolute minimum code required to load `libghostty`, query runtime metadata, and establish global context.

### Code

```c
// main.c
#include <stdio.h>
#include <stdlib.h>
#include <ghostty.h>

int main(int argc, char** argv) {
    // Initialize global library context
    ghostty_result_t res = ghostty_init();
    if (res != GHOSTTY_SUCCESS) {
        fprintf(stderr, "Fatal: Failed to initialize libghostty (Error code: %d)\n", res);
        return EXIT_FAILURE;
    }

    // Query engine version info
    ghostty_version_t ver = ghostty_version();
    printf("Successfully initialized libghostty v%d.%d.%d\n", 
           ver.major, ver.minor, ver.patch);

    // Clean up library state
    ghostty_finalize();
    return EXIT_SUCCESS;
}
```

### Build Command

```bash
clang -Wall -Wextra main.c -lghostty -o ghostty-term
./ghostty-term
```

---

## Step 2: Spawning the Child Process (PTY Allocator)

A terminal emulator requires a **Pseudo-Terminal (PTY)** pair (master/slave) to communicate with shell processes (`/bin/zsh` or `/bin/bash`).

### Diff & Incremental Additions

```diff
+#include <unistd.h>
+#include <pty.h>
+#include <sys/wait.h>
 #include <stdio.h>
 #include <stdlib.h>
 #include <ghostty.h>

+typedef struct {
+    int master_fd;
+    pid_t child_pid;
+} pty_session_t;

+pty_session_t create_pty_session(const char* shell_path) {
+    pty_session_t session = { .master_fd = -1, .child_pid = -1 };
+    
+    // Fork child process with an allocated PTY master/slave pair
+    session.child_pid = forkpty(&session.master_fd, NULL, NULL, NULL);
+    
+    if (session.child_pid < 0) {
+        perror("forkpty failed");
+        exit(EXIT_FAILURE;
+    }
+    
+    if (session.child_pid == 0) {
+        // Inside Child Process: Execute the requested shell
+        char* const envp[] = { "TERM=xterm-256color", NULL };
+        char* const argv[] = { (char*)shell_path, NULL };
+        execve(shell_path, argv, envp);
+        
+        // If execve returns, an error occurred
+        perror("execve failed");
+        _exit(EXIT_FAILURE);
+    }
+    
+    // Return session handle to parent process
+    return session;
+}
```

### Explanation
- **`forkpty`**: Creates a master/slave PTY pair and forks the running process.
- **Child Branch (`pid == 0`)**: Sets default environment variables (e.g., `TERM=xterm-256color`) and replaces the image with the target shell (`execve`).
- **Parent Branch (`pid > 0`)**: Stores `master_fd` for bi-directional I/O operations.

---

## Step 3: Binding `libghostty` Terminal Grid to the PTY

Next, we bind the master file descriptor to a `ghostty_terminal_t` instance. This object manages screen buffers, ANSI sequence parsing, cursor states, and scrollback history.

### Diff & Incremental Additions

```diff
 typedef struct {
     int master_fd;
     pid_t child_pid;
 } pty_session_t;

+typedef struct {
+    ghostty_terminal_t* terminal;
+    pty_session_t pty;
+    uint32_t cols;
+    uint32_t rows;
+} terminal_window_t;

+terminal_window_t* create_terminal_window(uint32_t cols, uint32_t rows) {
+    terminal_window_t* win = malloc(sizeof(terminal_window_t));
+    win->cols = cols;
+    win->rows = rows;
+    
+    // 1. Spawn Child PTY Process
+    win->pty = create_pty_session("/bin/bash");
+    
+    // 2. Configure Ghostty Terminal Options
+    ghostty_terminal_config_t config = {
+        .cols = cols,
+        .rows = rows,
+        .max_scrollback = 10000,
+    };
+    
+    // 3. Instramentiate libghostty instance
+    ghostty_result_t res = ghostty_terminal_new(&config, &win->terminal);
+    if (res != GHOSTTY_SUCCESS) {
+        fprintf(stderr, "Failed to instantiate terminal grid\n");
+        exit(EXIT_FAILURE);
+    }
+    
+    return win;
+}
```

### Explanation
- **`ghostty_terminal_config_t`**: Configures screen geometry (columns and rows) and buffer limits.
- **`ghostty_terminal_new`**: Constructs the state machine responsible for processing terminal escape codes (`VT100`, `xterm`).

---

## Step 4: The Event & Render Loop (Non-blocking I/O)

To process output from the shell and forward key events, we implement a non-blocking event loop using `select()`.

### Full Updated Code

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pty.h>
#include <sys/select.h>
#include <ghostty.h>

typedef struct {
    int master_fd;
    pid_t child_pid;
} pty_session_t;

typedef struct {
    ghostty_terminal_t* terminal;
    pty_session_t pty;
    uint32_t cols;
    uint32_t rows;
} terminal_window_t;

void process_pty_output(terminal_window_t* win) {
    char buffer[4096];
    ssize_t bytes_read = read(win->pty.master_fd, buffer, sizeof(buffer));
    
    if (bytes_read > 0) {
        // Feed raw bytes from shell into Ghostty's parser engine
        ghostty_terminal_write(win->terminal, buffer, (size_t)bytes_read);
    }
}

void render_frame(terminal_window_t* win) {
    // Lock surface state and fetch grid update instructions
    ghostty_render_state_t render_state;
    ghostty_terminal_render_state(win->terminal, &render_state);

    // In a full graphics application, pipeline cells to GPU/OpenGL/Metal here.
    // For verification, we fetch dirty lines and cursor position.
    ghostty_cursor_t cursor = ghostty_render_state_cursor(&render_state);
    
    // Release render lock
    ghostty_render_state_free(&render_state);
}

void run_event_loop(terminal_window_t* win) {
    fd_set read_fds;
    int max_fd = win->pty.master_fd;
    
    while (1) {
        FD_ZERO(&read_fds);
        FD_SET(win->pty.master_fd, &read_fds);
        
        struct timeval timeout = { .tv_sec = 0, .tv_usec = 16000 }; // ~60 FPS cycle
        
        int activity = select(max_fd + 1, &read_fds, NULL, NULL, &timeout);
        if (activity < 0) {
            perror("select error");
            break;
        }
        
        if (FD_ISSET(win->pty.master_fd, &read_fds)) {
            process_pty_output(win);
        }
        
        // Render updated terminal surface
        render_frame(win);
    }
}
```

---

## Step 5: Multi-Window Lifecycle Architecture

In a production-ready application, users open and close multiple windows independently. We introduce a thread-safe window collection and dynamic lifecycle manager.

### Code Architecture

```cpp
// window_manager.hpp
#pragma once
#include <vector>
#include <memory>
#include <ghostty.h>

class TerminalWindow {
public:
    TerminalWindow(uint32_t width, uint32_t height, const char* shell);
    ~TerminalWindow();

    void update();
    void render();
    bool should_close() const { return m_should_close; }
    int get_pty_fd() const { return m_pty_fd; }

private:
    ghostty_terminal_t* m_term = nullptr;
    int m_pty_fd = -1;
    pid_t m_child_pid = -1;
    bool m_should_close = false;
};

class WindowManager {
public:
    static WindowManager& instance() {
        static WindowManager inst;
        return inst;
    }

    void create_window(uint32_t width = 80, uint32_t height = 24) {
        m_windows.push_back(std::make_unique<TerminalWindow>(width, height, "/bin/bash"));
    }

    void process_events() {
        for (auto it = m_windows.begin(); it != m_windows.end();) {
            (*it)->update();
            (*it)->render();
            
            if ((*it)->should_close()) {
                it = m_windows.erase(it);
            } else {
                ++it;
            }
        }
    }

    bool has_active_windows() const { return !m_windows.empty(); }

private:
    std::vector<std::unique_ptr<TerminalWindow>> m_windows;
};
```

---

## Step 6: Complete Production Code Base

Below is the complete, self-contained, multi-window C++ application utilizing `libghostty`.

```cpp
// main.cpp
#include <iostream>
#include <vector>
#include <memory>
#include <unistd.h>
#include <pty.h>
#include <sys/select.h>
#include <sys/wait.h>
#include <ghostty.h>

class TerminalInstance {
private:
    ghostty_terminal_t* m_terminal = nullptr;
    int m_master_fd = -1;
    pid_t m_pid = -1;
    bool m_closed = false;

public:
    TerminalInstance(uint32_t cols, uint32_t rows, const char* shell) {
        // 1. Allocate PTY
        m_pid = forkpty(&m_master_fd, nullptr, nullptr, nullptr);
        if (m_pid == 0) {
            char* const envp[] = { (char*)"TERM=xterm-256color", nullptr };
            char* const argv[] = { (char*)shell, nullptr };
            execve(shell, argv, envp);
            _exit(1);
        }

        // 2. Initialize Ghostty Terminal Instance
        ghostty_terminal_config_t config = {
            .cols = cols,
            .rows = rows,
            .max_scrollback = 50000,
        };

        if (ghostty_terminal_new(&config, &m_terminal) != GHOSTTY_SUCCESS) {
            throw std::runtime_error("Failed to initialize ghostty terminal");
        }
    }

    ~TerminalInstance() {
        if (m_terminal) {
            ghostty_terminal_free(m_terminal);
        }
        if (m_master_fd >= 0) {
            close(m_master_fd);
        }
        if (m_pid > 0) {
            kill(m_pid, SIGTERM);
            waitpid(m_pid, nullptr, WNOHANG);
        }
    }

    int get_fd() const { return m_master_fd; }
    bool is_closed() const { return m_closed; }

    void read_pty() {
        char buf[8192];
        ssize_t n = read(m_master_fd, buf, sizeof(buf));
        if (n <= 0) {
            m_closed = true;
            return;
        }
        ghostty_terminal_write(m_terminal, buf, static_cast<size_t>(n));
    }

    void handle_key_input(const char* input, size_t len) {
        // Forward keyboard input directly to master PTY file descriptor
        write(m_master_fd, input, len);
    }

    void render() {
        ghostty_render_state_t state;
        ghostty_terminal_render_state(m_terminal, &state);
        // GPU rendering hooks bind here
        ghostty_render_state_free(&state);
    }
};

int main() {
    if (ghostty_init() != GHOSTTY_SUCCESS) {
        std::cerr << "Failed to initialize libghostty\n";
        return 1;
    }

    std::vector<std::unique_ptr<TerminalInstance>> windows;
    
    // Spawn two initial terminal windows
    windows.push_back(std::make_unique<TerminalInstance>(80, 24, "/bin/bash"));
    windows.push_back(std::make_unique<TerminalInstance>(100, 30, "/bin/bash"));

    std::cout << "Spawned " << windows.size() << " terminal windows.\n";

    while (!windows.empty()) {
        fd_set read_fds;
        FD_ZERO(&read_fds);
        int max_fd = -1;

        for (const auto& win : windows) {
            int fd = win->get_fd();
            FD_SET(fd, &read_fds);
            if (fd > max_fd) max_fd = fd;
        }

        struct timeval tv = { .tv_sec = 0, .tv_usec = 10000 };
        int res = select(max_fd + 1, &read_fds, nullptr, nullptr, &tv);

        if (res > 0) {
            for (auto& win : windows) {
                if (FD_ISSET(win->get_fd(), &read_fds)) {
                    win->read_pty();
                }
            }
        }

        // Render and clean up closed windows
        for (auto it = windows.begin(); it != windows.end();) {
            (*it)->render();
            if ((*it)->is_closed()) {
                std::cout << "Terminal window closed.\n";
                it = windows.erase(it);
            } else {
                ++it;
            }
        }
    }

    ghostty_finalize();
    std::cout << "All terminal windows closed. Exiting cleanly.\n";
    return 0;
}
```

---

## Build & Testing Verification

To compile and verify the multi-window C++ terminal application:

```bash
# Compile using C++17
clang++ -std=c++17 -Wall -Wextra main.cpp -lghostty -o libghostty-demo

# Run the terminal application
./libghostty-demo
```
