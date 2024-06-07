// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionCampaign} from "../../campaign/InteractionCampaign.sol";
import {IInteractionFacet} from "../facets/IInteractionFacet.sol";

/// @title ContentInteractionStorageLib
/// @author @KONFeature
/// @notice Helper to access the global storage for every content interaction facets
/// @custom:security-contact contact@frak.id
abstract contract ContentInteractionStorageLib {
    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.content.interaction')) - 1)
    bytes32 private constant _CONTENT_INTERACTION_STORAGE_SLOT =
        0xd966519fe3fe853ea9b03acd8a0422a17006c68dbe1d8fa2b9127b9e8e22eac4;

    struct ContentInteractionStorage {
        /// @dev The referral tree for this content
        bytes32 referralTree;
        /// @dev Nonce for the validation of the interaction
        mapping(bytes32 nonceKey => uint256 nonce) nonces;
        /// @dev Array of all the current active campaigns
        InteractionCampaign[] campaigns;
        /// @dev Array of our logic "facets"
        mapping(uint256 contentType => IInteractionFacet facet) facets;
    }

    function _contentInteractionStorage() internal pure returns (ContentInteractionStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _CONTENT_INTERACTION_STORAGE_SLOT
        }
    }

    /// @dev Get the referral tree
    function _referralTree() internal view returns (bytes32) {
        return _contentInteractionStorage().referralTree;
    }
}
