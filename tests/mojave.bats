#!/usr/bin/env bats

setup() {
	source "$BATS_TEST_DIRNAME/../mojave"
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
}

teardown() {
	rm -rf "$BATS_TMPDIR/fixtures"
	if [[ -n "${SANDBOX_CONFIG_FILE:-}" ]]; then rm -f "$SANDBOX_CONFIG_FILE"; fi
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

@test "generate_config: sets bash catch-all to allow" {
	generate_config
	local val
	val="$(jq -r '.permission.bash["*"]' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "allow" ]]
}

@test "generate_config: keeps curl as ask" {
	generate_config
	local val
	val="$(jq -r '.permission.bash["curl *"]' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "ask" ]]
}

@test "generate_config: keeps git push as ask" {
	generate_config
	local val
	val="$(jq -r '.permission.bash["git push*"]' "$SANDBOX_CONFIG_FILE")"
	[[ "$val" == "ask" ]]
}
