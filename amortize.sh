#!/bin/bash
set -e

LOCALNET="$( cd "$( dirname -- "$BASH_SOURCE" )" && pwd )"
LOTUS="$LOCALNET/lotus-local-net/lotus"

echo "Deal:     $DEAL_ADDRESS"
DEAL_ID=$("$LOTUS" evm stat "$DEAL_ADDRESS" | grep "ID address:" | awk '{print $NF}')
echo "Deal ID:  $DEAL_ID"

cast call "$DEAL_ADDRESS" "amortize()" \
    --from "$SENDER_ADDRESS" \
    --rpc-url "${API_URL}/rpc/v1"

RECEIPT=$(cast send "$DEAL_ADDRESS" "amortize()" \
    --private-key "$SENDER_KEY" \
    --rpc-url "${API_URL}/rpc/v1" \
    --gas-limit 500000000)
echo "$RECEIPT"

TX_STATUS=$(echo "$RECEIPT" | grep "^status" | awk '{print $2}')
TX_HASH=$(echo "$RECEIPT"  | grep "^transactionHash" | awk '{print $2}')

if [ "$TX_STATUS" != "1" ]; then
    echo "amortize failed (status=$TX_STATUS), getting trace..."
    MSG_CID=$("$LOTUS" eth get-message-cid-by-transaction-hash "$TX_HASH" 2>&1 | tail -1)
    echo "Message CID: $MSG_CID"
    "$LOTUS" state replay --show-trace "$MSG_CID" || true
    exit 1
fi
