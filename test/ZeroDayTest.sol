// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ZeroDay} from "../src/ZeroDay.sol";
import {IZeroDay} from "../src/interfaces/IZeroDay.sol";
import {helper} from "./helper.sol";
import {mulDiv} from "@prb-math/src/Common.sol";

contract ZeroDayTest is Test, IZeroDay {
    ZeroDay public nft;
    /// NOTE: these are test values.
    uint256 public constant init_pre_sale_price_example = 0.7 ether;
    uint256 public constant PUBLIC_SALE_MINT_PRICE = 1 ether;
    uint32 public constant start_pre_sale_date_example = 1716718200; // Sunday, May 26, 2024 10:10:00 AM
    uint32 public constant start_reveal_date_example = 1716977400; // Wednesday, May 29, 2024 10:10:00 AM
    uint32 public constant start_public_sale_date_example = 1717063800; //Thursday, May 30, 2024 10:10:00 AM
    uint96 public constant ROYALTY_BASIS_POINT_VALUE = 500; // 5% of token Royalty.
    uint96 public constant FEE_DENOMINATOR = 10000; // 100 in basis points.

    address owner = address(this);
    address whitelistEligibleUser = 0x0B654CCa32393aE18f877012b2D907aeE34120fF;
    uint256 public constant whiteListEligibleUserAmountToMint = 1;

    address whitelistEligibleUser2 = 0x4362780946Cbd4D863E1701bA5726f3Eb25740EF;
    uint256 public constant whiteListEligibleUserAmountToMint2 = 2;

    address whitelistIneligibleUser = makeAddr("whitelistIneligibleUser");
    address whitelistValidMinter = makeAddr("whitelistValidMinter");
    address publicSaleMinter = makeAddr("publicSaleMinter");
    address destinationUser = makeAddr("destinationUser");
    address invalidCaller = makeAddr("invalidCaller");

    bytes32[] public merkleProof0;
    bytes32[] public merkleProof1;
    bytes32[] public merkleProof2;
    bytes32[] public merkleProof3;

    bytes32 merkleRoot;

    struct EligibleUsersForWhitelist {
        bytes32[] proof;
        address minter;
        uint256 amount;
    }
    EligibleUsersForWhitelist[4] public eligibleUsersForWhitelist;

    event withdrawSucceeded(address indexed from, address indexed to, uint256 indexed amount, bytes data);
    
    function setUp() public {
        /// @notice these merkleProofs and merkle root are based on this assumed data.
        /// [{ address: "0x0B654CCa32393aE18f877012b2D907aeE34120fF", number: 1 },
        /// { address: "0x4362780946Cbd4D863E1701bA5726f3Eb25740EF", number: 2 },
        /// { address: "0xF83C98E3f306198BDD5A5Ef82Cb3E15153349B42", number: 3 },
        /// { address: "0x4bb99d525D357E9412873619C6decf7109C777b0", number: 4 },
        /// { address: "0x3C4aE7d8D9e8152bbC889eb79D5b3CC626AC4496", number: 5 }]
        merkleRoot = 0xdd72d55d4b80240b342b458de7d1e17b7dd1c0466755d216dca1a3661c004351;

        merkleProof0 = new bytes32[](3);
        merkleProof0[0] = 0xcc3b18a6563c488783911ed860e05e0b2d2a36ad7ddc76eb41196d68a74d59f0;
        merkleProof0[1] = 0x7167e9020180294635c190b2e454f20497f596a2815433f36220357fa3829459;
        merkleProof0[2] = 0x2eb269ededd96c50d162b3b16e1409fa7e52ed147587eddea1916e2ae230c71b;
        eligibleUsersForWhitelist[0] = EligibleUsersForWhitelist ({
            proof: merkleProof0,
            minter: 0x0B654CCa32393aE18f877012b2D907aeE34120fF,
            amount: 1
        });

        merkleProof1 = new bytes32[](3);
        merkleProof1[0] = 0xecab0314047fb99dbd66e1113743838782a6123127cd203de80882811d9c5755;
        merkleProof1[1] = 0x7167e9020180294635c190b2e454f20497f596a2815433f36220357fa3829459; 
        merkleProof1[2] = 0x2eb269ededd96c50d162b3b16e1409fa7e52ed147587eddea1916e2ae230c71b;
        eligibleUsersForWhitelist[1] = EligibleUsersForWhitelist ({
            proof: merkleProof1,
            minter: 0x4362780946Cbd4D863E1701bA5726f3Eb25740EF,
            amount: 2
        });

        merkleProof2 = new bytes32[](3);
        merkleProof2[0] = 0xd07b58788339695d6514334b362b045aca928f7bd39c8c91f98917490999cd0d;
        merkleProof2[1] = 0xef67600507c0a44ff1ffabd4d2bc82cf35098d3ace73905b924ce5f6f0d3b34e; 
        merkleProof2[2] = 0x2eb269ededd96c50d162b3b16e1409fa7e52ed147587eddea1916e2ae230c71b;
        eligibleUsersForWhitelist[2] = EligibleUsersForWhitelist ({
            proof: merkleProof2,
            minter: 0xF83C98E3f306198BDD5A5Ef82Cb3E15153349B42,
            amount: 3
        });

        merkleProof3 = new bytes32[](3);
        merkleProof3[0] = 0xe19764bbfeec8958a66b2c1de427bd02c0bc4ae28b2596890a853102dd61168e;
        merkleProof3[1] = 0xef67600507c0a44ff1ffabd4d2bc82cf35098d3ace73905b924ce5f6f0d3b34e; 
        merkleProof3[2] = 0x2eb269ededd96c50d162b3b16e1409fa7e52ed147587eddea1916e2ae230c71b;
        eligibleUsersForWhitelist[3] = EligibleUsersForWhitelist ({
            proof: merkleProof3,
            minter: 0x4bb99d525D357E9412873619C6decf7109C777b0,
            amount: 4
        });

        vm.startPrank(owner);
        nft = new ZeroDay(
            start_pre_sale_date_example,
            start_reveal_date_example,
            start_public_sale_date_example,
            merkleRoot
        );
        vm.stopPrank();
    }

    /// @notice fallback and receive functions are just for testing withdraw functionality.
    fallback() external payable {}
    receive() external payable {}

    /*///////////////////////////////////////////////////////////////
                            MODIFIER
    //////////////////////////////////////////////////////////////*/
    // #remove the console logs
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

    /*///////////////////////////////////////////////////////////////
                           WITHDRAW FUNCTION
    //////////////////////////////////////////////////////////////*/
    function testWithdrawByValidOwnerWithValidAmount() public {
        vm.deal(address(nft), 2 ether);

        uint256 target_balance_before_trasnfer = address(this).balance;
        vm.startPrank(payable(owner));
        nft.withdraw(payable(address(this)), 1 ether, "");
        vm.stopPrank();
        uint256 traget_balance_after_trasnfer = address(this).balance;

        assertEq(address(nft).balance, 1 ether, "NFT contract balance didn't changed");
        assertEq(
            traget_balance_after_trasnfer, target_balance_before_trasnfer + 1 ether, "target balance didn't changed"
        );
    }

    function testFailWithdrawByInvalidCallerWithValidAmount() public {
        vm.deal(address(nft), 2 ether);

        vm.startPrank(payable(invalidCaller));
        nft.withdraw(payable(address(this)), 1 ether, "");
        vm.stopPrank();
    }

    function testFailWithdrawByValidCallerWithInvalidAmount() public {
        vm.deal(address(nft), 1 ether - 1 wei);

        vm.startPrank(payable(invalidCaller));
        nft.withdraw(payable(address(this)), 1 ether, "");
        vm.stopPrank();
    }

    function testWithdrawByValidCallerWithValidAmountViaMintFunction() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether * 2);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);
        vm.stopPrank();

        uint256 target_balance_before_trasnfer = address(this).balance;
        vm.startPrank(payable(owner));
        nft.withdraw(payable(address(this)), 1 ether, "");
        vm.stopPrank();
        uint256 traget_balance_after_trasnfer = address(this).balance;

        assertEq(address(nft).balance, 1 ether, "NFT contract balance didn't changed");
        assertEq(
            traget_balance_after_trasnfer, target_balance_before_trasnfer + 1 ether, "target balance didn't changed"
        );
    }

    /*///////////////////////////////////////////////////////////////
                       WHITELIST AND MERKLE TREE
    //////////////////////////////////////////////////////////////*/
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
        bytes32 sameMerkleRoot = merkleRoot;
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

    function testWhiteListMintWithEligibleUser() public changePhaseTo(PHASE.PRE_SALE, true) {
        uint256 tokenIdCounter = 0;

        for (uint256 i = 0; i < 4; i++) {
            EligibleUsersForWhitelist memory user = eligibleUsersForWhitelist[i];
            vm.startPrank(user.minter);
            nft.whiteListMint(user.proof, user.amount);
            tokenIdCounter += user.amount;
            vm.stopPrank();

            assertEq(nft.ownerOf(tokenIdCounter - 1), user.minter, "Owner is not correct");
            assertEq(nft.totalSupply(), tokenIdCounter, "There is a problem in NFT counter");
        }

        assertEq(nft.totalSupply(), 10);
        console.log("totalSupply in test: ", nft.totalSupply());
    }

    function testFailWhiteListMintWithInvalidPhase() public changePhaseTo(PHASE.REVEAL, true) {
        EligibleUsersForWhitelist memory user = eligibleUsersForWhitelist[0];

        vm.startPrank(user.minter);
        nft.whiteListMint(user.proof, user.amount);
        vm.stopPrank();
    }

    function testFailWhiteListMintInWrongAmount() public changePhaseTo(PHASE.PRE_SALE, true) {
        EligibleUsersForWhitelist memory user = eligibleUsersForWhitelist[2];

        vm.startPrank(user.minter);
        nft.whiteListMint(user.proof, 4);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), address(0x0));
        assertEq(nft.ownerOf(4), address(0x0));
        assertEq(nft.totalSupply(), 0);
    }

    function testFailWhiteListMintWithIneligibleMinter() public changePhaseTo(PHASE.PRE_SALE, true) {
        EligibleUsersForWhitelist memory user = eligibleUsersForWhitelist[0];

        vm.startPrank(invalidCaller);
        // vm.deal(invalidCaller, init_pre_sale_price_example);
        nft.whiteListMint(user.proof, user.amount);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), address(0x0));
        assertEq(nft.totalSupply(), 0);
    }

    function testFailWhiteListMintWhenPhaseIsLocked() public changePhaseTo(PHASE.PRE_SALE, true) {
        EligibleUsersForWhitelist memory user = eligibleUsersForWhitelist[0];

        vm.startPrank(owner);
        nft.changePhaseLock();
        vm.stopPrank();

        vm.startPrank(user.minter);
        // vm.deal(whitelistEligibleUser, init_pre_sale_price_example);
        nft.whiteListMint(user.proof, user.amount);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), address(0x0));
        assertEq(nft.totalSupply(), 0);
    }

    function testWhiteListMintWhenPhaseBeLockedAndUnlocked() public changePhaseTo(PHASE.PRE_SALE, true) {
        EligibleUsersForWhitelist memory user = eligibleUsersForWhitelist[0];

        vm.startPrank(owner);
        nft.changePhaseLock();
        nft.changePhaseLock();
        vm.stopPrank();

        vm.startPrank(user.minter);
        nft.whiteListMint(user.proof, user.amount);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), user.minter);
        assertEq(nft.totalSupply(), 1);
        vm.expectRevert();
        nft.ownerOf(1);
    }
    
    /*///////////////////////////////////////////////////////////////
                            MINT FUNCTION
    //////////////////////////////////////////////////////////////*/
    function testMintNFTWithValidPhase() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        console.log(getStatus());
        // string memory testTokenURI = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna";

        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);
        vm.stopPrank();

        uint256 tokenIdMinted = nft.totalSupply() - 1;
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.ownerOf(tokenIdMinted), publicSaleMinter);
        assertEq(address(nft).balance, PUBLIC_SALE_MINT_PRICE);

        (address royaltyOwner, uint256 royaltyAmount) = nft.royaltyInfo(tokenIdMinted, PUBLIC_SALE_MINT_PRICE);
        console.log("Royalty amount: ", royaltyAmount);
        assertEq(royaltyOwner, publicSaleMinter);
        assertEq(royaltyAmount, calculateRoyalty(PUBLIC_SALE_MINT_PRICE));
    }

    function testFailMintNFTWithInvalidPhase() public changePhaseTo(PHASE.REVEAL, true) {
        // string memory testTokenURI = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna";
        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);
        vm.stopPrank();
    }

    function testFailMintNFTWithInsufficientBalanceWithValidPhase() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        // string memory testTokenURI = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna";
        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 0.99 ether);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);
        vm.stopPrank();

        assertEq(address(nft).balance, 0);
    }

    function testFailMintNFTWhenPhaseIsLocked() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        vm.startPrank(owner);
        nft.changePhaseLock();
        vm.stopPrank();

        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);
        vm.stopPrank();
    }

    function testMintNFTWhenPhaseBeLockedAndUnlocked() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        vm.startPrank(owner);
        nft.changePhaseLock();
        nft.changePhaseLock();
        vm.stopPrank();

        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);
        vm.stopPrank();
    }


    /*///////////////////////////////////////////////////////////////
                            TRANSFER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function testTransferWithValidCallerAndValidDestination() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: 1 ether}(10);

        nft.transfer(destinationUser, 0, "");
        vm.stopPrank();

        assertEq(nft.balanceOf(publicSaleMinter), 0);
        assertEq(nft.balanceOf(destinationUser), 1);
        assertNotEq(nft.ownerOf(0), publicSaleMinter);
        assertEq(nft.ownerOf(0), destinationUser);
    }

    function testFailTransferWithInvalidCallerAndValidDestination() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: 1 ether}(10);
        vm.stopPrank();

        vm.startPrank(invalidCaller);
        nft.transfer(destinationUser, 1, "");
        vm.stopPrank();
    }

    function testFailTransferWithValidCallerAndInvalidDestination() public changePhaseTo(PHASE.PUBLIC_SALE, true) {
        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: 1 ether}(10);
        vm.stopPrank();

        vm.startPrank(publicSaleMinter);
        nft.transfer(address(0), 1, "");
        vm.stopPrank();
    }

    function testFailTransferWithInvalidPhase() public changePhaseTo(PHASE.PUBLIC_SALE, false) {
        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: 1 ether}(10);
        vm.stopPrank();

        vm.startPrank(publicSaleMinter);
        nft.transfer(destinationUser, 1, "");
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            CHANGE PHASE
    //////////////////////////////////////////////////////////////*/
    function testStartPreSaleWithValidTimeRange() public 
    /*changePhaseTo(PHASE.PRE_SALE, false)*/
    {
        vm.startPrank(owner);
        vm.warp(nft.getStartPreSaleDate() + 10 seconds);
        nft.startPreSale();
        vm.stopPrank();

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
        // string memory testTokenURI = "bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna";

        vm.startPrank(publicSaleMinter);
        vm.deal(publicSaleMinter, 1 ether);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);

        vm.deal(publicSaleMinter, 1 ether + 1 wei);
        nft.mintNFT{value: PUBLIC_SALE_MINT_PRICE}(ROYALTY_BASIS_POINT_VALUE);
        vm.stopPrank();

        string memory expectedValueWithIndexOne = "https://ipfs.io/ipfs/0.json";
        string memory expectedValueWithIndexTwo = "https://ipfs.io/ipfs/1.json";
        assertEq(nft.tokenURI(0), expectedValueWithIndexOne);
        assertEq(nft.tokenURI(1), expectedValueWithIndexTwo);
    }

    /*///////////////////////////////////////////////////////////////
                          TIME MANIPULATION
    //////////////////////////////////////////////////////////////*/
    function testChangePreSaleDate() public {
        vm.startPrank(owner);
        uint32 newPreSaleDate = start_pre_sale_date_example + 1 days;
        nft.changePreSaleDate(newPreSaleDate);
        vm.stopPrank();

        assertEq(nft.getStartPreSaleDate(), newPreSaleDate);
    }

    function testFailChangePreSaleDateWithSameValue() public {
        vm.startPrank(owner);
        uint32 newPreSaleDate = start_pre_sale_date_example;
        nft.changePreSaleDate(newPreSaleDate);
        vm.stopPrank();
    }

    function testFailChangePreSaleDateWithInvalidCaller() public {
        vm.startPrank(invalidCaller);
        uint32 newPreSaleDate = start_pre_sale_date_example + 1 days;
        nft.changePreSaleDate(newPreSaleDate);
        vm.stopPrank();
    }

    /// @notice for changing reveal date.
    function testChangeReveal() public {
        vm.startPrank(owner);
        uint32 newRevealDate = start_reveal_date_example + 1 days;
        nft.changeRevealDate(newRevealDate);
        vm.stopPrank();

        assertEq(nft.getStartRevealDate(), newRevealDate);
    }

    function testFailChangeRevealDateWithSameValue() public {
        vm.startPrank(owner);
        uint32 newRevealDate = start_reveal_date_example;
        nft.changeRevealDate(newRevealDate);
        vm.stopPrank();
    }

    function testFailChangeRevealDateWithInvalidCaller() public {
        vm.startPrank(invalidCaller);
        uint32 newRevealDate = start_reveal_date_example + 1 days;
        nft.changePreSaleDate(newRevealDate);
        vm.stopPrank();
    }

    /// @notice for changing public-sale date.
    function testChangePublicSale() public {
        vm.startPrank(owner);
        uint32 newPublicSaleDate = start_public_sale_date_example + 1 days;
        nft.changePublicSaleDate(newPublicSaleDate);
        vm.stopPrank();

        assertEq(nft.getStartPublicSaleDate(), newPublicSaleDate);
    }

    function testFailChangePublicSaleWithSameValue() public {
        vm.startPrank(owner);
        uint32 newPublicSaleDate = start_public_sale_date_example;
        nft.changePublicSaleDate(newPublicSaleDate);
        vm.stopPrank();
    }

    function testFailChangePublicSaleDateWithInvalidCaller() public {
        vm.startPrank(invalidCaller);
        uint32 newPublicSaleDate = start_public_sale_date_example + 1 days;
        nft.changePublicSaleDate(newPublicSaleDate);
        vm.stopPrank();
    }

    function calculateRoyalty(uint256 _price) private pure returns (uint256) {
        return mulDiv(_price, ROYALTY_BASIS_POINT_VALUE, FEE_DENOMINATOR);
    }

    function getStatus() public view returns (string memory status) {
        status = "";
        if (nft.getCurrentPhase() == PHASE.NOT_STARTED) status = "NOT_STARTED";
        else if (nft.getCurrentPhase() == PHASE.PRE_SALE) status = "PRE_SALE";
        else if (nft.getCurrentPhase() == PHASE.REVEAL) status = "REVEAL";
        else if (nft.getCurrentPhase() == PHASE.PUBLIC_SALE) status = "PUBLIC_SALE";
    }
}
