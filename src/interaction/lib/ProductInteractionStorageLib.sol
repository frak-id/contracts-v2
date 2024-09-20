// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionCampaign} from "../../campaign/InteractionCampaign.sol";
import {IInteractionFacet} from "../facets/IInteractionFacet.sol";

/// @title ProductInteractionStorageLib
/// @author @KONFeature
/// @notice Helper to access the global storage for every product interaction facets
/// @custom:security-contact contact@frak.id
abstract contract ProductInteractionStorageLib {
    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.product.interaction')) - 1)
    bytes32 private constant _PRODUCT_INTERACTION_STORAGE_SLOT =
        0xe70b52857d6f1370095d9c7055183bf0411267bd51c725ea283a2fd9a8016ce7;

    /// @custom:storage-location erc7201:frak.product.interaction
    struct ProductInteractionStorage {
        /// @dev The product id (in storage to be accessible for facets)
        uint256 productId;
        /// @dev The referral tree for this product
        bytes32 referralTree;
        /// @dev Nonce for the validation of the interaction
        mapping(bytes32 nonceKey => uint256 nonce) nonces;
        /// @dev Array of all the current active campaigns
        InteractionCampaign[] campaigns;
        /// @dev Array of our logic "facets"
        mapping(uint256 productType => IInteractionFacet facet) facets;
    }

    function _productInteractionStorage() internal pure returns (ProductInteractionStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _PRODUCT_INTERACTION_STORAGE_SLOT
        }
    }

    /// @dev Get the referral tree
    function _referralTree() internal view returns (bytes32) {
        return _productInteractionStorage().referralTree;
    }

    /// @dev Get the product id
    function _productId() internal view returns (uint256) {
        return _productInteractionStorage().productId;
    }
}
