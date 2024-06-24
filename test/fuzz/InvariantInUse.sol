// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {console} from "forge-std/console.sol";
import {ZeroDay} from "../../src/ZeroDay.sol";
import {IZeroDay} from "../../src/interfaces/IZeroDay.sol";

/// Invariants in contract:
/// @notice nft counter value should always less than totalSupply.
contract InvariantInUse is StdInvariant, Test, IZeroDay {
    error InvariantInUse__loopTimesExceeded(uint256 time);

    string public tokenURIHash = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna";
    ZeroDay public nft;

    uint96 public constant ROYALTY_BASIS_POINT_VALUE = 500; // 5% of token Royalty.
    uint256 public constant PUBLIC_SALE_MINT_PRICE = 1 ether;

    address owner = address(this);
    address publicSaleMinter = makeAddr("publicSaleMinter");

    /// @notice If the count exceeds 1, the time range manipulation process will not be occurred.
    uint256 private count;

    bytes32 public merkleRoot;

    constructor(
        uint32 startPreSaleDate,
        uint32 startRevealDate,
        uint32 startPublicSaleDate,
        bytes32 _merkleRoot
    ) {
        merkleRoot = keccak256(abi.encodePacked("merkelRoot"));

        vm.startPrank(owner);
        nft = new ZeroDay(
            startPreSaleDate, 
            startRevealDate, 
            startPublicSaleDate, 
            _merkleRoot
        );
        vm.stopPrank();
        count = 0;
    }

    function mintNFT(uint256 mintingTimes) public {
        // Exceedable from collection max supply which is `9983`
        uint256 max_times = 10;
        mintingTimes = bound(mintingTimes, 1, max_times);

        if (count == 0) {
            // time range manipulation.
            vm.warp(nft.getStartPreSaleDate() + 10 seconds);
            nft.startPreSale();

            vm.warp(nft.getStartRevealDate() + 10 seconds);
            nft.startReveal();

            vm.warp(nft.getStartPublicSaleDate() + 10 seconds);
            nft.startPublicSale();
        }

        for (uint256 i = 0; i < mintingTimes; i++) {
            if (i > max_times) revert InvariantInUse__loopTimesExceeded(i);

            vm.startPrank(publicSaleMinter);

            vm.deal(publicSaleMinter, PUBLIC_SALE_MINT_PRICE);
            nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);

            count = count == 0 ? ++count : count;

            vm.stopPrank();
        }
    }

    /*///////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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
}
