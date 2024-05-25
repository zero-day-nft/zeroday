// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import { Math } from "@openzeppelin/contracts/"
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "./libraries/ERC721Enumerable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import { IZeroDay } from "./interfaces/IZeroDay.sol";

/// @notice when caller of the whitelist function is not included in whitelist.
error ZeroDay__UserNotIncludedInWhiteList(address user);
/// @notice this error will occurr when the off-chain caluclated merkle-tree hashs are not calcualted.
error ZeroDay__MerkleProofHashesAreEmpty();
/// @notice when user wants to mint his NFT token in whitelist for second time.
error ZeroDay__AlreadyMintedInWhiteList();
/// @notice when owner of this contract wants to change the merkle-root hash, but it's same with the last one.
error ZeroDay__NewMerkleRootHasSameNameWithOldMerkleRoot();
/// @notice when someone who is not the owner of the NFT wants to perform something on that asset.
error ZeroDay__OnlyOwnerOfTokenId();
/// @notice when minting counter exceeds max supply
error ZeroDay__ExceedsMaxSupply();
/// @notice when mentioned NFT (via tokenId) has not minted.
error ZeroDay__tokenIdHasNotMinted(uint256 tokenId);
/// @notice change revealed state variable in an unappropriate time.
error ZeroDay__RevealDateNotReached();
/// @notice change pre-sale status in an unappropriate time.
error ZeroDay__PreSaleDateNotReached();
/// @notice when an unappropriate function will call in a wrong time.
error ZeroDay__WeAreNotInThisPhase();
/// @notice when msg.value be less than the nft minting price.
error ZeroDay__notSufficientBalanceToMint();

