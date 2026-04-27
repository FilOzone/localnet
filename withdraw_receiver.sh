#!/bin/bash
set -e

LOCALNET="$( cd "$( dirname -- "$BASH_SOURCE" )" && pwd )"
LOTUS="$LOCALNET/lotus-local-net/lotus"

RECEIVER_ADDRESS=$(cast call "$SERVICE_ADDRESS" \
    "getReceiverAddress(uint64)(address)" "$PROVIDER_ID" \
    --rpc-url "${API_URL}/rpc/v1")
echo "Receiver: $RECEIVER_ADDRESS"

FUNDS=$(cast call "$PAYMENTS_ADDRESS" \
    "accounts(address,address)(uint256,uint256,uint256,uint256)" \
    "$TOKEN_ADDRESS" "$RECEIVER_ADDRESS" \
    --rpc-url "${API_URL}/rpc/v1" | head -1 | awk '{print $1}')
echo "Receiver funds: $FUNDS"

RECEIVER_STAT=$("$LOTUS" evm stat "$RECEIVER_ADDRESS")
RECEIVER_ID=$(echo "$RECEIVER_STAT" | grep "ID address:" | awk '{print $NF}')
RECEIVER_ETH=$(echo "$RECEIVER_STAT" | grep -i "Eth address:" | awk '{print $NF}')
echo "Receiver ID:  $RECEIVER_ID"
echo "Receiver ETH: $RECEIVER_ETH  (predicted: $RECEIVER_ADDRESS)"

echo "=== Receiver account state (predicted address) ==="
cast call "$PAYMENTS_ADDRESS" \
    "accounts(address,address)(uint256 funds,uint256 lockupCurrent,uint256 lockupRate,uint256 lockupLastSettledAt)" \
    "$TOKEN_ADDRESS" "$RECEIVER_ADDRESS" \
    --rpc-url "${API_URL}/rpc/v1"

if [ -n "$RECEIVER_ETH" ] && [ "$RECEIVER_ETH" != "$RECEIVER_ADDRESS" ]; then
    echo "=== Receiver account state (actual ETH address) ==="
    cast call "$PAYMENTS_ADDRESS" \
        "accounts(address,address)(uint256 funds,uint256 lockupCurrent,uint256 lockupRate,uint256 lockupLastSettledAt)" \
        "$TOKEN_ADDRESS" "$RECEIVER_ETH" \
        --rpc-url "${API_URL}/rpc/v1"
fi

if [ "$FUNDS" -eq 0 ]; then
    echo "Nothing to withdraw"
    exit 0
fi

WITHDRAW_CALLDATA=$(cast calldata "withdraw(address,uint256)" "$TOKEN_ADDRESS" "$FUNDS")
SUDO_CALLDATA=$(cast calldata "sudo(address,bytes)" "$PAYMENTS_ADDRESS" "$WITHDRAW_CALLDATA")

RECEIPT=$(cast send "$RECEIVER_ADDRESS" "${SUDO_CALLDATA}" \
    --private-key "$SENDER_KEY" \
    --rpc-url "${API_URL}/rpc/v1" \
    --gas-limit 500000000)
echo "$RECEIPT"

TX_STATUS=$(echo "$RECEIPT" | grep "^status" | awk '{print $2}')
TX_HASH=$(echo "$RECEIPT"  | grep "^transactionHash" | awk '{print $2}')

if [ "$TX_STATUS" != "1" ]; then
    echo "withdraw failed (status=$TX_STATUS), getting trace..."
    MSG_CID=$("$LOTUS" eth get-message-cid-by-transaction-hash "$TX_HASH" 2>&1 | tail -1)
    echo "Message CID: $MSG_CID"
    "$LOTUS" state replay --show-trace "$MSG_CID" || true
    exit 1
fi
