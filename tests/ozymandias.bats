#!/usr/bin/env bats

setup() {
	source "$BATS_TEST_DIRNAME/../ozymandias"
	GLOBAL_CONFIG_DIR="$BATS_TMPDIR/fixtures"
	mkdir -p "$GLOBAL_CONFIG_DIR"
	cat >"$GLOBAL_CONFIG_DIR/opencode.json" <<'EOF'
{
  "model": "test-model",
  "permission": {
    "bash": { "*": "ask" },
    "read": "ask",
    "write": "ask"
  }
}
EOF
	SANDBOX_CONFIG_FILE=""
	cat >"$GLOBAL_CONFIG_DIR/AGENTS.md" <<'EOF'
# Existing instructions

Be concise.
EOF
	SANDBOX_AGENTS_FILE=""
	SESSION_HASH=""
	# Create a minimal mock opencode binary so prerequisite tests are portable.
	printf '#!/bin/sh\n' >"$GLOBAL_CONFIG_DIR/mock-opencode"
	chmod +x "$GLOBAL_CONFIG_DIR/mock-opencode"
	OPENCODE_BIN="$GLOBAL_CONFIG_DIR/mock-opencode"
	OZYMANDIAS_POLICY_FILE="$BATS_TEST_DIRNAME/../ozymandias-policy.json"
}

teardown() {
	rm -rf "$BATS_TMPDIR/fixtures"
	if [[ -n "${SANDBOX_CONFIG_FILE:-}" ]]; then rm -f "$SANDBOX_CONFIG_FILE"; fi
	if [[ -n "${SANDBOX_AGENTS_FILE:-}" ]]; then rm -f "$SANDBOX_AGENTS_FILE"; fi
}

@test "parse_args: defaults PROJECT_DIR to PWD when no argument given" {
	parse_args
	[[ "$PROJECT_DIR" == "$PWD" ]]
}

@test "parse_args: sets PROJECT_DIR to absolute path of given argument" {
	parse_args "/tmp"
	[[ "$PROJECT_DIR" == "/tmp" ]]
}

@test "parse_args: resolves relative path to absolute" {
	parse_args "."
	[[ "$PROJECT_DIR" == "$PWD" ]]
}

@test "parse_args: rejects non-existent directory" {
	run parse_args "/nonexistent/path/that/does/not/exist"
	[[ "$status" -ne 0 ]]
}

@test "parse_args: -s flag sets SESSION_HASH" {
	parse_args -s "ses_abc123def456ghi789jkl01234"
	[[ "$SESSION_HASH" == "ses_abc123def456ghi789jkl01234" ]]
}

@test "parse_args: -s flag works alongside explicit project dir" {
	parse_args -s "ses_abc123def456ghi789jkl01234" "/tmp"
	[[ "$SESSION_HASH" == "ses_abc123def456ghi789jkl01234" ]]
	[[ "$PROJECT_DIR" == "/tmp" ]]
}

@test "parse_args: -s requires an argument" {
	run parse_args -s
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"requires"* ]]
}

@test "parse_args: -s rejects invalid session hash format" {
	run parse_args -s "not-a-valid-hash"
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"invalid session hash"* ]]
}

@test "parse_args: rejects unknown options" {
	run parse_args --unknown
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"unknown option"* ]]
}

@test "parse_args: rejects path containing a colon" {
	# Create a temp dir with a colon in the path by symlinking.
	# Colons in directory names are legal on Linux but break podman volume specs.
	# We test this via parse_args by mocking realpath output.
	local real_realpath
	real_realpath="$(command -v realpath)"
	realpath() { echo "/home/user/my:project"; }
	run parse_args "/tmp"
	unset -f realpath
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"colon"* ]]
}

@test "OPENCODE_BIN: uses default install path when present" {
	local fake_home
	fake_home="$(mktemp -d)"
	mkdir -p "$fake_home/.opencode/bin"
	printf '#!/bin/sh\n' >"$fake_home/.opencode/bin/opencode"
	chmod +x "$fake_home/.opencode/bin/opencode"
	result="$(HOME="$fake_home" bash -c 'source "$1"; echo "$OPENCODE_BIN"' _ "$BATS_TEST_DIRNAME/../ozymandias")"
	rm -rf "$fake_home"
	[[ "$result" == "$fake_home/.opencode/bin/opencode" ]]
}

