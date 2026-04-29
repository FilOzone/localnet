#!/bin/bash
set -e

LOCALNET="$( cd "$( dirname -- "$BASH_SOURCE" )" && pwd )"

source "$LOCALNET/local_lotus.sh"
# cwd is now lotus-local-net/ — create_miner.sh expects this for ./lotus-shed
source "$LOCALNET/create_miner.sh"

source "$LOCALNET/prepare_piece.sh"
source "$LOCALNET/create_service.sh"
source "$LOCALNET/sector_notify.sh"
"$LOCALNET/check_lockup.sh"
"$LOCALNET/amortize.sh"
sleep 3
"$LOCALNET/withdraw_receiver.sh"
"$LOCALNET/sector_faulty.sh"
"$LOCALNET/sector_terminate.sh"
