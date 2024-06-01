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
    uint256 public constant start_pre_sale_date_example = 1743493497; // Tuesday, April 1, 2025 7:44:57 AM
    uint256 public constant start_reveal_date_example = 1746085497; // Thursday, May 1, 2025 7:44:57 AM
    uint256 public constant start_public_sale_date_example =  1748763897; //Sunday, June 1, 2025 7:44:57 AM

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

    function invariant_tokenIdCounterShouldAlwaysBeLessThanTotalSupplyDuringNFTMint() 
        public
        changePhaseTo(PHASE.PUBLIC_SALE, true)
    {
        uint256 maxSupply = 9983;
        uint256 tokenCounter = nft.totalSupply();

        assertGe(maxSupply, tokenCounter);
        assertEq(getStatus(), "PUBLIC_SALE");
    }


    modifier changePhaseTo(PHASE _phase, bool _after) {
        vm.startPrank(owner);

        if (_phase == PHASE.PRE_SALE) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            nft.startPreSale();
            
        } else if (_phase == PHASE.REVEAL) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            nft.startPreSale();

            vm.warp(nft.getStartRevealDate() + 10 seconds);
            if (_after) {
                nft.startReveal();
            }
            
        } else if (_phase == PHASE.PUBLIC_SALE) {
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            nft.startPreSale();

            vm.warp(nft.getStartRevealDate() + 10 seconds);
            nft.startReveal();

            vm.warp(nft.getStartPublicSaleDate() + 10 seconds);
            if (_after) {
                nft.startPublicSale();
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