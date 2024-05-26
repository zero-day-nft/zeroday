// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { console } from "forge-std/console.sol";
import { ZeroDay } from "../../src/ZeroDay.sol";
import { IZeroDay } from "../../src/interfaces/IZeroDay.sol";

/// Invariants in contract:
/// @notice nft counter value should always less than totalSupply. 
contract InvariantInUse is StdInvariant, Test, IZeroDay {
    string public tokenURIHash = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna";
    ZeroDay public nft;

    address owner = address(this);
    address publicSaleMinter = makeAddr("publicSaleMinter");

    bytes32 public merkleRoot;
    constructor(
        uint256 init_pre_sale_price,
        uint256 startPreSaleDate,
        uint256 startRevealDate,
        uint256 startPublicSaleDa,
        bytes32 _merkleRoot
    ) 
    {
        merkleRoot = keccak256(abi.encodePacked("merkelRoot"));

        vm.startPrank(owner);
        nft = new ZeroDay(
            init_pre_sale_price,
            startPreSaleDate,
            startRevealDate,
            startPublicSaleDa,
            _merkleRoot
        );
        vm.stopPrank();
    }


    function mintNFTInPublicSalePhase(uint256 mintingTimes)
        public
        changePhaseTo(PHASE.PUBLIC_SALE, true)
    {
        // Exceedable from collection max supply which is `9983`
        uint256 max_times = 10000;
        mintingTimes = bound(mintingTimes, 1, max_times);

        for (uint256 i = 0; i < mintingTimes; i++) {
            if (i > max_times) vm.expectRevert();
            
            vm.startPrank(publicSaleMinter);
            nft.mintNFT(tokenURIHash);
            vm.stopPrank();
        }
    }

    modifier changePhaseTo(PHASE _phase, bool _after) {
        vm.startPrank(owner);

        if (_phase == PHASE.PRE_SALE) {
            vm.warp(nft.i_startPreSaleDate() + 10 seconds);
            console.log("should be pre-sale: ", getStatus());
            nft.startPreSale();
            
        } else if (_phase == PHASE.REVEAL) {
            vm.warp(nft.i_startPreSaleDate() + 10 seconds);
            console.log("should be pre-sale: ", getStatus());
            nft.startPreSale();

            vm.warp(nft.i_startRevealDate() + 10 seconds);
            if (_after) {
                console.log("Should be reveal: ", getStatus());
                nft.startReveal();
            }
            
        } else if (_phase == PHASE.PUBLIC_SALE) {
            vm.warp(nft.i_startPreSaleDate() + 10 seconds);
            nft.startPreSale();
            console.log("should be pre-sale: ", getStatus());

            vm.warp(nft.i_startRevealDate() + 10 seconds);
            nft.startReveal();
            console.log("Should be reveal: ", getStatus());

            vm.warp(nft.i_startPublicSaleDate() + 10 seconds);
            if (_after) {
                nft.startPublicSale();
                console.log("Should be public-sale: ", getStatus());
            }
        }

        vm.stopPrank();
        _;
    }

    function getStatus() public view returns (string memory status) {
        status = "";
        if(nft.getCurrentPhase() == PHASE.NOT_STARTED) status = "NOT_STARTED";
        else if(nft.getCurrentPhase() == PHASE.PRE_SALE) status = "PRE_SALE";
        else if(nft.getCurrentPhase() == PHASE.REVEAL) status = "REVEAL";
        else if(nft.getCurrentPhase() == PHASE.PUBLIC_SALE) status = "PUBLIC_SALE";
    }
}