@test "OPENCODE_BIN: falls back to opencode on PATH when default path absent" {
	local fake_bin fake_home
	fake_bin="$(mktemp -d)"
	fake_home="$(mktemp -d)"
	printf '#!/bin/sh\n' >"$fake_bin/opencode"
	chmod +x "$fake_bin/opencode"
	result="$(HOME="$fake_home" PATH="$fake_bin:$PATH" bash -c 'source "$1"; echo "$OPENCODE_BIN"' _ "$BATS_TEST_DIRNAME/../ozymandias")"
	rm -rf "$fake_bin" "$fake_home"
	[[ "$result" == "$fake_bin/opencode" ]]
}

@test "OPENCODE_BIN: resolves symlink on PATH to real binary path" {
	local fake_bin fake_home real_bin link_dir
	fake_bin="$(mktemp -d)"
	fake_home="$(mktemp -d)"
	link_dir="$(mktemp -d)"
	printf '#!/bin/sh\n' >"$fake_bin/opencode-real"
	chmod +x "$fake_bin/opencode-real"
	ln -s "$fake_bin/opencode-real" "$link_dir/opencode"
	result="$(HOME="$fake_home" PATH="$link_dir:$PATH" bash -c 'source "$1"; echo "$OPENCODE_BIN"' _ "$BATS_TEST_DIRNAME/../ozymandias")"
	rm -rf "$fake_bin" "$fake_home" "$link_dir"
	[[ "$result" == "$fake_bin/opencode-real" ]]
}

@test "check_prerequisites: passes when all required commands exist" {
	run check_prerequisites
	[[ "$status" -eq 0 ]]
}

@test "check_prerequisites: fails when podman is missing" {
	local fake_bin old_path
	fake_bin="$(mktemp -d)"
	old_path="$PATH"
	PATH="$fake_bin"
	run check_prerequisites
	PATH="$old_path"
	rm -rf "$fake_bin"
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"podman"* ]]
}

@test "check_prerequisites: fails when opencode binary is missing" {
	local old_bin
	old_bin="$OPENCODE_BIN"
	OPENCODE_BIN="/nonexistent/opencode"
	run check_prerequisites
	OPENCODE_BIN="$old_bin"
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"opencode"* ]]
}

@test "check_prerequisites: fails when policy file is missing" {
	local old_policy
	old_policy="$OZYMANDIAS_POLICY_FILE"
	OZYMANDIAS_POLICY_FILE="/nonexistent/ozymandias-policy.json"
	run check_prerequisites
	OZYMANDIAS_POLICY_FILE="$old_policy"
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"policy"* ]]
}

@test "check_prerequisites: fails when jq is missing" {
	local fake_bin old_path old_bin
	fake_bin="$(mktemp -d)"
	ln -s "$(command -v podman)" "$fake_bin/podman"
	old_path="$PATH"
	old_bin="$OPENCODE_BIN"
	PATH="$fake_bin"
	OPENCODE_BIN="$(command -v true)"
	run check_prerequisites
	PATH="$old_path"
	OPENCODE_BIN="$old_bin"
	rm -rf "$fake_bin"
	[[ "$status" -ne 0 ]]
	[[ "$output" == *"jq"* ]]
}

@test "generate_config: creates a temp file" {
	generate_config
	[[ -f "$SANDBOX_CONFIG_FILE" ]]
}

@test "generate_config: preserves non-permission fields from host config" {
	generate_config
	local model
	model="$(jq -r '.model' "$SANDBOX_CONFIG_FILE")"
	[[ "$model" == "test-model" ]]
}

@test "generate_config: sets read permission to allow" {
	generate_config
	local val
	val="$(jq -r '.permission.read' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "allow" ]]
}

@test "generate_config: sets write permission to allow" {
	generate_config
	local val
	val="$(jq -r '.permission.write' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "allow" ]]
}

@test "generate_config: sets bash catch-all to ask" {
	generate_config
	local val
	val="$(jq -r '.permission.bash["*"]' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "ask" ]]
}

