// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import { Math } from "@openzeppelin/contracts/"
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";    
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { ERC721 } from "@solmate/src/tokens/ERC721.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import { Common } from "@prb-math/src/Common.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ZeroDay is ReentrancyGuard, Ownable, ERC721 {
    error ZeroDay__MerkleProofHashesAreEmpty();
    error ZeroDay__ZeroAmountNotAllowed();
    error Zero__AlreadyMintedInWhiteList();
    
    uint16 private constant COLLECTION_MAX_SUPPLY = 9983;
    uint256 private immutable i_init_pre_sale_price;
    bytes32 private immutable i_merkle_root;

    mapping(address => bool) private whiteListClaimed;

    event MintedInWhiteList(
        address minter;
    )

    /// @param _init_pre_sale_price is the price that will defined in public sale phase
    /// @param _merkle_root is the hash of merkle tree used for whitelist algorithm
    ///     It'll calculated off-chain.
    /// @notice using Ownable to give access to the contract deployer won't effect on centralization
    ///     owner accessability restricted to managing phase that we are in, not manipulating critical functionlaities.
    constructor(uint256 _init_pre_sale_price, bytes32 _merkle_root) 
    ERC721("ZeroDay", "ZERO")
    Ownable(msg.sender)
    {
        i_init_pre_sale_price = _init_pre_sale_price;
        i_merkle_root = _merkle_root;
    }   


    /// @notice the pre-defined addresses call this function to mint their NFT in pre-sale.
    /// @param _merkleProof is 
    function _whiteListMint(bytes32[] calldata _merkleProof, address _minter) internal returns(bool) {
        
    }

    function whiteListMin(bytes32[] calldata _merkleProof) external nonReentrant() {
        if (_merkleProof.length != 0) revert ZeroDay__MerkleProofHashesAreEmpty();
        if (whiteListClaimed[msg.sender]) revert Zero__AlreadyMintedInWhiteList();
        
        _whiteListMint(_merkleProof, msg.sender);
    }

    function tokenURI(uint256 id) public view virtual override returns(string memory) {}
}