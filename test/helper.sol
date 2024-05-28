// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IZeroDay} from "../src/interfaces/IZeroDay.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ZeroDay} from "../src/ZeroDay.sol";
import {ZeroDayTest} from "./ZeroDayTest.sol";

abstract contract helper is Test, IZeroDay {
    function functionChangePhaseTo(address caller, ZeroDay nft, PHASE _phase) internal {
        vm.startPrank(caller);

        if (_phase == PHASE.PRE_SALE) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            nft.startPreSale();
        } else if (_phase == PHASE.REVEAL) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            nft.startPreSale();

            vm.warp(nft.getStartRevealDate() + 10 seconds);
            nft.startReveal();
        } else if (_phase == PHASE.PUBLIC_SALE) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            nft.startPreSale();

            vm.warp(nft.getStartRevealDate() + 10 seconds);
            nft.startReveal();

            vm.warp(nft.getStartPublicSaleDate() + 10 seconds);
            nft.startPublicSale();
        }

        vm.stopPrank();
    }

    // Merkle trre generator from addresses.

    // merkle root generator.
}
