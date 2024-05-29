// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { console } from "forge-std/console.sol";
import { ZeroDay } from "../../src/ZeroDay.sol";
import { IZeroDay } from "../../src/interfaces/IZeroDay.sol";
import { InvariantInUse } from "./InvariantInUse.sol";

/// Invariants in contract:
/// @notice nft counter value should always less than totalSupply. 
contract InvarianTesting is StdInvariant, Test, IZeroDay {
    string public tokenURIHash = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna";
    ZeroDay public nft;
    uint256 public constant init_pre_sale_price_example = 1 ether;
    uint256 public constant start_pre_sale_date_example = 1716718200; // Sunday, May 26, 2024 10:10:00 AM
    uint256 public constant start_reveal_date_example = 1716977400; // Wednesday, May 29, 2024 10:10:00 AM
    uint256 public constant start_public_sale_date_example =  1717063800; //Thursday, May 30, 2024 10:10:00 AM

    address owner = address(this);
    address publicSaleMinter = makeAddr("publicSaleMinter");

    bytes32 public merkleRoot;

    InvariantInUse public handler;

    function setUp() public {
        merkleRoot = keccak256(abi.encodePacked("merkelRoot"));

        vm.startPrank(owner);
        nft = new ZeroDay(
            init_pre_sale_price_example,
            start_pre_sale_date_example,
            start_reveal_date_example,
            start_public_sale_date_example,
            merkleRoot
        );
        vm.stopPrank();

        handler = new InvariantInUse(
            init_pre_sale_price_example,
            start_pre_sale_date_example,
            start_reveal_date_example,
            start_public_sale_date_example,
            merkleRoot
        );
        targetContract(address(handler));
    }
    // #bug season management issue.
    function check_invariant_tokenIdCounterShouldAlwaysBeLessThanTotalSupply() 
        public
        changePhaseTo(PHASE.PUBLIC_SALE, true)
    {
        vm.startPrank(publicSaleMinter);
        nft.mintNFT();
        vm.stopPrank();

        uint256 maxSupply = 9983;
        uint256 tokenCounter = nft.totalSupply();

        assertGe(maxSupply, tokenCounter);
    }

    modifier changePhaseTo(PHASE _phase, bool _after) {
        vm.startPrank(owner);

        if (_phase == PHASE.PRE_SALE) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            console.log("should be pre-sale: ", getStatus());
            nft.startPreSale();
            
        } else if (_phase == PHASE.REVEAL) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            console.log("should be pre-sale: ", getStatus());
            nft.startPreSale();

            vm.warp(nft.getStartRevealDate() + 10 seconds);
            if (_after) {
                console.log("Should be reveal: ", getStatus());
                nft.startReveal();
            }
            
        } else if (_phase == PHASE.PUBLIC_SALE) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            nft.startPreSale();
            console.log("should be pre-sale: ", getStatus());

            vm.warp(nft.getStartRevealDate() + 10 seconds);
            nft.startReveal();
            console.log("Should be reveal: ", getStatus());

            vm.warp(nft.getStartPublicSaleDate() + 10 seconds);
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