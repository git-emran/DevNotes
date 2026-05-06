The two big external APIs you'll need are:

- a way to talk to the process (shell, NeoVim, whatever) running inside the terminal
    
- a way to draw the terminal output to the screen
    

For the first one, you'll need to use the Unix "pseudoterminal" API, probably something like [`nix::pty::forkpty()`](https://docs.rs/nix/0.20.0/nix/pty/fn.forkpty.html). The idea is that you get a "master" file descriptor and a "slave" file descriptor; you launch a new process with its stdin/stdout/stderr set to the slave file descriptor, then you can read its output from the master, write its input to the master, and apply configuration changes (like "window size") to the master and they'll be communicated to the child process.

For the second one, that's tricky... there's a lot of Rust bindings for low-level graphics APIs like OpenGL or Vulkan, but you don't need that fancy stuff and they don't provide things you do need, like "draw text". There's rust bindings for high-level APIs like GTK+ and Windows, but they're all about buttons and sliders and it takes some messing around to get a canvas to just draw on. I don't have any recommendations here, you'll have to figure it out on your own.

Once you have those two, it's down to the fun part: building a data structure to represent the terminal emulator state, decoding terminal control sequences to update that data structure, and encoding control sequences to represent key-press and mouse events. You'll definitely get familiar with things like [the VT220 Programmer's Reference Manual](https://vt100.net/docs/vt220-rm/contents.html), the [xterm Control Sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html) document, and [vttest](https://invisible-island.net/vttest/vttest.html).

You _don't_ need to care about terminal UI libraries like ncurses, since they just produce control sequences like those documented above - if you handle the control sequence correctly, you'll handle it whether it was produced by ncurses or by hard-coding.

Oh, you might also find the `/usr/bin/script` tool handy - it lets you run a terminal app and log its output, including all the terminal control sequences. That means if your terminal misbehaves with a given app, you can record it and feed the recording into your terminal emulator repeatedly to test it, instead of having to manually run the application every time.