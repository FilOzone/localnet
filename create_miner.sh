#!/bin/bash

# Worker must be an account actor (t1/t3); default wallet is the BLS genesis key
WORKER=$(./lotus wallet default)
echo "WORKER=$WORKER" >&2
if [ -z "$WORKER" ]; then
    echo "ERROR: could not determine worker address" >&2
    exit 1
fi

# Capture all output (lotus-shed logs via log.Infof to stderr)
OUTPUT=$(./lotus-shed miner create "$WORKER" "$f4" "$WORKER" 2KiB 2>&1)
echo "$OUTPUT" >&2

export MINER_ID=$(echo "$OUTPUT" | grep "New miners address is:" | sed 's/.*New miners address is: \(t0[0-9]*\).*/\1/')
if [ -z "$MINER_ID" ]; then
    echo "ERROR: could not parse MINER_ID from lotus-shed output" >&2
    exit 1
fi
echo "$MINER_ID"
