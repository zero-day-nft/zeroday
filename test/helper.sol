// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IZeroDay} from "../src/interfaces/IZeroDay.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ZeroDay} from "../src/ZeroDay.sol";
import {ZeroDayTest} from "./ZeroDayTest.sol";

abstract contract helper is IZeroDay {
    function getStatus(ZeroDay nft) public view returns (string memory status) {
        status = "";
        if (nft.getCurrentPhase() == PHASE.NOT_STARTED) status = "NOT_STARTED";
        else if (nft.getCurrentPhase() == PHASE.PRE_SALE) status = "PRE_SALE";
        else if (nft.getCurrentPhase() == PHASE.REVEAL) status = "REVEAL";
        else if (nft.getCurrentPhase() == PHASE.PUBLIC_SALE) status = "PUBLIC_SALE";
    }

    // Merkle trre generator from addresses.

    // merkle root generator.
}
