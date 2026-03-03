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
