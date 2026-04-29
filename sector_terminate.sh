#!/bin/bash
set -e

LOCALNET="$( cd "$( dirname -- "$BASH_SOURCE" )" && pwd )"
LOTUS_SHED="$LOCALNET/lotus-local-net/lotus-shed"

echo "Looking up sector partition..."
cd "$LOCALNET"
PARTITION_OUTPUT=$(go run -tags 2k ./cmd/sector-partition 2>&1)
echo "$PARTITION_OUTPUT"
DEADLINE=$(echo "$PARTITION_OUTPUT" | grep "^DEADLINE=" | cut -d= -f2-)
PARTITION=$(echo "$PARTITION_OUTPUT" | grep "^PARTITION=" | cut -d= -f2-)
echo "Deadline: $DEADLINE  Partition: $PARTITION"

echo "Verifying sectorExpired is rejected before TerminateSectors..."
PRE_RECEIPT=$(cast send "$DEAL_ADDRESS" \
    "sectorExpired(uint64,int64,int64,address)" \
    "$SECTOR_ID" "$DEADLINE" "$PARTITION" "$SENDER_ADDRESS" \
    --private-key "$SENDER_KEY" \
    --rpc-url "${API_URL}/rpc/v1" \
    --gas-limit 500000000 2>&1 || true)
echo "$PRE_RECEIPT"

PRE_STATUS=$(echo "$PRE_RECEIPT" | grep "^status" | awk '{print $2}')
if [ "$PRE_STATUS" = "1" ]; then
    echo "sectorExpired unexpectedly succeeded before TerminateSectors"
    exit 1
fi
echo "sectorExpired correctly rejected before TerminateSectors (status=$PRE_STATUS)"

echo "Terminating sector $SECTOR_ID on-chain..."
"$LOTUS_SHED" sectors terminate --actor "$MINER_ID" --really-do-it "$SECTOR_ID"

echo "Verifying sectorRecovered is rejected after TerminateSectors..."
RECOVERY_RECEIPT=$(cast send "$DEAL_ADDRESS" \
    "sectorRecovered(uint64,int64,int64)" \
    "$SECTOR_ID" "$DEADLINE" "$PARTITION" \
    --private-key "$SENDER_KEY" \
    --rpc-url "${API_URL}/rpc/v1" \
    --gas-limit 500000000 2>&1 || true)
echo "$RECOVERY_RECEIPT"

RECOVERY_STATUS=$(echo "$RECOVERY_RECEIPT" | grep "^status" | awk '{print $2}')
if [ "$RECOVERY_STATUS" = "1" ]; then
    echo "sectorRecovered unexpectedly succeeded after TerminateSectors"
    exit 1
fi
echo "sectorRecovered correctly rejected after TerminateSectors (status=$RECOVERY_STATUS)"

echo "Calling sectorExpired on deal contract..."
RECEIPT=$(cast send "$DEAL_ADDRESS" \
    "sectorExpired(uint64,int64,int64,address)" \
    "$SECTOR_ID" "$DEADLINE" "$PARTITION" "$SENDER_ADDRESS" \
    --private-key "$SENDER_KEY" \
    --rpc-url "${API_URL}/rpc/v1" \
    --gas-limit 500000000)
echo "$RECEIPT"

TX_STATUS=$(echo "$RECEIPT" | grep "^status" | awk '{print $2}')

if [ "$TX_STATUS" != "1" ]; then
    echo "sectorExpired failed (status=$TX_STATUS)"
    exit 1
fi

echo "sectorExpired succeeded"
