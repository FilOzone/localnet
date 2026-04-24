// SPDX-License-Identifier: Apache-2.0 OR MIT
pragma solidity ^0.8.30;

// Run with --skip-simulation on Filecoin networks.
// isMiner() calls the CALL_ACTOR_BY_ID precompile, which forge's post-script
// on-chain simulation cannot handle.  --skip-simulation uses eth_estimateGas
// instead and avoids that step entirely.
//
// Example (devnet):
//   PROVIDER_ID=1234 forge script script/PoRepSmokeTest.s.sol \
//     --rpc-url http://localhost:1234/rpc/v1 \
//     --broadcast --skip-simulation \
//     --private-key $CLIENT_PRIVATE_KEY
//
// Optional env vars:
//   PAYMENTS_ADDRESS        – reuse an existing FilecoinPayV1 (skips deploy)
//   TOKEN_ADDRESS           – reuse an existing ERC20 (skips MockToken deploy)
//   DEPOSIT_AMOUNT          – tokens deposited for the client (default: 1e24)
//   TOKENS_PER_BYTE_PER_EPOCH – rail rate (default: 1)
//   DEAL_DURATION_EPOCHS    – epochs from now until deal end (default: 1000)
//   INSURANCE_BPS           – insurance rate in bps (default: 0)
//   PIECE_DIGEST            – bytes32 raw sha2-256-trunc254-padded CommP digest to authorise
//                             (output of prepare_piece.sh / sector_notify.sh)

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FilecoinPayV1} from "@fws-payments/FilecoinPayV1.sol";
import {CALL_ACTOR_BY_ID} from "@fvm-solidity/FVMPrecompiles.sol";
import {PoRepService} from "../src/PoRepService.sol";
import {PoRepDeal} from "../src/PoRepDeal.sol";

contract MockToken is ERC20 {
    constructor(address recipient, uint256 supply) ERC20("Mock Token", "MOCK") {
        _mint(recipient, supply);
    }
}

contract PoRepSmokeTest is Script {
    bytes constant RETURN_SUCCESS = hex"60205ff3";

    function run() external {
        uint64 providerId = uint64(vm.envUint("PROVIDER_ID"));

        address paymentsAddr = vm.envOr("PAYMENTS_ADDRESS", address(0));
        address tokenAddr = vm.envOr("TOKEN_ADDRESS", address(0));
        uint256 depositAmount = vm.envOr("DEPOSIT_AMOUNT", uint256(1e24));
        uint256 tokensPerBytePerEpoch = vm.envOr("TOKENS_PER_BYTE_PER_EPOCH", uint256(1));
        uint64 dealDurationEpochs = uint64(vm.envOr("DEAL_DURATION_EPOCHS", uint256(1000)));
        uint256 insuranceBps = vm.envOr("INSURANCE_BPS", uint256(0));
        bytes32 pieceDigest = bytes32(vm.envBytes32("PIECE_DIGEST"));

        address client = msg.sender;

        vm.etch(CALL_ACTOR_BY_ID, RETURN_SUCCESS);

        vm.startBroadcast();

        FilecoinPayV1 payments;
        if (paymentsAddr == address(0)) {
            payments = new FilecoinPayV1();
            console.log("FilecoinPayV1 deployed:", address(payments));
        } else {
            payments = FilecoinPayV1(paymentsAddr);
            console.log("FilecoinPayV1 (existing):", address(payments));
        }

        IERC20 token;
        if (tokenAddr == address(0)) {
            token = IERC20(address(new MockToken(client, depositAmount)));
            console.log("MockToken deployed:", address(token));
        } else {
            token = IERC20(tokenAddr);
            console.log("Token (existing):", address(token));
        }

        PoRepService service = new PoRepService(payments);
        console.log("PoRepService deployed:", address(service));

        // Approve PoRepService as an operator so it can create rails on the
        // client's behalf.  Max allowances are fine for a smoke test.
        uint256 maxUint = type(uint256).max;
        payments.setOperatorApproval(token, address(service), true, maxUint, maxUint, maxUint);

        // Fund the client's payments account.
        token.approve(address(payments), depositAmount);
        payments.deposit(token, client, depositAmount);
        console.log("Deposited", depositAmount, "tokens for client");

        // Create the deal.  Calls isMiner() internally – requires a real lotus
        // devnet with providerId registered as a miner actor.
        uint64 dealEndEpoch = uint64(block.number) + dealDurationEpochs;
        address dealAddr =
            service.createDeal(client, providerId, token, tokensPerBytePerEpoch, dealEndEpoch, insuranceBps);
        console.log("PoRepDeal deployed:", dealAddr);

        // Authorise the piece so that the miner can later commit it.
        bytes32[] memory pieceDigests = new bytes32[](1);
        pieceDigests[0] = pieceDigest;
        PoRepDeal(dealAddr).addPieces(pieceDigests);
        console.log("addPieces called with CID hash:", vm.toString(pieceDigest));

        vm.stopBroadcast();
    }
}
