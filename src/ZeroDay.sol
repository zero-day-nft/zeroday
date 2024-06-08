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
import {Errors} from "./libraries/Errors.sol";
import {console} from "forge-std/console.sol";

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

    /// @notice this boolean is used to change the useability of functions relatedt to a phase.
    bool private phaseLocked;
    /*///////////////////////////////////////////////////////////////
                               MAPPINGS
    //////////////////////////////////////////////////////////////*/
    /// @notice id minter minted his NFT in pre-sale phase, it's value will be true.
    mapping(address minter => bool included) private s_whiteListClaimed;
    mapping(uint256 tokenId => bool minted) private s_tokenIdMinted;

    event tokenTransferSucceeded(address indexed from, address indexed to, uint256 indexed tokenId, bytes data);
    event withdrawSucceeded(address indexed from, address indexed to, uint256 indexed amount, bytes data);
    event MintedInWhiteList(address minter);
    event phaseChanged(PHASE phase);
    event merkleRootChanged(bytes32 newMerkleRoot);
    event CurrentPhaseLockedByOwner(PHASE phase);
    event fallbackEmitted(address caller);
    event receiveEmitted(address caller);

    /// @param _init_pre_sale_price is the price of NFTs in pre-sale phase.
    /// @param _merkle_root is the hash of merkle tree used for whitelist function - caluclated off-chain.
    /// @param _startPreSaleDate is the time that pre-sale should start.
    /// @param _startRevealDate is the time that reveal phase should start.
    /// @param _startPublicSaleDate is the time that public sale phase should start.
    /// @notice using Ownable to granting access to the contract's deployer won't effect on centralization rule.
    /// @notice owner accessability restricted to managing phase that we are in, not manipulating critical functionlaities.
    /// @dev Setting defualt royalty to this contract's address for artists who don't use royalty for their arts.
    constructor(
        uint256 _init_pre_sale_price,
        uint256 _startPreSaleDate,
        uint256 _startRevealDate,
        uint256 _startPublicSaleDate,
        bytes32 _merkle_root
    ) payable ERC721("ZeroDay", "ZERO") Ownable(msg.sender) {
        init_pre_sale_price = _init_pre_sale_price;
        startPreSaleDate = _startPreSaleDate;
        startPublicSaleDate = _startPublicSaleDate;
        startRevealDate = _startRevealDate;
        s_merkleRoot = _merkle_root;
        // initial phase
        collection_phase = PHASE.PRE_SALE;
        phaseLocked = false;

        totalMinted = 0;

        _setDefaultRoyalty(address(this), 0);
    }

    /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    modifier isLessThanMaxSupply() {
        if (totalSupply() + 1 > COLLECTION_MAX_SUPPLY) {
            revert Errors.ZeroDay__ExceedsMaxSupply();
        }
        _;
    }

    /// @notice function is callable just if we be temporally in that time range.
    modifier shouldBeInThePhaseOf(PHASE _phase) {
        if (collection_phase != _phase) {
            revert Errors.ZeroDay__WeAreNotInThisPhase();
        }
        _;
    }

    modifier isPhaseLocked() {
        if (phaseLocked) revert Errors.ZeroDay__thisPhaseLockedByTheOwner();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @param _newMerkleRoot calculated root-hash of merkle-proof off-chain to facilitate the whitelist process
    /// @notice onlyOwner of the contract could call this function.
    function changeMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        if (_newMerkleRoot == s_merkleRoot) {
            revert Errors.ZeroDay__NewMerkleRootHasSameNameWithOldMerkleRoot();
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

    /// @notice This function is only callable by the owner of the contract.
    /// @notice The onlyOwner caller restriction doesn't affect the decentralization of the contract.
    /// @param _target The address to which the owner wants to send Ether.
    /// @param _amount The amount of Ether that the owner wants to transfer from this contract to _target.
    /// @param _data Optional data for the transfer, could be "".
    function withdraw(address payable _target, uint256 _amount, bytes memory _data) external onlyOwner {
        if (_amount > address(this).balance) {
            revert Errors.ZeroDay__notSufficientBalanceInContractToWithdraw();
        }

        (bool success, bytes memory returnedData) = _target.call{value: _amount}(_data);
        if (!success) {
            revert Errors.ZeroDay__withdrawReverted(returnedData);
        }
        emit withdrawSucceeded(address(this), _target, _amount, _data);
    }

    fallback() external payable {
        emit fallbackEmitted(msg.sender);
    }

    receive() external payable {
        emit receiveEmitted(msg.sender);
    }

    /// @param _merkleProof calculated merkle-proof off-chain to facilitate the whitelist process.
    /// @notice Eligible user could call this function to mint his NFT in pre-sale phase.
    function whiteListMint(bytes32[] memory _merkleProof)
        external
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PRE_SALE)
        isPhaseLocked
        isLessThanMaxSupply
    {
        if (_merkleProof.length == 0) revert Errors.ZeroDay__MerkleProofHashesAreEmpty();
        if (s_whiteListClaimed[msg.sender]) revert Errors.ZeroDay__AlreadyMintedInWhiteList();

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
            revert Errors.ZeroDay__UserNotIncludedInWhiteList(_minter);
        }
        unchecked {
            totalMinted++;
        }

        _safeMint(_minter, totalSupply() + 1);
    }

    /// @notice this function is callable in public-sale phase.
    /// @notice to call this function msg.sender has to own msg.value more than PUBLIC_SALE_MINT_PRICE.
    /// Invariant: the tokenId is always less than COLLECTION_MAX_SUPPLY.
    function mintNFT(uint96 _royaltyValue)
        public
        payable
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PUBLIC_SALE)
        isPhaseLocked
        isLessThanMaxSupply
    {
        if (msg.value < PUBLIC_SALE_MINT_PRICE) revert Errors.ZeroDay__NotSufficientBalanceToMint();

        uint256 lastCounter = totalSupply() + 1;
        s_tokenIdMinted[lastCounter] = true;

        unchecked {
            totalMinted++;
        }

        // if _royaltyValue is sets to zero, then the default Roaylty will consider.
        if (_royaltyValue != 0) {
            _setTokenRoyalty(lastCounter, msg.sender, _royaltyValue);
        }
        _safeMint(msg.sender, lastCounter);
    }

    /// @notice transfering NFT asset to another wallet.
    /// @param _to is the destination address which should not be address(0)
    /// @param _tokenId is the one of your NFT token's ID that you want to trasnfer.
    /// @param _data is the encoded message in the transfer function which is forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
    function transfer(address _to, uint256 _tokenId, bytes memory _data)
        external
        payable
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PUBLIC_SALE)
    {
        if (_to == address(0x0)) revert Errors.ZeroDay__invalidAddresses();
        if (_requireOwned(_tokenId) != msg.sender) revert Errors.ZeroDay__callerIsNotOwner();

        _safeTransfer(msg.sender, _to, _tokenId, _data);

        emit tokenTransferSucceeded(msg.sender, _to, _tokenId, _data);
    }

    /// @notice only owner of the contract could call this function.
    /// @notice This function can be called just once.
    /// @notice to call this function we have to be in the pre-sale phase.
    /// @dev collection phase is initialy on pre-sale phase, so we don't need to change that.
    function startPreSale() external onlyOwner shouldBeInThePhaseOf(PHASE.PRE_SALE) {
        require(!preSaled, "ZeroDay__preSaledBefore");

        if (!(timeStamp() >= startPreSaleDate && timeStamp() < startRevealDate)) {
            revert Errors.ZeroDay__PreSaleDateNotReached();
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
            revert Errors.ZeroDay__RevealDateNotReached();
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

        if (!(timeStamp() >= startPublicSaleDate)) {
            revert Errors.ZeroDay__PublicSaleDateNotReached();
        }
        publicSaled = true;
        collection_phase = PHASE.PUBLIC_SALE;

        emit phaseChanged(PHASE.PUBLIC_SALE);
    }

    /// @notice changing the pre-defined pre-sale date if it's necessary.
    /// @notice this function is only callable from the contract owner - it doesn't effect on decentralization rule.
    /// @param _newPreSaleDate the new pre-sale date to change.
    function changePreSaleDate(uint256 _newPreSaleDate) external onlyOwner {
        if (startPreSaleDate == _newPreSaleDate) revert Errors.ZeroDay__newDateIsAsSameAsOldOne();
        startPreSaleDate = _newPreSaleDate;
    }

    /// @notice changing the pre-defined Reveal date if it's necessary.
    /// @notice this function is only callable from the contract owner - it doesn't effect on decentralization rule.
    /// @param _newRevealDate the new reveal date to change.
    function changeRevealDate(uint256 _newRevealDate) external onlyOwner {
        if (startRevealDate == _newRevealDate) revert Errors.ZeroDay__newDateIsAsSameAsOldOne();
        startRevealDate = _newRevealDate;
    }

    /// @notice changing the pre-defined pre-sale date if it's necessary.
    /// @notice this function is only callable from the contract owner - it doesn't effect on decentralization rule.
    /// @param _newPublicSaleDate the new public-sale date to change.
    function changePublicSaleDate(uint256 _newPublicSaleDate) external onlyOwner {
        if (startPublicSaleDate == _newPublicSaleDate) revert Errors.ZeroDay__newDateIsAsSameAsOldOne();
        startPublicSaleDate = _newPublicSaleDate;
    }

    /// @notice this function is use for modifying public function callable using for a specific phase.
    /// @dev only owner could call this function.
    function changePhaseLock() external onlyOwner {
        phaseLocked = phaseLocked ? false : true;
        emit CurrentPhaseLockedByOwner(collection_phase);
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
        if (!s_tokenIdMinted[_tokenId]) revert Errors.ZeroDay__thisTokenIdHasNotMinted();

        string memory typeFile = ".json";
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _tokenId.toString(), typeFile)) : "";
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

    function getStartPreSaleDate() public view returns (uint256) {
        return startPreSaleDate;
    }

    function getStartRevealDate() public view returns (uint256) {
        return startRevealDate;
    }

    function getStartPublicSaleDate() public view returns (uint256) {
        return startPublicSaleDate;
    }
}
