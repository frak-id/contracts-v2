// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev The unlock type for a Gating Provider
/// @dev This should be a Type Struct Hash
type UnlockType is bytes32;

/// @author @KONFeature
/// @title IGatingProvider
/// @notice Contract representing a GatingProvider
interface IGatingProvider {
    /// @dev Get a list of all the unlock types supported by this Gating Provider
    function unlockTypes() external pure returns (UnlockType[] memory);

    /// @dev Check if the access to an `item` on a `contentId` by the given `user` is allowed
    /// @return isAllowed True if the access is allowed, false otherwise
    function isAllowed(uint256 contentId, bytes32 articleId, address user) external view returns (bool isAllowed);
}
