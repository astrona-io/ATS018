#!/bin/sh
# Test script for scout: checks that VERSION exists and holds a version number.
set -eu
echo "Checking VERSION"
test -f VERSION
grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' VERSION
printf "Tests passed for scout %s\n" "$(cat VERSION)"
