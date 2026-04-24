#!/bin/bash
set -e

cd "$( dirname -- "$BASH_SOURCE" )"

OUTPUT=$(go run ./cmd/prepare-piece 2>&1)
echo "$OUTPUT" >&2

export PIECE_FILE=$(echo "$OUTPUT" | grep "^PIECE_FILE=" | cut -d= -f2-)
export PIECE_DIGEST=$(echo "$OUTPUT" | grep "^PIECE_DIGEST=" | cut -d= -f2-)
echo "$PIECE_DIGEST"
