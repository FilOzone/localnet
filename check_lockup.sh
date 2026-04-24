#!/bin/bash
set -e

CLIENT_ADDRESS=$(cast wallet address --private-key "$SENDER_KEY")

echo "FilecoinPayV1: $PAYMENTS_ADDRESS"
echo "Token:         $TOKEN_ADDRESS"
echo "Client:        $CLIENT_ADDRESS"
echo ""

cast call "$PAYMENTS_ADDRESS" \
    "accounts(address,address)(uint256 funds,uint256 lockupCurrent,uint256 lockupRate,uint256 lockupLastSettledAt)" \
    "$TOKEN_ADDRESS" "$CLIENT_ADDRESS" \
    --rpc-url "${API_URL}/rpc/v1"
