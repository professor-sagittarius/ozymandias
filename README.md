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
   - `~/.local/share/opencode/` - session data and credentials (read-write)
   - `~/.gitconfig` - read-only, if present (so git commits have correct identity)

4. **Cleans up on exit** - strips the injected preamble from `AGENTS.md` and
   removes temp files.

## Requirements

- [Podman](https://podman.io)
- [jq](https://jqlang.org)
- opencode installed at `~/.opencode/bin/opencode`

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

Inside the container the following are auto-allowed without prompts:

- File reads, writes, edits, glob, grep
- General bash commands
- Web fetch and web search
- Git local operations (add, commit, diff, log, status, checkout)

The following require confirmation:

- `curl`, `wget`, `ssh`, `scp`
- `rm`, `mv`, `cp -f`, `chmod`, `chown`, `find -exec`
- Git remote operations: `push`, `pull`, `fetch`, `clone`
- Package managers: `npm`, `yarn`, `pip`, `cargo`, `apt`, `yum`, `brew`
- `docker`, `docker-compose`

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