@test "generate_config: policy allows ls" {
	generate_config
	local val
	val="$(jq -r '.permission.bash["ls*"]' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "allow" ]]
}

@test "generate_config: floor enforces curl as ask" {
	generate_config
	local val
	val="$(jq -r '.permission.bash["curl *"]' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "ask" ]]
}

@test "generate_config: floor enforces git push as ask" {
	generate_config
	local val
	val="$(jq -r '.permission.bash["git push*"]' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "ask" ]]
}

@test "generate_config: floor enforces rm as ask even when policy allows all" {
	local permissive_policy
	permissive_policy="$(mktemp --suffix=.json)"
	echo '{"permission":{"bash":{"*":"allow","rm *":"allow"},"read":"allow","edit":"allow","write":"allow","glob":"allow","grep":"allow","webfetch":"allow","websearch":"allow"}}' \
		>"$permissive_policy"
	OZYMANDIAS_POLICY_FILE="$permissive_policy" generate_config
	rm -f "$permissive_policy"
	local val
	val="$(jq -r '.permission.bash["rm *"]' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "ask" ]]
}

@test "inject_preamble: creates a temp file" {
	inject_preamble
	[[ -f "$SANDBOX_AGENTS_FILE" ]]
}

@test "inject_preamble: temp file starts with OZYMANDIAS:START sentinel" {
	inject_preamble
	head -1 "$SANDBOX_AGENTS_FILE" | grep -q "OZYMANDIAS:START"
}

@test "inject_preamble: temp file contains OZYMANDIAS:END sentinel" {
	inject_preamble
	grep -q "OZYMANDIAS:END" "$SANDBOX_AGENTS_FILE"
}

@test "inject_preamble: preamble appears before existing content" {
	inject_preamble
	local start_line existing_line
	start_line="$(grep -n "OZYMANDIAS:START" "$SANDBOX_AGENTS_FILE" | cut -d: -f1)"
	existing_line="$(grep -n "Existing instructions" "$SANDBOX_AGENTS_FILE" | cut -d: -f1)"
	[[ "$start_line" -lt "$existing_line" ]]
}

@test "inject_preamble: existing AGENTS.md content is preserved" {
	inject_preamble
	grep -q "Be concise." "$SANDBOX_AGENTS_FILE"
}

@test "strip_preamble: removes OZYMANDIAS:START sentinel" {
	inject_preamble
	echo "New agent instruction." >>"$SANDBOX_AGENTS_FILE"
	strip_preamble
	! grep -q "OZYMANDIAS:START" "$GLOBAL_CONFIG_DIR/AGENTS.md"
}

@test "strip_preamble: removes OZYMANDIAS:END sentinel" {
	inject_preamble
	strip_preamble
	! grep -q "OZYMANDIAS:END" "$GLOBAL_CONFIG_DIR/AGENTS.md"
}

@test "strip_preamble: preserves original content" {
	inject_preamble
	strip_preamble
	grep -q "Be concise." "$GLOBAL_CONFIG_DIR/AGENTS.md"
}

@test "strip_preamble: preserves content added during session" {
	inject_preamble
	echo "New agent instruction." >>"$SANDBOX_AGENTS_FILE"
	strip_preamble
	grep -q "New agent instruction." "$GLOBAL_CONFIG_DIR/AGENTS.md"
}

@test "strip_preamble: is idempotent when preamble not present" {
	# Simulate the case where sandbox died before inject_preamble ran.
	# SANDBOX_AGENTS_FILE points to a copy without sentinels.
	local no_preamble_file
	no_preamble_file="$(mktemp)"
	cp "$GLOBAL_CONFIG_DIR/AGENTS.md" "$no_preamble_file"
	SANDBOX_AGENTS_FILE="$no_preamble_file"
	strip_preamble
	grep -q "Be concise." "$GLOBAL_CONFIG_DIR/AGENTS.md"
	! grep -q "OZYMANDIAS" "$GLOBAL_CONFIG_DIR/AGENTS.md"
	rm -f "$no_preamble_file"
	SANDBOX_AGENTS_FILE=""
}