// ▐▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▌
// ▐ ________  _______   ________  ________          ________  ________      ___    ___ ▌
// ▐|\_____  \|\  ___ \ |\   __  \|\   __  \        |\   ___ \|\   __  \    |\  \  /  /|▌
// ▐ \|___/  /\ \   __/|\ \  \|\  \ \  \|\  \       \ \  \_|\ \ \  \|\  \   \ \  \/  / /▌
// ▐     /  / /\ \  \_|/_\ \   _  _\ \  \\\  \       \ \  \ \\ \ \   __  \   \ \    / / ▌
// ▐    /  /_/__\ \  \_|\ \ \  \\  \\ \  \\\  \       \ \  \_\\ \ \  \ \  \   \/  /  /  ▌
// ▐   |\________\ \_______\ \__\\ _\\ \_______\       \ \_______\ \__\ \__\__/  / /    ▌
// ▐    \|_______|\|_______|\|__|\|__|\|_______|        \|_______|\|__|\|__|\___/ /     ▌
// ▐                                                                       \|___|/      ▌
// ▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌
/// @title ZeroDay
/// @author Parsa Aminpour
/// @notice ZeroDay NFT collection
/// #add a brief explanation about this collection.
contract ZeroDay is ERC721Royalty, ReentrancyGuard, Ownable, IZeroDay /*ERC721Burnable*/ {
    /*///////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint16 private constant COLLECTION_MAX_SUPPLY = 9983;
    // @audit-info this should change based on the team decission.
    uint256 private constant WHITELIST_PRICE = 0.5 ether;
    // @audit-info this sould change based on the team decission.
    uint256 private constant PUBLIC_SALE_PRICE = 1 ether;

    // @audit-info we should define these values seperately based on the team plan.
    /// @notice is the price of NFTs in pre-sale phase.
    uint256 public immutable i_init_pre_sale_price;
    /// @notice is the date in block.timestamp which pre-sale phase starts.
    uint256 public immutable i_startPreSaleDate;
    /// @notice is the data that collection reveal will occurr.
    uint256 public immutable i_startRevealDate;
    /// @notice is the date in block.timestamp which public-sale phase starts.
    uint256 public immutable i_startPublicSaleDate;

    /// @notice is the current phase that we are in, based on PHASE enum.

    PHASE private collection_phase;
    /// @notice totalMinted is the total NFT minted during all phases.
    uint256 private totalMinted;
    /// @notice is the root-hash of merkle tree which calculated off-chain.
    bytes32 private s_merkleRoot;

    bool private revealed;
    bool private preSaled;
    bool private publicSaled;

    /*///////////////////////////////////////////////////////////////
                               MAPPINGS
    //////////////////////////////////////////////////////////////*/
    mapping(address minter => bool included) private s_whiteListClaimed;
    mapping(uint256 tokenId => string tokenURI) private s_tokenIdToTokenURI;

    event MintedInWhiteList(address minter);
    event phaseChanged(PHASE phase);
    event merkleRootChanged(bytes32 newMerkleRoot);

    /// @param _init_pre_sale_price is the price that will defined in public sale phase
    /// @param _merkle_root is the hash of merkle tree used for whitelist algorithm
    ///     It'll calculated off-chain.
    /// @notice using Ownable to give access to the contract deployer won't effect on centralization
    ///     owner accessability restricted to managing phase that we are in, not manipulating critical functionlaities.
    constructor(
        uint256 _init_pre_sale_price,
        uint256 _startPreSaleDate,
        uint256 _startRevealDate,
        uint256 _startPublicSaleDate,
        bytes32 _merkle_root
    ) ERC721("ZeroDay", "ZERO") Ownable(msg.sender) {
        i_init_pre_sale_price = _init_pre_sale_price;
        i_startPreSaleDate = _startPreSaleDate;
        i_startPublicSaleDate = _startPublicSaleDate;
        i_startRevealDate = _startRevealDate;
        s_merkleRoot = _merkle_root;
        // initial phase
        collection_phase = PHASE.NOT_STARTED;
        totalMinted = 0;
    }

    /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    modifier isLessThanMaxSupply() {
        if (totalSupply() + 1 > COLLECTION_MAX_SUPPLY) {
            revert ZeroDay__ExceedsMaxSupply();
        }
        _;
    }

    modifier shouldBeInThePhaseOf(PHASE _phase) {
        if (collection_phase != _phase) {
            revert ZeroDay__WeAreNotInThisPhase();
        }
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @param _newMerkleRoot calculated root-hash of merkle-tree off-chain to facilitate the whitelist process
    /// @notice onlyOwner of the contract could call this function.
    function changeMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        if (_newMerkleRoot == s_merkleRoot) {
            revert ZeroDay__NewMerkleRootHasSameNameWithOldMerkleRoot();
        }

        s_merkleRoot = _newMerkleRoot;
        emit merkleRootChanged(_newMerkleRoot);
    }

    /// @param _merkleProof calculated merkle-tree off-chain to facilitate the whitelist process/
    /// @notice Eligible user will call this function to mint his NFT in pre-sale phase.
    function whiteListMint(bytes32[] memory _merkleProof)
        external
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PRE_SALE)
        isLessThanMaxSupply
    {
        if (_merkleProof.length != 0) revert ZeroDay__MerkleProofHashesAreEmpty();
        if (s_whiteListClaimed[msg.sender]) revert ZeroDay__AlreadyMintedInWhiteList();

        s_whiteListClaimed[msg.sender] = true;
        _whiteListMint(_merkleProof, msg.sender);

        emit MintedInWhiteList(msg.sender);
    }

    /// @notice the pre-defined addresses call this function to mint their NFT in pre-sale.
    /// @param _merkleProof is all mekle tree hashed which calculated off-chain
    /// @param _minter is for verifying address included in merkle tree.
    /// @notice follows CEI
    function _whiteListMint(bytes32[] memory _merkleProof, address _minter) internal {
        bytes32 leaf = keccak256(abi.encodePacked(_minter));

        if (!MerkleProof.verify(_merkleProof, s_merkleRoot, leaf)) {
            revert ZeroDay__UserNotIncludedInWhiteList(_minter);
        }
        unchecked {
            totalMinted++;
        }

        _safeMint(_minter, totalSupply() + 1);
    }

    /// @notice this function is callable in public sale phase.
    /// @param _tokenURI is the ipfs hash which contains the NFT metadata.
    function mintNFT(string memory _tokenURI)
        public
        payable
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PUBLIC_SALE)
        isLessThanMaxSupply
    {
        require(bytes(_tokenURI).length != 0, "ZeroDay__InvalidTokenURI");

        // if (msg.value < PUBLIC_SALE_PRICE) {
        //     revert ZeroDay__notSufficientBalanceToMint();
        // }

        uint256 lastCounter = totalSupply() + 1;
        s_tokenIdToTokenURI[lastCounter] = _tokenURI;

        unchecked {
            totalMinted++;
        }
        _safeMint(msg.sender, lastCounter);
    }



    function startPreSale() external onlyOwner shouldBeInThePhaseOf(PHASE.NOT_STARTED) {
        require(!preSaled, "ZeroDay__preSaledBefore");

        if (!(timeStamp() < i_startPreSaleDate)) {
            revert ZeroDay__PreSaleDateNotReached();
        }
        preSaled = true;
        collection_phase = PHASE.PRE_SALE;

        emit phaseChanged(PHASE.PRE_SALE);
    }

    // @audit-info implementing Chainlink Automation for reveal event.
    function startReveal() external onlyOwner shouldBeInThePhaseOf(PHASE.PRE_SALE) {
        require(!revealed, "ZeroDay__ReevaledBefore");

        if (!(timeStamp() <= i_startRevealDate)) {
            revert ZeroDay__RevealDateNotReached();
        }
        revealed = true;
        collection_phase = PHASE.REVEAL;

        emit phaseChanged(PHASE.REVEAL);
    }

    /// NOTE: Based on the modifier if this function calls means that we are in REVEAL phase
    ///     so the time is definitely after the REVEAL phase time, so we don't need to check the time again.
    function startPublicSale() external onlyOwner shouldBeInThePhaseOf(PHASE.REVEAL) {
        require(!publicSaled, "ZeroDay__publicSaledBefore");

        publicSaled = true;
        collection_phase = PHASE.PUBLIC_SALE;

        emit phaseChanged(PHASE.PUBLIC_SALE);
    }

    function _baseURI() internal pure virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice getting ipfs url (represent tokenURI) to get correspond tokenId NFT metadata.
    /// @param _tokenId is the tokenId of that NFT you want its tokenURI.
    /// @return tokenURI.
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        string memory ipfs_hash = s_tokenIdToTokenURI[_tokenId];
        if (bytes(ipfs_hash).length == 0) {
            revert ZeroDay__tokenIdHasNotMinted(_tokenId);
        }
        return string(abi.encodePacked(_baseURI(), ipfs_hash, "/", _tokenId));
    }

    function getTokenURI(uint256 _tokenId) public view returns (string memory) {
        return s_tokenIdToTokenURI[_tokenId];
    }

    function getWhiteListMinterStatus(address _minter) public view returns (bool) {
        return s_whiteListClaimed[_minter];
    }

    function getMerkleRoot() public view returns (bytes32) {
        return s_merkleRoot;
    }

    function totalSupply() public view returns (uint256) {
        return totalMinted;
    }

    function getCurrentPhase() public view returns (PHASE) {
        return collection_phase;
    }

    function timeStamp() private view returns (uint32) {
        return uint32(block.timestamp);
    }
}
