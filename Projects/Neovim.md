[[Neovim issues]]

Neovim contribution guidelines quickstart:

Here's a complete workflow based on Neovim's actual contribution guidelines:

### 1. Find something to work on

bash

```bash
# Read the dev docs first — this is important
nvim-dev -c ":help dev" -c "only"
nvim-dev -c ":help dev-quickstart" -c "only"
```

Good places to find issues: github.com/neovim/neovim/issues with labels `good-first-issue` or `complexity:low`.

---

### 2. Create a branch

Never work on `master` directly:

bash

```bash
cd ~/neovim
git fetch upstream
git rebase upstream/master      # stay up to date
git checkout -b fix/my-fix-name # descriptive branch name
```

---

### 3. Make your changes, then build & test

bash

```bash
# After editing source files:
make -j$(nproc)

# Run the test suite (required before submitting)
make test

# Run only a specific test file (faster):
make functionaltest TEST_FILE=test/functional/ui/float_spec.lua

# Check formatting/lint:
make lint
make lintcommit   # checks your commit message format
```

---

### 4. Commit message format

Neovim follows conventional commits. Keep the subject under 72 characters and concisely describe the problem and solution in the body. The format is: [GitHub](https://github.com/neovim/neovim/blob/master/CONTRIBUTING.md)

```
type(scope): short description

Longer explanation of the problem and how this commit solves it.
```

Valid types: `fix`, `feat`, `refactor`, `docs`, `test`, `ci`, `build`, `chore`

Examples:

```
fix(lsp): handle nil client in on_attach callback
feat(treesitter): add support for injected languages
docs(api): clarify nvim_buf_set_text behavior
```

For breaking API changes, use `!` after the type and add a `BREAKING CHANGE` footer. [GitHub](https://github.com/neovim/neovim/blob/master/CONTRIBUTING.md)

---

### 5. Push and open the PR

bash

```bash
git push origin fix/my-fix-name
```

Then open a PR on GitHub against `neovim/neovim:master` (not your fork's master).

In the PR description follow this structure:

- **Problem**: what issue does this fix / what is missing
- **Solution**: how you solved it
- Link any related issues with `Fixes #NNNN`

---

### 6. CI will run automatically

Each PR must pass the automated builds on Cirrus CI and GitHub Actions. CI builds are compiled with `-Werror`, so compiler warnings will fail the build. [GitHub](https://github.com/neovim/neovim/blob/master/CONTRIBUTING.md)

You can run ASAN locally to catch memory issues before pushing:

bash

```bash
CC=clang make CMAKE_FLAGS="-DENABLE_ASAN_UBSAN=ON"
```

---

### Day-to-day cheatsheet

bash

```bash
git fetch upstream && git rebase upstream/master  # sync with upstream
make -j$(nproc)                                   # rebuild
nvim-dev somefile.lua                             # test your build
make test                                         # run tests
make lint && make lintcommit                      # check before committing
git push origin your-branch                       # push changes
```

The most important thing Neovim maintainers care about is: a clear problem statement, tests for your change, and clean commit messages.