@test "cleanup: removes SANDBOX_CONFIG_FILE" {
	generate_config
	local f="$SANDBOX_CONFIG_FILE"
	[[ -f "$f" ]]
	cleanup
	[[ ! -f "$f" ]]
}

@test "cleanup: removes SANDBOX_AGENTS_FILE" {
	inject_preamble
	local f="$SANDBOX_AGENTS_FILE"
	[[ -f "$f" ]]
	cleanup
	[[ ! -f "$f" ]]
}

@test "cleanup: writes AGENTS.md back without preamble" {
	inject_preamble
	echo "Appended during session." >>"$SANDBOX_AGENTS_FILE"
	cleanup
	grep -q "Appended during session." "$GLOBAL_CONFIG_DIR/AGENTS.md"
	! grep -q "OZYMANDIAS:START" "$GLOBAL_CONFIG_DIR/AGENTS.md"
}

@test "launch_container: dry run passes -s flag to opencode when session set" {
	parse_args -s "ses_abc123def456ghi789jkl01234" "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"-s ses_abc123def456ghi789jkl01234"* ]]
}

@test "launch_container: dry run omits -s flag when no session set" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" != *" -s "* ]]
}

@test "launch_container: resume line prints known session hash when SESSION_HASH set" {
	local fake_bin
	fake_bin="$(mktemp -d)"
	printf '#!/bin/sh\nexit 0\n' >"$fake_bin/podman"
	chmod +x "$fake_bin/podman"
	parse_args -s "ses_abc123def456ghi789jkl01234" "/tmp"
	generate_config
	inject_preamble
	PATH="$fake_bin:$PATH" run launch_container
	rm -rf "$fake_bin"
	[[ "$output" == *"ozymandias -s ses_abc123def456ghi789jkl01234 /tmp"* ]]
}

@test "launch_container: dry run includes project dir mount at same path" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"--volume /tmp:/tmp"* ]]
}

@test "launch_container: dry run mounts opencode binary read-only" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"${OPENCODE_BIN}:${OPENCODE_BIN}:ro"* ]]
}

@test "launch_container: dry run mounts opencode data dir read-write" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"${OPENCODE_DATA_DIR}:${OPENCODE_DATA_DIR}"* ]]
}

@test "launch_container: dry run overlays auth.json read-only when present" {
	local fake_data
	fake_data="$(mktemp -d)"
	echo '{}' >"$fake_data/auth.json"
	OPENCODE_DATA_DIR="$fake_data" parse_args "/tmp"
	OPENCODE_DATA_DIR="$fake_data" generate_config
	OPENCODE_DATA_DIR="$fake_data" inject_preamble
	OPENCODE_DATA_DIR="$fake_data" DRY_RUN=1 run launch_container
	rm -rf "$fake_data"
	[[ "$output" == *"${fake_data}/auth.json:${fake_data}/auth.json:ro"* ]]
}

@test "launch_container: dry run omits auth.json overlay when absent" {
	local fake_data
	fake_data="$(mktemp -d)"
	OPENCODE_DATA_DIR="$fake_data" parse_args "/tmp"
	OPENCODE_DATA_DIR="$fake_data" generate_config
	OPENCODE_DATA_DIR="$fake_data" inject_preamble
	OPENCODE_DATA_DIR="$fake_data" DRY_RUN=1 run launch_container
	rm -rf "$fake_data"
	[[ "$output" != *"auth.json"* ]]
}

@test "launch_container: dry run overlays bin read-only when present" {
	local fake_data
	fake_data="$(mktemp -d)"
	mkdir "$fake_data/bin"
	OPENCODE_DATA_DIR="$fake_data" parse_args "/tmp"
	OPENCODE_DATA_DIR="$fake_data" generate_config
	OPENCODE_DATA_DIR="$fake_data" inject_preamble
	OPENCODE_DATA_DIR="$fake_data" DRY_RUN=1 run launch_container
	rm -rf "$fake_data"
	[[ "$output" == *"${fake_data}/bin:${fake_data}/bin:ro"* ]]
}

