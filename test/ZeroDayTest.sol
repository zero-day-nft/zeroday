// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ZeroDay } from "../src/ZeroDay.sol";
import { IZeroDay } from "../src/interfaces/IZeroDay.sol";
import { helper } from "./helper.sol";

contract ZeroDayTest is Test, IZeroDay {
    ZeroDay public nft;
    uint256 public constant init_pre_sale_price_example = 1 ether;
    uint256 public constant start_pre_sale_date_example = 1716718200; // Sunday, May 26, 2024 10:10:00 AM
    uint256 public constant start_reveal_date_example = 1716977400; // Wednesday, May 29, 2024 10:10:00 AM
    uint256 public constant start_public_sale_date_example =  1717063800; //Thursday, May 30, 2024 10:10:00 AM

    address owner = address(this);
    address whitelistValidMinter = makeAddr("whitelistValidMinter");
    address publicSaleMinter = makeAddr("publicSaleMinter");
    address invalidCaller = makeAddr("invalidCaller");

    function setUp() public {
        bytes32 merkleRoot = keccak256(abi.encodePacked("merkelRoot"));

        vm.startPrank(owner);
        nft = new ZeroDay(
            init_pre_sale_price_example,
            start_pre_sale_date_example,
            start_reveal_date_example,
            start_public_sale_date_example,
            merkleRoot
        );
        vm.stopPrank();
    }

    // #remove the console logs
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

    function testChangeValidMerkleRootWithValidCaller() public {
        bytes32 preMerkleRoot = nft.getMerkleRoot();
        bytes32 newValidMerkleRoot = keccak256(abi.encodePacked("newValidMerkleRoot"));

        vm.startPrank(owner);
        nft.changeMerkleRoot(newValidMerkleRoot);
        vm.stopPrank();

        assertEq(nft.getMerkleRoot(), newValidMerkleRoot);
        assertNotEq(nft.getMerkleRoot(), preMerkleRoot);
    }

    function testFailChangeInvalidMerkleRootWithValidCaller() public {
        bytes32 sameMerkleRoot = keccak256(abi.encodePacked("merkelRoot"));
        vm.startPrank(owner);
        nft.changeMerkleRoot(sameMerkleRoot);
        vm.stopPrank();
    }

    function testFailChangeValidMerkleRootWithInvalidCaller() public {
        bytes32 newValidMerkleRoot = keccak256(abi.encodePacked("newValidMerkleRoot"));

        vm.startPrank(invalidCaller);
        nft.changeMerkleRoot(newValidMerkleRoot);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            MINT FUNCTION
    //////////////////////////////////////////////////////////////*/
    function testMintNFTWithValidPhase() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        console.log(getStatus());
        string memory testTokenURI = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna"; 
        vm.startPrank(publicSaleMinter);
        nft.mintNFT(testTokenURI);
        vm.stopPrank();

        assertEq(nft.totalSupply(), 1);
        assertEq(nft.getTokenURI(nft.totalSupply()), testTokenURI);
    }
    
    function testFailMintNFTWithInvalidPhase() public changePhaseTo(PHASE.REVEAL, true) {
        string memory testTokenURI = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna"; 
        vm.startPrank(publicSaleMinter);
        nft.mintNFT(testTokenURI);
        vm.stopPrank();
    }


    /*///////////////////////////////////////////////////////////////
                            CHANGE PHASE
    //////////////////////////////////////////////////////////////*/
    function testStartPreSaleWithValidTimeRange() public /*changePhaseTo(PHASE.PRE_SALE, false)*/ {
        vm.startPrank(owner);
        vm.warp(nft.i_startPreSaleDate() + 10 seconds);
        nft.startPreSale();
        vm.stopPrank();

        assertTrue(nft.getPreSaled());
        assertFalse(nft.getRevealed());
        assertFalse(nft.getPublicSaled());

        assertEq(getStatus(), "PRE_SALE");
    }

    function testFailStartPreSaleWithInvalidCaller() public changePhaseTo(PHASE.NOT_STARTED, false) {
        vm.startPrank(invalidCaller);
        nft.startPreSale();
        vm.stopPrank();
    }

    function testFailStartPreSaleWithInValidTimeRange() public changePhaseTo(PHASE.PRE_SALE, true) {
        vm.startPrank(owner);
        nft.startPreSale();
        vm.stopPrank();
    }

    function testFailStartPreSaleForSecondTimeWithValidTimeRange() public changePhaseTo(PHASE.NOT_STARTED, false) {
        vm.startPrank(owner);
        nft.startPreSale();
        nft.startPreSale();
        vm.stopPrank();
    }

    /// @notice test startRevealSale functionality
    function testStartRevealWithValidTimeRange() public changePhaseTo(PHASE.REVEAL, false) {
        vm.startPrank(owner);
        nft.startReveal();
        vm.stopPrank();

        console.log(getStatus());
        assertTrue(nft.getPreSaled());
        assertTrue(nft.getRevealed());
        assertFalse(nft.getPublicSaled());
        assertEq(getStatus(), "REVEAL");
    }

    function testFailStartRevealWithInvlidCallerWithValidTimeRange() public changePhaseTo(PHASE.REVEAL, false) {
        vm.startPrank(invalidCaller);
        nft.startReveal();
        nft.startReveal();
        vm.stopPrank();
    }    

    function testFailStartRevealTwiceWithValidTimeRange() public changePhaseTo(PHASE.REVEAL, false) {
        vm.startPrank(owner);
        nft.startReveal();
        nft.startReveal();
        vm.stopPrank();
    }

    function testFailStartRevealWithInvalidTimeRange() public changePhaseTo(PHASE.PRE_SALE, false) {
        vm.startPrank(owner);
        nft.startReveal();
        vm.stopPrank();
    }

    function testFailStartRevealWithInvalidTimeRange2() public changePhaseTo(PHASE.PUBLIC_SALE, false) {
        vm.startPrank(owner);
        nft.startReveal();
        vm.stopPrank();
    }

    /// @notice test startPublicSale functionality
    function testStartPublicSaleWithValidTimeRange() public changePhaseTo(PHASE.PUBLIC_SALE, false) {
        vm.startPrank(owner);
        nft.startPublicSale();
        vm.stopPrank();

        assertTrue(nft.getPreSaled());
        assertTrue(nft.getRevealed());
        assertTrue(nft.getPublicSaled());

        assertEq(getStatus(), "PUBLIC_SALE");
    }

    function testFailStartPublicWithInvalidCallerWithValidTimeRange() public changePhaseTo(PHASE.PUBLIC_SALE, false) {
        vm.startPrank(invalidCaller);
        nft.startPublicSale();
        vm.stopPrank();
    }

    function testFailStartPublicSaleWithInvalidTimeRange() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        vm.startPrank(owner);
        nft.startPublicSale();
        vm.stopPrank();
    }

    function testFailStartPublicSaleWithInvalidTimeRange2() public changePhaseTo(PHASE.REVEAL, true) {
        vm.startPrank(owner);
        nft.startPublicSale();
        vm.stopPrank();
    }

    function testFailStartPublicSaleTwiceWithValidTimeRange() public changePhaseTo(PHASE.PUBLIC_SALE, false) {
        vm.startPrank(owner);
        nft.startPublicSale();
        nft.startPublicSale();
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            TOKEN URI
    //////////////////////////////////////////////////////////////*/
    function testTokenURIOutput() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        string memory testTokenURI = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna"; 

        vm.startPrank(publicSaleMinter);
        nft.mintNFT(testTokenURI);
        nft.mintNFT(testTokenURI);
        vm.stopPrank();

        string memory expectedValueWithIndexOne = "https://ipfs.io/ipfs/bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna/1";
        string memory expectedValueWithIndexTwo = "https://ipfs.io/ipfs/bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna/2";

        assertEq(nft.tokenURI(1), expectedValueWithIndexOne);
        assertEq(nft.tokenURI(2), expectedValueWithIndexTwo);
    }

    function getStatus() public view returns (string memory status) {
        status = "";
        if(nft.getCurrentPhase() == PHASE.NOT_STARTED) status = "NOT_STARTED";
        else if(nft.getCurrentPhase() == PHASE.PRE_SALE) status = "PRE_SALE";
        else if(nft.getCurrentPhase() == PHASE.REVEAL) status = "REVEAL";
        else if(nft.getCurrentPhase() == PHASE.PUBLIC_SALE) status = "PUBLIC_SALE";
    }
}