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

    modifier changePhaseTo(PHASE _phase) {
        vm.startPrank(owner);

        if (_phase == PHASE.PRE_SALE) {
            vm.warp(nft.i_startPreSaleDate() - 10 seconds);
            nft.startPreSale();
            
        } else if (_phase == PHASE.REVEAL) {
            vm.warp(nft.i_startPreSaleDate() - 10 seconds);
            nft.startPreSale();

            vm.warp(nft.i_startRevealDate() - 10 seconds);
            nft.startReveal();
            
        } else if (_phase == PHASE.PUBLIC_SALE) {
            vm.warp(nft.i_startPreSaleDate() - 10 seconds);
            nft.startPreSale();
            
            vm.warp(nft.i_startRevealDate() - 10 seconds);
            nft.startReveal();

            vm.warp(nft.i_startPublicSaleDate() - 10 seconds);
            nft.startPublicSale();
        }

        vm.stopPrank();
        _;
    }

    function testMintNFTInValidPhase() public changePhaseTo(PHASE.PUBLIC_SALE) {
        console.log(getStatus());
        string memory testTokenURI = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna"; 
        vm.startPrank(publicSaleMinter);
        nft.mintNFT(testTokenURI);
        vm.stopPrank();

        assertEq(nft.totalSupply(), 1);
        assertEq(nft.getTokenURI(nft.totalSupply()), testTokenURI);
    }
    
    function getStatus() public view returns (string memory status) {
        status = "";
        if(nft.getCurrentPhase() == PHASE.NOT_STARTED) status = "NOT_STARTED";
        else if(nft.getCurrentPhase() == PHASE.PRE_SALE) status = "PRE_SALE";
        else if(nft.getCurrentPhase() == PHASE.REVEAL) status = "REVEAL";
        else if(nft.getCurrentPhase() == PHASE.PUBLIC_SALE) status = "PUBLIC_SALE";
    }
}