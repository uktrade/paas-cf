#!/bin/sh

set -e
set -u

TESTS_DIR="${1}"
shift

cd "${TESTS_DIR}"
export GOPATH
GOPATH="${GOPATH}:$(pwd)}"
godep restore
go test -ginkgo.v "${@}"
