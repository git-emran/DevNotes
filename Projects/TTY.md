
First of all, this PS1 thing is weird enough for people unfamiliar with the Linux shell and terminal (yes shell and terminal are not the same thing and I will dissect this in this post). To start off, PS1 is not even an environment variable. It is a shell variable (more specifically, a bourne shell variable that bash uses).

| Element | Description                                                                                  |
| ------- | -------------------------------------------------------------------------------------------- |
| `\[`    | Starts a string of non-printing characters                                                   |
| `\[`    | Starts a string of non-printing characters                                                   |
| `\033[` | Starts the SGR parameters. \033 can also be represented as \E or \x1b in different contexts. |

## Where is the terminal?

Fair enough, whoever is reading this might be a bit impatient to start typing code to create a very simple terminal on their own. However, some concepts must be understood before jumping into the code. I think that the best way to understand all the moving parts of a terminal emulator is to start with simpler mental models first. The diagram below shows a very simplified abstraction of terminal emulator architecture that should help building up confidence before coding.

## The main components
#### The terminal emulator

The terminal emulator is a graphical application that allows you to type in the commands and interact with your ***nix** operational system. Examples of a terminal emulator are gnome-terminal, Alacrity, ST ([Simple Terminal](https://st.suckless.org/)), iterm from MacOS, xterm and many many more. At the time of this writing I found a page with a list of [30+ Linux Terminal Emulators](https://linuxblog.io/linux-terminal-emulators/).