#!/bin/sh

set -eu

godep restore

if [ -n "${GINKGO_FOCUS:-}" ]; then
  ginkgo -v -p -nodes=16 -focus="${GINKGO_FOCUS}"
else
  ginkgo -v -p -nodes=16
fi
