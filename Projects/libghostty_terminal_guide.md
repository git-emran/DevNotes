# Building a Ghostty/Kitty-Style Windowed Terminal with libghostty

 *An incremental, technically accurate guide — every function referenced below is fully implemented somewhere in this document.*

 ---
This guide uses **Raylib**, same as ghostling, because libghostty has zero opinion about your renderer and Raylib is the least ceremony between you and a pixel on screen.

 ---

 ## How this guide is organized

 Every step below adds to **one growing file, `main.c`**. Each code block starts with a comment telling you exactly where it goes relative to what you already have — treat the whole document as a diff applied in order, not as independent snippets. Here's the final shape you're building toward, top to bottom:

 ```
main.c
├── #includes                        (Step 0)
├── PtyReadResult enum                (Step 3)
├── pty_spawn()                       (Step 2)
├── pty_write()                       (Step 3)
├── pty_read()                        (Step 3)
├── utf8_encode()                     (Step 5)
├── render_terminal()                 (Step 5)
├── raylib_key_to_ghostty()           (Step 6)
├── raylib_key_unshifted_codepoint()  (Step 6)
├── get_ghostty_mods()                (Step 6)
├── send_key_events()                 (Step 6)
├── raylib_mouse_to_ghostty()         (Step 7)
├── mouse_encode_and_write()          (Step 7)
├── send_mouse_events()               (Step 7)
├── apply_resize()                    (Step 8)
└── main()                            (Step 8)
```

 Nothing here is optional scaffolding — by the end of Step 8 you have a single file that builds and runs.

 ---

 ## Prerequisites

 - CMake 3.19+, Ninja, a C11 compiler
