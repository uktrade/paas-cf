#!/usr/bin/env bash
set -e -u -o pipefail

cd "$(dirname "$0")/.."
root_dir="$(pwd)"

previous_commit="$(git log --format=%H --max-count 1 --skip 1 -- "config/buildpacks.yml")"

cd "tools/buildpacks"

go run email.go structs.go -old <(git show "$previous_commit:config/buildpacks.yml") -new <(git show "head:config/buildpacks.yml")