@test "launch_container: dry run omits bin overlay when absent" {
	local fake_data
	fake_data="$(mktemp -d)"
	OPENCODE_DATA_DIR="$fake_data" parse_args "/tmp"
	OPENCODE_DATA_DIR="$fake_data" generate_config
	OPENCODE_DATA_DIR="$fake_data" inject_preamble
	OPENCODE_DATA_DIR="$fake_data" DRY_RUN=1 run launch_container
	rm -rf "$fake_data"
	[[ "$output" != *"${fake_data}/bin:"* ]]
}

@test "launch_container: dry run mounts sandbox config as opencode.json read-only" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"${SANDBOX_CONFIG_FILE}:${GLOBAL_CONFIG_DIR}/opencode.json:ro"* ]]
}

@test "launch_container: dry run mounts sandbox agents file as AGENTS.md" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"${SANDBOX_AGENTS_FILE}:${GLOBAL_CONFIG_DIR}/AGENTS.md"* ]]
}

@test "launch_container: dry run mounts config dir read-only" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"${GLOBAL_CONFIG_DIR}:${GLOBAL_CONFIG_DIR}:ro"* ]]
}

@test "launch_container: dry run sets working directory to project dir" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"--workdir /tmp"* ]]
}

@test "launch_container: dry run uses ubuntu:24.04 image" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"ubuntu:24.04"* ]]
}

@test "launch_container: dry run sets HOME env to match host" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	DRY_RUN=1 run launch_container
	[[ "$output" == *"--env HOME=${HOME}"* ]]
}

@test "launch_container: dry run passes TERM to container" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	TERM=xterm-256color DRY_RUN=1 run launch_container
	[[ "$output" == *"--env TERM=xterm-256color"* ]]
}

@test "launch_container: dry run passes COLORTERM to container" {
	parse_args "/tmp"
	generate_config
	inject_preamble
	COLORTERM=truecolor DRY_RUN=1 run launch_container
	[[ "$output" == *"--env COLORTERM=truecolor"* ]]
}

@test "launch_container: dry run mounts gitconfig read-only when present" {
	local fake_home
	fake_home="$(mktemp -d)"
	touch "$fake_home/.gitconfig"
	HOME="$fake_home" parse_args "/tmp"
	HOME="$fake_home" generate_config
	HOME="$fake_home" inject_preamble
	HOME="$fake_home" DRY_RUN=1 run launch_container
	rm -rf "$fake_home"
	[[ "$output" == *"${fake_home}/.gitconfig:${fake_home}/.gitconfig:ro"* ]]
}

@test "launch_container: dry run omits gitconfig mount when absent" {
	local fake_home
	fake_home="$(mktemp -d)"
	HOME="$fake_home" parse_args "/tmp"
	HOME="$fake_home" generate_config
	HOME="$fake_home" inject_preamble
	HOME="$fake_home" DRY_RUN=1 run launch_container
	rm -rf "$fake_home"
	[[ "$output" != *".gitconfig"* ]]
}

@test "warn_gitconfig_includes: emits warning when [include] present" {
	local fake_home
	fake_home="$(mktemp -d)"
	printf '[include]\n\tpath = ~/.gitconfig.d/work\n' >"$fake_home/.gitconfig"
	HOME="$fake_home" run warn_gitconfig_includes
	rm -rf "$fake_home"
	[[ "$output" == *"[include]"* ]]
}

@test "warn_gitconfig_includes: no warning when [include] absent" {
	local fake_home
	fake_home="$(mktemp -d)"
	printf '[user]\n\tname = Test\n' >"$fake_home/.gitconfig"
	HOME="$fake_home" run warn_gitconfig_includes
	rm -rf "$fake_home"
	[[ -z "$output" ]]
}

@test "warn_gitconfig_includes: no warning when gitconfig absent" {
	local fake_home
	fake_home="$(mktemp -d)"
	HOME="$fake_home" run warn_gitconfig_includes
	rm -rf "$fake_home"
	[[ -z "$output" ]]
}

@test "end-to-end: DRY_RUN produces a valid podman run command" {
	DRY_RUN=1 run "$BATS_TEST_DIRNAME/../ozymandias" "/tmp"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"podman run"* ]]
	[[ "$output" == *"ubuntu:24.04"* ]]
	[[ "$output" == *"--workdir /tmp"* ]]
}
