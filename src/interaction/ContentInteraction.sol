// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";

/// @dev Struct for all the metadatas of a platform
struct PlatformMetadata {
    /// @dev The content type for the given platform
    bytes4 contentType;
    /// @dev The platform name
    string platformName;
    /// @dev The platform origin
    string platformOrigin;
    /// @dev The hash of the origin
    bytes32 originHash;
}

/// @title ContentInteraction
/// @author @KONFeature
/// @notice Interface for a content platform
/// @dev This interface is meant to be implemented by a contract that represents a content platform
/// @custom:security-contact contact@frak.id
abstract contract ContentInteraction is OwnableRoles {
    /// @dev The base content referral tree: `keccak256("ContentReferralTree")`
    bytes32 private constant _BASE_CONTENT_TREE = 0x3d16196f272c96153eabc4eb746e08ae541cf36535edb959ed80f5e5169b6787;

    /// @dev The content id
    uint256 internal immutable _CONTENT_ID;

    /// @dev The referral registry
    ReferralRegistry internal immutable _REGERRAL_REGISTRY;

    constructor(uint256 _contentId, address _owner, address _referralRegistry) {
        _CONTENT_ID = _contentId;
        _initializeOwner(_owner);
        _REGERRAL_REGISTRY = ReferralRegistry(_referralRegistry);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Referral related                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Save on the registry level that `_user` has been referred by `_referrer`
    function _saveReferrer(address _user, address _referrer) internal {
        _REGERRAL_REGISTRY.saveReferrer(getReferralTree(), _user, _referrer);
    }

    /// @dev Check on the registry if the `_user` has already a referrer
    function _isUserAlreadyReferred(address _user) internal view returns (bool) {
        return _REGERRAL_REGISTRY.getReferrer(getReferralTree(), _user) != address(0);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Some metadata reader                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the type for the current content
    function getContentType() public pure virtual returns (bytes4);

    /// @dev Get the id for the current content
    function getContentId() public view returns (uint256) {
        return _CONTENT_ID;
    }

    /// @dev Get the referral tree for the current content
    /// @dev keccak256("ContentReferralTree", contentId)
    function getReferralTree() public view returns (bytes32 tree) {
        uint256 cId = _CONTENT_ID;
        assembly {
            mstore(0, _BASE_CONTENT_TREE)
            mstore(0x20, cId)
            tree := keccak256(0, 0x40)
        }
    }

    /// @dev Get all the platform metadata
    function getMetadata() external pure virtual returns (PlatformMetadata memory);
}
