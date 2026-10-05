Here is a comprehensive guide to understanding why C/C++ LSPs can't find header files and how to fix it in any project.

---

### 1. Why LSPs Can't Find Headers

Unlike languages with package managers (like Python, Go, or Rust), C/C++ compilers and LSPs do not recursively scan your project for header files.

When you write `#include "my_header.h"`, the LSP only searches:

1. The **current directory** of the source file.
2. The **include search paths** explicitly passed to it (e.g. `-I<path>`).
3. Standard **system directories** (e.g. `/usr/include`).

If your header lives in another folder (such as `common/`, `include/`, or `../shared/`), you must tell the LSP where to look.

---

### 2. Solution by LSP Engine / Tool

#### A. If using `clangd` (VS Code Clangd, Neovim, Emacs, Zed, Antigravity)

Place a ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/document.svg)

`.clangd` file in the root of your project:

```
yamlCompileFlags:  Add:    - "-Ipath/to/headers"     # Relative to project root    - "-I../path/to/headers"  # For source files located in subfolders    - "-I."    - "-I.."    - "-D_GNU_SOURCE"         # Required for Linux/POSIX extensions    - "-std=c17"              # Or -std=c11, -std=c++20, etc.
```

> **Tip:** You can also use ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/document.svg)
>
> `compile_flags.txt` in the project root (one flag per line):
>
> ```
> text-Icommon-I../common-Iinclude-D_GNU_SOURCE-std=c17
> ```

---

#### B. For CMake / Make / Meson Projects (`compile_commands.json`)

The gold standard for large or complex C/C++ projects is a **Compilation Database** (`compile_commands.json`).

1. **CMake**:

   ```
   bashcmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build# Symlink it to project root so clangd discovers it:ln -s build/compile_commands.json .
   ```
2. **Make / Makefiles** (using `bear`):

   ```
   bash# Install bear (brew install bear or apt install bear)bear -- make
   ```

   This records exact compiler calls and automatically generates `compile_commands.json`.

---

#### C. If using Microsoft C/C++ Extension (`cpptools` in VS Code)

Configure ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/brackets-yellow.svg)

`.vscode/c_cpp_properties.json`:

```json
json{  "configurations": [    {      "name": "C/C++",      "includePath": [        "${workspaceFolder}/**",        "${workspaceFolder}/common",        "${workspaceFolder}/include"      ],      "defines": ["_GNU_SOURCE"],      "cStandard": "c17"    }  ],  "version": 4}
```

---

### 3. Common Traps to Watch Out For

1. **Header Name Shadowing**:
  - **Never** name custom helper files after standard library headers (e.g. `time.h`, `string.h`, `stdio.h`, `types.h`).
  - If a folder contains `time.h`, any `#include <time.h>` from system libraries might pull in your local file instead and break standard types (like `struct tm`, `strftime`, etc.).
2. **Relative Subdirectory Includes**:
  - If your source file is nested (e.g. `chapter02/prog.c`), `-Icommon` will resolve from the root, while `-I../common` will resolve when compiling directly inside `chapter02/`. Adding both ensures it works in both contexts.
3. **Restarting the LSP**:
  - After creating or modifying `.clangd` or `compile_flags.txt`, restart the Language Server or reload your editor window (e.g. `Clangd: Restart language server` or `Developer: Reload Window`).