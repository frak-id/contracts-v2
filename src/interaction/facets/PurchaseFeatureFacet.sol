// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib} from "../../constants/InteractionType.sol";
import {DENOMINATOR_FEATURE_PURCHASE} from "../../constants/ProductTypes.sol";
import {ProductInteractionStorageLib} from "../lib/ProductInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title PurchaseFeatureFacet
/// @author @KONFeature
/// @notice Contract managing a purchase related user interaction
/// @custom:security-contact contact@frak.id
contract PurchaseFeatureFacet is ProductInteractionStorageLib, IInteractionFacet {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev High level interaction router
    fallback(bytes calldata) external returns (bytes memory) {
        revert UnknownInteraction();
    }

    /// @dev Get the handled product type of this facet
    function productTypeDenominator() public pure override returns (uint8) {
        return DENOMINATOR_FEATURE_PURCHASE;
    }
}
