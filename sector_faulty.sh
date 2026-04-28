#!/bin/bash
set -e

LOCALNET="$( cd "$( dirname -- "$BASH_SOURCE" )" && pwd )"
LOTUS="$LOCALNET/lotus-local-net/lotus"

echo "Looking up sector partition..."
cd "$LOCALNET"
PARTITION_OUTPUT=$(go run -tags 2k ./cmd/sector-partition 2>&1)
echo "$PARTITION_OUTPUT"

PRE_DEADLINE=$(echo "$PARTITION_OUTPUT" | grep "^DEADLINE=" | cut -d= -f2-)
PRE_PARTITION=$(echo "$PARTITION_OUTPUT" | grep "^PARTITION=" | cut -d= -f2-)
echo "Pre-fault deadline: $PRE_DEADLINE  partition: $PRE_PARTITION"

echo "Verifying sectorFaulty is rejected before DeclareFaults..."
PRE_RECEIPT=$(cast send "$DEAL_ADDRESS" \
    "sectorFaulty(uint64,int64,int64,address)" \
    "$SECTOR_ID" "$PRE_DEADLINE" "$PRE_PARTITION" "$SENDER_ADDRESS" \
    --private-key "$SENDER_KEY" \
    --rpc-url "${API_URL}/rpc/v1" \
    --gas-limit 500000000 2>&1 || true)
echo "$PRE_RECEIPT"

PRE_STATUS=$(echo "$PRE_RECEIPT" | grep "^status" | awk '{print $2}')
if [ "$PRE_STATUS" = "1" ]; then
    echo "sectorFaulty unexpectedly succeeded before DeclareFaults"
    exit 1
fi
echo "sectorFaulty correctly rejected before DeclareFaults (status=$PRE_STATUS)"

echo "Declaring sector $SECTOR_ID faulty on-chain..."
OUTPUT=$(go run -tags 2k ./cmd/declare-faults 2>&1 | tee /dev/stderr)

DEADLINE=$(echo "$OUTPUT" | grep "^DEADLINE=" | cut -d= -f2-)
PARTITION=$(echo "$OUTPUT" | grep "^PARTITION=" | cut -d= -f2-)
echo "Deadline: $DEADLINE  Partition: $PARTITION"

RECEIPT=$(cast send "$DEAL_ADDRESS" \
    "sectorFaulty(uint64,int64,int64,address)" \
    "$SECTOR_ID" "$DEADLINE" "$PARTITION" "$SENDER_ADDRESS" \
    --private-key "$SENDER_KEY" \
    --rpc-url "${API_URL}/rpc/v1" \
    --gas-limit 500000000)
echo "$RECEIPT"

TX_STATUS=$(echo "$RECEIPT" | grep "^status" | awk '{print $2}')
TX_HASH=$(echo "$RECEIPT"  | grep "^transactionHash" | awk '{print $2}')

if [ "$TX_STATUS" != "1" ]; then
    echo "sectorFaulty failed (status=$TX_STATUS), getting trace..."
    MSG_CID=$("$LOTUS" eth get-message-cid-by-transaction-hash "$TX_HASH" 2>&1 | tail -1)
    echo "Message CID: $MSG_CID"
    "$LOTUS" state replay --show-trace "$MSG_CID" || true
    exit 1
fi

echo "Verifying sectorRecovered is rejected after fault declaration..."
RECOVERY_RECEIPT=$(cast send "$DEAL_ADDRESS" \
    "sectorRecovered(uint64,int64,int64)" \
    "$SECTOR_ID" "$DEADLINE" "$PARTITION" \
    --private-key "$SENDER_KEY" \
    --rpc-url "${API_URL}/rpc/v1" \
    --gas-limit 500000000 2>&1 || true)
echo "$RECOVERY_RECEIPT"

RECOVERY_STATUS=$(echo "$RECOVERY_RECEIPT" | grep "^status" | awk '{print $2}')
if [ "$RECOVERY_STATUS" = "1" ]; then
    echo "sectorRecovered unexpectedly succeeded after fault declaration"
    exit 1
fi
echo "sectorRecovered correctly rejected (status=$RECOVERY_STATUS)"
