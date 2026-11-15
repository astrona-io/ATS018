#!/usr/bin/env bash
# Prints a JSON array of labs and playgrounds for a GitHub Actions matrix:
#   [{"kind":"lab","path":"sections/.../labs/lab-01"},
#    {"kind":"playground","path":"sections/.../playground"}, ...]
#
#   list-environments.sh                        # every section
#   list-environments.sh sections/section-040   # only these paths
#   list-environments.sh --changed-since <ref>  # environments changed since <ref>
#
# With --changed-since, a change to scripts/ or the labs workflow selects
# every section, because it can break any lab. Otherwise each lab or
# playground with a changed file in its own directory is selected: every
# environment is self-contained, so a change in one cannot break another.
# Changes to course pages, quizzes, astrona.yaml and TEACHING-COVERAGE.yaml
# select nothing here; the structure checks in the workflow's list job cover
# them. No match prints [].
set -euo pipefail
cd "$(dirname "$0")/../.."

paths=()
if [ "${1:-}" = "--changed-since" ]; then
  ref=${2:?usage: list-environments.sh --changed-since <ref>}
  changed=$(git diff --name-only "$ref"...HEAD)
  if grep -qE '^(scripts/|\.github/workflows/labs\.yml$)' <<<"$changed"; then
    paths=(sections)
  else
    # A deleted lab or playground has no directory left, so it is skipped.
    while read -r environment; do
      [ -d "$environment" ] && paths+=("$environment")
    done < <(grep -oE '^sections/section-[0-9]+/module-[0-9]+/(labs/lab-[0-9]+|playground)/' <<<"$changed" | sort -u)
  fi
  [ "${#paths[@]}" -gt 0 ] || { echo '[]'; exit 0; }
elif [ "$#" -gt 0 ]; then
  paths=("$@")
else
  paths=(sections)
fi

find "${paths[@]}" -name config.yaml \( -path '*/labs/lab-*/config.yaml' -o -path '*/playground/config.yaml' \) |
  sort |
  while read -r config; do
    dir=$(dirname "$config")
    case "$dir" in
      */playground) kind=playground ;;
      *) kind=lab ;;
    esac
    runtime=$(sed -n 's/^  type: //p' "$config" | head -n 1 | tr -d '"')
    runtime=${runtime:-kind}
    case "$runtime" in kind|qemu) ;; *) echo "Unsupported runtime: $runtime" >&2; exit 1 ;; esac
    printf '{"kind":"%s","path":"%s","runtime":"%s"}\n' "$kind" "$dir" "$runtime"
  done |
  jq -cs .
