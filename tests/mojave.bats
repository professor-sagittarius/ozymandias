#!/usr/bin/env bats

setup() {
    # Source the script without running main.
    source "$BATS_TEST_DIRNAME/../mojave"
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
