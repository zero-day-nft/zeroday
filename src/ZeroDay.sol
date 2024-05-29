// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IZeroDay} from "./interfaces/IZeroDay.sol";


/// @notice When the caller of the whitelist function is not included in the whitelist.
error ZeroDay__UserNotIncludedInWhiteList(address user);
/// @notice This error will occur when the off-chain calculated Merkle-tree hashes are not calculated.
error ZeroDay__MerkleProofHashesAreEmpty();
/// @notice When a user wants to mint their NFT token in the whitelist for the second time.
error ZeroDay__AlreadyMintedInWhiteList();
/// @notice When the owner of this contract wants to change the Merkle-root hash, but it is the same as the last one.
error ZeroDay__NewMerkleRootHasSameNameWithOldMerkleRoot();
/// @notice When someone who is not the owner of the NFT wants to perform an action on that asset.
error ZeroDay__OnlyOwnerOfTokenId();
/// @notice When the minting counter exceeds the max supply.
error ZeroDay__ExceedsMaxSupply();
/// @notice When the mentioned NFT (via tokenId) has not been minted.
error ZeroDay__tokenIdHasNotMinted(uint256 tokenId);
/// @notice Change the revealed state variable at an inappropriate time.
error ZeroDay__RevealDateNotReached();
/// @notice Change the pre-sale status at an inappropriate time.
error ZeroDay__PreSaleDateNotReached();
/// @notice Change the phase to public sale at an inappropriate time.
error ZeroDay__PublicSaleDateNotReached();
/// @notice When an inappropriate function is called at the wrong time.
error ZeroDay__WeAreNotInThisPhase();
/// @notice Will trigger in whitelist mint and public sale mint if the user's balance is less than required.
error ZeroDay__NotSufficientBalanceToMint();
/// @notice When the owner wants to change the collection's phase period times to the same value as defined before.
error ZeroDay__newDateIsAsSameAsOldOne();
/// @notice If you want to get a tokenURI for a token that has not been minted yet.
error ZeroDay__thisTokenIdHasNotMinted();

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
/// @notice A robust ERC721-based NFT smart contract featuring phased sales, 
///     Merkle tree whitelisting, and built-in royalty management 
///     for secure and efficient digital asset minting and trading.
contract ZeroDay is ERC721Royalty, ReentrancyGuard, Ownable, IZeroDay /*ERC721Burnable*/ {
    using Strings for uint256;
    /*///////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant COLLECTION_MAX_SUPPLY = 9983;
    // @audit-info this sould change based on the team decission.
    uint256 public constant PUBLIC_SALE_MINT_PRICE = 1 ether;

    // @audit-info we should define these values seperately based on the team plan.
    /// @notice is the price of NFTs in pre-sale phase.
    uint256 public immutable init_pre_sale_price;
    /// @notice is a date in block.timestamp which pre-sale phase starts.
    uint256 private startPreSaleDate;
    /// @notice is a date that collection reveal will occur.
    uint256 private startRevealDate;
    /// @notice is a date in block.timestamp which public-sale phase starts.
    uint256 private startPublicSaleDate;

    /// @notice is the current phase that we are in, based on PHASE enum.
    PHASE private collection_phase;
    /// @notice totalMinted is the total NFT minted during all phases - counter.
    uint256 private totalMinted;
    /// @notice is the root-hash of merkle tree which calculated off-chain.
    bytes32 private s_merkleRoot;

    /// @notice preSaled is done or not.
    bool private preSaled;
    /// @notice reveal phase is done or not.
    bool private revealed;
    /// @notice publicSaled is done or not.
    bool private publicSaled;

    /*///////////////////////////////////////////////////////////////
                               MAPPINGS
    //////////////////////////////////////////////////////////////*/
    /// @notice id minter minted his NFT in pre-sale phase, it's value will be true.
    mapping(address minter => bool included) private s_whiteListClaimed;
    mapping(uint256 tokenId => bool minted) private s_tokenIdMinted;

    event MintedInWhiteList(address minter);
    event phaseChanged(PHASE phase);
    event merkleRootChanged(bytes32 newMerkleRoot);

    /// @param _init_pre_sale_price is the price of NFTs in pre-sale phase.
    /// @param _merkle_root is the hash of merkle tree used for whitelist function - caluclated off-chain.
    /// @param _startPreSaleDate is the time that pre-sale should start.
    /// @param _startRevealDate is the time that reveal phase should start.
    /// @param _startPublicSaleDate is the time that public sale phase should start.
    /// @notice using Ownable to granting access to the contract's deployer won't effect on centralization rule.
    /// @notice owner accessability restricted to managing phase that we are in, not manipulating critical functionlaities.
    constructor(
        uint256 _init_pre_sale_price,
        uint256 _startPreSaleDate,
        uint256 _startRevealDate,
        uint256 _startPublicSaleDate,
        bytes32 _merkle_root
    ) ERC721("ZeroDay", "ZERO") Ownable(msg.sender) {
        init_pre_sale_price = _init_pre_sale_price;
        startPreSaleDate = _startPreSaleDate;
            startPublicSaleDate = _startPublicSaleDate;
        startRevealDate = _startRevealDate;
        s_merkleRoot = _merkle_root;
        // initial phase
        collection_phase = PHASE.PRE_SALE;
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

    /// @notice function is callable just if we be temporally in that time range. 
    modifier shouldBeInThePhaseOf(PHASE _phase) {
        if (collection_phase != _phase) {
            revert ZeroDay__WeAreNotInThisPhase();
        }
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @param _newMerkleRoot calculated root-hash of merkle-proof off-chain to facilitate the whitelist process
    /// @notice onlyOwner of the contract could call this function.
    function changeMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        if (_newMerkleRoot == s_merkleRoot) {
            revert ZeroDay__NewMerkleRootHasSameNameWithOldMerkleRoot();
        }

        s_merkleRoot = _newMerkleRoot;
        emit merkleRootChanged(_newMerkleRoot);
    }

     /// @dev Transfers ownership of the contract to a new account (`newOwner`).
     /// @notice Can only be called by the current owner.
     function transferOwnership(address newOwner) public virtual override onlyOwner {
        if (newOwner == address(0) && newOwner != owner()) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /// @param _merkleProof calculated merkle-proof off-chain to facilitate the whitelist process.
    /// @notice Eligible user could call this function to mint his NFT in pre-sale phase.
    function whiteListMint(bytes32[] memory _merkleProof)
        external
        payable
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PRE_SALE)
        isLessThanMaxSupply
    {
        if (msg.value < init_pre_sale_price) revert ZeroDay__NotSufficientBalanceToMint();
        if (_merkleProof.length == 0) revert ZeroDay__MerkleProofHashesAreEmpty();
        if (s_whiteListClaimed[msg.sender]) revert ZeroDay__AlreadyMintedInWhiteList();

        s_whiteListClaimed[msg.sender] = true;
        _whiteListMint(_merkleProof, msg.sender);

        emit MintedInWhiteList(msg.sender);
    }

    /// @notice the pre-defined addresses could call this function to mint their NFT in pre-sale.
    /// @param _merkleProof is all hashes which are calculated off-chain.
    /// @param _minter is for verifying address included in merkle proof.
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

    /// @notice this function is callable in public-sale phase.
    /// @notice to call this function msg.sender has to own msg.value more than PUBLIC_SALE_MINT_PRICE.
    /// Invariant: the tokenId is always less than COLLECTION_MAX_SUPPLY.
    function mintNFT()
        public
        payable
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PUBLIC_SALE)
        isLessThanMaxSupply
    {
        if (msg.value < PUBLIC_SALE_MINT_PRICE) revert ZeroDay__NotSufficientBalanceToMint();   

        uint256 lastCounter = totalSupply() + 1;
        s_tokenIdMinted[lastCounter] = true;

        unchecked {
            totalMinted++;
        }
        _safeMint(msg.sender, lastCounter);
    }

    // @audit-info implementing Chainlink Automation for reveal event.
    /// @notice only owner of the contract could call this function.
    /// @notice This function can be called just once.
    /// @notice to call this function we have to be in the pre-sale phase.
    /// @dev collection phase is initialy on pre-sale phase, so we don't need to change that.
    function startPreSale() external onlyOwner shouldBeInThePhaseOf(PHASE.PRE_SALE) {
        require(!preSaled, "ZeroDay__preSaledBefore");

        if (!(timeStamp() >= startPreSaleDate && timeStamp() < startRevealDate)) {
            revert ZeroDay__PreSaleDateNotReached();
        }
        preSaled = true;

        emit phaseChanged(PHASE.PRE_SALE);
    }

    /// @notice only owner of the contract could call this function.
    /// @notice This function can be called just once.
    /// @notice to call this function we have to be in the Reveal phase.
    function startReveal() external onlyOwner shouldBeInThePhaseOf(PHASE.PRE_SALE) {
        require(!revealed, "ZeroDay__ReevaledBefore");

        if (!(timeStamp() >= startRevealDate && timeStamp() < startPublicSaleDate)) {
            revert ZeroDay__RevealDateNotReached();
        }
        revealed = true;
        collection_phase = PHASE.REVEAL;

        emit phaseChanged(PHASE.REVEAL);
    }

    /// @notice only owner of the contract could call this function.
    /// @notice This function can be called just once.
    /// @notice to call this function we have to be in the public-sale phase.
    function startPublicSale() external onlyOwner shouldBeInThePhaseOf(PHASE.REVEAL) {
        require(!publicSaled, "ZeroDay__publicSaledBefore");

        if (!(timeStamp() >=    startPublicSaleDate)) {
            revert ZeroDay__PublicSaleDateNotReached();
        }
        publicSaled = true;
        collection_phase = PHASE.PUBLIC_SALE;

        emit phaseChanged(PHASE.PUBLIC_SALE);
    }

    /// @notice changing the pre-defined pre-sale date if it's necessary.
    /// @notice this function is only callable from the contract owner - it doesn't effect on decentralization rule.
    /// @param _newPreSaleDate the new pre-sale date to change.
    function changePreSaleDate(uint256 _newPreSaleDate) external onlyOwner {
        if(startPreSaleDate == _newPreSaleDate) revert ZeroDay__newDateIsAsSameAsOldOne();
        startPreSaleDate = _newPreSaleDate;
    }

    /// @notice changing the pre-defined Reveal date if it's necessary.
    /// @notice this function is only callable from the contract owner - it doesn't effect on decentralization rule.
    /// @param _newRevealDate the new reveal date to change.
    function changeRevealDate(uint256 _newRevealDate) external onlyOwner {
        if (startRevealDate == _newRevealDate) revert ZeroDay__newDateIsAsSameAsOldOne();
        startRevealDate = _newRevealDate;
    }

    /// @notice changing the pre-defined pre-sale date if it's necessary.
    /// @notice this function is only callable from the contract owner - it doesn't effect on decentralization rule.
    /// @param _newPublicSaleDate the new public-sale date to change.
    function changePublicSaleDate(uint256 _newPublicSaleDate) external onlyOwner {
        if (startPublicSaleDate == _newPublicSaleDate) revert ZeroDay__newDateIsAsSameAsOldOne();
        startPublicSaleDate = _newPublicSaleDate;
    }

    function _baseURI() internal pure virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice getting ipfs url (represent tokenURI) to get correspond tokenId NFT metadata.
    /// @notice the tokenURI format is https://ipfs.io/ipfs/{tokenId},json
    /// @param _tokenId is the tokenId of that NFT you want its tokenURI.
    /// @return tokenURI.
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!s_tokenIdMinted[_tokenId]) revert ZeroDay__thisTokenIdHasNotMinted();

        string memory typeFile = ".json";
        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(baseURI, _tokenId.toString(), typeFile)
                )
                : "";
    }


    function tokenIdMinted(uint256 _tokenId) public view returns (bool) {
        return s_tokenIdMinted[_tokenId];
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

    /// @notice there is no time-overflow until 2106 AC.
    function timeStamp() private view returns (uint32) {
        return uint32(block.timestamp);
    }

    function getRevealed() public view returns (bool) {
        return revealed;
    }

    function getPreSaled() public view returns (bool) {
        return preSaled;
    }

    function getPublicSaled() public view returns (bool) {
        return publicSaled;
    }
    
    function getStartPreSaleDate() public view returns(uint256) {
        return startPreSaleDate;
    }
    function getStartRevealDate() public view returns(uint256) {
        return startRevealDate;
    }
    function getStartPublicSaleDate() public view returns(uint256) {
        return startPublicSaleDate;
    }
}
