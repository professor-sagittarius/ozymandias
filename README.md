# mojave

Runs [opencode](https://opencode.ai) inside a Podman container so the AI agent
operates on a limited filesystem slice rather than your whole system.

## What it does

When you launch a project with mojave:

1. **Generates a sandboxed config** - merges your existing `opencode.json` with
   a permission policy that auto-allows file reads/writes/edits and requires
   confirmation for destructive or network operations (curl, rm, git push, package
   managers, etc.).

2. **Injects a sandbox preamble** into your `AGENTS.md` so the agent knows its
   filesystem constraints and behavioral rules up front.

3. **Launches a container** (`ubuntu:24.04` via Podman) with only these paths
   mounted:
   - The project directory (read-write)
   - `~/.config/opencode/` - sandboxed config and AGENTS.md (the original
     `opencode.json` is replaced by the merged sandbox version)
   - `~/.local/share/opencode/` - session database and runtime files (read-write);
     `auth.json` and `bin/` within this directory are read-only
   - `~/.gitconfig` - read-only, if present (so git commits have correct identity);
     `[include]` directives referencing other files will not resolve inside the
     container - mojave warns if any are detected

4. **Cleans up on exit** - strips the injected preamble from `AGENTS.md` and
   removes temp files.

## Requirements

- [Podman](https://podman.io)
- [jq](https://jqlang.org)
- opencode binary, found via (in order):
  1. `$OPENCODE_BIN` environment variable
  2. `~/.opencode/bin/opencode` (default install path)
  3. `opencode` on `$PATH` (symlinks are resolved to the real binary)

## Installation

```sh
./install.sh            # installs to ~/.local/bin/mojave
./install.sh /usr/local/bin  # or a custom directory
```

Make sure the install directory is on your `PATH`.

## Usage

```sh
mojave [project-dir]
```

`project-dir` defaults to the current directory. The path must not contain a
colon (podman volume spec constraint).

## Permission policy

Permissions are defined in `mojave-policy.json`, installed alongside the binary.
You can edit this file to customize what requires confirmation. The defaults are:

**Auto-allowed:**
- File operations: read, write, edit, glob, grep, webfetch, websearch
- Bash file inspection: `ls`, `cat`, `head`, `tail`, `stat`, `diff`, `wc`, `du`, `df`
- Bash text processing: `grep`, `sed`, `awk`, `sort`, `uniq`, `cut`, `tr`
- Bash shell utilities: `echo`, `printf`, `pwd`, `env`, `date`, `which`, `whoami`, `ps`
- Directory creation: `mkdir`, `touch`
- Git local operations: `add`, `commit`, `diff`, `log`, `status`, `checkout`, `branch`, `stash`, `merge`, `rebase`, `show`, `tag`, `config`
- Common runtimes: `python`, `node`, `ruby`, `go`, `make`, `bash`, `sh`
- All other bash commands: require confirmation (`"*": "ask"`)

**Always require confirmation (not overridable):**

These floor constraints are hardcoded in mojave and cannot be weakened by editing
`mojave-policy.json`:

- File removal and overwriting: `rm`, `mv`, `cp -f`, `find -exec`
- Network tools: `curl`, `wget`, `ssh`, `scp`
- Git remote operations: `push`, `pull`, `fetch`, `clone`

## Overrides

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_BIN` | `~/.opencode/bin/opencode` | Path to opencode binary |
| `GLOBAL_CONFIG_DIR` | `~/.config/opencode` | opencode config directory |
| `OPENCODE_DATA_DIR` | `~/.local/share/opencode` | opencode data directory |
| `CONTAINER_IMAGE` | `ubuntu:24.04` | Container image to use |

## Tests

```sh
bats tests/mojave.bats
```

Requires [bats-core](https://github.com/bats-core/bats-core).
