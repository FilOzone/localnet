#!/bin/bash
set -e

LOCALNET="$( cd "$( dirname -- "$BASH_SOURCE" )" && pwd )"
LOTUS="$LOCALNET/lotus-local-net/lotus"

echo "Declaring sector $SECTOR_ID faulty on-chain..."
cd "$LOCALNET"
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
