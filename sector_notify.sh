#!/bin/bash
set -e

cd "$( dirname -- "$BASH_SOURCE" )"

OUTPUT=$(go run -tags 2k ./cmd/sector-notify 2>&1 | tee /dev/stderr)
export SECTOR_ID=$(echo "$OUTPUT" | grep "Using sector number:" | awk '{print $NF}')
