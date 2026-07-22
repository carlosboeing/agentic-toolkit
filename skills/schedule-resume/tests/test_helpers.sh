#!/bin/sh

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

assert_equal() {
  expected=$1
  actual=$2
  message=$3

  if [ "$expected" != "$actual" ]; then
    fail "$message (expected '$expected', got '$actual')"
  fi
}

assert_file_exists() {
  file=$1
  message=$2

  [ -f "$file" ] || fail "$message (missing '$file')"
}

assert_path_not_exists() {
  path=$1
  message=$2

  [ ! -e "$path" ] || fail "$message (unexpected '$path')"
}

assert_json_equal() {
  expected=$1
  actual=$2
  message=$3

  if ! jq -e --argjson expected "$expected" '. == $expected' "$actual" >/dev/null; then
    fail "$message"
  fi
}

assert_command_fails() {
  message=$1
  shift

  if "$@" >/dev/null 2>&1; then
    fail "$message"
  fi
}

pass() {
  printf 'ok - %s\n' "$1"
}
