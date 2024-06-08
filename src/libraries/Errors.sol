// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Collection of common custom errors used in ZeroDay contract.
library Errors {
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
    /// @notice this error will appear if a phase of this collection become stopped
    error ZeroDay__thisPhaseLockedByTheOwner();
    /// @notice this error will appear in withdraw function if the contract's balance be less than the requested amount.
    error ZeroDay__notSufficientBalanceInContractToWithdraw();
    /// @notice this error will appear when withdraw function failed.
    error ZeroDay__withdrawReverted(bytes returnedData);
    /// @notice this error will appear when a zero address received as input address which is invalid.
    error ZeroDay__invalidAddresses();
    /// @notice this error will appear when caller wants to trasnfer an asset which is not the owner of that.
    error ZeroDay__callerIsNotOwner();
}
