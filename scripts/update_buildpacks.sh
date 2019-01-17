#!/usr/bin/env bash
set -e -u -o pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
temp_file="$(mktemp -t buildpacks.yml)"

cd "$root_dir/tools/buildpacks"
go run main.go structs.go < "$root_dir/config/buildpacks.yml" > "$temp_file"

cp "$temp_file" "$root_dir/config/buildpacks.yml"