- **Zig 0.15.x on `PATH`** — `libghostty-vt` builds from source via Zig as part of `cmake --build`
- Linux: `sudo apt install ninja-build build-essential git libxinerama-dev libxcursor-dev libxrandr-dev libxi-dev libxext-dev libx11-dev libgl-dev`
- macOS: Xcode Command Line Tools

 ```cmake
# CMakeLists.txt — the whole build config, nothing else needed
cmake_minimum_required(VERSION 3.19)
project(my_terminal C)
set(CMAKE_C_STANDARD 11)

include(FetchContent)

FetchContent_Declare(
  libghostty
  URL https://release.files.ghostty.org/tip/libghostty-vt-tip.tar.gz
)
FetchContent_MakeAvailable(libghostty)

FetchContent_Declare(
  raylib
  GIT_REPOSITORY https://github.com/raysan5/raylib.git
  GIT_TAG 5.0
)
FetchContent_MakeAvailable(raylib)

add_executable(my_terminal main.c)
target_link_libraries(my_terminal PRIVATE ghostty-vt raylib)
```

 Pin `libghostty-vt` to a released tag once you've settled on an API surface — `tip` tracks upstream `main`, which still moves.

 ---

 ## Step 0 — includes (top of `main.c`, nothing before these)

 ```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <pwd.h>

#if defined(__APPLE__)
  #include <util.h>   // forkpty on macOS
#else
  #include <pty.h>    // forkpty on Linux
#endif

#include "raylib.h"
#include <ghostty/vt.h>
```

 ---

 ## Step 1 — prove the VT engine works, headless

 Before any window: create a terminal, feed it bytes, confirm the parser is doing its job. This is throwaway code (superseded by `main()` in Step 8) but worth running once on its own — it isolates "is my terminal-state code right" from "is my renderer right."

 ```c
// TEMPORARY — replace with Step 8's main() once you get here.
int main(void) {
    GhosttyTerminal term = NULL;
    GhosttyTerminalOptions opts = {0};
    opts.cols = 80;
    opts.rows = 24;

    if (ghostty_terminal_new(NULL, &term, opts) != GHOSTTY_SUCCESS) {
        fprintf(stderr, "failed to create terminal\n");
        return 1;
    }

    const char *hello = "Hello, \x1b[1;32mlibghostty\x1b[0m!\r\n";
    ghostty_terminal_vt_write(term, (const uint8_t *)hello, strlen(hello));

    ghostty_terminal_free(term);
    return 0;
}
```

 `ghostty_terminal_new(allocator, &terminal, options)` takes the options **struct by value** (not a pointer) and an allocator pointer you can pass as `NULL` to get the default allocator — every `_new` function in this API follows that same `(allocator, out*)` shape.

 ---

 ## Step 2 — a real PTY (goes above `main()`, near the top with the includes)

 ```c
// Spawn the user's shell in a new pseudo-terminal. Sets ws_xpixel/
// ws_ypixel too (not just rows/cols) so pixel-aware programs get
// correct geometry from their very first ioctl, not just after a
// resize. Non-blocking master fd so reading it never stalls a frame.
static int pty_spawn(pid_t *child_out, uint16_t cols, uint16_t rows,
                      int cell_w, int cell_h) {
    struct winsize ws = {
        .ws_row = rows, .ws_col = cols,
        .ws_xpixel = (unsigned short)(cols * cell_w),
        .ws_ypixel = (unsigned short)(rows * cell_h),
    };

    int fd;
    pid_t pid = forkpty(&fd, NULL, NULL, &ws);
    if (pid < 0) { perror("forkpty"); return -1; }

    if (pid == 0) {
        const char *shell = getenv("SHELL");
        if (!shell || !*shell) {
            struct passwd *pw = getpwuid(getuid());
            shell = (pw && pw->pw_shell && *pw->pw_shell) ? pw->pw_shell : "/bin/sh";
        }
        const char *name = strrchr(shell, '/');
        name = name ? name + 1 : shell;

        setenv("TERM", "xterm-256color", 1);
        execl(shell, name, NULL);
        _exit(127); // only reached if execl fails
    }

    int flags = fcntl(fd, F_GETFL);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);

    *child_out = pid;
    return fd;
}
```

 ---

 ## Step 3 — wire the PTY into the terminal (goes right after `pty_spawn()`)

 ```c
// Result of draining the pty master fd this frame.
typedef enum {
    PTY_READ_OK,    // drained everything currently available
    PTY_READ_EOF,   // child exited / closed its side
    PTY_READ_ERROR, // a real read error
} PtyReadResult;

// Best-effort write: non-blocking fd means write() can be short or
// return EAGAIN under back-pressure. Retry on EINTR, advance past
// partial writes, drop the remainder on EAGAIN — same behavior every
// terminal emulator uses under load.
static void pty_write(int fd, const char *buf, size_t len) {
    while (len > 0) {
        ssize_t n = write(fd, buf, len);
        if (n > 0) {
            buf += n;
            len -= (size_t)n;
        } else if (n < 0) {
            if (errno == EINTR) continue;
            break; // EAGAIN or real error — drop the remainder
        }
    }
}

// Drain all currently-available PTY output into the terminal's VT
// parser. Call this once per frame, before rendering.
static PtyReadResult pty_read(int fd, GhosttyTerminal term) {
    uint8_t buf[4096];
    for (;;) {
        ssize_t n = read(fd, buf, sizeof(buf));
        if (n > 0) {
            ghostty_terminal_vt_write(term, buf, (size_t)n);
        } else if (n == 0) {
            return PTY_READ_EOF;
        } else if (errno == EAGAIN) {
            return PTY_READ_OK;   // nothing more available this frame
        } else if (errno == EINTR) {
            continue;
        } else if (errno == EIO) {
            // Linux often reports a closed slave as EIO, not read()==0
            return PTY_READ_EOF;
        } else {
            perror("pty read");
            return PTY_READ_ERROR;
        }
    }
}
```

 At this point you have a fully working headless terminal. Everything from here is presentation and input.

 ---

 ## Step 4 — open the actual window (structural note, code lands in `main()` at Step 8)

 This is the piece the original guide skipped. `libghostty-vt` doesn't know Raylib exists — the window, the font, the event loop are entirely yours:

 ```c
InitWindow(cols * cell_w + pad * 2, rows * cell_h + pad * 2, "my-terminal");
SetTargetFPS(60);
Font font = LoadFontEx("JetBrainsMono-Regular.ttf", font_size, NULL, 0);
```

 Measure your real cell size from the loaded font instead of hardcoding it — monospace fonts vary slightly by hinting:

 ```c
Vector2 metrics = MeasureTextEx(font, "M", font_size, 0);
int cell_w = (int)metrics.x;
int cell_h = font_size + 4; // small line-height pad; tune to taste
```

 ---

 ## Step 5 — decode codepoints and draw real content (goes after `pty_read()`)

 Two pieces here: a UTF-8 encoder (the render state gives you Unicode codepoints, not bytes — Raylib's `DrawTextEx` wants UTF-8), and `render_terminal()`, which walks `GhosttyRenderState`'s row/cell iterator.

 ```c
// Encode one Unicode codepoint to UTF-8. Returns bytes written (1-4).
// Codepoints above U+10FFFF (invalid) become U+FFFD.
static int utf8_encode(uint32_t cp, char out[4]) {
    if (cp > 0x10FFFF) cp = 0xFFFD;

    if (cp < 0x80) {
        out[0] = (char)cp;
        return 1;
    } else if (cp < 0x800) {
        out[0] = (char)(0xC0 | (cp >> 6));
        out[1] = (char)(0x80 | (cp & 0x3F));
        return 2;
    } else if (cp < 0x10000) {
        out[0] = (char)(0xE0 | (cp >> 12));
        out[1] = (char)(0x80 | ((cp >> 6) & 0x3F));
        out[2] = (char)(0x80 | (cp & 0x3F));
        return 3;
    } else {
        out[0] = (char)(0xF0 | (cp >> 18));
        out[1] = (char)(0x80 | ((cp >> 12) & 0x3F));
        out[2] = (char)(0x80 | ((cp >> 6) & 0x3F));
        out[3] = (char)(0x80 | (cp & 0x3F));
        return 4;
    }
}
```

 ```c
// Draw one frame of terminal content using the render-state snapshot
// API. render_state/row_iter/cells are created once in main() (Step 8)
// and reused every frame — only their *contents* change per call.
static void render_terminal(GhosttyRenderState render_state,
                             GhosttyRenderStateRowIterator row_iter,
                             GhosttyRenderStateRowCells cells,
                             GhosttyTerminal term, Font font,
                             int cell_w, int cell_h, int font_size, int pad) {
    GhosttyRenderStateColors colors = {0};
    if (ghostty_render_state_colors_get(render_state, &colors) != GHOSTTY_SUCCESS)
        return;

    if (ghostty_render_state_get(render_state,
            GHOSTTY_RENDER_STATE_DATA_ROW_ITERATOR, &row_iter) != GHOSTTY_SUCCESS)
        return;

    int y = pad;
    while (ghostty_render_state_row_iterator_next(row_iter)) {
        if (ghostty_render_state_row_get(row_iter,
                GHOSTTY_RENDER_STATE_ROW_DATA_CELLS, &cells) != GHOSTTY_SUCCESS) {
            y += cell_h;
            continue;
        }

        int x = pad;
        while (ghostty_render_state_row_cells_next(cells)) {
            uint32_t glen = 0;
            ghostty_render_state_row_cells_get(cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_LEN, &glen);

            // Empty cell: it may still carry an explicit background
            // color (e.g. from a colored erase), so check before moving on.
            if (glen == 0) {
                GhosttyColorRgb bg = {0};
                if (ghostty_render_state_row_cells_get(cells,
                        GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_BG_COLOR, &bg) == GHOSTTY_SUCCESS) {
                    DrawRectangle(x, y, cell_w, cell_h, (Color){bg.r, bg.g, bg.b, 255});
                }
                x += cell_w;
                continue;
            }

            uint32_t codepoints[16];
            uint32_t len = glen < 16 ? glen : 16;
            ghostty_render_state_row_cells_get(cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_BUF, codepoints);

            char text[64];
            int pos = 0;
            for (uint32_t i = 0; i < len && pos < 60; i++) {
                char u8[4];
                int n = utf8_encode(codepoints[i], u8);
                memcpy(&text[pos], u8, n);
                pos += n;
            }
            text[pos] = '\0';

            // Per-cell colors already flatten SGR / palette / content-tag
            // resolution for you — you never touch the palette directly.
            GhosttyColorRgb fg = colors.foreground;
            ghostty_render_state_row_cells_get(cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_FG_COLOR, &fg);

            GhosttyColorRgb bg = colors.background;
            bool has_bg = ghostty_render_state_row_cells_get(cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_BG_COLOR, &bg) == GHOSTTY_SUCCESS;

            GhosttyStyle style = {0};
            ghostty_render_state_row_cells_get(cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_STYLE, &style);

            if (style.inverse) {
                GhosttyColorRgb tmp = fg; fg = bg; bg = tmp;
                has_bg = true;
            }

            if (has_bg)
                DrawRectangle(x, y, cell_w, cell_h, (Color){bg.r, bg.g, bg.b, 255});

            Color ray_fg = {fg.r, fg.g, fg.b, 255};
            int italic_off = style.italic ? font_size / 6 : 0;
            DrawTextEx(font, text, (Vector2){x + italic_off, y}, font_size, 0, ray_fg);
            if (style.bold) // cheap "fake bold": redraw shifted 1px
                DrawTextEx(font, text, (Vector2){x + italic_off + 1, y}, font_size, 0, ray_fg);

            x += cell_w;
        }
        y += cell_h;
    }

    // Cursor
    bool cursor_visible = false, cursor_in_view = false;
    ghostty_render_state_get(render_state, GHOSTTY_RENDER_STATE_DATA_CURSOR_VISIBLE, &cursor_visible);
    ghostty_render_state_get(render_state, GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_HAS_VALUE, &cursor_in_view);
    if (cursor_visible && cursor_in_view) {
        uint16_t cx = 0, cy = 0;
        ghostty_render_state_get(render_state, GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_X, &cx);
        ghostty_render_state_get(render_state, GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_Y, &cy);
        GhosttyColorRgb cur = colors.cursor_has_value ? colors.cursor : colors.foreground;
        DrawRectangle(pad + cx * cell_w, pad + cy * cell_h, cell_w, cell_h,
                       (Color){cur.r, cur.g, cur.b, 128});
    }

    (void)term; // kept in the signature for symmetry with Step 7's mouse code
}
```

 Kitty-graphics image layering is real but purely mechanical on top of this — see ghostling's `render_kitty_images()` when you're ready for it; everything above already gives you a complete text terminal.

 ---

 ## Step 6 — keyboard input (goes after `render_terminal()`)

 Key presses have to become *correct* VT sequences given the terminal's current modes (application cursor keys, Kitty keyboard protocol, etc.) — the encoder reads that state for you on every call, so you never hand-roll an escape-sequence table.

 ```c
// Map a raylib key constant to a GhosttyKey. Covers letters, digits,
// F-keys (all contiguous ranges in both enums) plus the common
// punctuation/navigation keys. Extend the switch for anything raylib
// exposes that you also want to forward.
static GhosttyKey raylib_key_to_ghostty(int rl_key) {
    if (rl_key >= KEY_A && rl_key <= KEY_Z) return GHOSTTY_KEY_A + (rl_key - KEY_A);
    if (rl_key >= KEY_ZERO && rl_key <= KEY_NINE) return GHOSTTY_KEY_DIGIT_0 + (rl_key - KEY_ZERO);
    if (rl_key >= KEY_F1 && rl_key <= KEY_F12) return GHOSTTY_KEY_F1 + (rl_key - KEY_F1);

    switch (rl_key) {
        case KEY_SPACE:     return GHOSTTY_KEY_SPACE;
        case KEY_ENTER:     return GHOSTTY_KEY_ENTER;
        case KEY_TAB:       return GHOSTTY_KEY_TAB;
        case KEY_BACKSPACE: return GHOSTTY_KEY_BACKSPACE;
        case KEY_DELETE:    return GHOSTTY_KEY_DELETE;
        case KEY_ESCAPE:    return GHOSTTY_KEY_ESCAPE;
        case KEY_UP:        return GHOSTTY_KEY_ARROW_UP;
        case KEY_DOWN:      return GHOSTTY_KEY_ARROW_DOWN;
        case KEY_LEFT:      return GHOSTTY_KEY_ARROW_LEFT;
        case KEY_RIGHT:     return GHOSTTY_KEY_ARROW_RIGHT;
        case KEY_HOME:      return GHOSTTY_KEY_HOME;
        case KEY_END:       return GHOSTTY_KEY_END;
        default:            return GHOSTTY_KEY_UNIDENTIFIED;
    }
}

// The character this key produces with no modifiers on a US layout —
// the Kitty keyboard protocol needs this to identify keys independent
// of shift state. 0 for keys with no natural codepoint (arrows, etc).
static uint32_t raylib_key_unshifted_codepoint(int rl_key) {
    if (rl_key >= KEY_A && rl_key <= KEY_Z) return 'a' + (uint32_t)(rl_key - KEY_A);
    if (rl_key >= KEY_ZERO && rl_key <= KEY_NINE) return '0' + (uint32_t)(rl_key - KEY_ZERO);
    if (rl_key == KEY_SPACE) return ' ';
    return 0;
}

static GhosttyMods get_ghostty_mods(void) {
    GhosttyMods mods = 0;
    if (IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT)) mods |= GHOSTTY_MODS_SHIFT;
    if (IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL)) mods |= GHOSTTY_MODS_CTRL;
    if (IsKeyDown(KEY_LEFT_ALT) || IsKeyDown(KEY_RIGHT_ALT)) mods |= GHOSTTY_MODS_ALT;
    if (IsKeyDown(KEY_LEFT_SUPER) || IsKeyDown(KEY_RIGHT_SUPER)) mods |= GHOSTTY_MODS_SUPER;
    return mods;
}

// Poll raylib for one frame's worth of key events and forward each
// through the key encoder. `encoder`/`event` are created once in
// main() (Step 8) and reused every frame.
static void send_key_events(int pty_fd, GhosttyKeyEncoder encoder,
                             GhosttyKeyEvent event, GhosttyTerminal term) {
    ghostty_key_encoder_setopt_from_terminal(encoder, term);

    // Collect this frame's printable text once, up front.
    char text[64];
    int text_len = 0;
    int ch;
    while ((ch = GetCharPressed()) != 0) {
        char u8[4];
        int n = utf8_encode((uint32_t)ch, u8);
        if (text_len + n < (int)sizeof(text)) {
            memcpy(&text[text_len], u8, n);
            text_len += n;
        }
    }

    static const int scan_keys[] = {
        KEY_SPACE, KEY_ENTER, KEY_TAB, KEY_BACKSPACE, KEY_DELETE, KEY_ESCAPE,
        KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END,
    };
    GhosttyMods mods = get_ghostty_mods();

    // Letters, digits, F-keys, plus the explicit list above.
    int all_keys[26 + 10 + 12 + (int)(sizeof(scan_keys) / sizeof(scan_keys[0]))];
    int n_keys = 0;
    for (int k = KEY_A; k <= KEY_Z; k++) all_keys[n_keys++] = k;
    for (int k = KEY_ZERO; k <= KEY_NINE; k++) all_keys[n_keys++] = k;
    for (int k = KEY_F1; k <= KEY_F12; k++) all_keys[n_keys++] = k;
    for (size_t i = 0; i < sizeof(scan_keys) / sizeof(scan_keys[0]); i++)
        all_keys[n_keys++] = scan_keys[i];

    for (int i = 0; i < n_keys; i++) {
        int rl_key = all_keys[i];
        bool pressed  = IsKeyPressed(rl_key);
        bool repeated = IsKeyPressedRepeat(rl_key);
        bool released = IsKeyReleased(rl_key);
        if (!pressed && !repeated && !released) continue;

        GhosttyKey gkey = raylib_key_to_ghostty(rl_key);
        if (gkey == GHOSTTY_KEY_UNIDENTIFIED) continue;

        ghostty_key_event_set_key(event, gkey);
        ghostty_key_event_set_action(event, released ? GHOSTTY_KEY_ACTION_RELEASE
                                    : pressed ? GHOSTTY_KEY_ACTION_PRESS
                                              : GHOSTTY_KEY_ACTION_REPEAT);
        ghostty_key_event_set_mods(event, mods);

        uint32_t ucp = raylib_key_unshifted_codepoint(rl_key);
        ghostty_key_event_set_unshifted_codepoint(event, ucp);

        GhosttyMods consumed = (ucp != 0 && (mods & GHOSTTY_MODS_SHIFT)) ? GHOSTTY_MODS_SHIFT : 0;
        ghostty_key_event_set_consumed_mods(event, consumed);

        if (text_len > 0 && !released) {
            ghostty_key_event_set_utf8(event, text, (size_t)text_len);
            text_len = 0; // attach only to the first key event this frame
        } else {
            ghostty_key_event_set_utf8(event, NULL, 0);
        }

        char buf[128];
        size_t written = 0;
        if (ghostty_key_encoder_encode(encoder, event, buf, sizeof(buf), &written)
                == GHOSTTY_SUCCESS && written > 0) {
            pty_write(pty_fd, buf, written);
            text_len = 0;
        }
    }

    // Fallback for platforms where the char event lands a frame late.
    if (text_len > 0) pty_write(pty_fd, text, (size_t)text_len);
}
```

 ---

 ## Step 7 — mouse input (goes after `send_key_events()`)

 ```c
static GhosttyMouseButton raylib_mouse_to_ghostty(int rl_btn) {
    switch (rl_btn) {
        case MOUSE_BUTTON_LEFT:   return GHOSTTY_MOUSE_BUTTON_LEFT;
        case MOUSE_BUTTON_RIGHT:  return GHOSTTY_MOUSE_BUTTON_RIGHT;
        case MOUSE_BUTTON_MIDDLE: return GHOSTTY_MOUSE_BUTTON_MIDDLE;
        default:                  return GHOSTTY_MOUSE_BUTTON_UNKNOWN;
    }
}

static void mouse_encode_and_write(int pty_fd, GhosttyMouseEncoder encoder,
                                    GhosttyMouseEvent event) {
    char buf[128];
    size_t written = 0;
    if (ghostty_mouse_encoder_encode(encoder, event, buf, sizeof(buf), &written)
            == GHOSTTY_SUCCESS && written > 0)
        pty_write(pty_fd, buf, written);
}

// Click/scroll handling. `encoder`/`event` are created once in main()
// (Step 8) and reused every frame, same as the key encoder.
static void send_mouse_events(int pty_fd, GhosttyMouseEncoder encoder,
                               GhosttyMouseEvent event, GhosttyTerminal term,
                               int cell_w, int cell_h, int pad) {
    ghostty_mouse_encoder_setopt_from_terminal(encoder, term);

    GhosttyMouseEncoderSize size = {
        .size = sizeof(GhosttyMouseEncoderSize),
        .screen_width = (uint32_t)GetScreenWidth(),
        .screen_height = (uint32_t)GetScreenHeight(),
        .cell_width = (uint32_t)cell_w,
        .cell_height = (uint32_t)cell_h,
        .padding_top = (uint32_t)pad, .padding_bottom = (uint32_t)pad,
        .padding_left = (uint32_t)pad, .padding_right = (uint32_t)pad,
    };
    ghostty_mouse_encoder_setopt(encoder, GHOSTTY_MOUSE_ENCODER_OPT_SIZE, &size);

    Vector2 pos = GetMousePosition();
    ghostty_mouse_event_set_mods(event, get_ghostty_mods());
    ghostty_mouse_event_set_position(event, (GhosttyMousePosition){pos.x, pos.y});

    static const int buttons[] = {MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE};
    for (size_t i = 0; i < sizeof(buttons) / sizeof(buttons[0]); i++) {
        GhosttyMouseButton gbtn = raylib_mouse_to_ghostty(buttons[i]);
        if (IsMouseButtonPressed(buttons[i])) {
            ghostty_mouse_event_set_button(event, gbtn);
            ghostty_mouse_event_set_action(event, GHOSTTY_MOUSE_ACTION_PRESS);
            mouse_encode_and_write(pty_fd, encoder, event);
        } else if (IsMouseButtonReleased(buttons[i])) {
            ghostty_mouse_event_set_button(event, gbtn);
            ghostty_mouse_event_set_action(event, GHOSTTY_MOUSE_ACTION_RELEASE);
            mouse_encode_and_write(pty_fd, encoder, event);
        }
    }

    // Scroll: forward to the app if it enabled mouse tracking,
    // otherwise scroll our own scrollback viewport.
    float wheel = GetMouseWheelMove();
    if (wheel != 0.0f) {
        bool tracking = false;
        ghostty_terminal_get(term, GHOSTTY_TERMINAL_DATA_MOUSE_TRACKING, &tracking);
        if (tracking) {
            GhosttyMouseButton sbtn = wheel > 0 ? GHOSTTY_MOUSE_BUTTON_FOUR : GHOSTTY_MOUSE_BUTTON_FIVE;
            ghostty_mouse_event_set_button(event, sbtn);
            ghostty_mouse_event_set_action(event, GHOSTTY_MOUSE_ACTION_PRESS);
            mouse_encode_and_write(pty_fd, encoder, event);
            ghostty_mouse_event_set_action(event, GHOSTTY_MOUSE_ACTION_RELEASE);
            mouse_encode_and_write(pty_fd, encoder, event);
        } else {
            GhosttyTerminalScrollViewport sv = {
                .tag = GHOSTTY_SCROLL_VIEWPORT_DELTA,
                .value = { .delta = wheel > 0 ? -3 : 3 },
            };
            ghostty_terminal_scroll_viewport(term, sv);
        }
    }
}
```

 (Drag-to-scroll on a visible scrollbar, and full any-event mouse tracking with motion deduplication, are in ghostling's `handle_scrollbar()`/`handle_mouse()` — worth adding once clicks and basic scroll are working.)

 ---

 ## Step 8 — resize handling and `main()` (this is the file's final section)

 ```c
// Call once per frame. Resizes both the PTY (so the shell/programs
// inside see the new geometry) and the terminal's own VT state (so
// text reflows to match) — skipping either leaves them disagreeing,
// which shows up as wrong $COLUMNS inside vim/less.
static void apply_resize(int pty_fd, GhosttyTerminal term,
                          int *last_cols, int *last_rows,
                          int cell_w, int cell_h, int pad) {
    int cols = (GetScreenWidth() - pad * 2) / cell_w;
    int rows = (GetScreenHeight() - pad * 2) / cell_h;
    if (cols == *last_cols && rows == *last_rows) return;

    struct winsize ws = {
        .ws_row = (unsigned short)rows, .ws_col = (unsigned short)cols,
        .ws_xpixel = (unsigned short)(cols * cell_w),
        .ws_ypixel = (unsigned short)(rows * cell_h),
    };
    ioctl(pty_fd, TIOCSWINSZ, &ws);
    ghostty_terminal_resize(term, (uint16_t)cols, (uint16_t)rows);

    *last_cols = cols;
    *last_rows = rows;
}

int main(void) {
    const int cell_w_guess = 9, cell_h_guess = 18, font_size = 16, pad = 4;
    const int init_cols = 80, init_rows = 24;

    InitWindow(init_cols * cell_w_guess + pad * 2,
               init_rows * cell_h_guess + pad * 2, "my-terminal");
    SetTargetFPS(60);
    Font font = LoadFontEx("JetBrainsMono-Regular.ttf", font_size, NULL, 0);
    Vector2 metrics = MeasureTextEx(font, "M", font_size, 0);
    int cell_w = (int)metrics.x, cell_h = font_size + 4;

    pid_t child;
    int pty_fd = pty_spawn(&child, init_cols, init_rows, cell_w, cell_h);
    if (pty_fd < 0) return 1;

    GhosttyTerminal term = NULL;
    GhosttyTerminalOptions opts = {0};
    opts.cols = init_cols;
    opts.rows = init_rows;
    if (ghostty_terminal_new(NULL, &term, opts) != GHOSTTY_SUCCESS) return 1;

    GhosttyRenderState render_state = NULL;
    ghostty_render_state_new(NULL, &render_state);
    GhosttyRenderStateRowIterator row_iter = NULL;
    GhosttyRenderStateRowCells cells = NULL;

    GhosttyKeyEncoder key_encoder = NULL;
    ghostty_key_encoder_new(NULL, &key_encoder);
    GhosttyKeyEvent key_event = NULL;
    ghostty_key_event_new(NULL, &key_event);

    GhosttyMouseEncoder mouse_encoder = NULL;
    ghostty_mouse_encoder_new(NULL, &mouse_encoder);
    GhosttyMouseEvent mouse_event = NULL;
    ghostty_mouse_event_new(NULL, &mouse_event); // same (allocator, out*) pattern as above

    int last_cols = init_cols, last_rows = init_rows;

    while (!WindowShouldClose()) {
        if (pty_read(pty_fd, term) == PTY_READ_EOF) break;

        apply_resize(pty_fd, term, &last_cols, &last_rows, cell_w, cell_h, pad);
        send_key_events(pty_fd, key_encoder, key_event, term);
        send_mouse_events(pty_fd, mouse_encoder, mouse_event, term, cell_w, cell_h, pad);

        ghostty_render_state_update(render_state, term);

        BeginDrawing();
        ClearBackground(BLACK);
        render_terminal(render_state, row_iter, cells, term, font,
                         cell_w, cell_h, font_size, pad);
        EndDrawing();
    }

    ghostty_terminal_free(term);
    UnloadFont(font);
    CloseWindow();
    return 0;
}
```

 ---

 ## "Multi-window, like Ghostty/kitty" — what that actually means

 `libghostty` has zero window concept, so "multi-window" is entirely an application-level pattern: your own collection of independent `(pty_fd, GhosttyTerminal, GhosttyRenderState, encoders/events)` tuples — everything from Step 8's `main()` — each tied to one Raylib window, each pumped through the same per-frame loop:

 ```c
typedef struct {
    int pty_fd;
    pid_t child_pid;
    GhosttyTerminal term;
    GhosttyRenderState render_state;
    GhosttyKeyEncoder key_encoder;
    GhosttyKeyEvent key_event;
    GhosttyMouseEncoder mouse_encoder;
    GhosttyMouseEvent mouse_event;
    int last_cols, last_rows;
    // + whatever windowing-lib-specific window/context handle
} TerminalWindow;

TerminalWindow *windows[MAX_WINDOWS];
int window_count = 0;

// create_window()      == everything in Step 8's main() up to the
//                          `while (!WindowShouldClose())` line, run
//                          once per new window
// process_all_windows() == the loop body of that same while-loop,
//                          run once per window per frame
```

 Tabs/splits are the same idea one level down: multiple tuples sharing *one* window and one region of the framebuffer each, instead of one tuple per OS window.

 ---

 ## Where to go from here

 - **[ghostty-org/ghostling](https://github.com/ghostty-org/ghostling)** — the complete, buildable, MIT-licensed reference: full key/mouse encoding (including drag-to-scroll and any-event mouse tracking), 24-bit color + palette resolution, and Kitty graphics protocol support on top of everything built here.
- Its README documents what's deliberately left for *you* to build: tabs, splits, session management, a config file/GUI, search UI.
- Always benchmark `-DCMAKE_BUILD_TYPE=Release` builds — debug builds of `libghostty-vt` carry a lot of safety/correctness checking and are not representative of real performance.