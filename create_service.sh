#!/bin/bash
set +e

PROVIDER_ID="${MINER_ID#t0}"

OUTPUT=$(
    cd "$( dirname -- "$BASH_SOURCE" )/filecoin-services/service_contracts"
    PROVIDER_ID=$PROVIDER_ID PIECE_DIGEST=$PIECE_DIGEST forge script script/PoRepSmokeTest.s.sol \
        --tc PoRepSmokeTest \
        --rpc-url "${API_URL}/rpc/v1" \
        --broadcast --skip-simulation \
        --private-key "$SENDER_KEY" 2>&1
)
FORGE_EXIT=$?
echo "$OUTPUT" >&2
if [ $FORGE_EXIT -ne 0 ]; then
    echo "ERROR: forge script failed (exit $FORGE_EXIT)" >&2
    exit $FORGE_EXIT
fi

export PAYMENTS_ADDRESS=$(echo "$OUTPUT" | grep "FilecoinPayV1" | grep -oE '0x[0-9a-fA-F]{40}')
export TOKEN_ADDRESS=$(echo "$OUTPUT" | grep -E "MockToken deployed|Token \(existing\)" | grep -oE '0x[0-9a-fA-F]{40}')
export SERVICE_ADDRESS=$(echo "$OUTPUT" | grep "PoRepService deployed:" | grep -oE '0x[0-9a-fA-F]{40}')
export DEAL_ADDRESS=$(echo "$OUTPUT" | grep "PoRepDeal deployed:" | grep -oE '0x[0-9a-fA-F]{40}')
export PROVIDER_ID
echo "$SERVICE_ADDRESS"
