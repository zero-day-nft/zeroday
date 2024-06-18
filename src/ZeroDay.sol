// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {IZeroDay} from "./interfaces/IZeroDay.sol";
import {Errors} from "./libraries/Errors.sol";

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
    uint32 private startPreSaleDate;
    /// @notice is a date that collection reveal will occur.
    uint32 private startRevealDate;
    /// @notice is a date in block.timestamp which public-sale phase starts.
    uint32 private startPublicSaleDate;

    /// @notice is the current phase that we are in, based on PHASE enum.
    PHASE private collection_phase;
    /// @notice totalMinted is the total NFT minted during all phases - counter.
    uint256 private totalMinted;
    /// @notice is the root-hash of merkle tree which calculated off-chain.
    bytes32 private s_merkleRoot;

    /// @notice this boolean is used to change the useability of functions relatedt to a phase.
    bool private phaseLocked;
    /*///////////////////////////////////////////////////////////////
                               MAPPINGS
    //////////////////////////////////////////////////////////////*/
    /// @notice id minter minted his NFT in pre-sale phase, it's value will be true.
    mapping(address minter => bool included) private s_whiteListClaimed;

    event tokenTransferSucceeded(address indexed from, address indexed to, uint256 indexed tokenId, bytes data);
    event withdrawSucceeded(address indexed from, address indexed to, uint256 indexed amount, bytes data);
    event NFTMinted(uint256 indexed tokenId, address indexed owner, uint96 indexed royaltyValue);
    event MintedInWhiteList(address minter);
    event phaseChanged(PHASE phase);
    event merkleRootChanged(bytes32 newMerkleRoot);
    event CurrentPhaseLockedByOwner(PHASE phase);
    event fallbackEmitted(address caller);
    event receiveEmitted(address caller);

    /// @param _init_pre_sale_price is the price of NFTs in pre-sale phase.
    /// @param _startPreSaleDate is the time that pre-sale should start.
    /// @param _startRevealDate is the time that reveal phase should start.
    /// @param _startPublicSaleDate is the time that public sale phase should start.
    /// @param _merkle_root is the hash of merkle tree used for whitelist function - caluclated off-chain.
    /// @notice using Ownable to granting access to the contract's deployer won't effect on centralization rule.
    /// @notice owner accessability restricted to managing phase that we are in, not manipulating critical functionlaities.
    /// @dev Setting defualt royalty to this contract's address for artists who don't use royalty for their arts.
    constructor(
        uint256 _init_pre_sale_price,
        uint32 _startPreSaleDate,
        uint32 _startRevealDate,
        uint32 _startPublicSaleDate,
        bytes32 _merkle_root
    ) payable ERC721("ZeroDay", "ZERO") Ownable(msg.sender) {
        init_pre_sale_price = _init_pre_sale_price;
        startPreSaleDate = _startPreSaleDate;
        startPublicSaleDate = _startPublicSaleDate;
        startRevealDate = _startRevealDate;
        s_merkleRoot = _merkle_root;
        // initial phase
        collection_phase = PHASE.NOT_STARTED;
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

    modifier isPhaseUnlocked() {
        if (phaseLocked) revert Errors.ZeroDay__thisPhaseLockedByTheOwner();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    fallback() external payable {
        emit fallbackEmitted(msg.sender);
    }
    receive() external payable {
        emit receiveEmitted(msg.sender);
    }

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
        if (newOwner == address(0) && newOwner == owner()) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /// @notice This function can only be called by the owner of the contract.
    /// @notice The restriction that only the owner can call this function does not compromise the decentralization of the contract.
    /// @param _target The address to which the owner intends to send Ether.
    /// @param _amount The amount of Ether the owner intends to transfer from this contract to the specified target address.
    /// @param _data Optional data to include with the transfer, which can be an empty string.
    function withdraw(address payable _target, uint256 _amount, bytes memory _data) external onlyOwner {
        if (_amount > address(this).balance) {
            revert Errors.ZeroDay__notSufficientBalanceInContractToWithdraw();
        }

        uint256 amount = _amount == type(uint256).max ? address(this).balance : _amount;

        (bool success, bytes memory returnedData) = _target.call{value: amount}(_data);
        if (!success) {
            revert Errors.ZeroDay__withdrawReverted(returnedData);
        }
        emit withdrawSucceeded(address(this), _target, _amount, _data);
    }


    /// @param _merkleProof calculated merkle-proof off-chain to facilitate the whitelist process.
    /// @notice Eligible user could call this function to mint his NFT in pre-sale phase.
    function whiteListMint(bytes32[] memory _merkleProof, uint256 _amount)
        external
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PRE_SALE)
        isPhaseUnlocked
        isLessThanMaxSupply
    {
        if (_merkleProof.length == 0) revert Errors.ZeroDay__MerkleProofHashesAreEmpty();
        if (s_whiteListClaimed[msg.sender]) revert Errors.ZeroDay__AlreadyMintedInWhiteList();

        _whiteListMint(_merkleProof, msg.sender, _amount);
        
        emit MintedInWhiteList(msg.sender);
    }

    /// @param _merkleProof An array of hashes that are calculated off-chain.
    /// @param _minter The address to be verified as included in the Merkle proof.
    /// @notice This function follows the Checks-Effects-Interactions (CEI) pattern.
    function _whiteListMint(bytes32[] memory _merkleProof, address _minter, uint256 _amount) internal {
        bytes32 leaf = keccak256(abi.encodePacked(_minter, _amount));

        if (!MerkleProof.verify(_merkleProof, s_merkleRoot, leaf)) {
            revert Errors.ZeroDay__UserNotIncludedInWhiteList(_minter);
        }
        uint256 tokenIdToMint = totalMinted;
        unchecked {
            totalMinted++;
        }
        
        s_whiteListClaimed[msg.sender] = true;
        _safeMint(_minter, tokenIdToMint);
    }

    /// @notice This function can be called during the public sale phase.
    /// @notice To call this function, the sender (msg.sender) must possess a balance greater than or equal to the public sale mint price (PUBLIC_SALE_MINT_PRICE).
    /// @param _royaltyValue The percentage of the sale price that will be paid to the original creator of the NFT as a royalty. 
    ///     This value ensures that creators continue to receive compensation each time their NFT is resold in secondary markets. 
    ///     The royalty value is typically set during the minting of the NFT and is immutable thereafter. It represents a key feature 
    ///     in supporting the ongoing revenue for artists and creators in the NFT ecosystem.
    function mintNFT(uint96 _royaltyValue)
        public
        payable
        nonReentrant
        shouldBeInThePhaseOf(PHASE.PUBLIC_SALE)
        isPhaseUnlocked
        isLessThanMaxSupply
    {
        if (msg.value < PUBLIC_SALE_MINT_PRICE) revert Errors.ZeroDay__NotSufficientBalanceToMint();

        uint256 tokenIdToMint = totalSupply();

        unchecked {
            totalMinted++;
        }

        // if _royaltyValue is sets to zero, then the default Roaylty will consider.
        if (_royaltyValue != 0) {
            _setTokenRoyalty(tokenIdToMint, msg.sender, _royaltyValue);
        }
        _safeMint(msg.sender, tokenIdToMint);

        emit NFTMinted(tokenIdToMint, msg.sender, _royaltyValue);
    }


    /// @notice Transfers an NFT asset to another wallet.
    /// @param _to The destination address, which should not be the zero address (address(0)).
    /// @param _tokenId The ID of the NFT token that you want to transfer.
    /// @param _data The encoded message in the transfer function, which is forwarded to contract recipients in {IERC721Receiver-onERC721Received}.
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

    /// @notice Only the owner of the contract can call this function.
    /// @notice This function can be called only once.
    /// @notice to call this function we have to be in the PRE_SALED phase in terms of time and in the NOT_STARTED in terms of current phase.
    function startPreSale() external onlyOwner shouldBeInThePhaseOf(PHASE.NOT_STARTED) {
        // require(!preSaled, "ZeroDay__preSaledBefore");

        if (!(timeStamp() >= startPreSaleDate && timeStamp() < startRevealDate)) {
            revert Errors.ZeroDay__PreSaleDateNotReached();
        }
        collection_phase = PHASE.PRE_SALE;

        emit phaseChanged(PHASE.PRE_SALE);
    }

    /// @notice Only the owner of the contract can call this function.
    /// @notice This function can be called only once.
    /// @notice to call this function we have to be in the REVEAL phase in terms of time and in the PRE_SALE in terms of current phase.
    function startReveal() external onlyOwner shouldBeInThePhaseOf(PHASE.PRE_SALE) {
        // require(!revealed, "ZeroDay__ReevaledBefore");

        if (!(timeStamp() >= startRevealDate && timeStamp() < startPublicSaleDate)) {
            revert Errors.ZeroDay__RevealDateNotReached();
        }
        collection_phase = PHASE.REVEAL;

        emit phaseChanged(PHASE.REVEAL);
    }

    /// @notice only owner of the contract could call this function.
    /// @notice This function can be called just once.
    /// @notice to call this function we have to be in the public-sale phase in terms of time and in the REVEAL in terms of current phase.
    function startPublicSale() external onlyOwner shouldBeInThePhaseOf(PHASE.REVEAL) {
        // require(!publicSaled, "ZeroDay__publicSaledBefore");

        if (!(timeStamp() >= startPublicSaleDate)) {
            revert Errors.ZeroDay__PublicSaleDateNotReached();
        }
        collection_phase = PHASE.PUBLIC_SALE;

        emit phaseChanged(PHASE.PUBLIC_SALE);
    }

    /// @notice Changes the pre-defined pre-sale date if necessary.
    /// @notice This function can only be called by the contract owner and does not affect the decentralization rule.
    /// @param _newPreSaleDate The new pre-sale date to be set.
    function changePreSaleDate(uint32 _newPreSaleDate) external onlyOwner {
        if (startPreSaleDate == _newPreSaleDate) revert Errors.ZeroDay__newDateIsAsSameAsOldOne();
        startPreSaleDate = _newPreSaleDate;
    }

    /// @notice Changes the pre-defined Reveal date if necessary.
    /// @notice This function can only be called by the contract owner and does not affect the decentralization rule.
    /// @param _newRevealDate The new Reveal date to be set.
    function changeRevealDate(uint32 _newRevealDate) external onlyOwner {
        if (startRevealDate == _newRevealDate) revert Errors.ZeroDay__newDateIsAsSameAsOldOne();
        startRevealDate = _newRevealDate;
    }

    /// @notice Changes the pre-defined public sale date if necessary.
    /// @notice This function can only be called by the contract owner and does not affect the decentralization rule.
    /// @param _newPublicSaleDate The new public sale date to be set.
    function changePublicSaleDate(uint32 _newPublicSaleDate) external onlyOwner {
        if (startPublicSaleDate == _newPublicSaleDate) revert Errors.ZeroDay__newDateIsAsSameAsOldOne();
        startPublicSaleDate = _newPublicSaleDate;
    }

    /// @notice Modifies the callable status of public functions for a specific phase.
    /// @dev Only the owner can call this function.
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
    /// @notice Retrieves the IPFS URL representing the tokenURI to get the metadata for the corresponding NFT tokenId.
    /// @notice The tokenURI format is https://ipfs.io/ipfs/{tokenId}.json
    /// @param _tokenId The tokenId of the NFT for which you want the tokenURI.
    /// @return tokenURI A string representing the tokenURI.
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (ownerOf(_tokenId) == address(0x0)) revert Errors.ZeroDay__thisTokenIdHasNotMinted();

        string memory typeFile = ".json";
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _tokenId.toString(), typeFile)) : "";
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

    function getStartPreSaleDate() public view returns (uint32) {
        return startPreSaleDate;
    }

    function getStartRevealDate() public view returns (uint32) {
        return startRevealDate;
    }

    function getStartPublicSaleDate() public view returns (uint32) {
        return startPublicSaleDate;
    }
}
